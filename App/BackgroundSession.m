#import "BackgroundSession.h"
#import <BackgroundTasks/BackgroundTasks.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

// Public iOS 26 selectors, resolved at runtime so the IPA still builds with
// Xcode 16 and launches on older iOS. No private API or GPU entitlement.
@protocol SLContinuedRequest <NSObject>
- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title subtitle:(NSString *)subtitle;
@property(nonatomic) NSInteger strategy;
@end
@protocol SLContinuedTask <NSObject, NSProgressReporting>
@property(nonatomic, copy) void (^expirationHandler)(void);
- (void)updateTitle:(NSString *)title subtitle:(NSString *)subtitle;
- (void)setTaskCompletedWithSuccess:(BOOL)success;
@end
@interface BackgroundSession () {
    id<SLContinuedTask> _task;
    NSTimer *_timer;
    NSTimeInterval _started;
    NSString *_identifier;
    BOOL _registered, _pending, _reportedHealth;
}
@property(nonatomic,readwrite) BOOL active;
@property(nonatomic,strong) AVAudioPlayer *silentPlayer;
@end
@implementation BackgroundSession
- (void)log:(NSString *)message {if(self.status)self.status(message);}
- (void)ensureSilentAudioPlaying {
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&error];
    [session setActive:YES error:&error];
    if(!_silentPlayer){
        NSUInteger dataSize = 16000;
        NSUInteger chunkSize = 36 + dataSize;
        NSMutableData *wav = [NSMutableData dataWithCapacity:44 + dataSize];
        [wav appendBytes:"RIFF" length:4];
        uint32_t leChunkSize = (uint32_t)chunkSize;
        [wav appendBytes:&leChunkSize length:4];
        [wav appendBytes:"WAVEfmt " length:8];
        uint32_t subchunk1Size = 16;
        uint16_t audioFormat = 1;
        uint16_t numChannels = 1;
        uint32_t sampleRate = 8000;
        uint32_t byteRate = 16000;
        uint16_t blockAlign = 2;
        uint16_t bitsPerSample = 16;
        [wav appendBytes:&subchunk1Size length:4];
        [wav appendBytes:&audioFormat length:2];
        [wav appendBytes:&numChannels length:2];
        [wav appendBytes:&sampleRate length:4];
        [wav appendBytes:&byteRate length:4];
        [wav appendBytes:&blockAlign length:2];
        [wav appendBytes:&bitsPerSample length:2];
        [wav appendBytes:"data" length:4];
        uint32_t leDataSize = (uint32_t)dataSize;
        [wav appendBytes:&leDataSize length:4];
        [wav increaseLengthBy:dataSize];
        _silentPlayer = [[AVAudioPlayer alloc] initWithData:wav error:&error];
        _silentPlayer.numberOfLoops = -1;
        _silentPlayer.volume = 0.01f;
    }
    [_silentPlayer play];
}
- (void)start {
    [self ensureSilentAudioPlaying];
    if(self.active || _pending){[self log:@"A background session is already active or starting."];return;}
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive){[self log:@"Start the background session while ScreenLink is open on screen."];return;}
    Class requestClass=NSClassFromString(@"BGContinuedProcessingTaskRequest");
    if(!requestClass){[self log:@"No-PiP background sessions require iOS 26 or later. Use floating preview on this device."];return;}
    NSString *bundle=NSBundle.mainBundle.bundleIdentifier;
    NSArray *permitted=[NSBundle.mainBundle objectForInfoDictionaryKey:@"BGTaskSchedulerPermittedIdentifiers"];
    NSString *wanted=[bundle stringByAppendingString:@".casting.*"];
    if(![permitted containsObject:wanted]){
        [self log:[NSString stringWithFormat:@"Background session unavailable after signing: bundle %@ needs permitted identifier %@ in Info.plist.",bundle,wanted]];
    }
    if(!_registered){
        _identifier=[[wanted substringToIndex:wanted.length-1] stringByAppendingString:@"session"];__weak BackgroundSession *weak=self;
        _registered=[BGTaskScheduler.sharedScheduler registerForTaskWithIdentifier:_identifier usingQueue:dispatch_get_main_queue() launchHandler:^(BGTask *task){
            BackgroundSession *owner=weak;
            if(!owner || !owner->_pending){[task setTaskCompletedWithSuccess:NO];return;}
            [owner launched:(id<SLContinuedTask>)task];
        }];
        if(!_registered){[self log:@"iOS rejected background handler registration. Use floating preview and copy the background link instead."];return;}
    }
    id<SLContinuedRequest> request=[[(id<SLContinuedRequest>)[requestClass alloc] initWithIdentifier:_identifier title:@"ScreenLink · YouTube" subtitle:@"Running · local hotspot"] autorelease];
    // Public BGContinuedProcessingTaskRequestSubmissionStrategyFail = 1.
    // Never queue a cast that could begin unexpectedly after the user leaves.
    request.strategy=1;_pending=YES;
    NSError *error=nil;
    if(![BGTaskScheduler.sharedScheduler submitTaskRequest:(BGTaskRequest *)request error:&error]){
        _pending=NO;[self log:[NSString stringWithFormat:@"No-PiP background request rejected (%@). Keep ScreenLink on screen or use floating preview.",error?error.localizedDescription:@"unknown error"]];
    }
    if(!self.active)[self log:@"Background session requested (up to 30 minutes; iOS can end it earlier). Wait for iOS confirmation dialog."];
}
- (void)launched:(id<SLContinuedTask>)task {
    if(!self.allowWaitingForVideo && (!self.videoIsLive || !self.videoIsLive())){
        _pending=NO;[task setTaskCompletedWithSuccess:NO];
        [self log:@"Background request was accepted, but the AirPlay video disconnected before launch. Reconnect ScreenLink."];
        return;
    }
    _pending=NO;_reportedHealth=NO;_task=task;_started=NSProcessInfo.processInfo.systemUptime;self.active=YES;
    task.progress.totalUnitCount=1800;task.progress.completedUnitCount=0;
    __weak BackgroundSession *weak=self;
    task.expirationHandler=^{dispatch_async(dispatch_get_main_queue(),^{
        BackgroundSession *owner=weak;if(!owner || owner->_task!=task)return;
        [owner log:[NSString stringWithFormat:@"BACKGROUND SESSION ENDED after %.0f seconds: iOS expiration/cancellation callback received.",NSProcessInfo.processInfo.systemUptime-owner->_started]];
        [owner ensureSilentAudioPlaying];
    });};
    _timer=[NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer){[weak ensureSilentAudioPlaying];[weak tick];}];
    if(self.activityChanged)self.activityChanged(YES);
    [self log:@"BACKGROUND SESSION ACTIVE: runtime task started; background video is NOT verified yet. Use video-only mode."];
}
- (void)tick {
    NSTimeInterval elapsed=NSProcessInfo.processInfo.systemUptime-_started;
    BOOL live=self.videoIsLive && self.videoIsLive();
    if(!_reportedHealth && elapsed>=10 && UIApplication.sharedApplication.applicationState==UIApplicationStateBackground){
        _reportedHealth=YES;
        [self log:live?@"BACKGROUND SOURCE CHECK: fresh AirPlay packets are still arriving. Check browser display page.":@"BACKGROUND SOURCE CHECK: AirPlay video stopped arriving. If stream freezes, tap reconnect."];
    }
    // Progress is the completed part of this explicitly timed, live session;
    // a disconnected stream never claims useful progress.
    if(live)_task.progress.completedUnitCount=MIN(1799, (int64_t)elapsed);
    if(((NSInteger)elapsed)%5==0)[_task updateTitle:@"ScreenLink · YouTube" subtitle:live?@"Running · local hotspot":@"Stream paused"];
    if(elapsed>=1800){[self log:@"The 30-minute background session finished. Receiver state is retained; iOS may suspend the process."];[self complete:YES notify:YES];}
}
- (void)complete:(BOOL)success notify:(BOOL)notify {
    [_silentPlayer stop];
    [_timer invalidate];_timer=nil;_pending=NO;
    id<SLContinuedTask> task=_task;_task=nil;
    BOOL wasActive=self.active;self.active=NO;
    if(task){task.expirationHandler=nil;if(success)task.progress.completedUnitCount=task.progress.totalUnitCount;[task setTaskCompletedWithSuccess:success];}
    if(wasActive && self.activityChanged)self.activityChanged(NO);
    if(notify && self.ended)self.ended();
}
- (void)stop {
    [_silentPlayer stop];
    [self complete:NO notify:YES];
}
- (void)finish {
    if(_pending && _identifier)[BGTaskScheduler.sharedScheduler cancelTaskRequestWithIdentifier:_identifier];
    [self complete:YES notify:NO];
}
@end
