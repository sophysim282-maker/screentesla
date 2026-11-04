#import <Foundation/Foundation.h>
/// A foreground-requested, bounded iOS 26 casting session. Never auto-renewed.
@interface BackgroundSession : NSObject
@property(nonatomic,copy) void (^status)(NSString *);
@property(nonatomic,copy) void (^activityChanged)(BOOL);
@property(nonatomic,copy) void (^ended)(void);
@property(nonatomic,copy) BOOL (^videoIsLive)(void);
@property(nonatomic,readonly) BOOL active;
/// Native media mode must reserve runtime before leaving for the YouTube app.
@property(nonatomic) BOOL allowWaitingForVideo;
- (void)start;
- (void)finish;
@end
