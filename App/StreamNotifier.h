#import <Foundation/Foundation.h>
// Build 89: iPhone notifications that tell you what to do to keep the car stream playing.
// Rules map ScreenLink log events to a short title + action. Notifications are shown only
// while ScreenLink is not on screen (Home already shows the status) and never repeat an
// alert sooner than its cooldown. Tapping one opens ScreenLink, which resumes PiP/receiver.
@interface SLStreamNotifier : NSObject
/// Returns {id, title, body, cooldown} for a log line, or nil when it needs no notification.
+ (NSDictionary<NSString *,id> *)ruleForMessage:(NSString *)message;
+ (void)requestPermission;
+ (void)handleLogMessage:(NSString *)message appActive:(BOOL)active;
@end
