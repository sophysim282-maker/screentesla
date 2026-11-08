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
 CHECK([c performWidgetAction:@"hd720" media:media]);
 CHECK([[c snapshotForMedia:media][@"quality"] isEqual:@"720"]);
 CHECK([c performWidgetAction:@"auto" media:media]);
 CHECK([[c snapshotForMedia:media][@"quality"] isEqual:@"auto"]);
 CHECK([c performWidgetAction:@"hd1080" media:media]);
 CHECK([[c snapshotForMedia:media][@"quality"] isEqual:@"1080"]);
 CHECK([c performWidgetAction:@"music" media:media]);
 CHECK([[c snapshotForMedia:media][@"eq"] isEqual:@"music"]);
 CHECK([c performWidgetAction:@"normalSound" media:media]);
 CHECK([[c snapshotForMedia:media][@"eq"] isEqual:@"normal"]);
 CHECK([c update:@{@"volume":@0.4} media:media]);
 CHECK([c performWidgetAction:@"toggleMute" media:media]);
 CHECK([[c snapshotForMedia:media][@"volume"] doubleValue]==0);
 CHECK([c performWidgetAction:@"toggleMute" media:media]);
 CHECK([[c snapshotForMedia:media][@"volume"] doubleValue]==.4);
 for(int i=0;i<12;i++)CHECK([c performWidgetAction:@"volumeUp" media:media]);
 CHECK([[c snapshotForMedia:media][@"volume"] doubleValue]==1);
 for(int i=0;i<12;i++)CHECK([c performWidgetAction:@"volumeDown" media:media]);
 CHECK([[c snapshotForMedia:media][@"volume"] doubleValue]==0);
 CHECK(![c performWidgetAction:@"playPause" media:media]);
 CHECK(![c performWidgetAction:@"forward" media:media]);
 CHECK(![c performWidgetAction:@"start" media:media]);
 media[@"active"]=@YES;media[@"paused"]=@NO;media[@"position"]=@99;
 CHECK([c performWidgetAction:@"playPause" media:media]);
 CHECK([[c snapshotForMedia:media][@"playback"][@"paused"] boolValue]);
 CHECK([c performWidgetAction:@"playPause" media:media]);
 CHECK(![[c snapshotForMedia:media][@"playback"][@"paused"] boolValue]);
 CHECK([c performWidgetAction:@"forward" media:media]);
 CHECK([c performWidgetAction:@"forward" media:media]);
 CHECK([[c snapshotForMedia:media][@"playback"][@"seek"] doubleValue]==119);
 CHECK([c performWidgetAction:@"forward" media:media]);
 CHECK([[c snapshotForMedia:media][@"playback"][@"seek"] doubleValue]==120);
 CHECK([c performWidgetAction:@"back" media:media]);
 CHECK([[c snapshotForMedia:media][@"playback"][@"seek"] doubleValue]==110);
 media[@"epoch"]=@"three";
 CHECK(![c snapshotForMedia:media][@"playback"]);
 puts("PHONE_AND_WIDGET_CONTROLS_PASSED: presets, volume bounds, mute restore, rapid taps, seek clamp, command leases and acknowledgements.");
}return 0;}
