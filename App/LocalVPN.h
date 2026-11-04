#import <Foundation/Foundation.h>
@interface LocalVPN : NSObject
@property(nonatomic,copy) void (^status)(NSString *);
@property(nonatomic,readonly) BOOL connected;
- (void)connect:(void (^)(BOOL))completion;
- (void)connectRouteProbe:(void (^)(BOOL))completion;
- (void)routeProbeStatus;
- (void)disconnect;
@end
