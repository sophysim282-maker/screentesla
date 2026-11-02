#import <Foundation/Foundation.h>
#import "SLPingPeer.h"
#import "SLSignaling.h"
#include <assert.h>
static void waitUntil(BOOL (^condition)(void),double seconds){NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:seconds];while(!condition()&&deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.02]];if(!condition())@throw [NSException exceptionWithName:@"Test" reason:@"Timed out waiting for asynchronous test step" userInfo:nil];}
static void require(BOOL ok,NSString *step){if(!ok)@throw [NSException exceptionWithName:@"Test" reason:step userInfo:nil];}
static NSDictionary *call(SLSignaling *api,NSString *method,NSString *path,NSString *auth,NSDictionary *body,NSInteger expected){__block BOOL done=NO;__block NSDictionary *reply=nil;__block NSInteger code=0;__block NSInteger transportError=0;[api call:method path:path authorization:auth body:body completion:^(NSInteger status,NSDictionary *data,NSError *error){code=status;reply=data;transportError=error.code;done=YES;}];waitUntil(^BOOL{return done;},12);require(code==expected,[NSString stringWithFormat:@"API %@ step returned HTTP %ld, expected %ld; sanitized error code %ld",method,(long)code,(long)expected,(long)transportError]);return reply;}
static NSString *lastOfferGathering,*lastAnswerGathering;
static NSString *offer(SLPingPeer *peer){__block NSString *sdp=nil;__block BOOL done=NO;__block NSError *failure=nil;[peer offerRestart:NO completion:^(NSString *text,NSString *gathering,NSError *error){sdp=text;lastOfferGathering=gathering;failure=error;done=YES;}];waitUntil(^BOOL{return done;},6);require(!failure&&sdp.length,@"Native offer generation failed");return sdp;}
static NSString *answer(SLPingPeer *peer,NSString *sdp){__block NSString *result=nil;__block BOOL done=NO;__block NSError *failure=nil;[peer answerOffer:sdp completion:^(NSString *text,NSString *gathering,NSError *error){result=text;lastAnswerGathering=gathering;failure=error;done=YES;}];waitUntil(^BOOL{return done;},6);require(!failure&&result.length,@"Native answer generation failed");return result;}
static void apply(SLPingPeer *peer,NSString *sdp){__block BOOL done=NO;__block NSError *failure=nil;[peer applyAnswer:sdp completion:^(NSError *error){failure=error;done=YES;}];waitUntil(^BOOL{return done;},6);require(!failure,@"Native answer application failed");}
static NSDictionary *snapshot(SLPingPeer *peer){__block NSDictionary *data=nil;[peer snapshot:^(NSDictionary *value){data=value;}];waitUntil(^BOOL{return data!=nil;},4);return data;}
static void verifyPeers(SLPingPeer *left,SLPingPeer *right){NSDate *until=[NSDate dateWithTimeIntervalSinceNow:20];NSDictionary *a=nil,*b=nil;do{a=snapshot(left);b=snapshot(right);if([a[@"verified"] boolValue]&&[b[@"verified"] boolValue])return;[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];}while(until.timeIntervalSinceNow>0);NSLog(@"Sanitized peer snapshots: %@ %@",a,b);require(NO,@"Native local ping/route verification failed");}
int main(int argc,const char *argv[]){@autoreleasepool{
 BOOL live=argc>1&&!strcmp(argv[1],"--live");SLPingPeer *left=[[SLPingPeer alloc]initWithHotspotOnly:NO offerer:YES],*right=[[SLPingPeer alloc]initWithHotspotOnly:NO offerer:NO];SLSignaling *api=nil;NSString *session=nil,*auth=nil;int result=0;
 @try {
  require([SLSignaling validSecret:[@"a" stringByPaddingToLength:64 withString:@"a" startingAtIndex:0]],@"Secret validation");require(![SLSignaling validSecret:@"short"]&&![SLSignaling validIdentifier:@"../bad"]&&[SLSignaling validCode:@"012345"],@"Identifier validation");
  NSString *sdp=offer(left);
  if(!live){apply(left,answer(right,sdp));verifyPeers(left,right);puts("Native WebRTC peers passed: host-only offer/answer, DTLS/SCTP ping/pong, traffic stats and private-route checks. This is a same-Mac test.");}
  else {
   api=[[SLSignaling alloc]initWithBaseURL:[NSURL URLWithString:@"https://tesla4khmer.com/api/public/screenlink"]];NSDictionary *created=call(api,@"POST",@"/sessions",nil,@{@"sdpOffer":sdp,@"iceGathering":lastOfferGathering},201);
   session=created[@"sessionId"];require([SLSignaling validIdentifier:session]&&[SLSignaling validSecret:created[@"deviceSecret"]]&&[SLSignaling validCode:created[@"pairingCode"]],@"Production session response invalid");auth=[@"Device " stringByAppendingString:created[@"deviceSecret"]];
   NSDictionary *joined=call(api,@"POST",@"/join",nil,@{@"pairingCode":created[@"pairingCode"]},202);NSString *join=joined[@"joinId"];require([SLSignaling validIdentifier:join]&&[SLSignaling validSecret:joined[@"viewerSecret"]],@"Production join response invalid");NSString *viewer=[@"Viewer " stringByAppendingString:joined[@"viewerSecret"]];NSString *devicePath=[@"/sessions/" stringByAppendingString:session],*viewerPath=[@"/join/" stringByAppendingString:join];
   call(api,@"GET",[viewerPath stringByAppendingString:@"/offer"],viewer,nil,403);
   NSDictionary *pending=call(api,@"GET",[devicePath stringByAppendingString:@"/join-requests"],auth,nil,200);require([pending[@"requests"] count]>0,@"Approval request missing");
   call(api,@"POST",[devicePath stringByAppendingString:@"/approve"],auth,@{@"joinId":join},200);
   NSDictionary *released=call(api,@"GET",[viewerPath stringByAppendingString:@"/offer"],viewer,nil,200);require([released[@"sdpOffer"] isEqual:sdp],@"Approved offer mismatch");
   NSString *reply=answer(right,released[@"sdpOffer"]);call(api,@"POST",[viewerPath stringByAppendingString:@"/answer"],viewer,@{@"sdpAnswer":reply,@"iceGathering":lastAnswerGathering,@"negotiationRevision":@1},200);
   NSDictionary *received=call(api,@"GET",[devicePath stringByAppendingString:@"/answer"],auth,nil,200);require([received[@"negotiationRevision"] intValue]==1,@"Answer revision mismatch");apply(left,received[@"sdpAnswer"]);verifyPeers(left,right);
   NSMutableDictionary *a=[snapshot(left) mutableCopy],*b=[snapshot(right) mutableCopy];for(NSMutableDictionary *body in @[a,b]){[body removeObjectForKey:@"verified"];[body removeObjectForKey:@"localRouteVerified"];body[@"state"]=@"connected";body[@"negotiationRevision"]=@1;}
   call(api,@"POST",[devicePath stringByAppendingString:@"/state"],auth,a,200);call(api,@"POST",[viewerPath stringByAppendingString:@"/state"],viewer,b,200);
   puts("Production signaling passed: actual native SDP, phone approval, answer exchange, real bidirectional ping and both role state reports. Test peers were on one hosted Mac, not an iPhone or Tesla.");
  }
 } @catch(NSException *error){fprintf(stderr,"RTC test failed: %s\n",error.reason.UTF8String);result=1;}
 @finally {if(api&&session&&auth){@try{call(api,@"DELETE",[@"/sessions/" stringByAppendingString:session],auth,nil,200);puts("Test signaling session closed.");}@catch(NSException *e){fprintf(stderr,"Test session cleanup failed; server expiry remains in effect.\n");}}[api close];[left close];[right close];}
 return result;
}}
