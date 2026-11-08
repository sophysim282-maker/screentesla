#import <Foundation/Foundation.h>
#import "ViewerControls.h"
#include <assert.h>
int main(void){@autoreleasepool{
 ViewerControls *c=[ViewerControls new];NSMutableDictionary *media=[@{@"active":@YES,@"epoch":@"one",@"command":@3,@"duration":@120} mutableCopy];
 assert([[c snapshotForMedia:media][@"quality"] isEqual:@"auto"]);
 assert([c update:@{@"quality":@"720",@"volume":@0.3,@"eq":@"music"} media:media]);NSDictionary *state=[c snapshotForMedia:media];assert([state[@"quality"] isEqual:@"720"]&&[state[@"volume"] doubleValue]==.3);
 NSUInteger revision=[state[@"revision"] unsignedIntegerValue];assert(![c update:@{@"volume":@2,@"quality":@"1080"} media:media]);assert([[c snapshotForMedia:media][@"revision"] unsignedIntegerValue]==revision);assert([[c snapshotForMedia:media][@"quality"] isEqual:@"720"]); // atomic validation
 for(NSDictionary *bad in @[@{@"quality":@"4k"},@{@"volume":@YES},@{@"volume":@(-1)},@{@"paused":@1},@{@"seek":@(-1)},@{@"seek":@"20"},@{@"unknown":@1},@{}])assert(![c update:bad media:media]);
 assert([c update:@{@"paused":@YES} media:media]);NSDictionary *pause=[c snapshotForMedia:media][@"playback"];assert([pause[@"paused"] boolValue]);
 assert([c update:@{@"seek":@200} media:media]);NSDictionary *seek=[c snapshotForMedia:media][@"playback"];assert([seek[@"seek"] doubleValue]==120&&[seek[@"paused"] boolValue]);assert([seek[@"revision"] unsignedIntegerValue]>[pause[@"revision"] unsignedIntegerValue]);
 [c acknowledge:@{@"epoch":@"wrong",@"command":@3,@"viewerPlaybackRevision":seek[@"revision"]}];assert([c snapshotForMedia:media][@"playback"]);
 [c acknowledge:@{@"epoch":@"one",@"command":@3,@"viewerPlaybackRevision":pause[@"revision"]}];assert([c snapshotForMedia:media][@"playback"]); // stale ACK cannot clear newer command
 [c acknowledge:@{@"epoch":@"one",@"command":@3,@"viewerPlaybackRevision":seek[@"revision"]}];assert(![c snapshotForMedia:media][@"playback"]); // reload won't repeat old seek
 assert([c update:@{@"paused":@NO} media:media]);media[@"command"]=@4;assert(![c snapshotForMedia:media][@"playback"]); // newer YouTube action wins
 assert([c update:@{@"seek":@20} media:media]);media[@"epoch"]=@"two";assert(![c snapshotForMedia:media][@"playback"]); // old video's controls never reach a new video
 media[@"active"]=@NO;assert(![c update:@{@"paused":@YES} media:media]);assert([c update:@{@"quality":@"1080",@"volume":@0} media:media]);assert([[c snapshotForMedia:media][@"quality"] isEqual:@"1080"]);
 puts("PHONE_VIEWER_CONTROLS_PASSED: atomic bounded settings, volume zero, seek clamp, merged commands, exact epoch/source lease, stale ACK isolation, no seek replay, newer YouTube command precedence, settings retained across videos.");
}return 0;}
