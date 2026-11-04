#import <Foundation/Foundation.h>
/// Ordered, bounded handoff. Offering a packet never waits for the decoder.
@interface VideoInbox : NSObject
- (instancetype)initWithQueue:(dispatch_queue_t)queue maxBytes:(NSUInteger)bytes maxPackets:(NSUInteger)packets
                      consume:(void (^)(NSData *, uint64_t, NSUInteger))consume
                discontinuity:(void (^)(NSUInteger))discontinuity;
- (BOOL)offer:(NSData *)data timestamp:(uint64_t)timestamp generation:(NSUInteger)generation;
@end
