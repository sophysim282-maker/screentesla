#import <Foundation/Foundation.h>
@protocol SLMediaProvider <NSObject>
@property(nonatomic,readonly) BOOL active;
- (NSDictionary *)state;
- (NSDictionary *)resource:(NSString *)identifier range:(NSString *)range;
- (void)report:(NSDictionary *)report;
@end
