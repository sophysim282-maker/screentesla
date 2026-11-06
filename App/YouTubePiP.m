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
@property(nonatomic) BOOL interrupted,seekInFlight;
@property(nonatomic) double lastSeek;
@property(nonatomic,copy) NSURL *sourceURL;
@property(nonatomic) BOOL failedPlayback,recoveryScheduled;
@end
@implementation YouTubePiP
+ (Class)layerClass {return AVPlayerLayer.class;}
- (AVPlayerLayer *)playerLayer {return (AVPlayerLayer *)self.layer;}
- (BOOL)active {return self.pip.pictureInPictureActive;}
- (BOOL)pipSupported {return AVPictureInPictureController.isPictureInPictureSupported;}
- (BOOL)appIsActive {return UIApplication.sharedApplication.applicationState==UIApplicationStateActive;}
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
   if([note.name isEqual:AVPlayerItemFailedToPlayToEndTimeNotification])owner.failedPlayback=YES;
   [owner scheduleRealMediaRecovery];

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
- (void)installItemAtURL:(NSURL *)url {
 if(!url)return;self.generation++;self.recoveryScheduled=NO;self.attempting=NO;
 self.sourceURL=url;self.failedPlayback=NO;self.seekInFlight=NO;
 AVPlayerItem *item=[AVPlayerItem playerItemWithURL:url];
 item.preferredMaximumResolution=CGSizeMake(1280,720);item.preferredPeakBitRate=6000000;
 if(!self.player||self.player.status==AVPlayerStatusFailed){
  [self.player pause];self.player=[AVPlayer playerWithPlayerItem:item];
 }else [self.player replaceCurrentItemWithPlayerItem:item];
 self.player.muted=YES;self.player.allowsExternalPlayback=NO;self.player.automaticallyWaitsToMinimizeStalling=YES;
 [self observeItem:item];
 self.playerLayer.player=self.player;self.playerLayer.videoGravity=AVLayerVideoGravityResizeAspect;
 if(!self.pip&&AVPictureInPictureController.isPictureInPictureSupported)self.pip=[[AVPictureInPictureController alloc]initWithPlayerLayer:self.playerLayer];
 self.pip.delegate=self;self.pip.canStartPictureInPictureAutomaticallyFromInline=NO;
}
- (void)scheduleRealMediaRecovery {
 if(self.recoveryScheduled||self.sourcePaused||self.sourceMissing||self.interrupted||self.recoveryCount>=2||!self.sourceURL)return;
 // Background repair may keep an existing presentation alive. A stopped
 // presentation is only requested again on explicit start or foreground return.
 if(!self.active&&!(self.requested&&[self appIsActive]))return;
 self.recoveryScheduled=YES;self.recoveryCount++;
 NSUInteger generation=self.generation;NSString *epoch=self.epoch;AVPlayerItem *item=self.player.currentItem;__weak YouTubePiP *weak=self;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
  YouTubePiP *owner=weak;if(!owner||generation!=owner.generation||![epoch isEqual:owner.epoch]||owner.player.currentItem!=item)return;
  owner.recoveryScheduled=NO;
  if(owner.sourcePaused||owner.sourceMissing||owner.interrupted||(!owner.active&&!(owner.requested&&[owner appIsActive])))return;
  if(owner.failedPlayback||item.status==AVPlayerItemStatusFailed||owner.player.status==AVPlayerStatusFailed){
   [owner installItemAtURL:owner.sourceURL];[owner report:@"PiP RECOVERY: replaced failed real-media preview; receiver and viewer session preserved."];
  }
  [owner.player play];owner.attempting=NO;[owner beginIfReady];
 });
}
- (void)resumeAfterForeground {
 if(![self appIsActive]||self.active)return;
 self.recoveryCount=0;
 // Returning to the app resumes the previously selected YouTube + PiP mode.
 // Reset/Disconnect All clears the mode in the controller and cancels callbacks.
 [self startFloating];
}
- (void)dealloc {[self clearItemObservers];}
- (void)updateState:(NSDictionary *)state {
 if(![state[@"active"] boolValue]){if(self.player){[self.player pause];self.sourcePaused=YES;if(!self.sourceMissing)[self report:@"PiP source waiting for the next YouTube item. No screen recording or replacement video is started. iOS may stop PiP if media ends."];self.sourceMissing=YES;}return;}
 self.sourceMissing=NO;
 NSString *epoch=state[@"epoch"],*path=state[@"url"];
 if(![epoch isKindOfClass:NSString.class]||![path hasPrefix:@"/media/resource/"])return;
 BOOL replaced=![self.epoch isEqual:epoch];
 if(replaced){
  self.generation++;self.recoveryScheduled=NO;self.attempting=NO;self.epoch=epoch;self.recoveryCount=0;self.interrupted=NO;self.seekInFlight=NO;self.lastSeek=0;
  NSURL *url=[NSURL URLWithString:[@"http://127.0.0.1:8080" stringByAppendingString:path]];
  [self installItemAtURL:url];
 }
 BOOL paused=[state[@"paused"] boolValue];
 if(!self.interrupted&&(replaced||paused!=self.sourcePaused)){if(paused)[self.player pause];else [self.player play];}self.sourcePaused=paused;
 double position=[state[@"position"] doubleValue],current=CMTimeGetSeconds(self.player.currentTime);
 double now=NSProcessInfo.processInfo.systemUptime;
 if(isfinite(current)&&isfinite(position)&&position>=0&&fabs(current-position)>5&&!self.seekInFlight&&now-self.lastSeek>3&&self.player.currentItem.status==AVPlayerItemStatusReadyToPlay){
  self.seekInFlight=YES;self.lastSeek=now;NSUInteger generation=self.generation;NSString *epoch=self.epoch;__weak YouTubePiP *weak=self;
  [self.player seekToTime:CMTimeMakeWithSeconds(position,600) toleranceBefore:CMTimeMakeWithSeconds(.5,600) toleranceAfter:CMTimeMakeWithSeconds(.5,600) completionHandler:^(BOOL finished){
   dispatch_async(dispatch_get_main_queue(),^{YouTubePiP *owner=weak;if(owner&&generation==owner.generation&&[epoch isEqual:owner.epoch])owner.seekInFlight=NO;});
  }];
 }
 [self beginIfReady];
}
- (void)startFloating {
 if(self.active)return;
 if(![self pipSupported]){[self report:@"YouTube PiP is unavailable on this device. Receiver retained; no recording starts."];return;}
 self.recoveryCount=0;self.requested=YES;
 if(self.failedPlayback||self.player.currentItem.status==AVPlayerItemStatusFailed||self.player.status==AVPlayerStatusFailed){[self scheduleRealMediaRecovery];return;}
 if(!self.player.currentItem){[self report:@"PiP REQUEST SAVED: open YouTube, select ScreenLink VPN Phone through AirPlay, then return to ScreenLink. Its real video will prepare PiP here. No screen recording and no dummy video are used."];return;}
 [self beginIfReady];
}
- (void)beginIfReady {
 if(!self.requested||self.attempting||self.active||!self.player.currentItem||self.sourceMissing)return;
 // The user's PiP request may precede AirPlay. Keep it pending while outside
 // ScreenLink; do not try to present PiP behind another foreground app.
 if(![self appIsActive])return;
 NSError *error=nil;AVAudioSession *audio=AVAudioSession.sharedInstance;
 if(![audio setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeMoviePlayback options:AVAudioSessionCategoryOptionMixWithOthers error:&error]||![audio setActive:YES error:&error]){self.requested=NO;self.attempting=NO;[self report:@"YouTube PiP audio session unavailable. Receiver retained; copy the test log."];return;}
 self.attempting=YES;if(!self.sourcePaused)[self.player play];[self attempt:30 generation:self.generation];
}
- (void)attempt:(NSUInteger)remaining generation:(NSUInteger)generation {
 if(generation!=self.generation||!self.requested||self.active)return;
 if(self.sourceMissing){self.attempting=NO;return;}
 if(![self appIsActive]){self.attempting=NO;return;}
 if(self.failedPlayback||self.player.currentItem.status==AVPlayerItemStatusFailed||self.player.status==AVPlayerStatusFailed){
  self.attempting=NO;[self scheduleRealMediaRecovery];
  if(self.recoveryCount>=2&&!self.recoveryScheduled){self.requested=NO;[self report:@"PiP recovery paused after two real-source retries. Return to ScreenLink or tap Start + PiP to retry."];}
  return;
 }
 if(self.pip.pictureInPicturePossible){[self.pip startPictureInPicture];return;}
 if(!remaining){self.requested=NO;self.attempting=NO;[self report:@"PiP is not ready. Keep ScreenLink visible, verify live YouTube, then retry PiP."];return;}
 __weak YouTubePiP *weak=self;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.3*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[weak attempt:remaining-1 generation:generation];});
}
- (void)reset {[self clearItemObservers];self.generation++;self.requested=NO;self.attempting=NO;self.sourceMissing=NO;self.recoveryScheduled=NO;self.failedPlayback=NO;self.sourceURL=nil;self.pip.delegate=nil;[self.pip stopPictureInPicture];self.pip=nil;[self.player pause];self.playerLayer.player=nil;self.player=nil;self.epoch=nil;}
- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)controller {self.requested=NO;self.attempting=NO;[self report:@"YOUTUBE PiP ACTIVE: real received YouTube preview, no screen recording. You may switch apps. You can move or resize this ScreenLink window. Closing or pausing PiP can end background playback; iOS still controls runtime."];if(self.activityChanged)self.activityChanged(YES);}
- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)controller {self.requested=NO;self.attempting=NO;[self.player pause];[self report:@"YouTube PiP stopped. Return to ScreenLink to restore your selected PiP mode; background runtime is no longer assured."];if(self.activityChanged)self.activityChanged(NO);}
- (void)pictureInPictureController:(AVPictureInPictureController *)controller failedToStartPictureInPictureWithError:(NSError *)error {self.requested=NO;self.attempting=NO;[self report:[@"YouTube PiP failed: " stringByAppendingString:error.localizedDescription?:@"unknown"]];if(self.activityChanged)self.activityChanged(NO);}
- (void)pictureInPictureController:(AVPictureInPictureController *)controller restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL))completion {completion(YES);}
@end
