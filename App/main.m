#import <UIKit/UIKit.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import "Receiver.h"
#import "FloatingPreview.h"
#import "YouTubePiP.h"
#import "BackgroundSession.h"
#import "LocalVPN.h"
#import "ScreenLinkHomeView.h"
#import "SLDisconnectFlow.h"
#import "SLWidgetRoute.h"
#import "RTCPrototypeController.h"
#import "SLMediaController.h"
#import <ReplayKit/ReplayKit.h>
// Swift class has an explicit Objective-C runtime name; no generated header.
@protocol SLSessionDisconnectAPI
- (void)stopForDisconnectAll;
@end
@protocol SLPendingWidgetAPI
- (void)cancelPendingWidgetAction;
@end
@protocol SLWidgetActivityAPI
+ (void)updateStatus:(NSString *)status running:(BOOL)running;
+ (void)finish;
+ (NSString *)widgetDiagnostics;
@end
static void SLActivityStatus(NSString *status, BOOL running) {
 Class cls=NSClassFromString(@"SLWidgetActivity");
 if([cls respondsToSelector:@selector(updateStatus:running:)])[(id<SLWidgetActivityAPI>)cls updateStatus:status running:running];
}
static void SLActivityFinish(void) {
 Class cls=NSClassFromString(@"SLWidgetActivity");
 if([cls respondsToSelector:@selector(finish)])[(id<SLWidgetActivityAPI>)cls finish];
}
@interface Controller : UIViewController <NSNetServiceBrowserDelegate> { CVPixelBufferRef _lastPixel; }
@property(nonatomic,strong) Receiver *receiver;
@property(nonatomic,strong) NSNetServiceBrowser *networkProbe;
@property(nonatomic,strong) LocalVPN *vpn;
@property(nonatomic,strong) RPSystemBroadcastPickerView *broadcastPicker;
@property(nonatomic,strong) NSTimer *broadcastTimer;
@property(nonatomic) BOOL broadcastArmed;
@property(nonatomic) BOOL broadcastChecking;
@property(nonatomic,copy) NSString *broadcastToken;
@property(nonatomic,copy) NSString *lastBroadcastLine;
@property(nonatomic,copy) NSString *localViewerRequestID;
@property(nonatomic) BOOL quickStartPending;
@property(nonatomic) BOOL youtubePiPRequested;
@property(nonatomic) BOOL broadcastYouTubeOnly;
@property(nonatomic) BOOL mediaOnlyRestarting;
@property(nonatomic) NSUInteger mediaStartGeneration;
@property(nonatomic,strong) UILabel *localViewerStatus;
@property(nonatomic,strong) UIButton *localViewerApprove,*localViewerReject;
@property(nonatomic,strong) UITextView *text;
@property(nonatomic,strong) FloatingPreview *preview;
@property(nonatomic,strong) YouTubePiP *youtubePiP;
@property(nonatomic,strong) BackgroundSession *session;
@property(nonatomic,strong) UIView *previewSlot;
@property UIBackgroundTaskIdentifier backgroundTask;
@property(nonatomic,strong) UISegmentedControl *discoveryMode;
@property(nonatomic,strong) UISegmentedControl *videoProfile;
@property(nonatomic,strong) UILabel *bookmark;
@property(nonatomic,strong) UIScrollView *developerScroll;
@property(nonatomic,strong) UIStackView *developerStack;
@property(nonatomic,strong) ScreenLinkHomeView *dashboard;
@property(nonatomic,strong) NSArray<NSLayoutConstraint *> *previewConstraints;
@property(nonatomic,strong) SLDisconnectFlow *disconnectFlow;
@property(nonatomic) BOOL userDisconnected,disconnectNeedsAttention;
@property(nonatomic) NSUInteger previewIndex;
@property(nonatomic,strong) NSURLSession *disconnectSession;
@property(nonatomic,copy) NSString *homeFailure;
@property(nonatomic) BOOL discoveryPolicyDenied;
@end
@implementation Controller
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.backgroundTask=UIBackgroundTaskInvalid;self.userDisconnected=[NSUserDefaults.standardUserDefaults boolForKey:@"manualDisconnected"];self.disconnectFlow=[SLDisconnectFlow new];
    UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=6;stack.translatesAutoresizingMaskIntoConstraints=NO;
    UIScrollView *scroll=[UIScrollView new];self.developerScroll=scroll;self.developerStack=stack;scroll.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:scroll];[NSLayoutConstraint activateConstraints:@[[scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],[scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]]];[scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:8],[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-8],[stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],[stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],[stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32]]];
    UILabel *title=[UILabel new];title.text=@"ScreenLink · 0.20.31 / 68";title.font=[UIFont boldSystemFontOfSize:21];[stack addArrangedSubview:title];
    self.bookmark=[UILabel new];self.bookmark.font=[UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightMedium];self.bookmark.numberOfLines=0;self.bookmark.text=@"Connect your Mac to the hotspot, then start receiver.";[stack addArrangedSubview:self.bookmark];
    UILabel *help=[UILabel new];help.numberOfLines=0;help.font=[UIFont systemFontOfSize:13];help.text=@"YouTube: enable Personal Hotspot, tap Start YouTube · no recording, then choose ScreenLink in YouTube AirPlay. No screen broadcast or automatic PiP is started. Background time is controlled by iOS.";[stack addArrangedSubview:help];
    self.discoveryMode=[[UISegmentedControl alloc]initWithItems:@[@"iPhone VPN",@"Mac VPN",@"Native"]];
    id savedMode=[NSUserDefaults.standardUserDefaults objectForKey:@"discoveryMode"];
    NSInteger mode=savedMode?[savedMode integerValue]:SLDiscoveryPhoneVPN;
    self.discoveryMode.selectedSegmentIndex=2-MAX(0,MIN(2,mode));
    [self.discoveryMode addTarget:self action:@selector(discoveryChanged) forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:self.discoveryMode];
    self.videoProfile=[[UISegmentedControl alloc]initWithItems:@[@"Fast JPEG",@"Balanced JPEG",@"Sharp JPEG"]];
    id savedProfile=[NSUserDefaults.standardUserDefaults objectForKey:@"videoProfile"];
    self.videoProfile.selectedSegmentIndex=savedProfile?MAX(0,MIN(2,[savedProfile integerValue])):SLVideoFast;
    [self.videoProfile addTarget:self action:@selector(profileChanged) forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:self.videoProfile];
    self.previewSlot=[UIView new];self.previewSlot.backgroundColor=UIColor.blackColor;
    NSLayoutConstraint *previewHeight=[self.previewSlot.heightAnchor constraintEqualToConstant:100];previewHeight.priority=750;previewHeight.active=YES;
    [stack addArrangedSubview:self.previewSlot];
    self.broadcastPicker=[[RPSystemBroadcastPickerView alloc]initWithFrame:CGRectMake(0,0,50,50)];self.broadcastPicker.showsMicrophoneButton=NO;self.broadcastPicker.hidden=YES;[self.broadcastPicker.heightAnchor constraintEqualToConstant:50].active=YES;[stack addArrangedSubview:self.broadcastPicker];
    NSArray *labels=@[@"Start YouTube · no recording",@"Start YouTube + PiP · no recording",@"Check Home Screen widget",@"Maps + YouTube · screen broadcast",@"Copy YouTube website link",@"Maps + YouTube · website",@"WebRTC moving-video test",@"Maps + YouTube · prepare screen broadcast",@"Start YouTube video-only",@"Start receiver",@"Copy viewer link",@"Start background session (iOS controlled)",@"Start floating preview",@"Show browser links",@"Copy test log",@"Refresh discovery",@"Stop sharing"];
    NSArray *actions=@[NSStringFromSelector(@selector(startYouTubeNoRecording)),NSStringFromSelector(@selector(startYouTubePiP)),NSStringFromSelector(@selector(widgetDiagnostics)),NSStringFromSelector(@selector(quickStart)),NSStringFromSelector(@selector(youtubeOnlyWebsite)),NSStringFromSelector(@selector(youtubeWebsite)),NSStringFromSelector(@selector(rtcPrototype)),NSStringFromSelector(@selector(prepareBroadcast)),NSStringFromSelector(@selector(startMedia)),NSStringFromSelector(@selector(start)),NSStringFromSelector(@selector(copyViewer)),NSStringFromSelector(@selector(startSession)),NSStringFromSelector(@selector(startFloating)),NSStringFromSelector(@selector(links)),NSStringFromSelector(@selector(copyLog)),NSStringFromSelector(@selector(refreshDiscovery)),NSStringFromSelector(@selector(stop))];
    for(NSUInteger i=0;i<labels.count;i++) {
        UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];[button setTitle:labels[i] forState:UIControlStateNormal];[button.heightAnchor constraintEqualToConstant:34].active=YES;
        [button addTarget:self action:NSSelectorFromString(actions[i]) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:button];
    }
    UIStackView *vpnRow=[UIStackView new];vpnRow.axis=UILayoutConstraintAxisHorizontal;vpnRow.distribution=UIStackViewDistributionFillEqually;
    for(NSString *name in @[@"Connect built-in VPN",@"Disconnect VPN"]){UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];[button setTitle:name forState:UIControlStateNormal];[button.heightAnchor constraintEqualToConstant:34].active=YES;[button addTarget:self action:[name hasPrefix:@"Connect"]?@selector(connectVPN):@selector(disconnectVPN) forControlEvents:UIControlEventTouchUpInside];[vpnRow addArrangedSubview:button];}
    [stack insertArrangedSubview:vpnRow atIndex:3];
    for(NSString *title in @[@"Experimental virtual-IP probe",@"Route probe status"]){UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];[button setTitle:title forState:UIControlStateNormal];[button.heightAnchor constraintEqualToConstant:34].active=YES;[button addTarget:self action:[title hasPrefix:@"Experimental"]?@selector(startRouteProbe):@selector(routeProbeStatus) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:button];}
    self.localViewerStatus=[UILabel new];self.localViewerStatus.numberOfLines=0;self.localViewerStatus.font=[UIFont systemFontOfSize:13];self.localViewerStatus.text=@"Local viewer: not connected. HTTPS: https://car.tesla4khmer.com/ ; HTTP fallback: http://240.3.3.3:8080/";[stack addArrangedSubview:self.localViewerStatus];
    for(NSString *name in @[@"Approve local viewer",@"Reject local viewer",@"Disconnect local viewer"]){UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];[button setTitle:name forState:UIControlStateNormal];[button.heightAnchor constraintEqualToConstant:34].active=YES;[button addTarget:self action:[name hasPrefix:@"Approve"]?@selector(approveLocalViewer):([name hasPrefix:@"Reject"]?@selector(rejectLocalViewer):@selector(disconnectLocalViewer)) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:button];if([name hasPrefix:@"Approve"]){self.localViewerApprove=button;button.enabled=NO;}else if([name hasPrefix:@"Reject"]){self.localViewerReject=button;button.enabled=NO;}}
    self.text=[UITextView new];self.text.editable=NO;[self.text.heightAnchor constraintEqualToConstant:230].active=YES;self.text.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];[stack addArrangedSubview:self.text];
    self.broadcastArmed=[NSUserDefaults.standardUserDefaults boolForKey:@"screenBroadcastArmed"];
    self.receiver=[Receiver new];__weak Controller *weak=self;
    self.vpn=[LocalVPN new];self.vpn.status=^(NSString *message){Controller *owner=weak;if([message hasPrefix:@"Built-in VPN failed"]||[message hasPrefix:@"VPN connection timed out"]||[message hasPrefix:@"VPN extension is missing"])owner.homeFailure=@"Couldn’t connect. Check the iOS VPN prompt or open Developer for details, then try Start again.";[owner append:message];};
    self.receiver.status=^(NSString *message){Controller *owner=weak;if([message hasPrefix:@"AIRPLAY DISCOVERY BLOCKED"])owner.discoveryPolicyDenied=YES;else if([message hasPrefix:@"Local proxy address verified:"])owner.discoveryPolicyDenied=NO;if([message hasPrefix:@"Local HTTPS not started"])owner.homeFailure=@"The secure website connection is unavailable. Check Developer before continuing.";[owner append:message];};
    self.receiver.preview=^(CVPixelBufferRef pixel){[weak receivedPixel:pixel];};
    self.receiver.videoProfile=self.videoProfile.selectedSegmentIndex;
    self.session=[BackgroundSession new];
    self.session.status=^(NSString *message){[weak append:message];};
    self.session.videoIsLive=^BOOL{return weak.receiver.videoIsLive;};
    self.session.activityChanged=^(BOOL active){Controller *owner=weak;if(!owner)return;if(owner.receiver.mediaOnly&&!owner.youtubePiP.active){owner.localViewerStatus.text=active?@"READY":@"Background session ended. Return to ScreenLink.";SLActivityStatus(active?@"READY":@"Return to ScreenLink",active);}owner.receiver.compressedOnlyInBackground=!owner.preview.active;if(active)[owner endGrace];};
    self.session.ended=^{
        Controller *owner=weak;if(!owner || !owner.receiver.isRunning)return;
        [owner append:@"BACKGROUND RUNTIME ENDED: receiver, viewer link and media session retained. iOS may suspend this app without PiP. Returning to ScreenLink resumes the existing receiver; Start is not required to rebuild it."];
        if(!owner.preview.active&&!owner.youtubePiP.active && UIApplication.sharedApplication.applicationState==UIApplicationStateBackground)[owner beginGrace];
    };
    [self append:@"Version 0.20.31 / build 68: Minimal fullscreen YouTube car page; quality, volume, sound preset, pause and seeking controlled on the phone. Video selection remains in YouTube. Decoder, canvas timing, audio scheduler and AirPlay media delivery unchanged. Policy-denied discovery retries on foreground or Start; no repeated denied-permission loop. No recording. Original website disconnect cause remains unconfirmed. Previous changes: Removes saved/offline website; retires old browser cache. Connection interruptions retain buffered media while reauthorizing; same-browser proof survives reload/hotspot peer changes. No HTTPS watchdog. Build64 playback, audio, PiP, VPN and widgets retained. Physical Tesla reconnection still requires validation. Previous changes: Light/dark glass home and website; user car decoration stops before sharing; expanded widget and Dynamic Island app-opening controls. Build 63 playback, audio, AirPlay and PiP recovery preserved. Previous changes: Repair dead AirPlay and web listeners in place on foreground; restore the selected real-media PiP mode after returning without recording or clearing viewer authorization. Retain newest late decoded frame and preserve decoder references during timestamp catch-up. Retains build 60: New client home and coordinated icon/cover; full technical controls remain in Developer. Disconnect All stops sharing, background tasks and only ScreenLink VPN, with confirmation and cancelled pending starts. Home Screen controls use explicit app-opening Start/Disconnect deep links. All extension identifiers are preserved. Retains build 59: Recovers defunct Bonjour handles on foreground without restarting healthy AirPlay listeners or viewer authorization. Real-media PiP stall recovery is bounded and never reopens dismissed PiP. Video-only catch-up preserves the audio decoder and clock under delayed video decoding. Bounded playlist snapshots replace permanent registry exhaustion. Physical-device background endurance still requires testing. Retains build 57: The explicit Start YouTube + PiP button starts the receiver without recording and remembers a PiP request before AirPlay arrives. Open YouTube, select ScreenLink, and return once to ScreenLink to let real media prepare the movable PiP. No dummy video is generated. Retains the PiP controller across gaps between songs, pauses while the source is absent, and replaces actual media on a new epoch. Coexistence with YouTube AirPlay still needs physical-device verification. No fixed background duration is promised. Retains build 56: Connection request deadlines now cover response bodies as well as headers, preventing interrupted JSON responses from hanging automatic discovery and health polling. Cached-page restoration now restarts discovery; late approval replies cannot revive abandoned pages. Repeated YouTube Start preserves an already-running receiver. Background button no longer implies a reserved 30-minute grant. Auto source quality accepts lower resolutions up to 1080p. Viewer re-authenticates after sustained connection loss without interrupting healthy buffered playback, resets stale Maps state on a new connection, and supports authenticated hotspot peer changes. Adds elapsed-time background expiration diagnostics. YouTube-only starts the app-owned AirPlay receiver without ReplayKit recording. Removes the recording-based YouTube shortcut from build 52. Copy YouTube website link never opens recording. PiP stays optional and manual. The existing timed task is controlled by iOS and may end early; returning to ScreenLink resumes its receiver. No unlimited background runtime is promised. Maps screen broadcast remains a separate, explicitly labelled choice. Retains inline Tesla buttons, HD range downloads and in-place transport retries. Audio and Maps engines are unchanged."];
    self.broadcastTimer=[NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(probeBroadcast) userInfo:nil repeats:YES];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(background) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(active) name:UIApplicationDidBecomeActiveNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(foreground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [self buildHome];[self widgetDiagnostics];if(self.userDisconnected)[self disconnectAll];
}
- (void)ensurePolling {
 if(!self.broadcastTimer)self.broadcastTimer=[NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(probeBroadcast) userInfo:nil repeats:YES];
}
- (BOOL)permitExplicitStart {
 if(self.disconnectFlow.running||self.vpn.disconnecting){[self append:@"Disconnect is still in progress. Wait for confirmation before starting."];return NO;}
 self.userDisconnected=NO;self.disconnectNeedsAttention=NO;self.homeFailure=nil;[NSUserDefaults.standardUserDefaults setBool:NO forKey:@"manualDisconnected"];[self ensurePolling];return YES;
}
- (void)buildHome {
 self.previewIndex=[self.developerStack.arrangedSubviews indexOfObject:self.previewSlot];
 UIButton *back=[UIButton buttonWithType:UIButtonTypeSystem];[back setTitle:@"‹ Home" forState:UIControlStateNormal];back.accessibilityIdentifier=@"developer.home";[back.heightAnchor constraintGreaterThanOrEqualToConstant:44].active=YES;[back addTarget:self action:@selector(showHome) forControlEvents:UIControlEventTouchUpInside];[self.developerStack insertArrangedSubview:back atIndex:0];self.previewIndex++;
 self.dashboard=[ScreenLinkHomeView new];self.dashboard.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:self.dashboard];
 [NSLayoutConstraint activateConstraints:@[[self.dashboard.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],[self.dashboard.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],[self.dashboard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[self.dashboard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]]];
 __weak Controller *weak=self;
 self.dashboard.playerAction=^(NSDictionary *request){[weak phonePlayerControl:request];};
 self.dashboard.startAction=^{[weak startHome];};self.dashboard.disconnectAction=^{[weak disconnectAll];};self.dashboard.developerAction=^{[weak showDeveloper];};self.dashboard.copyAction=^{[weak youtubeOnlyWebsite];};
 [self showHome];
}
- (void)phonePlayerControl:(NSDictionary *)command {
 if(self.userDisconnected||self.disconnectFlow.running){[self append:@"Start ScreenLink before using the car player controls."];return;}
 if(self.receiver.isRunning&&self.receiver.mediaOnly){
  if([self.receiver applyPhoneViewerControl:command])[self.dashboard showPlayerState:[self.receiver nativeMediaState]];
  else [self append:@"Car player control unavailable. Connect YouTube AirPlay and choose a video first."];
  return;
 }
 if(!self.broadcastArmed){[self append:@"Start ScreenLink before using the car player controls."];return;}
 NSUInteger generation=self.mediaStartGeneration;
 NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:8080/local/viewer/playback"]];request.HTTPMethod=@"POST";request.timeoutInterval=2;
 [request setValue:@"app" forHTTPHeaderField:@"X-ScreenLink-Control"];[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];request.HTTPBody=[NSJSONSerialization dataWithJSONObject:command options:0 error:nil];
 [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){dispatch_async(dispatch_get_main_queue(),^{
  if(generation!=self.mediaStartGeneration||self.userDisconnected)return;
  if(error||[(NSHTTPURLResponse *)response statusCode]!=200){[self append:@"Car player control was not confirmed. Check the receiver and choose a YouTube video."];return;}
  id state=data.length?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
  if([state isKindOfClass:NSDictionary.class])[self.dashboard showPlayerState:state];
 });}] resume];
}
- (void)showHome {
 [self loadViewIfNeeded];if(!self.dashboard.hidden&&self.previewSlot.superview==self.dashboard.previewHost){[self updateHome];return;}self.developerScroll.hidden=YES;self.dashboard.hidden=NO;
 [NSLayoutConstraint deactivateConstraints:self.previewConstraints?:@[]];[self.developerStack removeArrangedSubview:self.previewSlot];[self.previewSlot removeFromSuperview];
 self.previewSlot.translatesAutoresizingMaskIntoConstraints=NO;[self.dashboard.previewHost addSubview:self.previewSlot];
 self.previewConstraints=@[[self.previewSlot.topAnchor constraintEqualToAnchor:self.dashboard.previewHost.topAnchor],[self.previewSlot.bottomAnchor constraintEqualToAnchor:self.dashboard.previewHost.bottomAnchor],[self.previewSlot.leadingAnchor constraintEqualToAnchor:self.dashboard.previewHost.leadingAnchor],[self.previewSlot.trailingAnchor constraintEqualToAnchor:self.dashboard.previewHost.trailingAnchor]];[NSLayoutConstraint activateConstraints:self.previewConstraints];[self updateHome];
}
- (void)showDeveloper {
 [NSLayoutConstraint deactivateConstraints:self.previewConstraints?:@[]];self.previewConstraints=nil;[self.previewSlot removeFromSuperview];[self.developerStack insertArrangedSubview:self.previewSlot atIndex:MIN(self.previewIndex,self.developerStack.arrangedSubviews.count)];
 self.dashboard.hidden=YES;self.developerScroll.hidden=NO;
}
- (void)updateHome {
 if(!self.dashboard)return;
 BOOL busy=self.disconnectFlow.running||self.mediaOnlyRestarting;
 NSString *status=@"Ready to connect",*detail=@"Turn on Personal Hotspot, then tap Start.";
 BOOL sharing=self.receiver.isRunning||self.broadcastArmed;
 if(self.disconnectFlow.running){status=@"Disconnecting…";detail=@"Stopping sharing and ScreenLink VPN. Please keep the app open.";}
 else if(self.userDisconnected){status=self.disconnectNeedsAttention?@"Check disconnect status":@"Disconnected";detail=self.disconnectNeedsAttention?@"Sharing has stopped. VPN or screen broadcast could not be confirmed. Open Developer for details, or try Disconnect All again.":@"Sharing and ScreenLink VPN are off. Tap Start whenever you’re ready.";}
 else if(self.discoveryPolicyDenied){status=@"AirPlay discovery blocked";detail=@"iOS denied local-network discovery. Check Settings → Privacy & Security → Local Network → ScreenLink, then return and tap Start to retry.";}
 else if(self.homeFailure){status=@"Connection needs attention";detail=self.homeFailure;}
 else if(self.mediaOnlyRestarting){status=@"Getting ready…";detail=@"Approve any iOS connection request to continue.";}
 else if(self.broadcastArmed){status=@"Screen broadcast selected";detail=@"Manage this screen-sharing mode in Developer.";}
 else if(self.youtubePiP.active){status=@"Floating video active";detail=@"Your floating video is active. Keep the viewer on your hotspot.";}
 else if(self.receiver.isRunning){status=@"Ready for AirPlay";detail=@"Choose ScreenLink in YouTube’s AirPlay menu, then return here once to prepare PiP.";}
 [self.dashboard showStatus:status detail:detail busy:busy sharing:sharing disconnecting:self.disconnectFlow.running attention:self.disconnectNeedsAttention||self.discoveryPolicyDenied||self.homeFailure.length>0];
}
- (void)startHome {
 if(![self permitExplicitStart])return;[self startYouTubePiP];[self updateHome];
}
- (void)stopOwnBroadcast:(NSUInteger)remaining completion:(void (^)(BOOL))completion {
 NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:8080/local/owner"]];request.timeoutInterval=1;request.cachePolicy=NSURLRequestReloadIgnoringLocalCacheData;[request setValue:@"app" forHTTPHeaderField:@"X-ScreenLink-Control"];
 [[self.disconnectSession dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){dispatch_async(dispatch_get_main_queue(),^{
  if(!self.disconnectFlow.running)return;
  if(error.code==NSURLErrorCannotConnectToHost){completion(YES);return;}
  NSDictionary *owner=data.length?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;
  if(!error&&[(NSHTTPURLResponse *)response statusCode]==200&&[owner[@"broadcast"] boolValue]){
   NSMutableURLRequest *stop=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:8080/local/broadcast/stop"]];stop.HTTPMethod=@"POST";stop.timeoutInterval=1;[stop setValue:@"app" forHTTPHeaderField:@"X-ScreenLink-Control"];[[self.disconnectSession dataTaskWithRequest:stop] resume];
  }
  if(!remaining){[self append:@"DISCONNECT NOT CONFIRMED: screen broadcast listener still present or loopback check unavailable. Stop any active ScreenLink broadcast in Control Center."];completion(NO);return;}
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.25*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self stopOwnBroadcast:remaining-1 completion:completion];});
 });}] resume];
}
- (void)stopPresentedSessions:(UIViewController *)controller {
 if(!controller)return;
 for(UIViewController *child in controller.childViewControllers)[self stopPresentedSessions:child];
 [self stopPresentedSessions:controller.presentedViewController];
 if([controller respondsToSelector:@selector(stopForDisconnectAll)])[(id<SLSessionDisconnectAPI>)controller stopForDisconnectAll];
}
- (void)disconnectAll {
 [self loadViewIfNeeded];if(self.disconnectFlow.running)return;
 id delegate=UIApplication.sharedApplication.delegate;if([delegate respondsToSelector:@selector(cancelPendingWidgetAction)])[(id<SLPendingWidgetAPI>)delegate cancelPendingWidgetAction];
 self.userDisconnected=YES;self.disconnectNeedsAttention=NO;self.homeFailure=nil;[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"manualDisconnected"];
 self.disconnectSession=[NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
 [self.disconnectFlow runStopSources:^{
  self.quickStartPending=NO;self.broadcastChecking=NO;[self stopPresentedSessions:self.presentedViewController];[self stop];[self.broadcastTimer invalidate];self.broadcastTimer=nil;
  self.networkProbe.delegate=nil;[self.networkProbe stop];self.networkProbe=nil;
  [self dismissViewControllerAnimated:YES completion:nil];[self showHome];[self updateHome];
 } broadcast:^(void(^reply)(BOOL)){[self stopOwnBroadcast:20 completion:reply];}
 vpn:^(void(^reply)(BOOL)){[self.vpn disconnectWithCompletion:reply];}
 completion:^(BOOL confirmed){
  [self.disconnectSession invalidateAndCancel];self.disconnectSession=nil;
  self.disconnectNeedsAttention=!confirmed;self.localViewerStatus.text=confirmed?@"Disconnected":@"Disconnect not fully confirmed";
  [self append:confirmed?@"DISCONNECT ALL CONFIRMED: sharing, PiP, viewer sessions, background tasks and ScreenLink VPN stopped. Auto-resume is disabled; saved VPN configuration retained.":@"Sharing stopped; complete disconnect could not be confirmed. Check the VPN/broadcast status before starting again."];
  [self updateHome];
 }];
 [self updateHome];
}
- (void)requestLocalNetwork {
    if(self.userDisconnected||self.networkProbe||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    self.networkProbe=[NSNetServiceBrowser new];self.networkProbe.delegate=self;
    [self.networkProbe searchForServicesOfType:@"_airplay._tcp." inDomain:@"local."];
    [self append:@"LOCAL NETWORK PREFLIGHT: allow ScreenLink Local Network access if iOS asks before leaving this app. A background broadcast extension cannot show that permission alert. This browse is not proof of Tesla connectivity."];
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary<NSString *,NSNumber *> *)error {
    [self append:[NSString stringWithFormat:@"LOCAL NETWORK PREFLIGHT FAILED: %@. Check iPhone Settings → Privacy & Security → Local Network → ScreenLink. No permission grant is inferred.",error]];
}
- (void)append:(NSString *)s { if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self append:s];});return;}[self updateHome];self.text.text=[self.text.text stringByAppendingFormat:@"\n%@ %@\n",[NSDate date],s];if(self.text.text.length>24000)self.text.text=[self.text.text substringFromIndex:self.text.text.length-18000];[self.text scrollRangeToVisible:NSMakeRange(self.text.text.length,0)]; }
- (void)widgetDiagnostics {
 Class cls=NSClassFromString(@"SLWidgetActivity");
 if([cls respondsToSelector:@selector(widgetDiagnostics)])[self append:[(id<SLWidgetActivityAPI>)cls widgetDiagnostics]];
 else [self append:@"Widget diagnostic bridge missing from signed app."];
}
- (void)prepareYouTubePiP {
 if(!self.youtubePiPRequested||!self.receiver.mediaOnly||!self.receiver.isRunning)return;
 NSDictionary *state=[self.receiver nativeMediaState];
 if(!self.youtubePiP&&UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
 if(!self.youtubePiP){
  YouTubePiP *view=[[YouTubePiP alloc]initWithFrame:self.previewSlot.bounds];view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;self.youtubePiP=view;[self.previewSlot addSubview:view];
  __weak Controller *weak=self;view.status=^(NSString *message){[weak append:message];};
  view.activityChanged=^(BOOL active){Controller *owner=weak;if(!owner)return;if(active){[owner endGrace];[owner.session finish];SLActivityStatus(@"PLAYING · PiP",YES);owner.localViewerStatus.text=@"PiP ACTIVE";}else{if(!owner.session.active&&UIApplication.sharedApplication.applicationState==UIApplicationStateBackground)[owner beginGrace];}};
 }
 [self.youtubePiP updateState:state];
}
- (void)startYouTubePiP {
 if(![self permitExplicitStart])return;
 if(!self.receiver.isRunning||!self.receiver.mediaOnly){[self startYouTubeNoRecordingWithPiP:YES];return;}
 if(![self.receiver resumeListenersIfNeeded]){self.localViewerStatus.text=@"Receiver connection recovery failed. Copy test log.";return;}
 [self.receiver refreshDiscovery];
 self.youtubePiPRequested=YES;
 [self prepareYouTubePiP];
 if(!self.youtubePiP){[self append:@"Return to ScreenLink to prepare its PiP window. No recording starts."];return;}
 [self.youtubePiP startFloating];
}
- (void)startFromWidget {[self loadViewIfNeeded];[self showHome];[self startHome];}
- (void)startYouTubeNoRecording {[self startYouTubeNoRecordingWithPiP:NO];}
- (void)startYouTubeNoRecordingWithPiP:(BOOL)requestPiP {if(![self permitExplicitStart])return;if(self.mediaOnlyRestarting)return;if(self.receiver.isRunning&&self.receiver.mediaOnly){if(requestPiP){[self startYouTubePiP];return;}self.youtubePiPRequested=NO;[self.youtubePiP reset];[self.youtubePiP removeFromSuperview];self.youtubePiP=nil;[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"resumeYouTubeOnReturn"];[self resumeYouTubeOnReturn];[self append:@"YouTube receiver is already running. Keeping its AirPlay and viewer sessions; no recording or PiP is started."];return;}self.mediaOnlyRestarting=YES;NSUInteger generation=self.mediaStartGeneration;[self requestLocalNetwork];self.quickStartPending=NO;[self.vpn connectRouteProbe:^(BOOL ok){if(generation!=self.mediaStartGeneration||!self.mediaOnlyRestarting)return;if(!ok){self.mediaOnlyRestarting=NO;return;}[self stop];self.youtubePiPRequested=requestPiP;self.mediaOnlyRestarting=YES;[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"resumeYouTubeOnReturn"];self.discoveryMode.selectedSegmentIndex=0;[self startMediaOnlyWhenFree:20 generation:self.mediaStartGeneration];}];}
- (void)resumeYouTubeOnReturn {
 if(self.userDisconnected||self.disconnectFlow.running||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive||self.mediaOnlyRestarting||![NSUserDefaults.standardUserDefaults boolForKey:@"resumeYouTubeOnReturn"])return;
 if(!self.receiver.isRunning||!self.receiver.mediaOnly){BOOL resumePiP=self.youtubePiPRequested;[self startYouTubeNoRecordingWithPiP:resumePiP];return;}
 if(![self.receiver resumeListenersIfNeeded]){self.localViewerStatus.text=@"Restoring receiver connection…";return;}
 if(self.youtubePiPRequested){[self prepareYouTubePiP];[self.youtubePiP resumeAfterForeground];}
 [self.receiver refreshDiscovery];
 if((self.youtubePiP.active||self.session.active)&&self.vpn.connected)return;
 self.mediaOnlyRestarting=YES;NSUInteger generation=self.mediaStartGeneration;[self.vpn connectRouteProbe:^(BOOL ok){if(generation!=self.mediaStartGeneration)return;self.mediaOnlyRestarting=NO;if(!ok)return;[self.receiver refreshDiscovery];if(!self.youtubePiP.active&&!self.session.active){self.session.allowWaitingForVideo=YES;[self.session start];}self.localViewerStatus.text=self.youtubePiP.active?@"PiP ACTIVE":(self.session.active?@"READY":@"Restarting background session…");[self append:@"RESUMING YOUTUBE: foreground return requested a new timed session. The existing receiver, viewer authorization and media state are preserved. If YouTube released AirPlay, select ScreenLink VPN Phone again in YouTube."];}];
}
- (void)startMediaOnlyWhenFree:(NSUInteger)attempts generation:(NSUInteger)generation {
 NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:8080/local/owner"]];[request setValue:@"app" forHTTPHeaderField:@"X-ScreenLink-Control"];request.timeoutInterval=1;
 [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){dispatch_async(dispatch_get_main_queue(),^{
 if(generation!=self.mediaStartGeneration||!self.mediaOnlyRestarting)return;
 if(!error&&[(NSHTTPURLResponse *)response statusCode]==200){if(attempts)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self startMediaOnlyWhenFree:attempts-1 generation:generation];});else {self.mediaOnlyRestarting=NO;self.localViewerStatus.text=@"Stop the previous broadcast and retry.";}return;}
 [self.receiver prepareMediaOnly];[self startReceiver];self.mediaOnlyRestarting=NO;if(!self.receiver.isRunning){self.localViewerStatus.text=@"Receiver could not start.";return;}[self.receiver authorizeNextLocalViewer];self.session.allowWaitingForVideo=YES;[self.session start];self.localViewerStatus.text=self.session.active?@"READY":@"Wait for BACKGROUND SESSION ACTIVE before opening YouTube.";UIPasteboard.generalPasteboard.string=@"https://car.tesla4khmer.com/video";[self append:@"YOUTUBE ONLY: no ReplayKit recording, no screen encoder. Open https://car.tesla4khmer.com/video. Website connects automatically. This uses a bounded background session; if iOS rejects or ends it, return to ScreenLink to resume. PiP is optional and user requested. There is no automatic recording fallback."];if(self.youtubePiPRequested){[self prepareYouTubePiP];[self.youtubePiP startFloating];}
 });}] resume];
}
- (void)quickStart {
 if(![self permitExplicitStart])return;NSUInteger generation=self.mediaStartGeneration;
 [self requestLocalNetwork];self.youtubePiPRequested=NO;[self.youtubePiP reset];[self.youtubePiP removeFromSuperview];self.youtubePiP=nil;
 [self.vpn connectRouteProbe:^(BOOL ok){if(!ok||generation!=self.mediaStartGeneration||self.userDisconnected)return;self.quickStartPending=YES;self.broadcastYouTubeOnly=NO;[self prepareBroadcast];
  for(UIView *view in self.broadcastPicker.subviews)if([view isKindOfClass:UIButton.class])[(UIButton *)view sendActionsForControlEvents:UIControlEventTouchUpInside];
 }];
}
- (void)youtubeOnlyWebsite {UIPasteboard.generalPasteboard.string=@"https://car.tesla4khmer.com/video";[self append:@"YouTube viewer link copied: https://car.tesla4khmer.com/video. Start YouTube · no recording on this phone. Copying the link never starts recording."];}
- (void)youtubeWebsite {[self presentWebsite:NO];}
- (void)presentWebsite:(BOOL)youtubeOnly {if(youtubeOnly){[self youtubeOnlyWebsite];return;}[self requestLocalNetwork];[self prepareBroadcast];SLMediaController *controller=[SLMediaController new];controller.youtubeOnly=youtubeOnly;controller.broadcastExtensionIdentifier=self.broadcastPicker.preferredExtension;controller.modalPresentationStyle=UIModalPresentationFullScreen;[self presentViewController:controller animated:YES completion:nil];}
- (void)rtcPrototype {[self requestLocalNetwork];RTCPrototypeController *controller=[RTCPrototypeController new];controller.modalPresentationStyle=UIModalPresentationFullScreen;[self presentViewController:controller animated:YES completion:nil];}
- (void)discoveryChanged {
    if(self.receiver.isRunning){self.discoveryMode.selectedSegmentIndex=2-self.receiver.discoveryMode;[self append:@"Stop sharing before changing discovery mode."];return;}
    [NSUserDefaults.standardUserDefaults setInteger:2-self.discoveryMode.selectedSegmentIndex forKey:@"discoveryMode"];
}
- (void)profileChanged {
    [NSUserDefaults.standardUserDefaults setInteger:self.videoProfile.selectedSegmentIndex forKey:@"videoProfile"];
    self.receiver.videoProfile=self.videoProfile.selectedSegmentIndex;
}
- (void)refreshDiscovery { [self.receiver refreshDiscovery]; }
- (void)prepareBroadcast {
    if(![self permitExplicitStart])return;NSUInteger generation=self.mediaStartGeneration;
    if(@available(iOS 16.0,*)){}else{[self append:@"The screen broadcast encoder requires iOS 16 or later. Normal AirPlay remains available."];return;}
    NSString *identifier=nil;
    for(NSURL *url in [NSFileManager.defaultManager contentsOfDirectoryAtURL:NSBundle.mainBundle.builtInPlugInsURL includingPropertiesForKeys:nil options:0 error:nil]){NSBundle *bundle=[NSBundle bundleWithURL:url];if([bundle.infoDictionary[@"NSExtension"][@"NSExtensionPointIdentifier"] isEqual:@"com.apple.broadcast-services-upload"]){identifier=bundle.bundleIdentifier;break;}}
    if(!identifier){[self append:@"Screen broadcast extension is missing. Re-sign the full IPA keeping BOTH the VPN and screen broadcast extensions."];return;}
    if(self.broadcastArmed){self.broadcastPicker.preferredExtension=identifier;self.broadcastPicker.hidden=NO;[self probeBroadcast];[self append:@"Screen broadcast mode is already selected. Use the round system button to inspect or restart capture. Stop sharing exits this mode."];return;}
    self.discoveryMode.selectedSegmentIndex=0;
    [self.vpn connect:^(BOOL ok){if(!ok||generation!=self.mediaStartGeneration||self.userDisconnected)return;
        [self stop];self.broadcastArmed=YES;[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"screenBroadcastArmed"];
        self.broadcastPicker.preferredExtension=identifier;self.broadcastPicker.hidden=NO;self.lastBroadcastLine=nil;
        [self append:@"Tap the round system broadcast button above, select ScreenLink Screen, then Start Broadcast. Wait for SCREEN BROADCAST ACTIVE, select ScreenLink VPN Phone in YouTube AirPlay, and open Google Maps. The website shows your whole current screen, including other apps if you switch. Keep the phone unlocked. Stop through Control Center or Stop sharing here. This mode hosts AirPlay and the viewer in the broadcast extension; simultaneous YouTube AirPlay still needs your iPhone test."];
        [self links];
    }];
}
- (void)probeBroadcast {
    [self updateHome];if(self.userDisconnected||self.disconnectFlow.running)return;NSUInteger generation=self.mediaStartGeneration;
    [self prepareYouTubePiP];
    if(self.receiver.mediaOnly&&self.receiver.isRunning)SLActivityStatus(self.youtubePiP.active?@"PLAYING · PiP":self.session.active?(self.receiver.videoIsLive?@"PLAYING":@"READY"):@"Return to ScreenLink",self.session.active||self.youtubePiP.active);
    if((!self.broadcastArmed&&!(self.receiver.mediaOnly&&self.receiver.isRunning))||self.broadcastChecking||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    self.broadcastChecking=YES;NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:8080/local/owner"]];[request setValue:@"app" forHTTPHeaderField:@"X-ScreenLink-Control"];request.timeoutInterval=2;request.cachePolicy=NSURLRequestReloadIgnoringLocalCacheData;
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){dispatch_async(dispatch_get_main_queue(),^{
        if(generation!=self.mediaStartGeneration||self.userDisconnected)return;self.broadcastChecking=NO;if((!self.broadcastArmed&&!(self.receiver.mediaOnly&&self.receiver.isRunning))||!data.length){self.localViewerRequestID=nil;self.localViewerApprove.enabled=NO;self.localViewerReject.enabled=NO;return;}NSDictionary *owner=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];if(![owner isKindOfClass:NSDictionary.class]||(![owner[@"broadcast"] boolValue]&&![owner[@"mediaOnly"] boolValue]))return;
        [self.dashboard showPlayerState:owner[@"mediaState"]];
        if(self.quickStartPending){self.quickStartPending=NO;[self localViewerDecision:@"automatic"];}
        NSDictionary *local=[owner[@"localViewer"] isKindOfClass:NSDictionary.class]?owner[@"localViewer"]:@{};BOOL pending=[local[@"phase"] isEqual:@"pending"];self.localViewerRequestID=pending?local[@"requestID"]:nil;self.localViewerApprove.enabled=pending;self.localViewerReject.enabled=pending;
        self.localViewerStatus.text=([owner[@"screenLocked"] boolValue]&&[local[@"automatic"] boolValue])?@"YOUTUBE READY · SCREEN LOCKED":[local[@"phase"] isEqual:@"approved"]?@"CONNECTED":([local[@"automatic"] boolValue]?@"READY":@"Start ScreenLink");
        self.broadcastToken=owner[@"token"];NSArray *logs=[owner[@"logs"] isKindOfClass:NSArray.class]?owner[@"logs"]:@[];NSUInteger begin=0;if(self.lastBroadcastLine){NSUInteger last=[logs indexOfObject:self.lastBroadcastLine];begin=last==NSNotFound?(logs.count>10?logs.count-10:0):last+1;}
        for(NSUInteger i=begin;i<logs.count;i++)[self append:[@"BROADCAST: " stringByAppendingString:logs[i]]];self.lastBroadcastLine=logs.lastObject;
    });}] resume];
}
- (void)approveLocalViewer { [self localViewerDecision:@"approve"]; }
- (void)rejectLocalViewer { [self localViewerDecision:@"reject"]; }
- (void)disconnectLocalViewer { [self localViewerDecision:@"disconnect"]; }
- (void)localViewerDecision:(NSString *)action {
    if(self.userDisconnected)return;NSUInteger generation=self.mediaStartGeneration;
    if(!self.broadcastArmed&&!(self.receiver.isRunning&&self.receiver.mediaOnly)){[self append:@"Start ScreenLink before connecting a local viewer. No screen recording is required for YouTube."];return;}
    if(![action isEqual:@"disconnect"]&&![action isEqual:@"automatic"]&&!self.localViewerRequestID.length)return;
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:8080/local/viewer/decision"]];request.HTTPMethod=@"POST";request.timeoutInterval=2;[request setValue:@"app" forHTTPHeaderField:@"X-ScreenLink-Control"];[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];request.HTTPBody=[NSJSONSerialization dataWithJSONObject:@{@"action":action,@"requestID":self.localViewerRequestID?:@"",@"youtubeOnly":@(self.receiver.mediaOnly||self.broadcastYouTubeOnly)} options:0 error:nil];
    self.localViewerApprove.enabled=NO;self.localViewerReject.enabled=NO;
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){dispatch_async(dispatch_get_main_queue(),^{
        if(generation!=self.mediaStartGeneration||self.userDisconnected)return;
        if(error||[(NSHTTPURLResponse *)response statusCode]!=200)[self append:@"Local viewer decision was not confirmed. Keep phone screen hidden and retry after status refresh."];
        if([action isEqual:@"automatic"]&&!error&&[(NSHTTPURLResponse *)response statusCode]==200)self.localViewerStatus.text=self.broadcastYouTubeOnly?@"YOUTUBE READY · SCREEN LOCKED":@"READY";else [self probeBroadcast];
    });}] resume];
}
- (void)stopBroadcast {
    if(!self.broadcastArmed)return;NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:8080/local/broadcast/stop"]];request.HTTPMethod=@"POST";[request setValue:@"app" forHTTPHeaderField:@"X-ScreenLink-Control"];request.timeoutInterval=2;[[NSURLSession.sharedSession dataTaskWithRequest:request] resume];
    self.localViewerRequestID=nil;self.localViewerApprove.enabled=NO;self.localViewerReject.enabled=NO;self.localViewerStatus.text=@"Local alias viewer: stopped.";
    self.broadcastArmed=NO;self.broadcastPicker.hidden=YES;self.broadcastToken=nil;[NSUserDefaults.standardUserDefaults setBool:NO forKey:@"screenBroadcastArmed"];
}
- (void)startRouteProbe {
    if(![self permitExplicitStart])return;NSUInteger generation=self.mediaStartGeneration;
    [self.vpn connectRouteProbe:^(BOOL ok){if(!ok||generation!=self.mediaStartGeneration||self.userDisconnected)return;
        [self prepareBroadcast];
        [self append:@"ROUTING EXPERIMENT ONLY: start the system screen broadcast so the local server stays available. No website pairing or YouTube needed. While parked, try the FULL URLs http://172.20.10.1:8080/local-route-probe and http://240.3.3.3:8080/local-route-probe in Tesla. A success page proves TCP reached this phone; failure does not identify browser policy by itself. Copy the test log and Route probe status. Disconnect VPN, then reconnect normally to remove the alias."];
    }];
}
- (void)routeProbeStatus { [self.vpn routeProbeStatus]; }
- (void)connectVPN {if([self permitExplicitStart])[self.vpn connect:nil];}
- (void)disconnectVPN { [self.vpn disconnect]; }
- (void)withVPN:(void (^)(void))ready {
    NSUInteger generation=self.mediaStartGeneration;
    if(2-self.discoveryMode.selectedSegmentIndex!=SLDiscoveryPhoneVPN || self.vpn.connected){ready();return;}
    [self.vpn connect:^(BOOL ok){if(ok&&generation==self.mediaStartGeneration&&!self.userDisconnected)ready();}];
}
- (void)start {if(![self permitExplicitStart])return; if(self.broadcastArmed){[self probeBroadcast];[self append:@"Screen broadcast mode is selected. Start it using the system broadcast button; Stop sharing exits this mode before starting the normal receiver."];return;} [self withVPN:^{[self startReceiver];}]; }
- (void)startReceiver {
    if(!self.receiver.isRunning)self.receiver.discoveryMode=2-self.discoveryMode.selectedSegmentIndex;
    if([self.receiver start]){[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"receiverArmed"];UIApplication.sharedApplication.idleTimerDisabled=YES;[self links];}
}
- (void)stop {self.discoveryPolicyDenied=NO;[self.dashboard showPlayerState:@{}];self.youtubePiPRequested=NO;[self.youtubePiP reset];[self.youtubePiP removeFromSuperview];self.youtubePiP=nil;SLActivityFinish();self.mediaStartGeneration++;self.mediaOnlyRestarting=NO;[NSUserDefaults.standardUserDefaults setBool:NO forKey:@"resumeYouTubeOnReturn"]; [self stopBroadcast]; [NSUserDefaults.standardUserDefaults setBool:NO forKey:@"receiverArmed"];[self.session finish];[self endGrace];[self.receiver stop];[self.preview reset];[self.preview removeFromSuperview];self.preview=nil;if(_lastPixel){CVPixelBufferRelease(_lastPixel);_lastPixel=NULL;}UIApplication.sharedApplication.idleTimerDisabled=NO;[self append:@"Stopped. Video frames cleared."]; }
- (void)startMedia {
    if(![self permitExplicitStart])return;
    if(self.broadcastArmed){[self probeBroadcast];[self append:@"In screen broadcast mode, select ScreenLink VPN Phone inside YouTube AirPlay, then open Google Maps. The extension owns the receiver; no timed task or floating preview is needed for the main app. Verify both streams on your iPhone."];return;}
    [self withVPN:^{[self startMediaReady];}];
}
- (void)startMediaReady {
    [self startReceiver];if(!self.receiver.isRunning)return;
    self.session.allowWaitingForVideo=YES;[self.session start];
    [self append:@"NATIVE VIDEO TEST: open the fixed hotspot link on your Mac. Then switch to YouTube on iPhone, tap Cast → AirPlay & Bluetooth devices → ScreenLink VPN Phone. Do not start Control Center Screen Mirroring. Browser playback includes audio; press Play with sound on the Mac. A timed background session must be active before leaving ScreenLink. Native YouTube compatibility needs a device test."];
}
- (void)startSession {
    if(![self permitExplicitStart])return;
    self.session.allowWaitingForVideo=NO;
    if(!self.receiver.videoIsLive){[self append:@"The AirPlay video connection is not live yet. Reconnect ScreenLink VPN Phone in Screen Mirroring and wait for at least 10 fresh frames before starting the background test."];return;}
    [self.session start];
}
- (void)receivedPixel:(CVPixelBufferRef)pixel {
    if(self.userDisconnected||!self.receiver.isRunning)return;
    CVPixelBufferRetain(pixel);if(_lastPixel)CVPixelBufferRelease(_lastPixel);_lastPixel=pixel;
    [self.preview receivePixelBuffer:pixel];
}
- (void)startFloating {
    if(![self permitExplicitStart])return;
    if(!self.receiver.isRunning || !_lastPixel){[self append:@"Connect AirPlay first and wait for actual video received. Then return here and start floating preview."];return;}
    if(!self.preview){
        self.preview=[[FloatingPreview alloc]initWithFrame:CGRectZero];self.preview.translatesAutoresizingMaskIntoConstraints=NO;
        [self.previewSlot addSubview:self.preview];
        [NSLayoutConstraint activateConstraints:@[[self.preview.topAnchor constraintEqualToAnchor:self.previewSlot.topAnchor],[self.preview.bottomAnchor constraintEqualToAnchor:self.previewSlot.bottomAnchor],[self.preview.leadingAnchor constraintEqualToAnchor:self.previewSlot.leadingAnchor],[self.preview.trailingAnchor constraintEqualToAnchor:self.previewSlot.trailingAnchor]]];
        [self.previewSlot layoutIfNeeded];
        __weak Controller *weak=self;
        self.preview.status=^(NSString *message){[weak append:message];};
        self.preview.activityChanged=^(BOOL active){
            Controller *owner=weak;if(!owner)return;
            owner.receiver.compressedOnlyInBackground=!active;
            if(active)[owner endGrace];
            else if(!owner.session.active && UIApplication.sharedApplication.applicationState==UIApplicationStateBackground && owner.receiver.isRunning)[owner beginGrace];
        };
        [self.preview receivePixelBuffer:_lastPixel];
    }
    [self.preview startFloating];
}
- (void)copyLog { UIPasteboard.generalPasteboard.string=self.text.text;[self append:@"Test log copied."]; }
- (NSArray<NSDictionary *> *)addresses {
    struct ifaddrs *head=NULL;if(getifaddrs(&head)!=0)return @[];
    NSMutableArray *result=[NSMutableArray array];
    for(struct ifaddrs *p=head;p;p=p->ifa_next) {
        if(!p->ifa_addr || p->ifa_addr->sa_family!=AF_INET)continue;
        NSString *name=[NSString stringWithUTF8String:p->ifa_name];if(![name hasPrefix:@"en"] && ![name hasPrefix:@"bridge"])continue;
        char address[INET_ADDRSTRLEN];struct sockaddr_in *a=(void *)p->ifa_addr;
        if(inet_ntop(AF_INET,&a->sin_addr,address,sizeof address)) {
            NSString *host=[NSString stringWithUTF8String:address];
            NSInteger priority=[name hasPrefix:@"bridge"]?0:([host hasPrefix:@"169.254."]?2:1);
            [result addObject:@{@"name":name,@"host":host,@"priority":@(priority)}];
        }
    }freeifaddrs(head);
    [result sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"priority"] compare:b[@"priority"]];}];return result;
}
- (NSString *)linkForAddress:(NSDictionary *)address {
    if([address[@"name"] hasPrefix:@"bridge"])return [NSString stringWithFormat:@"http://%@:8080/%@",address[@"host"],self.broadcastArmed?@"split":@""];
    return [NSString stringWithFormat:@"http://%@:8080/%@?token=%@",address[@"host"],self.broadcastArmed?@"split":@"",self.broadcastArmed?(self.broadcastToken?:@""):self.receiver.token];
}
- (void)copyViewer {
    if(!self.receiver.isRunning&&!self.broadcastArmed){[self append:@"Start the receiver first, then copy its active viewer link."];return;}
    NSDictionary *address=[self addresses].firstObject;
    if(!address){[self append:@"No Wi-Fi/hotspot address yet. Connect the viewer to your hotspot, then try again."];return;}
    NSString *link=[self linkForAddress:address];UIPasteboard.generalPasteboard.string=link;
    [self append:[NSString stringWithFormat:@"Viewer link copied (%@). Paste on the viewer device before casting.\n%@",address[@"name"],link]];
}
- (void)links {
    NSArray *addresses=[self addresses];
    for(NSDictionary *address in addresses)if([address[@"name"] hasPrefix:@"bridge"]){self.bookmark.text=[NSString stringWithFormat:@"Bookmark on your Mac:\n%@",[self linkForAddress:address]];break;}
    for(NSDictionary *address in addresses)[self append:[NSString stringWithFormat:@"Browser link (%@):\n%@",address[@"name"],[self linkForAddress:address]]];
    if(!addresses.count)[self append:@"No Wi-Fi/hotspot IPv4 address found. Connect the viewer, then show links again."];
}
- (void)beginGrace {
    if(self.backgroundTask!=UIBackgroundTaskInvalid || !self.receiver.isRunning)return;
    self.backgroundTask=[UIApplication.sharedApplication beginBackgroundTaskWithName:@"Finish AirPlay transition" expirationHandler:^{
        if(self.preview.active || self.youtubePiP.active || self.session.active){[self append:@"Transition time ended; PiP or background session is active. Continuing the receiver."];[self endGrace];return;}
        [self endGrace];[self append:@"PiP is inactive and background grace expired. Receiver remains armed, but iOS may suspend it. Return to ScreenLink to resume listening; a VPN alone does not grant background execution."];
    }];
}
- (void)endGrace {
    if(self.backgroundTask!=UIBackgroundTaskInvalid){[UIApplication.sharedApplication endBackgroundTask:self.backgroundTask];self.backgroundTask=UIBackgroundTaskInvalid;}
}
- (void)background {
    self.networkProbe.delegate=nil;[self.networkProbe stop];self.networkProbe=nil;
    if(self.broadcastArmed){[self append:@"Main app backgrounded in screen broadcast mode. The broadcast extension owns the streams while iOS keeps the user-started screen broadcast active."];[self endGrace];return;}
    if(self.youtubePiPRequested&&!self.youtubePiP.active)[self append:@"PIP NOT ACTIVE: the saved PiP request is not a running floating window. Return to ScreenLink and wait for YOUTUBE PiP ACTIVE; a temporary background task can expire early."];
    if(self.session.active){[self append:@"App backgrounded with a timed session active. Verify the H.264 viewer keeps updating without PiP."];[self endGrace];}
    else if(self.preview.active||self.youtubePiP.active){[self append:@"App backgrounded with floating preview active. Test whether the viewer keeps updating."];[self endGrace];}
    else {[self append:self.youtubePiPRequested?@"PIP NOT ACTIVE: return to ScreenLink and wait for YOUTUBE PiP ACTIVE before switching apps. The saved request alone cannot keep the receiver running.":@"Floating preview is not active. Only a short background grace is available. Return and start floating preview before switching apps."];[self beginGrace];}
}
- (void)active {
    [self updateHome];if(self.userDisconnected||self.disconnectFlow.running)return;
    [self requestLocalNetwork];
    if(![NSUserDefaults.standardUserDefaults boolForKey:@"widgetChecked51"]){[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"widgetChecked51"];[self widgetDiagnostics];}
    if([NSUserDefaults.standardUserDefaults boolForKey:@"resumeYouTubeOnReturn"]){[self resumeYouTubeOnReturn];return;}
    [self prepareYouTubePiP];
    if(self.broadcastArmed){[self probeBroadcast];return;}
    if([NSUserDefaults.standardUserDefaults boolForKey:@"receiverArmed"] && !self.receiver.isRunning)[self start];
}
- (void)foreground {
    [self endGrace];[self append:@"App returned to foreground."];
}
@end
@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic) SLWidgetRoute pendingWidgetAction;
@property(nonatomic) NSUInteger widgetGeneration;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
 SLWidgetRoute launchAction=SLRouteForURL(options[UIApplicationLaunchOptionsURLKey]);
 if(launchAction==SLWidgetRouteDisconnect){[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"manualDisconnected"];[NSUserDefaults.standardUserDefaults setBool:NO forKey:@"receiverArmed"];[NSUserDefaults.standardUserDefaults setBool:NO forKey:@"resumeYouTubeOnReturn"];}
 self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[Controller new];[self.window makeKeyAndVisible];self.pendingWidgetAction=launchAction;return YES;
}
- (void)cancelPendingWidgetAction {self.widgetGeneration++;self.pendingWidgetAction=SLWidgetRouteNone;}
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
 SLWidgetRoute action=SLRouteForURL(url);if(action==SLWidgetRouteNone)return NO;
 self.widgetGeneration++;self.pendingWidgetAction=action;
 if(action==SLWidgetRouteDisconnect){self.pendingWidgetAction=SLWidgetRouteNone;[(Controller *)self.window.rootViewController disconnectAll];return YES;}
 if(app.applicationState==UIApplicationStateActive)[self consumeWidgetStart];return YES;
}
- (void)applicationDidBecomeActive:(UIApplication *)application {[self consumeWidgetStart];}
- (void)consumeWidgetStart {
 if(self.pendingWidgetAction==SLWidgetRouteNone)return;
 Controller *owner=(Controller *)self.window.rootViewController;[owner loadViewIfNeeded];[owner showHome];
 if(owner.disconnectFlow.running&&self.pendingWidgetAction==SLWidgetRouteStart){
  NSUInteger generation=self.widgetGeneration;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.25*NSEC_PER_SEC)),dispatch_get_main_queue(),^{if(generation==self.widgetGeneration)[self consumeWidgetStart];});return;
 }
 SLWidgetRoute action=self.pendingWidgetAction;self.pendingWidgetAction=SLWidgetRouteNone;
 if(action==SLWidgetRouteDisconnect)[owner disconnectAll];
 else if(action==SLWidgetRouteStart)[owner startFromWidget];
 else if(action==SLWidgetRouteResume)[owner resumeYouTubeOnReturn];
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(AppDelegate.class));}}

