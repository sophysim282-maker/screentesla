#import <Foundation/Foundation.h>
@interface LocalVPN : NSObject
@property(nonatomic,copy) void (^status)(NSString *);
@property(nonatomic,readonly) BOOL connected;
- (void)connect:(void (^)(BOOL))completion;
- (void)disconnect;
@end
