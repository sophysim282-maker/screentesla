#import "H264Stream.h"
#import "FMP4.h"
@interface H264Stream () {
    NSCondition *_ready;
    NSData *_initialization,*_pending;
    NSMutableArray<NSDictionary *> *_units;
    NSString *_epoch,*_codec;
    uint64_t _sequence,_base,_pendingTime;
    uint32_t _lastDuration;
    BOOL _pendingKey,_needKey;
    NSUInteger _bytes,_maxBytes,_maxPackets;
}
@end
@implementation H264Stream
- (instancetype)init {return [self initWithMaxBytes:24*1024*1024 packets:720];}
- (instancetype)initWithMaxBytes:(NSUInteger)bytes packets:(NSUInteger)packets {if((self=[super init])){_maxBytes=MAX(1024,bytes);_maxPackets=MAX(2,packets);_ready=[NSCondition new];[self reset];}return self;}
- (void)reset {
    [_ready lock];_initialization=nil;_pending=nil;_units=[NSMutableArray array];_epoch=NSUUID.UUID.UUIDString;_sequence=0;_base=0;_bytes=0;_needKey=YES;_lastDuration=33333;[_ready broadcast];[_ready unlock];
}
- (void)configureSPS:(NSData *)sps PPS:(NSData *)pps width:(uint16_t)width height:(uint16_t)height {
    NSMutableData *data=[NSMutableData dataWithLength:2048+sps.length+pps.length];
    size_t length=sl_mp4_init(data.mutableBytes,data.length,sps.bytes,sps.length,pps.bytes,pps.length,width,height);
    [self reset];if(!length)return;data.length=length;const uint8_t *p=sps.bytes;
    [_ready lock];_initialization=data;_codec=[NSString stringWithFormat:@"avc1.%02X%02X%02X",p[1],p[2],p[3]];[_ready broadcast];[_ready unlock];
}
- (void)appendAVCC:(NSData *)sample timestamp:(uint64_t)time keyframe:(BOOL)key {
    [_ready lock];
    if(_pending && time<_pendingTime){_pending=nil;[_units removeAllObjects];_bytes=0;_sequence=0;_needKey=YES;_epoch=NSUUID.UUID.UUIDString;}
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
            // Keep preceding GOPs for viewers briefly delayed by Wi-Fi or a
            // browser scheduling pause. A keyframe alone is not eviction.
            [_units addObject:@{@"id":@(++_sequence),@"data":fragment,@"key":@(_pendingKey)}];_bytes+=length;
            // Evict cache history without interrupting clients that are already
            // decoding. A new client waits for a retained keyframe; it must
            // never bootstrap using a dependent frame after eviction.
            while(_units.count>1 && (_bytes>_maxBytes || _units.count>_maxPackets)){
                _bytes-=[_units.firstObject[@"data"] length];[_units removeObjectAtIndex:0];
            }
        }
    }
    _pending=sample;_pendingTime=time;_pendingKey=key;[_ready broadcast];[_ready unlock];
}
- (NSDictionary *)info {[_ready lock];NSDictionary *result=@{@"epoch":_epoch,@"ready":@(_initialization!=nil),@"codec":_codec ?: @"",@"sequence":@(_sequence)};[_ready unlock];return result;}
- (NSDictionary *)initialization {[_ready lock];NSDictionary *result=@{@"epoch":_epoch,@"data":_initialization ?: [NSData data]};[_ready unlock];return result;}
- (NSDictionary *)readAfter:(uint64_t)after epoch:(NSString *)epoch {
    [_ready lock];NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:1];
    while([epoch isEqual:_epoch] && (!_units.count || after>=_sequence))if(![_ready waitUntilDate:deadline])break;
    uint64_t first=[_units.firstObject[@"id"] unsignedLongLongValue];
    if(![epoch isEqual:_epoch] || after>_sequence || (after && first && after+1<first)) {
        NSDictionary *result=@{@"reset":@YES,@"epoch":_epoch};[_ready unlock];return result;
    }
    NSMutableData *data=[NSMutableData data];uint64_t last=after;
    NSUInteger bootstrap=NSNotFound;
    if(!after)for(NSUInteger i=0;i<_units.count;i++)if([_units[i][@"key"] boolValue])bootstrap=i;
    if(!after && bootstrap==NSNotFound){
        NSDictionary *result=@{@"reset":@NO,@"epoch":_epoch,@"id":@0,@"data":data};[_ready unlock];return result;
    }
    for(NSUInteger i=after?0:bootstrap;i<_units.count;i++){
        NSDictionary *unit=_units[i];
        if([unit[@"id"] unsignedLongLongValue]>after){[data appendData:unit[@"data"]];last=[unit[@"id"] unsignedLongLongValue];if(data.length>=2*1024*1024)break;}
    }
    NSDictionary *result=@{@"reset":@NO,@"epoch":_epoch,@"id":@(last),@"data":data};[_ready unlock];return result;
}
@end
