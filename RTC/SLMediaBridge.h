#import <Foundation/Foundation.h>
/// Ordered media-v1 RPC. Call methods on main queue. One bounded response at a time.
@interface SLMediaBridge : NSObject
@property(nonatomic,copy) NSDictionary *(^stateProvider)(void);
@property(nonatomic,copy) NSDictionary *(^resourceProvider)(NSString *,NSString *);
@property(nonatomic,copy) void (^reportConsumer)(NSDictionary *);
@property(nonatomic,copy) BOOL (^send)(NSData *,BOOL);
@property(nonatomic,copy) uint64_t (^bufferedAmount)(void);
@property(nonatomic,readonly) uint64_t bytesForwarded;
- (void)open;
- (void)receive:(NSData *)data;
- (void)stop;
@end
