#import <UIKit/UIKit.h>
@interface ScreenLinkHomeView : UIView
@property(nonatomic,copy) void (^startAction)(void), (^disconnectAction)(void), (^developerAction)(void), (^copyAction)(void);
@property(nonatomic,copy) void (^playerAction)(NSDictionary *request);
@property(nonatomic,strong,readonly) UIView *previewHost;
- (void)showPlayerState:(NSDictionary *)state;
- (void)showStatus:(NSString *)status detail:(NSString *)detail busy:(BOOL)busy sharing:(BOOL)sharing disconnecting:(BOOL)disconnecting attention:(BOOL)attention;
@end

