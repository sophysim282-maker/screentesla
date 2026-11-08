#import <Foundation/Foundation.h>
/// Small phone-to-viewer commands, separate from media delivery and decoding.
@interface ViewerControls : NSObject
- (BOOL)update:(NSDictionary *)request media:(NSDictionary *)media;
- (BOOL)performWidgetAction:(NSString *)action media:(NSDictionary *)media;
- (NSDictionary *)snapshotForMedia:(NSDictionary *)media;
- (void)acknowledge:(NSDictionary *)report;
@end
