#import <UIKit/UIKit.h>
@interface ScreenLinkHomeView : UIView
@property(nonatomic,copy) void (^startAction)(void), (^disconnectAction)(void), (^developerAction)(void), (^copyAction)(void), (^mapAction)(void);
@property(nonatomic,copy) void (^playerAction)(NSDictionary *request);
@property(nonatomic,strong,readonly) UIView *previewHost;
/// Build 106: status light. 0 = not used, 1 = green (car connected), 2 = yellow, 3 = red.
@property(nonatomic) NSInteger healthLevel;
- (void)showPlayerState:(NSDictionary *)state;
- (void)showStatus:(NSString *)status detail:(NSString *)detail busy:(BOOL)busy sharing:(BOOL)sharing disconnecting:(BOOL)disconnecting attention:(BOOL)attention;
@end

