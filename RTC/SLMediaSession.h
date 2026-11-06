#import <Foundation/Foundation.h>
#import "SLMediaProvider.h"
/// Owned by the running receiver, including inside the ReplayKit extension.
@interface SLMediaSession : NSObject
@property(nonatomic,copy) void (^status)(NSString *);
@property(nonatomic,copy) NSDictionary *(^screenProvider)(NSString *,NSDictionary *);
- (instancetype)initWithMedia:(id<SLMediaProvider>)media;
- (instancetype)initWithMedia:(id<SLMediaProvider>)media hotspotOnly:(BOOL)strict;
- (NSDictionary *)control:(NSString *)command;
- (void)stop;
@end
