// Build 171: real Home view on the Xcode 27.1 iPhone Duo simulator. Scene-based (like the Duo app).
// Step 0 is on the outside screen; the script then opens the phone. Steps 1-4: Home, Video, sideways Home and Video; after each it writes shot-N.txt and waits
// for the script to take the screenshot (ack-N.txt).
#import <UIKit/UIKit.h>
#import "ScreenLinkHomeView.h"
@interface DuoApp : UIResponder <UIApplicationDelegate> @end
@implementation DuoApp
- (BOOL)application:(UIApplication *)a didFinishLaunchingWithOptions:(NSDictionary *)o {return YES;}
- (UISceneConfiguration *)application:(UIApplication *)a configurationForConnectingSceneSession:(UISceneSession *)s options:(UISceneConnectionOptions *)o {
 UISceneConfiguration *c=[UISceneConfiguration configurationWithName:@"Default" sessionRole:s.role];c.delegateClass=NSClassFromString(@"DuoScene");return c;}
@end
@interface DuoScene : UIResponder <UIWindowSceneDelegate>
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) ScreenLinkHomeView *home;
@end
@implementation DuoScene
static NSString *Doc(NSString *n){return [NSHomeDirectory() stringByAppendingPathComponent:[@"Documents" stringByAppendingPathComponent:n]];}
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
 UIWindowScene *ws=(UIWindowScene *)scene;self.window=[[UIWindow alloc]initWithWindowScene:ws];UIViewController *c=[UIViewController new];
 ScreenLinkHomeView *home=[ScreenLinkHomeView new];home.translatesAutoresizingMaskIntoConstraints=NO;[c.view addSubview:home];self.home=home;
 [NSLayoutConstraint activateConstraints:@[[home.topAnchor constraintEqualToAnchor:c.view.topAnchor],[home.bottomAnchor constraintEqualToAnchor:c.view.bottomAnchor],[home.leadingAnchor constraintEqualToAnchor:c.view.leadingAnchor],[home.trailingAnchor constraintEqualToAnchor:c.view.trailingAnchor]]];
 [home showStatus:@"Playing on your car" detail:@"Choose videos in YouTube." busy:NO sharing:YES disconnecting:NO attention:NO];
 [home showPlayerState:@{@"receiverRunning":@YES,@"active":@YES,@"epoch":@"fixture",@"paused":@NO,@"ready":@YES,@"position":@75,@"duration":@300,@"title":@"Lana Del Rey – Video",@"viewerControls":@{@"quality":@"auto",@"volume":@1,@"eq":@"normal"}}];
 home.healthLevel=1;
 self.window.rootViewController=c;[self.window makeKeyAndVisible];
 [NSFileManager.defaultManager createDirectoryAtPath:Doc(@"") withIntermediateDirectories:YES attributes:nil error:nil];
 [self step:0];
}
- (void)step:(int)n {
 if(n>=5){[@"done" writeToFile:Doc(@"done.txt") atomically:YES encoding:NSUTF8StringEncoding error:nil];return;}
 UIWindowScene *ws=self.window.windowScene;
 if(n==3&&@available(iOS 16.0,*)){[ws requestGeometryUpdateWithPreferences:[[UIWindowSceneGeometryPreferencesIOS alloc]initWithInterfaceOrientations:UIInterfaceOrientationMaskLandscapeRight] errorHandler:nil];}
 SEL page=NSSelectorFromString(@"showPage:");
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((n==3?3:2)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
  if([self.home respondsToSelector:page]){NSInteger p=(n==2||n==4)?1:0;NSMethodSignature *sig=[self.home methodSignatureForSelector:page];NSInvocation *inv=[NSInvocation invocationWithMethodSignature:sig];inv.selector=page;inv.target=self.home;[inv setArgument:&p atIndex:2];[inv invoke];}
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
   CGSize s=self.window.bounds.size;
   [[NSString stringWithFormat:@"%.0fx%.0f",s.width,s.height] writeToFile:Doc([NSString stringWithFormat:@"shot-%d.txt",n]) atomically:YES encoding:NSUTF8StringEncoding error:nil];
   [self waitAck:n];});});
}
- (void)waitAck:(int)n {
 if([NSFileManager.defaultManager fileExistsAtPath:Doc([NSString stringWithFormat:@"ack-%d.txt",n])]){[self step:n+1];return;}
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.3*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self waitAck:n];});
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(DuoApp.class));}}
