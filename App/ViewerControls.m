#import "ViewerControls.h"
#import <math.h>
@interface ViewerControls ()
@property(nonatomic,copy) NSString *quality,*eq;
@property(nonatomic) double volume;
@property(nonatomic) double lastAudibleVolume;
@property(nonatomic) NSUInteger revision,playbackRevision;
@property(nonatomic,copy) NSDictionary *pending;
@end
static BOOL number(id value){return [value isKindOfClass:NSNumber.class]&&CFGetTypeID((__bridge CFTypeRef)value)!=CFBooleanGetTypeID()&&isfinite([value doubleValue]);}
@implementation ViewerControls
- (instancetype)init{if((self=[super init])){_quality=@"auto";_eq=@"normal";_volume=1;_lastAudibleVolume=1;}return self;}
- (BOOL)update:(NSDictionary *)request media:(NSDictionary *)media{ @synchronized(self){
 if(![request isKindOfClass:NSDictionary.class]||!request.count)return NO;
 for(id key in request)if(![@[@"quality",@"volume",@"eq",@"paused",@"seek"] containsObject:key])return NO;
 if(request[@"quality"]&&![@[@"auto",@"720",@"1080",@"1440",@"2160"] containsObject:request[@"quality"]])return NO;
 if(request[@"eq"]&&![@[@"normal",@"music"] containsObject:request[@"eq"]])return NO;
 if(request[@"volume"]&&(!number(request[@"volume"])||[request[@"volume"] doubleValue]<0||[request[@"volume"] doubleValue]>1))return NO;
 if(request[@"paused"]&&(![request[@"paused"] isKindOfClass:NSNumber.class]||CFGetTypeID((__bridge CFTypeRef)request[@"paused"])!=CFBooleanGetTypeID()))return NO;
 if(request[@"seek"]&&(!number(request[@"seek"])||[request[@"seek"] doubleValue]<0||[request[@"seek"] doubleValue]>1e7))return NO;
 BOOL playback=request[@"paused"]||request[@"seek"];
 if(playback&&(![media[@"active"] boolValue]||![media[@"epoch"] isKindOfClass:NSString.class]||![media[@"epoch"] length]))return NO;
 if(request[@"quality"])self.quality=request[@"quality"];
 if(request[@"volume"]){
  self.volume=[request[@"volume"] doubleValue];
  if(self.volume>0)self.lastAudibleVolume=self.volume;
 }
 if(request[@"eq"])self.eq=request[@"eq"];
 self.revision++;
 if(playback){
  NSMutableDictionary *command=[@{@"revision":@(++_playbackRevision),@"epoch":media[@"epoch"],@"sourceCommand":media[@"command"]?:@0} mutableCopy];
  if([self.pending[@"epoch"] isEqual:media[@"epoch"]]&&[self.pending[@"sourceCommand"] isEqual:media[@"command"]?:@0])for(NSString *key in @[@"paused",@"seek"])if(self.pending[key])command[key]=self.pending[key];
  if(request[@"paused"])command[@"paused"]=request[@"paused"];
  if(request[@"seek"]){double duration=[media[@"duration"] doubleValue];command[@"seek"]=@(duration>0?MIN(duration,[request[@"seek"] doubleValue]):[request[@"seek"] doubleValue]);}
  self.pending=command;
 }
 return YES;
} }
- (BOOL)performWidgetAction:(NSString *)action media:(NSDictionary *)media {
 if(![action isKindOfClass:NSString.class])return NO;
 @synchronized(self){
  if([action isEqualToString:@"auto"])return [self update:@{@"quality":@"auto"} media:media];
  if([action isEqualToString:@"hd720"])return [self update:@{@"quality":@"720"} media:media];
  if([action isEqualToString:@"hd1080"])return [self update:@{@"quality":@"1080"} media:media];
  if([action isEqualToString:@"normalSound"])return [self update:@{@"eq":@"normal"} media:media];
  if([action isEqualToString:@"music"])return [self update:@{@"eq":@"music"} media:media];
  if([action isEqualToString:@"toggleMute"]){
   double volume=self.volume>0?0:self.lastAudibleVolume;
   return [self update:@{@"volume":@(volume)} media:media];
  }
  if([action isEqualToString:@"volumeUp"]||[action isEqualToString:@"volumeDown"]){
   double step=[action isEqualToString:@"volumeUp"]?.1:-.1;
   double volume=round((self.volume+step)*100)/100;
   return [self update:@{@"volume":@(MAX(0,MIN(1,volume)))} media:media];
  }

  NSDictionary *pending=[self snapshotForMedia:media][@"playback"];
  if([action isEqualToString:@"playPause"]){
   BOOL paused=[(pending[@"paused"]?:media[@"paused"]) boolValue];
   return [self update:@{@"paused":[NSNumber numberWithBool:!paused]} media:media];
  }
  if([action isEqualToString:@"back"]||[action isEqualToString:@"forward"]){
   double duration=[media[@"duration"] doubleValue];
   if(!isfinite(duration)||duration<=0)return NO;
   double position=[(pending[@"seek"]?:media[@"position"]) doubleValue];
   double offset=[action isEqualToString:@"forward"]?10:-10;
   return [self update:@{@"seek":@(MAX(0,MIN(duration,position+offset)))} media:media];
  }
  return NO;
 }
}
- (NSDictionary *)snapshotForMedia:(NSDictionary *)media{ @synchronized(self){
 if(self.pending&&(![media[@"active"] boolValue]||![self.pending[@"epoch"] isEqual:media[@"epoch"]]||![self.pending[@"sourceCommand"] isEqual:media[@"command"]?:@0]))self.pending=nil;
 NSMutableDictionary *state=[@{@"quality":self.quality,@"volume":@(self.volume),@"eq":self.eq,@"revision":@(self.revision)} mutableCopy];
 if(self.pending)state[@"playback"]=self.pending;return state;
} }
- (void)acknowledge:(NSDictionary *)report{ @synchronized(self){
 if(self.pending&&[report[@"epoch"] isEqual:self.pending[@"epoch"]]&&[report[@"command"] isEqual:self.pending[@"sourceCommand"]]&&[report[@"viewerPlaybackRevision"] unsignedIntegerValue]==[self.pending[@"revision"] unsignedIntegerValue])self.pending=nil;
} }
@end
