#import <UIKit/UIKit.h>
#import "ScreenLinkHomeView.h"
@interface PreviewController:UIViewController
@property(nonatomic,strong) ScreenLinkHomeView *home;
@end
@implementation PreviewController
- (void)viewDidLoad {
 [super viewDidLoad];self.view.backgroundColor=UIColor.systemGroupedBackgroundColor;
 self.home=[ScreenLinkHomeView new];self.home.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:self.home];
 [NSLayoutConstraint activateConstraints:@[[self.home.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],[self.home.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],[self.home.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[self.home.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]]];
 __weak PreviewController *weak=self;
 self.home.startAction=^{[weak.home showStatus:@"Ready for AirPlay" detail:@"Choose ScreenLink in YouTube’s AirPlay menu, then return here once to prepare PiP." busy:NO sharing:NO attention:NO];};
 self.home.disconnectAction=^{[weak.home showStatus:@"Disconnected" detail:@"Sharing and ScreenLink VPN are off. Tap Start whenever you’re ready." busy:NO sharing:NO attention:NO];};
 self.home.developerAction=^{[weak.home showStatus:@"Developer controls opened" detail:@"This cloud harness verifies the dashboard callback. The production app retains its full technical screen." busy:NO sharing:NO attention:NO];};
 self.home.copyAction=^{UIPasteboard.generalPasteboard.string=@"https://car.tesla4khmer.com/video";};
}
@end
@interface PreviewDelegate:UIResponder<UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation PreviewDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
 self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[PreviewController new];
 if([NSProcessInfo.processInfo.arguments containsObject:@"--dark"])self.window.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
 else self.window.overrideUserInterfaceStyle=UIUserInterfaceStyleLight;
 [self.window makeKeyAndVisible];return YES;
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(PreviewDelegate.class));}}
