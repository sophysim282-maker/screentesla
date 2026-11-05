#import <Foundation/Foundation.h>
#import "MediaCast.h"
#import "HLSPlaylist.h"
#import <sys/socket.h>
#import <unistd.h>
#include <assert.h>
static NSDictionary *parse(NSData *data){id p=[NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];assert([p isKindOfClass:NSDictionary.class]);return p;}
static NSData *binary(id object){return [NSPropertyListSerialization dataWithPropertyList:object format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];}
static NSData *exchange(MediaCast *media,NSString *method,NSString *path,NSString *session,id plist,void *connection,int fd){
    NSData *body=plist?binary(plist):[NSData data];NSString *head=[NSString stringWithFormat:@"%@ %@ HTTP/1.1\r\nHost: receiver\r\nContent-Type: application/x-apple-binary-plist\r\nContent-Length: %lu\r\n%@%@\r\n",method,path,(unsigned long)body.length,session?[NSString stringWithFormat:@"X-Apple-Session-ID: %@\r\n",session]:@"",[path isEqual:@"/reverse"]?@"Connection: Upgrade\r\nUpgrade: PTTH/1.0\r\n":@""];
    NSMutableData *wire=[[head dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];[wire appendData:body];http_request_t *request=http_request_init();http_request_add_data(request,wire.bytes,(int)wire.length);assert(!http_request_has_error(request));assert(http_request_is_complete(request));
    http_response_t *response=NULL;assert([media handle:request connection:connection socket:fd response:&response]);http_request_destroy(request);assert(response);int length=0;const char *raw=http_response_get_data(response,&length);NSData *result=[NSData dataWithBytes:raw length:length];http_response_destroy(response);
    // Parse the complete wire response as a persistent-connection client. A
    // missing zero Content-Length leaves HTTP 200 incomplete until EOF.
    http_request_t *framing=http_request_init();http_request_add_data(framing,result.bytes,(int)result.length);assert(!http_request_has_error(framing));assert(http_request_is_complete(framing));http_request_destroy(framing);
    return result;
}
static NSInteger status(NSData *wire){NSString *text=[[NSString alloc]initWithData:wire encoding:NSUTF8StringEncoding];return [[[text componentsSeparatedByString:@" "] objectAtIndex:1] integerValue];}
static NSDictionary *responsePlist(NSData *wire){NSData *boundary=[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];NSRange r=[wire rangeOfData:boundary options:0 range:NSMakeRange(0,wire.length)];return parse([wire subdataWithRange:NSMakeRange(NSMaxRange(r),wire.length-NSMaxRange(r))]);}
static NSDictionary *event(int fd){
    NSMutableData *head=[NSMutableData data];char c;while(head.length<8192){assert(recv(fd,&c,1,0)==1);[head appendBytes:&c length:1];if(head.length>=4 && !memcmp((const char *)head.bytes+head.length-4,"\r\n\r\n",4))break;}
    NSString *text=[[NSString alloc]initWithData:head encoding:NSUTF8StringEncoding];assert([text hasPrefix:@"POST /event HTTP/1.1"]);NSUInteger length=0;for(NSString *line in [text componentsSeparatedByString:@"\r\n"])if([line hasPrefix:@"Content-Length:"])length=[[line substringFromIndex:15] integerValue];assert(length>0 && length<65536);
    NSMutableData *body=[NSMutableData dataWithLength:length];NSUInteger used=0;while(used<length){ssize_t n=recv(fd,(char *)body.mutableBytes+used,length-used,0);assert(n>0);used+=n;}return parse(body);
}
static void deliver(MediaCast *media,NSDictionary *request,NSString *text,NSString *session){NSDictionary *p=request[@"request"];NSDictionary *response=@{@"type":@"unhandledURLResponse",@"params":@{@"FCUP_Response_URL":p[@"FCUP_Response_URL"],@"FCUP_Response_RequestID":p[@"FCUP_Response_RequestID"],@"FCUP_Response_StatusCode":@0,@"FCUP_Response_Data":[text dataUsingEncoding:NSUTF8StringEncoding]}};assert(status(exchange(media,@"POST",@"/action",session,response,NULL,-1))==200);}
@interface MediaCast (RegistryTest)
- (NSString *)rewrite:(NSString *)text base:(NSURL *)base owner:(NSString *)owner epoch:(NSString *)epoch code:(NSInteger *)code;
@end
int main(void){@autoreleasepool{
    NSData *validPlaylist=[@"#EXTM3U\n#EXT-X-ENDLIST\n" dataUsingEncoding:NSUTF8StringEncoding];
    assert(SLFCUPPlaylistStatus(0,validPlaylist)==200);
    assert(SLFCUPPlaylistStatus(0,[NSData data])==502);
    assert(SLFCUPPlaylistStatus(0,nil)==502);
    assert(SLFCUPPlaylistStatus(0,[@"not a playlist" dataUsingEncoding:NSUTF8StringEncoding])==502);
    assert(SLFCUPPlaylistStatus(403,validPlaylist)==403);
    NSError *error=nil;NSString *expanded=SLExpandYouTubePlaylist(@"#EXTM3U\n#YT-EXT-CONDENSED-URL:BASE-URI=\"https://example.test/videoplayback\",PARAMS=\"sq,lmt\",PREFIX=\"s/\"\n#EXTINF:2.0,\ns/1/42\n#EXT-X-ENDLIST\n",&error);assert(!error && [expanded containsString:@"https://example.test/videoplayback/sq/1/lmt/42"]);
    assert(!SLExpandYouTubePlaylist(@"#EXTM3U\n#YT-EXT-CONDENSED-URL:PREFIX=\"s/\"\n",&error));
    assert(!SLRewritePlaylist(@"#EXTM3U\n#EXT-X-KEY:METHOD=SAMPLE-AES,URI=\"skd://protected\"\n",^NSString *(NSString *uri){return uri;},&error));
    NSString *hdMaster=@"#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=300000,RESOLUTION=426x240\nlow.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=8000000,RESOLUTION=1280x720\nmid.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=12000000,RESOLUTION=1920x1080\nhigh.m3u8\n";
    assert(([SLPlaylistVideoHeights(hdMaster) isEqual:@[@240,@720,@1080]]));
    NSString *mappedHD=SLRewritePlaylist(hdMaster,^NSString *(NSString *uri){return [@"/local/" stringByAppendingString:uri];},NULL);assert([mappedHD containsString:@"RESOLUTION=1920x1080"]);assert([mappedHD containsString:@"/local/high.m3u8"]);
    MediaCast *media=[MediaCast new];media.token=@"test-token";media.deviceID=@"02:00:00:00:00:01";
    assert(status(exchange(media,@"POST",@"/play",nil,@{@"Content-Location":@"mlhls://localhost/master.m3u8"},NULL,-1))==400);
    NSDictionary *server=responsePlist(exchange(media,@"GET",@"/server-info",nil,nil,NULL,-1));assert([server[@"model"] isEqual:@"AppleTV3,2"]);assert([server[@"features"] unsignedIntValue]==0x27B);assert(([server[@"features"] unsignedIntValue]&17)==17);assert(!([server[@"features"] unsignedIntValue]&4));
    int fds[2];assert(!socketpair(AF_UNIX,SOCK_STREAM,0,fds));struct timeval timeout={5,0};setsockopt(fds[1],SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof timeout);void *connection=(void *)1;
    assert(status(exchange(media,@"POST",@"/reverse",@"S1",nil,connection,fds[0]))==101);
    NSDictionary *play=@{@"Content-Location":@"mlhls://localhost/master.m3u8",@"uuid":@"video-1",@"Start-Position-Seconds":@3};
    assert(status(exchange(media,@"POST",@"/play",@"S1",play,NULL,-1))==200);assert([event(fds[1])[@"state"] isEqual:@"loading"]);NSDictionary *masterRequest=event(fds[1]);assert([masterRequest[@"type"] isEqual:@"unhandledURLRequest"]);
    deliver(media,masterRequest,@"#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=1280x720\nvideo.m3u8\n",@"S1");
    NSDictionary *childRequest=event(fds[1]); // Prefetched before any browser variant request.
    NSDictionary *state=[media state];assert([state[@"active"] boolValue]);assert(([state[@"sourceHeights"] isEqual:@[@720]]));assert([state[@"start"] intValue]==3);NSString *identifier=[NSURLComponents componentsWithString:state[@"url"]].path.lastPathComponent;
    NSDictionary *master=[media resource:identifier range:nil];assert([master[@"code"] intValue]==200);NSString *masterText=[[NSString alloc]initWithData:master[@"data"] encoding:NSUTF8StringEncoding];assert([masterText containsString:@"/media/resource/"]);assert(![masterText containsString:@"mlhls://"]);
    NSString *child=nil;for(NSString *line in [masterText componentsSeparatedByString:@"\n"])if([line hasPrefix:@"/media/resource/"])child=[NSURLComponents componentsWithString:line].path.lastPathComponent;assert(child);
    dispatch_semaphore_t done=dispatch_semaphore_create(0);__block NSDictionary *variant=nil;dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{variant=[media resource:child range:nil];dispatch_semaphore_signal(done);});
    __block NSDictionary *secondVariant=nil;dispatch_semaphore_t secondDone=dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{secondVariant=[media resource:child range:nil];dispatch_semaphore_signal(secondDone);});
    assert([childRequest[@"request"][@"FCUP_Response_URL"] isEqual:@"mlhls://localhost/video.m3u8"]);
    deliver(media,childRequest,@"#EXTM3U\n#YT-EXT-CONDENSED-URL:BASE-URI=\"https://example.test/videoplayback\",PARAMS=\"sq,lmt\",PREFIX=\"s/\"\n#EXTINF:2.0,\ns/1/42\n#EXT-X-ENDLIST\n",@"S1");assert(!dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC)));assert([variant[@"code"] intValue]==200);NSString *variantText=[[NSString alloc]initWithData:variant[@"data"] encoding:NSUTF8StringEncoding];assert(!dispatch_semaphore_wait(secondDone,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC)));assert([secondVariant[@"code"] intValue]==200);assert([variantText containsString:@"/media/resource/"]);assert(![variantText containsString:@"s/1/42"]);
    MediaCast *rolling=[MediaCast new];rolling.token=@"secret";NSString *owner=@"https://example.test/rolling.m3u8";
    assert(status(exchange(rolling,@"POST",@"/play",@"R",@{@"Content-Location":owner},NULL,-1))==200);
    NSString *epoch=[rolling state][@"epoch"];NSInteger rewriteCode;NSMutableDictionary *resources=[rolling valueForKey:@"resources"],*flights=[rolling valueForKey:@"inflight"];NSMutableArray *retired=[rolling valueForKey:@"retiredLinks"];NSString *pinned=nil;
    for(NSUInteger generation=0;generation<12;generation++){
        for(NSUInteger i=0;i<retired.count;i++)retired[i]=@{@"ids":retired[i][@"ids"],@"until":@0};
        NSMutableString *list=[NSMutableString stringWithString:@"#EXTM3U\n"];for(NSUInteger i=0;i<1000;i++)[list appendFormat:@"#EXTINF:2,\nhttps://example.test/s/%lu\n",(unsigned long)(generation*500+i)];
        NSString *rewritten=[rolling rewrite:list base:[NSURL URLWithString:owner] owner:owner epoch:epoch code:&rewriteCode];assert(rewritten&&rewriteCode==200);assert(resources.count<=2002);
        for(NSString *line in [rewritten componentsSeparatedByString:@"\n"])if([line hasPrefix:@"/media/resource/"]){NSString *key=[NSURLComponents componentsWithString:line].path.lastPathComponent;assert(resources[key]);assert([[NSUUID alloc]initWithUUIDString:key]);if(!pinned){pinned=key;flights[key]=@1;}}
        assert(resources[pinned]);assert([[rolling rewrite:list base:[NSURL URLWithString:owner] owner:owner epoch:epoch code:&rewriteCode] isEqual:rewritten]);
    }
    // A paused source must retain full cached seek references while another
    // rendition is loaded; consuming a rendition pins it across long gaps.
    NSString *vod=@"https://example.test/vod.m3u8";NSInteger pausedCode;
    NSString *vodBody=[rolling rewrite:@"#EXTM3U\nhttps://example.test/vod/early.ts\nhttps://example.test/vod/late.ts\n#EXT-X-ENDLIST\n" base:[NSURL URLWithString:vod] owner:vod epoch:epoch code:&pausedCode];assert(vodBody);
    NSSet *vodLinks=[[[rolling valueForKey:@"playlistLinks"] objectForKey:vod] copy];
    NSMutableDictionary *times=[rolling valueForKey:@"playlistTimes"];
    assert(status(exchange(rolling,@"POST",@"/rate?value=0",@"R",nil,NULL,-1))==200);times[vod]=@0;
    assert([rolling rewrite:@"#EXTM3U\nhttps://example.test/other.ts\n" base:[NSURL URLWithString:owner] owner:owner epoch:epoch code:&pausedCode]);
    for(NSString *key in vodLinks)assert(resources[key]);
    [[rolling valueForKey:@"selectedPlaylists"] addObject:vod];assert(status(exchange(rolling,@"POST",@"/rate?value=1",@"R",nil,NULL,-1))==200);times[vod]=@0;
    assert([rolling rewrite:@"#EXTM3U\nhttps://example.test/another.ts\n" base:[NSURL URLWithString:owner] owner:owner epoch:epoch code:&pausedCode]);for(NSString *key in vodLinks)assert(resources[key]);
    NSUInteger count=resources.count;
    assert(![rolling rewrite:@"#EXTM3U\nfile:///private/test\n" base:[NSURL URLWithString:owner] owner:owner epoch:epoch code:&rewriteCode]&&rewriteCode==422&&resources.count==count);
    assert(![rolling rewrite:@"#EXTM3U\nhttps://example.test/a\n" base:[NSURL URLWithString:owner] owner:owner epoch:@"stale" code:&rewriteCode]&&rewriteCode==410&&resources.count==count);
    NSMutableString *oversized=[NSMutableString stringWithString:@"#EXTM3U\n"];for(NSUInteger i=0;i<4100;i++)[oversized appendFormat:@"https://example.test/b/%lu\n",(unsigned long)i];
    assert(![rolling rewrite:oversized base:[NSURL URLWithString:owner] owner:owner epoch:epoch code:&rewriteCode]&&rewriteCode==503&&resources.count==count&&resources[pinned]);
    [rolling stop];assert(!resources.count&&!flights.count&&!retired.count);
    puts("Registry lifecycle passed: 6500 unique URLs, current seek links, stable UUID reloads, in-flight pinning, bounded memory, transactional capacity and invalid/stale errors.");
    [media report:@{@"epoch":state[@"epoch"],@"command":@0,@"position":@4,@"duration":@10,@"ready":@YES,@"paused":@NO}];assert(media.videoIsLive);assert([event(fds[1])[@"state"] isEqual:@"playing"]);
    NSDictionary *info=responsePlist(exchange(media,@"GET",@"/playback-info",@"S1",nil,NULL,-1));assert([info[@"duration"] intValue]==10 && [info[@"position"] intValue]==4);
    assert(status(exchange(media,@"POST",@"/scrub?position=7",@"S1",nil,NULL,-1))==200);assert([[media state][@"seek"] intValue]==7);
    assert(status(exchange(media,@"POST",@"/rate?value=0",@"S1",nil,NULL,-1))==200);assert([[media state][@"paused"] boolValue]);
    // HTTP response acknowledgements on the upgraded PTTH socket must parse.
    http_request_t *ack=http_request_init();const char *wire="HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n";http_request_add_data(ack,wire,(int)strlen(wire));assert(!http_request_has_error(ack));http_response_t *none=NULL;assert([media handle:ack connection:connection socket:fds[0] response:&none]);assert(!none);http_request_destroy(ack);
    [media connectionClosed:connection];
    [NSThread sleepForTimeInterval:2.1];NSTimeInterval began=NSDate.timeIntervalSinceReferenceDate;
    assert([[media resource:identifier range:nil][@"code"] intValue]==200);
    assert([[media resource:child range:nil][@"code"] intValue]==200);
    assert(NSDate.timeIntervalSinceReferenceDate-began<1); // Cached VOD survives sender-channel loss and old 2s TTL.
    [media stop];assert(!media.active);assert([[media resource:identifier range:nil][@"code"] intValue]==404);close(fds[0]);close(fds[1]);
    puts("Native media passed: status-zero FCUP playlists, persistent HTTP response completion, HTTP/PTTH, FCUP master/variant handoff, condensed YouTube HLS, early variant prefetch, durable VOD cache, playback feedback, pause/seek and cleanup.");
}return 0;}
