#import "SLTestVideo.h"
#import <WebRTC/WebRTC.h>
#import <CoreVideo/CoreVideo.h>
@interface SLTestVideo () {
    CVPixelBufferPoolRef _pool;
}
@property(nonatomic,strong) RTCVideoSource *source;
@property(nonatomic,strong) RTCVideoCapturer *capturer;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic) uint64_t sequence;
@end
@implementation SLTestVideo
- (instancetype)initWithSource:(RTCVideoSource *)source {
    if((self=[super init])){
        _source=source;_capturer=[[RTCVideoCapturer alloc]initWithDelegate:source];
        NSDictionary *attributes=@{(id)kCVPixelBufferWidthKey:@640,(id)kCVPixelBufferHeightKey:@360,(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA),(id)kCVPixelBufferIOSurfacePropertiesKey:@{}};
        if(CVPixelBufferPoolCreate(kCFAllocatorDefault,NULL,(__bridge CFDictionaryRef)attributes,&_pool)!=kCVReturnSuccess)return nil;
        [source adaptOutputFormatToWidth:640 height:360 fps:30];
    }return self;
}
- (void)draw {
    @autoreleasepool {
        // Drop a frame if encoders still retain all four buffers. Never queue captures.
        CVPixelBufferRef pixel=NULL;NSDictionary *limit=@{(id)kCVPixelBufferPoolAllocationThresholdKey:@4};
        if(CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault,_pool,(__bridge CFDictionaryRef)limit,&pixel)!=kCVReturnSuccess)return;
        CVPixelBufferLockBaseAddress(pixel,0);uint8_t *bytes=CVPixelBufferGetBaseAddress(pixel);size_t stride=CVPixelBufferGetBytesPerRow(pixel);uint64_t n=self.sequence++;
        int boxX=(int)((n*7)%576),boxY=(int)((n*3)%296);
        for(int y=0;y<360;y++)for(int x=0;x<640;x++){
            uint8_t *p=bytes+y*stride+x*4;int band=x/80;
            p[0]=(uint8_t)(30+band*24);p[1]=(uint8_t)(40+y/3);p[2]=(uint8_t)(170-band*17);p[3]=255;
            if((x>=boxX&&x<boxX+64&&y>=boxY&&y<boxY+64)||((y>320)&&((n>>(x/40))&1)))p[0]=p[1]=p[2]=245;
        }
        CVPixelBufferUnlockBaseAddress(pixel,0);
        RTCCVPixelBuffer *buffer=[[RTCCVPixelBuffer alloc]initWithPixelBuffer:pixel];
        RTCVideoFrame *frame=[[RTCVideoFrame alloc]initWithBuffer:buffer rotation:RTCVideoRotation_0 timeStampNs:(int64_t)(NSProcessInfo.processInfo.systemUptime*1e9)];
        [self.source capturer:self.capturer didCaptureVideoFrame:frame];CVPixelBufferRelease(pixel);
    }
}
- (void)start {if(self.timer)return;__weak SLTestVideo *weak=self;self.timer=[NSTimer timerWithTimeInterval:1.0/30 repeats:YES block:^(NSTimer *timer){[weak draw];}];[NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];[self draw];}
- (void)stop {[self.timer invalidate];self.timer=nil;}
- (void)dealloc {[self stop];if(_pool)CVPixelBufferPoolRelease(_pool);}
@end
