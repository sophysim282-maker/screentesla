#import <Foundation/Foundation.h>
#import "H264Stream.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
    @autoreleasepool {
        H264Stream *stream=[H264Stream new];
        const uint8_t s[]={0x67,0x42,0xc0,0x1e,0x89},p[]={0x68,0xcb,0x83,0xcb},v[]={0,0,0,2,0x65,0x88};
        NSData *sample=[NSData dataWithBytes:v length:sizeof v];
        [stream configureSPS:[NSData dataWithBytes:s length:sizeof s] PPS:[NSData dataWithBytes:p length:sizeof p] width:640 height:360];
        NSString *epoch=[stream info][@"epoch"];assert([[stream info][@"ready"] boolValue]);
        [stream appendAVCC:sample timestamp:1000000 keyframe:YES];
        [stream appendAVCC:sample timestamp:1016667 keyframe:NO];
        [stream appendAVCC:sample timestamp:1033334 keyframe:NO];
        NSDictionary *part=[stream readAfter:0 epoch:epoch];assert(![part[@"reset"] boolValue]);assert([part[@"id"] intValue]==2);assert([part[@"data"] length]>200);
        [stream appendAVCC:sample timestamp:500000 keyframe:YES];
        assert(![epoch isEqual:[stream info][@"epoch"]]);assert([[stream readAfter:2 epoch:epoch][@"reset"] boolValue]);
        epoch=[stream info][@"epoch"];
        [stream appendAVCC:sample timestamp:516667 keyframe:NO];
        part=[stream readAfter:0 epoch:epoch];assert([part[@"id"] intValue]==1);assert([part[@"data"] length]>100);
        [stream reset];assert(![[stream info][@"ready"] boolValue]);assert([[stream readAfter:1 epoch:epoch][@"reset"] boolValue]);
        puts("H.264 stream passed: keyframe startup, fragment batching, timestamp reset, epoch recovery and stop reset.");
    }
    return 0;
}
