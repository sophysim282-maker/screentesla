#import <Foundation/Foundation.h>
@interface Receiver : NSObject
@property(nonatomic,copy) void (^status)(NSString *);
@property(nonatomic,copy,readonly) NSString *token;
- (BOOL)start;
- (void)stop;
@end
