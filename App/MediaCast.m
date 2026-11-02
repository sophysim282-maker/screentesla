#import "MediaCast.h"
#import "HLSPlaylist.h"
#import <sys/socket.h>
#import <unistd.h>
#import <math.h>

@interface MediaCast () {
    NSCondition *_ready;
    dispatch_queue_t _events;
    NSURLSession *_network;
    int _reverse;
    void *_reverseConnection;
    NSString *_appleSession,*_epoch,*_primary,*_uuid;
    NSMutableDictionary *_resources,*_identifiers,*_cache,*_pending;
    NSUInteger _requestID,_command;
    BOOL _active,_paused,_readyToPlay;
    double _position,_duration,_start,_fraction,_heartbeat,_rate,_seekPosition;
    NSString *_commandKind;
    NSString *_error,*_eventState;
}
@end
static NSData *plistData(id object){return [NSPropertyListSerialization dataWithPropertyList:object format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];}
static NSDictionary *readPlist(NSData *data){id object=[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];return [object isKindOfClass:NSDictionary.class]?object:nil;}
static NSString *header(http_request_t *r,const char *key){const char *v=http_request_get_header(r,key);return v?[NSString stringWithUTF8String:v]:@"";}
static BOOL webURL(NSURL *url){return [@[@"http",@"https"] containsObject:url.scheme.lowercaseString] && url.host.length && !url.user.length && !url.password.length;}
static BOOL virtualURL(NSURL *url){return [url.scheme.lowercaseString isEqual:@"mlhls"] && url.host.length;}
static BOOL sendBytes(int fd,NSData *data){const char *p=data.bytes;NSUInteger n=data.length;while(n){ssize_t k=send(fd,p,n,0);if(k<0 && errno==EINTR)continue;if(k<=0)return NO;p+=k;n-=(NSUInteger)k;}return YES;}
@implementation MediaCast
- (instancetype)init{if((self=[super init])){_ready=[NSCondition new];_events=dispatch_queue_create("ScreenLink.media.events",DISPATCH_QUEUE_SERIAL);_reverse=-1;_resources=[NSMutableDictionary dictionary];_identifiers=[NSMutableDictionary dictionary];_cache=[NSMutableDictionary dictionary];_pending=[NSMutableDictionary dictionary];_epoch=NSUUID.UUID.UUIDString;NSURLSessionConfiguration *c=NSURLSessionConfiguration.ephemeralSessionConfiguration;c.timeoutIntervalForRequest=12;c.timeoutIntervalForResource=20;c.requestCachePolicy=NSURLRequestReloadIgnoringLocalCacheData;_network=[NSURLSession sessionWithConfiguration:c];}return self;}
- (void)log:(NSString *)text{if(self.status)self.status(text);}
- (BOOL)active{[_ready lock];BOOL value=_active;[_ready unlock];return value;}
- (BOOL)videoIsLive{[_ready lock];BOOL value=_active && _readyToPlay && NSProcessInfo.processInfo.systemUptime-_heartbeat<10;[_ready unlock];return value;}
- (NSString *)registerURL:(NSString *)url{
    NSString *identifier=_identifiers[url];
    if(!identifier){if(_resources.count>=4096)return nil;identifier=NSUUID.UUID.UUIDString;_resources[identifier]=url;_identifiers[url]=identifier;}
    return [NSString stringWithFormat:@"/media/resource/%@?token=%@",identifier,self.token];
}
- (void)sendEvent:(NSDictionary *)object session:(NSString *)session{
    NSData *body=plistData(object);if(!body)return;
    NSString *head=[NSString stringWithFormat:@"POST /event HTTP/1.1\r\nX-Apple-Session-ID: %@\r\nContent-Type: text/x-apple-plist+xml\r\nContent-Length: %lu\r\n\r\n",session,(unsigned long)body.length];
    NSMutableData *bytes=[[head dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];[bytes appendData:body];
    dispatch_async(_events,^{
        [self->_ready lock];int fd=([session isEqual:self->_appleSession] && self->_reverse>=0)?dup(self->_reverse):-1;[self->_ready unlock];
        if(fd<0){[self log:@"MEDIA: no reverse AirPlay channel. Re-select ScreenLink in YouTube's AirPlay menu."];return;}
        struct timeval timeout={2,0};setsockopt(fd,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof timeout);
#ifdef SO_NOSIGPIPE
        int one=1;setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof one);
#endif
        BOOL sent=sendBytes(fd,bytes);close(fd);if(!sent)[self log:@"MEDIA: AirPlay reverse-channel send failed."];
    });
}
- (void)requestURL:(NSString *)url{
    [_ready lock];
    if(!_active || _pending[url]){[_ready unlock];return;}
    NSUInteger request=++_requestID;_pending[url]=@(request);NSString *session=_appleSession;[_ready unlock];
    NSDictionary *headers=@{@"X-Playback-Session-Id":session,@"User-Agent":@"AppleCoreMedia/1.0.0.11B554a (Apple TV; U; CPU OS 7_0_4 like Mac OS X; en_us"};
    NSDictionary *params=@{@"FCUP_Response_ClientInfo":@1,@"FCUP_Response_ClientRef":@40030004,@"FCUP_Response_RequestID":@(request),@"FCUP_Response_URL":url,@"sessionID":@1,@"FCUP_Response_Headers":headers};
    [self sendEvent:@{@"sessionID":@1,@"type":@"unhandledURLRequest",@"request":params} session:session];
}
- (NSDictionary *)state{[_ready lock];NSString *path=_primary?[self registerURL:_primary]:nil;NSDictionary *state=@{@"active":@(_active),@"ready":@(_readyToPlay),@"epoch":_epoch,@"url":path?:@"",@"command":@(_command),@"commandKind":_commandKind?:@"rate",@"seek":@(_seekPosition),@"paused":@(_paused),@"position":@(_position),@"duration":@(_duration),@"start":@(_start),@"fraction":@(_fraction),@"error":_error?:@""};[_ready unlock];return state;}
- (void)report:(NSDictionary *)report{
    NSString *event=nil,*session=nil;[_ready lock];
    if(![report[@"epoch"] isEqual:_epoch] || !_active){[_ready unlock];return;}
    double position=[report[@"position"] doubleValue],duration=[report[@"duration"] doubleValue];
    if(isfinite(position) && position>=0)_position=position;if(isfinite(duration) && duration>=0)_duration=duration;
    _heartbeat=NSProcessInfo.processInfo.systemUptime;if([report[@"command"] unsignedIntegerValue]==_command){_paused=[report[@"paused"] boolValue];_rate=_paused?0:1;}_readyToPlay=[report[@"ready"] boolValue];
    NSString *error=[report[@"error"] isKindOfClass:NSString.class]?report[@"error"]:nil;
    if(error.length)_error=[error substringToIndex:MIN(error.length,240)];
    NSString *next=[report[@"ended"] boolValue]?@"stopped":(_readyToPlay?([report[@"paused"] boolValue]?@"paused":@"playing"):@"loading");
    if(![next isEqual:_eventState]){_eventState=next;event=next;session=_appleSession;}
    if([next isEqual:@"stopped"])_active=NO;[_ready unlock];
    if(event){[self sendEvent:@{@"category":@"video",@"state":event} session:session];[self log:[NSString stringWithFormat:@"MEDIA BROWSER %@: video-only playback state reported.",event.uppercaseString]];}
}
- (void)connectionClosed:(void *)connection{[_ready lock];if(connection==_reverseConnection){if(_reverse>=0)close(_reverse);_reverse=-1;_reverseConnection=NULL;[_pending removeAllObjects];[_ready broadcast];}[_ready unlock];}
- (void)stop{[_ready lock];_active=NO;_readyToPlay=NO;_primary=nil;_epoch=NSUUID.UUID.UUIDString;[_resources removeAllObjects];[_identifiers removeAllObjects];[_pending removeAllObjects];[_cache removeAllObjects];if(_reverse>=0)close(_reverse);_reverse=-1;_reverseConnection=NULL;[_ready broadcast];[_ready unlock];}
- (void)reply:(http_response_t **)response status:(int)code type:(NSString *)type data:(NSData *)data{
    *response=http_response_init("HTTP/1.1",code,code==200?"OK":(code==101?"Switching Protocols":"Request Failed"));
    if(type)http_response_add_header(*response,"Content-Type",type.UTF8String);
    http_response_finish(*response,data.bytes,(int)data.length);
}
- (BOOL)handle:(http_request_t *)request connection:(void *)connection socket:(int)socket response:(http_response_t **)response{
    const char *rawMethod=http_request_get_method(request),*rawURL=http_request_get_url(request);
    if(rawMethod && !strcmp(rawMethod,"RESPONSE"))return YES;
    if(!rawURL || !rawMethod)return NO;
    NSString *method=[NSString stringWithUTF8String:rawMethod];NSURLComponents *url=[NSURLComponents componentsWithString:[@"http://receiver" stringByAppendingString:[NSString stringWithUTF8String:rawURL]]];
    NSString *path=url.path;NSSet *paths=[NSSet setWithArray:@[@"/server-info",@"/reverse",@"/play",@"/action",@"/playback-info",@"/scrub",@"/rate",@"/stop",@"/getProperty",@"/setProperty"]];
    if(![paths containsObject:path])return NO;
    int length=0;const char *raw=http_request_get_data(request,&length);if(length<0 || length>4*1024*1024){[self reply:response status:413 type:nil data:nil];return YES;}
    NSData *body=length?[NSData dataWithBytes:raw length:(NSUInteger)length]:[NSData data];NSDictionary *plist=readPlist(body);NSString *session=header(request,"X-Apple-Session-ID");
    NSDictionary *query;NSMutableDictionary *q=[NSMutableDictionary dictionary];for(NSURLQueryItem *item in url.queryItems)if(item.value)q[item.name]=item.value;query=q;
    if([path isEqual:@"/server-info"]){
        NSDictionary *info=@{@"features":@(0x5A7FFEFB),@"deviceid":self.deviceID?:@"",@"macAddress":self.deviceID?:@"",@"model":@"AppleTV2,1",@"srcvers":@"220.68",@"osBuildVersion":@"12B435",@"protovers":@"1.0",@"vv":@2};
        [self reply:response status:200 type:@"text/x-apple-plist+xml" data:plistData(info)];return YES;
    }
    if([path isEqual:@"/reverse"] && [method isEqual:@"POST"]){
        if(socket<0 || ![header(request,"Upgrade").uppercaseString isEqual:@"PTTH/1.0"]){[self reply:response status:400 type:nil data:nil];return YES;}
        [_ready lock];if(_reverse>=0)close(_reverse);_reverse=dup(socket);_reverseConnection=connection;[_ready unlock];
        *response=http_response_init("HTTP/1.1",101,"Switching Protocols");http_response_add_header(*response,"Connection","Upgrade");http_response_add_header(*response,"Upgrade","PTTH/1.0");http_response_finish(*response,NULL,0);
        [self log:@"MEDIA: YouTube AirPlay reverse control channel connected."];return YES;
    }
    if([path isEqual:@"/play"] && [method isEqual:@"POST"]){
        NSString *location=[plist[@"Content-Location"] isKindOfClass:NSString.class]?plist[@"Content-Location"]:nil;
        if(!location){NSString *text=[[NSString alloc]initWithData:body encoding:NSUTF8StringEncoding];for(NSString *line in [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet])if([line hasPrefix:@"Content-Location:"])location=[[line substringFromIndex:17] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];}
        NSURL *target=[NSURL URLWithString:location?:@""];
        if(!session.length || session.length>128 || [session rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location!=NSNotFound || (!webURL(target)&&!virtualURL(target))){[self reply:response status:400 type:nil data:nil];return YES;}
        [_ready lock];_active=YES;_readyToPlay=NO;_paused=NO;_position=0;_duration=0;_heartbeat=0;_rate=1;_command=0;_commandKind=@"rate";_seekPosition=0;_start=MAX(0,[plist[@"Start-Position-Seconds"] doubleValue]);_fraction=MAX(0,MIN(1,[plist[@"Start-Position"] doubleValue]));_error=nil;_eventState=@"loading";_appleSession=session;_primary=target.absoluteString;_uuid=[plist[@"uuid"] isKindOfClass:NSString.class]?plist[@"uuid"]:NSUUID.UUID.UUIDString;_epoch=NSUUID.UUID.UUIDString;[_resources removeAllObjects];[_identifiers removeAllObjects];[_cache removeAllObjects];[_pending removeAllObjects];[_ready broadcast];[_ready unlock];
        [self reply:response status:200 type:nil data:nil];
        [self log:@"MEDIA PLAY REQUEST: native video-only handoff received. Open the hotspot viewer; its video player will show only the playing media."];
        [self sendEvent:@{@"category":@"video",@"state":@"loading"} session:session];if(virtualURL(target))[self requestURL:target.absoluteString];return YES;
    }
    if([path isEqual:@"/action"] && [method isEqual:@"POST"]){
        NSDictionary *params=[plist[@"params"] isKindOfClass:NSDictionary.class]?plist[@"params"]:@{};
        NSString *type=plist[@"type"];
        if([type isEqual:@"unhandledURLResponse"]){
            NSString *location=[params[@"FCUP_Response_URL"] isKindOfClass:NSString.class]?params[@"FCUP_Response_URL"]:nil;NSData *data=[params[@"FCUP_Response_Data"] isKindOfClass:NSData.class]?params[@"FCUP_Response_Data"]:nil;
            [_ready lock];NSNumber *expected=location?_pending[location]:nil;BOOL valid=[session isEqual:_appleSession] && expected && [expected isEqual:params[@"FCUP_Response_RequestID"]];
            if(valid){NSInteger code=params[@"FCUP_Response_StatusCode"]?[params[@"FCUP_Response_StatusCode"] integerValue]:200;_cache[location]=@{@"data":data?:[NSData data],@"code":@(code),@"time":@(NSProcessInfo.processInfo.systemUptime)};[_pending removeObjectForKey:location];[_ready broadcast];}[_ready unlock];
            [self reply:response status:valid?200:409 type:nil data:nil];if(valid)[self log:[NSString stringWithFormat:@"MEDIA PLAYLIST RESPONSE: %lu bytes received from YouTube's control channel.",(unsigned long)data.length]];return YES;
        }
        if([type isEqual:@"playlistRemove"]){[_ready lock];NSDictionary *item=[params[@"item"] isKindOfClass:NSDictionary.class]?params[@"item"]:@{};if([session isEqual:_appleSession] && [item[@"uuid"] isEqual:_uuid]){_active=NO;_readyToPlay=NO;[_ready broadcast];}[_ready unlock];[self reply:response status:200 type:nil data:nil];return YES;}
        [self reply:response status:501 type:nil data:nil];[self log:@"MEDIA: sender requested an unsupported playlist action. Copy test log if playback stops here."];return YES;
    }
    if([path isEqual:@"/playback-info"]){
        [_ready lock];double duration=_duration,position=_position;BOOL ready=_readyToPlay;double rate=_paused?0:_rate;[_ready unlock];
        NSDictionary *info=@{@"duration":@(duration),@"position":@(position),@"rate":@(rate),@"readyToPlay":@(ready),@"playbackBufferEmpty":@(!ready),@"playbackBufferFull":@(ready),@"playbackLikelyToKeepUp":@(ready),@"loadedTimeRanges":@[@{@"start":@(position),@"duration":@(MAX(0,duration-position))}],@"seekableTimeRanges":@[@{@"start":@0,@"duration":@(duration)}]};[self reply:response status:200 type:@"text/x-apple-plist+xml" data:plistData(info)];return YES;
    }
    if([path isEqual:@"/scrub"]){
        [_ready lock];if([method isEqual:@"POST"] && query[@"position"]){double value=[query[@"position"] doubleValue];if(isfinite(value) && value>=0){_seekPosition=value;_commandKind=@"seek";_command++;}}
        NSData *result=[[NSString stringWithFormat:@"duration: %.6f\nposition: %.6f\n",_duration,_position] dataUsingEncoding:NSUTF8StringEncoding];[_ready unlock];[self reply:response status:200 type:@"text/parameters" data:result];return YES;
    }
    if([path isEqual:@"/rate"]){[_ready lock];double rate=[query[@"value"] doubleValue];_paused=rate==0;_rate=_paused?0:1;_commandKind=@"rate";_command++;[_ready unlock];[self reply:response status:200 type:nil data:nil];return YES;}
    if([path isEqual:@"/stop"]){[_ready lock];_active=NO;_readyToPlay=NO;_command++;[_ready broadcast];[_ready unlock];[self reply:response status:200 type:nil data:nil];[self log:@"MEDIA: sender stopped native playback."];return YES;}
    [self reply:response status:200 type:@"text/x-apple-plist+xml" data:plistData(@{@"errorCode":@0})];return YES;
}
- (NSDictionary *)resource:(NSString *)identifier range:(NSString *)range{
    [_ready lock];NSString *location=_resources[identifier],*epoch=_epoch;[_ready unlock];if(!location)return @{@"code":@404};
    NSURL *url=[NSURL URLWithString:location];NSData *data=nil;NSInteger code=200;NSString *mime=nil,*contentRange=nil;
    if(virtualURL(url)){
        [_ready lock];NSDictionary *cached=_cache[location];BOOL fresh=cached && NSProcessInfo.processInfo.systemUptime-[cached[@"time"] doubleValue]<2;[_ready unlock];
        if(!fresh)[self requestURL:location];
        [_ready lock];NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:10];while([epoch isEqual:_epoch] && _active && _pending[location])if(![_ready waitUntilDate:deadline])break;
        cached=[epoch isEqual:_epoch]?_cache[location]:nil;data=cached[@"data"];code=cached?[cached[@"code"] integerValue]:504;if(_pending[location])[_pending removeObjectForKey:location];[_ready unlock];mime=@"application/vnd.apple.mpegurl";
    }else if(webURL(url)){
        NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];[request setValue:@"AppleCoreMedia/1.0 ScreenLink" forHTTPHeaderField:@"User-Agent"];
        if(range.length<128 && [range hasPrefix:@"bytes="] && [range rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location==NSNotFound)[request setValue:range forHTTPHeaderField:@"Range"];
        dispatch_semaphore_t done=dispatch_semaphore_create(0);__block NSData *download=nil;__block NSHTTPURLResponse *response=nil;
        NSURLSessionDataTask *task=[_network dataTaskWithRequest:request completionHandler:^(NSData *bytes,NSURLResponse *r,NSError *error){download=bytes;response=[r isKindOfClass:NSHTTPURLResponse.class]?(NSHTTPURLResponse *)r:nil;dispatch_semaphore_signal(done);}];[task resume];
        if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,20*NSEC_PER_SEC))){[task cancel];return @{@"code":@504};}
        data=download;code=response?response.statusCode:502;mime=response.MIMEType;contentRange=response.allHeaderFields[@"Content-Range"];
        if(data.length>32*1024*1024)return @{@"code":@413};
    }else return @{@"code":@400};
    if(code<200 || code>=300 || !data.length)return @{@"code":@(code>=400?code:502)};
    NSString *text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    if([text hasPrefix:@"#EXTM3U"]){
        NSError *error=nil;NSString *rewritten=SLRewritePlaylist(text,^NSString *(NSString *uri){
            NSURL *target=[NSURL URLWithString:uri relativeToURL:url].absoluteURL;if(!webURL(target)&&!virtualURL(target))return nil;
            [self->_ready lock];NSString *path=[epoch isEqual:self->_epoch]?[self registerURL:target.absoluteString]:nil;[self->_ready unlock];return path;
        },&error);
        if(!rewritten){[self log:[@"MEDIA PLAYLIST ERROR: " stringByAppendingString:error.localizedDescription?:@"Unknown playlist error"]];return @{@"code":@422};}
        data=[rewritten dataUsingEncoding:NSUTF8StringEncoding];mime=@"application/vnd.apple.mpegurl";
    }
    [_ready lock];BOOL current=[epoch isEqual:_epoch];[_ready unlock];if(!current)return @{@"code":@410};
    NSMutableDictionary *result=[@{@"code":@(code),@"data":data,@"mime":mime?:@"application/octet-stream"} mutableCopy];if(contentRange)result[@"range"]=contentRange;return result;
}
@end
