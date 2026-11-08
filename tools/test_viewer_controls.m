#import <Foundation/Foundation.h>
#import "ViewerControls.h"
#include <assert.h>
#define CHECK(...) assert((__VA_ARGS__))
int main(void){@autoreleasepool{
 ViewerControls *c=[ViewerControls new];NSMutableDictionary *media=[@{@"active":@YES,@"epoch":@"one",@"command":@3,@"duration":@120} mutableCopy];
 CHECK([[c snapshotForMedia:media][@"quality"] isEqual:@"auto"]);
 CHECK([c update:@{@"quality":@"720",@"volume":@0.3,@"eq":@"music"} media:media]);NSDictionary *state=[c snapshotForMedia:media];CHECK([state[@"quality"] isEqual:@"720"]&&[state[@"volume"] doubleValue]==.3);
 NSUInteger revision=[state[@"revision"] unsignedIntegerValue];CHECK(![c update:@{@"volume":@2,@"quality":@"1080"} media:media]);CHECK([[c snapshotForMedia:media][@"revision"] unsignedIntegerValue]==revision);CHECK([[c snapshotForMedia:media][@"quality"] isEqual:@"720"]); // atomic validation
 for(NSDictionary *bad in @[@{@"quality":@"4k"},@{@"volume":@YES},@{@"volume":@(-1)},@{@"paused":@1},@{@"seek":@(-1)},@{@"seek":@"20"},@{@"unknown":@1},@{}])CHECK(![c update:bad media:media]);
 CHECK([c update:@{@"paused":@YES} media:media]);NSDictionary *pause=[c snapshotForMedia:media][@"playback"];CHECK([pause[@"paused"] boolValue]);
 CHECK([c update:@{@"seek":@200} media:media]);NSDictionary *seek=[c snapshotForMedia:media][@"playback"];CHECK([seek[@"seek"] doubleValue]==120&&[seek[@"paused"] boolValue]);CHECK([seek[@"revision"] unsignedIntegerValue]>[pause[@"revision"] unsignedIntegerValue]);
 [c acknowledge:@{@"epoch":@"wrong",@"command":@3,@"viewerPlaybackRevision":seek[@"revision"]}];CHECK([c snapshotForMedia:media][@"playback"]);
 [c acknowledge:@{@"epoch":@"one",@"command":@3,@"viewerPlaybackRevision":pause[@"revision"]}];CHECK([c snapshotForMedia:media][@"playback"]); // stale ACK cannot clear newer command
 [c acknowledge:@{@"epoch":@"one",@"command":@3,@"viewerPlaybackRevision":seek[@"revision"]}];CHECK(![c snapshotForMedia:media][@"playback"]); // reload won't repeat old seek
 CHECK([c update:@{@"paused":@NO} media:media]);media[@"command"]=@4;CHECK(![c snapshotForMedia:media][@"playback"]); // newer YouTube action wins
 CHECK([c update:@{@"seek":@20} media:media]);media[@"epoch"]=@"two";CHECK(![c snapshotForMedia:media][@"playback"]); // old video's controls never reach a new video
 media[@"active"]=@NO;CHECK(![c update:@{@"paused":@YES} media:media]);CHECK([c update:@{@"quality":@"1080",@"volume":@0} media:media]);CHECK([[c snapshotForMedia:media][@"quality"] isEqual:@"1080"]);
 puts("PHONE_VIEWER_CONTROLS_PASSED: atomic bounded settings, volume zero, seek clamp, merged commands, exact epoch/source lease, stale ACK isolation, no seek replay, newer YouTube command precedence, settings retained across videos.");
}return 0;}
