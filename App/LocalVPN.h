#import <Foundation/Foundation.h>
@interface LocalVPN : NSObject
@property(nonatomic,copy) void (^status)(NSString *);
@property(nonatomic,readonly) BOOL connected;
- (void)connect:(void (^)(BOOL))completion;
- (void)connectRouteProbe:(void (^)(BOOL))completion;
- (void)routeProbeStatus;
@property(nonatomic,readonly) BOOL disconnecting;
- (void)disconnectWithCompletion:(void (^)(BOOL))completion;
- (void)disconnect;
@end
