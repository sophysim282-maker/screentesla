#import "SLPingPeer.h"
#import "SLTestVideo.h"
#import <WebRTC/WebRTC.h>
#import <arpa/inet.h>
@interface SLPingPeer () <RTCPeerConnectionDelegate,RTCDataChannelDelegate,RTCVideoRenderer>
@property(nonatomic,strong) RTCPeerConnectionFactory *factory;
@property(nonatomic,strong) RTCPeerConnection *peer;
@property(nonatomic,strong) RTCDataChannel *channel,*mediaChannel,*screenChannel;
@property(nonatomic,strong) NSTimer *pingTimer;
@property(nonatomic,strong) RTCVideoSource *videoSource;
@property(nonatomic,strong) RTCVideoTrack *videoTrack,*receivedTrack;
@property(nonatomic,strong) SLTestVideo *testVideo;
@property(nonatomic) NSUInteger decodedFrames,changedFrames,remoteFrames;
@property(nonatomic) uint32_t lastChecksum;
@property(nonatomic) NSTimeInterval lastDecoded,lastRemoteProgress;
@property(nonatomic) BOOL strict,closed,waiting,pingSent;
@property(nonatomic) NSUInteger offerGeneration;
@property(nonatomic) NSTimeInterval lastVerified;
@property(nonatomic,copy) void (^offerCompletion)(NSString *,NSString *,NSError *);
@end
@implementation SLPingPeer
- (instancetype)initWithHotspotOnly:(BOOL)strict offerer:(BOOL)offerer {return [self initWithHotspotOnly:strict offerer:offerer dataOnly:NO];}
- (instancetype)initWithHotspotOnly:(BOOL)strict offerer:(BOOL)offerer dataOnly:(BOOL)dataOnly {
    if((self=[super init])){static dispatch_once_t once;dispatch_once(&once,^{RTCInitializeSSL();RTCSetMinDebugLogLevel(RTCLoggingSeverityError);});_strict=strict;if(dataOnly){_factory=[RTCPeerConnectionFactory new];}else{RTCDefaultVideoEncoderFactory *encoders=[RTCDefaultVideoEncoderFactory new];for(RTCVideoCodecInfo *codec in [RTCDefaultVideoEncoderFactory supportedCodecs])if([codec.name isEqual:@"H264"]){encoders.preferredCodec=codec;break;}_factory=[[RTCPeerConnectionFactory alloc]initWithEncoderFactory:encoders decoderFactory:[RTCDefaultVideoDecoderFactory new]];}RTCSetMinDebugLogLevel(RTCLoggingSeverityNone);RTCConfiguration *config=[RTCConfiguration new];config.iceServers=@[];config.iceTransportPolicy=RTCIceTransportPolicyAll;config.sdpSemantics=RTCSdpSemanticsUnifiedPlan;config.bundlePolicy=RTCBundlePolicyMaxBundle;config.tcpCandidatePolicy=RTCTcpCandidatePolicyEnabled;config.continualGatheringPolicy=RTCContinualGatheringPolicyGatherOnce;
        _peer=[_factory peerConnectionWithConfiguration:config constraints:[[RTCMediaConstraints alloc]initWithMandatoryConstraints:nil optionalConstraints:nil] delegate:self];
        if(offerer){RTCDataChannelConfiguration *channel=[RTCDataChannelConfiguration new];channel.isOrdered=YES;_channel=[_peer dataChannelForLabel:@"ping" configuration:channel];_channel.delegate=self;}
    }return self;
}
- (void)enableMediaChannel {if(self.closed||self.mediaChannel||self.peer.localDescription)return;RTCDataChannelConfiguration *config=[RTCDataChannelConfiguration new];config.isOrdered=YES;config.protocol=@"screenlink-media-v1";self.mediaChannel=[self.peer dataChannelForLabel:@"media" configuration:config];self.mediaChannel.delegate=self;}
- (void)enableScreenChannel {if(self.closed||self.screenChannel||self.peer.localDescription)return;RTCDataChannelConfiguration *config=[RTCDataChannelConfiguration new];config.isOrdered=YES;config.protocol=@"screenlink-screen-v1";self.screenChannel=[self.peer dataChannelForLabel:@"screen" configuration:config];self.screenChannel.delegate=self;}
- (uint64_t)screenBufferedAmount {return self.screenChannel.bufferedAmount;}
- (BOOL)screenOpen {return self.screenChannel!=nil&&self.screenChannel.readyState==RTCDataChannelStateOpen;}
- (BOOL)sendScreen:(NSData *)data binary:(BOOL)binary {if(!self.screenOpen||data.length>16384||self.screenBufferedAmount>65536)return NO;return [self.screenChannel sendData:[[RTCDataBuffer alloc]initWithData:data isBinary:binary]];}
- (uint64_t)mediaBufferedAmount {return self.mediaChannel.bufferedAmount;}
- (BOOL)mediaOpen {return self.mediaChannel.readyState==RTCDataChannelStateOpen&&self.mediaChannel!=nil;}
- (BOOL)sendMedia:(NSData *)data binary:(BOOL)binary {if(!self.mediaOpen||data.length>16384||self.mediaBufferedAmount>262144)return NO;return [self.mediaChannel sendData:[[RTCDataBuffer alloc]initWithData:data isBinary:binary]];}
- (BOOL)enableTestVideo:(NSError **)error {
    if(self.closed||self.peer.localDescription||self.videoTrack){if(error)*error=[self error:@"Video must be enabled before starting pairing."];return NO;}
    self.videoSource=[self.factory videoSource];self.videoTrack=[self.factory videoTrackWithSource:self.videoSource trackId:@"screenlink-test-video"];
    RTCRtpTransceiverInit *init=[RTCRtpTransceiverInit new];init.direction=RTCRtpTransceiverDirectionSendOnly;init.streamIds=@[@"screenlink-test"];
    RTCRtpTransceiver *transceiver=[self.peer addTransceiverWithTrack:self.videoTrack init:init];
    NSArray *available=[self.factory rtpSenderCapabilitiesForKind:kRTCMediaStreamTrackKindVideo].codecs;
    NSMutableArray *codecs=[NSMutableArray array];for(NSString *wanted in @[@"H264",@"VP8"]){for(RTCRtpCodecCapability *codec in available)if([codec.name caseInsensitiveCompare:wanted]==NSOrderedSame||[codec.mimeType caseInsensitiveCompare:[@"video/" stringByAppendingString:wanted]]==NSOrderedSame)[codecs addObject:codec];if(codecs.count)break;}
    NSError *codecError=nil;if(!transceiver||!codecs.count||![transceiver setCodecPreferences:codecs error:&codecError]){if(error)*error=[self error:[NSString stringWithFormat:@"Video setup failed (transceiver %@, codecs %@, encoders %@, error %@).",transceiver?@"available":@"missing",[available valueForKey:@"name"],[[RTCDefaultVideoEncoderFactory supportedCodecs] valueForKey:@"name"],codecError.localizedDescription?:@"none"]];return NO;}
    RTCRtpParameters *parameters=transceiver.sender.parameters;for(RTCRtpEncodingParameters *encoding in parameters.encodings){encoding.maxBitrateBps=@1500000;encoding.maxFramerate=@30;}transceiver.sender.parameters=parameters;
    self.testVideo=[[SLTestVideo alloc]initWithSource:self.videoSource];if(!self.testVideo){if(error)*error=[self error:@"Could not allocate bounded video buffers."];return NO;}return YES;
}
- (void)setSize:(CGSize)size {}
- (void)renderFrame:(RTCVideoFrame *)frame {
    if(!frame)return;id<RTCI420Buffer> pixels=[frame.buffer toI420];if(!pixels||pixels.width<=0||pixels.height<=0)return;
    uint32_t hash=2166136261u;for(int y=0;y<pixels.height;y+=MAX(1,pixels.height/18))for(int x=0;x<pixels.width;x+=MAX(1,pixels.width/32)){hash^=pixels.dataY[y*pixels.strideY+x];hash*=16777619u;}
    @synchronized(self){self.decodedFrames++;if(hash!=self.lastChecksum)self.changedFrames++;self.lastChecksum=hash;self.lastDecoded=NSProcessInfo.processInfo.systemUptime;}
}
- (void)peerConnection:(RTCPeerConnection *)peer didAddReceiver:(RTCRtpReceiver *)receiver streams:(NSArray<RTCMediaStream *> *)streams {
    if(![receiver.track isKindOfClass:RTCVideoTrack.class])return;dispatch_async(dispatch_get_main_queue(),^{if(self.closed)return;[self.receivedTrack removeRenderer:self];self.receivedTrack=(RTCVideoTrack *)receiver.track;[self.receivedTrack addRenderer:self];});
}
- (void)log:(NSString *)message {if(self.status)self.status(message);}
- (NSError *)error:(NSString *)message {return [NSError errorWithDomain:@"ScreenLink.WebRTC" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];}
- (BOOL)pingOK {return self.lastVerified>0&&NSProcessInfo.processInfo.systemUptime-self.lastVerified<15;}
- (NSString *)filteredSDP:(NSString *)sdp {
    NSMutableArray *lines=[NSMutableArray array];NSUInteger usable=0;
    for(NSString *line in [sdp componentsSeparatedByString:@"\r\n"]){
        if([line hasPrefix:@"a=candidate:"]){NSArray *fields=[[line componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];BOOL host=fields.count>=8&&[fields[6] isEqual:@"typ"]&&[fields[7] isEqual:@"host"];struct in_addr address;BOOL ipv4=fields.count>=8&&inet_pton(AF_INET,[fields[4] UTF8String],&address)==1;if(!host||!ipv4|| (self.strict&&![fields[4] isEqual:@"172.20.10.1"]))continue;usable++;}
        [lines addObject:line];
    }
    return usable?[lines componentsJoinedByString:@"\r\n"]:nil;
}
- (void)finishGathering:(BOOL)complete generation:(NSUInteger)generation {
    if(self.closed||!self.waiting||generation!=self.offerGeneration)return;self.waiting=NO;
    NSString *sdp=[self filteredSDP:self.peer.localDescription.sdp];void (^callback)(NSString *,NSString *,NSError *)=self.offerCompletion;self.offerCompletion=nil;
    if(callback)callback(sdp,complete?@"complete":@"timeout",sdp?nil:[self error:self.strict?@"No iPhone hotspot host candidate. Turn on Personal Hotspot, connect the viewer, and retry. No session was published.":@"No usable local host candidates."]);
}
- (void)localDescription:(RTCSessionDescription *)sdp generation:(NSUInteger)generation {
    [self.peer setLocalDescription:sdp completionHandler:^(NSError *error){dispatch_async(dispatch_get_main_queue(),^{
        if(self.closed||generation!=self.offerGeneration)return;
        if(error){void (^done)(NSString *,NSString *,NSError *)=self.offerCompletion;self.offerCompletion=nil;if(done)done(nil,nil,[self error:@"WebRTC could not set its local description."]);return;}
        self.waiting=YES;if(self.peer.iceGatheringState==RTCIceGatheringStateComplete)[self finishGathering:YES generation:generation];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),dispatch_get_main_queue(),^{[self finishGathering:self.peer.iceGatheringState==RTCIceGatheringStateComplete generation:generation];});
    });}];
}
- (void)offerRestart:(BOOL)restart completion:(void (^)(NSString *,NSString *,NSError *))completion {
    self.offerCompletion=completion;self.waiting=NO;NSUInteger generation=++self.offerGeneration;if(restart)[self.peer restartIce];
    RTCMediaConstraints *constraints=[[RTCMediaConstraints alloc]initWithMandatoryConstraints:restart?@{@"IceRestart":@"true"}:nil optionalConstraints:nil];
    [self.peer offerForConstraints:constraints completionHandler:^(RTCSessionDescription *sdp,NSError *error){dispatch_async(dispatch_get_main_queue(),^{if(self.closed||generation!=self.offerGeneration)return;if(error||!sdp){self.offerCompletion=nil;completion(nil,nil,[self error:@"WebRTC could not create an offer."]);return;}[self localDescription:sdp generation:generation];});}];
}
- (void)answerOffer:(NSString *)offer completion:(void (^)(NSString *,NSString *,NSError *))completion {
    self.offerCompletion=completion;NSUInteger generation=++self.offerGeneration;
    [self.peer setRemoteDescription:[[RTCSessionDescription alloc]initWithType:RTCSdpTypeOffer sdp:offer] completionHandler:^(NSError *error){
        if(error){dispatch_async(dispatch_get_main_queue(),^{completion(nil,nil,[self error:@"Remote offer rejected."]);});return;}
        [self.peer answerForConstraints:[[RTCMediaConstraints alloc]initWithMandatoryConstraints:nil optionalConstraints:nil] completionHandler:^(RTCSessionDescription *sdp,NSError *answerError){dispatch_async(dispatch_get_main_queue(),^{if(self.closed||generation!=self.offerGeneration)return;if(answerError){completion(nil,nil,[self error:@"Could not create answer."]);return;}[self localDescription:sdp generation:generation];});}];
    }];
}
- (void)applyAnswer:(NSString *)answer completion:(void (^)(NSError *))completion {
    [self.peer setRemoteDescription:[[RTCSessionDescription alloc]initWithType:RTCSdpTypeAnswer sdp:answer] completionHandler:^(NSError *error){dispatch_async(dispatch_get_main_queue(),^{completion(error?[self error:@"WebRTC rejected the viewer answer."]:nil);});}];
}
- (BOOL)send:(NSString *)text {if(self.channel.readyState!=RTCDataChannelStateOpen)return NO;return [self.channel sendData:[[RTCDataBuffer alloc]initWithData:[text dataUsingEncoding:NSUTF8StringEncoding] isBinary:NO]];}
- (void)ping {if(!self.closed&&self.channel.readyState==RTCDataChannelStateOpen)self.pingSent=[self send:@"ping"]||self.pingSent;}
- (void)dataChannelDidChangeState:(RTCDataChannel *)dataChannel {
    dispatch_async(dispatch_get_main_queue(),^{
        if(self.closed)return;
        if(dataChannel==self.mediaChannel){if(self.mediaOpen&&self.mediaOpened)self.mediaOpened();return;}
        if(dataChannel==self.screenChannel){if(self.screenOpen&&self.screenOpened)self.screenOpened();return;}
        if(dataChannel!=self.channel)return;
        if(dataChannel.readyState==RTCDataChannelStateOpen){[self log:@"WebRTC data channel open; waiting for a verified ping/pong exchange."];[self ping];if(!self.pingTimer){__weak SLPingPeer *weak=self;self.pingTimer=[NSTimer scheduledTimerWithTimeInterval:3 repeats:YES block:^(NSTimer *timer){[weak ping];}];}}
    });
}
- (void)dataChannel:(RTCDataChannel *)channel didReceiveMessageWithBuffer:(RTCDataBuffer *)buffer {
    // Classification must run after the queued incoming-channel installation.
    // Otherwise an immediate hello can be mistaken for an unknown ping channel.
    if(buffer.data.length>16384)return;
    dispatch_async(dispatch_get_main_queue(),^{
        if(self.closed)return;
        if(channel==self.mediaChannel){if(self.mediaMessage)self.mediaMessage(buffer.data,buffer.isBinary);return;}
        if(channel==self.screenChannel){if(self.screenMessage)self.screenMessage(buffer.data,buffer.isBinary);return;}
        if(channel!=self.channel||buffer.data.length>4096||buffer.isBinary)return;
        NSString *text=[[NSString alloc]initWithData:buffer.data encoding:NSUTF8StringEncoding];
        if([text isEqual:@"ping"]){if([self send:@"pong"])self.lastVerified=NSProcessInfo.processInfo.systemUptime;}
        else if([text isEqual:@"pong"]&&self.pingSent)self.lastVerified=NSProcessInfo.processInfo.systemUptime;
        else {id object=[NSJSONSerialization JSONObjectWithData:buffer.data options:0 error:nil];if([object isKindOfClass:NSDictionary.class]&&[object[@"type"] isEqual:@"video-report"]){id count=object[@"framesRendered"];if([count isKindOfClass:NSNumber.class]&&[count unsignedLongLongValue]<=1000000000ULL){NSUInteger n=[count unsignedIntegerValue];if(n>self.remoteFrames){self.remoteFrames=n;self.lastRemoteProgress=NSProcessInfo.processInfo.systemUptime;}}}
        else if([object isKindOfClass:NSDictionary.class]&&[object[@"type"] isEqual:@"ping"]){NSMutableDictionary *reply=[@{@"type":@"pong"} mutableCopy];if([object[@"id"] isKindOfClass:NSString.class]&&[object[@"id"] length]<=64)reply[@"id"]=object[@"id"];NSData *bytes=[NSJSONSerialization dataWithJSONObject:reply options:0 error:nil];if([self send:[[NSString alloc]initWithData:bytes encoding:NSUTF8StringEncoding]])self.lastVerified=NSProcessInfo.processInfo.systemUptime;}}
    });
}
static BOOL privateIP(NSString *host,BOOL strict){struct in_addr address;if(inet_pton(AF_INET,host.UTF8String,&address)!=1)return NO;uint32_t ip=ntohl(address.s_addr);if(strict)return (ip&0xffffff00)==0xac140a00;return (ip>>24)==10||(ip>>24)==127||(ip>>20)==0xac1||(ip>>16)==0xc0a8;}
- (void)snapshot:(void (^)(NSDictionary *))completion {
    if(self.closed){completion(@{@"connectionState":@"closed",@"verified":@NO});return;}
    [self.peer statisticsWithCompletionHandler:^(RTCStatisticsReport *report){dispatch_async(dispatch_get_main_queue(),^{
        RTCStatistics *pair=nil;NSDictionary *all=report.statistics;
        for(RTCStatistics *stat in all.allValues)if([stat.type isEqual:@"transport"]&&stat.values[@"selectedCandidatePairId"]){pair=all[stat.values[@"selectedCandidatePairId"]];break;}
        if(!pair)for(RTCStatistics *stat in all.allValues)if([stat.type isEqual:@"candidate-pair"]&&[(id)stat.values[@"nominated"] boolValue]&&[stat.values[@"state"] isEqual:@"succeeded"]){pair=stat;break;}
        RTCStatistics *local=all[pair.values[@"localCandidateId"]?:@""],*remote=all[pair.values[@"remoteCandidateId"]?:@""];
        NSString *lh=(id)local.values[@"address"]?:(id)local.values[@"ip"]?:@"",*rh=(id)remote.values[@"address"]?:(id)remote.values[@"ip"]?:@"";
        BOOL localRoute=privateIP(lh,self.strict)&&privateIP(rh,self.strict)&&![(id)local.values[@"candidateType"] isEqual:@"relay"]&&![(id)remote.values[@"candidateType"] isEqual:@"relay"];
        uint64_t sent=[(id)pair.values[@"bytesSent"] unsignedLongLongValue],received=[(id)pair.values[@"bytesReceived"] unsignedLongLongValue];
        BOOL connected=self.peer.connectionState==RTCPeerConnectionStateConnected,verified=connected&&self.channel.readyState==RTCDataChannelStateOpen&&self.pingOK&&sent>0&&received>0&&localRoute;
        NSArray *states=@[@"new",@"connecting",@"connected",@"disconnected",@"failed",@"closed"];NSUInteger index=self.peer.connectionState;
        NSDictionary *selected=@{@"local":[NSString stringWithFormat:@"%@:%@",lh,local.values[@"port"]?:@0],@"remote":[NSString stringWithFormat:@"%@:%@",rh,remote.values[@"port"]?:@0],@"protocol":local.values[@"protocol"]?:@"unknown"};
        NSMutableArray *checks=[NSMutableArray array],*dtls=[NSMutableArray array];
        for(RTCStatistics *stat in all.allValues){if([stat.type isEqual:@"candidate-pair"]&&checks.count<16){NSMutableDictionary *item=[NSMutableDictionary dictionary];for(NSString *key in @[@"state",@"nominated",@"requestsSent",@"requestsReceived",@"responsesReceived",@"bytesSent",@"bytesReceived"])if(stat.values[key])item[key]=stat.values[key];[checks addObject:item];}if([stat.type isEqual:@"transport"]&&stat.values[@"dtlsState"])[dtls addObject:stat.values[@"dtlsState"]];}
        uint64_t encoded=0,videoBytes=0;NSString *codec=@"";
        for(RTCStatistics *stat in all.allValues)if([stat.type isEqual:@"outbound-rtp"]&&([(id)stat.values[@"kind"] isEqual:@"video"]||[(id)stat.values[@"mediaType"] isEqual:@"video"])){encoded+=[(id)stat.values[@"framesEncoded"] unsignedLongLongValue];videoBytes+=[(id)stat.values[@"bytesSent"] unsignedLongLongValue];RTCStatistics *type=all[stat.values[@"codecId"]?:@""];codec=(id)type.values[@"mimeType"]?:@"";}
        NSUInteger decoded,changed;NSTimeInterval fresh;@synchronized(self){decoded=self.decodedFrames;changed=self.changedFrames;fresh=self.lastDecoded;}
        NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;BOOL videoVerified=verified&&((self.testVideo&&encoded>0&&self.remoteFrames>0&&now-self.lastRemoteProgress<4)||(!self.testVideo&&decoded>0&&now-fresh<4));
        completion(@{@"iceChecks":checks,@"dtlsStates":dtls,@"screenChannelOpen":@(self.screenOpen),@"videoFramesEncoded":@(encoded),@"videoBytesSent":@(videoBytes),@"videoFramesDecoded":@(decoded),@"videoFramesChanged":@(changed),@"viewerFramesRendered":@(self.remoteFrames),@"videoCodec":codec,@"videoVerified":@(videoVerified),@"connectionState":index<states.count?states[index]:@"unknown",@"bytesSent":@(sent),@"bytesReceived":@(received),@"dataChannelPingOk":@(self.pingOK),@"localRouteVerified":@(localRoute),@"verified":@(verified),@"selectedPair":selected});
    });}];
}
- (void)close {self.closed=YES;self.screenChannel.delegate=nil;[self.screenChannel close];self.screenChannel=nil;self.screenMessage=nil;self.screenOpened=nil;self.mediaChannel.delegate=nil;[self.mediaChannel close];self.mediaChannel=nil;self.mediaMessage=nil;self.mediaOpened=nil;[self.testVideo stop];self.testVideo=nil;[self.receivedTrack removeRenderer:self];self.receivedTrack=nil;self.videoTrack=nil;self.videoSource=nil;self.offerGeneration++;self.offerCompletion=nil;[self.pingTimer invalidate];self.pingTimer=nil;self.channel.delegate=nil;[self.channel close];self.channel=nil;self.peer.delegate=nil;[self.peer close];self.peer=nil;self.factory=nil;}
- (void)peerConnection:(RTCPeerConnection *)peer didChangeConnectionState:(RTCPeerConnectionState)state {dispatch_async(dispatch_get_main_queue(),^{if(!self.closed){if(state==RTCPeerConnectionStateConnected)[self.testVideo start];else [self.testVideo stop];NSArray *states=@[@"new",@"connecting",@"connected",@"disconnected",@"failed",@"closed"];[self log:[NSString stringWithFormat:@"WEBRTC TRANSPORT: %@. Local traffic verification is separate.",state<states.count?states[state]:@"unknown"]];}});}
- (void)peerConnection:(RTCPeerConnection *)p didChangeIceGatheringState:(RTCIceGatheringState)state {dispatch_async(dispatch_get_main_queue(),^{if(state==RTCIceGatheringStateComplete)[self finishGathering:YES generation:self.offerGeneration];});}
- (void)peerConnection:(RTCPeerConnection *)p didOpenDataChannel:(RTCDataChannel *)channel {
    // Queue ownership first, then attach the observer before returning to WebRTC.
    // Waiting for the main queue to attach it loses messages sent at channel-open.
    dispatch_async(dispatch_get_main_queue(),^{
        if(self.closed){channel.delegate=nil;[channel close];return;}
        if([channel.label isEqual:@"media"]&&[channel.protocol isEqual:@"screenlink-media-v1"]){self.mediaChannel=channel;[self dataChannelDidChangeState:channel];return;}
        if([channel.label isEqual:@"screen"]&&[channel.protocol isEqual:@"screenlink-screen-v1"]){self.screenChannel=channel;[self dataChannelDidChangeState:channel];return;}
        if(![channel.label isEqual:@"ping"]){channel.delegate=nil;[channel close];return;}
        self.channel=channel;[self dataChannelDidChangeState:channel];
    });
    channel.delegate=self;
}
- (void)peerConnection:(RTCPeerConnection *)p didChangeSignalingState:(RTCSignalingState)s {}
- (void)peerConnection:(RTCPeerConnection *)p didChangeIceConnectionState:(RTCIceConnectionState)s {}
- (void)peerConnection:(RTCPeerConnection *)p didGenerateIceCandidate:(RTCIceCandidate *)c {}
- (void)peerConnection:(RTCPeerConnection *)p didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)c {}
- (void)peerConnection:(RTCPeerConnection *)p didAddStream:(RTCMediaStream *)s {}
- (void)peerConnection:(RTCPeerConnection *)p didRemoveStream:(RTCMediaStream *)s {}
- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)p {}
@end
