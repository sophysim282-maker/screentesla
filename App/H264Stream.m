#import "H264Stream.h"
#import "FMP4.h"

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
    NSUInteger _privacyRevision;
    uint64_t _notBefore;
    BOOL _needKey;
    uint64_t _base;
    uint32_t _lastDuration;
    NSData *_pending;
    uint64_t _pendingTime;
    BOOL _pendingKey;
    NSString *_codec;
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

- (void)configureSPS:(NSData *)sps PPS:(NSData *)pps width:(uint16_t)width height:(uint16_t)height {
    NSMutableData *data=[NSMutableData dataWithLength:2048+sps.length+pps.length];
    size_t length=sl_mp4_init(data.mutableBytes,data.length,sps.bytes,sps.length,pps.bytes,pps.length,width,height);
    [self reset];if(!length)return;data.length=length;const uint8_t *p=sps.bytes;
    [_ready lock];_initialization=data;_codec=[NSString stringWithFormat:@"avc1.%02X%02X%02X",p[1],p[2],p[3]];[_ready broadcast];[_ready unlock];
}

- (void)reset {
    [_ready lock];
    _initialization=nil;[_units removeAllObjects];_bytes=0;_sequence=0;_needKey=YES;
    _epoch=[NSUUID UUID].UUIDString;_privacyHidden=NO;_privacyRevision=0;_notBefore=0;
    _pending=nil;_pendingTime=0;_pendingKey=NO;_lastDuration=10000;
    [_ready broadcast];[_ready unlock];
}

- (void)setPrivacyHidden:(BOOL)hidden revision:(NSUInteger)revision {
    [_ready lock];
    _privacyHidden=hidden;_privacyRevision=revision;
    if(hidden){_pending=nil;[_units removeAllObjects];_bytes=0;_needKey=YES;}
    [_ready broadcast];[_ready unlock];
}

- (void)flushBeforeTimestamp:(uint64_t)notBefore {
    [_ready lock];
    _notBefore=notBefore;
    if(_pending && _pendingTime<notBefore){_pending=nil;[_units removeAllObjects];_bytes=0;_needKey=YES;}
    [_ready broadcast];[_ready unlock];
}

- (void)appendAVCC:(NSData *)sample timestamp:(uint64_t)time keyframe:(BOOL)key privacyPermit:(NSUInteger)permit {
    [_ready lock];
    if(!permit || _privacyHidden || permit!=_privacyRevision || time<_notBefore){[_ready unlock];return;}
    if(_pending && time<_pendingTime){_pending=nil;[_units removeAllObjects];_bytes=0;_sequence=0;_needKey=YES;_epoch=[NSUUID UUID].UUIDString;}
    if(_pending && time==_pendingTime)time=_pendingTime+_lastDuration;
    if(!_initialization || (_needKey && !key)){[_ready unlock];return;}
    if(_needKey){_pending=nil;_needKey=NO;_base=time;}
    if(_pending) {
        uint64_t delta=time>_pendingTime?time-_pendingTime:_lastDuration;
        uint32_t duration=(uint32_t)MIN(MAX(delta,1000),1000000);_lastDuration=duration;
        NSMutableData *fragment=[NSMutableData dataWithLength:_pending.length+256];
        size_t length=sl_mp4_fragment(fragment.mutableBytes,fragment.length,_pending.bytes,_pending.length,(uint32_t)(_sequence+1),_pendingTime>=_base?_pendingTime-_base:0,duration,_pendingKey);
        if(length) {
            fragment.length=length;
            [_units addObject:@{@"id":@(_sequence),@"data":fragment,@"key":@(_pendingKey)}];_bytes+=length;
            while(_units.count>1 && (_bytes>_maxBytes || _units.count>_maxPackets)){
               if (_maxPackets >= 60)  {NSInteger keyIdx = -1;
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
                } else {
                    _bytes-=[_units.firstObject[@"data"] length];[_units removeObjectAtIndex:0];
                }} else { _bytes-=[_units.firstObject[@"data"] length];[_units removeObjectAtIndex:0]; }
            }
            _sequence++;
        }
    }
    _pending=sample;_pendingTime=time;_pendingKey=key;
    [_ready broadcast];[_ready unlock];
}

- (NSDictionary *)fetchAfterSequence:(int64_t)sequence limitBytes:(NSUInteger)limitBytes {
    [_ready lock];
    if (sequence < 0 && _units.count > 0) {
        for (NSInteger i = (NSInteger)_units.count - 1; i >= 0; i--) {
            if ([_units[i][@"key"] boolValue]) {
                sequence = [_units[i][@"id"] longLongValue] - 1;
                break;
            }
        }
    }
    NSMutableArray *items = [NSMutableArray new];
    uint64_t total = 0;
    for (NSDictionary *unit in _units) {
        if ([unit[@"id"] longLongValue] > sequence) {
            NSData *data = unit[@"data"];
            if (items.count > 0 && limitBytes > 0 && total + data.length > limitBytes) break;
            [items addObject:data];
            total += data.length;
        }
    }
    NSDictionary *result = @{
        @"epoch": _epoch ?: @"",
        @"init": _initialization ?: [NSData data],
        @"codec": _codec ?: @"",
        @"units": items
    };
    [_ready unlock];
    return result;
}

@end
