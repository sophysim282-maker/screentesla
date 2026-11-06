#import <Foundation/Foundation.h>
typedef void (^SLDisconnectStep)(void (^completion)(BOOL));
@interface SLDisconnectFlow : NSObject
@property(nonatomic,readonly) BOOL running;
- (void)runStopSources:(void (^)(void))stopSources broadcast:(SLDisconnectStep)broadcast vpn:(SLDisconnectStep)vpn completion:(void (^)(BOOL))completion;
@end
