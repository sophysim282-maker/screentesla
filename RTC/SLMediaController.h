#import <UIKit/UIKit.h>
@interface SLMediaController : UIViewController
@property(nonatomic) BOOL youtubeOnly;
@property(nonatomic,copy) NSString *broadcastExtensionIdentifier;
- (void)stopForDisconnectAll;
@end
