#import <Foundation/Foundation.h>
#import "H264Stream.h"
#include <assert.h>
#include <stdio.h>
int main(void){@autoreleasepool{
 H264Stream *stream=[H264Stream new];const uint8_t s[]={0x67,0x42,0xc0,0x1e,0x89},p[]={0x68,0xcb,0x83,0xcb},v[]={0,0,0,2,0x65,0x88};NSData *sample=[NSData dataWithBytes:v length:sizeof v];
 [stream configureSPS:[NSData dataWithBytes:s length:sizeof s] PPS:[NSData dataWithBytes:p length:sizeof p] width:640 height:360];NSUInteger old=[stream privacyPermitForTimestamp:1000000];assert(old);
 [stream appendAVCC:sample timestamp:1000000 keyframe:YES privacyPermit:old];[stream appendAVCC:sample timestamp:1033333 keyframe:NO privacyPermit:old];NSString *epoch=[stream info][@"epoch"];assert([[stream readAfter:0 epoch:epoch][@"data"] length]>0);
 [stream setPrivacyHidden:YES notBefore:1100000];assert(stream.privacyHidden);assert(![[stream info][@"ready"] boolValue]);assert(![[stream initialization][@"data"] length]);assert(![stream privacyPermitForTimestamp:1200000]);assert(![[stream readAfter:0 epoch:epoch][@"data"] length]);
 NSUInteger revision=[[stream info][@"privacyRevision"] unsignedIntegerValue];[stream setPrivacyHidden:YES notBefore:1200000];assert(![stream changePrivacyHidden:NO notBefore:1300000 expectedRevision:revision]);assert(stream.privacyHidden);
 revision=[[stream info][@"privacyRevision"] unsignedIntegerValue];assert([stream changePrivacyHidden:NO notBefore:2000000 expectedRevision:revision]);assert(!stream.privacyHidden);assert(![stream privacyPermitForTimestamp:1999999]);NSUInteger fresh=[stream privacyPermitForTimestamp:2000000];assert(fresh&&fresh!=old);
 [stream appendAVCC:sample timestamp:2100000 keyframe:YES privacyPermit:old];epoch=[stream info][@"epoch"];assert(![[stream readAfter:0 epoch:epoch][@"data"] length]);
 [stream appendAVCC:sample timestamp:2000000 keyframe:NO privacyPermit:fresh];[stream appendAVCC:sample timestamp:2033333 keyframe:YES privacyPermit:fresh];[stream appendAVCC:sample timestamp:2066666 keyframe:NO privacyPermit:fresh];assert([[stream readAfter:0 epoch:epoch][@"data"] length]>0);
 puts("Screen privacy passed: hidden output/history blocking, fresh timestamps, stale encoder rejection, fresh keyframe startup and stale Show rejection.");
}return 0;}
