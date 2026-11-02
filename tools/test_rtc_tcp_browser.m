#import <Foundation/Foundation.h>
#import "SLPingPeer.h"
#include <stdio.h>
@interface SLPingPeer (TransportTest)
- (NSString *)filteredSDP:(NSString *)sdp;
@end
@interface TCPOnlyPeer : SLPingPeer
@end
@implementation TCPOnlyPeer
- (NSString *)filteredSDP:(NSString *)sdp {
    NSString *base=[super filteredSDP:sdp];NSMutableArray *lines=[NSMutableArray array];NSUInteger count=0;
    for(NSString *line in [base componentsSeparatedByString:@"\r\n"]){if([line hasPrefix:@"a=candidate:"]){NSArray *parts=[line componentsSeparatedByString:@" "];if(parts.count<8||[parts[2] caseInsensitiveCompare:@"tcp"]!=NSOrderedSame)continue;count++;}[lines addObject:line];}
    return count?[lines componentsJoinedByString:@"\r\n"]:nil;
}
@end
static void check(BOOL condition,NSString *message){if(!condition)@throw [NSException exceptionWithName:@"TCPInterop" reason:message userInfo:nil];}
static void spin(BOOL (^condition)(void),NSTimeInterval timeout){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:timeout];while(!condition()&&end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];check(condition(),@"Native/browser TCP interop timed out");}
int main(int argc,const char *argv[]){@autoreleasepool{
    if(argc!=2)return 2;NSString *script=[NSString stringWithUTF8String:argv[1]],*folder=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];NSFileManager *files=NSFileManager.defaultManager;[files createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:nil];
    TCPOnlyPeer *peer=[[TCPOnlyPeer alloc]initWithHotspotOnly:NO offerer:YES dataOnly:YES];[peer enableMediaChannel];[peer enableScreenChannel];__weak TCPOnlyPeer *weak=peer;
    peer.mediaOpened=^{[weak sendMedia:[@"hello-media" dataUsingEncoding:NSUTF8StringEncoding] binary:NO];};peer.screenOpened=^{[weak sendScreen:[@"hello-screen" dataUsingEncoding:NSUTF8StringEncoding] binary:NO];};
    peer.mediaMessage=^(NSData *bytes,BOOL binary){if(binary)[weak sendMedia:bytes binary:YES];};peer.screenMessage=^(NSData *bytes,BOOL binary){if(binary)[weak sendScreen:bytes binary:YES];};
    NSTask *task=[NSTask new];int result=0;
    @try {
        __block BOOL ready=NO;__block NSString *offer;
        [peer offerRestart:NO completion:^(NSString *sdp,NSString *gathering,NSError *error){offer=sdp;ready=YES;}];spin(^BOOL{return ready;},8);check(offer.length,@"Native library did not produce TCP host candidates");
        NSData *config=[NSJSONSerialization dataWithJSONObject:@{@"offer":offer} options:0 error:nil];NSString *configPath=[folder stringByAppendingPathComponent:@"offer.json"];[config writeToFile:configPath atomically:YES];[files setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:configPath error:nil];
        task.executableURL=[NSURL fileURLWithPath:@"/usr/bin/env"];task.arguments=@[@"node",script,folder];NSError *launch=nil;check([task launchAndReturnError:&launch],@"Could not launch browser TCP test");
        NSString *answerPath=[folder stringByAppendingPathComponent:@"answer.json"];spin(^BOOL{return [files fileExistsAtPath:answerPath]||!task.running;},20);NSData *data=[NSData dataWithContentsOfFile:answerPath];NSDictionary *answer=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;check([answer[@"sdpAnswer"] length]>0,@"Browser did not gather TCP candidates");
        ready=NO;[peer applyAnswer:answer[@"sdpAnswer"] completion:^(NSError *error){check(!error,@"Browser TCP answer rejected");ready=YES;}];spin(^BOOL{return ready;},8);
        NSString *reportPath=[folder stringByAppendingPathComponent:@"result.json"];spin(^BOOL{return [files fileExistsAtPath:reportPath]||!task.running;},55);
        NSData *reportBytes=[NSData dataWithContentsOfFile:reportPath];NSDictionary *report=reportBytes?[NSJSONSerialization JSONObjectWithData:reportBytes options:0 error:nil]:nil;check([report[@"mediaEchoOk"] boolValue]&&[report[@"screenEchoOk"] boolValue]&&[report[@"protocol"] isEqual:@"tcp"],@"Browser did not select TCP for both roles");
        __block NSDictionary *snapshot;[peer snapshot:^(NSDictionary *value){snapshot=value;}];spin(^BOOL{return snapshot!=nil;},8);check([snapshot[@"selectedPair"][@"protocol"] isEqual:@"tcp"]&&[snapshot[@"bytesSent"] unsignedLongLongValue]>0&&[snapshot[@"bytesReceived"] unsignedLongLongValue]>0,@"Native stats did not confirm TCP traffic");
        [NSData.data writeToFile:[folder stringByAppendingPathComponent:@"native-checked"] atomically:YES];spin(^BOOL{return !task.running;},15);check(task.terminationStatus==0,@"Browser TCP transfer check failed");
        puts("NATIVE_BROWSER_TCP_PASSED: real native passive TCP host -> Chromium active TCP candidate, UDP excluded from both exchanged descriptions, exact binary media/screen echoes, bidirectional traffic. Same-Mac interoperability test, not Tesla.");
    } @catch(NSException *error){
        fprintf(stderr,"Native/browser TCP test failed: %s\n",error.reason.UTF8String);
        __block NSDictionary *diagnostic;[peer snapshot:^(NSDictionary *value){diagnostic=value;}];NSDate *end=[NSDate dateWithTimeIntervalSinceNow:2];while(!diagnostic&&end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
        fprintf(stderr,"TCP diagnostic: state=%s; pairs=%lu; DTLS=%s\n",[diagnostic[@"connectionState"] UTF8String]?: "unknown",(unsigned long)[diagnostic[@"iceChecks"] count],[[diagnostic[@"dtlsStates"] componentsJoinedByString:@","] UTF8String]?: "unknown");result=1;
    }
    @finally {if(task.running)[task terminate];[peer close];[files removeItemAtPath:folder error:nil];}
    return result;
}}
