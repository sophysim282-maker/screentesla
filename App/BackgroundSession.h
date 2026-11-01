#import <Foundation/Foundation.h>
/// A foreground-requested, bounded iOS 26 casting session. Never auto-renewed.
@interface BackgroundSession : NSObject
@property(nonatomic,copy) void (^status)(NSString *);
@property(nonatomic,copy) void (^activityChanged)(BOOL);
@property(nonatomic,copy) void (^ended)(void);
@property(nonatomic,copy) BOOL (^videoIsLive)(void);
@property(nonatomic,readonly) BOOL active;
- (void)start;
- (void)finish;
@end
