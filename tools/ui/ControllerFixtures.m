// Simulator-only dependency fixtures. Never part of the production app target.
#import <UIKit/UIKit.h>
#import "Receiver.h"
#import "FloatingPreview.h"
#import "YouTubePiP.h"
#import "BackgroundSession.h"
#import "LocalVPN.h"
#import "RTCPrototypeController.h"
#import "SLMediaController.h"
NSUInteger SLFixtureReceiverStarts=0,SLFixturePiPStarts=0,SLFixturePeerStops=0;
UIViewController *SLFixtureRetainedPeer;
@interface Receiver ()
@property(nonatomic,readwrite,getter=isRunning) BOOL running;
@property(nonatomic,copy,readwrite) NSString *token;
@end
@implementation Receiver
- (instancetype)init {if((self=[super init]))self.token=@"fixture-token";return self;}
- (BOOL)start {self.running=YES;SLFixtureReceiverStarts++;return YES;}
- (void)stop {self.running=NO;}
- (void)prepareMediaOnly {self.mediaOnly=YES;}
- (void)authorizeNextLocalViewer {}
- (void)refreshDiscovery {}
- (BOOL)videoIsLive {return self.running;}
- (NSDictionary *)nativeMediaState {return @{@"active":@(self.running),@"epoch":@"fixture",@"url":@"/media/resource/fixture",@"paused":@NO};}
@end
@interface LocalVPN ()
@property(nonatomic,readwrite) BOOL connected,disconnecting;
@property(nonatomic) BOOL cancelled;
@end
@implementation LocalVPN
- (void)connectRouteProbe:(void(^)(BOOL))completion {
 self.cancelled=NO;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
  if(!self.cancelled)self.connected=YES;
  // Intentionally deliver stale success after cancel to exercise Controller's own fence.
  if(completion)completion(YES);
 });
}
- (void)connect:(void(^)(BOOL))completion {[self connectRouteProbe:completion];}
- (void)disconnectWithCompletion:(void(^)(BOOL))completion {self.cancelled=YES;self.connected=NO;self.disconnecting=YES;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.1*NSEC_PER_SEC)),dispatch_get_main_queue(),^{self.disconnecting=NO;if(completion)completion(YES);});}
- (void)disconnect {[self disconnectWithCompletion:nil];}
- (void)routeProbeStatus {}
@end
@interface BackgroundSession ()
@property(nonatomic,readwrite) BOOL active;
@end
@implementation BackgroundSession
- (void)start {self.active=YES;if(self.activityChanged)self.activityChanged(YES);}
- (void)finish {self.active=NO;if(self.activityChanged)self.activityChanged(NO);}
@end
@interface YouTubePiP ()
@property(nonatomic,readwrite) BOOL active;
@end
@implementation YouTubePiP
- (void)updateState:(NSDictionary *)state {}
- (void)startFloating {SLFixturePiPStarts++;self.active=YES;if(self.activityChanged)self.activityChanged(YES);}
- (void)reset {self.active=NO;}
@end
@interface FloatingPreview ()
@property(nonatomic,readwrite) BOOL active;
@end
@implementation FloatingPreview
- (void)receivePixelBuffer:(CVPixelBufferRef)pixel {}
- (void)startFloating {self.active=YES;}
- (void)reset {self.active=NO;}
@end
@implementation RTCPrototypeController
- (void)viewDidLoad {[super viewDidLoad];self.view.backgroundColor=UIColor.systemBackgroundColor;SLFixtureRetainedPeer=self;}
- (void)stopForDisconnectAll {SLFixturePeerStops++;}
@end
@implementation SLMediaController
- (void)stopForDisconnectAll {SLFixturePeerStops++;}
@end
