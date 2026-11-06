#import "SLDisconnectFlow.h"
@interface SLDisconnectFlow ()
@property(nonatomic,readwrite) BOOL running;
@property(nonatomic) NSUInteger generation;
@end
@implementation SLDisconnectFlow
- (void)runStopSources:(void (^)(void))stopSources broadcast:(SLDisconnectStep)broadcast vpn:(SLDisconnectStep)vpn completion:(void (^)(BOOL))completion {
    NSAssert(NSThread.isMainThread,@"Disconnect flow is main-queue only");
    if(self.running)return;self.running=YES;NSUInteger generation=++self.generation;
    stopSources();__block BOOL broadcastCompleted=NO;
    broadcast(^(BOOL broadcastOK){
        if(generation!=self.generation||!self.running||broadcastCompleted)return;
        broadcastCompleted=YES;__block BOOL vpnCompleted=NO;
        vpn(^(BOOL vpnOK){
            if(generation!=self.generation||!self.running||vpnCompleted)return;
            vpnCompleted=YES;self.running=NO;if(completion)completion(broadcastOK&&vpnOK);
        });
    });
}
@end
