#import "Receiver.h"
#import "LiveActivityBridge.h"
#import "LocalTLS.h"
#import "VPNDiscovery.h"
#import "AnnexB.h"
#import "FrameCadence.h"
#import "MJPEG.h"
#import "H264Stream.h"
#import "VideoInbox.h"
#import "HotspotLink.h"
#import "RouteProbe.h"
#import "LocalViewerApproval.h"
#import "LocalViewerHeader.h"
#import "LocalMediaToken.h"
#import "MediaCast.h"
#import "SLMediaSession.h"
#import <VideoToolbox/VideoToolbox.h>
#import <CoreMedia/CMSync.h>
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
    H264Stream *_h264,*_screenStream;
    NSMutableArray *_broadcastLog;
    NSUInteger _screenFrames;
    NSInteger _screenOrientation;
    CFTimeInterval _screenTime;
    NSTimer *_islandTimer;
    MediaCast *_media;
    LocalViewerApproval *_localViewer;
    SLMediaSession *_rtcMedia;
    VideoInbox *_inbox;
    NSUInteger _controlClients;
    BOOL _mirrorTransportOpen,_hasStreamKeyframe;
    uint64_t _disconnects,_sessionFrames;
    uint64_t _decodedFrames;
    CFTimeInterval _lastDecodedTime,_lastCompressedTime,_jpegDemandUntil;
    uint64_t _compressedFrames;
    VTDecompressionSessionRef _decoder;
    CMVideoFormatDescriptionRef _format;
    NSData *_sps,*_pps,*_jpeg;
    CIContext *_ci;
    int _socket,_httpsSocket;
    BOOL _running;
    BOOL _previewPending;
    BOOL _jpegBusy;
    dispatch_queue_t _jpegQueue;
    dispatch_semaphore_t _httpSlots,_mediaSlots;
    dispatch_semaphore_t _streamSlots;
    NSUInteger _streamClients;
    SLVideoProfile _videoProfile;
    NSCondition *_frameReady;
    CFTimeInterval _frameTime;
    CFTimeInterval _lastPreview;
    NSUInteger _generation;
    BOOL _waitingForIDR;
    BOOL _appBackgrounded;
    uint64_t _backgroundPackets;
    NSUInteger _backgroundFailures;
    CFTimeInterval _nextDecoderAttempt;
    CFTimeInterval _lastDecoderErrorLog;
    uint64_t _decoderErrors;
    id _foregroundObserver;
    id _backgroundObserver;
    uint64_t _frames;
    CFTimeInterval _nextJPEG;
    dispatch_queue_t _decodeQueue;
}
@property(nonatomic,copy,readwrite) NSString *token;
@property(nonatomic,copy,readwrite) NSDictionary *discoveryProfile;
- (void)emit:(NSString *)message;
- (BOOL)mediaRequest:(http_request_t *)request connection:(void *)connection socket:(int)socket response:(http_response_t **)response;
- (void)mediaClosed:(void *)connection;
- (void)receive:(NSData *)data timestamp:(uint64_t)timestamp;
- (void)image:(CVImageBufferRef)pixel;
- (void)decode:(NSData *)data timestamp:(uint64_t)timestamp;
- (BOOL)startWeb;
- (BOOL)startListener:(unsigned short)port context:(SSL_CTX *)context;
- (void)serveClient:(int)client generation:(NSUInteger)generation;
- (void)streamClient:(int)client generation:(NSUInteger)generation;
- (void)discardDecoder;
- (BOOL)createDecoder;
- (void)decoderFailed:(OSStatus)error;
- (void)installLifecycleObservers;
- (void)controlOpened;
- (void)controlClosed;
- (void)videoDisconnected;
- (void)resetVideo;
@end
static void log_message(void *c,int level,const char *m) {
    if(strstr(m,"raop_rtp_mirror tcp socket closed") || strstr(m,"raop_rtp_mirror error in recv"))
        [(__bridge Receiver *)c videoDisconnected];
    if(level<=RAOP_LOG_INFO) [(__bridge Receiver *)c emit:[NSString stringWithUTF8String:m] ?: @"Receiver log"];
}
int sl_media_handle(void *owner,void *connection,int socket,http_request_t *request,http_response_t **response){return [(__bridge Receiver *)owner mediaRequest:request connection:connection socket:socket response:response];}
void sl_media_closed(void *owner,void *connection){[(__bridge Receiver *)owner mediaClosed:connection];}
static void audio(void *c,raop_ntp_t *n,aac_decode_struct *d) { /* Video-only first prototype. */ }
static void flush(void *c) {}
static void connection(void *c) { [(__bridge Receiver *)c controlOpened]; }
static void disconnection(void *c) { [(__bridge Receiver *)c controlClosed]; }
static void video(void *c,raop_ntp_t *n,h264_decode_struct *d) {
    if(d->data_len>0 && d->data_len<16*1024*1024)
        [(__bridge Receiver *)c receive:[NSData dataWithBytes:d->data length:d->data_len] timestamp:d->pts];
}
static void decoded(void *c,void *source,OSStatus status,VTDecodeInfoFlags flags,CVImageBufferRef image,CMTime pts,CMTime duration) {
    if(status==noErr && image) [(__bridge Receiver *)c image:image];
}
static BOOL send_all(int fd, const void *bytes,size_t length) {
    const char *p=bytes;
    while(length) { ssize_t n=sl_tls_write(fd,p,length); if(n<=0)return NO; p+=n;length-=(size_t)n; }
    return YES;
}
static BOOL hotspotClient(int client) {
    struct sockaddr_in peer={0},local={0};socklen_t size=sizeof peer;
    if(getpeername(client,(struct sockaddr *)&peer,&size)!=0 || peer.sin_family!=AF_INET)return NO;
    size=sizeof local;if(getsockname(client,(struct sockaddr *)&local,&size)!=0 || local.sin_family!=AF_INET)return NO;
    struct ifaddrs *head=NULL;if(getifaddrs(&head)!=0)return NO;BOOL allowed=NO;
    for(struct ifaddrs *p=head;p;p=p->ifa_next){
        if(!p->ifa_addr || !p->ifa_netmask || p->ifa_addr->sa_family!=AF_INET || strncmp(p->ifa_name,"bridge",6)!=0)continue;
        struct sockaddr_in *bridge=(void *)p->ifa_addr,*mask=(void *)p->ifa_netmask;
        if(sl_hotspot_peer(peer.sin_addr.s_addr,local.sin_addr.s_addr,bridge->sin_addr.s_addr,mask->sin_addr.s_addr)){allowed=YES;break;}
    }
    freeifaddrs(head);return allowed;
}
static BOOL routeProbeClient(int client) {
    struct sockaddr_in peer={0},local={0};socklen_t size=sizeof peer;
    if(getpeername(client,(struct sockaddr *)&peer,&size)!=0 || peer.sin_family!=AF_INET)return NO;
    size=sizeof local;if(getsockname(client,(struct sockaddr *)&local,&size)!=0 || local.sin_family!=AF_INET)return NO;
    uint32_t peerIP=ntohl(peer.sin_addr.s_addr),localIP=ntohl(local.sin_addr.s_addr);
    if(sl_route_probe_peer(peerIP,localIP,0,0,0))return YES;
    struct ifaddrs *head=NULL;if(getifaddrs(&head)!=0)return NO;BOOL owned=NO,allowed=NO;
    for(struct ifaddrs *p=head;p;p=p->ifa_next)if(p->ifa_addr && p->ifa_addr->sa_family==AF_INET && ntohl(((struct sockaddr_in *)p->ifa_addr)->sin_addr.s_addr)==0xf0030303u)owned=YES;
    for(struct ifaddrs *p=head;p;p=p->ifa_next){
        if(!p->ifa_addr || !p->ifa_netmask || p->ifa_addr->sa_family!=AF_INET || strncmp(p->ifa_name,"bridge",6)!=0)continue;
        if(sl_route_probe_peer(peerIP,localIP,ntohl(((struct sockaddr_in *)p->ifa_addr)->sin_addr.s_addr),ntohl(((struct sockaddr_in *)p->ifa_netmask)->sin_addr.s_addr),owned)){allowed=YES;break;}
    }
    freeifaddrs(head);return allowed;
}
typedef struct { double fps, edge, quality; const char *name; } SLVideoSettings;
static SLVideoSettings videoSettings(SLVideoProfile profile) {
    switch(profile) {
        case SLVideoFast:return (SLVideoSettings){20,720,0.45,"Fast"};
        case SLVideoSharp:return (SLVideoSettings){15,1280,0.68,"Sharp"};
        default:return (SLVideoSettings){15,960,0.5,"Balanced"};
    }
}
@implementation Receiver
- (instancetype)init { if((self=[super init])) { _socket=-1;_httpsSocket=-1;_localViewer=[LocalViewerApproval new];_h264=[H264Stream new];_media=[MediaCast new];
#if SL_BROADCAST_EXTENSION
        _h264=[[H264Stream alloc]initWithMaxBytes:2*1024*1024 packets:90];_screenStream=[[H264Stream alloc]initWithMaxBytes:3*1024*1024 packets:120];_broadcastLog=[NSMutableArray array];_appBackgrounded=YES;_compressedOnlyInBackground=YES;
#else
        _ci=[CIContext contextWithOptions:nil];
#endif
_decodeQueue=dispatch_queue_create("ScreenLink.decode",DISPATCH_QUEUE_SERIAL);_jpegQueue=dispatch_queue_create("ScreenLink.jpeg",DISPATCH_QUEUE_SERIAL);_httpSlots=dispatch_semaphore_create(12);_mediaSlots=dispatch_semaphore_create(_screenStream?3:8);_streamSlots=dispatch_semaphore_create(2);_frameReady=[NSCondition new];_token=NSUUID.UUID.UUIDString;[self installLifecycleObservers];
        __weak Receiver *weak=self;
        _media.status=^(NSString *text){[weak emit:text];};
        _inbox=[[VideoInbox alloc]initWithQueue:_decodeQueue maxBytes:(_screenStream?2:16)*1024*1024 maxPackets:(_screenStream?30:120) consume:^(NSData *data,uint64_t timestamp,NSUInteger generation){
            Receiver *owner=weak;if(!owner)return;BOOL current;@synchronized(owner){current=owner->_running && generation==owner->_generation;}
            if(current)[owner decode:data timestamp:timestamp];
        } discontinuity:^(NSUInteger generation){
            Receiver *owner=weak;if(!owner)return;BOOL current;@synchronized(owner){current=generation==owner->_generation;}
            if(current){[owner resetVideo];[owner emit:@"Video processing overloaded. Compressed history and decoder reset; waiting for a fresh keyframe. The network thread was not blocked."];}
        }];
    } return self; }
- (H264Stream *)screenStream {return _screenStream;}
- (BOOL)screenHidden {return !_screenStream || _screenStream.privacyHidden;}
- (BOOL)changeScreenHidden:(BOOL)hidden expectedRevision:(NSUInteger)revision {if(!_screenStream)return NO;CMTime time=CMClockGetTime(CMClockGetHostTimeClock());BOOL changed=[_screenStream changePrivacyHidden:hidden notBefore:(uint64_t)(CMTimeGetSeconds(time)*1000000) expectedRevision:revision];if(changed)[self emit:hidden?@"PHONE SCREEN HIDDEN: new screen frames are blocked and cached screen history cleared. YouTube media continues.":@"PHONE SCREEN ENABLED: only show after Google Maps is open. Waiting for a fresh capture keyframe."];return changed;}
- (void)setScreenHidden:(BOOL)hidden {[self changeScreenHidden:hidden expectedRevision:[[_screenStream info][@"privacyRevision"] unsignedIntegerValue]];}
- (void)screenFrameWithOrientation:(NSInteger)orientation {@synchronized(self){_screenFrames++;_screenOrientation=orientation;_screenTime=CACurrentMediaTime();}}
- (void)broadcastMessage:(NSString *)message {[self emit:message];}
- (NSDictionary *)rtcScreenRequest:(NSString *)path request:(NSDictionary *)request {
    if(!_screenStream||!self.running)return @{@"code":@503};
    if([path isEqual:@"/screen/info"])return @{@"code":@200,@"mime":@"application/json",@"data":[NSJSONSerialization dataWithJSONObject:[self screenInfo] options:0 error:nil]};
    if([path isEqual:@"/screen/privacy"]){NSDictionary *body=request[@"body"];BOOL changed=[self changeScreenHidden:[body[@"hidden"] boolValue] expectedRevision:[body[@"expectedRevision"] unsignedIntegerValue]];return @{@"code":changed?@200:@409,@"mime":@"application/json",@"data":[NSJSONSerialization dataWithJSONObject:[self screenInfo] options:0 error:nil]};}
    NSDictionary *part=[path isEqual:@"/screen/init.mp4"]?[_screenStream initialization]:[_screenStream readAfter:[request[@"after"] unsignedLongLongValue] epoch:request[@"epoch"]?:@"" maxBytes:262144 wait:.2];NSData *bytes=part[@"data"]?:NSData.data;NSInteger code=[part[@"reset"] boolValue]?409:(bytes.length?200:204);return @{@"code":@(code),@"mime":@"video/mp4",@"data":bytes,@"epoch":part[@"epoch"]?:@"",@"lastId":part[@"id"]?:@0};
}
- (NSDictionary *)screenInfo {NSMutableDictionary *info=[[_screenStream info] mutableCopy]?:[NSMutableDictionary dictionary];@synchronized(self){info[@"frames"]=@(_screenFrames);info[@"orientation"]=@(_screenOrientation?:1);info[@"ageMs"]=@(_screenTime?(CACurrentMediaTime()-_screenTime)*1000:999999);}return info;}
- (BOOL)mediaRequest:(http_request_t *)request connection:(void *)connection socket:(int)socket response:(http_response_t **)response{return [_media handle:request connection:connection socket:socket response:response];}
- (void)mediaClosed:(void *)connection{[_media connectionClosed:connection];}
- (BOOL)isRunning { return _running; }
- (SLVideoProfile)videoProfile { @synchronized(self){return _videoProfile;} }
- (void)setVideoProfile:(SLVideoProfile)profile {
    @synchronized(self){_videoProfile=MAX(SLVideoFast,MIN(SLVideoSharp,profile));}
    SLVideoSettings settings=videoSettings(self.videoProfile);
    [self emit:[NSString stringWithFormat:@"Video profile: %s, %.0f-pixel longest edge, JPEG fallback up to %.0f fps. H.264 forwards source timing without this cap.",settings.name,settings.edge,settings.fps]];
}
- (BOOL)externalDiscovery { return self.discoveryMode!=SLDiscoveryNative; }
- (BOOL)videoIsLive { if(_media.videoIsLive)return YES;@synchronized(self){return _running && _mirrorTransportOpen && _hasStreamKeyframe && _sessionFrames>=10 && _lastCompressedTime>0 && CACurrentMediaTime()-_lastCompressedTime<2;} }
- (void)controlOpened { @synchronized(self){_controlClients++;}[self emit:@"AirPlay control connection received. Waiting for video."]; }
- (void)controlClosed { BOOL last;@synchronized(self){if(_controlClients)_controlClients--;last=_controlClients==0;}if(last)[self videoDisconnected]; }
- (void)resetVideo {
    [self discardDecoder];if(_format){CFRelease(_format);_format=NULL;}
    _sps=nil;_pps=nil;_waitingForIDR=YES;@synchronized(self){_hasStreamKeyframe=NO;_sessionFrames=0;}_nextDecoderAttempt=0;_backgroundFailures=0;[_h264 reset];
}
- (void)videoDisconnected {
    BOOL wasOpen;@synchronized(self){wasOpen=_mirrorTransportOpen;_mirrorTransportOpen=NO;_hasStreamKeyframe=NO;_lastCompressedTime=0;_sessionFrames=0;if(wasOpen)_disconnects++;}
    if(!wasOpen)return;
    [self emit:@"AIRPLAY VIDEO DISCONNECTED: the video socket closed. A background task can keep this app awake, but cannot reconnect Screen Mirroring automatically. Select ScreenLink VPN Phone again; discovery and the viewer link are retained."];
    dispatch_async(_decodeQueue,^{[self resetVideo];});
}
- (void)emit:(NSString *)s { if(_broadcastLog){@synchronized(self){[_broadcastLog addObject:[NSString stringWithFormat:@"%@ %@",NSDate.date,s]];while(_broadcastLog.count>60)[_broadcastLog removeObjectAtIndex:0];}} dispatch_async(dispatch_get_main_queue(),^{ if(self.status)self.status(s); }); }
- (void)installLifecycleObservers {
#if !SL_BROADCAST_EXTENSION
    __weak Receiver *weak=self;
    _backgroundObserver=[NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){
        Receiver *owner=weak;if(!owner)return;
        dispatch_async(owner->_decodeQueue,^{owner->_appBackgrounded=YES;owner->_backgroundPackets=0;owner->_backgroundFailures=0;});
    }];
    _foregroundObserver=[NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){
        Receiver *owner=weak;if(!owner)return;
        dispatch_async(owner->_decodeQueue,^{
            owner->_appBackgrounded=NO;owner->_backgroundFailures=0;owner->_nextDecoderAttempt=0;
            if(owner->_running && owner->_waitingForIDR)[owner emit:@"App active again. Decoder recovery will resume at the next H.264 keyframe; the browser may hold its last image until then."];
        });
    }];
#endif
}
- (void)receive:(NSData *)data timestamp:(uint64_t)timestamp {
    NSUInteger generation;@synchronized(self){generation=_generation;_mirrorTransportOpen=YES;}
    [_inbox offer:data timestamp:timestamp generation:generation];
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
- (void)decode:(NSData *)data timestamp:(uint64_t)timestamp {
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
        CMVideoDimensions dimensions=CMVideoFormatDescriptionGetDimensions(_format);
        [_h264 configureSPS:_sps PPS:_pps width:(uint16_t)dimensions.width height:(uint16_t)dimensions.height];
        [self emit:@"H.264 configuration received. Waiting for a keyframe."];
    }
    if(!_format || !hasVCL || !avcc.length)return;
    uint64_t sessionFrames;@synchronized(self){if(hasIDR)_hasStreamKeyframe=YES;_lastCompressedTime=CACurrentMediaTime();_compressedFrames++;sessionFrames=++_sessionFrames;}
    if(sessionFrames==10)[self emit:@"AIRPLAY VIDEO LIVE: 10 fresh frames received. You can now request the background test. Verify motion in the browser first."];
    [_h264 appendAVCC:avcc timestamp:timestamp ?: (uint64_t)(CACurrentMediaTime()*1000000) keyframe:hasIDR];
    if(_appBackgrounded && self.compressedOnlyInBackground){
        _backgroundPackets++;
        if(_backgroundPackets==30 || _backgroundPackets%300==0)[self emit:[NSString stringWithFormat:@"BACKGROUND H.264 VERIFIED: %llu packets forwarded after leaving ScreenLink. No local video decoding or JPEG encoding on this path.",(unsigned long long)_backgroundPackets]];
        _waitingForIDR=YES;return;
    }
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
    BOOL deliver=NO, encode=NO;NSUInteger generation;SLVideoSettings settings;
    @synchronized(self) {
        if(!_running)return;
        generation=_generation;settings=videoSettings(_videoProfile);_decodedFrames++;_lastDecodedTime=now;
        if(!_previewPending && self.preview && now-_lastPreview>=1.0/15.0){_lastPreview=now;_previewPending=YES;deliver=YES;}
        // Drop rendered output under pressure, never build a JPEG work backlog.
        if((_streamClients || now<_jpegDemandUntil) && !_jpegBusy && sl_frame_due(now,settings.fps,&_nextJPEG)){_jpegBusy=YES;encode=YES;}
    }
    uint64_t decodedCount;@synchronized(self){decodedCount=_decodedFrames;}
    if(decodedCount==1 || decodedCount%300==0)[self emit:[NSString stringWithFormat:@"Actual decoded video: %llu frames. H.264 passthrough is available; JPEG conversion runs only for fallback viewers.",(unsigned long long)decodedCount]];
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
            CGFloat scale=MIN(1.0,settings.edge/MAX(im.extent.size.width,im.extent.size.height));
            im=[im imageByApplyingTransform:CGAffineTransformMakeScale(scale,scale)];
            CGColorSpaceRef cs=CGColorSpaceCreateDeviceRGB();
            NSData *jpeg=[self->_ci JPEGRepresentationOfImage:im colorSpace:cs options:@{(__bridge NSString *)kCGImageDestinationLossyCompressionQuality:@(settings.quality)}];
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
- (NSDictionary *)liveActivitySnapshot {
    BOOL running=self.running;
    NSDictionary *media=[_media state];
    BOOL active=[media[@"active"] boolValue];
    BOOL paused=[media[@"paused"] boolValue];
    BOOL streaming=active && [media[@"ready"] boolValue] && !paused;
    BOOL approved=[[_localViewer statusAt:NSProcessInfo.processInfo.systemUptime][@"phase"] isEqual:@"approved"];
    NSString *status=streaming?@"AirPlay active":(active&&paused?@"Media paused":(approved?@"Viewer approved":@"Ready for viewer"));
    return @{@"running":@(running),@"status":status,@"screenVisible":@(!self.screenHidden),@"streaming":@(streaming)};
}
- (void)publishIslandStatus {
    SLPublishLiveActivity([self liveActivitySnapshot],NO);
}
- (BOOL)start {
    if(_running)return YES;
    @synchronized(self){_generation++;}
    NSString *saved=[NSUserDefaults.standardUserDefaults stringForKey:@"viewerToken"];
    if(!saved.length){saved=NSUUID.UUID.UUIDString;[NSUserDefaults.standardUserDefaults setObject:saved forKey:@"viewerToken"];}
    _token=saved;_media.token=saved;
    raop_callbacks_t cb={0};cb.cls=(__bridge void *)self;cb.audio_process=audio;cb.video_process=video;cb.video_flush=flush;cb.audio_flush=flush;cb.conn_init=connection;cb.conn_destroy=disconnection;
    _raop=raop_init(8,&cb);if(!_raop){[self emit:@"Receiver initialization failed."];return NO;}
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
    NSMutableString *mediaID=[NSMutableString string];for(int i=0;i<6;i++)[mediaID appendFormat:i?@":%02X":@"%02X",idBytes[i]];_media.deviceID=mediaID;
    NSString *serviceName=self.discoveryMode==SLDiscoveryPhoneVPN?@"ScreenLink VPN Phone":@"ScreenLink VPN";
    NSString *host=self.discoveryMode==SLDiscoveryPhoneVPN?[NSString stringWithFormat:@"screenlink-%@-vpn.local.",hex.lowercaseString]:@"screenlink-vpn.local.";
    self.discoveryProfile=@{@"name":serviceName,@"host":host,@"port":@(port),@"peer":@"10.7.0.1",@"raopName":[NSString stringWithFormat:@"%@@%@",hex,serviceName],@"airplayTXT":airplayTXT,@"raopTXT":txtStrings(txt,txtLength),@"externalDiscovery":@(self.externalDiscovery),@"discoveryMode":@(self.discoveryMode)};
    if(![self startWeb]){[self stop];return NO;}
    _running=YES;
    NSUInteger islandGeneration=_generation;
    dispatch_async(dispatch_get_main_queue(),^{
        if(!self->_running || self->_generation!=islandGeneration)return;
        [self->_islandTimer invalidate];
        __weak Receiver *weak=self;
        self->_islandTimer=[NSTimer scheduledTimerWithTimeInterval:5 repeats:YES block:^(NSTimer *timer){[weak publishIslandStatus];}];
        [self publishIslandStatus];
    });
    if(self.discoveryMode==SLDiscoveryPhoneVPN)[self refreshDiscovery];
    else [self emit:self.externalDiscovery?@"Receiver ready in Mac VPN discovery mode. Start the Mac helper with your viewer link, then select ScreenLink VPN. Phone advertisements are disabled to avoid duplicates.":@"Receiver ready with native discovery. Look for ScreenLink in Screen Mirroring; same-phone discovery can vary."];
    return YES;
}
- (void)refreshDiscovery {
    if(!_running){[self emit:@"Start the receiver before refreshing discovery."];return;}
    BOOL busy;@synchronized(self){busy=_controlClients>0 || _mirrorTransportOpen;}
    if(busy){[self emit:@"Discovery kept unchanged: AirPlay is connecting or connected. Refreshing now could interrupt the session."];return;}
    if(self.discoveryMode!=SLDiscoveryPhoneVPN){[self emit:@"Refresh discovery applies to iPhone VPN mode. For Mac VPN mode, keep its helper running."];return;}
    if(!_vpnDiscovery){
        _vpnDiscovery=[VPNDiscovery new];__weak Receiver *weak=self;
        _vpnDiscovery.status=^(NSString *message){[weak emit:message];};
    }
    [_vpnDiscovery startWithProfile:self.discoveryProfile];
}
- (BOOL)startWeb {
    if(![self startListener:8080 context:NULL])return NO;
    NSString *directory=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"PrivateTLS"];
    SSL_CTX *context=sl_tls_context([[directory stringByAppendingPathComponent:@"fullchain.pem"] fileSystemRepresentation],[[directory stringByAppendingPathComponent:@"private.key"] fileSystemRepresentation]);
    if(context){if([self startListener:443 context:context])[self emit:@"LOCAL HTTPS READY: https://car.tesla4khmer.com/ — approve the viewer on this phone. Open /capabilities to check browser APIs."];else [self emit:@"HTTPS port 443 unavailable. HTTP viewer remains available."];SSL_CTX_free(context);}
    else [self emit:@"Local HTTPS not started: certificate missing, expired, wrong hostname or mismatched key. HTTP viewer remains available."];
    return YES;
}
- (BOOL)startListener:(unsigned short)port context:(SSL_CTX *)context {
    int server=socket(AF_INET,SOCK_STREAM,0);if(server<0)return NO;
    int yes=1;setsockopt(server,SOL_SOCKET,SO_REUSEADDR,&yes,sizeof yes);
    struct sockaddr_in address={0};address.sin_len=sizeof address;address.sin_family=AF_INET;address.sin_port=htons(port);address.sin_addr.s_addr=INADDR_ANY;
    if(bind(server,(struct sockaddr *)&address,sizeof address)<0 || listen(server,8)<0){close(server);return NO;}
    if(context)_httpsSocket=server;else _socket=server;
    NSUInteger generation;@synchronized(self){generation=_generation;}
    if(context)SSL_CTX_up_ref(context);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
        while(YES) {
            BOOL current;@synchronized(self){current=generation==self->_generation;}if(!current)break;
            int client=accept(server,NULL,NULL);if(client<0)break;
            if(dispatch_semaphore_wait(self->_httpSlots,DISPATCH_TIME_NOW)!=0){close(client);continue;}
            if(context)SSL_CTX_up_ref(context);
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
                struct timeval timeout={5,0};setsockopt(client,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof timeout);setsockopt(client,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof timeout);
                int one=1;setsockopt(client,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof one);
                @try {@autoreleasepool {if(!context || sl_tls_begin(context,client))[self serveClient:client generation:generation];}}
                @finally {if(context){sl_tls_end();SSL_CTX_free(context);}close(client);dispatch_semaphore_signal(self->_httpSlots);}
            });
        }
        if(context)SSL_CTX_free(context);
    });return YES;
}
- (void)serveClient:(int)client generation:(NSUInteger)generation {
    struct timeval timeout={2,0};setsockopt(client,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof timeout);setsockopt(client,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof timeout);
    int one=1;setsockopt(client,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof one);setsockopt(client,IPPROTO_TCP,TCP_NODELAY,&one,sizeof one);
    NSMutableData *request=[NSMutableData data];char buffer[1024];
    while(request.length<8192) {
        ssize_t n=sl_tls_read(client,buffer,sizeof buffer);if(n<=0)return;[request appendBytes:buffer length:n];
        if([request rangeOfData:[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding] options:0 range:NSMakeRange(0,request.length)].location!=NSNotFound)break;
    }
    NSString *line=[[NSString alloc]initWithData:request encoding:NSUTF8StringEncoding] ?: @"";
    NSArray *parts=[line componentsSeparatedByString:@" "];NSString *target=parts.count>1?parts[1]:@"";
    NSURLComponents *url=[NSURLComponents componentsWithString:[@"http://localhost" stringByAppendingString:target]];
    NSString *token=nil,*epoch=nil;uint64_t after=0;BOOL longPoll=NO;
    for(NSURLQueryItem *item in url.queryItems){if([item.name isEqual:@"epoch"])epoch=item.value;else if([item.name isEqual:@"token"])token=item.value;else if([item.name isEqual:@"after"]){after=strtoull(item.value.UTF8String,NULL,10);longPoll=YES;}}
    NSString *mime=@"text/plain; charset=utf-8",*status=@"200 OK",*extra=@"";NSData *body=[NSData data];
    NSRange headerEnd=[request rangeOfData:[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding] options:0 range:NSMakeRange(0,request.length)];
    NSUInteger bodyOffset=headerEnd.location==NSNotFound?request.length:NSMaxRange(headerEnd);NSUInteger bodyLength=0;NSString *byteRange=nil,*origin=nil,*host=nil;BOOL localControl=NO,viewerHeaderValid=NO;
    for(NSString *field in [line componentsSeparatedByString:@"\r\n"]){
        if([field.lowercaseString hasPrefix:@"host:"])host=[[[field substringFromIndex:5] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] lowercaseString];
        if([field.lowercaseString hasPrefix:@"x-screenlink-control:"] && [[[field substringFromIndex:21] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] isEqual:@"app"])localControl=YES;
        if([field.lowercaseString hasPrefix:@"content-length:"])bodyLength=(NSUInteger)MAX(0,[[field substringFromIndex:15] integerValue]);
        if([field.lowercaseString hasPrefix:@"origin:"])origin=[[field substringFromIndex:7] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if([field.lowercaseString hasPrefix:@"x-screenlink-viewer:"])viewerHeaderValid=sl_local_viewer_request_header(field.UTF8String);
        if([field.lowercaseString hasPrefix:@"range:"])byteRange=[[field substringFromIndex:6] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    }
    BOOL secureTransport=sl_tls_active(client);
    if(secureTransport && ![@[@"car.tesla4khmer.com",@"car.tesla4khmer.com:443"] containsObject:host])return;
    NSString *expectedOrigin=secureTransport?@"https://car.tesla4khmer.com":@"http://240.3.3.3:8080";
    if(bodyLength>8192)return;
    while(request.length-bodyOffset<bodyLength){ssize_t n=sl_tls_read(client,buffer,MIN(sizeof buffer,bodyLength-(request.length-bodyOffset)));if(n<=0)return;[request appendBytes:buffer length:n];}
    struct sockaddr_in peer={0};socklen_t peerSize=sizeof peer;BOOL loopback=getpeername(client,(struct sockaddr *)&peer,&peerSize)==0 && peer.sin_family==AF_INET && (ntohl(peer.sin_addr.s_addr)>>24)==127;
    BOOL localOwner=loopback && localControl && [parts.firstObject isEqual:@"GET"] && [url.path isEqual:@"/local/owner"];
    BOOL localStop=loopback && localControl && [parts.firstObject isEqual:@"POST"] && [url.path isEqual:@"/local/broadcast/stop"];
    BOOL localRTC=loopback&&localControl&&[url.path hasPrefix:@"/local/rtc/"]&&_screenStream!=nil&&([parts.firstObject isEqual:@"GET"]||[parts.firstObject isEqual:@"POST"]);
    struct sockaddr_in localEndpoint={0};socklen_t localSize=sizeof localEndpoint;
    BOOL aliasDestination=getsockname(client,(struct sockaddr *)&localEndpoint,&localSize)==0 && localEndpoint.sin_family==AF_INET && ntohl(localEndpoint.sin_addr.s_addr)==0xf0030303u;
    BOOL aliasClient=aliasDestination && _screenStream && routeProbeClient(client);
    char peerAddress[INET_ADDRSTRLEN]={0};inet_ntop(AF_INET,&peer.sin_addr,peerAddress,sizeof peerAddress);NSString *peerHost=[NSString stringWithUTF8String:peerAddress];
    NSTimeInterval localNow=NSProcessInfo.processInfo.systemUptime;
    BOOL localViewerControl=loopback && localControl && [parts.firstObject isEqual:@"POST"] && [url.path isEqual:@"/local/viewer/decision"];
    BOOL privacy=[parts.firstObject isEqual:@"POST"] && [url.path isEqual:@"/screen/privacy"];
    BOOL report=[parts.firstObject isEqual:@"POST"] && [url.path isEqual:@"/media/report"];
    BOOL current;@synchronized(self){current=_generation==generation;}
    if(current && localViewerControl){
        id object=[NSJSONSerialization JSONObjectWithData:[request subdataWithRange:NSMakeRange(bodyOffset,bodyLength)] options:0 error:nil];
        NSString *action=[object isKindOfClass:NSDictionary.class]?object[@"action"]:nil;BOOL changed=NO;
        if([action isEqual:@"disconnect"]){[_localViewer reset];[self setScreenHidden:YES];changed=YES;[self emit:@"LOCAL VIEWER DISCONNECTED: alias media authorization revoked; phone screen hidden."];}
        else if([action isEqual:@"approve"]||[action isEqual:@"reject"]){changed=[_localViewer decide:[action isEqual:@"approve"] requestID:object[@"requestID"] now:localNow];if(changed){[self setScreenHidden:YES];[self emit:[action isEqual:@"approve"]?@"LOCAL VIEWER APPROVED: experimental HTTP media enabled for this hotspot client; phone screen starts hidden. Tesla playback is not yet verified.":@"LOCAL VIEWER REJECTED: no alias media access granted."];}}
        status=changed?@"200 OK":@"409 Conflict";mime=@"application/json";body=[@"{}" dataUsingEncoding:NSUTF8StringEncoding];
    }
    else if(current && [url.path isEqual:@"/local-viewer/request"]){
        if(!aliasClient || ![parts.firstObject isEqual:@"POST"] || ![origin isEqual:expectedOrigin] || !viewerHeaderValid){status=@"403 Forbidden";[self emit:[NSString stringWithFormat:@"LOCAL APPROVAL REQUEST REJECTED: owned-alias/hotspot=%d, POST=%d, expected-origin=%d, request-header=%d. No media access granted.",aliasClient,[parts.firstObject isEqual:@"POST"],[origin isEqual:expectedOrigin],viewerHeaderValid]];}
        else{id object=[NSJSONSerialization JSONObjectWithData:[request subdataWithRange:NSMakeRange(bodyOffset,bodyLength)] options:0 error:nil];NSString *nonce=[object isKindOfClass:NSDictionary.class]?object[@"nonce"]:nil;NSDictionary *result=[_localViewer request:nonce peer:peerHost now:localNow];mime=@"application/json";body=[NSJSONSerialization dataWithJSONObject:result options:0 error:nil];}
    }
    else if(current && aliasClient && [parts.firstObject isEqual:@"GET"] && [url.path isEqual:@"/capabilities"]){mime=@"text/html; charset=utf-8";body=[NSData dataWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"Capabilities" ofType:@"html"]]?:NSData.data;}
    else if(current && aliasClient && [parts.firstObject isEqual:@"GET"] && !token && [@[@"/",@"/split",@"/map",@"/video"] containsObject:url.path]){
        mime=@"text/html; charset=utf-8";NSString *path=[NSBundle.mainBundle pathForResource:@"LocalViewer" ofType:@"html"];body=path?[NSData dataWithContentsOfFile:path]:NSData.data;
    }
    else if(current && [parts.firstObject isEqual:@"GET"] && ([url.path isEqual:@"/"] || [url.path isEqual:@"/video"] || [url.path isEqual:@"/split"] || [url.path isEqual:@"/map"]) && !token && hotspotClient(client)){
        status=@"302 Found";
        extra=[NSString stringWithFormat:@"Location: %@?token=%@\r\nReferrer-Policy: no-referrer\r\n",url.path,self.token];
    }
    else if(current && [parts.firstObject isEqual:@"GET"] && [url.path isEqual:@"/local-route-probe"]){
        extra=@"X-Content-Type-Options: nosniff\r\nReferrer-Policy: no-referrer\r\n";
        if(!routeProbeClient(client)){status=@"403 Forbidden";body=[@"Route probe unavailable for this source." dataUsingEncoding:NSUTF8StringEncoding];}
        else{
            struct sockaddr_in local={0};socklen_t size=sizeof local;getsockname(client,(struct sockaddr *)&local,&size);
            char localText[INET_ADDRSTRLEN]={0},peerText[INET_ADDRSTRLEN]={0};inet_ntop(AF_INET,&local.sin_addr,localText,sizeof localText);inet_ntop(AF_INET,&peer.sin_addr,peerText,sizeof peerText);
            NSString *message=[NSString stringWithFormat:@"LOCAL TCP PROBE REACHED\nBuild: %@ (%@)\nPhone endpoint: %s:%u\nObserved client: %s:%u\nThis proves only this TCP request reached ScreenLink. Video, HTTPS and UDP are not verified. No screen or media is returned.\n",NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]?:@"unknown",NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]?:@"unknown",localText,ntohs(local.sin_port),peerText,ntohs(peer.sin_port)];
            body=[message dataUsingEncoding:NSUTF8StringEncoding];[self emit:message];
        }
    }
    else if(current && localOwner){mime=@"application/json";NSDictionary *owner;@synchronized(self){owner=@{@"broadcast":@(_screenStream!=nil),@"running":@(_running),@"frames":@(_screenFrames),@"token":self.token,@"logs":_broadcastLog.copy?:@[],@"localViewer":[_localViewer statusAt:localNow],@"island":[self liveActivitySnapshot]};}body=[NSJSONSerialization dataWithJSONObject:owner options:0 error:NULL];}
    else if(current&&localRTC){__block NSDictionary *result;NSString *command=[url.path substringFromIndex:11];BOOL allowed=([parts.firstObject isEqual:@"GET"]&&[command isEqual:@"status"])||([parts.firstObject isEqual:@"POST"]&&[@[@"start",@"approve",@"reject",@"stop"] containsObject:command]);if(!allowed){status=@"405 Method Not Allowed";}else{dispatch_sync(dispatch_get_main_queue(),^{if(!self->_rtcMedia&&[command isEqual:@"start"]){self->_rtcMedia=[[SLMediaSession alloc]initWithMedia:self->_media];__weak Receiver *weak=self;self->_rtcMedia.status=^(NSString *message){[weak emit:message];};self->_rtcMedia.screenProvider=^NSDictionary *(NSString *path,NSDictionary *request){return [weak rtcScreenRequest:path request:request]?:@{@"code":@503};};}result=self->_rtcMedia?[self->_rtcMedia control:command]:@{@"phase":@"idle",@"approvalRequested":@NO,@"events":@[]};});mime=@"application/json";body=[NSJSONSerialization dataWithJSONObject:result options:0 error:nil];}}
    else if(current && localStop && _screenStream){mime=@"application/json";body=[@"{}" dataUsingEncoding:NSUTF8StringEncoding];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_MSEC*250),dispatch_get_main_queue(),^{if(self.broadcastStop)self.broadcastStop();});}
    else if(!current || (![parts.firstObject isEqual:@"GET"] && !report && !privacy) || !(aliasDestination?(aliasClient && [_localViewer allowsToken:token peer:peerHost now:localNow]):[token isEqual:self.token])){status=@"403 Forbidden";body=[(aliasDestination?@"Open http://240.3.3.3:8080/ and request approval on the iPhone.":@"On the iPhone hotspot, open http://172.20.10.1:8080/ . On other Wi-Fi, use the complete viewer link from ScreenLink.") dataUsingEncoding:NSUTF8StringEncoding];}
    else if(privacy){NSData *json=[request subdataWithRange:NSMakeRange(bodyOffset,bodyLength)];id object=[NSJSONSerialization JSONObjectWithData:json options:0 error:NULL];id value=[object isKindOfClass:NSDictionary.class]?object[@"hidden"]:nil;if(!_screenStream){status=@"409 Conflict";}else if(!value || CFGetTypeID((__bridge CFTypeRef)value)!=CFBooleanGetTypeID()){status=@"400 Bad Request";}else{if(![self changeScreenHidden:[value boolValue] expectedRevision:[object[@"expectedRevision"] unsignedIntegerValue]])status=@"409 Conflict";mime=@"application/json";body=[NSJSONSerialization dataWithJSONObject:[self screenInfo] options:0 error:NULL];}}
    else if([url.path isEqual:@"/screen/info"]){mime=@"application/json";body=[NSJSONSerialization dataWithJSONObject:[self screenInfo] options:0 error:NULL];}
    else if([url.path isEqual:@"/screen/init.mp4"]){NSDictionary *part=[_screenStream initialization];body=part[@"data"]?:NSData.data;mime=@"video/mp4";extra=[NSString stringWithFormat:@"X-Stream-Epoch: %@\r\n",part[@"epoch"]?:@""];if(!body.length)status=@"503 Service Unavailable";}
    else if([url.path isEqual:@"/screen/segments"]){NSDictionary *part=[_screenStream readAfter:after epoch:epoch?:@""];if([part[@"reset"] boolValue])status=@"409 Conflict";else{body=part[@"data"]?:NSData.data;if(!body.length)status=@"204 No Content";}mime=@"video/mp4";extra=[NSString stringWithFormat:@"X-Stream-Epoch: %@\r\nX-Last-ID: %@\r\n",part[@"epoch"]?:@"",part[@"id"]?:@0];}
    else if([url.path isEqual:@"/split"] || [url.path isEqual:@"/map"]){mime=@"text/html; charset=utf-8";NSString *path=[NSBundle.mainBundle pathForResource:[url.path isEqual:@"/split"]?@"SplitViewer":@"MapPlayer" ofType:@"html"];body=path?[NSData dataWithContentsOfFile:path]:NSData.data;}
    else if([url.path isEqual:@"/media/state"]){mime=@"application/json";body=[NSJSONSerialization dataWithJSONObject:[_media state] options:0 error:NULL];}
    else if(report){
        NSData *json=[request subdataWithRange:NSMakeRange(bodyOffset,bodyLength)];id object=[NSJSONSerialization JSONObjectWithData:json options:0 error:NULL];
        if([object isKindOfClass:NSDictionary.class]){[_media report:object];mime=@"application/json";body=[@"{}" dataUsingEncoding:NSUTF8StringEncoding];}else status=@"400 Bad Request";
    }
    else if([url.path hasPrefix:@"/media/resource/"]){
        NSDictionary *part;if(dispatch_semaphore_wait(_mediaSlots,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC)))part=@{@"code":@503};else{@try{part=[_media resource:[url.path substringFromIndex:16] range:byteRange];}@finally{dispatch_semaphore_signal(_mediaSlots);}}NSInteger code=[part[@"code"] integerValue];
        status=[NSString stringWithFormat:@"%ld %@",(long)code,code==200?@"OK":(code==206?@"Partial Content":@"Media Request Failed")];mime=part[@"mime"]?:@"text/plain";body=part[@"data"]?:[NSData data];if(part[@"range"])extra=[NSString stringWithFormat:@"Content-Range: %@\r\n",part[@"range"]];
    }
    else if([url.path isEqual:@"/video"] || [@[@"/media/hls.js",@"/media/canvas.js",@"/media/mp4box.js",@"/media/mux.js"] containsObject:url.path]){
        BOOL script=[url.path hasSuffix:@".js"];NSDictionary *scripts=@{@"/media/hls.js":@"HLSPlayer",@"/media/canvas.js":@"CanvasPlayer",@"/media/mp4box.js":@"MP4Demux",@"/media/mux.js":@"TSDemux"};NSString *path=[NSBundle.mainBundle pathForResource:script?scripts[url.path]:@"MediaPlayer" ofType:script?@"js":@"html"];
        mime=script?@"application/javascript":@"text/html; charset=utf-8";body=path?[NSData dataWithContentsOfFile:path]:nil;if(!body){status=@"503 Service Unavailable";body=[NSData data];}
    }
    else if([url.path isEqual:@"/h264/info"]){mime=@"application/json";body=[NSJSONSerialization dataWithJSONObject:[_h264 info] options:0 error:NULL];}
    else if([url.path isEqual:@"/h264/init.mp4"]){NSDictionary *part=[_h264 initialization];body=part[@"data"];mime=@"video/mp4";extra=[NSString stringWithFormat:@"X-Stream-Epoch: %@\r\n",part[@"epoch"]];if(!body.length)status=@"503 Service Unavailable";}
    else if([url.path isEqual:@"/h264/segments"]) {
        NSDictionary *part=[_h264 readAfter:after epoch:epoch ?: @""];
        if([part[@"reset"] boolValue])status=@"409 Conflict";
        else {body=part[@"data"];if(!body.length)status=@"204 No Content";}
        mime=@"video/mp4";extra=[NSString stringWithFormat:@"X-Stream-Epoch: %@\r\nX-Last-ID: %@\r\n",part[@"epoch"],part[@"id"] ?: @0];
    }
    else if([url.path isEqual:@"/stream.mjpg"]){if(secureTransport){status=@"501 Not Implemented";body=[@"Use the MP4 screen viewer on HTTPS." dataUsingEncoding:NSUTF8StringEncoding];}else{[self streamClient:client generation:generation];return;}}
    else if([url.path isEqual:@"/status.json"]) {
        NSDictionary *snapshot;
        @synchronized(self){
            SLVideoSettings settings=videoSettings(_videoProfile);
            double age=_lastDecodedTime?MAX(0,CACurrentMediaTime()-_lastDecodedTime)*1000:999999;
            snapshot=@{@"mediaActive":@(_media.active),@"appBackgrounded":@(_appBackgrounded),@"compressedOnlyInBackground":@(self.compressedOnlyInBackground),@"backgroundPackets":@(_backgroundPackets),@"mirrorConnected":@(_mirrorTransportOpen),@"disconnects":@(_disconnects),@"sessionFrames":@(_sessionFrames),@"running":@(_running),@"frames":@(_decodedFrames),@"jpegFrames":@(_frames),@"h264Frames":@(_compressedFrames),@"compressedAgeMs":@(_lastCompressedTime?MAX(0,CACurrentMediaTime()-_lastCompressedTime)*1000:999999),@"frameAgeMs":@(age),@"profile":[NSString stringWithUTF8String:settings.name],@"maxFPS":@(settings.fps),@"streamClients":@(_streamClients)};
        }
        mime=@"application/json";body=[NSJSONSerialization dataWithJSONObject:snapshot options:0 error:NULL];
    }
    else if([url.path isEqual:@"/discovery.json"]){mime=@"application/json";body=[NSJSONSerialization dataWithJSONObject:self.discoveryProfile ?: @{} options:0 error:NULL];}
    else if([url.path isEqual:@"/frame.jpg"]) {
        @synchronized(self){_jpegDemandUntil=CACurrentMediaTime()+3;}
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
        NSString *path=[NSBundle.mainBundle pathForResource:_screenStream?@"SplitViewer":@"Viewer" ofType:@"html"];
        body=path?[NSData dataWithContentsOfFile:path]:nil;
        if(!body){status=@"500 Internal Server Error";body=[@"Viewer resource missing" dataUsingEncoding:NSUTF8StringEncoding];}
    } else {status=@"404 Not Found";}
    if(aliasClient && ([url.path isEqual:@"/media/state"] || [url.path hasPrefix:@"/media/resource/"]))body=SLRetokenLocalMediaData(body,mime,self.token,token);
    NSString *header=[NSString stringWithFormat:@"HTTP/1.1 %@\r\nContent-Type: %@\r\nContent-Length: %lu\r\nCache-Control: no-store\r\nConnection: close\r\nX-Content-Type-Options: nosniff\r\n%@\r\n",status,mime,(unsigned long)body.length,extra];
    NSData *h=[header dataUsingEncoding:NSUTF8StringEncoding];if(send_all(client,h.bytes,h.length))send_all(client,body.bytes,body.length);
}
- (void)streamClient:(int)client generation:(NSUInteger)generation {
    if(dispatch_semaphore_wait(_streamSlots,DISPATCH_TIME_NOW)!=0) {
        const char *busy="HTTP/1.1 429 Too Many Requests\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
        send_all(client,busy,strlen(busy));return;
    }
    @synchronized(self){_streamClients++;}
    @try {
        int bytes=65536;setsockopt(client,SOL_SOCKET,SO_SNDBUF,&bytes,sizeof bytes);
        struct timeval timeout={1,0};setsockopt(client,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof timeout);
        if(!sl_mjpeg_begin(client))return;
        uint64_t sent=0;
        while(YES) {
            NSData *frame=nil;uint64_t sequence=0;BOOL current;double age;
            [_frameReady lock];
            while(YES) {
                @synchronized(self){current=_running && generation==_generation;sequence=_frames;age=_frameTime?CACurrentMediaTime()-_frameTime:999;frame=_jpeg;}
                if(!current || (sequence>sent && frame.length && age<2))break;
                if(![_frameReady waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]])break;
            }
            [_frameReady unlock];
            if(!current)break;
            char probe;ssize_t connected=recv(client,&probe,1,MSG_PEEK|MSG_DONTWAIT);
            if(connected==0 || (connected<0 && errno!=EAGAIN && errno!=EWOULDBLOCK && errno!=EINTR))break;
            if(sequence<=sent || !frame.length || age>=2)continue;
            // At most one JPEG is in flight. Each iteration selects the newest
            // frame; slow clients cannot build an application-level backlog.
            if(!sl_mjpeg_frame(client,frame.bytes,frame.length,sequence))break;
            sent=sequence;
        }
    } @finally {
        @synchronized(self){_streamClients--;}
        dispatch_semaphore_signal(_streamSlots);
    }
}
- (void)stop {
    BOOL islandWasRunning=_running;
    dispatch_async(dispatch_get_main_queue(),^{
        if(!self->_running){[self->_islandTimer invalidate];self->_islandTimer=nil;}
    });
    if(islandWasRunning)SLPublishLiveActivity(@{@"running":@NO},NO);
    void (^closeRTC)(void)=^{[self->_rtcMedia stop];self->_rtcMedia=nil;};if(NSThread.isMainThread)closeRTC();else dispatch_sync(dispatch_get_main_queue(),closeRTC);
    [_localViewer reset];[_screenStream reset];[_media stop];[_vpnDiscovery stop];_vpnDiscovery=nil;[_h264 reset];
    @synchronized(self){_running=NO;_generation++;_mirrorTransportOpen=NO;_sessionFrames=0;_controlClients=0;}
    [_frameReady lock];[_frameReady broadcast];[_frameReady unlock];
    if(_httpsSocket>=0){shutdown(_httpsSocket,SHUT_RDWR);close(_httpsSocket);_httpsSocket=-1;}
    if(_socket>=0){shutdown(_socket,SHUT_RDWR);close(_socket);_socket=-1;}
    if(_raop){raop_stop(_raop);raop_destroy(_raop);_raop=NULL;}
    if(_dns){dnssd_unregister_airplay(_dns);dnssd_unregister_raop(_dns);dnssd_destroy(_dns);_dns=NULL;}
    dispatch_sync(_decodeQueue,^{
        [self discardDecoder];
        if(self->_format){CFRelease(self->_format);self->_format=NULL;}
        self->_sps=nil;self->_pps=nil;self->_waitingForIDR=YES;self->_backgroundFailures=0;self->_nextDecoderAttempt=0;self->_lastDecoderErrorLog=0;self->_decoderErrors=0;
    });
    dispatch_sync(_jpegQueue,^{});
    [_h264 reset];
    @synchronized(self){_jpeg=nil;_frames=0;_nextJPEG=0;_frameTime=0;_decodedFrames=0;_lastDecodedTime=0;_jpegDemandUntil=0;_compressedFrames=0;_lastCompressedTime=0;}
}
@end
