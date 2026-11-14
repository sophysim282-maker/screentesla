#import <Foundation/Foundation.h>
/// Bounded in-flight HTTP resource. Oversized media is cancelled before buffering it.
NSDictionary *SLBoundedDownload(NSURLRequest *request,NSUInteger maxBytes);
/// Build 146: open warm connections (mobile radio awake, name lookup, secure handshake) before the first video.
void SLWarmDownloads(NSArray<NSURL *> *urls);
