#import <Foundation/Foundation.h>
typedef void (^SLAPICompletion)(NSInteger code,NSDictionary *body,NSError *error);
@interface SLSignaling : NSObject
@property(nonatomic,strong,readonly) NSURL *baseURL;
- (instancetype)initWithBaseURL:(NSURL *)baseURL;
- (void)call:(NSString *)method path:(NSString *)path authorization:(NSString *)authorization body:(NSDictionary *)body completion:(SLAPICompletion)completion;
- (void)close;
+ (BOOL)validSecret:(id)value;
+ (BOOL)validIdentifier:(id)value;
+ (BOOL)validCode:(id)value;
@end
