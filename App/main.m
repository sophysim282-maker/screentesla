#import <UIKit/UIKit.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import "Receiver.h"
#import "FloatingPreview.h"
#import "BackgroundSession.h"
#import "LocalVPN.h"
#import "RTCPrototypeController.h"
#import "SLMediaController.h"
#import <ReplayKit/ReplayKit.h>
// Swift class has an explicit Objective-C runtime name; no generated header.
@protocol SLWidgetActivityAPI
+ (void)updateStatus:(NSString *)status running:(BOOL)running;
+ (void)finish;
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
@property(nonatomic) BOOL mediaOnlyRestarting;
@property(nonatomic) NSUInteger mediaStartGeneration;
@property(nonatomic,strong) UILabel *localViewerStatus;
@property(nonatomic,strong) UIButton *localViewerApprove,*localViewerReject;
@property(nonatomic,strong) UITextView *text;
@property(nonatomic,strong) FloatingPreview *preview;
@property(nonatomic,strong) BackgroundSession *session;
@property(nonatomic,strong) UIView *previewSlot;
@property UIBackgroundTaskIdentifier backgroundTask;
@property(nonatomic,strong) UISegmentedControl *discoveryMode;
@property(nonatomic,strong) UISegmentedControl *videoProfile;
@property(nonatomic,strong) UILabel *bookmark;
@end
@implementation Controller
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.backgroundTask=UIBackgroundTaskInvalid;
    UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=6;stack.translatesAutoresizingMaskIntoConstraints=NO;
    UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:scroll];[NSLayoutConstraint activateConstraints:@[[scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],[scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]]];[scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:8],[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-8],[stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],[stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],[stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32]]];
    UILabel *title=[UILabel new];title.text=@"ScreenLink · 0.20.13";title.font=[UIFont boldSystemFontOfSize:21];[stack addArrangedSubview:title];
    self.bookmark=[UILabel new];self.bookmark.font=[UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightMedium];self.bookmark.numberOfLines=0;self.bookmark.text=@"Connect your Mac to the hotspot, then start receiver.";[stack addArrangedSubview:self.bookmark];
    UILabel *help=[UILabel new];help.numberOfLines=0;help.font=[UIFont systemFontOfSize:13];help.text=@"Connect built-in VPN → allow setup → Start YouTube video-only → wait for background session → open YouTube AirPlay. Keep the Mac on your hotspot.";[stack addArrangedSubview:help];
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
    NSArray *labels=@[@"Start YouTube · no recording",@"Start Maps + YouTube",@"YouTube only · website",@"Maps + YouTube · website",@"WebRTC moving-video test",@"Maps + YouTube · prepare screen broadcast",@"Start YouTube video-only",@"Start receiver",@"Copy viewer link",@"Start 30-minute background test",@"Start floating preview",@"Show browser links",@"Copy test log",@"Refresh discovery",@"Stop sharing"];
    NSArray *actions=@[NSStringFromSelector(@selector(startYouTubeNoRecording)),NSStringFromSelector(@selector(quickStart)),NSStringFromSelector(@selector(youtubeOnlyWebsite)),NSStringFromSelector(@selector(youtubeWebsite)),NSStringFromSelector(@selector(rtcPrototype)),NSStringFromSelector(@selector(prepareBroadcast)),NSStringFromSelector(@selector(startMedia)),NSStringFromSelector(@selector(start)),NSStringFromSelector(@selector(copyViewer)),NSStringFromSelector(@selector(startSession)),NSStringFromSelector(@selector(startFloating)),NSStringFromSelector(@selector(links)),NSStringFromSelector(@selector(copyLog)),NSStringFromSelector(@selector(refreshDiscovery)),NSStringFromSelector(@selector(stop))];
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
    self.vpn=[LocalVPN new];self.vpn.status=^(NSString *message){[weak append:message];};
    self.receiver.status=^(NSString *message){[weak append:message];};
    self.receiver.preview=^(CVPixelBufferRef pixel){[weak receivedPixel:pixel];};
    self.receiver.videoProfile=self.videoProfile.selectedSegmentIndex;
    self.session=[BackgroundSession new];
    self.session.status=^(NSString *message){[weak append:message];};
    self.session.videoIsLive=^BOOL{return weak.receiver.videoIsLive;};
    self.session.activityChanged=^(BOOL active){Controller *owner=weak;if(!owner)return;if(owner.receiver.mediaOnly){owner.localViewerStatus.text=active?@"READY":@"Background session ended. Return to ScreenLink.";SLActivityStatus(active?@"READY":@"Return to ScreenLink",active);}owner.receiver.compressedOnlyInBackground=!owner.preview.active;if(active)[owner endGrace];};
    self.session.ended=^{
        Controller *owner=weak;if(!owner || !owner.receiver.isRunning)return;
        [owner append:@"BACKGROUND RUNTIME ENDED: receiver, viewer link and media session retained. iOS may suspend this app without PiP. Returning to ScreenLink resumes the existing receiver; Start is not required to rebuild it."];
        if(!owner.preview.active && UIApplication.sharedApplication.applicationState==UIApplicationStateBackground)[owner beginGrace];
    };
    [self append:@"Version 0.20.13 WIDGETS: adds Dog, Cat and Roadster Home Screen launchers for YouTube-only without recording. Tap a widget to open ScreenLink and start/resume its existing local receiver. Live Activity / Dynamic Island shows real source status and short state-change animations, not continuous pet animation. A widget does not extend the bounded background session. Previous version 0.20.12 FOREGROUND RESUME: after a YouTube-only timed session expires or is cancelled, returning to ScreenLink requests a fresh session and restores its receiver if needed. A healthy receiver and its existing authorization are retained. Stop sharing disables automatic resume. Maps mode is unchanged. YouTube may still require selecting its AirPlay route again. Previous version 0.20.11 RECOVERY: Start ScreenLink prepares alias VPN and authorizes the first local viewer for five minutes. The iOS system broadcast confirmation remains required. Website connects automatically. Up to three decoder retries retain the exact error and resume position. Smaller decoded-video lookahead preserves resolution. Physical Tesla recovery is unverified. Previous version 0.20.10 AAC WAVEFORM CONTINUITY: preserves the audio decoder across ordinary HLS segment boundaries instead of flushing/reinitializing it each segment. Flushes at stream end, configuration changes and true discontinuities. A real-browser AAC comparison reproduced altered PCM near 5/10-second boundaries despite zero timing gaps; uninterrupted decoding avoids it. Requests the decoded source sample rate when first enabling sound to reduce per-packet resampling. Actual listening still needs confirmation. Previous version 0.20.9 YOUTUBE ONLY: adds a YouTube-only website option and /video link. The viewer gives YouTube the full area, hides phone-screen capture with acknowledgement, and does not open the Maps screen socket. Switch back with View → Maps + YouTube; Show screen is still explicit. YouTube buffering and audio remain unchanged. Previous version 0.20.8 YOUTUBE BUFFER: adds one second of startup buffering for YouTube audio and video together, requires one second of decoded audio and downloaded video reserve, retains four-second native audio scheduling, and leaves Maps unchanged. This is buffering, not a guarantee to remove clicks inside decoded audio. Previous version 0.20.7 PACKED AAC CONTINUITY: directly extracts every complete ADTS packet, preserves ID3 transport timestamps, and uses exact sample continuity when packed timestamps are absent or reset. Fixes the reproduced dropped-AAC-packet conversion path. Previous version 0.20.6 FOUR-SECOND AUDIO: fills up to four seconds in the native audio graph, shares fetched/demuxed segments between independent audio/video pipelines, and keeps audio playing through brief video-only starvation. Real audio starvation still triggers coordinated recovery on a 40 ms runway. Previous version 0.20.5 AUDIO ENGINE: direct AudioData-to-AudioBuffer copying, 600 ms scheduling lookahead, shared 40 ms startup runway, short stop fades, and continuous source timestamp mapping between segments. Adds Copy playback diagnostics. Previous version 0.20.4 SEGMENT PREFETCH: downloads one encoded HLS segment ahead per rendition while the current segment decodes. Keeps decoded frame and audio limits, cancels old fetches on seek, and reports buffer waiting time. Previous version 0.20.3 TIMER REPAIR: fixes build 39 creating an audio timer on every Canvas frame. One audio scheduler is created per player and cleared when it closes. Adds timer lifecycle regression checks. Previous version 0.20.2 AUDIO TIMING REPAIR: schedules Web Audio chunks on one absolute sample clock, joins small AAC boundary gaps, preserves queued PCM on pause, and schedules audio independently from Canvas drawing. Previous version 0.20.1 PACKED AUDIO REPAIR: recognizes AAC/ADTS and ID3 HLS segments instead of incorrectly treating them as MP4. Adds bounded format diagnostics without media URLs. A parser failure matching the reported error is reproduced and covered by regression tests; actual YouTube source compatibility still needs verification. Previous version 0.20.0 CANVAS PLAYER: HTTPS viewer now uses direct WebCodecs for Maps and YouTube, Web Audio and a bounded approved WSS screen stream. No video/audio elements are created by the HTTPS viewer. Static UI can load from offline cache after first installation; capture, tokens and media are never cached. Start the VPN and broadcast, open https://car.tesla4khmer.com/ and approve the viewer. Physical Tesla performance still needs testing. Version 0.19.4 LOCAL HTTPS: adds port 443 with the privately packaged hostname certificate. Keep experimental VPN and system broadcast active, then open https://car.tesla4khmer.com/ and approve the local viewer. /capabilities checks HTTPS and browser decoder support. WSS, a new Maps decoder and offline caching are not implemented in this checkpoint. Version 0.19.3 APPROVAL HEADER FIX: corrects build 34 rejecting the browser request header. Local approval failures now show HTTP status or timeout instead of a generic interruption. Test Mac approval before any further Tesla trip. Tesla playback remains unverified. Version 0.19.2 LOCAL ALIAS PLAYBACK EXPERIMENT: after starting the experimental VPN and screen broadcast, open http://240.3.3.3:8080/ in the parked Tesla, press Connect phone, then Approve local viewer here. Uses existing local HTTP media paths; not HTTPS. No cloud media relay. Phone screen starts hidden; use Show only after Maps is open. Tesla playback is unverified. Version 0.19.1 ROUTE EXPERIMENT: adds an optional virtual-IP alias and read-only TCP route probe. This is NOT a verified Tesla video fix. Normal mode preserves the existing VPN and media paths. Version 0.19.0: adds a phone-local STUN Binding service for browser NAT address discovery. Update the website to 0.19.0-web1; old viewers do not use this new route discovery. No public STUN/TURN or cloud media relay is configured. The Tesla test advertised a 192.168.93.x browser address while the phone hotspot was 172.20.10.1. Physical recovery still needs testing. Also retains hotspot interfaces through native enumeration instead of NWPathMonitor filtering, excludes cellular/VPN/loopback candidates in hotspot mode, and tolerates slower signaling responses. This targets a possible route-loss cause; physical Tesla recovery is not yet verified. Also fixes early ICE gathering completion and repeated restart requests, adds foreground local-network permission preflight and route diagnostics; retains confirmed Hide status across health polls and adds a separate HTTPS WebRTC Maps screen channel with default-hidden capture and explicit Hide/Show acknowledgement. The viewer has a draggable Maps/YouTube split. Adds native ICE check diagnostics and actual transport states, and restores local ICE TCP candidates alongside preferred UDP. Retains the HD repair: HD source selection prefers the highest offered resolution up to 1080p, removes the Canvas player's 6 Mbps quality cutoff, adds local 720p/1080p choices when supplied, and reports actual decoded size. AirPlay media uses a 1080p-capable legacy receiver compatibility profile. Source resolutions are logged without media URLs. This does not create HD if YouTube only offers SD. Website connection uses automatic receiver lookup and explicit phone approval. No pairing number is displayed or entered. Network matching can be unavailable or ambiguous; that is shown honestly. Connect built-in VPN and hotspot, then use the user-started ScreenLink broadcast. Phone-screen capture starts hidden. iOS can interrupt the broadcast; unlimited runtime is not promised."];
    self.broadcastTimer=[NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(probeBroadcast) userInfo:nil repeats:YES];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(background) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(active) name:UIApplicationDidBecomeActiveNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(foreground) name:UIApplicationWillEnterForegroundNotification object:nil];
}
- (void)requestLocalNetwork {
    if(self.networkProbe||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    self.networkProbe=[NSNetServiceBrowser new];self.networkProbe.delegate=self;
    [self.networkProbe searchForServicesOfType:@"_airplay._tcp." inDomain:@"local."];
    [self append:@"LOCAL NETWORK PREFLIGHT: allow ScreenLink Local Network access if iOS asks before leaving this app. A background broadcast extension cannot show that permission alert. This browse is not proof of Tesla connectivity."];
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary<NSString *,NSNumber *> *)error {
    [self append:[NSString stringWithFormat:@"LOCAL NETWORK PREFLIGHT FAILED: %@. Check iPhone Settings → Privacy & Security → Local Network → ScreenLink. No permission grant is inferred.",error]];
}
- (void)append:(NSString *)s { self.text.text=[self.text.text stringByAppendingFormat:@"\n%@ %@\n",[NSDate date],s];if(self.text.text.length>24000)self.text.text=[self.text.text substringFromIndex:self.text.text.length-18000];[self.text scrollRangeToVisible:NSMakeRange(self.text.text.length,0)]; }
- (void)startFromWidget {
 [self loadViewIfNeeded];
 if(self.receiver.isRunning&&self.receiver.mediaOnly){
  [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"resumeYouTubeOnReturn"];
  [self resumeYouTubeOnReturn];
  SLActivityStatus(self.session.active?(self.receiver.videoIsLive?@"PLAYING":@"READY"):@"Return to ScreenLink",self.session.active);
 } else [self startYouTubeNoRecording];
}
- (void)startYouTubeNoRecording {if(self.mediaOnlyRestarting)return;self.mediaOnlyRestarting=YES;NSUInteger generation=self.mediaStartGeneration;[self requestLocalNetwork];self.quickStartPending=NO;[self.vpn connectRouteProbe:^(BOOL ok){if(generation!=self.mediaStartGeneration||!self.mediaOnlyRestarting)return;if(!ok){self.mediaOnlyRestarting=NO;return;}[self stop];self.mediaOnlyRestarting=YES;[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"resumeYouTubeOnReturn"];self.discoveryMode.selectedSegmentIndex=0;[self startMediaOnlyWhenFree:20 generation:self.mediaStartGeneration];}];}
- (void)resumeYouTubeOnReturn {
 if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive||self.mediaOnlyRestarting||![NSUserDefaults.standardUserDefaults boolForKey:@"resumeYouTubeOnReturn"])return;
 if(!self.receiver.isRunning||!self.receiver.mediaOnly){[self startYouTubeNoRecording];return;}
 if(self.session.active)return;
 self.mediaOnlyRestarting=YES;NSUInteger generation=self.mediaStartGeneration;[self.vpn connectRouteProbe:^(BOOL ok){if(generation!=self.mediaStartGeneration)return;self.mediaOnlyRestarting=NO;if(!ok)return;self.session.allowWaitingForVideo=YES;[self.session start];self.localViewerStatus.text=self.session.active?@"READY":@"Restarting background session…";[self append:@"RESUMING YOUTUBE: foreground return requested a new timed session. The existing receiver, viewer authorization and media state are preserved. If YouTube released AirPlay, select ScreenLink VPN Phone again in YouTube."];}];
}
- (void)startMediaOnlyWhenFree:(NSUInteger)attempts generation:(NSUInteger)generation {
 NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:8080/local/owner"]];[request setValue:@"app" forHTTPHeaderField:@"X-ScreenLink-Control"];request.timeoutInterval=1;
 [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){dispatch_async(dispatch_get_main_queue(),^{
 if(generation!=self.mediaStartGeneration||!self.mediaOnlyRestarting)return;
 if(!error&&[(NSHTTPURLResponse *)response statusCode]==200){if(attempts)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self startMediaOnlyWhenFree:attempts-1 generation:generation];});else {self.mediaOnlyRestarting=NO;self.localViewerStatus.text=@"Stop the previous broadcast and retry.";}return;}
 [self.receiver prepareMediaOnly];[self startReceiver];self.mediaOnlyRestarting=NO;if(!self.receiver.isRunning){self.localViewerStatus.text=@"Receiver could not start.";return;}[self.receiver authorizeNextLocalViewer];self.session.allowWaitingForVideo=YES;[self.session start];self.localViewerStatus.text=self.session.active?@"READY":@"Wait for BACKGROUND SESSION ACTIVE before opening YouTube.";UIPasteboard.generalPasteboard.string=@"https://car.tesla4khmer.com/video";[self append:@"YOUTUBE ONLY: no ReplayKit recording, no screen encoder. Open https://car.tesla4khmer.com/video. Website connects automatically. This uses a bounded background session; if iOS rejects or ends it, keep ScreenLink open or use Maps + YouTube broadcast mode."];
 });}] resume];
}
- (void)quickStart {self.quickStartPending=YES;[self requestLocalNetwork];[self.vpn connectRouteProbe:^(BOOL ok){if(!ok){self.quickStartPending=NO;return;}[self prepareBroadcast];for(UIView *view in self.broadcastPicker.subviews)if([view isKindOfClass:UIButton.class])[(UIButton *)view sendActionsForControlEvents:UIControlEventTouchUpInside];}];}
- (void)youtubeOnlyWebsite {[self presentWebsite:YES];}
- (void)youtubeWebsite {[self presentWebsite:NO];}
- (void)presentWebsite:(BOOL)youtubeOnly {[self requestLocalNetwork];[self prepareBroadcast];SLMediaController *controller=[SLMediaController new];controller.youtubeOnly=youtubeOnly;controller.broadcastExtensionIdentifier=self.broadcastPicker.preferredExtension;controller.modalPresentationStyle=UIModalPresentationFullScreen;[self presentViewController:controller animated:YES completion:nil];}
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
    if(@available(iOS 16.0,*)){}else{[self append:@"The screen broadcast encoder requires iOS 16 or later. Normal AirPlay remains available."];return;}
    NSString *identifier=nil;
    for(NSURL *url in [NSFileManager.defaultManager contentsOfDirectoryAtURL:NSBundle.mainBundle.builtInPlugInsURL includingPropertiesForKeys:nil options:0 error:nil]){NSBundle *bundle=[NSBundle bundleWithURL:url];if([bundle.infoDictionary[@"NSExtension"][@"NSExtensionPointIdentifier"] isEqual:@"com.apple.broadcast-services-upload"]){identifier=bundle.bundleIdentifier;break;}}
    if(!identifier){[self append:@"Screen broadcast extension is missing. Re-sign the full IPA keeping BOTH the VPN and screen broadcast extensions."];return;}
    if(self.broadcastArmed){self.broadcastPicker.preferredExtension=identifier;self.broadcastPicker.hidden=NO;[self probeBroadcast];[self append:@"Screen broadcast mode is already selected. Use the round system button to inspect or restart capture. Stop sharing exits this mode."];return;}
    self.discoveryMode.selectedSegmentIndex=0;
    [self.vpn connect:^(BOOL ok){if(!ok)return;
        [self stop];self.broadcastArmed=YES;[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"screenBroadcastArmed"];
        self.broadcastPicker.preferredExtension=identifier;self.broadcastPicker.hidden=NO;self.lastBroadcastLine=nil;
        [self append:@"Tap the round system broadcast button above, select ScreenLink Screen, then Start Broadcast. Wait for SCREEN BROADCAST ACTIVE, select ScreenLink VPN Phone in YouTube AirPlay, and open Google Maps. The website shows your whole current screen, including other apps if you switch. Keep the phone unlocked. Stop through Control Center or Stop sharing here. This mode hosts AirPlay and the viewer in the broadcast extension; simultaneous YouTube AirPlay still needs your iPhone test."];
        [self links];
    }];
}
- (void)probeBroadcast {
    if(self.receiver.mediaOnly&&self.receiver.isRunning)SLActivityStatus(self.session.active?(self.receiver.videoIsLive?@"PLAYING":@"READY"):@"Return to ScreenLink",self.session.active);
    if(!self.broadcastArmed||self.broadcastChecking||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    self.broadcastChecking=YES;NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:8080/local/owner"]];[request setValue:@"app" forHTTPHeaderField:@"X-ScreenLink-Control"];request.timeoutInterval=2;request.cachePolicy=NSURLRequestReloadIgnoringLocalCacheData;
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){dispatch_async(dispatch_get_main_queue(),^{
        self.broadcastChecking=NO;if(!self.broadcastArmed||!data.length){self.localViewerRequestID=nil;self.localViewerApprove.enabled=NO;self.localViewerReject.enabled=NO;return;}NSDictionary *owner=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];if(![owner isKindOfClass:NSDictionary.class]||![owner[@"broadcast"] boolValue])return;
        if(self.quickStartPending){self.quickStartPending=NO;[self localViewerDecision:@"automatic"];}
        NSDictionary *local=[owner[@"localViewer"] isKindOfClass:NSDictionary.class]?owner[@"localViewer"]:@{};BOOL pending=[local[@"phase"] isEqual:@"pending"];self.localViewerRequestID=pending?local[@"requestID"]:nil;self.localViewerApprove.enabled=pending;self.localViewerReject.enabled=pending;
        self.localViewerStatus.text=[local[@"phase"] isEqual:@"approved"]?@"CONNECTED":([local[@"automatic"] boolValue]?@"READY":@"Start ScreenLink");
        self.broadcastToken=owner[@"token"];NSArray *logs=[owner[@"logs"] isKindOfClass:NSArray.class]?owner[@"logs"]:@[];NSUInteger begin=0;if(self.lastBroadcastLine){NSUInteger last=[logs indexOfObject:self.lastBroadcastLine];begin=last==NSNotFound?(logs.count>10?logs.count-10:0):last+1;}
        for(NSUInteger i=begin;i<logs.count;i++)[self append:[@"BROADCAST: " stringByAppendingString:logs[i]]];self.lastBroadcastLine=logs.lastObject;
    });}] resume];
}
- (void)approveLocalViewer { [self localViewerDecision:@"approve"]; }
- (void)rejectLocalViewer { [self localViewerDecision:@"reject"]; }
- (void)disconnectLocalViewer { [self localViewerDecision:@"disconnect"]; }
- (void)localViewerDecision:(NSString *)action {
    if(!self.broadcastArmed){[self append:@"Start the system screen broadcast before connecting a local alias viewer."];return;}
    if(![action isEqual:@"disconnect"]&&![action isEqual:@"automatic"]&&!self.localViewerRequestID.length)return;
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:8080/local/viewer/decision"]];request.HTTPMethod=@"POST";request.timeoutInterval=2;[request setValue:@"app" forHTTPHeaderField:@"X-ScreenLink-Control"];[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];request.HTTPBody=[NSJSONSerialization dataWithJSONObject:@{@"action":action,@"requestID":self.localViewerRequestID?:@""} options:0 error:nil];
    self.localViewerApprove.enabled=NO;self.localViewerReject.enabled=NO;
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){dispatch_async(dispatch_get_main_queue(),^{
        if(error||[(NSHTTPURLResponse *)response statusCode]!=200)[self append:@"Local viewer decision was not confirmed. Keep phone screen hidden and retry after status refresh."];
        if([action isEqual:@"automatic"]&&!error&&[(NSHTTPURLResponse *)response statusCode]==200)self.localViewerStatus.text=@"READY";else [self probeBroadcast];
    });}] resume];
}
- (void)stopBroadcast {
    if(!self.broadcastArmed)return;NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:8080/local/broadcast/stop"]];request.HTTPMethod=@"POST";[request setValue:@"app" forHTTPHeaderField:@"X-ScreenLink-Control"];request.timeoutInterval=2;[[NSURLSession.sharedSession dataTaskWithRequest:request] resume];
    self.localViewerRequestID=nil;self.localViewerApprove.enabled=NO;self.localViewerReject.enabled=NO;self.localViewerStatus.text=@"Local alias viewer: stopped.";
    self.broadcastArmed=NO;self.broadcastPicker.hidden=YES;self.broadcastToken=nil;[NSUserDefaults.standardUserDefaults setBool:NO forKey:@"screenBroadcastArmed"];
}
- (void)startRouteProbe {
    [self.vpn connectRouteProbe:^(BOOL ok){if(!ok)return;
        [self prepareBroadcast];
        [self append:@"ROUTING EXPERIMENT ONLY: start the system screen broadcast so the local server stays available. No website pairing or YouTube needed. While parked, try the FULL URLs http://172.20.10.1:8080/local-route-probe and http://240.3.3.3:8080/local-route-probe in Tesla. A success page proves TCP reached this phone; failure does not identify browser policy by itself. Copy the test log and Route probe status. Disconnect VPN, then reconnect normally to remove the alias."];
    }];
}
- (void)routeProbeStatus { [self.vpn routeProbeStatus]; }
- (void)connectVPN { [self.vpn connect:nil]; }
- (void)disconnectVPN { [self.vpn disconnect]; }
- (void)withVPN:(void (^)(void))ready {
    if(2-self.discoveryMode.selectedSegmentIndex!=SLDiscoveryPhoneVPN || self.vpn.connected){ready();return;}
    [self.vpn connect:^(BOOL ok){if(ok)ready();}];
}
- (void)start { if(self.broadcastArmed){[self probeBroadcast];[self append:@"Screen broadcast mode is selected. Start it using the system broadcast button; Stop sharing exits this mode before starting the normal receiver."];return;} [self withVPN:^{[self startReceiver];}]; }
- (void)startReceiver {
    if(!self.receiver.isRunning)self.receiver.discoveryMode=2-self.discoveryMode.selectedSegmentIndex;
    if([self.receiver start]){[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"receiverArmed"];UIApplication.sharedApplication.idleTimerDisabled=YES;[self links];}
}
- (void)stop {SLActivityFinish();self.mediaStartGeneration++;self.mediaOnlyRestarting=NO;[NSUserDefaults.standardUserDefaults setBool:NO forKey:@"resumeYouTubeOnReturn"]; [self stopBroadcast]; [NSUserDefaults.standardUserDefaults setBool:NO forKey:@"receiverArmed"];[self.session finish];[self endGrace];[self.receiver stop];[self.preview reset];[self.preview removeFromSuperview];self.preview=nil;if(_lastPixel){CVPixelBufferRelease(_lastPixel);_lastPixel=NULL;}UIApplication.sharedApplication.idleTimerDisabled=NO;[self append:@"Stopped. Video frames cleared."]; }
- (void)startMedia {
    if(self.broadcastArmed){[self probeBroadcast];[self append:@"In screen broadcast mode, select ScreenLink VPN Phone inside YouTube AirPlay, then open Google Maps. The extension owns the receiver; no timed task or floating preview is needed for the main app. Verify both streams on your iPhone."];return;}
    [self withVPN:^{[self startMediaReady];}];
}
- (void)startMediaReady {
    [self startReceiver];if(!self.receiver.isRunning)return;
    self.session.allowWaitingForVideo=YES;[self.session start];
    [self append:@"NATIVE VIDEO TEST: open the fixed hotspot link on your Mac. Then switch to YouTube on iPhone, tap Cast → AirPlay & Bluetooth devices → ScreenLink VPN Phone. Do not start Control Center Screen Mirroring. Browser playback includes audio; press Play with sound on the Mac. A timed background session must be active before leaving ScreenLink. Native YouTube compatibility needs a device test."];
}
- (void)startSession {
    self.session.allowWaitingForVideo=NO;
    if(!self.receiver.videoIsLive){[self append:@"The AirPlay video connection is not live yet. Reconnect ScreenLink VPN Phone in Screen Mirroring and wait for at least 10 fresh frames before starting the background test."];return;}
    [self.session start];
}
- (void)receivedPixel:(CVPixelBufferRef)pixel {
    CVPixelBufferRetain(pixel);if(_lastPixel)CVPixelBufferRelease(_lastPixel);_lastPixel=pixel;
    [self.preview receivePixelBuffer:pixel];
}
- (void)startFloating {
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
        if(self.preview.active || self.session.active){[self append:@"Transition time ended; PiP or background session is active. Continuing the receiver."];[self endGrace];return;}
        [self endGrace];[self append:@"PiP is inactive and background grace expired. Receiver remains armed, but iOS may suspend it. Return to ScreenLink to resume listening; a VPN alone does not grant background execution."];
    }];
}
- (void)endGrace {
    if(self.backgroundTask!=UIBackgroundTaskInvalid){[UIApplication.sharedApplication endBackgroundTask:self.backgroundTask];self.backgroundTask=UIBackgroundTaskInvalid;}
}
- (void)background {
    self.networkProbe.delegate=nil;[self.networkProbe stop];self.networkProbe=nil;
    if(self.broadcastArmed){[self append:@"Main app backgrounded in screen broadcast mode. The broadcast extension owns the streams while iOS keeps the user-started screen broadcast active."];[self endGrace];return;}
    if(self.session.active){[self append:@"App backgrounded with a timed session active. Verify the H.264 viewer keeps updating without PiP."];[self endGrace];}
    else if(self.preview.active){[self append:@"App backgrounded with floating preview active. Test whether the viewer keeps updating."];[self endGrace];}
    else {[self append:@"Floating preview is not active. Only a short background grace is available. Return and start floating preview before switching apps."];[self beginGrace];}
}
- (void)active {
    [self requestLocalNetwork];
    if([NSUserDefaults.standardUserDefaults boolForKey:@"resumeYouTubeOnReturn"]){[self resumeYouTubeOnReturn];return;}
    if(self.broadcastArmed){[self probeBroadcast];return;}
    if([NSUserDefaults.standardUserDefaults boolForKey:@"receiverArmed"] && !self.receiver.isRunning)[self start];
}
- (void)foreground {
    [self endGrace];[self append:@"App returned to foreground."];
}
@end
@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic) BOOL pendingWidgetStart;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[Controller new];[self.window makeKeyAndVisible];NSURL *url=options[UIApplicationLaunchOptionsURLKey];if([self isWidgetURL:url])self.pendingWidgetStart=YES;return YES;
}
- (BOOL)isWidgetURL:(NSURL *)url {return [url.scheme.lowercaseString isEqual:@"screenlink"]&&([url.host isEqual:@"start-youtube"]||[url.host isEqual:@"resume"]);}
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
 if(![self isWidgetURL:url])return NO;
 self.pendingWidgetStart=YES;
 if(app.applicationState==UIApplicationStateActive)[self consumeWidgetStart];
 return YES;
}
- (void)applicationDidBecomeActive:(UIApplication *)application {[self consumeWidgetStart];}
- (void)consumeWidgetStart {
 if(!self.pendingWidgetStart)return;
 self.pendingWidgetStart=NO;
 [(Controller *)self.window.rootViewController startFromWidget];
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(AppDelegate.class));}}

