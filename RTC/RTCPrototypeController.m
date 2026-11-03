#import "RTCPrototypeController.h"
#import "SLSignaling.h"
#import "SLPingPeer.h"
@interface RTCPrototypeController ()
@property(nonatomic,strong) SLSignaling *api;
@property(nonatomic,strong) SLPingPeer *peer;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,strong) UILabel *codeLabel,*stateLabel,*requestLabel;
@property(nonatomic,strong) UITextView *logView;
@property(nonatomic,strong) UIButton *startButton,*approveButton,*rejectButton;
@property(nonatomic,copy) NSString *sessionId,*secret,*pendingJoin;
@property(nonatomic,strong) NSDictionary *lastSnapshot;
@property(nonatomic) NSUInteger generation,revision,answerRevision,lastRestartRevision,restartCount;
@property(nonatomic) BOOL busy,approvalBusy,approved,negotiating,verified,heartbeatBusy;
@property(nonatomic) NSTimeInterval lastHeartbeat,lastErrorTime;
@end
@implementation RTCPrototypeController
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=UIColor.systemBackgroundColor;
    UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=10;stack.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],[stack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12],[stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18],[stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18]]];
    UILabel *title=[UILabel new];title.text=@"WebRTC video test · Milestone 2";title.font=[UIFont boldSystemFontOfSize:20];title.numberOfLines=0;[stack addArrangedSubview:title];
    UILabel *help=[UILabel new];help.numberOfLines=0;help.font=[UIFont systemFontOfSize:14];help.text=@"Connect the viewer to this iPhone’s Personal Hotspot. Keep this test screen open. Start the test, enter its code in the website’s WebRTC pairing page, then approve the request here. The website will show moving test video. Keep this screen open. Maps and YouTube still use the existing local player.";[stack addArrangedSubview:help];
    self.codeLabel=[UILabel new];self.codeLabel.text=@"— — — — — —";self.codeLabel.font=[UIFont monospacedDigitSystemFontOfSize:38 weight:UIFontWeightBold];self.codeLabel.textAlignment=NSTextAlignmentCenter;[stack addArrangedSubview:self.codeLabel];
    self.stateLabel=[UILabel new];self.stateLabel.text=@"Ready · tesla4khmer.com";self.stateLabel.numberOfLines=0;[stack addArrangedSubview:self.stateLabel];
    self.requestLabel=[UILabel new];self.requestLabel.numberOfLines=0;self.requestLabel.font=[UIFont systemFontOfSize:13];self.requestLabel.text=@"No viewer approval requested.";[stack addArrangedSubview:self.requestLabel];
    UIStackView *approval=[UIStackView new];approval.axis=UILayoutConstraintAxisHorizontal;approval.distribution=UIStackViewDistributionFillEqually;
    self.approveButton=[self button:@"Approve viewer" action:@selector(approve)];self.rejectButton=[self button:@"Reject" action:@selector(reject)];[approval addArrangedSubview:self.approveButton];[approval addArrangedSubview:self.rejectButton];[stack addArrangedSubview:approval];[self updateApproval];
    self.startButton=[self button:@"Start video test" action:@selector(startTest)];[stack addArrangedSubview:self.startButton];
    UIStackView *actions=[UIStackView new];actions.axis=UILayoutConstraintAxisHorizontal;actions.distribution=UIStackViewDistributionFillEqually;
    [actions addArrangedSubview:[self button:@"Stop test" action:@selector(stopTest)]];[actions addArrangedSubview:[self button:@"Copy diagnostics" action:@selector(copyDiagnostics)]];[actions addArrangedSubview:[self button:@"Done" action:@selector(done)]];[stack addArrangedSubview:actions];
    self.logView=[UITextView new];self.logView.editable=NO;self.logView.font=[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];[stack addArrangedSubview:self.logView];
    [self log:@"Native moving-video test (H.264 preferred, VP8 fallback), 640 × 360 up to 30 fps. No STUN/TURN configured, no microphone/camera/screen capture. Existing local viewer tokens are never passed to signaling. Pairing secrets and SDP are excluded from diagnostics."];
}
- (UIButton *)button:(NSString *)title action:(SEL)action {UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];[button setTitle:title forState:UIControlStateNormal];[button.heightAnchor constraintEqualToConstant:36].active=YES;[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return button;}
- (void)log:(NSString *)message {self.logView.text=[self.logView.text stringByAppendingFormat:@"%@ %@\n",NSDate.date,message];if(self.logView.text.length>10000)self.logView.text=[self.logView.text substringFromIndex:self.logView.text.length-8000];[self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length,0)];}
- (void)updateApproval {BOOL enabled=self.pendingJoin.length&&!self.approvalBusy;self.approveButton.enabled=enabled;self.rejectButton.enabled=enabled;}
- (NSString *)authorization {return self.secret.length?[@"Device " stringByAppendingString:self.secret]:nil;}
- (NSString *)path:(NSString *)suffix {return [NSString stringWithFormat:@"/sessions/%@/%@",self.sessionId,suffix];}
- (void)error:(NSError *)error {
    if(NSProcessInfo.processInfo.systemUptime-self.lastErrorTime>8){[self log:[NSString stringWithFormat:@"%@ (%@/%ld)",error.localizedDescription?:@"Signaling unavailable.",error.domain,(long)error.code]];self.lastErrorTime=NSProcessInfo.processInfo.systemUptime;}
    self.stateLabel.text=self.verified?@"Local ping verified · signaling currently unavailable":error.localizedDescription;
}
- (void)startTest {
    [self stopTest];self.generation++;NSUInteger generation=self.generation;self.startButton.enabled=NO;self.revision=1;self.answerRevision=0;self.approved=NO;self.lastHeartbeat=0;self.lastErrorTime=0;
    self.api=[[SLSignaling alloc]initWithBaseURL:[NSURL URLWithString:@"https://tesla4khmer.com/api/public/screenlink"]];self.peer=[[SLPingPeer alloc]initWithHotspotOnly:YES offerer:YES];__weak RTCPrototypeController *weak=self;
    self.peer.status=^(NSString *message){[weak log:message];};NSError *videoError=nil;if(![self.peer enableTestVideo:&videoError]){[self error:videoError];self.startButton.enabled=YES;return;}self.stateLabel.text=@"Gathering local hotspot candidates…";
    [self.peer offerRestart:NO completion:^(NSString *sdp,NSString *gathering,NSError *error){
        if(generation!=self.generation)return;if(error){[self error:error];self.startButton.enabled=YES;return;}
        self.stateLabel.text=@"Creating signaling session…";
        [self.api call:@"POST" path:@"/sessions" authorization:nil body:@{@"sdpOffer":sdp,@"iceGathering":gathering} completion:^(NSInteger code,NSDictionary *body,NSError *failure){
            if(generation!=self.generation)return;if(failure){[self error:failure];self.startButton.enabled=YES;return;}
            if(code!=201||![SLSignaling validIdentifier:body[@"sessionId"]]||![SLSignaling validSecret:body[@"deviceSecret"]]||![SLSignaling validCode:body[@"pairingCode"]]||[body[@"negotiationRevision"] unsignedIntegerValue]!=1){[self error:[NSError errorWithDomain:@"ScreenLink.Signaling" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Server session response did not match contract v2."}]];self.startButton.enabled=YES;return;}
            self.sessionId=body[@"sessionId"];self.secret=body[@"deviceSecret"];self.codeLabel.text=body[@"pairingCode"];self.stateLabel.text=@"Waiting for viewer · code expires in 3 minutes";[self log:@"Pairing session created. Enter the displayed code in the HTTPS viewer. Approval is required here before the offer is released."];
            self.timer=[NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer){[weak poll];}];[self poll];
        }];
    }];
}
- (void)poll {
    if(!self.peer)return;NSUInteger generation=self.generation;
    [self.peer snapshot:^(NSDictionary *snapshot){if(generation!=self.generation)return;self.lastSnapshot=snapshot;BOOL verified=[snapshot[@"verified"] boolValue];if(verified!=self.verified){self.verified=verified;[self log:verified?@"LOCAL P2P PING VERIFIED: real bidirectional data and a private hotspot route. Waiting for video frames to render on the viewer.":@"Ping verification is no longer fresh; checking the existing connection."];}
        if(verified)self.stateLabel.text=[snapshot[@"videoVerified"] boolValue]?[NSString stringWithFormat:@"VIDEO ACTIVE · %@ encoded · %@ rendered by viewer",snapshot[@"videoFramesEncoded"],snapshot[@"viewerFramesRendered"]]:@"Connected · waiting for viewer video frames";else if(self.approved)self.stateLabel.text=@"Connection/video not verified · checking local traffic";
        if(self.sessionId.length&&!self.heartbeatBusy&&NSProcessInfo.processInfo.systemUptime-self.lastHeartbeat>=10){self.lastHeartbeat=NSProcessInfo.processInfo.systemUptime;self.heartbeatBusy=YES;NSMutableDictionary *body=[NSMutableDictionary dictionary];for(NSString *key in @[@"connectionState",@"bytesSent",@"bytesReceived",@"selectedPair"])if(snapshot[key])body[key]=snapshot[key];body[@"state"]=verified?@"connected":@"heartbeat";body[@"negotiationRevision"]=@(self.revision);
            [self.api call:@"POST" path:[self path:@"state"] authorization:self.authorization body:body completion:^(NSInteger code,NSDictionary *reply,NSError *error){if(generation!=self.generation)return;self.heartbeatBusy=NO;if(error){[self error:error];if(code==410||code==401)[self signalingExpired];return;}id wanted=reply[@"restartRequestedRevision"];if([wanted isKindOfClass:NSNumber.class]&&[wanted unsignedIntegerValue]==self.revision)[self restart];}];
        }
    }];
    if(!self.sessionId.length||self.busy||self.negotiating)return;self.busy=YES;
    [self.api call:@"GET" path:[self path:@"join-requests"] authorization:self.authorization body:nil completion:^(NSInteger code,NSDictionary *body,NSError *error){
        if(generation!=self.generation)return;self.busy=NO;if(error){[self error:error];if(code==410||code==401)[self signalingExpired];return;}
        if(!self.approved){NSArray *requests=[body[@"requests"] isKindOfClass:NSArray.class]?body[@"requests"]:@[];NSString *join=nil;for(id value in requests)if([value isKindOfClass:NSDictionary.class]&&[SLSignaling validIdentifier:value[@"joinId"]]){join=value[@"joinId"];break;}
            self.pendingJoin=join;self.requestLabel.text=join?[NSString stringWithFormat:@"Viewer request %@. Approve only if you just entered this phone’s code.",[join substringToIndex:MIN(8,join.length)]]:@"No viewer approval requested.";[self updateApproval];
        }
        if(self.approved&&self.answerRevision!=self.revision)[self fetchAnswer:generation];
    }];
}
- (void)fetchAnswer:(NSUInteger)generation {
    if(self.busy)return;self.busy=YES;NSUInteger revision=self.revision;
    [self.api call:@"GET" path:[self path:@"answer"] authorization:self.authorization body:nil completion:^(NSInteger code,NSDictionary *body,NSError *error){
        if(generation!=self.generation)return;self.busy=NO;if(error){[self error:error];return;}if(code==204)return;
        if([body[@"negotiationRevision"] unsignedIntegerValue]!=revision||revision!=self.revision||![body[@"sdpAnswer"] isKindOfClass:NSString.class]||[body[@"sdpAnswer"] length]>262144)return;
        self.answerRevision=revision;[self.peer applyAnswer:body[@"sdpAnswer"] completion:^(NSError *failure){if(generation!=self.generation)return;if(failure){self.answerRevision=0;[self error:failure];}else{self.stateLabel.text=@"Answer applied · waiting for local ping";[self log:@"Current-revision answer applied. SDP exchange alone is not proof of connectivity."];}}];
    }];
}
- (void)decision:(BOOL)approve {
    if(!self.pendingJoin.length||self.approvalBusy)return;self.approvalBusy=YES;[self updateApproval];NSUInteger generation=self.generation;
    [self.api call:@"POST" path:[self path:approve?@"approve":@"reject"] authorization:self.authorization body:@{@"joinId":self.pendingJoin} completion:^(NSInteger code,NSDictionary *body,NSError *error){
        if(generation!=self.generation)return;self.approvalBusy=NO;if(error){[self error:error];}else{self.approved=approve;self.pendingJoin=nil;self.requestLabel.text=approve?@"Viewer approved. Waiting for its answer.":@"Viewer rejected. Waiting for another request.";[self log:approve?@"Viewer approved by the iPhone user.":@"Viewer request rejected by the iPhone user."];}
        [self updateApproval];[self poll];
    }];
}
- (void)approve {[self decision:YES];}
- (void)reject {[self decision:NO];}
- (void)restart {
    if(self.negotiating||!self.sessionId.length||self.lastRestartRevision==self.revision||self.restartCount>=2)return;self.lastRestartRevision=self.revision;self.restartCount++;self.negotiating=YES;NSUInteger generation=self.generation,next=self.revision+1;[self log:@"Viewer requested an ICE restart; preparing the next revision."];
    [self.peer offerRestart:YES completion:^(NSString *sdp,NSString *gathering,NSError *error){if(generation!=self.generation)return;if(error){self.negotiating=NO;[self error:error];return;}
        [self.api call:@"POST" path:[self path:@"offer"] authorization:self.authorization body:@{@"sdpOffer":sdp,@"iceGathering":gathering,@"negotiationRevision":@(next)} completion:^(NSInteger code,NSDictionary *body,NSError *failure){if(generation!=self.generation)return;self.negotiating=NO;if(failure){[self error:failure];return;}self.revision=next;self.answerRevision=0;self.lastHeartbeat=0;[self log:@"ICE restart offer published; waiting for the matching answer."];}];
    }];
}
- (void)signalingExpired {
    self.sessionId=nil;self.secret=nil;self.pendingJoin=nil;[self updateApproval];
    self.stateLabel.text=self.verified?@"Local ping remains active · signaling expired":@"Signaling expired · Stop and start a new pairing";
    [self log:@"Signaling credentials expired or were rejected. The existing peer connection was retained; a new pairing is needed for future negotiation."];
}
- (void)stopTest {
    self.generation++;[self.timer invalidate];self.timer=nil;[self.peer close];self.peer=nil;SLSignaling *api=self.api;
    if(self.sessionId.length&&self.secret.length){[api call:@"DELETE" path:[@"/sessions/" stringByAppendingString:self.sessionId] authorization:self.authorization body:nil completion:^(NSInteger code,NSDictionary *body,NSError *error){[api close];}];}else [api close];
    self.lastRestartRevision=0;self.restartCount=0;self.api=nil;self.sessionId=nil;self.secret=nil;self.pendingJoin=nil;self.approved=NO;self.busy=NO;self.heartbeatBusy=NO;self.approvalBusy=NO;self.negotiating=NO;self.verified=NO;self.lastSnapshot=nil;self.startButton.enabled=YES;self.codeLabel.text=@"— — — — — —";self.stateLabel.text=@"Video test stopped";self.requestLabel.text=@"No viewer approval requested.";[self updateApproval];
}
- (void)copyDiagnostics {NSDictionary *data=@{@"version":@"0.15.0",@"milestone":@"h264-moving-test-video",@"snapshot":self.lastSnapshot?:@{},@"events":self.logView.text?:@""};NSData *json=[NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingPrettyPrinted error:nil];UIPasteboard.generalPasteboard.string=[[NSString alloc]initWithData:json encoding:NSUTF8StringEncoding];[self log:@"Sanitized diagnostics copied; no SDP, pairing code, or role secrets included."];}
- (void)done {[self stopTest];[self dismissViewControllerAnimated:YES completion:nil];}
- (void)viewDidDisappear:(BOOL)animated {[super viewDidDisappear:animated];if(self.isBeingDismissed||self.navigationController.isBeingDismissed)[self stopTest];}
@end

