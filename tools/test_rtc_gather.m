#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>
#import "SLPingPeer.h"
@interface SLPingPeer (GatherTest)
- (void)finishGathering:(BOOL)complete generation:(NSUInteger)generation;
@end
@interface TestDescription : NSObject
@property(nonatomic,copy) NSString *sdp;
@end
@implementation TestDescription
@end
@interface TestPeerDescription : NSObject
@property(nonatomic,strong) TestDescription *localDescription;
@property(nonatomic,weak) id delegate;
- (void)close;
@end
@implementation TestPeerDescription
- (void)close {}
@end
static void require(BOOL value,NSString *why){if(!value)@throw [NSException exceptionWithName:@"GatherRegression" reason:why userInfo:nil];}
int main(void){@autoreleasepool{
 SLPingPeer *peer=[SLPingPeer new];TestPeerDescription *fake=[TestPeerDescription new];fake.localDescription=[TestDescription new];[peer setValue:fake forKey:@"peer"];[peer setValue:@YES forKey:@"strict"];[peer setValue:@"stun:172.20.10.1:3478" forKey:@"localStunURL"];[peer setValue:@7 forKey:@"offerGeneration"];[peer setValue:@YES forKey:@"waiting"];[peer setValue:@"new" forKey:@"expectedUfrag"];[peer setValue:@(NSProcessInfo.processInfo.systemUptime+10) forKey:@"offerDeadline"];
 __block NSUInteger calls=0;__block NSString *result;__block NSError *failure;
 void (^done)(NSString *,NSString *,NSError *)=^(NSString *sdp,NSString *state,NSError *error){calls++;result=sdp;failure=error;};[peer setValue:done forKey:@"offerCompletion"];
 NSString *candidate=@"a=candidate:1 1 udp 12345 172.20.10.1 50000 typ host\r\n";
 @try {
  fake.localDescription.sdp=[@"v=0\r\na=ice-ufrag:old\r\n" stringByAppendingString:candidate];[peer finishGathering:YES generation:7];require(calls==0,@"A previous-generation completion consumed the new callback");
  fake.localDescription.sdp=@"v=0\r\na=ice-ufrag:new\r\nm=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n";[peer finishGathering:YES generation:7];require(calls==0,@"Complete state without a usable candidate failed too early");
  fake.localDescription.sdp=[fake.localDescription.sdp stringByAppendingString:candidate];[peer finishGathering:YES generation:6];require(calls==0,@"A stale completion ran");[peer finishGathering:YES generation:7];require(calls==1&&result.length&&!failure,@"A later usable candidate did not finish gathering");require([result containsString:@"a=x-screenlink-stun:stun:172.20.10.1:3478\r\nm=application"],@"Local STUN capability was not placed before the media section");[peer finishGathering:YES generation:7];require(calls==1,@"Gathering completed twice");
  [peer setValue:@8 forKey:@"offerGeneration"];[peer setValue:@YES forKey:@"waiting"];[peer setValue:@"next" forKey:@"expectedUfrag"];[peer setValue:@(NSProcessInfo.processInfo.systemUptime-1) forKey:@"offerDeadline"];[peer setValue:done forKey:@"offerCompletion"];[peer finishGathering:NO generation:8];require(calls==2&&!result&&failure,@"Deadline did not report candidate failure");
  puts("ICE gather regression passed: old generation ignored, empty completed state waits, later valid hotspot candidate succeeds once, deadline fails honestly.");
 }@catch(NSException *error){fprintf(stderr,"Gather regression failed: %s\n",error.reason.UTF8String);[peer close];return 1;}[peer close];return 0;
}}
