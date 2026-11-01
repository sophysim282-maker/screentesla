#import "Receiver.h"
#import "VPNDiscovery.h"
#import "AnnexB.h"
#import <VideoToolbox/VideoToolbox.h>
#import <CoreImage/CoreImage.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <ImageIO/ImageIO.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <sys/socket.h>
#import <unistd.h>
#import "raop.h"
#import <netinet/tcp.h>
extern void sl_dnssd_set_external(dnssd_t *, int);
extern const char *sl_dnssd_get_raop_txt(dnssd_t *, int *);
_Static_assert(kVTInvalidSessionErr == -12903, "Check decoder error mapping against the iOS SDK");

@interface Receiver () {
    raop_t *_raop; dnssd_t *_dns;
    VPNDiscovery *_vpnDiscovery;
    VTDecompressionSessionRef _decoder;
    CMVideoFormatDescriptionRef _format;
    NSData *_sps,*_pps,*_jpeg;
    CIContext *_ci;
    int _socket;
    BOOL _running;
    BOOL _previewPending;
    BOOL _jpegBusy;
    dispatch_queue_t _jpegQueue;
    dispatch_semaphore_t _httpSlots;
    NSCondition *_frameReady;
    CFTimeInterval _frameTime;
    CFTimeInterval _lastPreview;
    NSUInteger _generation;
    BOOL _waitingForIDR;
    BOOL _appBackgrounded;
    NSUInteger _backgroundFailures;
    CFTimeInterval _nextDecoderAttempt;
    CFTimeInterval _lastDecoderErrorLog;
    uint64_t _decoderErrors;
    id _foregroundObserver;
    id _backgroundObserver;
    uint64_t _frames;
    CFTimeInterval _lastJPEG;
    dispatch_queue_t _decodeQueue;
    dispatch_semaphore_t _pendingVideo;
}
@property(nonatomic,copy,readwrite) NSString *token;
@property(nonatomic,copy,readwrite) NSDictionary *discoveryProfile;
- (void)emit:(NSString *)message;
- (void)receive:(NSData *)data;
- (void)image:(CVImageBufferRef)pixel;
- (void)decode:(NSData *)data;
- (BOOL)startWeb;
- (void)serveClient:(int)client generation:(NSUInteger)generation;
- (void)discardDecoder;
- (BOOL)createDecoder;
- (void)decoderFailed:(OSStatus)error;
- (void)installLifecycleObservers;
@end
static void log_message(void *c,int level,const char *m) {
    if(level<=RAOP_LOG_INFO) [(__bridge Receiver *)c emit:[NSString stringWithUTF8String:m] ?: @"Receiver log"];
}
static void audio(void *c,raop_ntp_t *n,aac_decode_struct *d) { /* Video-only first prototype. */ }
static void flush(void *c) {}
static void connection(void *c) { [(__bridge Receiver *)c emit:@"AirPlay control connection received. Waiting for video."]; }
static void video(void *c,raop_ntp_t *n,h264_decode_struct *d) {
    if(d->data_len>0 && d->data_len<16*1024*1024)
        [(__bridge Receiver *)c receive:[NSData dataWithBytes:d->data length:d->data_len]];
}
static void decoded(void *c,void *source,OSStatus status,VTDecodeInfoFlags flags,CVImageBufferRef image,CMTime pts,CMTime duration) {
    if(status==noErr && image) [(__bridge Receiver *)c image:image];
}
static BOOL send_all(int fd, const void *bytes,size_t length) {
    const char *p=bytes;
    while(length) { ssize_t n=send(fd,p,length,0); if(n<=0)return NO; p+=n;length-=(size_t)n; }
    return YES;
}
@implementation Receiver
- (instancetype)init { if((self=[super init])) { _socket=-1;_ci=[CIContext contextWithOptions:nil];_decodeQueue=dispatch_queue_create("ScreenLink.decode",DISPATCH_QUEUE_SERIAL);_pendingVideo=dispatch_semaphore_create(4);_jpegQueue=dispatch_queue_create("ScreenLink.jpeg",DISPATCH_QUEUE_SERIAL);_httpSlots=dispatch_semaphore_create(4);_frameReady=[NSCondition new];_token=NSUUID.UUID.UUIDString;[self installLifecycleObservers]; } return self; }
- (BOOL)isRunning { return _running; }
- (BOOL)externalDiscovery { return self.discoveryMode!=SLDiscoveryNative; }
- (void)emit:(NSString *)s { dispatch_async(dispatch_get_main_queue(),^{ if(self.status)self.status(s); }); }
- (void)installLifecycleObservers {
    __weak Receiver *weak=self;
    _backgroundObserver=[NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){
        Receiver *owner=weak;if(!owner)return;
        dispatch_async(owner->_decodeQueue,^{owner->_appBackgrounded=YES;owner->_backgroundFailures=0;});
    }];
    _foregroundObserver=[NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){
        Receiver *owner=weak;if(!owner)return;
        dispatch_async(owner->_decodeQueue,^{
            owner->_appBackgrounded=NO;owner->_backgroundFailures=0;owner->_nextDecoderAttempt=0;
            if(owner->_running && owner->_waitingForIDR)[owner emit:@"App active again. Decoder recovery will resume at the next H.264 keyframe; the browser may hold its last image until then."];
        });
    }];
}
- (void)receive:(NSData *)data {
    if(dispatch_semaphore_wait(_pendingVideo,DISPATCH_TIME_NOW)!=0)return;
    NSUInteger generation;@synchronized(self){generation=_generation;}
    dispatch_async(_decodeQueue,^{
        BOOL current;@synchronized(self){current=generation==self->_generation;}
        @autoreleasepool { if(current)[self decode:data]; }
        dispatch_semaphore_signal(self->_pendingVideo);
    });
}
- (void)discardDecoder {
    if(_decoder){VTDecompressionSessionWaitForAsynchronousFrames(_decoder);VTDecompressionSessionInvalidate(_decoder);CFRelease(_decoder);_decoder=NULL;}
}
- (BOOL)createDecoder {
    if(!_format)return NO;
    VTDecompressionOutputCallbackRecord cb={decoded,(__bridge void *)self};
    NSDictionary *attrs=@{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey:@{}};
    OSStatus error=VTDecompressionSessionCreate(NULL,_format,NULL,(__bridge CFDictionaryRef)attrs,&cb,&_decoder);
    if(error){[self decoderFailed:error];return NO;}
    VTSessionSetProperty(_decoder,kVTDecompressionPropertyKey_RealTime,kCFBooleanTrue);
    return YES;
}
- (void)decoderFailed:(OSStatus)error {
    _decoderErrors++;CFTimeInterval now=CACurrentMediaTime();
    if(error==kVTInvalidSessionErr || error==kVTVideoDecoderMalfunctionErr || error==kVTVideoDecoderNotAvailableNowErr || !_decoder) {
        [self discardDecoder];_waitingForIDR=YES;_nextDecoderAttempt=now+1.0;
        if(_appBackgrounded)_backgroundFailures++;
    }
    if(!_lastDecoderErrorLog || now-_lastDecoderErrorLog>=2.0) {
        _lastDecoderErrorLog=now;
        [self emit:[NSString stringWithFormat:@"Decoder error %d (%llu total), app %@. %@",(int)error,(unsigned long long)_decoderErrors,_appBackgrounded?@"background":@"foreground",_waitingForIDR?@"Invalid decoder discarded; waiting for a keyframe to recover.":@"Frame rejected; waiting for later video."]];
    }
    if(_appBackgrounded && _backgroundFailures==2)[self emit:@"iOS rejected two decoder sessions in background. Pausing decoder recreation until the app is active again. AirPlay/network listeners are not stopped by this decoder error. A frozen browser image is not proof of a live stream."];
}
- (void)decode:(NSData *)data {
    const uint8_t *p=data.bytes;size_t offsets[256],sizes[256];
    size_t count=sl_nals(p,data.length,offsets,sizes,256);if(count>256)return;
    BOOL changed=NO,hasIDR=NO,hasVCL=NO;
    NSMutableData *avcc=[NSMutableData data];
    for(size_t i=0;i<count;i++) {
        uint8_t type=p[offsets[i]]&31;NSData *nal=[NSData dataWithBytes:p+offsets[i] length:sizes[i]];
        if(type==7){changed|=![_sps isEqual:nal];_sps=nal;}
        else if(type==8){changed|=![_pps isEqual:nal];_pps=nal;}
        else {
            if(type>=1 && type<=5)hasVCL=YES;if(type==5)hasIDR=YES;
            uint32_t size=htonl((uint32_t)sizes[i]);[avcc appendBytes:&size length:4];[avcc appendData:nal];
        }
    }
    if(changed && _sps && _pps) {
        [self discardDecoder];if(_format){CFRelease(_format);_format=NULL;}
        const uint8_t *sets[]={_sps.bytes,_pps.bytes};const size_t lengths[]={_sps.length,_pps.length};
        OSStatus error=CMVideoFormatDescriptionCreateFromH264ParameterSets(NULL,2,sets,lengths,4,&_format);
        if(error){[self decoderFailed:error];return;}
        _waitingForIDR=YES;
        [self emit:@"H.264 configuration received. Waiting for a keyframe."];
    }
    if(!_format || !hasVCL || !avcc.length)return;
    if(_waitingForIDR && !hasIDR)return;
    if(!_decoder) {
        if(_appBackgrounded && _backgroundFailures>=2)return;
        if(CACurrentMediaTime()<_nextDecoderAttempt)return;
        if(!hasIDR || ![self createDecoder])return;
    }
    CMBlockBufferRef block=NULL;CMSampleBufferRef sample=NULL;
    OSStatus error=CMBlockBufferCreateWithMemoryBlock(NULL,NULL,avcc.length,NULL,NULL,0,avcc.length,0,&block);
    if(error){[self decoderFailed:error];return;}
    error=CMBlockBufferReplaceDataBytes(avcc.bytes,block,0,avcc.length);
    size_t size=avcc.length;
    if(!error)error=CMSampleBufferCreateReady(NULL,block,_format,1,0,NULL,1,&size,&sample);
    BOOL recovering=_waitingForIDR;
    if(!error)error=VTDecompressionSessionDecodeFrame(_decoder,sample,0,NULL,NULL);
    if(sample)CFRelease(sample);CFRelease(block);
    if(error){[self decoderFailed:error];return;}
    _waitingForIDR=NO;
    if(recovering)[self emit:@"Decoder accepted a keyframe. Waiting for actual decoded output; the frame counter confirms recovery."];
}
- (void)image:(CVImageBufferRef)pixel {
    CFTimeInterval now=CACurrentMediaTime();
    BOOL deliver=NO, encode=NO;NSUInteger generation;
    @synchronized(self) {
        if(!_running)return;
        generation=_generation;
        if(!_previewPending && self.preview && now-_lastPreview>=1.0/15.0){_lastPreview=now;_previewPending=YES;deliver=YES;}
        // Drop rendered output under pressure, never build a JPEG work backlog.
        if(!_jpegBusy && now-_lastJPEG>=1.0/15.0){_jpegBusy=YES;_lastJPEG=now;encode=YES;}
    }
    if(deliver) {
        CVPixelBufferRetain(pixel);
        dispatch_async(dispatch_get_main_queue(),^{
            BOOL current;@synchronized(self){current=self->_running && generation==self->_generation;}
            if(current && self.preview)self.preview(pixel);
            CVPixelBufferRelease(pixel);
            @synchronized(self){self->_previewPending=NO;}
        });
    }
    if(!encode)return;
    CVPixelBufferRetain(pixel);
    dispatch_async(_jpegQueue,^{
        @autoreleasepool {
            CIImage *im=[CIImage imageWithCVPixelBuffer:pixel];
            CGFloat scale=MIN(1.0,960.0/MAX(im.extent.size.width,im.extent.size.height));
            im=[im imageByApplyingTransform:CGAffineTransformMakeScale(scale,scale)];
            CGColorSpaceRef cs=CGColorSpaceCreateDeviceRGB();
            NSData *jpeg=[self->_ci JPEGRepresentationOfImage:im colorSpace:cs options:@{(__bridge NSString *)kCGImageDestinationLossyCompressionQuality:@0.5}];
            CGColorSpaceRelease(cs);CVPixelBufferRelease(pixel);
            uint64_t frames=0;
            @synchronized(self) {
                if(jpeg.length && self->_running && generation==self->_generation) {
                    self->_jpeg=jpeg;self->_frameTime=CACurrentMediaTime();frames=++self->_frames;
                }
                self->_jpegBusy=NO;
            }
            if(frames) {
                [self->_frameReady lock];[self->_frameReady broadcast];[self->_frameReady unlock];
                if(frames==1 || frames%150==0)[self emit:[NSString stringWithFormat:@"Actual video received: %llu browser frames. Low-latency output available.",(unsigned long long)frames]];
            }
        }
    });
}
static NSArray *txtStrings(const char *bytes,int length) {
    NSMutableArray *result=[NSMutableArray array];int offset=0;
    while(offset<length){unsigned int size=(uint8_t)bytes[offset++];if(size>(unsigned int)(length-offset))break;
        NSString *item=[[NSString alloc]initWithBytes:bytes+offset length:size encoding:NSUTF8StringEncoding];
        if(item)[result addObject:item];offset+=size;}
    return result;
}
- (BOOL)start {
    if(_running)return YES;
    @synchronized(self){_generation++;}
    _token=NSUUID.UUID.UUIDString;
    raop_callbacks_t cb={0};cb.cls=(__bridge void *)self;cb.audio_process=audio;cb.video_process=video;cb.video_flush=flush;cb.audio_flush=flush;cb.conn_init=connection;
    _raop=raop_init(4,&cb);if(!_raop){[self emit:@"Receiver initialization failed."];return NO;}
    raop_set_log_level(_raop,RAOP_LOG_INFO);raop_set_log_callback(_raop,log_message,(__bridge void *)self);
    unsigned short port=7000;
    if(raop_start(_raop,&port)<0){[self stop];[self emit:@"Could not start AirPlay listener."];return NO;}
    raop_set_port(_raop,port);
    /* Stable random locally administered ID. This is not the phone's hardware address. */
    NSUserDefaults *prefs=NSUserDefaults.standardUserDefaults;
    NSData *identity=[prefs dataForKey:@"receiverID"];
    if(identity.length!=6){uint8_t b[6];arc4random_buf(b,6);b[0]=(b[0]|2)&0xfe;identity=[NSData dataWithBytes:b length:6];[prefs setObject:identity forKey:@"receiverID"];}
    int error=0;_dns=dnssd_init("ScreenLink",10,identity.bytes,6,&error);
    if(!_dns){[self stop];[self emit:@"AirPlay discovery initialization failed."];return NO;}
    raop_set_dnssd(_raop,_dns);
    sl_dnssd_set_external(_dns,self.externalDiscovery);
    if(dnssd_register_raop(_dns,port)<=0 || dnssd_register_airplay(_dns,port)<=0){[self stop];[self emit:@"Bonjour registration failed. Check Local Network permission."];return NO;}
    int txtLength=0;const char *txt=dnssd_get_airplay_txt(_dns,&txtLength);
    NSArray *airplayTXT=txtStrings(txt,txtLength);txt=sl_dnssd_get_raop_txt(_dns,&txtLength);
    NSMutableString *hex=[NSMutableString string];const uint8_t *idBytes=identity.bytes;
    for(int i=0;i<6;i++)[hex appendFormat:@"%02X",idBytes[i]];
    NSString *serviceName=self.discoveryMode==SLDiscoveryPhoneVPN?@"ScreenLink VPN Phone":@"ScreenLink VPN";
    NSString *host=self.discoveryMode==SLDiscoveryPhoneVPN?[NSString stringWithFormat:@"screenlink-%@-vpn.local.",hex.lowercaseString]:@"screenlink-vpn.local.";
    self.discoveryProfile=@{@"name":serviceName,@"host":host,@"port":@(port),@"peer":@"10.7.0.1",@"raopName":[NSString stringWithFormat:@"%@@%@",hex,serviceName],@"airplayTXT":airplayTXT,@"raopTXT":txtStrings(txt,txtLength),@"externalDiscovery":@(self.externalDiscovery),@"discoveryMode":@(self.discoveryMode)};
    if(![self startWeb]){[self stop];return NO;}
    _running=YES;
    if(self.discoveryMode==SLDiscoveryPhoneVPN)[self refreshDiscovery];
    else [self emit:self.externalDiscovery?@"Receiver ready in Mac VPN discovery mode. Start the Mac helper with your viewer link, then select ScreenLink VPN. Phone advertisements are disabled to avoid duplicates.":@"Receiver ready with native discovery. Look for ScreenLink in Screen Mirroring; same-phone discovery can vary."];
    return YES;
}
- (void)refreshDiscovery {
    if(!_running){[self emit:@"Start the receiver before refreshing discovery."];return;}
    if(self.discoveryMode!=SLDiscoveryPhoneVPN){[self emit:@"Refresh discovery applies to iPhone VPN mode. For Mac VPN mode, keep its helper running."];return;}
    if(!_vpnDiscovery){
        _vpnDiscovery=[VPNDiscovery new];__weak Receiver *weak=self;
        _vpnDiscovery.status=^(NSString *message){[weak emit:message];};
    }
    [_vpnDiscovery startWithProfile:self.discoveryProfile];
}
- (BOOL)startWeb {
    _socket=socket(AF_INET,SOCK_STREAM,0);if(_socket<0)return NO;
    int yes=1;setsockopt(_socket,SOL_SOCKET,SO_REUSEADDR,&yes,sizeof yes);
    struct sockaddr_in address={0};address.sin_len=sizeof address;address.sin_family=AF_INET;address.sin_port=htons(8080);address.sin_addr.s_addr=INADDR_ANY;
    if(bind(_socket,(struct sockaddr *)&address,sizeof address)<0 || listen(_socket,8)<0){close(_socket);_socket=-1;[self emit:@"Browser port 8080 is unavailable."];return NO;}
    int server=_socket;NSUInteger generation;@synchronized(self){generation=_generation;}
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
        while(YES) {
            BOOL current;@synchronized(self){current=generation==self->_generation;}if(!current)break;
            int client=accept(server,NULL,NULL);if(client<0)break;
            if(dispatch_semaphore_wait(self->_httpSlots,DISPATCH_TIME_NOW)!=0){close(client);continue;}
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
                @autoreleasepool {[self serveClient:client generation:generation];}
                close(client);dispatch_semaphore_signal(self->_httpSlots);
            });
        }
    });return YES;
}
- (void)serveClient:(int)client generation:(NSUInteger)generation {
    struct timeval timeout={2,0};setsockopt(client,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof timeout);setsockopt(client,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof timeout);
    int one=1;setsockopt(client,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof one);setsockopt(client,IPPROTO_TCP,TCP_NODELAY,&one,sizeof one);
    NSMutableData *request=[NSMutableData data];char buffer[1024];
    while(request.length<8192) {
        ssize_t n=recv(client,buffer,sizeof buffer,0);if(n<=0)return;[request appendBytes:buffer length:n];
        if([request rangeOfData:[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding] options:0 range:NSMakeRange(0,request.length)].location!=NSNotFound)break;
    }
    NSString *line=[[NSString alloc]initWithData:request encoding:NSUTF8StringEncoding] ?: @"";
    NSArray *parts=[line componentsSeparatedByString:@" "];NSString *target=parts.count>1?parts[1]:@"";
    NSURLComponents *url=[NSURLComponents componentsWithString:[@"http://localhost" stringByAppendingString:target]];
    NSString *token=nil;uint64_t after=0;BOOL longPoll=NO;
    for(NSURLQueryItem *item in url.queryItems){if([item.name isEqual:@"token"])token=item.value;else if([item.name isEqual:@"after"]){after=strtoull(item.value.UTF8String,NULL,10);longPoll=YES;}}
    NSString *mime=@"text/plain; charset=utf-8",*status=@"200 OK",*extra=@"";NSData *body=[NSData data];
    BOOL current;@synchronized(self){current=_generation==generation;}
    if(!current || ![parts.firstObject isEqual:@"GET"] || ![token isEqual:self.token]){status=@"403 Forbidden";body=[@"Use the complete current link from ScreenLink." dataUsingEncoding:NSUTF8StringEncoding];}
    else if([url.path isEqual:@"/discovery.json"]){mime=@"application/json";body=[NSJSONSerialization dataWithJSONObject:self.discoveryProfile ?: @{} options:0 error:NULL];}
    else if([url.path isEqual:@"/frame.jpg"]) {
        uint64_t sequence=0;CFTimeInterval captured=0;
        [_frameReady lock];NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:1.0];
        while(YES){
            @synchronized(self){current=_running && generation==_generation;sequence=_frames;captured=_frameTime;body=_jpeg ?: [NSData data];}
            if(!current || !longPoll || sequence>after || ![_frameReady waitUntilDate:deadline])break;
        }
        [_frameReady unlock];
        CFTimeInterval age=captured?MAX(0,CACurrentMediaTime()-captured):999;
        if(!current || !sequence || age>2){status=@"503 Service Unavailable";body=[NSData data];}
        else if(longPoll && sequence<=after){status=@"204 No Content";body=[NSData data];}
        mime=@"image/jpeg";extra=[NSString stringWithFormat:@"X-Frame-ID: %llu\r\nX-Frame-Age-Ms: %.0f\r\n",(unsigned long long)sequence,age*1000];
    } else if([url.path isEqual:@"/"]) {
        mime=@"text/html; charset=utf-8";
        NSString *path=[NSBundle.mainBundle pathForResource:@"Viewer" ofType:@"html"];
        body=path?[NSData dataWithContentsOfFile:path]:nil;
        if(!body){status=@"500 Internal Server Error";body=[@"Viewer resource missing" dataUsingEncoding:NSUTF8StringEncoding];}
    } else {status=@"404 Not Found";}
    NSString *header=[NSString stringWithFormat:@"HTTP/1.1 %@\r\nContent-Type: %@\r\nContent-Length: %lu\r\nCache-Control: no-store\r\nConnection: close\r\nX-Content-Type-Options: nosniff\r\n%@\r\n",status,mime,(unsigned long)body.length,extra];
    NSData *h=[header dataUsingEncoding:NSUTF8StringEncoding];if(send_all(client,h.bytes,h.length))send_all(client,body.bytes,body.length);
}
- (void)stop {
    [_vpnDiscovery stop];_vpnDiscovery=nil;
    @synchronized(self){_running=NO;_generation++;}
    [_frameReady lock];[_frameReady broadcast];[_frameReady unlock];
    if(_socket>=0){shutdown(_socket,SHUT_RDWR);close(_socket);_socket=-1;}
    if(_raop){raop_stop(_raop);raop_destroy(_raop);_raop=NULL;}
    if(_dns){dnssd_unregister_airplay(_dns);dnssd_unregister_raop(_dns);dnssd_destroy(_dns);_dns=NULL;}
    dispatch_sync(_decodeQueue,^{
        [self discardDecoder];
        if(self->_format){CFRelease(self->_format);self->_format=NULL;}
        self->_sps=nil;self->_pps=nil;self->_waitingForIDR=YES;self->_backgroundFailures=0;self->_nextDecoderAttempt=0;self->_lastDecoderErrorLog=0;self->_decoderErrors=0;
    });
    dispatch_sync(_jpegQueue,^{});
    @synchronized(self){_jpeg=nil;_frames=0;_lastJPEG=0;_frameTime=0;}
}
@end
