#import <Foundation/Foundation.h>

/// Publishes a proxy address plus AirPlay/RAOP services from the phone itself.
/// Successful DNS registration is not proof of same-phone AirPlay discovery.
@interface VPNDiscovery : NSObject
@property(nonatomic,copy) void (^status)(NSString *);
- (BOOL)startWithProfile:(NSDictionary *)profile;
- (BOOL)recoverIfNeeded;
- (void)recoverOnForeground;
- (void)stop;
@end
