#import "SLMediaSession.h"
#import "SLSignaling.h"
#import "SLPingPeer.h"
#import "SLMediaBridge.h"

@interface SLMediaSession ()
@property(nonatomic,weak) id<SLMediaProvider> media;
@property(nonatomic) BOOL strict;
@property(nonatomic,strong) SLSignaling *api;
@property(nonatomic,strong) SLPingPeer *peer;
@property(nonatomic,strong) SLMediaBridge *bridge,*screenBridge;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,strong) NSDictionary *snapshot;
@property(nonatomic,strong) NSMutableArray *events;
@property(nonatomic,copy) NSString *sessionId,*secret,*pendingJoin,*phase,*failure,*lastTransportState;
@property(nonatomic) NSUInteger generation,revision,answerRevision,lastRestartRevision,restartCount;
@property(nonatomic) BOOL busy,approved,approvalBusy,heartbeatBusy,negotiating,snapshotBusy,restartFailed;
@property(nonatomic) NSTimeInterval lastHeartbeat,lastError;
@end
@implementation SLMediaSession
- (instancetype)initWithMedia:(id<SLMediaProvider>)media {return [self initWithMedia:media hotspotOnly:YES];}
- (instancetype)initWithMedia:(id<SLMediaProvider>)media hotspotOnly:(BOOL)strict {if((self=[super init])){_strict=strict;_media=media;_events=[NSMutableArray array];_phase=@"idle";}return self;}
- (void)log:(NSString *)message {if(!message.length)return;[self.events addObject:[NSString stringWithFormat:@"%@ %@",NSDate.date,message]];if(self.events.count>50)[self.events removeObjectAtIndex:0];if(self.status)self.status(message);}
- (NSString *)authorization {return self.secret.length?[@"Device " stringByAppendingString:self.secret]:nil;}
- (NSString *)path:(NSString *)suffix {return [NSString stringWithFormat:@"/sessions/%@/%@",self.sessionId,suffix];}
- (void)failed:(NSError *)error code:(NSInteger)code {
    self.failure=error.localizedDescription?:@"Signaling unavailable";if(NSProcessInfo.processInfo.systemUptime-self.lastError>10){[self log:self.failure];self.lastError=NSProcessInfo.processInfo.systemUptime;}
    if(code==410||code==401){self.sessionId=nil;self.secret=nil;self.pendingJoin=nil;BOOL live=[self.snapshot[@"verified"] boolValue]&&self.peer.mediaOpen;self.phase=live?@"connected":@"failed";[self log:live?@"Signaling expired; verified local media channel retained.":@"Signaling expired without a verified local connection. Start a new pairing."];}
}
- (void)start {
    [self stop];NSUInteger generation=self.generation;self.revision=1;self.phase=@"gathering";self.failure=nil;self.lastHeartbeat=0;self.lastError=0;
    self.api=[[SLSignaling alloc]initWithBaseURL:[NSURL URLWithString:@"https://tesla4khmer.com/api/public/screenlink"]];self.peer=[[SLPingPeer alloc]initWithHotspotOnly:self.strict offerer:YES dataOnly:YES];[self.peer enableMediaChannel];
    self.bridge=[SLMediaBridge new];__weak SLMediaSession *weak=self;self.peer.status=^(NSString *message){[weak log:message];};__weak id<SLMediaProvider> media=self.media;
    self.bridge.stateProvider=^NSDictionary *{return [media state]?:@{};};self.bridge.resourceProvider=^NSDictionary *(NSString *identifier,NSString *range){return [media resource:identifier range:range]?:@{@"code":@503};};self.bridge.reportConsumer=^(NSDictionary *report){[media report:report];};
    self.bridge.send=^BOOL(NSData *data,BOOL binary){return [weak.peer sendMedia:data binary:binary];};self.bridge.bufferedAmount=^uint64_t{return weak.peer.mediaBufferedAmount;};
    self.peer.mediaMessage=^(NSData *data,BOOL binary){if(!binary)[weak.bridge receive:data];};self.peer.mediaOpened=^{[weak.bridge open];[weak log:@"WEBRTC MEDIA CHANNEL OPEN: original video/audio resources stay on the local peer connection."];};
    if(self.screenProvider){self.screenProvider(@"/screen/privacy",@{@"body":@{@"hidden":@YES,@"expectedRevision":@0}});[self.peer enableScreenChannel];self.screenBridge=[[SLMediaBridge alloc]initWithScreenProvider:self.screenProvider];self.screenBridge.send=^BOOL(NSData *data,BOOL binary){return [weak.peer sendScreen:data binary:binary];};self.screenBridge.bufferedAmount=^uint64_t{return weak.peer.screenBufferedAmount;};self.peer.screenMessage=^(NSData *data,BOOL binary){if(!binary)[weak.screenBridge receive:data];};self.peer.screenOpened=^{[weak.screenBridge open];[weak log:@"WEBRTC MAPS CHANNEL OPEN: phone screen starts hidden; use Show only after Google Maps is open."];};}
    [self.peer offerRestart:NO completion:^(NSString *sdp,NSString *gathering,NSError *error){if(generation!=self.generation)return;if(error){self.phase=@"failed";[self failed:error code:0];return;}self.phase=@"creating";
        [self.api call:@"POST" path:@"/sessions" authorization:nil body:@{@"sdpOffer":sdp,@"iceGathering":gathering} completion:^(NSInteger code,NSDictionary *body,NSError *failure){if(generation!=self.generation)return;if(failure){self.phase=@"failed";[self failed:failure code:code];return;}
            if(code!=201||![SLSignaling validIdentifier:body[@"sessionId"]]||![SLSignaling validSecret:body[@"deviceSecret"]]||[body[@"negotiationRevision"] unsignedIntegerValue]!=1){self.phase=@"failed";self.failure=@"Signaling response did not match contract v2.";return;}
            self.sessionId=body[@"sessionId"];self.secret=body[@"deviceSecret"];self.phase=@"waiting_for_viewer";[self log:@"Website session ready. Press Connect phone on the website, then approve the request here. No pairing number is used."];
            self.timer=[NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer){[weak poll];}];[NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];[self poll];
        }];
    }];
}
- (void)poll {
    if(!self.peer)return;NSUInteger generation=self.generation;
    if(!self.snapshotBusy){self.snapshotBusy=YES;[self.peer snapshot:^(NSDictionary *value){if(generation!=self.generation)return;self.snapshotBusy=NO;self.snapshot=value;NSString *transport=value[@"connectionState"];if(![transport isEqual:self.lastTransportState]){self.lastTransportState=transport;if([transport isEqual:@"failed"]){uint64_t requests=0,responses=0;for(NSDictionary *pair in value[@"iceChecks"]){requests+=[pair[@"requestsSent"] unsignedLongLongValue];responses+=[pair[@"responsesReceived"] unsignedLongLongValue];}[self log:[NSString stringWithFormat:@"LOCAL CONNECTION FAILED: %lu ICE pairs, %llu check requests, %llu responses; DTLS states %@. Copy diagnostics for the route details.",(unsigned long)[value[@"iceChecks"] count],(unsigned long long)requests,(unsigned long long)responses,[value[@"dtlsStates"] componentsJoinedByString:@", "]?:@"unknown"]];}}if([value[@"verified"] boolValue]&&self.peer.mediaOpen){self.phase=@"connected";self.failure=nil;self.restartFailed=NO;}else if(self.restartFailed||[value[@"connectionState"] isEqual:@"failed"])self.phase=@"failed";else if(self.approved)self.phase=@"connecting";
        if(self.sessionId.length&&!self.heartbeatBusy&&!self.negotiating&&NSProcessInfo.processInfo.systemUptime-self.lastHeartbeat>=10){self.lastHeartbeat=NSProcessInfo.processInfo.systemUptime;self.heartbeatBusy=YES;NSMutableDictionary *body=[NSMutableDictionary dictionary];for(NSString *key in @[@"connectionState",@"bytesSent",@"bytesReceived",@"selectedPair"])if(value[key])body[key]=value[key];body[@"state"]=[value[@"verified"] boolValue]?@"connected":@"heartbeat";body[@"negotiationRevision"]=@(self.revision);
            [self.api call:@"POST" path:[self path:@"state"] authorization:self.authorization body:body completion:^(NSInteger code,NSDictionary *reply,NSError *error){if(generation!=self.generation)return;self.heartbeatBusy=NO;if(error){[self failed:error code:code];return;}id revision=reply[@"restartRequestedRevision"];if([revision isKindOfClass:NSNumber.class]&&[revision unsignedIntegerValue]==self.revision)[self restart];}];
        }
    }];}
    if(!self.sessionId.length||self.busy||self.negotiating||self.approvalBusy)return;self.busy=YES;
    if(self.approved&&self.answerRevision==self.revision){self.busy=NO;return;}
    NSString *suffix=self.approved?@"answer":@"join-requests";NSUInteger revision=self.revision;
    [self.api call:@"GET" path:[self path:suffix] authorization:self.authorization body:nil completion:^(NSInteger code,NSDictionary *body,NSError *error){if(generation!=self.generation)return;self.busy=NO;if(error){[self failed:error code:code];return;}if(code==204)return;
        if(!self.approved){NSArray *requests=[body[@"requests"] isKindOfClass:NSArray.class]?body[@"requests"]:@[];self.pendingJoin=nil;for(id item in requests)if([item isKindOfClass:NSDictionary.class]&&[SLSignaling validIdentifier:item[@"joinId"]]){self.pendingJoin=item[@"joinId"];break;}self.phase=self.pendingJoin?@"pending_approval":@"waiting_for_viewer";return;}
        if(revision!=self.revision||[body[@"negotiationRevision"] unsignedIntegerValue]!=revision||![body[@"sdpAnswer"] isKindOfClass:NSString.class]||[body[@"sdpAnswer"] length]>262144)return;
        self.answerRevision=revision;[self.peer applyAnswer:body[@"sdpAnswer"] completion:^(NSError *failure){if(generation!=self.generation)return;if(failure){self.answerRevision=0;[self failed:failure code:0];}else [self log:@"Viewer answer applied. Waiting for verified local traffic and YouTube media."];}];
    }];
}
- (void)decision:(BOOL)approve {
    if(!self.pendingJoin.length||self.approvalBusy)return;self.approvalBusy=YES;NSUInteger generation=self.generation;
    [self.api call:@"POST" path:[self path:approve?@"approve":@"reject"] authorization:self.authorization body:@{@"joinId":self.pendingJoin} completion:^(NSInteger code,NSDictionary *body,NSError *error){if(generation!=self.generation)return;self.approvalBusy=NO;if(error){[self failed:error code:code];return;}self.approved=approve;self.pendingJoin=nil;if(approve){self.phase=@"connecting";}else self.phase=@"waiting_for_viewer";[self log:approve?@"Viewer approved on phone. Open YouTube and select ScreenLink through AirPlay.":@"Viewer rejected on phone."];[self poll];}];
}
- (void)restart {
    if(self.negotiating||!self.sessionId.length||self.lastRestartRevision==self.revision||self.restartCount>=2)return;self.lastRestartRevision=self.revision;self.restartCount++;self.negotiating=YES;NSUInteger generation=self.generation,next=self.revision+1;
    [self.peer offerRestart:YES completion:^(NSString *sdp,NSString *gathering,NSError *error){if(generation!=self.generation)return;if(error){self.negotiating=NO;self.restartFailed=YES;self.phase=@"failed";[self failed:error code:0];[self log:@"ICE restart failed; this request will not be replayed on every heartbeat. The local connection is not established."];return;}
        [self.api call:@"POST" path:[self path:@"offer"] authorization:self.authorization body:@{@"sdpOffer":sdp,@"iceGathering":gathering,@"negotiationRevision":@(next)} completion:^(NSInteger code,NSDictionary *body,NSError *failure){if(generation!=self.generation)return;self.negotiating=NO;if(failure){self.restartFailed=YES;self.phase=@"failed";[self failed:failure code:code];return;}self.restartFailed=NO;self.failure=nil;self.revision=next;self.answerRevision=0;self.lastHeartbeat=0;[self log:@"Local ICE restart offer published."];}];
    }];
}
- (NSDictionary *)control:(NSString *)command {
    if([command isEqual:@"start"])[self start];else if([command isEqual:@"approve"])[self decision:YES];else if([command isEqual:@"reject"])[self decision:NO];else if([command isEqual:@"stop"])[self stop];
    return @{@"phase":self.phase?:@"idle",@"approvalRequested":@(self.pendingJoin.length>0&&!self.approvalBusy),@"snapshot":self.snapshot?:@{},@"screenChannelOpen":@(self.peer.screenOpen),@"mediaChannelOpen":@(self.peer.mediaOpen),@"mediaActive":@(self.media.active),@"bytesForwarded":@(self.bridge.bytesForwarded),@"error":self.failure?:@"",@"events":self.events.copy};
}
- (void)stop {
    if(self.screenProvider)self.screenProvider(@"/screen/privacy",@{@"body":@{@"hidden":@YES,@"expectedRevision":@0}});[self.screenBridge stop];self.screenBridge=nil;self.generation++;[self.timer invalidate];self.timer=nil;[self.bridge stop];self.bridge=nil;[self.peer close];self.peer=nil;SLSignaling *api=self.api;
    if(self.sessionId.length&&self.secret.length)[api call:@"DELETE" path:[@"/sessions/" stringByAppendingString:self.sessionId] authorization:self.authorization body:nil completion:^(NSInteger code,NSDictionary *body,NSError *error){[api close];}];else [api close];
    self.api=nil;self.sessionId=nil;self.secret=nil;self.pendingJoin=nil;self.snapshot=nil;self.lastTransportState=nil;self.approved=NO;self.busy=NO;self.approvalBusy=NO;self.heartbeatBusy=NO;self.negotiating=NO;self.snapshotBusy=NO;self.restartFailed=NO;self.lastRestartRevision=0;self.restartCount=0;self.answerRevision=0;self.phase=@"idle";
}
@end

