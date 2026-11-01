#import <Foundation/Foundation.h>
@interface H264Stream : NSObject
- (void)configureSPS:(NSData *)sps PPS:(NSData *)pps width:(uint16_t)width height:(uint16_t)height;
- (void)appendAVCC:(NSData *)sample timestamp:(uint64_t)timestamp keyframe:(BOOL)keyframe;
- (NSDictionary *)info;
- (NSDictionary *)initialization;
- (NSDictionary *)readAfter:(uint64_t)sequence epoch:(NSString *)epoch;
- (void)reset;
@end
