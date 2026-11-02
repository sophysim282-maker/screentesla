#import <Foundation/Foundation.h>
/// Expands YouTube's nonstandard segment URLs before ordinary HLS URI mapping.
FOUNDATION_EXPORT NSString *SLExpandYouTubePlaylist(NSString *text, NSError **error);
FOUNDATION_EXPORT NSString *SLRewritePlaylist(NSString *text, NSString *(^map)(NSString *uri), NSError **error);
