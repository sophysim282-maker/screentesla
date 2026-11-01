#import <UIKit/UIKit.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import "Receiver.h"
@interface Controller : UIViewController
@property(nonatomic,strong) Receiver *receiver;
@property(nonatomic,strong) UITextView *text;
@property UIBackgroundTaskIdentifier backgroundTask;
@end
@implementation Controller
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.backgroundTask=UIBackgroundTaskInvalid;
    UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=14;stack.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],[stack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],[stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],[stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20]]];
    UILabel *title=[UILabel new];title.text=@"ScreenLink · AirPlay Lab";title.font=[UIFont boldSystemFontOfSize:24];[stack addArrangedSubview:title];
    for(NSString *name in @[@"Start receiver",@"Show browser links",@"Copy test log",@"Stop sharing"]) {
        UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];[button setTitle:name forState:UIControlStateNormal];[button.heightAnchor constraintEqualToConstant:40].active=YES;
        SEL action=[name isEqual:@"Start receiver"]?@selector(start):[name isEqual:@"Show browser links"]?@selector(links):[name isEqual:@"Copy test log"]?@selector(copyLog):@selector(stop);
        [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:button];
    }
    self.text=[UITextView new];self.text.editable=NO;self.text.font=[UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];[stack addArrangedSubview:self.text];
    self.receiver=[Receiver new];__weak Controller *weak=self;
    self.receiver.status=^(NSString *message){[weak append:message];};
    [self append:@"EXPERIMENTAL: not a verified same-phone AirPlay solution. No VPN entitlement, no ReplayKit capture, no audio. Start receiver, then open Control Center → Screen Mirroring. Look for ScreenLink. The first real decoded frame is the success test."];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(background) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(foreground) name:UIApplicationWillEnterForegroundNotification object:nil];
}
- (void)append:(NSString *)s { self.text.text=[self.text.text stringByAppendingFormat:@"\n%@ %@\n",[NSDate date],s];if(self.text.text.length>24000)self.text.text=[self.text.text substringFromIndex:self.text.text.length-18000];[self.text scrollRangeToVisible:NSMakeRange(self.text.text.length,0)]; }
- (void)start { [self.receiver start];UIApplication.sharedApplication.idleTimerDisabled=YES;[self links]; }
- (void)stop { [self.receiver stop];UIApplication.sharedApplication.idleTimerDisabled=NO;[self append:@"Stopped. Video frames cleared."]; }
- (void)copyLog { UIPasteboard.generalPasteboard.string=self.text.text;[self append:@"Test log copied."]; }
- (void)links {
    struct ifaddrs *head=NULL;if(getifaddrs(&head)!=0)return;
    NSUInteger count=0;
    for(struct ifaddrs *p=head;p;p=p->ifa_next) {
        if(!p->ifa_addr || p->ifa_addr->sa_family!=AF_INET)continue;
        NSString *name=[NSString stringWithUTF8String:p->ifa_name];if(![name hasPrefix:@"en"] && ![name hasPrefix:@"bridge"])continue;
        char address[INET_ADDRSTRLEN];struct sockaddr_in *a=(void *)p->ifa_addr;
        if(inet_ntop(AF_INET,&a->sin_addr,address,sizeof address)){count++;[self append:[NSString stringWithFormat:@"Browser link (%@):\nhttp://%s:8080/?token=%@",name,address,self.receiver.token]];}
    }freeifaddrs(head);if(!count)[self append:@"No Wi-Fi/hotspot IPv4 address found. Enable hotspot and connect the other device, then show links again."];
}
- (void)background {
    [self append:@"App entered background. iOS may suspend the receiver; sustained background operation is NOT implemented."];
    if(self.backgroundTask!=UIBackgroundTaskInvalid)return;
    self.backgroundTask=[UIApplication.sharedApplication beginBackgroundTaskWithName:@"Finish AirPlay test" expirationHandler:^{
        [self stop];[self append:@"Background time expired. Receiver stopped."];
        [UIApplication.sharedApplication endBackgroundTask:self.backgroundTask];self.backgroundTask=UIBackgroundTaskInvalid;
    }];
}
- (void)foreground {
    if(self.backgroundTask!=UIBackgroundTaskInvalid){[UIApplication.sharedApplication endBackgroundTask:self.backgroundTask];self.backgroundTask=UIBackgroundTaskInvalid;}
    [self append:@"App returned to foreground."];
}
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
