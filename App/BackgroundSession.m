#import "BackgroundSession.h"
#import <BackgroundTasks/BackgroundTasks.h>
#import <UIKit/UIKit.h>

// Public iOS 26 selectors, resolved at runtime so the IPA still builds with
// Xcode 16 and launches on older iOS. No private API or GPU entitlement.
@protocol SLContinuedRequest <NSObject>
- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title subtitle:(NSString *)subtitle;
@property(nonatomic) NSInteger strategy;
@end
@protocol SLContinuedTask <NSObject, NSProgressReporting>
@property(nonatomic,copy) void (^expirationHandler)(void);
- (void)updateTitle:(NSString *)title subtitle:(NSString *)subtitle;
- (void)setTaskCompletedWithSuccess:(BOOL)success;
@end
@interface BackgroundSession () {
    id<SLContinuedTask> _task;
    NSTimer *_timer;
    NSTimeInterval _started;
    NSString *_identifier;
    BOOL _registered,_pending,_reportedHealth;
}
@property(nonatomic,readwrite) BOOL active;
@end
@implementation BackgroundSession
- (void)log:(NSString *)message {if(self.status)self.status(message);}
- (void)start {
    if(self.active || _pending){[self log:@"A background session is already active or starting."];return;}
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive){[self log:@"Start the background session while ScreenLink is on screen."];return;}
    Class requestClass=NSClassFromString(@"BGContinuedProcessingTaskRequest");
    if(!requestClass){[self log:@"No-PiP background sessions require iOS 26 or later. Use floating preview on this version."];return;}
    NSString *bundle=NSBundle.mainBundle.bundleIdentifier;
    NSArray *permitted=[NSBundle.mainBundle objectForInfoDictionaryKey:@"BGTaskSchedulerPermittedIdentifiers"];
    NSString *wanted=[bundle stringByAppendingString:@".casting.*"];
    if(![permitted containsObject:wanted]){
        [self log:[NSString stringWithFormat:@"Background session unavailable after signing: bundle %@ needs permitted identifier %@. Floating preview still works. Copy this log so the IPA can include the signed identifier.",bundle,wanted]];return;
    }
    if(!_registered){
        _identifier=[[wanted substringToIndex:wanted.length-1] stringByAppendingString:@"session"];__weak BackgroundSession *weak=self;
        _registered=[BGTaskScheduler.sharedScheduler registerForTaskWithIdentifier:_identifier usingQueue:dispatch_get_main_queue() launchHandler:^(BGTask *task){
            BackgroundSession *owner=weak;
            if(!owner || !owner->_pending){[task setTaskCompletedWithSuccess:NO];return;}
            [owner launched:(id<SLContinuedTask>)task];
        }];
        if(!_registered){[self log:@"iOS rejected background handler registration. Use floating preview and copy the log."];return;}
    }
    id<SLContinuedRequest> request=[(id<SLContinuedRequest>)[requestClass alloc] initWithIdentifier:_identifier title:@"ScreenLink · YouTube" subtitle:@"Video over your local hotspot"];
    // Public BGContinuedProcessingTaskRequestSubmissionStrategyFail = 1.
    // Never queue a cast that could begin unexpectedly after the user leaves.
    request.strategy=1;_pending=YES;
    NSError *error=nil;
    if(![BGTaskScheduler.sharedScheduler submitTaskRequest:(BGTaskRequest *)request error:&error]){
        _pending=NO;[self log:[NSString stringWithFormat:@"No-PiP background request rejected (%@). Keep ScreenLink visible or use floating preview.",error]];return;
    }
    if(!self.active)[self log:@"30-minute background session requested. Wait for BACKGROUND SESSION ACTIVE before switching apps. This is a device test; iOS can end the session early."];
}
- (void)launched:(id<SLContinuedTask>)task {
    if(!self.allowWaitingForVideo && (!self.videoIsLive || !self.videoIsLive())){
        _pending=NO;[task setTaskCompletedWithSuccess:NO];
        [self log:@"Background request was accepted, but the AirPlay video disconnected before launch. Reconnect ScreenLink VPN Phone in Screen Mirroring, wait for live video, then start the background test again."];return;
    }
    _pending=NO;_reportedHealth=NO;_task=task;_started=NSProcessInfo.processInfo.systemUptime;self.active=YES;
    task.progress.totalUnitCount=1800;task.progress.completedUnitCount=0;
    __weak BackgroundSession *weak=self;
    task.expirationHandler=^{dispatch_async(dispatch_get_main_queue(),^{
        BackgroundSession *owner=weak;if(!owner || owner->_task!=task)return;
        [owner log:@"iOS ended the background session or you cancelled it in system controls. Receiver state is retained; iOS may suspend the app without floating preview."];
        [owner complete:NO notify:YES];
    });};
    _timer=[NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer){[weak tick];}];
    if(self.activityChanged)self.activityChanged(YES);
    [self log:@"BACKGROUND SESSION ACTIVE: runtime task started; background video is NOT verified yet. Use video-only mode for YouTube, or H.264 for mirroring. System controls can cancel it. JPEG fallback needs floating preview while backgrounded. Unlimited background operation is not promised."];
}
- (void)tick {
    NSTimeInterval elapsed=NSProcessInfo.processInfo.systemUptime-_started;
    BOOL live=self.videoIsLive && self.videoIsLive();
    if(!_reportedHealth && elapsed>=10 && UIApplication.sharedApplication.applicationState==UIApplicationStateBackground){
        _reportedHealth=YES;
        [self log:live?@"BACKGROUND SOURCE CHECK: fresh AirPlay packets are still arriving. Check browser display FPS to verify playback.":@"BACKGROUND SOURCE WAITING: no fresh video or browser playback report. In native media mode, open the hotspot viewer and select ScreenLink through YouTube AirPlay. For mirroring, return and use floating preview if needed."];
    }
    // Progress is the completed part of this explicitly timed, live session;
    // a disconnected stream never claims useful progress.
    if(live)_task.progress.completedUnitCount=MIN(1799,(int64_t)elapsed);
    if(((NSInteger)elapsed)%5==0)[_task updateTitle:@"ScreenLink · YouTube" subtitle:live?@"Running · local hotspot":@"Waiting for the AirPlay stream"];
    if(elapsed>=1800){[self log:@"The 30-minute background session finished. Receiver state is retained; iOS may suspend the app without floating preview. Start another session in ScreenLink if needed."];[self complete:live notify:YES];}
}
- (void)complete:(BOOL)success notify:(BOOL)notify {
    [_timer invalidate];_timer=nil;_pending=NO;
    id<SLContinuedTask> task=_task;_task=nil;
    BOOL wasActive=self.active;self.active=NO;
    if(task){task.expirationHandler=nil;if(success)task.progress.completedUnitCount=task.progress.totalUnitCount;[task setTaskCompletedWithSuccess:success];}
    if(wasActive && self.activityChanged)self.activityChanged(NO);
    if(notify && self.ended)self.ended();
}
- (void)finish {
    if(_pending && _identifier)[BGTaskScheduler.sharedScheduler cancelTaskRequestWithIdentifier:_identifier];
    [self complete:YES notify:NO];
}
@end
