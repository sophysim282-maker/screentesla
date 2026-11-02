#import "SLPingPeer.h"
#import <WebRTC/WebRTC.h>
#import <arpa/inet.h>
@interface SLPingPeer () <RTCPeerConnectionDelegate,RTCDataChannelDelegate>
@property(nonatomic,strong) RTCPeerConnectionFactory *factory;
@property(nonatomic,strong) RTCPeerConnection *peer;
@property(nonatomic,strong) RTCDataChannel *channel;
@property(nonatomic,strong) NSTimer *pingTimer;
@property(nonatomic) BOOL strict,closed,waiting,pingSent;
@property(nonatomic) NSUInteger offerGeneration;
@property(nonatomic) NSTimeInterval lastVerified;
@property(nonatomic,copy) void (^offerCompletion)(NSString *,NSString *,NSError *);
@end
@implementation SLPingPeer
- (instancetype)initWithHotspotOnly:(BOOL)strict offerer:(BOOL)offerer {
    if((self=[super init])){static dispatch_once_t once;dispatch_once(&once,^{RTCInitializeSSL();RTCSetMinDebugLogLevel(RTCLoggingSeverityError);});_strict=strict;_factory=[RTCPeerConnectionFactory new];RTCConfiguration *config=[RTCConfiguration new];config.iceServers=@[];config.iceTransportPolicy=RTCIceTransportPolicyAll;config.sdpSemantics=RTCSdpSemanticsUnifiedPlan;config.bundlePolicy=RTCBundlePolicyMaxBundle;config.tcpCandidatePolicy=RTCTcpCandidatePolicyDisabled;config.continualGatheringPolicy=RTCContinualGatheringPolicyGatherOnce;
        _peer=[_factory peerConnectionWithConfiguration:config constraints:[[RTCMediaConstraints alloc]initWithMandatoryConstraints:nil optionalConstraints:nil] delegate:self];
        if(offerer){RTCDataChannelConfiguration *channel=[RTCDataChannelConfiguration new];channel.isOrdered=YES;_channel=[_peer dataChannelForLabel:@"ping" configuration:channel];_channel.delegate=self;}
    }return self;
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
    [self.peer offerForConstraints:constraints completionHandler:^(RTCSessionDescription *sdp,NSError *error){dispatch_async(dispatch_get_main_queue(),^{if(self.closed||generation!=self.offerGeneration)return;if(error||!sdp){self.offerCompletion=nil;completion(nil,nil,[self error:@"WebRTC could not create a data-channel offer."]);return;}[self localDescription:sdp generation:generation];});}];
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
- (void)dataChannelDidChangeState:(RTCDataChannel *)dataChannel {dispatch_async(dispatch_get_main_queue(),^{if(self.closed||dataChannel!=self.channel)return;if(dataChannel.readyState==RTCDataChannelStateOpen){[self log:@"WebRTC data channel open; waiting for a verified ping/pong exchange."];[self ping];if(!self.pingTimer){__weak SLPingPeer *weak=self;self.pingTimer=[NSTimer scheduledTimerWithTimeInterval:3 repeats:YES block:^(NSTimer *timer){[weak ping];}];}}});}
- (void)dataChannel:(RTCDataChannel *)channel didReceiveMessageWithBuffer:(RTCDataBuffer *)buffer {
    if(buffer.data.length>4096||buffer.isBinary)return;NSString *text=[[NSString alloc]initWithData:buffer.data encoding:NSUTF8StringEncoding];
    dispatch_async(dispatch_get_main_queue(),^{if(self.closed||channel!=self.channel)return;
        if([text isEqual:@"ping"]){if([self send:@"pong"])self.lastVerified=NSProcessInfo.processInfo.systemUptime;}
        else if([text isEqual:@"pong"]&&self.pingSent)self.lastVerified=NSProcessInfo.processInfo.systemUptime;
        else {id object=[NSJSONSerialization JSONObjectWithData:buffer.data options:0 error:nil];if([object isKindOfClass:NSDictionary.class]&&[object[@"type"] isEqual:@"ping"]){NSMutableDictionary *reply=[@{@"type":@"pong"} mutableCopy];if([object[@"id"] isKindOfClass:NSString.class]&&[object[@"id"] length]<=64)reply[@"id"]=object[@"id"];NSData *bytes=[NSJSONSerialization dataWithJSONObject:reply options:0 error:nil];if([self send:[[NSString alloc]initWithData:bytes encoding:NSUTF8StringEncoding]])self.lastVerified=NSProcessInfo.processInfo.systemUptime;}}
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
        completion(@{@"connectionState":index<states.count?states[index]:@"unknown",@"bytesSent":@(sent),@"bytesReceived":@(received),@"dataChannelPingOk":@(self.pingOK),@"localRouteVerified":@(localRoute),@"verified":@(verified),@"selectedPair":selected});
    });}];
}
- (void)close {self.closed=YES;self.offerGeneration++;self.offerCompletion=nil;[self.pingTimer invalidate];self.pingTimer=nil;self.channel.delegate=nil;[self.channel close];self.channel=nil;self.peer.delegate=nil;[self.peer close];self.peer=nil;self.factory=nil;}
- (void)peerConnection:(RTCPeerConnection *)peer didChangeConnectionState:(RTCPeerConnectionState)state {dispatch_async(dispatch_get_main_queue(),^{if(!self.closed)[self log:@"WebRTC connection state changed; traffic and route checks determine verification."];});}
- (void)peerConnection:(RTCPeerConnection *)p didChangeIceGatheringState:(RTCIceGatheringState)state {dispatch_async(dispatch_get_main_queue(),^{if(state==RTCIceGatheringStateComplete)[self finishGathering:YES generation:self.offerGeneration];});}
- (void)peerConnection:(RTCPeerConnection *)p didOpenDataChannel:(RTCDataChannel *)channel {dispatch_async(dispatch_get_main_queue(),^{if(self.closed||![channel.label isEqual:@"ping"]){[channel close];return;}self.channel=channel;channel.delegate=self;[self dataChannelDidChangeState:channel];});}
- (void)peerConnection:(RTCPeerConnection *)p didChangeSignalingState:(RTCSignalingState)s {}
- (void)peerConnection:(RTCPeerConnection *)p didChangeIceConnectionState:(RTCIceConnectionState)s {}
- (void)peerConnection:(RTCPeerConnection *)p didGenerateIceCandidate:(RTCIceCandidate *)c {}
- (void)peerConnection:(RTCPeerConnection *)p didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)c {}
- (void)peerConnection:(RTCPeerConnection *)p didAddStream:(RTCMediaStream *)s {}
- (void)peerConnection:(RTCPeerConnection *)p didRemoveStream:(RTCMediaStream *)s {}
- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)p {}
@end
