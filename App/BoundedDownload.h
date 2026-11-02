#import <Foundation/Foundation.h>
/// Bounded in-flight HTTP resource. Oversized media is cancelled before buffering it.
NSDictionary *SLBoundedDownload(NSURLRequest *request,NSUInteger maxBytes);
