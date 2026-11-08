#import <UIKit/UIKit.h>
#import "ScreenLinkHomeView.h"
#include <assert.h>
#include <math.h>
static UIView *find(UIView *v,NSString *identifier){if([v.accessibilityIdentifier isEqual:identifier])return v;for(UIView *child in v.subviews){UIView *result=find(child,identifier);if(result)return result;}return nil;}
@interface PreviewDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation PreviewDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
 self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];UIViewController *controller=[UIViewController new];ScreenLinkHomeView *home=[ScreenLinkHomeView new];home.translatesAutoresizingMaskIntoConstraints=NO;[controller.view addSubview:home];
 [NSLayoutConstraint activateConstraints:@[[home.topAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.topAnchor],[home.bottomAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.bottomAnchor],[home.leadingAnchor constraintEqualToAnchor:controller.view.leadingAnchor],[home.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor]]];
 [home showStatus:@"Playing on your car" detail:@"Choose videos in YouTube. Use the controls below for the car player." busy:NO sharing:YES disconnecting:NO attention:NO];
 [home showPlayerState:@{@"receiverRunning":@YES,@"active":@YES,@"epoch":@"fixture",@"paused":@NO,@"ready":@YES,@"position":@75,@"duration":@300,@"viewerControls":@{@"quality":@"auto",@"volume":@1,@"eq":@"normal"}}];
 NSMutableArray *actions=[NSMutableArray array];home.playerAction=^(NSDictionary *request){[actions addObject:request];};
 self.window.rootViewController=controller;[self.window makeKeyAndVisible];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{
  UISegmentedControl *quality=(id)find(home,@"player.quality");UISlider *volume=(id)find(home,@"player.volume"),*seek=(id)find(home,@"player.seek");UIButton *pause=(id)find(home,@"player.pause");
  assert(quality.enabled&&volume.enabled&&seek.enabled&&pause.enabled);
  quality.selectedSegmentIndex=1;[quality sendActionsForControlEvents:UIControlEventValueChanged];volume.value=.4;[volume sendActionsForControlEvents:UIControlEventValueChanged];seek.value=.5;[seek sendActionsForControlEvents:UIControlEventValueChanged];[pause sendActionsForControlEvents:UIControlEventTouchUpInside];
  assert(actions.count==4&&[actions[0][@"quality"] isEqual:@"720"]&&fabs([actions[1][@"volume"] doubleValue]-.4)<.01&&[actions[2][@"seek"] doubleValue]==150&&[actions[3][@"paused"] boolValue]);
  UIScrollView *scroll=(id)find(home,@"home.scroll");[scroll setContentOffset:CGPointMake(0,560) animated:NO];
  NSString *marker=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/phone-controls-passed.txt"];[@"PHONE_UI_PASSED" writeToFile:marker atomically:YES encoding:NSUTF8StringEncoding error:nil];
 });return YES;
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(PreviewDelegate.class));}}
