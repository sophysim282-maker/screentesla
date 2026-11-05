#import "FloatingPreview.h"
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
@interface FloatingPreview () <AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate>
@property(nonatomic, strong) AVPictureInPictureController *pip;
@property(nonatomic) BOOL hasFrame;
@property(nonatomic) BOOL paused;
@property(nonatomic) BOOL requested;
@property(nonatomic) NSUInteger attempts;
@end
@implementation FloatingPreview {
    CVPixelBufferRef _lastPixelBuffer;
    NSTimer *_keepAliveTimer;
}
+ (Class)layerClass { return AVSampleBufferDisplayLayer.class; }
- (AVSampleBufferDisplayLayer *)displayLayer { return (AVSampleBufferDisplayLayer *)self.layer; }
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.backgroundColor=UIColor.blackColor;
        [self displayLayer].videoGravity=AVLayerVideoGravityResizeAspect;
    }return self;
}
- (void)dealloc {
    if (_lastPixelBuffer) { CVPixelBufferRelease(_lastPixelBuffer); _lastPixelBuffer = NULL; }
    [_keepAliveTimer invalidate]; _keepAliveTimer = nil;
}
- (void)report:(NSString *)message { if(self.status)self.status(message); }
- (BOOL)active { return self.pip.isPictureInPictureActive; }
- (void)startKeepAliveTimer {
    if (_keepAliveTimer) return;
    _keepAliveTimer = [NSTimer timerWithTimeInterval:0.75 target:self selector:@selector(onKeepAlive) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_keepAliveTimer forMode:NSRunLoopCommonModes];
}
- (void)onKeepAlive {
    if (_lastPixelBuffer) {
        [self receivePixelBuffer:_lastPixelBuffer];
    }
}
- (void)receivePixelBuffer:(CVPixelBufferRef)pixel {
    NSAssert(NSThread.isMainThread,@"Preview must update on main thread");
    if (pixel != _lastPixelBuffer) {
        if (_lastPixelBuffer) { CVPixelBufferRelease(_lastPixelBuffer); }
        _lastPixelBuffer = CVPixelBufferRetain(pixel);
    }
    [self startKeepAliveTimer];
    AVSampleBufferDisplayLayer *layer=[self displayLayer];
    if(layer.status==AVSampleBufferDisplayLayerStatusFailed) {
        [self report:[NSString stringWithFormat:@"Preview renderer reset: %@",layer.error.localizedDescription ?:@""]];
        [layer flush];
    }
    if(!layer.isReadyForMoreMediaData)return;
    CMVideoFormatDescriptionRef format=NULL;CMSSampleBufferRef sample=NULL;
    OSStatus error=CMVideoFormatDescriptionCreateForImageBuffer(NULL,pixel,&format);
    if(error)return;
    CMSampleTimingInfo timing={CMTimeMake(1,10),CMClockGetTime(CMClockGetHostTimeClock()),kCMTimeInvalid};
    error=CMSampleBufferCreateReadyWithImageBuffer(NULL,pixel,format,&timing,&sample);
    if(!error) {
        CFArrayRef attachments=CMSampleBufferGetSampleAttachmentsArray(sample,YES);
        if(attachments && CFArrayGetCount(attachments))CFDictionarySetValue((CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments,0),kCMSampleBufferAttachmentKey_DisplayImmediately,kCFBooleanTrue);
        [layer enqueueSampleBuffer:sample];
        if(!self.hasFrame) {
            self.hasFrame=YES;
            [self report:@"Live preview ready. Tap Start floating preview, then switch apps only after the floating window opens."];
            [self.pip invalidatePlaybackState];
        }
    }
    if(sample)CFRelease(sample);CFRelease(format);
}
- (void)startFloating {
    if(self.active){[self report:@"Floating preview is already active."];return;}
    if(self.requested)return;
    if(!AVPictureInPictureController.isPictureInPictureSupported){[self report:@"Picture in Picture is not supported on this device."];return;}
    if(!self.hasFrame){[self report:@"Connect AirPlay and return here first. Floating preview needs a real receiver frame before starting."];return;}
    NSError *error=nil;AVAudioSession *session=AVAudioSession.sharedInstance;
    if(![session setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeMoviePlayback options:AVAudioSessionCategoryOptionMixWithOthers error:&error]){
        [self report:[NSString stringWithFormat:@"Could not prepare video playback: %@",error.localizedDescription ?:@""]];
    }
    if(!self.pip) {
        AVPictureInPictureControllerContentSource *source=[[AVPictureInPictureControllerContentSource alloc]initWithSampleBufferDisplayLayer:[self displayLayer] playbackDelegate:self];
        self.pip=[[AVPictureInPictureController alloc]initWithContentSource:source];self.pip.delegate=self;
        self.pip.requiresLinearPlayback=YES;self.pip.canStartPictureInPictureAutomaticallyFromInline=YES;
    }
    self.requested=YES;self.attempts=0;
    [self report:@"Requesting Picture in Picture..."];
    [self.pip startPictureInPicture];
}
- (void)stopFloating {
    self.requested=NO;
    if(self.active)[self.pip stopPictureInPicture];
}
- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    self.requested=NO;[self report:@"Floating preview started. Switch to other apps now."];
}
- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    self.requested=NO;self.paused=NO;[self report:@"Floating preview stopped."];
}
- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController failedToStartPictureInPictureWithError:(NSError *)error {
    self.requested=NO;
    [self report:[NSString stringWithFormat:@"Could not start floating preview: %@",error.localizedDescription ?:@""]];
}
- (BOOL)pictureInPictureControllerIsPlaybackPaused:(AVPictureInPictureController *)controller {
    return NO;
}
- (void)pictureInPictureController:(AVPictureInPictureController *)controller setPlaying:(BOOL)playing {
    self.paused=!playing;
    [self report:playing?@"Floating preview resumed.":@"Floating preview paused."];
}
- (CMTimeRange)pictureInPictureControllerTimeRangeForPlayback:(AVPictureInPictureController *)controller {
    return CMTimeRangeMake(CMTimeMake(0,10),CMTimeMake(360000,10));
}
@end
