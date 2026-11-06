#import <UIKit/UIKit.h>
#import "ScreenLinkHomeView.h"
#import <objc/runtime.h>
extern NSUInteger SLFixtureReceiverStarts,SLFixturePiPStarts;
@interface ScreenLinkTestDelegate:UIResponder<UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
static void fixtureBrowse(id self,SEL command,NSString *type,NSString *domain) {}
@interface PreviewController:UIViewController
@property(nonatomic,strong) ScreenLinkHomeView *home;
@end
@implementation PreviewController
- (void)viewDidLoad {
 [super viewDidLoad];self.view.backgroundColor=UIColor.systemGroupedBackgroundColor;
 self.home=[ScreenLinkHomeView new];self.home.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:self.home];
 [NSLayoutConstraint activateConstraints:@[[self.home.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],[self.home.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],[self.home.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[self.home.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]]];
 __weak PreviewController *weak=self;
 self.home.startAction=^{[weak.home showStatus:@"Ready for AirPlay" detail:@"Choose ScreenLink in YouTube’s AirPlay menu, then return here once to prepare PiP." busy:NO sharing:NO disconnecting:NO attention:NO];};
 self.home.disconnectAction=^{[weak.home showStatus:@"Disconnected" detail:@"Sharing and ScreenLink VPN are off. Tap Start whenever you’re ready." busy:NO sharing:NO disconnecting:NO attention:NO];};
 self.home.developerAction=^{[weak.home showStatus:@"Developer controls opened" detail:@"This cloud harness verifies the dashboard callback. The production app retains its full technical screen." busy:NO sharing:NO disconnecting:NO attention:NO];};
 self.home.copyAction=^{UIPasteboard.generalPasteboard.string=@"https://car.tesla4khmer.com/video";};
}
@end
@interface PreviewDelegate:ScreenLinkTestDelegate
@property(nonatomic,strong) UILabel *fixtureMeter;
@property(nonatomic,strong) NSTimer *fixtureTimer;
@end
@implementation PreviewDelegate
- (void)sendFixtureURL:(NSString *)host {
 [(id<UIApplicationDelegate>)self application:UIApplication.sharedApplication openURL:[NSURL URLWithString:[@"screenlink://" stringByAppendingString:host]] options:@{}];
}
- (void)fixtureStart {[self sendFixtureURL:@"start-youtube"];}
- (void)fixtureStop {[self sendFixtureURL:@"disconnect-all"];}
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
 if([NSProcessInfo.processInfo.arguments containsObject:@"--controller-tests"]){
  [NSUserDefaults.standardUserDefaults setBool:[NSProcessInfo.processInfo.arguments containsObject:@"--manual-disconnected"] forKey:@"manualDisconnected"];
  for(NSString *key in @[@"receiverArmed",@"resumeYouTubeOnReturn",@"screenBroadcastArmed"])[NSUserDefaults.standardUserDefaults setBool:NO forKey:key];
  Method browser=class_getInstanceMethod(NSNetServiceBrowser.class,@selector(searchForServicesOfType:inDomain:));method_setImplementation(browser,(IMP)fixtureBrowse);
  NSMutableDictionary *launch=[options mutableCopy]?:[NSMutableDictionary dictionary];
  if([NSProcessInfo.processInfo.arguments containsObject:@"--launch-start"])launch[UIApplicationLaunchOptionsURLKey]=[NSURL URLWithString:@"screenlink://start-youtube"];
  [super application:application didFinishLaunchingWithOptions:launch];
  self.fixtureMeter=[[UILabel alloc]initWithFrame:CGRectMake(6,self.window.bounds.size.height-24,180,20)];self.fixtureMeter.font=[UIFont systemFontOfSize:8];self.fixtureMeter.accessibilityIdentifier=@"integration.state";[self.window addSubview:self.fixtureMeter];
  self.fixtureTimer=[NSTimer scheduledTimerWithTimeInterval:.1 repeats:YES block:^(NSTimer *timer){self.fixtureMeter.text=[NSString stringWithFormat:@"receiver=%lu;pip=%lu",(unsigned long)SLFixtureReceiverStarts,(unsigned long)SLFixturePiPStarts];}];
  for(NSString *name in @[@"Start",@"Stop"]){UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];b.frame=CGRectMake([name isEqual:@"Start"]?190:260,self.window.bounds.size.height-34,65,28);b.titleLabel.font=[UIFont systemFontOfSize:10];[b setTitle:[@"Widget " stringByAppendingString:name] forState:UIControlStateNormal];b.accessibilityIdentifier=[@"integration.widget" stringByAppendingString:name];[b addTarget:self action:[name isEqual:@"Start"]?@selector(fixtureStart):@selector(fixtureStop) forControlEvents:UIControlEventTouchUpInside];[self.window addSubview:b];}
  return YES;
 }
 self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[PreviewController new];
 if([NSProcessInfo.processInfo.arguments containsObject:@"--dark"])self.window.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
 else self.window.overrideUserInterfaceStyle=UIUserInterfaceStyleLight;
 [self.window makeKeyAndVisible];return YES;
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(PreviewDelegate.class));}}
