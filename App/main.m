#import <UIKit/UIKit.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import "Receiver.h"
#import "FloatingPreview.h"
@interface Controller : UIViewController { CVPixelBufferRef _lastPixel; }
@property(nonatomic,strong) Receiver *receiver;
@property(nonatomic,strong) UITextView *text;
@property(nonatomic,strong) FloatingPreview *preview;
@property(nonatomic,strong) UIView *previewSlot;
@property UIBackgroundTaskIdentifier backgroundTask;
@property(nonatomic,strong) UISegmentedControl *discoveryMode;
@end
@implementation Controller
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.backgroundTask=UIBackgroundTaskInvalid;
    UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=6;stack.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],[stack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],[stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],[stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16]]];
    UILabel *title=[UILabel new];title.text=@"ScreenLink · AirPlay Lab 0.7";title.font=[UIFont boldSystemFontOfSize:21];[stack addArrangedSubview:title];
    UILabel *help=[UILabel new];help.numberOfLines=0;help.font=[UIFont systemFontOfSize:13];help.text=@"Start → copy viewer link before casting → connect AirPlay → return here → start floating preview before switching apps.";[stack addArrangedSubview:help];
    self.discoveryMode=[[UISegmentedControl alloc]initWithItems:@[@"iPhone VPN",@"Mac VPN",@"Native"]];
    id savedMode=[NSUserDefaults.standardUserDefaults objectForKey:@"discoveryMode"];
    NSInteger mode=savedMode?[savedMode integerValue]:SLDiscoveryPhoneVPN;
    self.discoveryMode.selectedSegmentIndex=2-MAX(0,MIN(2,mode));
    [self.discoveryMode addTarget:self action:@selector(discoveryChanged) forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:self.discoveryMode];
    self.previewSlot=[UIView new];self.previewSlot.backgroundColor=UIColor.blackColor;
    NSLayoutConstraint *previewHeight=[self.previewSlot.heightAnchor constraintEqualToConstant:100];previewHeight.priority=750;previewHeight.active=YES;
    [stack addArrangedSubview:self.previewSlot];
    NSArray *labels=@[@"Start receiver",@"Copy viewer link",@"Start floating preview",@"Show browser links",@"Copy test log",@"Refresh discovery",@"Stop sharing"];
    NSArray *actions=@[NSStringFromSelector(@selector(start)),NSStringFromSelector(@selector(copyViewer)),NSStringFromSelector(@selector(startFloating)),NSStringFromSelector(@selector(links)),NSStringFromSelector(@selector(copyLog)),NSStringFromSelector(@selector(refreshDiscovery)),NSStringFromSelector(@selector(stop))];
    for(NSUInteger i=0;i<labels.count;i++) {
        UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];[button setTitle:labels[i] forState:UIControlStateNormal];[button.heightAnchor constraintEqualToConstant:34].active=YES;
        [button addTarget:self action:NSSelectorFromString(actions[i]) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:button];
    }
    self.text=[UITextView new];self.text.editable=NO;self.text.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];[stack addArrangedSubview:self.text];
    self.receiver=[Receiver new];__weak Controller *weak=self;
    self.receiver.status=^(NSString *message){[weak append:message];};
    self.receiver.preview=^(CVPixelBufferRef pixel){[weak receivedPixel:pixel];};
    [self append:@"Version 0.7: LOCAL-ONLY iPhone VPN discovery test with an internal browse/resolve check. Stop old Mac helper commands, keep LocalDevVPN connected, select iPhone VPN, and start receiver. Look for ScreenLink VPN Phone. If it remains hidden, Mac VPN mode preserves the previous working setup. Video quality is unchanged from 0.5."];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(background) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(foreground) name:UIApplicationWillEnterForegroundNotification object:nil];
}
- (void)append:(NSString *)s { self.text.text=[self.text.text stringByAppendingFormat:@"\n%@ %@\n",[NSDate date],s];if(self.text.text.length>24000)self.text.text=[self.text.text substringFromIndex:self.text.text.length-18000];[self.text scrollRangeToVisible:NSMakeRange(self.text.text.length,0)]; }
- (void)discoveryChanged {
    if(self.receiver.isRunning){self.discoveryMode.selectedSegmentIndex=2-self.receiver.discoveryMode;[self append:@"Stop sharing before changing discovery mode."];return;}
    [NSUserDefaults.standardUserDefaults setInteger:2-self.discoveryMode.selectedSegmentIndex forKey:@"discoveryMode"];
}
- (void)refreshDiscovery { [self.receiver refreshDiscovery]; }
- (void)start {
    if(!self.receiver.isRunning)self.receiver.discoveryMode=2-self.discoveryMode.selectedSegmentIndex;
    if([self.receiver start]){UIApplication.sharedApplication.idleTimerDisabled=YES;[self links];}
}
- (void)stop { [self endGrace];[self.receiver stop];[self.preview reset];[self.preview removeFromSuperview];self.preview=nil;if(_lastPixel){CVPixelBufferRelease(_lastPixel);_lastPixel=NULL;}UIApplication.sharedApplication.idleTimerDisabled=NO;[self append:@"Stopped. Video frames cleared."]; }
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
            if(active)[owner endGrace];
            else if(UIApplication.sharedApplication.applicationState==UIApplicationStateBackground && owner.receiver.isRunning)[owner beginGrace];
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
- (NSString *)linkForAddress:(NSDictionary *)address { return [NSString stringWithFormat:@"http://%@:8080/?token=%@",address[@"host"],self.receiver.token]; }
- (void)copyViewer {
    if(!self.receiver.isRunning){[self append:@"Start the receiver first, then copy its active viewer link."];return;}
    NSDictionary *address=[self addresses].firstObject;
    if(!address){[self append:@"No Wi-Fi/hotspot address yet. Connect the viewer to your hotspot, then try again."];return;}
    NSString *link=[self linkForAddress:address];UIPasteboard.generalPasteboard.string=link;
    [self append:[NSString stringWithFormat:@"Viewer link copied (%@). Paste on the viewer device before casting.\n%@",address[@"name"],link]];
}
- (void)links {
    NSArray *addresses=[self addresses];
    for(NSDictionary *address in addresses)[self append:[NSString stringWithFormat:@"Browser link (%@):\n%@",address[@"name"],[self linkForAddress:address]]];
    if(!addresses.count)[self append:@"No Wi-Fi/hotspot IPv4 address found. Connect the viewer, then show links again."];
}
- (void)beginGrace {
    if(self.backgroundTask!=UIBackgroundTaskInvalid || !self.receiver.isRunning)return;
    self.backgroundTask=[UIApplication.sharedApplication beginBackgroundTaskWithName:@"Finish AirPlay transition" expirationHandler:^{
        if(self.preview.active){[self append:@"Transition time ended; floating video is active. Continuing the receiver."];[self endGrace];return;}
        [self stop];[self append:@"No active floating video: background time expired and the receiver stopped."];
    }];
}
- (void)endGrace {
    if(self.backgroundTask!=UIBackgroundTaskInvalid){[UIApplication.sharedApplication endBackgroundTask:self.backgroundTask];self.backgroundTask=UIBackgroundTaskInvalid;}
}
- (void)background {
    if(self.preview.active){[self append:@"App backgrounded with floating preview active. Test whether the viewer keeps updating."];[self endGrace];}
    else {[self append:@"Floating preview is not active. Only a short background grace is available. Return and start floating preview before switching apps."];[self beginGrace];}
}
- (void)foreground { [self endGrace];[self append:@"App returned to foreground."]; }
@end
@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[Controller new];[self.window makeKeyAndVisible];return YES;
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(AppDelegate.class));}}
