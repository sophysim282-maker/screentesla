#import "FloatingPreview.h"
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
@interface FloatingPreview () <AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate>
@property(nonatomic,strong) AVPictureInPictureController *pip;
@property(nonatomic) BOOL hasFrame;
@property(nonatomic) BOOL paused;
@end
@implementation FloatingPreview
+ (Class)layerClass { return AVSampleBufferDisplayLayer.class; }
- (AVSampleBufferDisplayLayer *)displayLayer { return (AVSampleBufferDisplayLayer *)self.layer; }
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.backgroundColor=UIColor.blackColor;
        [self displayLayer].videoGravity=AVLayerVideoGravityResizeAspect;
        if(AVPictureInPictureController.isPictureInPictureSupported) {
            AVPictureInPictureControllerContentSource *source=[[AVPictureInPictureControllerContentSource alloc] initWithSampleBufferDisplayLayer:[self displayLayer] playbackDelegate:self];
            self.pip=[[AVPictureInPictureController alloc]initWithContentSource:source];
            self.pip.delegate=self;
            self.pip.requiresLinearPlayback=YES;
            self.pip.canStartPictureInPictureAutomaticallyFromInline=YES;
        }
    }return self;
}
- (void)report:(NSString *)message { if(self.status)self.status(message); }
- (BOOL)active { return self.pip.isPictureInPictureActive; }
- (void)receivePixelBuffer:(CVPixelBufferRef)pixel {
    NSAssert(NSThread.isMainThread,@"Preview must update on main thread");
    if(self.paused)return;
    AVSampleBufferDisplayLayer *layer=[self displayLayer];
    if(layer.status==AVQueuedSampleBufferRenderingStatusFailed) {
        [self report:[NSString stringWithFormat:@"Preview renderer reset: %@",layer.error.localizedDescription ?: @"unknown error"]];
        [layer flush];
    }
    if(!layer.isReadyForMoreMediaData)return;
    CMVideoFormatDescriptionRef format=NULL;CMSampleBufferRef sample=NULL;
    OSStatus error=CMVideoFormatDescriptionCreateForImageBuffer(NULL,pixel,&format);
    if(error)return;
    CMSampleTimingInfo timing={CMTimeMake(1,10),CMClockGetTime(CMClockGetHostTimeClock()),kCMTimeInvalid};
    error=CMSampleBufferCreateReadyWithImageBuffer(NULL,pixel,format,&timing,&sample);
    if(!error) {
        CFArrayRef attachments=CMSampleBufferGetSampleAttachmentsArray(sample,YES);
        if(attachments && CFArrayGetCount(attachments))CFDictionarySetValue((CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments,0),kCMSampleAttachmentKey_DisplayImmediately,kCFBooleanTrue);
        [layer enqueueSampleBuffer:sample];
        if(!self.hasFrame) {
            self.hasFrame=YES;
            [self report:@"Live preview ready. Tap Start floating preview, then switch apps only after the floating video appears."];
            [self.pip invalidatePlaybackState];
        }
    }
    if(sample)CFRelease(sample);CFRelease(format);
}
- (void)startFloating {
    if(!self.pip){[self report:@"Picture in Picture is not supported on this device."];return;}
    if(!self.hasFrame){[self report:@"Connect AirPlay and return here first. Floating preview needs a real received video frame."];return;}
    NSError *error=nil;AVAudioSession *session=AVAudioSession.sharedInstance;
    if(![session setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeMoviePlayback options:AVAudioSessionCategoryOptionMixWithOthers error:&error] || ![session setActive:YES error:&error]) {
        [self report:[NSString stringWithFormat:@"Could not prepare video playback: %@",error.localizedDescription]];return;
    }
    self.paused=NO;[self.pip invalidatePlaybackState];
    if(!self.pip.isPictureInPicturePossible){[self report:@"Floating preview is not ready. Keep incoming video playing and try again. Check Settings → General → Picture in Picture if needed."];return;}
    [self.pip startPictureInPicture];
    [self report:@"Requesting floating preview. Wait for its visible window before leaving ScreenLink."];
}
- (void)reset {
    [self.pip stopPictureInPicture];self.hasFrame=NO;self.paused=NO;
    [[self displayLayer] flushAndRemoveImage];
    [self.pip invalidatePlaybackState];
}
- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)controller {
    [self report:@"Floating preview ACTIVE. You can try switching apps; background reception still needs a device test. Closing or pausing it can stop sharing."];
    if(self.activityChanged)self.activityChanged(YES);
}
- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)controller {
    [self report:@"Floating preview stopped."];
    if(self.activityChanged)self.activityChanged(NO);
}
- (void)pictureInPictureController:(AVPictureInPictureController *)controller failedToStartPictureInPictureWithError:(NSError *)error {
    [self report:[NSString stringWithFormat:@"Floating preview failed: %@",error.localizedDescription]];
    if(self.activityChanged)self.activityChanged(NO);
}
- (void)pictureInPictureController:(AVPictureInPictureController *)controller restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL))completionHandler { completionHandler(YES); }
- (void)pictureInPictureController:(AVPictureInPictureController *)controller setPlaying:(BOOL)playing {
    self.paused=!playing;[controller invalidatePlaybackState];
    if(!playing)[self report:@"Floating video paused. Return to ScreenLink and resume video; background sharing may stop."];
}
- (CMTimeRange)pictureInPictureControllerTimeRangeForPlayback:(AVPictureInPictureController *)controller { return CMTimeRangeMake(kCMTimeZero,kCMTimePositiveInfinity); }
- (BOOL)pictureInPictureControllerIsPlaybackPaused:(AVPictureInPictureController *)controller { return self.paused; }
- (void)pictureInPictureController:(AVPictureInPictureController *)controller didTransitionToRenderSize:(CMVideoDimensions)newRenderSize {}
- (void)pictureInPictureController:(AVPictureInPictureController *)controller skipByInterval:(CMTime)skipInterval completionHandler:(void (^)(void))completionHandler { completionHandler(); }
@end
