#import "H264Stream.h"

@implementation H264Stream {
    NSCondition *_ready;
    NSData *_initialization;
    NSMutableArray<NSDictionary *> *_units;
    uint64_t _bytes;
    uint64_t _maxBytes;
    NSUInteger _maxPackets;
    uint64_t _sequence;
    NSString *_epoch;
    BOOL _privacyHidden;

    NSData *_pending;
    CFTimeInterval _pendingTime;
    BOOL _pendingKey;
}

- (instancetype)init {
    if ((self = [super init])) {
        _ready = [NSCondition new];
        _units = [NSMutableArray new];
        _maxBytes = 24 * 1024 * 1024;
        _maxPackets = 1200;
        _epoch = [[NSUUID UUID] UUIDString];
    }
    return self;
}

- (void)configureSPS:(NSData *)sps pps:(NSData *)pps {
    [_ready lock];
    NSMutableData *combined = [NSMutableData dataWithCapacity:sps.length + pps.length + 8];
    static const uint8_t naluHeader[] = {0, 0, 0, 1};
    if (sps.length > 0) {
        [combined appendBytes:naluHeader length:4];
        [combined appendData:sps];
    }
    if (pps.length > 0) {
        [combined appendBytes:naluHeader length:4];
        [combined appendData:pps];
    }
    _initialization = combined;
    [_ready broadcast];
    [_ready unlock];
}

- (void)appendFragment:(NSData *)fragment isKeyframe:(BOOL)isKeyframe timestamp:(CFTimeInterval)time {
    if (!fragment || fragment.length == 0) return;
    [_ready lock];
    NSData *sample = [fragment copy];
    NSUInteger length = sample.length;
    [_units addObject:@{@"id": @(++_sequence), @"data": sample, @"key": @(isKeyframe)}];
    _bytes += length;
    while (_units.count > 1 && (_bytes > _maxBytes || _units.count > _maxPackets)) {
        NSInteger keyIdx = -1;
        for (NSInteger i = (NSInteger)_units.count - 1; i >= 1; i--) {
            if ([_units[i][@"key"] boolValue]) {
                keyIdx = i;
                break;
            }
        }
        if (keyIdx > 0) {
            for (NSInteger i = 1; i < keyIdx; i++) {
                _bytes -= [_units[1][@"data"] length];
                [_units removeObjectAtIndex:1];
            }
            if (_bytes > _maxBytes || _units.count > _maxPackets) {
                _bytes -= [_units[1][@"data"] length];
                [_units removeObjectAtIndex:1];
            }
        } else {
            _bytes -= [_units[0][@"data"] length];
            [_units removeObjectAtIndex:0];
        }
    }
    _pending = sample;
    _pendingTime = time;
    _pendingKey = isKeyframe;
    [_ready broadcast];
    [_ready unlock];
}

- (NSDictionary *)info {
    [_ready lock];
    NSDictionary *result = @{@"epoch": _epoch, @"ready": @(_initialization != nil && !_privacyHidden)};
    [_ready unlock];
    return result;
}

- (NSDictionary *)initialization {
    [_ready lock];
    NSDictionary *result = @{@"epoch": _epoch, @"data": (!_privacyHidden ? (_initialization ?: [NSData data]) : [NSData data])};
    [_ready unlock];
    return result;
}

- (NSDictionary *)readAfter:(uint64_t)after epoch:(NSString *)epoch {
    return [self readAfter:after epoch:epoch maxBytes:64 * 1024 waitUntilDate:nil];
}

- (NSDictionary *)readAfter:(uint64_t)after epoch:(NSString *)epoch maxBytes:(NSUInteger)maxBytes waitUntilDate:(NSDate *)waitUntilDate {
    NSUInteger limit = MAX(1024, MIN(maxBytes, 2 * 1024 * 1024));
    [_ready lock];
    if (waitUntilDate) {
        while (!_privacyHidden && [epoch isEqualToString:_epoch] && (_units.count == 0 || after >= _sequence)) {
            if (![_ready waitUntilDate:waitUntilDate]) break;
        }
    }
    if (_privacyHidden) {
        NSDictionary *result = @{@"reset": @YES, @"hidden": @YES, @"epoch": _epoch, @"data": [NSData data]};
        [_ready unlock];
        return result;
    }
    uint64_t first = [_units.firstObject[@"id"] unsignedLongLongValue];
    if (![epoch isEqualToString:_epoch] || after > _sequence || (after > 0 && first > 0 && after + 1 < first)) {
        NSDictionary *result = @{@"reset": @YES, @"epoch": _epoch};
        [_ready unlock];
        return result;
    }
    NSMutableData *data = [NSMutableData data];
    uint64_t last = after;
    NSUInteger bootstrap = NSNotFound;
    if (!after) {
        for (NSUInteger i = 0; i < _units.count; i++) {
            if ([_units[i][@"key"] boolValue]) {
                bootstrap = i;
                break;
            }
        }
    }
    if (!after && bootstrap == NSNotFound) {
        NSDictionary *result = @{@"reset": @NO, @"epoch": _epoch, @"id": @0, @"data": data};
        [_ready unlock];
        return result;
    }
    for (NSUInteger i = (after ? 0 : bootstrap); i < _units.count; i++) {
        NSDictionary *unit = _units[i];
        if ([unit[@"id"] unsignedLongLongValue] > after) {
            if ([unit[@"data"] length] > limit - data.length && data.length > 0) break;
            [data appendData:unit[@"data"]];
            last = [unit[@"id"] unsignedLongLongValue];
        }
    }
    NSDictionary *result = @{@"reset": @NO, @"epoch": _epoch, @"id": @(last), @"data": data};
    [_ready unlock];
    return result;
}

- (void)setPrivacyHidden:(BOOL)hidden {
    [_ready lock];
    _privacyHidden = hidden;
    [_ready broadcast];
    [_ready unlock];
}

@end
