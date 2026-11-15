#import "Receiver.h"
#import "LocalTLS.h"
#import "IdentityStore.h"
// Build 87: ScreenLink Maps (Swift, main app only) exposes its latest map picture and directions.
@protocol SLMapFeedAPI
+ (NSData *)frameData;
+ (NSData *)backgroundData;
+ (NSData *)stateData;
+ (void)command:(NSString *)action params:(NSDictionary<NSString *,NSString *> *)params;
@end
// Build 115: the user's own waiting screen files (Maps/WaitingScreen.swift).
@protocol SLWaitingStoreAPI
+ (NSData *)listData;
+ (NSDictionary *)item:(NSString *)identifier;
@end
// Build 105: map squares for the car, fetched by the phone (Maps/MapTiles.swift).
@protocol SLMapTilesAPI
+ (NSData *)tile:(NSString *)path;
+ (NSString *)tileCache:(NSString *)path;
@end
#import "LocalWebSocket.h"
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
#import "ViewerControls.h"
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
#import "WebWatch.h"
#import <pthread.h>
#import <stdatomic.h>
// Build 70 website diagnostics: process-wide, logging only.
static pthread_mutex_t webWatchLock=PTHREAD_MUTEX_INITIALIZER;
static SLWebWatch webWatch;
static double webBusyLogAt,webTLSLogAt,webHostLogAt;
static atomic_int webOpenConnections;
static __weak Receiver *webWatchOwner;
// Build 80: set by serveClient when an HTTPS reply may keep its connection open.
static _Thread_local BOOL webKeepAlive;
// Build 82: kept-open website connections used all 12 slots ("WEBSITE BUSY") and PiP's
// own media requests were refused. The app has 32 slots. Build 83: idle website connections
// stay open 2 min, so the phone (almost) never closes one the browser is about to reuse.
#if SL_BROADCAST_EXTENSION
#define SL_HTTP_SLOTS 12
#else
#define SL_HTTP_SLOTS 32
#endif
// Build 92: idle website connections stay open up to 10 min (was 2 min, 1000 requests), so
// the car opens fewer new connections and needs fewer name lookups. If the phone's slots run
// low, a connection idle for 15 s or more closes first, so PiP's media requests always get a slot.
static BOOL sl_keep_waiting(int client){
    for(int waited=0;waited<600;waited++){
        if(sl_tls_wait_readable(client,1000))return YES;
        if(waited>=15&&atomic_load(&webOpenConnections)>=SL_HTTP_SLOTS-6)return NO;
    }
    return NO;
}
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
    MediaCast *_media;
    ViewerControls *_viewerControls;
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
    BOOL _httpAccepting,_httpsAccepting;
    NSUInteger _httpListenSerial,_httpsListenSerial;
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
- (BOOL)listenerNeedsRepair:(BOOL)secure;
- (BOOL)resumeWebListeners;
- (BOOL)startListener:(unsigned short)port context:(SSL_CTX *)context;
- (void)serveClient:(int)client generation:(NSUInteger)generation;
- (void)streamClient:(int)client generation:(NSUInteger)generation;
- (void)screenSocket:(int)client generation:(NSUInteger)generation token:(NSString *)token peer:(NSString *)peer;
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
// Build 128: each AirPlay sound packet goes to SLAirPlaySound (Maps/AirPlaySound.swift), which can play the
// sound of other apps on the phone speaker. sl_audio_ct / sl_audio_spf come from the library patch.
extern int sl_audio_ct,sl_audio_spf,sl_audio_rawkey;
extern int sl_audio_shk_len,sl_audio_chacha_ok,sl_audio_chacha_fail;extern char sl_audio_keys[200];
// Build 132: lets the sound player switch between the two sound keys (see tools/prepare_receiver.py).
@interface SLAudioKey : NSObject
+ (void)setRaw:(NSNumber *)raw;
+ (NSNumber *)raw;
+ (NSString *)lockNote;
@end
@implementation SLAudioKey
+ (void)setRaw:(NSNumber *)raw {sl_audio_rawkey=raw.boolValue?1:0;}
+ (NSNumber *)raw {return @(sl_audio_rawkey!=0);}
// Build 145: which lock the iPhone used for the sound, for the log.
+ (NSString *)lockNote {return [NSString stringWithFormat:@"sound setup fields: %s; newer lock key sent: %@; opened with it %d, not opened %d",sl_audio_keys[0]?sl_audio_keys:"(none seen)",sl_audio_shk_len==32?@"yes":@"no",sl_audio_chacha_ok,sl_audio_chacha_fail];}
@end
@protocol SLAirPlaySoundAPI
+ (void)packet:(NSData *)data ct:(NSInteger)ct spf:(NSInteger)spf;
@end
static void audio(void *c,raop_ntp_t *n,aac_decode_struct *d) {
    static Class player;static dispatch_once_t once;dispatch_once(&once,^{player=NSClassFromString(@"SLAirPlaySound");});
    if(player&&d->data&&d->data_len>0&&d->data_len<65536)[(id<SLAirPlaySoundAPI>)player packet:[NSData dataWithBytes:d->data length:(NSUInteger)d->data_len] ct:sl_audio_ct spf:sl_audio_spf];
}
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
static BOOL wsSend(int fd,uint8_t opcode,NSData *data){uint8_t header[10];size_t size=sl_ws_header(opcode,data.length,header);return size&&send_all(fd,header,size)&&send_all(fd,data.bytes,data.length);}
static BOOL readExact(int fd,void *bytes,size_t size){uint8_t *p=bytes;while(size){ssize_t n=sl_tls_read(fd,p,size);if(n<=0)return NO;p+=n;size-=(size_t)n;}return YES;}
static BOOL wsNext(int fd){
    for(int control=0;control<8;control++){uint8_t bytes[131],out[126],opcode;size_t size;if(!readExact(fd,bytes,2))return NO;
        if(!(bytes[1]&0x80)||(bytes[1]&127)>125)return NO;size_t rest=4+(bytes[1]&127);if(!readExact(fd,bytes+2,rest)||!sl_ws_client(bytes,2+rest,&opcode,out,&size))return NO;
        if(opcode==8){wsSend(fd,8,[NSData dataWithBytes:out length:size]);return NO;}
        if(opcode==9){if(!wsSend(fd,10,[NSData dataWithBytes:out length:size]))return NO;continue;}
        if(opcode==10)continue;
        return opcode==1&&size==4&&!memcmp(out,"next",4);
    }return NO;
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
    for(struct ifaddrs *p=head;p;p=p->ifa_next)if(p->ifa_addr && p->ifa_addr->sa_family==AF_INET && ntohl(((struct sockaddr_in *)p->ifa_addr)->sin_addr.s_addr)==0x03030303u)owned=YES;
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
// Build 96: while the car stays silent, say so every 30 s (one line was easy to miss) and
// show what the phone can check itself: is the Personal Hotspot up, and is 3.3.3.3 present.
static double webStillLogAt;
static NSString *slNetworkSnapshot(void){
    struct ifaddrs *head=NULL;NSMutableArray *hotspot=[NSMutableArray array];BOOL alias=NO;
    if(getifaddrs(&head)==0){for(struct ifaddrs *p=head;p;p=p->ifa_next){if(!p->ifa_addr||p->ifa_addr->sa_family!=AF_INET)continue;uint32_t a=ntohl(((struct sockaddr_in *)p->ifa_addr)->sin_addr.s_addr);
        if(a==0x03030303u)alias=YES;
        if(!strncmp(p->ifa_name,"bridge",6)){char t[INET_ADDRSTRLEN]={0};inet_ntop(AF_INET,&((struct sockaddr_in *)p->ifa_addr)->sin_addr,t,sizeof t);[hotspot addObject:[NSString stringWithFormat:@"%s %s",p->ifa_name,t]];}}freeifaddrs(head);}
    return [NSString stringWithFormat:@"Personal Hotspot: %@. VPN address 3.3.3.3: %@.",hotspot.count?[@"ON (" stringByAppendingString:[[hotspot componentsJoinedByString:@", "] stringByAppendingString:@")"]]:@"OFF or no car joined",alias?@"present":@"MISSING"];
}
- (NSDictionary *)linkHealth {
    struct ifaddrs *head=NULL;BOOL hotspot=NO,alias=NO;
    if(getifaddrs(&head)==0){for(struct ifaddrs *p=head;p;p=p->ifa_next){if(!p->ifa_addr||p->ifa_addr->sa_family!=AF_INET)continue;
        if(ntohl(((struct sockaddr_in *)p->ifa_addr)->sin_addr.s_addr)==0x03030303u)alias=YES;if(!strncmp(p->ifa_name,"bridge",6))hotspot=YES;}freeifaddrs(head);}
    pthread_mutex_lock(&webWatchLock);double last=webWatch.lastSecure;pthread_mutex_unlock(&webWatchLock);
    return @{@"hotspot":@(hotspot),@"vpn":@(alias),@"carSeconds":@(last>0?NSProcessInfo.processInfo.systemUptime-last:-1)};
}
- (void)resetWebWatch {pthread_mutex_lock(&webWatchLock);memset(&webWatch,0,sizeof webWatch);webBusyLogAt=webTLSLogAt=webHostLogAt=0;pthread_mutex_unlock(&webWatchLock);}
- (void)startWebWatchTimer {
    static dispatch_source_t timer;static dispatch_once_t once;webWatchOwner=self;
    dispatch_once(&once,^{
        timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_global_queue(QOS_CLASS_UTILITY,0));
        dispatch_source_set_timer(timer,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),2*NSEC_PER_SEC,NSEC_PER_SEC/2);
        dispatch_source_set_event_handler(timer,^{
            Receiver *owner=webWatchOwner;if(!owner||!owner.isRunning)return;
            pthread_mutex_lock(&webWatchLock);
            double nowWatch=NSProcessInfo.processInfo.systemUptime;
            BOOL report=sl_web_watch_tick(&webWatch,nowWatch,6);
            double silentFor=webWatch.silent&&webWatch.lastSecure>0?nowWatch-webWatch.lastSecure:0;
            BOOL still=!report&&silentFor>=30&&sl_web_watch_allow(&webStillLogAt,nowWatch,30);if(report)webStillLogAt=nowWatch;
            unsigned long http=webWatch.http-webWatch.httpMark,tls=webWatch.tlsFailures-webWatch.tlsMark,busy=webWatch.busy-webWatch.busyMark,host=webWatch.wrongHost-webWatch.wrongHostMark;
            pthread_mutex_unlock(&webWatchLock);
            if(still)[owner emit:[NSString stringWithFormat:@"WEBSITE STILL LOST: no request from the car for %.0f s (%d connections open). %@ If the hotspot is ON, the car left it or its browser stopped; check the car's Wi-Fi icon and try http://3.3.3.3:8080 on the car.",silentFor,atomic_load(&webOpenConnections),slNetworkSnapshot()]];
            if(report)[owner emit:[@"CAR LINK DETAIL: " stringByAppendingString:slNetworkSnapshot()]];
            if(report)[owner emit:[NSString stringWithFormat:@"WEBSITE SILENT: no HTTPS request from the car for 6 s. Since its last HTTPS request: %lu HTTP (3.3.3.3) requests, %lu HTTPS handshake failures, %lu wrong-address HTTPS requests, %lu connections refused because all slots were busy; %d connections open now. If the HTTPS numbers are all 0, the car is not reaching the phone over HTTPS (name lookup or network). Before stopping, open https://car.tesla4khmer.com/capabilities?check=1 on the car and copy this log.",http,tls,host,busy,atomic_load(&webOpenConnections)]];
        });
        dispatch_resume(timer);
    });
}
- (void)noteWebBusy:(BOOL)secure {
    double now=NSProcessInfo.processInfo.systemUptime;
    pthread_mutex_lock(&webWatchLock);unsigned long total=++webWatch.busy;BOOL log=sl_web_watch_allow(&webBusyLogAt,now,5);pthread_mutex_unlock(&webWatchLock);
    if(log)[self emit:[NSString stringWithFormat:@"WEBSITE BUSY: all %d phone connection slots in use; closed a new %@ connection without answering (%lu refused so far, %d open).",SL_HTTP_SLOTS,secure?@"HTTPS":@"HTTP",total,atomic_load(&webOpenConnections)]];
}
- (void)noteHandshakeFailure:(int)client {
    struct sockaddr_in peer={0};socklen_t size=sizeof peer;char address[INET_ADDRSTRLEN]="unknown";
    if(getpeername(client,(struct sockaddr *)&peer,&size)==0&&peer.sin_family==AF_INET)inet_ntop(AF_INET,&peer.sin_addr,address,sizeof address);
    NSString *reason=[NSString stringWithUTF8String:sl_tls_last_error()]?:@"unknown";
    double now=NSProcessInfo.processInfo.systemUptime;
    pthread_mutex_lock(&webWatchLock);unsigned long total=++webWatch.tlsFailures;BOOL log=sl_web_watch_allow(&webTLSLogAt,now,5);pthread_mutex_unlock(&webWatchLock);
    if(log)[self emit:[NSString stringWithFormat:@"HTTPS HANDSHAKE FAILED from %s: %@ (%lu so far). A few from browser pre-connections are normal; many in a row mean the secure connection itself is failing.",address,reason,total]];
}
- (void)noteWrongHost:(NSString *)host line:(NSString *)first {
    double now=NSProcessInfo.processInfo.systemUptime;
    pthread_mutex_lock(&webWatchLock);unsigned long total=++webWatch.wrongHost;BOOL log=sl_web_watch_allow(&webHostLogAt,now,5);pthread_mutex_unlock(&webWatchLock);
    // Build 143: say what the request was (method and path only, never the token), to find where it comes from.
    NSString *what=[[first componentsSeparatedByString:@"?"].firstObject substringToIndex:MIN((NSUInteger)80,[first componentsSeparatedByString:@"?"].firstObject.length)];
    if(log)[self emit:[NSString stringWithFormat:@"HTTPS REQUEST REFUSED: address '%@' is not car.tesla4khmer.com (%lu so far). Request: %@. Answered 'try again' so the car retries at once.",host?:@"(none)",total,what]];
}
- (void)noteSecureRequest {
    pthread_mutex_lock(&webWatchLock);double gap=sl_web_watch_secure(&webWatch,NSProcessInfo.processInfo.systemUptime);pthread_mutex_unlock(&webWatchLock);
    if(gap>=0)[self emit:[NSString stringWithFormat:@"WEBSITE BACK: car HTTPS requests resumed after %.0f s of silence.",gap]];
}
// Build 75: playback problems reported by the authenticated car page.
- (void)logCarPlayer:(id)lines {
    if(![lines isKindOfClass:NSArray.class])return;NSUInteger count=0;
    for(id line in lines){if(![line isKindOfClass:NSString.class]||count>=6)continue;count++;
        NSString *text=[[line componentsSeparatedByCharactersInSet:NSCharacterSet.controlCharacterSet] componentsJoinedByString:@" "];
        if(text.length>220)text=[text substringToIndex:220];[self emit:[@"CAR PLAYER: " stringByAppendingString:text]];}
}
- (void)noteHTTPRequest {pthread_mutex_lock(&webWatchLock);webWatch.http++;pthread_mutex_unlock(&webWatchLock);}
- (instancetype)init { if((self=[super init])) { _socket=-1;_httpsSocket=-1;_localViewer=[LocalViewerApproval new];_h264=[H264Stream new];_media=[MediaCast new];_viewerControls=[ViewerControls new];
#if SL_BROADCAST_EXTENSION
        _h264=[[H264Stream alloc]initWithMaxBytes:2*1024*1024 packets:90];_screenStream=[[H264Stream alloc]initWithMaxBytes:3*1024*1024 packets:120];_broadcastLog=[NSMutableArray array];_appBackgrounded=YES;_compressedOnlyInBackground=YES;
#else
        _ci=[CIContext contextWithOptions:nil];
#endif
_decodeQueue=dispatch_queue_create("ScreenLink.decode",DISPATCH_QUEUE_SERIAL);_jpegQueue=dispatch_queue_create("ScreenLink.jpeg",DISPATCH_QUEUE_SERIAL);_httpSlots=dispatch_semaphore_create(SL_HTTP_SLOTS);_mediaSlots=dispatch_semaphore_create(_screenStream?3:8);_streamSlots=dispatch_semaphore_create(2);_frameReady=[NSCondition new];_token=NSUUID.UUID.UUIDString;[self installLifecycleObservers];
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
- (NSDictionary *)nativeMediaState {NSMutableDictionary *state=[[_media state] mutableCopy];/* Build 125: the Maps switch on Home. */state[@"maps"]=@([NSUserDefaults.standardUserDefaults boolForKey:@"mapsOpen"]);state[@"viewerControls"]=[_viewerControls snapshotForMedia:state];{/* Build 114: tell the warm-up which quality the car will ask for ("auto" reads as 0). */id wanted=[state[@"viewerControls"] isKindOfClass:NSDictionary.class]?state[@"viewerControls"][@"quality"]:nil;_media.warmHeight=[wanted respondsToSelector:@selector(integerValue)]?[wanted integerValue]:0;}state[@"receiverRunning"]=@(self.isRunning);state[@"internetBack"]=@(self.internetBackCount);return state;}
- (BOOL)applyPhoneViewerControl:(NSDictionary *)request {return [_viewerControls update:request media:[_media state]];}
- (void)prepareMediaOnly {if(_running)return;self.mediaOnly=YES;_screenStream=[[H264Stream alloc]initWithMaxBytes:3*1024*1024 packets:120];_compressedOnlyInBackground=YES;[self setScreenHidden:YES];}
- (void)authorizeNextLocalViewer {[_localViewer armAutomaticAt:NSProcessInfo.processInfo.systemUptime];[self setScreenHidden:YES];}
- (H264Stream *)screenStream {return _screenStream;}
- (BOOL)screenHidden {return !_screenStream || _screenStream.privacyHidden;}
- (BOOL)changeScreenHidden:(BOOL)hidden expectedRevision:(NSUInteger)revision {if(!_screenStream||(!hidden&&(self.mediaOnly||self.screenCaptureLocked)))return NO;CMTime time=CMClockGetTime(CMClockGetHostTimeClock());BOOL changed=[_screenStream changePrivacyHidden:hidden notBefore:(uint64_t)(CMTimeGetSeconds(time)*1000000) expectedRevision:revision];if(changed)[self emit:hidden?@"PHONE SCREEN HIDDEN: new screen frames are blocked and cached screen history cleared. YouTube media continues.":@"PHONE SCREEN ENABLED: only show after Google Maps is open. Waiting for a fresh capture keyframe."];return changed;}
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
        if(owner->_running){[owner resumeListenersIfNeeded];if(owner.discoveryMode==SLDiscoveryPhoneVPN)[owner->_vpnDiscovery recoverOnForeground];}
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
    // Build 124 "Phone sound": in YouTube-only mode ScreenLink can announce itself as a picture-only device
    // (no sound service, sound bit cleared). iOS then has nowhere to send the sound of other apps (Messenger,
    // Telegram …), so they play on the phone speaker. The car video and its sound do not use that path.
    BOOL noAudio=self.mediaOnly&&self.discoveryMode==SLDiscoveryPhoneVPN&&[NSUserDefaults.standardUserDefaults boolForKey:@"phoneSound"];
    if(noAudio){NSMutableArray *changed=[NSMutableArray array];for(NSString *entry in airplayTXT){NSString *out=entry;
        if([entry hasPrefix:@"features="]){NSArray<NSString *> *words=[[entry substringFromIndex:9] componentsSeparatedByString:@","];unsigned long long low=strtoull(words.firstObject.UTF8String,NULL,16);low&=~0x200ULL;NSMutableArray *again=[words mutableCopy];again[0]=[NSString stringWithFormat:@"0x%llX",low];out=[@"features=" stringByAppendingString:[again componentsJoinedByString:@","]];}
        [changed addObject:out];}airplayTXT=changed;
        [self emit:@"PHONE SOUND ON: ScreenLink is announced as a picture-only AirPlay device, so other apps keep their sound on the phone. If ScreenLink VPN Phone is missing in YouTube, switch Phone sound off on Home, then Disconnect all and Start."];}
    NSMutableString *hex=[NSMutableString string];const uint8_t *idBytes=identity.bytes;
    for(int i=0;i<6;i++)[hex appendFormat:@"%02X",idBytes[i]];
    NSMutableString *mediaID=[NSMutableString string];for(int i=0;i<6;i++)[mediaID appendFormat:i?@":%02X":@"%02X",idBytes[i]];_media.deviceID=mediaID;
    NSString *serviceName=self.discoveryMode==SLDiscoveryPhoneVPN?@"ScreenLink VPN Phone":@"ScreenLink VPN";
    NSString *host=self.discoveryMode==SLDiscoveryPhoneVPN?[NSString stringWithFormat:@"screenlink-%@-vpn.local.",hex.lowercaseString]:@"screenlink-vpn.local.";
    self.discoveryProfile=@{@"name":serviceName,@"host":host,@"port":@(port),@"peer":@"10.7.0.1",@"raopName":[NSString stringWithFormat:@"%@@%@",hex,serviceName],@"airplayTXT":airplayTXT,@"raopTXT":txtStrings(txt,txtLength),@"externalDiscovery":@(self.externalDiscovery),@"discoveryMode":@(self.discoveryMode),@"noAudio":@(noAudio)};
    if(![self startWeb]){[self stop];return NO;}
    _running=YES;
    if(self.discoveryMode==SLDiscoveryPhoneVPN)[self refreshDiscovery];
    else [self emit:self.externalDiscovery?@"Receiver ready in Mac VPN discovery mode. Start the Mac helper with your viewer link, then select ScreenLink VPN. Phone advertisements are disabled to avoid duplicates.":@"Receiver ready with native discovery. Look for ScreenLink in Screen Mirroring; same-phone discovery can vary."];
    return YES;
}
- (void)refreshDiscovery {
    if(!_running){[self emit:@"Start the receiver before refreshing discovery."];return;}
    if(_vpnDiscovery){[_vpnDiscovery recoverIfNeeded];return;}
    BOOL busy;@synchronized(self){busy=_controlClients>0 || _mirrorTransportOpen;}
    if(busy){[self emit:@"Discovery kept unchanged: AirPlay is connecting or connected. Refreshing now could interrupt the session."];return;}
    if(self.discoveryMode!=SLDiscoveryPhoneVPN){[self emit:@"Refresh discovery applies to iPhone VPN mode. For Mac VPN mode, keep its helper running."];return;}
    if(!_vpnDiscovery){
        _vpnDiscovery=[VPNDiscovery new];__weak Receiver *weak=self;
        _vpnDiscovery.status=^(NSString *message){[weak emit:message];};
    }
    [_vpnDiscovery startWithProfile:self.discoveryProfile];
}
- (BOOL)listenerNeedsRepair:(BOOL)secure {
    @synchronized(self){
        int server=secure?_httpsSocket:_socket;
        BOOL accepting=secure?_httpsAccepting:_httpAccepting;
        if(server<0||!accepting)return YES;
#if defined(SO_ISDEFUNCT)
        int defunct=0;socklen_t size=sizeof defunct;
        if(getsockopt(server,SOL_SOCKET,SO_ISDEFUNCT,&defunct,&size)==0&&defunct)return YES;
#endif
        int listening=0;socklen_t length=sizeof listening;
        if(getsockopt(server,SOL_SOCKET,SO_ACCEPTCONN,&listening,&length)==0)return !listening;
        // Darwin may not implement this option. Keep a live accept loop when
        // the socket still has a valid local endpoint; never restart it merely
        // because SO_ACCEPTCONN is unsupported.
        if(errno!=ENOPROTOOPT&&errno!=EINVAL)return YES;
        struct sockaddr_storage endpoint;socklen_t endpointLength=sizeof endpoint;
        return getsockname(server,(struct sockaddr *)&endpoint,&endpointLength)!=0;
    }
}
- (BOOL)resumeWebListeners {
    BOOL healthy=YES;
    for(NSNumber *secure in @[@NO,@YES]){
        BOOL tls=secure.boolValue;
        if(![self listenerNeedsRepair:tls])continue;
        @synchronized(self){
            int server=tls?_httpsSocket:_socket;
            if(tls){_httpsSocket=-1;_httpsAccepting=NO;}else{_socket=-1;_httpAccepting=NO;}
            if(server>=0){shutdown(server,SHUT_RDWR);close(server);}
        }
        SSL_CTX *context=NULL;
        if(tls){
            NSString *directory=[SLIdentityStore activeDirectory];
            context=sl_tls_context([[directory stringByAppendingPathComponent:@"fullchain.pem"] fileSystemRepresentation],[[directory stringByAppendingPathComponent:@"private.key"] fileSystemRepresentation]);
            if(!context){healthy=NO;[self emit:@"LISTENER RECOVERY: HTTPS identity unavailable; listener could not be restored."];continue;}
        }
        BOOL ready=[self startListener:tls?443:8080 context:context];if(context)SSL_CTX_free(context);
        healthy&=ready;
        [self emit:[NSString stringWithFormat:@"LISTENER RECOVERY: %@ %@; viewer authorization and media state retained.",tls?@"HTTPS 443":@"HTTP 8080",ready?@"listening again":@"could not bind"]];
    }
    return healthy;
}
- (BOOL)resumeListenersIfNeeded {
    if(!_running)return NO;
    BOOL healthy=YES;
    if(_raop&&!raop_is_running(_raop)){
        // Join only the dead AirPlay thread, retaining receiver identity, media,
        // website credentials and all healthy web listener workers.
        raop_stop(_raop);unsigned short port=raop_get_port(_raop);
        int result=raop_start(_raop,&port);
        BOOL ready=result>=0&&raop_is_running(_raop);healthy&=ready;
        if(ready)raop_set_port(_raop,port);
        [self emit:ready?@"LISTENER RECOVERY: AirPlay listening again; reselect ScreenLink in YouTube if the sender released AirPlay.":@"LISTENER RECOVERY: AirPlay listener could not restart. Return to ScreenLink and retry."];
    }
    return [self resumeWebListeners]&&healthy;
}
- (BOOL)startWeb {
    [self resetWebWatch];[self startWebWatchTimer];
    if(![self startListener:8080 context:NULL])return NO;
    NSString *directory=[SLIdentityStore activeDirectory];
    SSL_CTX *context=sl_tls_context([[directory stringByAppendingPathComponent:@"fullchain.pem"] fileSystemRepresentation],[[directory stringByAppendingPathComponent:@"private.key"] fileSystemRepresentation]);
    if(context){if([self startListener:443 context:context])[self emit:@"LOCAL HTTPS READY: https://car.tesla4khmer.com/ — approve the viewer on this phone. Open /capabilities to check browser APIs."];else [self emit:@"HTTPS port 443 unavailable. HTTP viewer remains available."];SSL_CTX_free(context);}
    else [self emit:[SLIdentityStore hasIdentity]?@"Local HTTPS not started: website certificate expired, wrong hostname or mismatched key. HTTP viewer remains available. Open Developer → Import website certificate.":@"Local HTTPS not started: no website certificate in this build. Open Developer → Import website certificate and pick your earlier ScreenLink IPA. HTTP viewer remains available."];
    return YES;
}
- (BOOL)startListener:(unsigned short)port context:(SSL_CTX *)context {
    int server=socket(AF_INET,SOCK_STREAM,0);if(server<0)return NO;
    int yes=1;setsockopt(server,SOL_SOCKET,SO_REUSEADDR,&yes,sizeof yes);
    struct sockaddr_in address={0};address.sin_len=sizeof address;address.sin_family=AF_INET;address.sin_port=htons(port);address.sin_addr.s_addr=INADDR_ANY;
    if(bind(server,(struct sockaddr *)&address,sizeof address)<0 || listen(server,8)<0){close(server);return NO;}
    NSUInteger generation,listenSerial;
    @synchronized(self){
        generation=_generation;
        if(context){_httpsSocket=server;_httpsAccepting=YES;listenSerial=++_httpsListenSerial;}
        else{_socket=server;_httpAccepting=YES;listenSerial=++_httpListenSerial;}
    }
    if(context)SSL_CTX_up_ref(context);
    // Build 110: the loop that accepts the car's connections ran at low (utility) priority, which iOS
    // slows down first for a background app. It now runs at the same priority as the request handlers.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        while(YES) {
            BOOL current;@synchronized(self){current=generation==self->_generation&&listenSerial==(context?self->_httpsListenSerial:self->_httpListenSerial);}if(!current)break;
            int client=accept(server,NULL,NULL);if(client<0){
                if(errno==EINTR||errno==EAGAIN||errno==EWOULDBLOCK||errno==ECONNABORTED)continue;
                [self emit:[NSString stringWithFormat:@"LOCAL LISTENER STOPPED: port %u, accept errno %d; foreground will repair it.",port,errno]];break;
            }
            if(dispatch_semaphore_wait(self->_httpSlots,DISPATCH_TIME_NOW)!=0){close(client);[self noteWebBusy:context!=NULL];continue;}
            if(context)SSL_CTX_up_ref(context);
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
                struct timeval timeout={5,0};setsockopt(client,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof timeout);setsockopt(client,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof timeout);
                int one=1;setsockopt(client,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof one);
                @try {@autoreleasepool {atomic_fetch_add(&webOpenConnections,1);if(!context || sl_tls_begin(context,client)){
                    // Build 80: reuse open HTTPS connections, so the car needs far fewer name
                    // lookups and secure handshakes (each failed lookup silenced the website).
                    for(int served=0;served<100000;served++){webKeepAlive=NO;@autoreleasepool{[self serveClient:client generation:generation];}if(!webKeepAlive||!sl_keep_waiting(client))break;}
                }else [self noteHandshakeFailure:client];}}
                @finally {atomic_fetch_sub(&webOpenConnections,1);if(context){sl_tls_end();SSL_CTX_free(context);}close(client);dispatch_semaphore_signal(self->_httpSlots);}
            });
        }
        @synchronized(self){
            int owned=context?self->_httpsSocket:self->_socket;
            if(generation==self->_generation&&listenSerial==(context?self->_httpsListenSerial:self->_httpListenSerial)&&owned==server){
                if(context){self->_httpsSocket=-1;self->_httpsAccepting=NO;}else{self->_socket=-1;self->_httpAccepting=NO;}
                shutdown(server,SHUT_RDWR);close(server);
            }
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
    NSString *mime=@"text/plain; charset=utf-8",*status=@"200 OK",*extra=@"",*cacheControl=@"no-store";NSData *body=[NSData data];
    NSRange headerEnd=[request rangeOfData:[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding] options:0 range:NSMakeRange(0,request.length)];
    if(headerEnd.location==NSNotFound)return;
    NSUInteger bodyOffset=headerEnd.location==NSNotFound?request.length:NSMaxRange(headerEnd);NSUInteger bodyLength=0;NSString *byteRange=nil,*origin=nil,*host=nil;NSMutableDictionary *wsHeaders=[NSMutableDictionary dictionary];BOOL duplicateWS=NO;BOOL localControl=NO,viewerHeaderValid=NO;
    for(NSString *field in [line componentsSeparatedByString:@"\r\n"]){
        NSRange separator=[field rangeOfString:@":"];if(separator.location!=NSNotFound){NSString *name=[[field substringToIndex:separator.location] lowercaseString];if([@[@"upgrade",@"connection",@"sec-websocket-key",@"sec-websocket-version",@"origin",@"host"] containsObject:name]){if(wsHeaders[name])duplicateWS=YES;wsHeaders[name]=[[field substringFromIndex:NSMaxRange(separator)] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];}}

        if([field.lowercaseString hasPrefix:@"host:"])host=[[[field substringFromIndex:5] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] lowercaseString];
        if([field.lowercaseString hasPrefix:@"x-screenlink-control:"] && [[[field substringFromIndex:21] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] isEqual:@"app"])localControl=YES;
        if([field.lowercaseString hasPrefix:@"content-length:"])bodyLength=(NSUInteger)MAX(0,[[field substringFromIndex:15] integerValue]);
        if([field.lowercaseString hasPrefix:@"origin:"])origin=[[field substringFromIndex:7] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if([field.lowercaseString hasPrefix:@"x-screenlink-viewer:"])viewerHeaderValid=sl_local_viewer_request_header(field.UTF8String);
        if([field.lowercaseString hasPrefix:@"range:"])byteRange=[[field substringFromIndex:6] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    }
    BOOL secureTransport=sl_tls_active(client);
    if(secureTransport && ![@[@"car.tesla4khmer.com",@"car.tesla4khmer.com:443"] containsObject:host]){
        // Build 143: answer at once and close, instead of leaving the car waiting on a silent connection.
        [self noteWrongHost:host line:[line componentsSeparatedByString:@"\r\n"].firstObject?:@""];
        static const char *retry="HTTP/1.1 421 Misdirected Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";send_all(client,retry,strlen(retry));return;}
    if(secureTransport)[self noteSecureRequest];
    NSString *expectedOrigin=secureTransport?@"https://car.tesla4khmer.com":@"http://3.3.3.3:8080";
    if(bodyLength>8192)return;
    while(request.length-bodyOffset<bodyLength){ssize_t n=sl_tls_read(client,buffer,MIN(sizeof buffer,bodyLength-(request.length-bodyOffset)));if(n<=0)return;[request appendBytes:buffer length:n];}
    struct sockaddr_in peer={0};socklen_t peerSize=sizeof peer;BOOL loopback=getpeername(client,(struct sockaddr *)&peer,&peerSize)==0 && peer.sin_family==AF_INET && (ntohl(peer.sin_addr.s_addr)>>24)==127;
    if(!secureTransport && !loopback)[self noteHTTPRequest];
    BOOL localOwner=loopback && localControl && [parts.firstObject isEqual:@"GET"] && [url.path isEqual:@"/local/owner"];
    BOOL localStop=loopback && localControl && [parts.firstObject isEqual:@"POST"] && [url.path isEqual:@"/local/broadcast/stop"];
    BOOL localRTC=loopback&&localControl&&[url.path hasPrefix:@"/local/rtc/"]&&_screenStream!=nil&&([parts.firstObject isEqual:@"GET"]||[parts.firstObject isEqual:@"POST"]);
    struct sockaddr_in localEndpoint={0};socklen_t localSize=sizeof localEndpoint;
    BOOL aliasDestination=getsockname(client,(struct sockaddr *)&localEndpoint,&localSize)==0 && localEndpoint.sin_family==AF_INET && ntohl(localEndpoint.sin_addr.s_addr)==0x03030303u;
    BOOL aliasClient=aliasDestination && _screenStream && routeProbeClient(client);
    char peerAddress[INET_ADDRSTRLEN]={0};inet_ntop(AF_INET,&peer.sin_addr,peerAddress,sizeof peerAddress);NSString *peerHost=[NSString stringWithUTF8String:peerAddress];
    NSTimeInterval localNow=NSProcessInfo.processInfo.systemUptime;
    BOOL localPlayerControl=loopback&&localControl&&[parts.firstObject isEqual:@"POST"]&&[url.path isEqual:@"/local/viewer/playback"];
    BOOL localViewerControl=loopback && localControl && [parts.firstObject isEqual:@"POST"] && [url.path isEqual:@"/local/viewer/decision"];
    BOOL privacy=[parts.firstObject isEqual:@"POST"] && [url.path isEqual:@"/screen/privacy"];
    BOOL report=[parts.firstObject isEqual:@"POST"] && [url.path isEqual:@"/media/report"];
    BOOL current;@synchronized(self){current=_generation==generation;}
    if(current && secureTransport && aliasClient && [url.path isEqual:@"/stream"]){
        char accept[29];NSArray *connections=[[[(wsHeaders[@"connection"]?:@"") lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@""] componentsSeparatedByString:@","];
        BOOL authorized=[_localViewer allowsToken:token peer:peerHost now:localNow];
        BOOL upgrade=!duplicateWS&&bodyLength==0&&authorized&&[parts.firstObject isEqual:@"GET"]&&[origin isEqual:expectedOrigin]&&[[wsHeaders[@"upgrade"] lowercaseString] isEqual:@"websocket"]&&[connections containsObject:@"upgrade"]&&[wsHeaders[@"sec-websocket-version"] isEqual:@"13"]&&sl_ws_accept([wsHeaders[@"sec-websocket-key"] UTF8String],accept);
        if(!upgrade){status=@"403 Forbidden";body=[@"Approved local HTTPS WebSocket required." dataUsingEncoding:NSUTF8StringEncoding];}
        else if(dispatch_semaphore_wait(_streamSlots,DISPATCH_TIME_NOW)!=0){status=@"429 Too Many Requests";}
        else{@try{NSString *header=[NSString stringWithFormat:@"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n\r\n",accept];NSData *bytes=[header dataUsingEncoding:NSUTF8StringEncoding];if(send_all(client,bytes.bytes,bytes.length))[self screenSocket:client generation:generation token:token peer:peerHost];}@finally{dispatch_semaphore_signal(_streamSlots);}return;}
    }
    else if(current && secureTransport && aliasClient && [url.path isEqual:@"/local-viewer/disconnect"] && [parts.firstObject isEqual:@"POST"] && [origin isEqual:expectedOrigin] && [_localViewer allowsToken:token peer:peerHost now:localNow]){[_localViewer reset];[self setScreenHidden:YES];mime=@"application/json";body=[@"{}" dataUsingEncoding:NSUTF8StringEncoding];}
    else if(current && localPlayerControl){
        id object=[NSJSONSerialization JSONObjectWithData:[request subdataWithRange:NSMakeRange(bodyOffset,bodyLength)] options:0 error:nil];
        NSDictionary *request=[object isKindOfClass:NSDictionary.class]?object:nil;
        if(request[@"action"]){
            BOOL accepted=request.count==1 && !origin.length && [host isEqual:@"127.0.0.1:8080"] &&
                self.isRunning && _screenStream && [_viewerControls performWidgetAction:request[@"action"] media:[_media state]];
            status=accepted?@"200 OK":@"400 Bad Request";
            mime=@"application/json";
            body=[NSJSONSerialization dataWithJSONObject:@{@"accepted":@(accepted)} options:0 error:nil];
        }else{
            BOOL accepted=[self applyPhoneViewerControl:request];
            status=accepted?@"200 OK":@"400 Bad Request";
            mime=@"application/json";
            body=[NSJSONSerialization dataWithJSONObject:accepted?[self nativeMediaState]:@{@"error":@"Invalid or unavailable player control"} options:0 error:nil];
        }
    }
    else if(current && localViewerControl){
        id object=[NSJSONSerialization JSONObjectWithData:[request subdataWithRange:NSMakeRange(bodyOffset,bodyLength)] options:0 error:nil];
        NSString *action=[object isKindOfClass:NSDictionary.class]?object[@"action"]:nil;BOOL changed=NO;
        if([action isEqual:@"automatic"]){if([object[@"youtubeOnly"] isKindOfClass:NSNumber.class])self.screenCaptureLocked=[object[@"youtubeOnly"] boolValue];[_localViewer armAutomaticAt:localNow];[self setScreenHidden:YES];changed=YES;}
        else if([action isEqual:@"disconnect"]){[_localViewer reset];[self setScreenHidden:YES];changed=YES;[self emit:@"LOCAL VIEWER DISCONNECTED: alias media authorization revoked; phone screen hidden."];}
        else if([action isEqual:@"approve"]||[action isEqual:@"reject"]){changed=[_localViewer decide:[action isEqual:@"approve"] requestID:object[@"requestID"] now:localNow];if(changed){[self setScreenHidden:YES];[self emit:[action isEqual:@"approve"]?@"LOCAL VIEWER APPROVED: experimental HTTP media enabled for this hotspot client; phone screen starts hidden. Tesla playback is not yet verified.":@"LOCAL VIEWER REJECTED: no alias media access granted."];}}
        status=changed?@"200 OK":@"409 Conflict";mime=@"application/json";body=[@"{}" dataUsingEncoding:NSUTF8StringEncoding];
    }
    else if(current && [url.path isEqual:@"/local-viewer/request"]){
        if(!aliasClient || ![parts.firstObject isEqual:@"POST"] || ![origin isEqual:expectedOrigin] || !viewerHeaderValid){status=@"403 Forbidden";[self emit:[NSString stringWithFormat:@"LOCAL APPROVAL REQUEST REJECTED: owned-alias/hotspot=%d, POST=%d, expected-origin=%d, request-header=%d. No media access granted.",aliasClient,[parts.firstObject isEqual:@"POST"],[origin isEqual:expectedOrigin],viewerHeaderValid]];}
        else{id object=[NSJSONSerialization JSONObjectWithData:[request subdataWithRange:NSMakeRange(bodyOffset,bodyLength)] options:0 error:nil];NSString *nonce=[object isKindOfClass:NSDictionary.class]?object[@"nonce"]:nil;NSDictionary *result=[_localViewer request:nonce peer:peerHost previousToken:([object isKindOfClass:NSDictionary.class]?object[@"previousToken"]:nil) now:localNow];mime=@"application/json";body=[NSJSONSerialization dataWithJSONObject:result options:0 error:nil];}
    }
    else if(current && secureTransport && aliasClient && [parts.firstObject isEqual:@"GET"] && ([@[@"/",@"/split",@"/map",@"/video",@"/sw.js"] containsObject:url.path]||[url.path hasPrefix:@"/app/"])){NSDictionary *assets=@{@"/":@"CanvasShell.html",@"/split":@"CanvasShell.html",@"/map":@"CanvasShell.html",@"/video":@"CanvasShell.html",@"/sw.js":@"CanvasServiceWorker.js",@"/app/pure.js":@"CanvasShell.js",@"/app/screen.js":@"CanvasScreen.js",@"/app/canvas.js":@"CanvasPlayer.js",@"/app/hls.js":@"HLSPlayer.js",@"/app/browser-video.js":@"BrowserVideoPlayer.js",@"/app/mp4box.js":@"MP4Demux.js",@"/app/mux.js":@"TSDemux.js",@"/app/car-poster.jpg":@"CarPoster.jpg",@"/app/car-ambient.webp":@"CarAmbient.webp"};NSString *file=assets[url.path];if(!file){status=@"404 Not Found";}else{mime=[file hasSuffix:@".js"]?@"application/javascript":[file hasSuffix:@".jpg"]?@"image/jpeg":[file hasSuffix:@".webp"]?@"image/webp":@"text/html; charset=utf-8";NSString *path=[NSBundle.mainBundle pathForResource:file.stringByDeletingPathExtension ofType:file.pathExtension];body=path?[NSData dataWithContentsOfFile:path]:nil;if(!body){status=@"503 Service Unavailable";body=NSData.data;}if([url.path isEqual:@"/sw.js"])extra=@"Service-Worker-Allowed: /\r\n";}}
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
    else if(current && loopback && localControl && [parts.firstObject isEqual:@"GET"] && [url.path isEqual:@"/local/widget/state"]){
        // Build 84: compact live state for the Home Screen widget and Control Center (loopback only).
        NSDictionary *m=[self nativeMediaState],*c=[m[@"viewerControls"] isKindOfClass:NSDictionary.class]?m[@"viewerControls"]:@{};
        pthread_mutex_lock(&webWatchLock);BOOL car=webWatch.lastSecure>0&&localNow-webWatch.lastSecure<6;pthread_mutex_unlock(&webWatchLock);
        mime=@"application/json";body=[NSJSONSerialization dataWithJSONObject:@{@"running":@(self.isRunning),@"active":@([m[@"active"] boolValue]),@"paused":@([m[@"paused"] boolValue]),@"position":@([m[@"position"] doubleValue]),@"duration":@([m[@"duration"] doubleValue]),@"quality":[c[@"quality"] isKindOfClass:NSString.class]?c[@"quality"]:@"auto",@"volume":@([c[@"volume"] respondsToSelector:@selector(doubleValue)]?[c[@"volume"] doubleValue]:1),@"eq":[c[@"eq"] isKindOfClass:NSString.class]?c[@"eq"]:@"normal",@"car":@(car),@"epoch":[m[@"epoch"] isKindOfClass:NSString.class]?m[@"epoch"]:@""} options:0 error:NULL];
    }
    else if(current && localOwner){mime=@"application/json";NSDictionary *mediaState=[self nativeMediaState];NSDictionary *owner;@synchronized(self){owner=@{@"broadcast":@(_screenStream!=nil&&!self.mediaOnly),@"mediaOnly":@(self.mediaOnly),@"screenLocked":@(self.screenCaptureLocked),@"running":@(_running),@"frames":@(_screenFrames),@"token":self.token,@"logs":_broadcastLog.copy?:@[],@"localViewer":[_localViewer statusAt:localNow],@"mediaState":mediaState};}body=[NSJSONSerialization dataWithJSONObject:owner options:0 error:NULL];}
    else if(current&&localRTC){__block NSDictionary *result;NSString *command=[url.path substringFromIndex:11];BOOL allowed=([parts.firstObject isEqual:@"GET"]&&[command isEqual:@"status"])||([parts.firstObject isEqual:@"POST"]&&[@[@"start",@"approve",@"reject",@"stop"] containsObject:command]);if(!allowed){status=@"405 Method Not Allowed";}else{dispatch_sync(dispatch_get_main_queue(),^{if(!self->_rtcMedia&&[command isEqual:@"start"]){self->_rtcMedia=[[SLMediaSession alloc]initWithMedia:self->_media];__weak Receiver *weak=self;self->_rtcMedia.status=^(NSString *message){[weak emit:message];};self->_rtcMedia.screenProvider=^NSDictionary *(NSString *path,NSDictionary *request){return [weak rtcScreenRequest:path request:request]?:@{@"code":@503};};}result=self->_rtcMedia?[self->_rtcMedia control:command]:@{@"phase":@"idle",@"approvalRequested":@NO,@"events":@[]};});mime=@"application/json";body=[NSJSONSerialization dataWithJSONObject:result options:0 error:nil];}}
    else if(current && localStop && _screenStream){mime=@"application/json";body=[@"{}" dataUsingEncoding:NSUTF8StringEncoding];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_MSEC*250),dispatch_get_main_queue(),^{if(self.broadcastStop)self.broadcastStop();});}
    else if(!current || (![parts.firstObject isEqual:@"GET"] && !report && !privacy) || !(aliasDestination?(aliasClient && [_localViewer allowsToken:token peer:peerHost now:localNow]):[token isEqual:self.token])){status=@"403 Forbidden";body=[(aliasDestination?@"Open http://3.3.3.3:8080/ and request approval on the iPhone.":@"On the iPhone hotspot, open http://172.20.10.1:8080/ . On other Wi-Fi, use the complete viewer link from ScreenLink.") dataUsingEncoding:NSUTF8StringEncoding];}
    else if(privacy){NSData *json=[request subdataWithRange:NSMakeRange(bodyOffset,bodyLength)];id object=[NSJSONSerialization JSONObjectWithData:json options:0 error:NULL];id value=[object isKindOfClass:NSDictionary.class]?object[@"hidden"]:nil;if(!_screenStream){status=@"409 Conflict";}else if(!value || CFGetTypeID((__bridge CFTypeRef)value)!=CFBooleanGetTypeID()){status=@"400 Bad Request";}else{if(![self changeScreenHidden:[value boolValue] expectedRevision:[object[@"expectedRevision"] unsignedIntegerValue]])status=@"409 Conflict";mime=@"application/json";body=[NSJSONSerialization dataWithJSONObject:[self screenInfo] options:0 error:NULL];}}
    else if([url.path isEqual:@"/screen/info"]){mime=@"application/json";body=[NSJSONSerialization dataWithJSONObject:[self screenInfo] options:0 error:NULL];}
    else if([url.path isEqual:@"/screen/init.mp4"]){NSDictionary *part=[_screenStream initialization];body=part[@"data"]?:NSData.data;mime=@"video/mp4";extra=[NSString stringWithFormat:@"X-Stream-Epoch: %@\r\n",part[@"epoch"]?:@""];if(!body.length)status=@"503 Service Unavailable";}
    else if([url.path isEqual:@"/screen/segments"]){NSDictionary *part=[_screenStream readAfter:after epoch:epoch?:@""];if([part[@"reset"] boolValue])status=@"409 Conflict";else{body=part[@"data"]?:NSData.data;if(!body.length)status=@"204 No Content";}mime=@"video/mp4";extra=[NSString stringWithFormat:@"X-Stream-Epoch: %@\r\nX-Last-ID: %@\r\n",part[@"epoch"]?:@"",part[@"id"]?:@0];}
    else if([url.path isEqual:@"/split"] || [url.path isEqual:@"/map"]){mime=@"text/html; charset=utf-8";NSString *path=[NSBundle.mainBundle pathForResource:[url.path isEqual:@"/split"]?@"SplitViewer":@"MapPlayer" ofType:@"html"];body=path?[NSData dataWithContentsOfFile:path]:NSData.data;}
    else if([url.path hasPrefix:@"/waiting/"]){
        // Build 115: pictures, GIFs and short videos the user chose as the car's waiting screen.
        Class store=NSClassFromString(@"SLWaitingStore");
        if(!store)status=@"404 Not Found";
        else if([url.path isEqual:@"/waiting/list"]){mime=@"application/json";body=[(id<SLWaitingStoreAPI>)store listData];}
        else if([url.path hasPrefix:@"/waiting/item/"]){
            NSDictionary *item=[(id<SLWaitingStoreAPI>)store item:[url.path substringFromIndex:14]];NSData *file=[item[@"data"] isKindOfClass:NSData.class]?item[@"data"]:nil;
            if(!file.length)status=@"404 Not Found";
            else{
                mime=[item[@"mime"] isKindOfClass:NSString.class]?item[@"mime"]:@"application/octet-stream";cacheControl=@"private, max-age=86400";
                NSUInteger total=file.length,from=0,to=total-1;BOOL partial=NO;
                // A video element asks for parts of the file ("Range: bytes=a-b").
                if([byteRange hasPrefix:@"bytes="]){NSArray<NSString *> *ends=[[byteRange substringFromIndex:6] componentsSeparatedByString:@"-"];
                    if(ends.count==2&&ends[0].length){long long first=ends[0].longLongValue,last=ends[1].length?ends[1].longLongValue:(long long)total-1;
                        if(first>=0&&first<(long long)total&&last>=first){from=(NSUInteger)first;to=(NSUInteger)MIN(last,(long long)total-1);partial=YES;}}}
                body=partial?[file subdataWithRange:NSMakeRange(from,to-from+1)]:file;
                if(partial){status=@"206 Partial Content";extra=[NSString stringWithFormat:@"Content-Range: bytes %lu-%lu/%lu\r\nAccept-Ranges: bytes\r\n",(unsigned long)from,(unsigned long)to,(unsigned long)total];}
                else extra=@"Accept-Ranges: bytes\r\n";
            }
        }
        else status=@"404 Not Found";
    }
    else if([url.path hasPrefix:@"/map/"]){
        // Build 87: small navigation map for the (rear-seat) car screen; same approval/token as media.
        Class feed=NSClassFromString(@"SLMapFeed");
        if(!feed){status=@"404 Not Found";}
        else if([url.path isEqual:@"/map/frame.jpg"]||[url.path isEqual:@"/map/bg.jpg"]){
            NSData *jpeg=[url.path isEqual:@"/map/frame.jpg"]?[(id<SLMapFeedAPI>)feed frameData]:[(id<SLMapFeedAPI>)feed backgroundData];
            if(jpeg.length){mime=@"image/jpeg";body=jpeg;}else status=@"204 No Content";
        }
        else if([url.path hasPrefix:@"/map/tile/"]){
            // Build 105: one map square. The car may keep it only as long as Google allowed the phone to.
            Class tiles=NSClassFromString(@"SLMapTiles");NSString *square=[url.path substringFromIndex:10];NSData *tile=tiles?[(id<SLMapTilesAPI>)tiles tile:square]:nil;
            if(tile.length>3){const uint8_t *first=tile.bytes;mime=first[0]==0x89?@"image/png":@"image/jpeg";body=tile;NSString *allowed=[(id<SLMapTilesAPI>)tiles tileCache:square];
                if([allowed isKindOfClass:NSString.class]&&allowed.length&&allowed.length<60&&[allowed rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location==NSNotFound)cacheControl=allowed;}else status=@"502 Bad Gateway";
        }
        else if([url.path isEqual:@"/map/state"]){mime=@"application/json";body=[(id<SLMapFeedAPI>)feed stateData];}
        else if([url.path isEqual:@"/map/cmd"]){
            NSMutableDictionary *params=[NSMutableDictionary dictionary];for(NSURLQueryItem *item in url.queryItems)if(![item.name isEqual:@"token"]&&item.value)params[item.name]=item.value;
            NSString *action=params[@"a"]?:@"";if(action.length&&action.length<40)[(id<SLMapFeedAPI>)feed command:action params:params];
            // Build 98: the car says whether it can draw the map itself. Log only changes.
            if([action isEqual:@"carmap"]){static NSString *lastCarMap;NSString *why=[params[@"why"] isKindOfClass:NSString.class]&&[params[@"why"] length]?params[@"why"]:@"unknown";if(why.length>60)why=[why substringToIndex:60];NSString *now=[params[@"ok"] isEqual:@"1"]?@"ok":[@"failed: " stringByAppendingString:why];
                if(![now isEqual:lastCarMap]){lastCarMap=now;[self emit:[now isEqual:@"ok"]?@"CAR MAP: the car draws the Google map itself, so it keeps working when ScreenLink is in the background or the iPhone is locked.":[NSString stringWithFormat:@"CAR MAP %@. The car uses the phone's map pictures instead. Fix: in Google Cloud enable Maps JavaScript API for your key and allow the website https://car.tesla4khmer.com/*.",now]];}}
            mime=@"application/json";body=[@"{\"ok\":true}" dataUsingEncoding:NSUTF8StringEncoding];
        }
        else status=@"404 Not Found";
    }
    else if([url.path isEqual:@"/media/state"]){mime=@"application/json";NSMutableDictionary *state=[[self nativeMediaState] mutableCopy];state[@"screenLocked"]=@(self.screenCaptureLocked||self.mediaOnly);body=[NSJSONSerialization dataWithJSONObject:state options:0 error:NULL];}
    else if(report){
        NSData *json=[request subdataWithRange:NSMakeRange(bodyOffset,bodyLength)];id object=[NSJSONSerialization JSONObjectWithData:json options:0 error:NULL];
        if([object isKindOfClass:NSDictionary.class]){[self logCarPlayer:object[@"carLog"]];[_media report:object];[_viewerControls acknowledge:object];mime=@"application/json";body=[@"{}" dataUsingEncoding:NSUTF8StringEncoding];}else status=@"400 Bad Request";
    }
    else if([url.path hasPrefix:@"/media/resource/"]){
        CFAbsoluteTime pieceStart=CFAbsoluteTimeGetCurrent();
        NSDictionary *part;if(dispatch_semaphore_wait(_mediaSlots,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC))){part=@{@"code":@503};[self emit:@"MEDIA PIECE REFUSED: every download place on the phone was busy for 2 s, so the car was told to ask again. Earlier downloads are stuck."];}else{@try{part=[_media resource:[url.path substringFromIndex:16] range:byteRange];}@finally{dispatch_semaphore_signal(_mediaSlots);}}NSInteger code=[part[@"code"] integerValue];
        // Build 118: remember when this piece was ready, to time the sending to the car below.
        NSThread.currentThread.threadDictionary[@"slPiece"]=@[@(pieceStart),@(CFAbsoluteTimeGetCurrent())];
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
    BOOL keep=secureTransport&&current&&parts.count>2&&[parts[2] hasPrefix:@"HTTP/1.1"]&&![[wsHeaders[@"connection"] lowercaseString] containsString:@"close"];
    NSString *header=[NSString stringWithFormat:@"HTTP/1.1 %@\r\nContent-Type: %@\r\nContent-Length: %lu\r\nCache-Control: %@\r\n%@X-Content-Type-Options: nosniff\r\n%@\r\n",status,mime,(unsigned long)body.length,cacheControl,keep?@"Connection: keep-alive\r\nKeep-Alive: timeout=600, max=100000\r\n":@"Connection: close\r\n",extra];
    NSData *h=[header dataUsingEncoding:NSUTF8StringEncoding];BOOL sent=send_all(client,h.bytes,h.length)&&send_all(client,body.bytes,body.length);if(sent)webKeepAlive=keep;
    // Build 118: one line when a video piece was slow or could not be handed to the car, and which side it was.
    NSArray *piece=NSThread.currentThread.threadDictionary[@"slPiece"];
    if(piece){[NSThread.currentThread.threadDictionary removeObjectForKey:@"slPiece"];double got=[piece[1] doubleValue]-[piece[0] doubleValue],gave=CFAbsoluteTimeGetCurrent()-[piece[1] doubleValue];
     if(got>=3||gave>=3||!sent)[self emit:[NSString stringWithFormat:@"MEDIA PIECE TO CAR %@: getting it ready took %.1f s, sending %lu KB to the car took %.1f s%@.",sent?@"SLOW":@"NOT DELIVERED",got,(unsigned long)(body.length/1024),gave,sent?@"":@" and the car connection broke"]];}
}
- (void)screenSocket:(int)client generation:(NSUInteger)generation token:(NSString *)token peer:(NSString *)peer {
    NSString *epoch=nil;uint64_t after=0;
    while(YES){@autoreleasepool{
        BOOL current;@synchronized(self){current=_running&&generation==_generation;}
        if(!current||![_localViewer allowsToken:token peer:peer now:NSProcessInfo.processInfo.systemUptime])break;
        NSDictionary *info=[self screenInfo];NSData *binary=nil;NSString *kind=@"state";
        if(![info[@"hidden"] boolValue]&&[info[@"ready"] boolValue]){
            if(![epoch isEqual:info[@"epoch"]]){NSDictionary *init=[_screenStream initialization];if([init[@"epoch"] isEqual:info[@"epoch"]]&&[init[@"data"] length]){epoch=info[@"epoch"];after=0;kind=@"init";binary=init[@"data"];}}
            else{NSDictionary *part=[_screenStream readAfter:after epoch:epoch maxBytes:2*1024*1024 wait:0.15];if([part[@"reset"] boolValue]){epoch=nil;continue;}if([part[@"data"] length]){kind=@"data";binary=part[@"data"];after=[part[@"id"] unsignedLongLongValue];}}
        }
        NSDictionary *fresh=[self screenInfo];if(![fresh[@"epoch"] isEqual:info[@"epoch"]]||[fresh[@"privacyRevision"] unsignedIntegerValue]!=[info[@"privacyRevision"] unsignedIntegerValue]){epoch=nil;continue;}
        NSMutableDictionary *message=[info mutableCopy];message[@"kind"]=kind;message[@"id"]=@(after);message[@"bytes"]=@(binary.length);
        if(!wsSend(client,1,[NSJSONSerialization dataWithJSONObject:message options:0 error:nil]))break;
        if(binary.length){NSDictionary *gate=[self screenInfo];if([gate[@"hidden"] boolValue]||![gate[@"epoch"] isEqual:info[@"epoch"]]||![_localViewer allowsToken:token peer:peer now:NSProcessInfo.processInfo.systemUptime])break;if(!wsSend(client,2,binary))break;}
        if(!wsNext(client))break;
    }}
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
    void (^closeRTC)(void)=^{[self->_rtcMedia stop];self->_rtcMedia=nil;};if(NSThread.isMainThread)closeRTC();else dispatch_sync(dispatch_get_main_queue(),closeRTC);
    [_localViewer reset];[_screenStream reset];
#if !SL_BROADCAST_EXTENSION
    if(self.mediaOnly){self.mediaOnly=NO;_screenStream=nil;}
#endif
    [_media stop];[_vpnDiscovery stop];_vpnDiscovery=nil;[_h264 reset];
    @synchronized(self){_running=NO;_generation++;_mirrorTransportOpen=NO;_sessionFrames=0;_controlClients=0;}
    [_frameReady lock];[_frameReady broadcast];[_frameReady unlock];
    @synchronized(self){
        _httpAccepting=NO;_httpsAccepting=NO;
        if(_httpsSocket>=0){shutdown(_httpsSocket,SHUT_RDWR);close(_httpsSocket);_httpsSocket=-1;}
        if(_socket>=0){shutdown(_socket,SHUT_RDWR);close(_socket);_socket=-1;}
    }
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

