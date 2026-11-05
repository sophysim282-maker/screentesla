#import "YouTubePiP.h"
#import <math.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
@interface YouTubePiP () <AVPictureInPictureControllerDelegate>
@property(nonatomic,strong) AVPlayer *player;
@property(nonatomic,strong) AVPictureInPictureController *pip;
@property(nonatomic,copy) NSString *epoch;
@property(nonatomic) BOOL requested;
@property(nonatomic) BOOL attempting;
@property(nonatomic) BOOL sourceMissing;
@property(nonatomic) BOOL sourcePaused;
@property(nonatomic) NSUInteger generation,recoveryCount;
@property(nonatomic,strong) NSMutableArray *itemObservers;
@property(nonatomic) BOOL interrupted;
@end
@implementation YouTubePiP
+ (Class)layerClass {return AVPlayerLayer.class;}
- (AVPlayerLayer *)playerLayer {return (AVPlayerLayer *)self.layer;}
- (BOOL)active {return self.pip.pictureInPictureActive;}
- (void)report:(NSString *)text {if(self.status)self.status(text);}
- (void)clearItemObservers {
 for(id token in self.itemObservers)[NSNotificationCenter.defaultCenter removeObserver:token];self.itemObservers=nil;
}
- (void)observeItem:(AVPlayerItem *)item {
 [self clearItemObservers];self.itemObservers=[NSMutableArray array];
 __weak YouTubePiP *weak=self;NSString *epoch=self.epoch;NSUInteger generation=self.generation;
 for(NSString *name in @[AVPlayerItemPlaybackStalledNotification,AVPlayerItemFailedToPlayToEndTimeNotification,AVPlayerItemDidPlayToEndTimeNotification]){
  id token=[NSNotificationCenter.defaultCenter addObserverForName:name object:item queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){
   YouTubePiP *owner=weak;if(!owner||generation!=owner.generation||![epoch isEqual:owner.epoch]||owner.player.currentItem!=item)return;
   if([note.name isEqual:AVPlayerItemDidPlayToEndTimeNotification]){[owner report:@"PiP real media reached its end; no substitute video or automatic reopening."];return;}
   NSError *error=note.userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey];
   [owner report:[NSString stringWithFormat:@"PiP real-media %@: item status %ld, error code %ld. Receiver remains armed.",[note.name isEqual:AVPlayerItemPlaybackStalledNotification]?@"stalled":@"failed",(long)item.status,(long)error.code]];
   if(!owner.active||owner.sourcePaused||owner.sourceMissing||owner.interrupted||owner.recoveryCount>=2)return;
   owner.recoveryCount++;
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
    YouTubePiP *view=weak;if(!view||generation!=view.generation||![epoch isEqual:view.epoch]||view.player.currentItem!=item||!view.active||view.sourcePaused||view.sourceMissing||view.interrupted)return;
    // Only retry the existing real-media source while PiP remains active.
    // Dismissal can never create a new PiP presentation.
    if(item.status==AVPlayerItemStatusFailed){
     NSURL *url=[item.asset isKindOfClass:AVURLAsset.class]?[(AVURLAsset *)item.asset URL]:nil;if(!url)return;
     AVPlayerItem *replacement=[AVPlayerItem playerItemWithURL:url];replacement.preferredMaximumResolution=CGSizeMake(1280,720);replacement.preferredPeakBitRate=6000000;
     [view.player replaceCurrentItemWithPlayerItem:replacement];[view observeItem:replacement];
    }
    [view.player play];
   });
  }];[self.itemObservers addObject:token];
 }
 id token=[NSNotificationCenter.defaultCenter addObserverForName:AVAudioSessionInterruptionNotification object:AVAudioSession.sharedInstance queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){
  YouTubePiP *owner=weak;if(!owner||generation!=owner.generation||![epoch isEqual:owner.epoch])return;
  owner.interrupted=[note.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue]==AVAudioSessionInterruptionTypeBegan;
  [owner report:owner.interrupted?@"PiP audio session interrupted.":@"PiP audio interruption ended."];
  if(!owner.interrupted&&([note.userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue]&AVAudioSessionInterruptionOptionShouldResume)&&owner.active&&!owner.sourcePaused&&!owner.sourceMissing){
   if([AVAudioSession.sharedInstance setActive:YES error:NULL])[owner.player play];
  }
 }];[self.itemObservers addObject:token];
}
- (void)dealloc {[self clearItemObservers];}
- (void)updateState:(NSDictionary *)state {
 if(![state[@"active"] boolValue]){if(self.player){[self.player pause];self.sourcePaused=YES;if(!self.sourceMissing)[self report:@"PiP source waiting for the next YouTube item. No screen recording or replacement video is started. iOS may stop PiP if media ends."];self.sourceMissing=YES;}return;}
 self.sourceMissing=NO;
 NSString *epoch=state[@"epoch"],*path=state[@"url"];
 if(![epoch isKindOfClass:NSString.class]||![path hasPrefix:@"/media/resource/"])return;
 BOOL replaced=![self.epoch isEqual:epoch];
 if(replaced){
  self.epoch=epoch;self.recoveryCount=0;self.interrupted=NO;
  NSURL *url=[NSURL URLWithString:[@"http://localhost:8080" stringByAppendingString:path]];
  AVPlayerItem *item=[AVPlayerItem playerItemWithURL:url];item.preferredMaximumResolution=CGSizeMake(1280,720);item.preferredPeakBitRate=6000000;
  if(self.player)[self.player replaceCurrentItemWithPlayerItem:item];else self.player=[AVPlayer playerWithPlayerItem:item];self.player.muted=YES;self.player.allowsExternalPlayback=NO;self.player.automaticallyWaitsToMinimizeStalling=YES;
  [self observeItem:item];
  self.playerLayer.player=self.player;self.playerLayer.videoGravity=AVLayerVideoGravityResizeAspect;
  if(!self.pip&&AVPictureInPictureController.isPictureInPictureSupported)self.pip=[[AVPictureInPictureController alloc]initWithPlayerLayer:self.playerLayer];self.pip.delegate=self;self.pip.canStartPictureInPictureAutomaticallyFromInline=NO;
 }
 BOOL paused=[state[@"paused"] boolValue];
 if(!self.interrupted&&(replaced||paused!=self.sourcePaused)){if(paused)[self.player pause];else [self.player play];}self.sourcePaused=paused;
 double position=[state[@"position"] doubleValue],current=CMTimeGetSeconds(self.player.currentTime);
 if(isfinite(current)&&fabs(current-position)>5)[self.player seekToTime:CMTimeMakeWithSeconds(position,600) toleranceBefore:CMTimeMakeWithSeconds(.5,600) toleranceAfter:CMTimeMakeWithSeconds(.5,600)];
 [self beginIfReady];
}
- (void)startFloating {
 if(self.active)return;
 if(!AVPictureInPictureController.isPictureInPictureSupported){[self report:@"YouTube PiP is unavailable on this device. Receiver retained; no recording starts."];return;}
 self.requested=YES;
 if(!self.player.currentItem){[self report:@"PiP REQUEST SAVED: open YouTube, select ScreenLink VPN Phone through AirPlay, then return to ScreenLink. Its real video will prepare PiP here. No screen recording and no dummy video are used."];return;}
 [self beginIfReady];
}
- (void)beginIfReady {
 if(!self.requested||self.attempting||self.active||!self.player.currentItem||self.sourceMissing)return;
 // The user's PiP request may precede AirPlay. Keep it pending while outside
 // ScreenLink; do not try to present PiP behind another foreground app.
 if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
 NSError *error=nil;AVAudioSession *audio=AVAudioSession.sharedInstance;
 if(![audio setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeMoviePlayback options:AVAudioSessionCategoryOptionMixWithOthers error:&error]||![audio setActive:YES error:&error]){self.requested=NO;self.attempting=NO;[self report:@"YouTube PiP audio session unavailable. Receiver retained; copy the test log."];return;}
 self.attempting=YES;if(!self.sourcePaused)[self.player play];[self attempt:30 generation:self.generation];
}
- (void)attempt:(NSUInteger)remaining generation:(NSUInteger)generation {
 if(generation!=self.generation||!self.requested||self.active)return;
 if(self.sourceMissing){self.attempting=NO;return;}
 if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive){self.attempting=NO;return;}
 if(self.player.currentItem.status==AVPlayerItemStatusFailed){self.requested=NO;self.attempting=NO;[self report:@"YouTube PiP could not load the local HLS preview. Receiver retained; copy test log."];return;}
 if(self.pip.pictureInPicturePossible){[self.pip startPictureInPicture];return;}
 if(!remaining){self.requested=NO;self.attempting=NO;[self report:@"PiP is not ready. Keep ScreenLink visible, verify live YouTube, then retry PiP."];return;}
 __weak YouTubePiP *weak=self;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.3*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[weak attempt:remaining-1 generation:generation];});
}
- (void)reset {[self clearItemObservers];self.generation++;self.requested=NO;self.attempting=NO;self.sourceMissing=NO;self.pip.delegate=nil;[self.pip stopPictureInPicture];self.pip=nil;[self.player pause];self.playerLayer.player=nil;self.player=nil;self.epoch=nil;}
- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)controller {self.requested=NO;self.attempting=NO;[self report:@"YOUTUBE PiP ACTIVE: real received YouTube preview, no screen recording. You may switch apps. You can move or resize this ScreenLink window. Closing or pausing PiP can end background playback; iOS still controls runtime."];if(self.activityChanged)self.activityChanged(YES);}
- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)controller {self.requested=NO;self.attempting=NO;[self.player pause];[self report:@"YouTube PiP closed. Return to ScreenLink to continue; background runtime is no longer assured."];if(self.activityChanged)self.activityChanged(NO);}
- (void)pictureInPictureController:(AVPictureInPictureController *)controller failedToStartPictureInPictureWithError:(NSError *)error {self.requested=NO;self.attempting=NO;[self report:[@"YouTube PiP failed: " stringByAppendingString:error.localizedDescription?:@"unknown"]];if(self.activityChanged)self.activityChanged(NO);}
- (void)pictureInPictureController:(AVPictureInPictureController *)controller restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL))completion {completion(YES);}
@end
