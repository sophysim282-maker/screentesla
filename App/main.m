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
#import <Network/Network.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "IdentityStore.h"
#import "StreamNotifier.h"
// Swift class has an explicit Objective-C runtime name; no generated header.
@protocol SLSessionDisconnectAPI
- (void)stopForDisconnectAll;
@end
@protocol SLPendingWidgetAPI
- (void)cancelPendingWidgetAction;
@end
// Build 87: ScreenLink Maps (Swift) — Car Maps navigation inside ScreenLink.
@protocol SLMapsLauncherAPI
+ (UIViewController *)mapsController;
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
// Build 105: Maps/KeepAwake.swift, reached by name like the other Swift parts.
// Build 111 (TikTok test): Maps/TikTokBrowser.swift.
@protocol SLTikTokLauncherAPI
+ (UIViewController *)controller;
+ (void)setLog:(void (^)(NSString *))block;
@end
// Build 115: Maps/WaitingScreen.swift.
@protocol SLWaitingLauncherAPI
+ (UIViewController *)controller;
@end
@protocol SLWaitingHomeAPI
+ (NSString *)summary;
+ (NSInteger)versionNumber;
+ (NSData *)firstPicture;
@end
@protocol SLKeepAwakeAPI
+ (void)start;
+ (void)stop;
+ (NSString *)problem;
+ (void)setLog:(void (^)(NSString *))block;
@end
@interface Controller : UIViewController <NSNetServiceBrowserDelegate,UIDocumentPickerDelegate> { CVPixelBufferRef _lastPixel; }
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
@property(nonatomic) BOOL keepAwakeLogged;
@property(nonatomic) NSInteger homeWaitingVersion;
@property(nonatomic) BOOL homeWaitingLoaded;
@property(nonatomic) BOOL mapsChoiceShown;
// Build 106: status light, background self-repair and internet watch.
@property(nonatomic,strong) NSTimer *healthTimer;
@property(nonatomic) NSInteger vpnMissingChecks;
@property(nonatomic) NSTimeInterval lastVPNRepair;
@property(nonatomic) BOOL internetLost;
@property(nonatomic,strong) nw_path_monitor_t internetMonitor;
@property(nonatomic) BOOL userDisconnected,disconnectNeedsAttention;
@property(nonatomic) NSUInteger previewIndex;
@property(nonatomic,strong) NSURLSession *disconnectSession;
@property(nonatomic,copy) NSString *homeFailure;
@property(nonatomic) NSUInteger soundOnlyCheck;
@property(nonatomic) BOOL discoveryPolicyDenied;
@end
@implementation Controller
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.backgroundTask=UIBackgroundTaskInvalid;self.userDisconnected=[NSUserDefaults.standardUserDefaults boolForKey:@"manualDisconnected"];self.disconnectFlow=[SLDisconnectFlow new];
    UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=6;stack.translatesAutoresizingMaskIntoConstraints=NO;
    UIScrollView *scroll=[UIScrollView new];self.developerScroll=scroll;self.developerStack=stack;scroll.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:scroll];[NSLayoutConstraint activateConstraints:@[[scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],[scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]]];[scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:8],[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-8],[stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],[stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],[stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32]]];
    UILabel *title=[UILabel new];title.text=[NSString stringWithFormat:@"ScreenLink · %@ / %@",NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]?:@"?",NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]?:@"?"];title.font=[UIFont boldSystemFontOfSize:21];[stack addArrangedSubview:title];
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
    NSArray *labels=@[@"Import website certificate",@"Start YouTube · no recording",@"Start YouTube + PiP · no recording",@"Check Home Screen widget",@"Maps + YouTube · screen broadcast",@"Copy YouTube website link",@"Maps + YouTube · website",@"WebRTC moving-video test",@"Maps + YouTube · prepare screen broadcast",@"Start YouTube video-only",@"Start receiver",@"Copy viewer link",@"Start background session (iOS controlled)",@"Start floating preview",@"Show browser links",@"Copy test log",@"Refresh discovery",@"Stop sharing"];
    NSArray *actions=@[NSStringFromSelector(@selector(importWebsiteCertificate)),NSStringFromSelector(@selector(startYouTubeNoRecording)),NSStringFromSelector(@selector(startYouTubePiP)),NSStringFromSelector(@selector(widgetDiagnostics)),NSStringFromSelector(@selector(quickStart)),NSStringFromSelector(@selector(youtubeOnlyWebsite)),NSStringFromSelector(@selector(youtubeWebsite)),NSStringFromSelector(@selector(rtcPrototype)),NSStringFromSelector(@selector(prepareBroadcast)),NSStringFromSelector(@selector(startMedia)),NSStringFromSelector(@selector(start)),NSStringFromSelector(@selector(copyViewer)),NSStringFromSelector(@selector(startSession)),NSStringFromSelector(@selector(startFloating)),NSStringFromSelector(@selector(links)),NSStringFromSelector(@selector(copyLog)),NSStringFromSelector(@selector(refreshDiscovery)),NSStringFromSelector(@selector(stop))];
    for(NSUInteger i=0;i<labels.count;i++) {
        UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];[button setTitle:labels[i] forState:UIControlStateNormal];[button.heightAnchor constraintEqualToConstant:34].active=YES;
        [button addTarget:self action:NSSelectorFromString(actions[i]) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:button];
    }
    UIStackView *vpnRow=[UIStackView new];vpnRow.axis=UILayoutConstraintAxisHorizontal;vpnRow.distribution=UIStackViewDistributionFillEqually;
    for(NSString *name in @[@"Connect built-in VPN",@"Disconnect VPN"]){UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];[button setTitle:name forState:UIControlStateNormal];[button.heightAnchor constraintEqualToConstant:34].active=YES;[button addTarget:self action:[name hasPrefix:@"Connect"]?@selector(connectVPN):@selector(disconnectVPN) forControlEvents:UIControlEventTouchUpInside];[vpnRow addArrangedSubview:button];}
    [stack insertArrangedSubview:vpnRow atIndex:3];
    for(NSString *title in @[@"Experimental virtual-IP probe",@"Route probe status"]){UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];[button setTitle:title forState:UIControlStateNormal];[button.heightAnchor constraintEqualToConstant:34].active=YES;[button addTarget:self action:[title hasPrefix:@"Experimental"]?@selector(startRouteProbe):@selector(routeProbeStatus) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:button];}
    self.localViewerStatus=[UILabel new];self.localViewerStatus.numberOfLines=0;self.localViewerStatus.font=[UIFont systemFontOfSize:13];self.localViewerStatus.text=@"Local viewer: not connected. HTTPS: https://car.tesla4khmer.com/ ; HTTP fallback: http://3.3.3.3:8080/";[stack addArrangedSubview:self.localViewerStatus];
    for(NSString *name in @[@"Approve local viewer",@"Reject local viewer",@"Disconnect local viewer"]){UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];[button setTitle:name forState:UIControlStateNormal];[button.heightAnchor constraintEqualToConstant:34].active=YES;[button addTarget:self action:[name hasPrefix:@"Approve"]?@selector(approveLocalViewer):([name hasPrefix:@"Reject"]?@selector(rejectLocalViewer):@selector(disconnectLocalViewer)) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:button];if([name hasPrefix:@"Approve"]){self.localViewerApprove=button;button.enabled=NO;}else if([name hasPrefix:@"Reject"]){self.localViewerReject=button;button.enabled=NO;}}
    self.text=[UITextView new];self.text.editable=NO;[self.text.heightAnchor constraintEqualToConstant:230].active=YES;self.text.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];[stack addArrangedSubview:self.text];
    self.broadcastArmed=[NSUserDefaults.standardUserDefaults boolForKey:@"screenBroadcastArmed"];
    self.receiver=[Receiver new];__weak Controller *weak=self;
    self.vpn=[LocalVPN new];self.vpn.status=^(NSString *message){Controller *owner=weak;if([message hasPrefix:@"Built-in VPN failed"]||[message hasPrefix:@"VPN connection timed out"]||[message hasPrefix:@"VPN extension is missing"])owner.homeFailure=@"Couldn’t connect. Check the iOS VPN prompt or open Developer for details, then try Start again.";[owner append:message];};
    self.receiver.status=^(NSString *message){Controller *owner=weak;if([message hasPrefix:@"AIRPLAY DISCOVERY BLOCKED"])owner.discoveryPolicyDenied=YES;else if([message hasPrefix:@"Local proxy address verified:"])owner.discoveryPolicyDenied=NO;if([message hasPrefix:@"Local HTTPS not started"])owner.homeFailure=[SLIdentityStore hasIdentity]?@"The website certificate can’t be used (expired or wrong). Open Developer → Import website certificate.":@"Website certificate missing. Open Developer → Import website certificate, then pick your earlier ScreenLink IPA.";[owner append:message];};
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
    [self append:@"Version 0.20.90 / build 127: Google navigation engine. While driving a route, the turns, the lanes, the distances, the arrival time and new routes now come from Google\'s Navigation SDK (the engine of the Google Maps app), not from ScreenLink\'s own turn logic. Lanes show under the turn banner on the phone. The car and the cube get Google\'s turn through the same path as before. If Google cannot start (Navigation SDK not enabled for the key, terms refused), the old logic runs and the log says why: GOOGLE NAVIGATION: …. Includes build 126."];
    [self append:@"Earlier build 126: background without PiP. The silent keep-awake sound starts when you press Start (not only after iOS paused the app) and is restarted if something stops it. New line on Home: Small window (PiP) On / Off; with Off no small window opens. Log: BACKGROUND (when you leave) and BACKGROUND REPORT (when you come back: how long away, and whether iOS paused ScreenLink). Includes build 125."];
    [self append:@"Earlier build 125: Maps switch. Home > Maps asks to open the maps. Closed (default): no map system runs and the car asks for no map, only the video. Open: the phone map, the map beside the video in the car and the Orbit Cube turns work again; the car gives the video first place. Tap Maps again to show the map or to close all maps. Includes build 124."];
    [self append:@"Earlier build 124: Phone sound. New line on Home (on by default): in YouTube mode ScreenLink is announced as a picture-only AirPlay device, so the sound of other apps (Messenger, Telegram …) stays on the phone speaker while the car plays the video. If ScreenLink VPN Phone is missing in YouTube with it on, switch it off, then Disconnect all and Start. Includes build 123."];
    [self append:@"Earlier build 123: TikTok auto scroll, more ways and proof. After each try ScreenLink checks whether the page really moved; if not it tries the next way: scroll to the next video, the page\'s next button, the arrow key, then a finger swipe made by the app. The log says which way worked (TIKTOK: auto scroll result) and what the page is made of (TIKTOK PAGE lines: number of videos, how the list scrolls, control names, boxes on top, what ScreenLink hid). Includes build 122."];
    [self append:@"Earlier build 122: TikTok auto scroll and next video ready. Auto scroll now follows the car: when the car reaches the end of the video, ScreenLink moves the page to the next one (and tries three ways to move it). The playing TikTok video and the next ones on the page are downloaded whole to the phone, so the car gets them from memory. Log: TIKTOK: the car reached the end …, TIKTOK: preparing the next …, MEDIA FILE READY. Includes build 121."];
    [self append:@"Earlier build 121: lighter 4K. A picture larger than 1440p is painted at the size of the car screen instead of at full 4K size, about four times less painting work; 1440p and smaller are unchanged. The CAR PLAYER summary line now shows the real video size and the painted size, paint time, screen step time, and LIKELY CAR TOO SLOW or LIKELY INTERNET TOO SLOW. Includes build 120."];
    [self append:@"Earlier build 120: TikTok stays inside ScreenLink. Every page move in the TikTok screen is now opened in place and is not offered to the TikTok app or Safari, also when the page itself jumps after a tap. Log: TIKTOK: page moved to … kept inside ScreenLink. Includes build 119."];
    [self append:@"Earlier build 119: Keep playing. New line on Home (on by default): a pause or stop that YouTube sends when another app takes the sound, for example a Telegram voice message, is ignored and the car plays this video to its end. Pause with the ScreenLink pause button. Log: KEEP PLAYING …, and AIRPLAY SOUND ARRIVING when the iPhone sends sound to ScreenLink instead of the phone speaker. Includes build 118."];
    [self append:@"Earlier build 118: unstick video downloads. A download from the video site that gets no data for 5 seconds is dropped and tried again on a new connection (up to 3 tries) instead of blocking the car for 21 seconds. New log lines: MEDIA PIECE SLOW / RECOVERED / FAILED (internet to phone), MEDIA PIECE TO CAR SLOW / NOT DELIVERED (phone to car), MEDIA PIECE REFUSED (all download places busy). Includes build 117."];
    [self append:@"Earlier build 117: cinematic entrance. When the app opens, the car pictures fill the screen; scrolling moves the camera (back, side, three-quarter view), then the status appears and the picture flies into its place on Home. A tap plays the rest alone. It needs the four entrance pictures inside the app; without them the old short entrance plays. Nothing in the video path changed. Includes build 116."];
    [self append:@"Earlier build 116: new Home screen. Dark and simple: the status under the name, one big picture (your waiting screen picture when you have one), round quick buttons (Start, pause, video settings, waiting screen, Disconnect all) and a list: Video, TikTok, Waiting screen, Maps, Orbit Cube, Help. The menu button at the top right opens the Developer screen and the test log. Every function works as before. Includes build 115."];
    [self append:@"Earlier build 115: My waiting screen. Home, Maps button, Waiting screen: choose pictures, GIFs or short videos from Photos. The car shows them while it waits and while a video loads, and changes to the YouTube picture with the transition you pick (Fade, Zoom, Slide, Flash, Dark dip). Files stay on the phone and go only to your car. Includes build 114."];
    [self append:@"Earlier build 114: faster video start. The phone now fetches the two YouTube lists the car needs first (not all 20 in turn) and downloads the first video and sound pieces at once, before the car asks (log: MEDIA WARM-UP). The car notices a new video within 0.4 s instead of 1 s. On Auto, after a slowly downloaded video the next one starts at 720p. The player itself is unchanged. Includes build 113."];
    [self append:@"Earlier build 113 TEST: TikTok page no longer keeps asking to open the app (it presses Not now and hides Open app buttons), and has an Auto button: when it is ON the next video starts by itself when the current one ends. Everything else is build 112."];
    [self append:@"Earlier build 112 TEST: TikTok stays inside ScreenLink. Taps no longer jump to the TikTok app or the App Store, and sign-in windows (for example Continue with Google) open inside ScreenLink. If Google refuses to sign in inside an app, use email or username with a password. Everything else is build 111."];
    [self append:@"Earlier build 111 TEST: TikTok inside ScreenLink without screen recording. Tap the Maps button on Home, then Open TikTok (test). Log in, play a video, tap Send to car or the AirPlay button and choose ScreenLink VPN Phone. Every step writes a TIKTOK TEST line here. It may not work; that is what this build finds out. Everything else is build 110."];
    [self append:@"Earlier build 110: finds and fights iOS pausing ScreenLink in the background. A one-second heartbeat notices when iOS paused or slowed the app (log: APP PAUSED BY iOS / BACKGROUND WORK SLOWED) and then starts a silent sound so iOS keeps the app running at full speed without PiP. The loop that accepts the car connections runs at normal priority. The two build 109 changes that forced new connections (4 s give-up, page reload) are removed. Maps stay closed."];
    [self append:@"Earlier build 109: video stability. With Quality on Auto, when picture pieces arrive too slowly the video steps down by itself (1080p to 720p to 480p) instead of freezing; a quality you choose yourself is never changed. A stuck request is retried after 4 s (was 7 s). The car page loads itself again after 45 s without any answer. Maps stay closed as in build 108."];
    [self append:@"Earlier build 108: ALL MAP SYSTEMS CLOSED. No map screen on the phone, no map on the car, and the car page asks the phone for no map data. Only the video runs. Everything else is as in build 107."];
    [self append:@"Earlier build 107: video first. The car map can no longer take the connections the video needs: one map download at a time while a video plays, none while a video is starting or short of picture, and the phone gives up on a slow map square after 2 s. The CAR PLAYER summary now also says whether a map is running and how fast the last picture piece downloaded. Player and quality choices unchanged."];
    [self append:@"Earlier build 106: stability. (A) Status light on Home: green Car connected, yellow or red with the one thing to do (hotspot, 3.3.3.3 link, phone internet, phone hot, car not opened). (B) Self-repair every 5 s also in the background: dead listeners are rebound and the 3.3.3.3 link is reconnected. (D) When the phone internet returns, the car retries the video at once. 4K and 1440p choices unchanged. Player unchanged."];
    [self append:@"Earlier build 105: (1) ScreenLink stays awake in the background while sharing, without PiP (location keep-alive, blue mark). (2) New fast car map: the car draws it itself from map squares this iPhone hands over, so drag and zoom are instant and the car never contacts Google. Needs Map Tiles API on your Google key; the map screen shows an orange button if it is missing. Video unchanged."];
    [self append:@"Earlier build 104: for China-version cars the car browser now talks only to this iPhone and never to Google. The car map comes from the phone as pictures; search, place card, Start, zoom, drag and tap-a-place work through the phone. If the map picture for a locked phone fails, an orange Tap to fix button says why (Maps Static API). The Google-drawn car map is a switch in Maps Settings, off by default. Cube status now lists what the cube offers."];
    [self append:@"Earlier build 103: new switch in the map settings, Orbit Cube (Bluetooth): sends the next turn, distance, road name and minutes left of the ScreenLink Maps route to an Orbit Cube display. Off by default. Nothing else changed. Includes build 102."];
    [self append:@"Earlier build 102: the log now says how long each video took to show its first picture (CAR PLAYER: start took ...), to find why the first video is slow. Measuring only; playback is unchanged. Includes build 101."];
    [self append:@"Earlier build 101: the map screen now says if the car draws the map itself (works when you leave the app) or not. If Google refuses the key on the car website, an orange Tap to fix button shows the steps and a box to paste a website key; the car then reloads its map. Includes build 100."];
    [self append:@"Earlier build 100: the big car map is touched directly like the phone (drag, pinch, turn, tilt, Re-centre). Search on the car with saved places and Google suggestions. Tap a place name on the map to open that place with its real name, pick a route and press Start on the car. Traffic and route refresh every 2 minutes while driving. Includes build 99 (Google look). Video unchanged from build 97."];
    [self append:@"Earlier build 99: the car map now looks like Google Maps navigation: 3D view that turns with the car, real Google day and night colours, live traffic, blue route with a red destination pin, smooth movement, Google-style turn banner with arrows and an arrival card. Only the map changed; video unchanged from build 97."];
    [self append:@"Earlier build 98: the car draws the navigation map itself from the phone GPS and route, so it keeps working when you leave ScreenLink or lock the phone. Car map ON/OFF switch on the map screen. Needs Maps JavaScript API on your Google key. Video unchanged from build 97."];
    [self append:@"Earlier build 97: the car keeps a saved copy of the website. If the car reloads while it cannot find car.tesla4khmer.com, it shows the ScreenLink page and reconnects by itself instead of server IP address could not be found. Open the website once with the phone connected so the copy is saved."];
    [self append:@"Earlier build 96: while the car is lost, the log says WEBSITE STILL LOST every 30 s with Personal Hotspot and 3.3.3.3 status. Includes build 95 (late YouTube answers kept, car page never gives up)."];
    [self append:@"Earlier build 95: when YouTube answers a playlist request late (it was rejected and the car waited ~55 s), the late answer is now kept; the car page never stops recovering by itself (no more Press Retry video). Use Auto quality: 4K is too heavy for the hotspot."];
    [self append:@"Earlier build 94: car player keeps retrying for about 30 s when the car loses the phone for a moment (Failed to fetch), instead of giving up after about 6 s while video was still buffered. Includes 3.3.3.3, connection fixes and 1440p/4K test."];
    [self append:@"Earlier build 93: optional 1440p and 4K TEST quality on the Home player switch (car page follows it). Auto, 720p and 1080p are unchanged. 4K needs more Wi-Fi and car decoding power; if it freezes, go back to Auto."];
    [self append:@"Earlier build 92: VPN address changed from 240.3.3.3 to 3.3.3.3 (a normal address that DNS servers do not drop). Car website: https://car.tesla4khmer.com/video (its internet DNS record must also point to 3.3.3.3); HTTP fallback: http://3.3.3.3:8080."];
    [self append:@"Earlier build 91: Opening Navigation map no longer drops YouTube AirPlay/PiP: map voice directions and voice search share ScreenLink\'s audio session (playback, mix with others) instead of switching it to voice-prompt/record. Previous changes: Version 0.20.53 / build 90: Detects when YouTube sends sound only (AirPlay audio, no video) so the car gets no new video and PiP keeps the old one; Home, the log and a notification say to choose ScreenLink VPN Phone in YouTube AirPlay again. Previous changes: Version 0.20.52 / build 89: Notifications tell you what to do to keep the car stream playing while ScreenLink is in the background: PiP closed or not running, ScreenLink about to be paused, car screen connection lost, VPN off, website certificate, Local Network permission, car video stopped, plus a one-time PiP tip. Tap a notification to open ScreenLink and resume. Previous changes: Version 0.20.51 / build 88: The rear-screen map stays on when the Navigation map screen is closed, ScreenLink Home is open, another app is open or the phone is locked: it uses the GPS-moved Google map picture with a car marker and the next turn. No screen recording fallback. Previous changes: Version 0.20.50 / build 87: ScreenLink Maps: Car Maps navigation (Google Maps, voice, search, re-routing) inside ScreenLink through Home → Navigation map, using the one 3.3.3.3 VPN and website. The car screen shows a small map with the next turn and arrival beside the video; tap to swap. Video playback unchanged. Previous changes: Version 0.20.49 / build 86: Cosmic Glass Home: animated space background with stars and aurora, a 3D car stage that tilts with the phone and your finger, glass status card with a glowing border while sharing, a shimmering Start button with haptics and a staggered entrance. Respects Reduce Motion. Developer and video playback unchanged. Previous changes: Version 0.20.48 / build 85: ScreenLink Mission Dynamic Island: original rocket, UFO, roadster and comet characters (new one each video), self-running T-minus countdown while waiting for YouTube, Liftoff when the car starts playing, a ring that fills with the video and time left, Hovering when paused, Signal lost and Landed. Video playback unchanged from build 83. Previous changes: Version 0.20.47 / build 84: Live Car Player widget (small, medium, large) shows On/Off, car connection, playing time, quality and volume with play/pause, 10 s skips, volume, mute, quality, sound and Start/Stop. Control Center (iOS 18): ScreenLink On/Off toggle, Car Play/Pause and Car Mute. Video playback unchanged from build 83. Previous changes: Version 0.20.46 / build 83: Website connections stay open up to 2 minutes idle and the car retries a failed check once at once, removing the repeating Failed to fetch. Keep the iPhone unlocked: iOS stops PiP and suspends ScreenLink when the phone locks. Previous changes: Version 0.20.45 / build 82: 32 phone connection slots in the app (was 12) and kept-open website connections close after 5 s idle, so PiP and the car are not refused (WEBSITE BUSY). Previous changes: Version 0.20.44 / build 81: Long YouTube videos no longer fill the media playlist registry (16384 references in the app, was 4096), which made PiP fail and let iOS suspend ScreenLink. Previous changes: Version 0.20.43 / build 80: The HTTPS car website keeps its connections open (keep-alive, 10 s idle) instead of a new connection, name lookup and secure handshake for every request. HTTP 3.3.3.3 unchanged. Previous changes: Version 0.20.42 / build 79: The car player keeps two video downloads in flight, so a new video builds its buffer quickly instead of freezing in the first 10-15 s. Previous changes: Version 0.20.41 / build 78: Auto and 1080p quality are capped at 1920x1088 pixels (720p at 1280x720), so ultra-wide 2560x1072 videos use 1920x804 and the 20 s read-ahead can fill. Previous changes: Version 0.20.40 / build 77: The ScreenLink VPN answers name lookups for car.tesla4khmer.com with 3.3.3.3 itself, so the car website does not depend on an internet DNS answer (server IP address could not be found). Route probe status shows localDNSAnswers. Previous changes: Version 0.20.39 / build 76: The WebCodecs car player now downloads video up to 20 s and sound up to 12 s ahead (was about 2 s video), so short phone or network pauses no longer freeze the picture while sound continues. Decoding and canvas timing unchanged. Previous changes: Version 0.20.38 / build 75: The car page sends its playback problems to this log as CAR PLAYER lines (decoder restarts, picture holds, software decoder switch, player and connection errors, and a summary each minute). Copy test log is all that is needed. Previous changes: Version 0.20.37 / build 74: WebCodecs canvas player: if the hardware video decoder stalls twice within a minute (picture stops, sound continues), the session switches to the software decoder instead of freezing again. Optional ?decoder=software or ?decoder=hardware. Previous changes: Version 0.20.36 / build 73: The car website uses the WebCodecs canvas player by default again, as in build 69. The build 71 browser video player is optional with ?engine=browser. Keeps website certificate import and website diagnostics. Previous changes: Version 0.20.35 / build 72: Developer → Import website certificate: pick your earlier ScreenLink IPA (or certificate + key files) once; the certificate is checked, kept in ScreenLink and used by future builds, so new IPAs no longer need it added. Includes build 71 browser video player on the car website. Previous changes: Version 0.20.34 / build 71: The car website now plays YouTube with the browser's own video player (HLS.js), the same path as the http://3.3.3.3:8080 fallback that played without freezing, drawn on the canvas with Web Audio volume and Normal/Music. The WebCodecs player is unchanged and available with ?engine=webcodecs. Phone and widget controls, approval, reconnect, PiP, VPN and build 70 website diagnostics retained. Previous changes: Version 0.20.33 / build 70: Website diagnostics only. The phone log now records HTTPS handshake failures with the reason, connections refused because all 12 slots are busy, wrong-address requests, and WEBSITE SILENT / WEBSITE BACK when the car stops or resumes HTTPS requests. The car page status shows the exact browser error and time. Player, audio, AirPlay media delivery, PiP, VPN and widgets unchanged. Previous changes: Version 0.20.32 / build 69: Interactive Home Screen Car Player widget for quality, volume, mute, play/pause, seek and sound preset during an active session. Previous changes: Minimal fullscreen YouTube car page; quality, volume, sound preset, pause and seeking controlled on the phone. Video selection remains in YouTube. Decoder, canvas timing, audio scheduler and AirPlay media delivery unchanged. Policy-denied discovery retries on foreground or Start; no repeated denied-permission loop. No recording. Original website disconnect cause remains unconfirmed. Previous changes: Removes saved/offline website; retires old browser cache. Connection interruptions retain buffered media while reauthorizing; same-browser proof survives reload/hotspot peer changes. No HTTPS watchdog. Build64 playback, audio, PiP, VPN and widgets retained. Physical Tesla reconnection still requires validation. Previous changes: Light/dark glass home and website; user car decoration stops before sharing; expanded widget and Dynamic Island app-opening controls. Build 63 playback, audio, AirPlay and PiP recovery preserved. Previous changes: Repair dead AirPlay and web listeners in place on foreground; restore the selected real-media PiP mode after returning without recording or clearing viewer authorization. Retain newest late decoded frame and preserve decoder references during timestamp catch-up. Retains build 60: New client home and coordinated icon/cover; full technical controls remain in Developer. Disconnect All stops sharing, background tasks and only ScreenLink VPN, with confirmation and cancelled pending starts. Home Screen controls use explicit app-opening Start/Disconnect deep links. All extension identifiers are preserved. Retains build 59: Recovers defunct Bonjour handles on foreground without restarting healthy AirPlay listeners or viewer authorization. Real-media PiP stall recovery is bounded and never reopens dismissed PiP. Video-only catch-up preserves the audio decoder and clock under delayed video decoding. Bounded playlist snapshots replace permanent registry exhaustion. Physical-device background endurance still requires testing. Retains build 57: The explicit Start YouTube + PiP button starts the receiver without recording and remembers a PiP request before AirPlay arrives. Open YouTube, select ScreenLink, and return once to ScreenLink to let real media prepare the movable PiP. No dummy video is generated. Retains the PiP controller across gaps between songs, pauses while the source is absent, and replaces actual media on a new epoch. Coexistence with YouTube AirPlay still needs physical-device verification. No fixed background duration is promised. Retains build 56: Connection request deadlines now cover response bodies as well as headers, preventing interrupted JSON responses from hanging automatic discovery and health polling. Cached-page restoration now restarts discovery; late approval replies cannot revive abandoned pages. Repeated YouTube Start preserves an already-running receiver. Background button no longer implies a reserved 30-minute grant. Auto source quality accepts lower resolutions up to 1080p. Viewer re-authenticates after sustained connection loss without interrupting healthy buffered playback, resets stale Maps state on a new connection, and supports authenticated hotspot peer changes. Adds elapsed-time background expiration diagnostics. YouTube-only starts the app-owned AirPlay receiver without ReplayKit recording. Removes the recording-based YouTube shortcut from build 52. Copy YouTube website link never opens recording. PiP stays optional and manual. The existing timed task is controlled by iOS and may end early; returning to ScreenLink resumes its receiver. No unlimited background runtime is promised. Maps screen broadcast remains a separate, explicitly labelled choice. Retains inline Tesla buttons, HD range downloads and in-place transport retries. Audio and Maps engines are unchanged."];
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
 self.dashboard.startAction=^{[weak startHome];};self.dashboard.mapAction=^{[weak showMaps];};[NSUserDefaults.standardUserDefaults registerDefaults:@{@"keepPlaying":@YES,@"phoneSound":@YES}];self.dashboard.moreAction=^(NSString *key){[weak openMore:key];};self.dashboard.disconnectAction=^{[weak disconnectAll];};self.dashboard.developerAction=^{[weak showDeveloper];};self.dashboard.copyAction=^{[weak youtubeOnlyWebsite];};
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
// Build 116: the Home list lines that open their own screen.
- (void)openMore:(NSString *)key {
 __weak typeof(self) weakSelf=self;
 if([key isEqual:@"pip"]){BOOL off=![NSUserDefaults.standardUserDefaults boolForKey:@"pipOff"];[NSUserDefaults.standardUserDefaults setBool:off forKey:@"pipOff"];[self append:off?@"SMALL WINDOW (PiP) OFF: no small window opens. ScreenLink stays awake in the background with the silent sound and location.":@"SMALL WINDOW (PiP) ON: the small window opens again when you return to ScreenLink."];[self refreshHomeExtras];return;}
 if([key isEqual:@"phonesound"]){BOOL on=![NSUserDefaults.standardUserDefaults boolForKey:@"phoneSound"];[NSUserDefaults.standardUserDefaults setBool:on forKey:@"phoneSound"];[self append:on?@"PHONE SOUND switched ON: takes effect after Disconnect all and Start.":@"PHONE SOUND switched OFF: takes effect after Disconnect all and Start."];[self refreshHomeExtras];
  UIAlertController *note=[UIAlertController alertControllerWithTitle:on?@"Phone sound: On":@"Phone sound: Off" message:@"To use the new setting, press the red power button (Disconnect all), then Start, then choose ScreenLink VPN Phone in YouTube again." preferredStyle:UIAlertControllerStyleAlert];[note addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:note animated:YES completion:nil];return;}
 if([key isEqual:@"keep"]){BOOL on=![NSUserDefaults.standardUserDefaults boolForKey:@"keepPlaying"];[NSUserDefaults.standardUserDefaults setBool:on forKey:@"keepPlaying"];[self append:on?@"KEEP PLAYING ON: a pause or stop from YouTube (for example when a Telegram voice message plays) no longer pauses the car video.":@"KEEP PLAYING OFF: YouTube can pause and stop the car video again."];[self refreshHomeExtras];return;}
 if([key isEqual:@"tiktok"]){Class launcher=NSClassFromString(@"SLTikTokLauncher");if(!launcher)return;
  [(id<SLTikTokLauncherAPI>)launcher setLog:^(NSString *line){dispatch_async(dispatch_get_main_queue(),^{[weakSelf append:line];});}];
  [self presentViewController:[(id<SLTikTokLauncherAPI>)launcher controller] animated:YES completion:nil];return;}
 if([key isEqual:@"waiting"]){Class launcher=NSClassFromString(@"SLWaitingLauncher");if(!launcher)return;
  [self presentViewController:[(id<SLWaitingLauncherAPI>)launcher controller] animated:YES completion:nil];[self append:@"WAITING SCREEN: opened. Files you choose are shown on the car while it waits and while a video loads."];return;}
 if([key isEqual:@"cube"]){UIAlertController *note=[UIAlertController alertControllerWithTitle:@"Orbit Cube" message:@"The cube shows the turns of a ScreenLink Maps route. Maps are closed in this build, so the cube has nothing to show yet." preferredStyle:UIAlertControllerStyleAlert];[note addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:note animated:YES completion:nil];}
}
// Build 116: the waiting screen line and the big picture on Home follow what the user chose.
- (void)refreshHomeExtras {
 [self.dashboard setSubtitle:[NSUserDefaults.standardUserDefaults boolForKey:@"keepPlaying"]?@"On · other apps cannot pause the car video":@"Off · YouTube can pause the car video" forRow:@"keep"];
 [self.dashboard setSubtitle:[NSUserDefaults.standardUserDefaults boolForKey:@"phoneSound"]?@"On · Messenger, Telegram … play on the phone":@"Off · other apps' sound goes to AirPlay (silent)" forRow:@"phonesound"];
 {BOOL mapsOpen=[NSUserDefaults.standardUserDefaults boolForKey:@"mapsOpen"];[self.dashboard setSubtitle:mapsOpen?@"Open · tap to show or close":@"Closed · tap to open" forRow:@"maps"];[self.dashboard setSubtitle:mapsOpen?@"Shows the turns of a Maps route":@"Needs Maps (closed)" forRow:@"cube"];}
 [self.dashboard setSubtitle:[NSUserDefaults.standardUserDefaults boolForKey:@"pipOff"]?@"Off · stays awake with silent sound":@"On · the small window keeps the app awake" forRow:@"pip"];
 Class store=NSClassFromString(@"SLWaitingStore");if(!store||!self.dashboard)return;
 [self.dashboard setSubtitle:[(id<SLWaitingHomeAPI>)store summary] forRow:@"waiting"];
 NSInteger version=[(id<SLWaitingHomeAPI>)store versionNumber];if(version==self.homeWaitingVersion&&self.homeWaitingLoaded)return;self.homeWaitingVersion=version;self.homeWaitingLoaded=YES;
 NSData *picture=[(id<SLWaitingHomeAPI>)store firstPicture];[self.dashboard showHeroImage:picture.length?[UIImage imageWithData:picture]:nil];
}
- (void)showMaps {
 // Build 125: Maps have a switch. Closed (default): no map system runs, only the video. Open: the phone map,
 // the car map and the cube work as before build 108; the car gives the video first place.
 BOOL open=[NSUserDefaults.standardUserDefaults boolForKey:@"mapsOpen"];__weak typeof(self) weakMaps=self;
 if(!open){UIAlertController *ask=[UIAlertController alertControllerWithTitle:@"Maps are closed" message:@"Closed: only the video runs (most stable). Open: the map works on the phone and beside the video in the car. The video always goes first." preferredStyle:UIAlertControllerStyleAlert];
  [ask addAction:[UIAlertAction actionWithTitle:@"Open maps" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"mapsOpen"];[weakMaps append:@"MAPS OPENED by the switch on Home."];[weakMaps refreshHomeExtras];[weakMaps showMaps];}]];
  [ask addAction:[UIAlertAction actionWithTitle:@"Keep closed" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:ask animated:YES completion:nil];return;}
 if(!self.mapsChoiceShown){self.mapsChoiceShown=YES;}
 else{UIAlertController *choice=[UIAlertController alertControllerWithTitle:@"Maps" message:nil preferredStyle:UIAlertControllerStyleAlert];
  [choice addAction:[UIAlertAction actionWithTitle:@"Show the map" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){weakMaps.mapsChoiceShown=NO;[weakMaps showMaps];}]];
  [choice addAction:[UIAlertAction actionWithTitle:@"Close all maps (video only)" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){[NSUserDefaults.standardUserDefaults setBool:NO forKey:@"mapsOpen"];weakMaps.mapsChoiceShown=NO;[weakMaps append:@"MAPS CLOSED by the switch on Home: only the video runs."];[weakMaps refreshHomeExtras];}]];
  [choice addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:choice animated:YES completion:nil];return;}
 Class cls=NSClassFromString(@"SLMapsLauncher");if(!cls){[self append:@"ScreenLink Maps is not available in this build."];return;}
 {Class engine=NSClassFromString(@"SLGoogleNav");if(engine)[(id<SLKeepAwakeAPI>)engine setLog:^(NSString *line){dispatch_async(dispatch_get_main_queue(),^{[weakMaps append:line];});}];}
 UIViewController *maps=[(id<SLMapsLauncherAPI>)cls mapsController];if(maps.presentingViewController)return;
 [self presentViewController:maps animated:YES completion:nil];[self append:@"SCREENLINK MAPS: navigation opened. The car screen shows a small map beside the video while you navigate."];
}
- (void)showDeveloper {
 [NSLayoutConstraint deactivateConstraints:self.previewConstraints?:@[]];self.previewConstraints=nil;[self.previewSlot removeFromSuperview];[self.developerStack insertArrangedSubview:self.previewSlot atIndex:MIN(self.previewIndex,self.developerStack.arrangedSubviews.count)];
 self.dashboard.hidden=YES;self.developerScroll.hidden=NO;
}
- (void)updateHome {
 if(!self.dashboard)return;
 [self refreshHomeExtras];
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
 // Build 106: status light. While sharing, say in plain words whether the car is really connected
 // and, if not, the one thing to do. Green = car connected, yellow = wait / care, red = link broken.
 NSInteger level=0;
 if(self.receiver.isRunning&&!self.broadcastArmed&&!busy&&!self.userDisconnected&&!self.homeFailure.length&&!self.discoveryPolicyDenied){
  NSDictionary *health=[self.receiver linkHealth];double car=[health[@"carSeconds"] doubleValue];
  if(![health[@"vpn"] boolValue]){level=3;status=@"Link to the car is off";detail=@"The 3.3.3.3 link is missing. ScreenLink is reconnecting it by itself. If this stays for a minute, tap Start.";}
  else if(![health[@"hotspot"] boolValue]){level=3;status=@"Hotspot is off or the car left it";detail=@"Turn on Personal Hotspot in iPhone Settings and check that the car’s Wi-Fi shows this iPhone.";}
  else if(self.internetLost){level=2;status=@"No internet on the phone";detail=@"Mobile data is gone. The video continues by itself when it comes back.";}
  else if(NSProcessInfo.processInfo.thermalState>=NSProcessInfoThermalStateSerious){level=2;status=@"Phone is hot";detail=@"Take it off the wireless charger and out of the sun, and close the floating video. Heat can drop the hotspot.";}
  else if(car<0||car>12){level=2;status=@"Waiting for the car";detail=@"Open car.tesla4khmer.com/video in the car browser.";}
  else{level=1;status=@"Car connected";detail=self.youtubePiP.active?@"Floating video is on. You can close it; ScreenLink stays awake without it.":@"Choose ScreenLink in YouTube’s AirPlay menu. You can leave this app; it stays awake.";}
 }
 self.dashboard.healthLevel=level;
 [self.dashboard showStatus:status detail:detail busy:busy sharing:sharing disconnecting:self.disconnectFlow.running attention:self.disconnectNeedsAttention||self.discoveryPolicyDenied||self.homeFailure.length>0];
}
// Build 106: every 5 s while sharing (also in the background, the app stays awake since 105):
// rebind dead listeners, bring the 3.3.3.3 link back, and refresh the status light.
- (void)startHealthWatch {
 if(!self.healthTimer){self.healthTimer=[NSTimer timerWithTimeInterval:5 target:self selector:@selector(healthTick) userInfo:nil repeats:YES];[NSRunLoop.mainRunLoop addTimer:self.healthTimer forMode:NSRunLoopCommonModes];}
 if(!self.internetMonitor){nw_path_monitor_t monitor=nw_path_monitor_create();self.internetMonitor=monitor;__weak typeof(self) weak=self;nw_path_monitor_set_queue(monitor,dispatch_get_main_queue());
  nw_path_monitor_set_update_handler(monitor,^(nw_path_t path){typeof(self) owner=weak;if(!owner)return;BOOL lost=nw_path_get_status(path)!=nw_path_status_satisfied;if(lost==owner.internetLost)return;owner.internetLost=lost;
   if(lost)[owner append:@"PHONE INTERNET LOST: mobile data is gone. The receiver and the car link are kept; video continues when it returns."];
   else{owner.receiver.internetBackCount=owner.receiver.internetBackCount+1;[owner append:@"PHONE INTERNET BACK: the car is told to retry the video now."];}
   [owner updateHome];});
  nw_path_monitor_start(monitor);}
}
- (void)stopHealthWatch {[self.healthTimer invalidate];self.healthTimer=nil;if(self.internetMonitor){nw_path_monitor_cancel(self.internetMonitor);self.internetMonitor=nil;}self.internetLost=NO;self.vpnMissingChecks=0;}
- (void)healthTick {
 if(!self.receiver.isRunning||self.userDisconnected||self.disconnectFlow.running||self.broadcastArmed){[self updateHome];return;}
 [self.receiver resumeListenersIfNeeded];
 if(![[self.receiver linkHealth][@"vpn"] boolValue]){self.vpnMissingChecks++;NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
  if(self.vpnMissingChecks>=2&&now-self.lastVPNRepair>30&&!self.mediaOnlyRestarting){self.lastVPNRepair=now;[self append:@"SELF-REPAIR: the 3.3.3.3 link is missing. Reconnecting ScreenLink VPN; the receiver keeps running."];
   __weak typeof(self) weak=self;[self.vpn connectRouteProbe:^(BOOL ok){typeof(self) owner=weak;if(!owner)return;[owner append:ok?@"SELF-REPAIR: ScreenLink VPN is back.":@"SELF-REPAIR: ScreenLink VPN could not reconnect. Open ScreenLink and tap Start."];if(ok&&owner.receiver.isRunning)[owner.receiver refreshDiscovery];[owner updateHome];}];}
 }else self.vpnMissingChecks=0;
 [self updateHome];
}
- (void)startHome {[SLStreamNotifier requestPermission];
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
- (void)append:(NSString *)s { if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self append:s];});return;}[SLStreamNotifier handleLogMessage:s appActive:UIApplication.sharedApplication.applicationState==UIApplicationStateActive];
 // Build 90: YouTube sometimes treats ScreenLink as a speaker (AirPlay sound only, no MEDIA PLAY REQUEST).
 // Then the car gets no new video and PiP holds the old one. Tell the user how to fix it.
 if([s hasPrefix:@"MEDIA PLAY REQUEST"]){self.soundOnlyCheck++;if([self.homeFailure hasPrefix:@"YouTube sent sound only"]){self.homeFailure=nil;[self updateHome];}}
 else if([s hasPrefix:@"raop_rtp starting audio"]&&self.receiver.mediaOnly){NSUInteger check=++self.soundOnlyCheck;__weak Controller *weakSelf=self;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{Controller *owner=weakSelf;
   if(!owner||check!=owner.soundOnlyCheck||!owner.receiver.isRunning||[[owner.receiver nativeMediaState][@"active"] boolValue])return;
   owner.homeFailure=@"YouTube sent sound only, so the car gets no video. In YouTube, tap AirPlay and choose ScreenLink VPN Phone again, or play the video again.";[owner updateHome];
   [owner append:@"YOUTUBE SENT SOUND ONLY: YouTube is using ScreenLink as a speaker (AirPlay audio), so the car gets no new video and PiP keeps the old one. In YouTube, tap AirPlay and choose ScreenLink VPN Phone again, or start the video again."];});}[self updateHome];self.text.text=[self.text.text stringByAppendingFormat:@"\n%@ %@\n",[NSDate date],s];if(self.text.text.length>24000)self.text.text=[self.text.text substringFromIndex:self.text.text.length-18000];[self.text scrollRangeToVisible:NSMakeRange(self.text.text.length,0)]; }
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
        [self append:@"ROUTING EXPERIMENT ONLY: start the system screen broadcast so the local server stays available. No website pairing or YouTube needed. While parked, try the FULL URLs http://172.20.10.1:8080/local-route-probe and http://3.3.3.3:8080/local-route-probe in Tesla. A success page proves TCP reached this phone; failure does not identify browser policy by itself. Copy the test log and Route probe status. Disconnect VPN, then reconnect normally to remove the alias."];
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
    if([self.receiver start]){[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"receiverArmed"];UIApplication.sharedApplication.idleTimerDisabled=YES;[self links];
        [self startHealthWatch];
        // Build 105: stay awake in the background without PiP (location keep-alive, blue mark).
        Class awake=NSClassFromString(@"SLKeepAwake");if(awake){{__weak typeof(self) weakLog=self;[(id<SLKeepAwakeAPI>)awake setLog:^(NSString *line){dispatch_async(dispatch_get_main_queue(),^{[weakLog append:line];});}];}[(id<SLKeepAwakeAPI>)awake start];if(!self.keepAwakeLogged){self.keepAwakeLogged=YES;[self append:@"KEEP AWAKE ON: while sharing, ScreenLink uses location in the background (blue mark at the top of the iPhone) so iOS does not put it to sleep when there is no PiP window. If iOS asks, allow location While Using."];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,8*NSEC_PER_SEC),dispatch_get_main_queue(),^{NSString *problem=[(id<SLKeepAwakeAPI>)awake problem];if([problem isKindOfClass:NSString.class]&&problem.length)[self append:[@"KEEP AWAKE NOT ACTIVE: " stringByAppendingString:problem]];});}}
    }
}
- (void)stop {{Class awake=NSClassFromString(@"SLKeepAwake");if(awake)[(id<SLKeepAwakeAPI>)awake stop];self.keepAwakeLogged=NO;}[self stopHealthWatch];self.discoveryPolicyDenied=NO;[self.dashboard showPlayerState:@{}];self.youtubePiPRequested=NO;[self.youtubePiP reset];[self.youtubePiP removeFromSuperview];self.youtubePiP=nil;SLActivityFinish();self.mediaStartGeneration++;self.mediaOnlyRestarting=NO;[NSUserDefaults.standardUserDefaults setBool:NO forKey:@"resumeYouTubeOnReturn"]; [self stopBroadcast]; [NSUserDefaults.standardUserDefaults setBool:NO forKey:@"receiverArmed"];[self.session finish];[self endGrace];[self.receiver stop];[self.preview reset];[self.preview removeFromSuperview];self.preview=nil;if(_lastPixel){CVPixelBufferRelease(_lastPixel);_lastPixel=NULL;}UIApplication.sharedApplication.idleTimerDisabled=NO;[self append:@"Stopped. Video frames cleared."]; }
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
// Build 71: one-time import of the website certificate from the user's own earlier
// ScreenLink IPA (or certificate + key files). It stays in the app for future builds.
- (void)importWebsiteCertificate {
    UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc]initForOpeningContentTypes:@[UTTypeItem] asCopy:YES];
    picker.allowsMultipleSelection=YES;picker.delegate=self;
    [self append:@"Pick your earlier ScreenLink IPA where https://car.tesla4khmer.com worked (or the certificate and private key files together)."];
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    BOOL saved=NO;NSString *message=[SLIdentityStore importFromURLs:urls success:&saved];
    for(NSURL *url in urls)[NSFileManager.defaultManager removeItemAtURL:url error:nil]; // picker copies only
    [self append:saved?message:[@"WEBSITE CERTIFICATE NOT SAVED: " stringByAppendingString:message]];
    if(saved){self.homeFailure=nil;if(self.receiver.isRunning)[self.receiver resumeListenersIfNeeded];[self updateHome];}
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:saved?@"Website certificate saved":@"Certificate not saved" message:saved?(self.receiver.isRunning?@"The website is starting now. Reload https://car.tesla4khmer.com/video in the car.":@"Tap Start. Then open https://car.tesla4khmer.com/video in the car."):message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:alert animated:YES completion:nil];
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

