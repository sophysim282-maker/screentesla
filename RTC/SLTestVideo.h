#import <Foundation/Foundation.h>
@class RTCVideoSource;
/// Generated motion only: no camera, microphone, screen or user content.
@interface SLTestVideo : NSObject
- (instancetype)initWithSource:(RTCVideoSource *)source;
- (void)start;
- (void)stop;
@end
