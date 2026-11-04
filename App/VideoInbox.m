#import "VideoInbox.h"
@implementation VideoInbox {
    NSLock *_lock;
    dispatch_queue_t _queue;
    NSUInteger _bytes,_packets,_maxBytes,_maxPackets;
    BOOL _resetPending;
    void (^_consume)(NSData *, uint64_t, NSUInteger);
    void (^_discontinuity)(NSUInteger);
}
- (instancetype)initWithQueue:(dispatch_queue_t)queue maxBytes:(NSUInteger)bytes maxPackets:(NSUInteger)packets consume:(void (^)(NSData *, uint64_t, NSUInteger))consume discontinuity:(void (^)(NSUInteger))discontinuity {
    if((self=[super init])){_lock=[NSLock new];_queue=queue;_maxBytes=bytes;_maxPackets=packets;_consume=[consume copy];_discontinuity=[discontinuity copy];}return self;
}
- (BOOL)offer:(NSData *)data timestamp:(uint64_t)timestamp generation:(NSUInteger)generation {
    [_lock lock];
    if(_resetPending){[_lock unlock];return NO;}
    if(_packets>=_maxPackets || data.length>_maxBytes-_bytes){
        _resetPending=YES;
        // The marker follows all accepted packets. No dependent packets may
        // cross the dropped-packet boundary without a decoder/keyframe reset.
        dispatch_async(_queue,^{
            if(self->_discontinuity)self->_discontinuity(generation);
            [self->_lock lock];self->_resetPending=NO;[self->_lock unlock];
        });
        [_lock unlock];return NO;
    }
    _bytes+=data.length;_packets++;
    dispatch_async(_queue,^{
        @autoreleasepool {if(self->_consume)self->_consume(data,timestamp,generation);}
        [self->_lock lock];self->_bytes-=data.length;self->_packets--;[self->_lock unlock];
    });
    [_lock unlock];return YES;
}
@end
