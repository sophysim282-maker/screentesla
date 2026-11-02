#import <Foundation/Foundation.h>
#import "SLMediaProvider.h"
/// Owned by the running receiver, including inside the ReplayKit extension.
@interface SLMediaSession : NSObject
@property(nonatomic,copy) void (^status)(NSString *);
- (instancetype)initWithMedia:(id<SLMediaProvider>)media;
- (instancetype)initWithMedia:(id<SLMediaProvider>)media hotspotOnly:(BOOL)strict;
- (NSDictionary *)control:(NSString *)command;
- (void)stop;
@end
