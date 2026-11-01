#import "Receiver.h"
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
_Static_assert(kVTInvalidSessionErr == -12903, "Check decoder error mapping against the iOS SDK");

@interface Receiver () {
    raop_t *_raop; dnssd_t *_dns;
    VTDecompressionSessionRef _decoder;
    CMVideoFormatDescriptionRef _format;
    NSData *_sps,*_pps,*_jpeg;
    CIContext *_ci;
    int _socket;
    BOOL _running;
    BOOL _previewPending;
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
- (void)emit:(NSString *)message;
- (void)receive:(NSData *)data;
- (void)image:(CVImageBufferRef)pixel;
- (void)decode:(NSData *)data;
- (BOOL)startWeb;
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
- (instancetype)init { if((self=[super init])) { _socket=-1;_ci=[CIContext contextWithOptions:nil];_decodeQueue=dispatch_queue_create("ScreenLink.decode",DISPATCH_QUEUE_SERIAL);_pendingVideo=dispatch_semaphore_create(4);_token=NSUUID.UUID.UUIDString;[self installLifecycleObservers]; } return self; }
- (BOOL)isRunning { return _running; }
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
    NSDictionary *attrs=@{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA),(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey:@{}};
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
    @autoreleasepool {
        CFTimeInterval now=CACurrentMediaTime();
        @synchronized(self) { if(now-_lastJPEG<0.1)return;_lastJPEG=now; }
        BOOL deliver=NO; NSUInteger generation;
        @synchronized(self) { generation=_generation; if(!_previewPending && self.preview){_previewPending=YES;deliver=YES;} }
        if(deliver) {
            CVPixelBufferRetain(pixel);
            dispatch_async(dispatch_get_main_queue(),^{
                BOOL current; @synchronized(self){current=self->_running && generation==self->_generation;}
                if(current && self.preview)self.preview(pixel);
                CVPixelBufferRelease(pixel);
                @synchronized(self){self->_previewPending=NO;}
            });
        }
        CIImage *im=[CIImage imageWithCVPixelBuffer:pixel];
        CGFloat scale=MIN(1.0,1280.0/MAX(im.extent.size.width,im.extent.size.height));
        im=[im imageByApplyingTransform:CGAffineTransformMakeScale(scale,scale)];
        CGColorSpaceRef cs=CGColorSpaceCreateDeviceRGB();
        NSData *jpeg=[_ci JPEGRepresentationOfImage:im colorSpace:cs options:@{(__bridge NSString *)kCGImageDestinationLossyCompressionQuality:@0.65}];CGColorSpaceRelease(cs);
        if(!jpeg.length)return;
        uint64_t frames;
        @synchronized(self) { _jpeg=jpeg;frames=++_frames; }
        if(frames==1 || frames%100==0)[self emit:[NSString stringWithFormat:@"Actual video received: %llu frames. Browser output is available.",(unsigned long long)frames]];
    }
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
    if(dnssd_register_raop(_dns,port)<=0 || dnssd_register_airplay(_dns,port)<=0){[self stop];[self emit:@"Bonjour registration failed. Check Local Network permission."];return NO;}
    if(![self startWeb]){[self stop];return NO;}
    _running=YES;
    [self emit:@"Receiver listeners started. Open Control Center → Screen Mirroring and look for ScreenLink. Discovery and same-phone connection are NOT yet verified."];
    return YES;
}
- (BOOL)startWeb {
    _socket=socket(AF_INET,SOCK_STREAM,0);if(_socket<0)return NO;
    int yes=1;setsockopt(_socket,SOL_SOCKET,SO_REUSEADDR,&yes,sizeof yes);
    struct sockaddr_in address={0};address.sin_len=sizeof address;address.sin_family=AF_INET;address.sin_port=htons(8080);address.sin_addr.s_addr=INADDR_ANY;
    if(bind(_socket,(struct sockaddr *)&address,sizeof address)<0 || listen(_socket,4)<0){close(_socket);_socket=-1;[self emit:@"Browser port 8080 is unavailable."];return NO;}
    int server=_socket;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
        while(YES) {
            int client=accept(server,NULL,NULL);if(client<0)break;
            @autoreleasepool {
                struct timeval timeout={2,0};setsockopt(client,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof timeout);setsockopt(client,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof timeout);
                int one=1;setsockopt(client,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof one);
                NSMutableData *request=[NSMutableData data];char buffer[1024];
                while(request.length<8192) {
                    ssize_t n=recv(client,buffer,sizeof buffer,0);if(n<=0)break;[request appendBytes:buffer length:n];
                    if([request rangeOfData:[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding] options:0 range:NSMakeRange(0,request.length)].location!=NSNotFound)break;
                }
                NSString *line=[[NSString alloc]initWithData:request encoding:NSUTF8StringEncoding] ?: @"";
                NSArray *parts=[line componentsSeparatedByString:@" "];
                NSString *target=parts.count>1?parts[1]:@"";
                NSURLComponents *url=[NSURLComponents componentsWithString:[@"http://localhost" stringByAppendingString:target]];
                NSString *token=nil;for(NSURLQueryItem *item in url.queryItems)if([item.name isEqual:@"token"])token=item.value;
                NSString *mime=@"text/plain; charset=utf-8",*status=@"200 OK";NSData *body;
                if(![parts.firstObject isEqual:@"GET"] || ![token isEqual:self.token]) {status=@"403 Forbidden";body=[@"Use the complete link shown in ScreenLink." dataUsingEncoding:NSUTF8StringEncoding];}
                else if([url.path isEqual:@"/frame.jpg"]) {
                    @synchronized(self){body=self->_jpeg;}
                    mime=@"image/jpeg";if(!body){status=@"503 Service Unavailable";body=[NSData data];}
                } else if([url.path isEqual:@"/"]) {
                    mime=@"text/html; charset=utf-8";
                    NSString *html=@"<!doctype html><meta name='viewport' content='width=device-width'><title>ScreenLink</title><style>body{margin:0;background:#10141c;color:white;font:16px system-ui;text-align:center}img{width:100vw;height:88vh;object-fit:contain}p{padding:12px}</style><p id='s'>Waiting for an actual AirPlay video frame…</p><img id='v' alt='Shared iPhone screen'><script>const token=new URLSearchParams(location.search).get('token');const v=document.getElementById('v'),s=document.getElementById('s');async function update(){try{const r=await fetch('/frame.jpg?token='+encodeURIComponent(token)+'&t='+Date.now(),{cache:'no-store'});if(!r.ok)throw Error();const b=await r.blob(),u=URL.createObjectURL(b),old=v.src;v.src=u;if(old.startsWith('blob:'))URL.revokeObjectURL(old);s.textContent='ScreenLink · video only';}catch(e){s.textContent='Waiting for video. Check the receiver app on the iPhone.';}setTimeout(update,100);}update();</script>";
                    body=[html dataUsingEncoding:NSUTF8StringEncoding];
                } else {status=@"404 Not Found";body=[NSData data];}
                NSString *header=[NSString stringWithFormat:@"HTTP/1.1 %@\r\nContent-Type: %@\r\nContent-Length: %lu\r\nCache-Control: no-store\r\nConnection: close\r\nX-Content-Type-Options: nosniff\r\n\r\n",status,mime,(unsigned long)body.length];
                NSData *h=[header dataUsingEncoding:NSUTF8StringEncoding];if(send_all(client,h.bytes,h.length))send_all(client,body.bytes,body.length);close(client);
            }
        }
    });return YES;
}
- (void)stop {
    @synchronized(self){_running=NO;_generation++;}
    if(_socket>=0){shutdown(_socket,SHUT_RDWR);close(_socket);_socket=-1;}
    if(_raop){raop_stop(_raop);raop_destroy(_raop);_raop=NULL;}
    if(_dns){dnssd_unregister_airplay(_dns);dnssd_unregister_raop(_dns);dnssd_destroy(_dns);_dns=NULL;}
    dispatch_sync(_decodeQueue,^{
        [self discardDecoder];
        if(self->_format){CFRelease(self->_format);self->_format=NULL;}
        self->_sps=nil;self->_pps=nil;self->_waitingForIDR=YES;self->_backgroundFailures=0;self->_nextDecoderAttempt=0;self->_lastDecoderErrorLog=0;self->_decoderErrors=0;
    });
    @synchronized(self){_jpeg=nil;_frames=0;_lastJPEG=0;}
}
@end
