#import "MediaCast.h"
#import "BoundedDownload.h"
#import "HLSPlaylist.h"
#import <sys/socket.h>
#import <unistd.h>
#import <math.h>

@interface MediaCast () {
    NSCondition *_ready;
    dispatch_queue_t _events;
    int _reverse;
    void *_reverseConnection;
    NSString *_appleSession,*_epoch,*_primary,*_uuid;
    NSMutableDictionary *_resources,*_identifiers,*_cache,*_pending;
    NSMutableDictionary *_playlistLinks,*_playlistTimes,*_inflight;
    NSMutableArray *_retiredLinks;
    NSMutableOrderedSet *_selectedPlaylists;
    NSMutableOrderedSet *_prefetch;
    NSArray<NSNumber *> *_sourceHeights;
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
static BOOL stablePlaylist(NSData *data){NSString *text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];return [text hasPrefix:@"#EXTM3U"] && ([text containsString:@"#EXT-X-ENDLIST"] || [text containsString:@"#EXT-X-STREAM-INF:"] || [text containsString:@"#EXT-X-I-FRAME-STREAM-INF:"]);}
static BOOL sendBytes(int fd,NSData *data){const char *p=data.bytes;NSUInteger n=data.length;while(n){ssize_t k=send(fd,p,n,0);if(k<0 && errno==EINTR)continue;if(k<=0)return NO;p+=k;n-=(NSUInteger)k;}return YES;}
@implementation MediaCast
- (instancetype)init{if((self=[super init])){_ready=[NSCondition new];_events=dispatch_queue_create("ScreenLink.media.events",DISPATCH_QUEUE_SERIAL);_reverse=-1;_resources=[NSMutableDictionary dictionary];_identifiers=[NSMutableDictionary dictionary];_cache=[NSMutableDictionary dictionary];_pending=[NSMutableDictionary dictionary];_prefetch=[NSMutableOrderedSet orderedSet];_playlistLinks=[NSMutableDictionary dictionary];_playlistTimes=[NSMutableDictionary dictionary];_inflight=[NSMutableDictionary dictionary];_retiredLinks=[NSMutableArray array];_selectedPlaylists=[NSMutableOrderedSet orderedSet];_epoch=NSUUID.UUID.UUIDString;}return self;}
- (void)log:(NSString *)text{if(self.status)self.status(text);}
- (BOOL)active{[_ready lock];BOOL value=_active;[_ready unlock];return value;}
- (BOOL)videoIsLive{[_ready lock];BOOL value=_active && _readyToPlay && NSProcessInfo.processInfo.systemUptime-_heartbeat<10;[_ready unlock];return value;}
// Build 81: long YouTube videos send ~1000 segments per quality and 6 qualities; 4096
// references filled up, PiP could not load ("MEDIA PLAYLIST CAPACITY"), and iOS then
// suspended the app. The main app allows 16384; the memory-limited extension keeps 4096.
#if SL_BROADCAST_EXTENSION
#define SL_MEDIA_REGISTRY_LIMIT 4096
#else
#define SL_MEDIA_REGISTRY_LIMIT 16384
#endif
- (NSString *)registerURL:(NSString *)url{
    NSString *identifier=_identifiers[url];
    if(!identifier){if(_resources.count>=SL_MEDIA_REGISTRY_LIMIT)return nil;identifier=NSUUID.UUID.UUIDString;_resources[identifier]=url;_identifiers[url]=identifier;}
    return [NSString stringWithFormat:@"/media/resource/%@?token=%@",identifier,self.token];
}
// Registry mutation is serialized by _ready, and publication is transactional.
// UUID resource paths preserve compatibility with every existing website loader.
- (NSString *)rewrite:(NSString *)text base:(NSURL *)base owner:(NSString *)owner epoch:(NSString *)epoch code:(NSInteger *)code {
    NSMutableOrderedSet *urls=[NSMutableOrderedSet orderedSet];__block NSString *reason=nil;NSError *error=nil;
    NSString *valid=SLRewritePlaylist(text,^NSString *(NSString *uri){
        NSURL *target=[NSURL URLWithString:uri relativeToURL:base].absoluteURL;
        if(!webURL(target)&&!virtualURL(target)){reason=@"unsupported URI scheme or authority";return nil;}
        if([target.absoluteString lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>16384){reason=@"URI size limit";return nil;}
        [urls addObject:target.absoluteString];return uri;
    },&error);
    if(!valid){*code=422;[self log:[@"MEDIA PLAYLIST INVALID: " stringByAppendingString:reason?:error.localizedDescription?:@"invalid HLS"]];return nil;}
    [_ready lock];
    if(![epoch isEqual:_epoch]||!_active){[_ready unlock];*code=410;[self log:@"MEDIA PLAYLIST STALE: playback epoch changed."];return nil;}
    double now=NSProcessInfo.processInfo.systemUptime;
    for(NSString *key in _playlistLinks.allKeys)if(!_paused&&![key isEqual:_primary]&&![_selectedPlaylists containsObject:key]&&now-[_playlistTimes[key] doubleValue]>120){[_playlistLinks removeObjectForKey:key];[_playlistTimes removeObjectForKey:key];}
    NSIndexSet *expired=[_retiredLinks indexesOfObjectsPassingTest:^BOOL(NSDictionary *entry,NSUInteger index,BOOL *stop){return [entry[@"until"] doubleValue]<=now;}];[_retiredLinks removeObjectsAtIndexes:expired];
    NSMutableDictionary *mapping=[NSMutableDictionary dictionary];NSMutableSet *next=[NSMutableSet set],*keep=[NSMutableSet setWithArray:_inflight.allKeys];
    if(_primary&&_identifiers[_primary])[keep addObject:_identifiers[_primary]];
    for(NSString *url in urls){NSString *identifier=_identifiers[url]?:NSUUID.UUID.UUIDString;mapping[url]=identifier;[next addObject:identifier];}
    [keep unionSet:next];for(NSString *key in _playlistLinks)if(![key isEqual:owner])[keep unionSet:_playlistLinks[key]];
    for(NSDictionary *entry in _retiredLinks)[keep unionSet:entry[@"ids"]];
    NSSet *old=_playlistLinks[owner];double until=[_playlistTimes[owner] doubleValue]+30;BOOL retiring=old&&![old isEqual:next]&&until>now;
    if(retiring)[keep unionSet:old];
    if(keep.count>SL_MEDIA_REGISTRY_LIMIT||(!_playlistLinks[owner]&&_playlistLinks.count>=64)||(retiring&&_retiredLinks.count>=64)){
        [_ready unlock];*code=503;[self log:@"MEDIA PLAYLIST CAPACITY: active/in-flight references fill bounded registry; retry after snapshot grace."];return nil;
    }
    if(retiring)[_retiredLinks addObject:@{@"ids":old,@"until":@(until)}];
    for(NSString *identifier in _resources.allKeys)if(![keep containsObject:identifier]){NSString *url=_resources[identifier];[_resources removeObjectForKey:identifier];[_identifiers removeObjectForKey:url];[_cache removeObjectForKey:url];}
    for(NSString *url in mapping){_identifiers[url]=mapping[url];_resources[mapping[url]]=url;}
    _playlistLinks[owner]=next;_playlistTimes[owner]=@(now);NSString *token=self.token;
    NSString *rewritten=SLRewritePlaylist(text,^NSString *(NSString *uri){NSString *url=[NSURL URLWithString:uri relativeToURL:base].absoluteURL.absoluteString;return [NSString stringWithFormat:@"/media/resource/%@?token=%@",mapping[url],token];},NULL);
    [_ready unlock];*code=200;return rewritten;
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
- (void)drivePrefetch {
    [_ready lock];NSString *next=nil;
    if(_active && _reverse>=0 && !_pending.count)while(_prefetch.count){NSString *candidate=_prefetch.firstObject;[_prefetch removeObjectAtIndex:0];if(!_cache[candidate]){next=candidate;break;}}
    [_ready unlock];if(next)[self requestURL:next];
}
- (void)prefetchChildren:(NSData *)data base:(NSString *)location {
    NSString *text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    if(![text containsString:@"#EXT-X-STREAM-INF:"] && ![text containsString:@"#EXT-X-MEDIA:"])return;
    NSMutableOrderedSet *children=[NSMutableOrderedSet orderedSet];NSURL *base=[NSURL URLWithString:location];
    SLRewritePlaylist(text,^NSString *(NSString *uri){NSURL *target=[NSURL URLWithString:uri relativeToURL:base].absoluteURL;if(virtualURL(target) && children.count<64)[children addObject:target.absoluteString];return uri;},NULL);
    [_ready lock];if(_active && [location isEqual:_primary])for(NSString *child in children)if(!_cache[child] && !_pending[child])[_prefetch addObject:child];[_ready unlock];
    [self drivePrefetch];
}
- (void)recordSourceHeights:(NSData *)data location:(NSString *)location epoch:(NSString *)epoch{
    NSString *text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];NSArray *heights=SLPlaylistVideoHeights(text?:@"");if(!heights.count)return;
    [_ready lock];BOOL changed=[location isEqual:_primary]&&(!epoch||[epoch isEqual:_epoch])&&![_sourceHeights isEqual:heights];if(changed)_sourceHeights=heights;[_ready unlock];
    if(changed)[self log:[NSString stringWithFormat:@"MEDIA SOURCE RESOLUTIONS: %@p. These are YouTube-offered variants; no upscaling.",[heights componentsJoinedByString:@"p, "]]];
}
- (void)requestURL:(NSString *)url{
    [_ready lock];
    NSDictionary *cached=_cache[url];BOOL fresh=cached&&[cached[@"code"] integerValue]==200&&(stablePlaylist(cached[@"data"])||NSProcessInfo.processInfo.systemUptime-[cached[@"time"] doubleValue]<2);
    if(!_active || _pending[url] || fresh){[_ready unlock];return;}
    NSUInteger request=++_requestID;_pending[url]=@(request);NSString *session=_appleSession;[_ready unlock];
    NSDictionary *headers=@{@"X-Playback-Session-Id":session,@"User-Agent":@"AppleCoreMedia/1.0.0.11B554a (Apple TV; U; CPU OS 7_0_4 like Mac OS X; en_us"};
    NSDictionary *params=@{@"FCUP_Response_ClientInfo":@1,@"FCUP_Response_ClientRef":@40030004,@"FCUP_Response_RequestID":@(request),@"FCUP_Response_URL":url,@"sessionID":@1,@"FCUP_Response_Headers":headers};
    [self sendEvent:@{@"sessionID":@1,@"type":@"unhandledURLRequest",@"request":params} session:session];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,12*NSEC_PER_SEC),_events,^{
        [self->_ready lock];BOOL expired=[self->_pending[url] isEqual:@(request)];if(expired){[self->_pending removeObjectForKey:url];[self->_ready broadcast];}[self->_ready unlock];
        if(expired){[self log:@"MEDIA: a playlist request timed out; retaining the current session for retry."];[self drivePrefetch];}
    });
}
- (NSDictionary *)state{[_ready lock];NSString *path=_primary?[self registerURL:_primary]:nil;NSDictionary *state=@{@"receiverProfile":@"AppleTV3,2",@"sourceHeights":_sourceHeights?:@[],@"active":@(_active),@"ready":@(_readyToPlay),@"epoch":_epoch,@"url":path?:@"",@"command":@(_command),@"commandKind":_commandKind?:@"rate",@"seek":@(_seekPosition),@"paused":@(_paused),@"position":@(_position),@"duration":@(_duration),@"start":@(_start),@"fraction":@(_fraction),@"error":_error?:@""};[_ready unlock];return state;}
- (void)report:(NSDictionary *)report{
    NSString *event=nil,*session=nil,*newError=nil;[_ready lock];
    if(![report[@"epoch"] isEqual:_epoch] || !_active){[_ready unlock];return;}
    double position=[report[@"position"] doubleValue],duration=[report[@"duration"] doubleValue];
    if(isfinite(position) && position>=0)_position=position;if(isfinite(duration) && duration>=0)_duration=duration;
    _heartbeat=NSProcessInfo.processInfo.systemUptime;if([report[@"command"] unsignedIntegerValue]==_command){_paused=[report[@"paused"] boolValue];_rate=_paused?0:1;}_readyToPlay=[report[@"ready"] boolValue];
    NSString *error=[report[@"error"] isKindOfClass:NSString.class]?report[@"error"]:nil;
    if(!error.length && _readyToPlay)_error=nil;
    if(error.length && ![error isEqual:_error]){_error=[error substringToIndex:MIN(error.length,240)];newError=_error;}
    NSString *next=[report[@"ended"] boolValue]?@"stopped":(_readyToPlay?([report[@"paused"] boolValue]?@"paused":@"playing"):@"loading");
    if(![next isEqual:_eventState]){_eventState=next;event=next;session=_appleSession;}
    if([next isEqual:@"stopped"])_active=NO;[_ready unlock];
    if(newError)[self log:[@"MEDIA BROWSER ERROR: " stringByAppendingString:newError]];
    if(event){[self sendEvent:@{@"category":@"video",@"state":event} session:session];[self log:[NSString stringWithFormat:@"MEDIA BROWSER %@: video-only playback state reported.",event.uppercaseString]];}
}
- (void)connectionClosed:(void *)connection{[_ready lock];if(connection==_reverseConnection){if(_reverse>=0)close(_reverse);_reverse=-1;_reverseConnection=NULL;[_pending removeAllObjects];[_ready broadcast];}[_ready unlock];}
- (void)stop{[_ready lock];_active=NO;_readyToPlay=NO;_primary=nil;_sourceHeights=@[];_epoch=NSUUID.UUID.UUIDString;[_resources removeAllObjects];[_identifiers removeAllObjects];[_playlistLinks removeAllObjects];[_playlistTimes removeAllObjects];[_inflight removeAllObjects];[_retiredLinks removeAllObjects];[_selectedPlaylists removeAllObjects];[_pending removeAllObjects];[_prefetch removeAllObjects];[_cache removeAllObjects];if(_reverse>=0)close(_reverse);_reverse=-1;_reverseConnection=NULL;[_ready broadcast];[_ready unlock];}
- (void)reply:(http_response_t **)response status:(int)code type:(NSString *)type data:(NSData *)data{
    *response=http_response_init("HTTP/1.1",code,code==200?"OK":(code==101?"Switching Protocols":"Request Failed"));
    if(type)http_response_add_header(*response,"Content-Type",type.UTF8String);
    // HTTP/1.1 persistent responses with no body still need an explicit length.
    // Otherwise the sender waits for connection close and /play never completes.
    if(!data.length && code!=101)http_response_add_header(*response,"Content-Length","0");
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
        [self log:@"MEDIA: 1080p-capable legacy HLS receiver profile requested (AppleTV3,2; media features 0x27B)."];
        NSDictionary *info=@{@"features":@(0x27B),@"deviceid":self.deviceID?:@"",@"macAddress":self.deviceID?:@"",@"model":@"AppleTV3,2",@"srcvers":@"220.68",@"osBuildVersion":@"12B435",@"protovers":@"1.0",@"vv":@2};
        [self reply:response status:200 type:@"text/x-apple-plist+xml" data:plistData(info)];return YES;
    }
    if([path isEqual:@"/reverse"] && [method isEqual:@"POST"]){
        if(socket<0 || ![header(request,"Upgrade").uppercaseString isEqual:@"PTTH/1.0"]){[self log:@"MEDIA REVERSE REJECTED: missing socket or PTTH upgrade header."];[self reply:response status:400 type:nil data:nil];return YES;}
        [_ready lock];if(_reverse>=0)close(_reverse);_reverse=dup(socket);_reverseConnection=connection;[_ready unlock];
        *response=http_response_init("HTTP/1.1",101,"Switching Protocols");http_response_add_header(*response,"Connection","Upgrade");http_response_add_header(*response,"Upgrade","PTTH/1.0");http_response_finish(*response,NULL,0);
        [self log:@"MEDIA: YouTube AirPlay reverse control channel connected."];return YES;
    }
    if([path isEqual:@"/play"] && [method isEqual:@"POST"]){
        NSString *location=[plist[@"Content-Location"] isKindOfClass:NSString.class]?plist[@"Content-Location"]:nil;
        if(!location){NSString *text=[[NSString alloc]initWithData:body encoding:NSUTF8StringEncoding];for(NSString *line in [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet])if([line hasPrefix:@"Content-Location:"])location=[[line substringFromIndex:17] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];}
        NSURL *target=[NSURL URLWithString:location?:@""];
        if(!session.length || session.length>128 || [session rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location!=NSNotFound || (!webURL(target)&&!virtualURL(target))){[self log:[NSString stringWithFormat:@"MEDIA PLAY REJECTED: session %@, content URL scheme %@, plist keys %@.",session.length?@"present":@"missing",target.scheme?:@"missing",[[plist.allKeys sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@", "]?:@"none"]];[self reply:response status:400 type:nil data:nil];return YES;}
        [_ready lock];_active=YES;_readyToPlay=NO;_paused=NO;_position=0;_duration=0;_heartbeat=0;_rate=1;_command=0;_commandKind=@"rate";_seekPosition=0;_start=MAX(0,[plist[@"Start-Position-Seconds"] doubleValue]);_fraction=MAX(0,MIN(1,[plist[@"Start-Position"] doubleValue]));_error=nil;_eventState=@"loading";_appleSession=session;_sourceHeights=@[];_primary=target.absoluteString;_uuid=[plist[@"uuid"] isKindOfClass:NSString.class]?plist[@"uuid"]:NSUUID.UUID.UUIDString;_epoch=NSUUID.UUID.UUIDString;[_resources removeAllObjects];[_identifiers removeAllObjects];[_playlistLinks removeAllObjects];[_playlistTimes removeAllObjects];[_inflight removeAllObjects];[_retiredLinks removeAllObjects];[_selectedPlaylists removeAllObjects];[_cache removeAllObjects];[_pending removeAllObjects];[_prefetch removeAllObjects];[_ready broadcast];[_ready unlock];
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
            if(valid){NSInteger code=params[@"FCUP_Response_StatusCode"]?[params[@"FCUP_Response_StatusCode"] integerValue]:200;
                // Some YouTube FCUP completions use status 0 for a delivered
                // playlist. Promote only a validated HLS body, never an empty,
                // non-playlist, or actual HTTP failure response.
                code=SLFCUPPlaylistStatus(code,data);
                _cache[location]=@{@"data":data?:[NSData data],@"code":@(code),@"time":@(NSProcessInfo.processInfo.systemUptime)};[_pending removeObjectForKey:location];[_ready broadcast];}[_ready unlock];
            [self reply:response status:valid?200:409 type:nil data:nil];if(!valid)[self log:@"MEDIA PLAYLIST RESPONSE REJECTED: session, URL, or request ID did not match an outstanding request."];if(valid){[self log:[NSString stringWithFormat:@"MEDIA PLAYLIST RESPONSE: %lu bytes received; sender status %@. Status 0 requires a valid HLS playlist.",(unsigned long)data.length,params[@"FCUP_Response_StatusCode"]?:@200]];[self recordSourceHeights:data location:location epoch:nil];[self prefetchChildren:data base:location];[self drivePrefetch];}return YES;
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
    [_ready lock];NSString *location=_resources[identifier],*epoch=_epoch;
    if(location){
        _inflight[identifier]=@([_inflight[identifier] unsignedIntegerValue]+1);
        for(NSString *owner in _playlistLinks)if([_playlistLinks[owner] containsObject:identifier]){
            _playlistTimes[owner]=@(NSProcessInfo.processInfo.systemUptime);
            if(![owner isEqual:_primary]){[_selectedPlaylists removeObject:owner];[_selectedPlaylists addObject:owner];while(_selectedPlaylists.count>4)[_selectedPlaylists removeObjectAtIndex:0];}
        }
    }
    [_ready unlock];if(!location)return @{@"code":@404};
    @try {
    NSURL *url=[NSURL URLWithString:location];NSData *data=nil;NSInteger code=200;NSString *mime=nil,*contentRange=nil;
    if(virtualURL(url)){
        [_ready lock];NSDictionary *cached=_cache[location];BOOL fresh=cached && ([cached[@"code"] integerValue]==200) && (stablePlaylist(cached[@"data"]) || NSProcessInfo.processInfo.systemUptime-[cached[@"time"] doubleValue]<2);[_ready unlock];
        if(!fresh)[self requestURL:location];
        [_ready lock];NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:15];while([epoch isEqual:_epoch] && _active && _pending[location])if(![_ready waitUntilDate:deadline])break;
        cached=[epoch isEqual:_epoch]?_cache[location]:nil;data=cached[@"data"];code=cached?[cached[@"code"] integerValue]:504;// requestURL owns the shared request lifetime. A timed-out browser/PiP waiter
        // must not cancel another waiter or a new epoch request for the same URL.
        [_ready unlock];mime=@"application/vnd.apple.mpegurl";
    }else if(webURL(url)){
        NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];[request setValue:@"AppleCoreMedia/1.0 ScreenLink" forHTTPHeaderField:@"User-Agent"];
        if(range.length<128 && [range hasPrefix:@"bytes="] && [range rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location==NSNotFound)[request setValue:range forHTTPHeaderField:@"Range"];
#if SL_BROADCAST_EXTENSION
        NSUInteger budget=6*1024*1024;
#else
        NSUInteger budget=32*1024*1024;
#endif
        NSDictionary *download=SLBoundedDownload(request,budget);data=download[@"data"];code=[download[@"code"] integerValue];mime=download[@"mime"];contentRange=download[@"range"];
    }else return @{@"code":@400};
    if(code<200 || code>=300 || !data.length){[self log:[NSString stringWithFormat:@"MEDIA RESOURCE FAILED: HTTP %ld from %@, %lu bytes. No signed URLs are included in this log.",(long)code,url.host?:@"sender",(unsigned long)data.length]];return @{@"code":@(code>=400?code:502)};}
    NSString *text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    if([text hasPrefix:@"#EXTM3U"]){
        [self recordSourceHeights:data location:location epoch:epoch];
        NSInteger rewriteCode;NSString *rewritten=[self rewrite:text base:url owner:location epoch:epoch code:&rewriteCode];
        if(!rewritten)return @{@"code":@(rewriteCode)};
        data=[rewritten dataUsingEncoding:NSUTF8StringEncoding];mime=@"application/vnd.apple.mpegurl";
    }
    [_ready lock];BOOL current=[epoch isEqual:_epoch];[_ready unlock];if(!current)return @{@"code":@410};
    NSMutableDictionary *result=[@{@"code":@(code),@"data":data,@"mime":mime?:@"application/octet-stream"} mutableCopy];if(contentRange)result[@"range"]=contentRange;return result;
    } @finally {
        [_ready lock];if([epoch isEqual:_epoch]){NSUInteger n=[_inflight[identifier] unsignedIntegerValue];if(n>1)_inflight[identifier]=@(n-1);else [_inflight removeObjectForKey:identifier];}[_ready unlock];
    }
}
@end
