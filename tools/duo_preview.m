// Build 171: real Home view on the Xcode 27.1 iPhone Duo simulator. Scene-based (like the Duo app).
// Outside screen: Home, sideways Home and Video; then inside-screen sizes drawn to pictures; after each it writes shot-N.txt and waits
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
 // 0 outside upright Home, 1 outside sideways Home, 2 outside sideways Video (real screenshots by the script),
 // then the inside screen sizes are drawn into pictures (the simulator cannot unfold from the command line).
 if(n>=3){[self renderInside];return;}
 UIWindowScene *ws=self.window.windowScene;
 if(n==1&&@available(iOS 16.0,*)){[ws requestGeometryUpdateWithPreferences:[[UIWindowSceneGeometryPreferencesIOS alloc]initWithInterfaceOrientations:UIInterfaceOrientationMaskLandscapeRight] errorHandler:nil];}
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((n==1?3:2)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
  [self show:self.home page:n==2?1:0];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
   CGSize s=self.window.bounds.size;
   [[NSString stringWithFormat:@"%.0fx%.0f",s.width,s.height] writeToFile:Doc([NSString stringWithFormat:@"shot-%d.txt",n]) atomically:YES encoding:NSUTF8StringEncoding error:nil];
   [self waitAck:n];});});
}
- (void)show:(ScreenLinkHomeView *)home page:(NSInteger)p {
 SEL page=NSSelectorFromString(@"showPage:");if(![home respondsToSelector:page])return;
 NSInvocation *inv=[NSInvocation invocationWithMethodSignature:[home methodSignatureForSelector:page]];inv.selector=page;inv.target=home;[inv setArgument:&p atIndex:2];[inv invoke];
}
- (void)renderInside {
 NSArray *jobs=@[@[@669,@951,@0,@"inside-home"],@[@669,@951,@1,@"inside-video"],@[@951,@669,@0,@"inside-home-sideways"],@[@951,@669,@1,@"inside-video-sideways"]];
 __block NSUInteger i=0;__block void (^next)(void);__weak __block void (^weakNext)(void);
 next=^{
  if(i>=jobs.count){[@"done" writeToFile:Doc(@"done.txt") atomically:YES encoding:NSUTF8StringEncoding error:nil];return;}
  NSArray *j=jobs[i++];CGSize size=CGSizeMake([j[0] doubleValue],[j[1] doubleValue]);
  UIViewController *c=[UIViewController new];c.view.backgroundColor=UIColor.blackColor;c.additionalSafeAreaInsets=UIEdgeInsetsMake(size.width<size.height?24:0,0,size.width<size.height?20:16,0);
  ScreenLinkHomeView *home=[ScreenLinkHomeView new];home.frame=CGRectMake(0,0,size.width,size.height);home.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;[c.view addSubview:home];
  [home showStatus:@"Playing on your car" detail:@"Choose videos in YouTube." busy:NO sharing:YES disconnecting:NO attention:NO];
  [home showPlayerState:@{@"receiverRunning":@YES,@"active":@YES,@"epoch":@"fixture",@"paused":@NO,@"ready":@YES,@"position":@75,@"duration":@300,@"viewerControls":@{@"quality":@"auto",@"volume":@1,@"eq":@"normal"}}];
  home.healthLevel=1;
  UIWindow *w=[[UIWindow alloc]initWithWindowScene:self.window.windowScene];w.frame=CGRectMake(0,0,size.width,size.height);w.rootViewController=c;w.windowLevel=UIWindowLevelNormal-1;w.hidden=NO;
  [self show:home page:[j[2] integerValue]];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
   w.frame=CGRectMake(0,0,size.width,size.height);[w layoutIfNeeded];
   UIGraphicsImageRendererFormat *f=[UIGraphicsImageRendererFormat defaultFormat];f.scale=3;
   UIImage *img=[[[UIGraphicsImageRenderer alloc]initWithSize:size format:f] imageWithActions:^(UIGraphicsImageRendererContext *ctx){
    if(![w drawViewHierarchyInRect:CGRectMake(0,0,size.width,size.height) afterScreenUpdates:YES])[w.layer renderInContext:ctx.CGContext];}];
   [UIImagePNGRepresentation(img) writeToFile:Doc([j[3] stringByAppendingString:@".png"]) atomically:YES];
   w.hidden=YES;dispatch_async(dispatch_get_main_queue(),weakNext);});
 };
 weakNext=next;next();
}
- (void)waitAck:(int)n {
 if([NSFileManager.defaultManager fileExistsAtPath:Doc([NSString stringWithFormat:@"ack-%d.txt",n])]){[self step:n+1];return;}
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.3*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self waitAck:n];});
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(DuoApp.class));}}
