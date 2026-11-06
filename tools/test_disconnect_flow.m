#import <Foundation/Foundation.h>
#import "SLDisconnectFlow.h"
#include <assert.h>
int main(void){@autoreleasepool{
 SLDisconnectFlow *flow=[SLDisconnectFlow new];__block NSUInteger stops=0,vpns=0,finishes=0;__block void(^broadcastReply)(BOOL);__block void(^vpnReply)(BOOL);__block BOOL result=NO;
 [flow runStopSources:^{stops++;} broadcast:^(void(^reply)(BOOL)){broadcastReply=[reply copy];} vpn:^(void(^reply)(BOOL)){vpns++;vpnReply=[reply copy];} completion:^(BOOL ok){finishes++;result=ok;}];
 assert(flow.running&&stops==1&&vpns==0&&finishes==0);
 [flow runStopSources:^{stops++;} broadcast:^(void(^r)(BOOL)){assert(0);} vpn:^(void(^r)(BOOL)){assert(0);} completion:^(BOOL x){assert(0);}];assert(stops==1);
 broadcastReply(YES);broadcastReply(NO);assert(vpns==1&&finishes==0);vpnReply(YES);vpnReply(NO);assert(!flow.running&&finishes==1&&result);
 void(^staleBroadcast)(BOOL)=broadcastReply;void(^staleVPN)(BOOL)=vpnReply;
 [flow runStopSources:^{stops++;} broadcast:^(void(^reply)(BOOL)){broadcastReply=[reply copy];} vpn:^(void(^reply)(BOOL)){vpns++;vpnReply=[reply copy];} completion:^(BOOL ok){finishes++;result=ok;}];
 staleBroadcast(YES);staleVPN(YES);assert(flow.running&&vpns==1&&finishes==1);
 broadcastReply(NO);assert(vpns==2&&flow.running);vpnReply(YES);assert(!result&&!flow.running&&finishes==2);
 puts("Disconnect orchestration passed: immediate source stop, async ordering, repeat taps, stale/duplicate completions, VPN teardown despite broadcast failure and truthful combined result.");
}return 0;}
