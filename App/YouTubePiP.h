#import <UIKit/UIKit.h>
@interface YouTubePiP : UIView
@property(nonatomic,copy) void (^status)(NSString *);
@property(nonatomic,copy) void (^activityChanged)(BOOL);
@property(nonatomic,readonly) BOOL active;
- (void)updateState:(NSDictionary *)state;
- (void)startFloating;
- (void)resumeAfterForeground;
- (void)reset;
@end
