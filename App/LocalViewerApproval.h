#import <Foundation/Foundation.h>
/* One bounded, in-memory alias viewer. All methods serialize their state. */
@interface LocalViewerApproval : NSObject
- (NSDictionary *)request:(NSString *)nonce peer:(NSString *)peer now:(NSTimeInterval)now;
- (NSDictionary *)statusAt:(NSTimeInterval)now;
- (BOOL)decide:(BOOL)approve requestID:(NSString *)requestID now:(NSTimeInterval)now;
- (BOOL)allowsToken:(NSString *)token peer:(NSString *)peer now:(NSTimeInterval)now;
- (void)reset;
- (void)armAutomaticAt:(NSTimeInterval)now;
@end
