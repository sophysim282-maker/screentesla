#import <Foundation/Foundation.h>
#import "LocalViewerApproval.h"
#import "LocalMediaToken.h"
#include <assert.h>
int main(void){@autoreleasepool{
 LocalViewerApproval *gate=[LocalViewerApproval new];NSString *nonce=@"0123456789abcdef0123456789abcdef",*peer=@"172.20.10.2";
 assert([[gate request:@"bad" peer:peer now:1][@"phase"] isEqual:@"invalid"]);
 assert([[gate statusAt:1][@"phase"] isEqual:@"idle"]);
 NSDictionary *pending=[gate request:nonce peer:peer now:2];assert([pending[@"phase"] isEqual:@"pending"]);assert(!pending[@"token"]);
 NSString *identifier=[gate statusAt:2][@"requestID"];
 assert(![gate decide:YES requestID:@"stale-request" now:3]);
 assert(![gate allowsToken:@"old-global-token" peer:peer now:3]);
 assert([[gate request:nonce peer:@"172.20.10.3" now:3][@"phase"] isEqual:@"busy"]);
 assert([[gate request:@"ffffffffffffffffffffffffffffffff" peer:peer now:3][@"phase"] isEqual:@"busy"]);
 assert([gate decide:YES requestID:identifier now:4]);
 NSString *token=[gate request:nonce peer:peer now:5][@"token"];assert(token.length);
 assert([gate allowsToken:token peer:peer now:5]);assert(![gate allowsToken:token peer:@"172.20.10.3" now:5]);
 assert(![gate decide:NO requestID:identifier now:6]);
 [gate reset];assert(![gate allowsToken:token peer:peer now:7]);
 [gate request:nonce peer:peer now:8];identifier=[gate statusAt:8][@"requestID"];assert([gate decide:NO requestID:identifier now:9]);assert(![gate request:nonce peer:peer now:10][@"token"]);assert([[gate request:nonce peer:peer now:10][@"phase"] isEqual:@"rejected"]);
 assert([[gate statusAt:130][@"phase"] isEqual:@"idle"]);
 [gate request:nonce peer:peer now:200];identifier=[gate statusAt:200][@"requestID"];assert(![gate decide:YES requestID:identifier now:321]);
 [gate request:nonce peer:peer now:400];identifier=[gate statusAt:400][@"requestID"];assert([gate decide:YES requestID:identifier now:401]);token=[gate request:nonce peer:peer now:402][@"token"];assert(![gate allowsToken:token peer:peer now:14802]);
 NSData *playlist=[@"#EXTM3U\n#EXT-X-MAP:URI=\"/media/resource/init?token=original\"\n/media/resource/part?token=original\n" dataUsingEncoding:NSUTF8StringEncoding];
 NSString *rewritten=[[NSString alloc]initWithData:SLRetokenLocalMediaData(playlist,@"application/vnd.apple.mpegurl",@"original",@"approved") encoding:NSUTF8StringEncoding];assert(![rewritten containsString:@"original"]);assert([rewritten containsString:@"part?token=approved"]);assert([SLRetokenLocalMediaData(playlist,@"video/mp4",@"original",@"approved") isEqual:playlist]);
 NSData *state=[@"{\"url\":\"/media/resource/master?token=original\"}" dataUsingEncoding:NSUTF8StringEncoding];NSDictionary *json=[NSJSONSerialization JSONObjectWithData:SLRetokenLocalMediaData(state,@"application/json",@"original",@"approved") options:0 error:nil];assert([json[@"url"] hasSuffix:@"token=approved"]);
 puts("Local viewer approval passed: no token before phone decision; peer/nonce binding, stale approval, rejection, expiry and disconnect revocation.");
}return 0;}
