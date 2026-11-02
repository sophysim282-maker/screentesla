#import "ScreenEncoder.h"
#import "H264Stream.h"
#import <VideoToolbox/VideoToolbox.h>
#include <math.h>
@interface ScreenEncoder () {
    VTCompressionSessionRef _encoder;
    VTPixelTransferSessionRef _transfer;
    CVPixelBufferPoolRef _pool;
    H264Stream *_stream;
    CMVideoDimensions _dimensions;
    dispatch_semaphore_t _slots;
    NSInteger _orientation;
    BOOL _configured,_stopped;
    CMTime _last;
}
- (void)encoded:(CMSampleBufferRef)sample error:(OSStatus)error;
@end
static void output(void *owner,void *frame,OSStatus status,VTEncodeInfoFlags flags,CMSampleBufferRef sample){
    ScreenEncoder *encoder=(__bridge ScreenEncoder *)owner;
    @autoreleasepool {[encoder encoded:sample error:status];}
}
@implementation ScreenEncoder
- (instancetype)initWithStream:(H264Stream *)stream {if((self=[super init])){_stream=stream;_slots=dispatch_semaphore_create(2);_last=kCMTimeInvalid;}return self;}
- (void)closeEncoder {
    if(_encoder){VTCompressionSessionCompleteFrames(_encoder,kCMTimeInvalid);VTCompressionSessionInvalidate(_encoder);CFRelease(_encoder);_encoder=NULL;}
    if(_pool){CFRelease(_pool);_pool=NULL;}if(_transfer){VTPixelTransferSessionInvalidate(_transfer);CFRelease(_transfer);_transfer=NULL;}_configured=NO;
}
- (BOOL)setup:(CVPixelBufferRef)source {
    size_t w=CVPixelBufferGetWidth(source),h=CVPixelBufferGetHeight(source);double scale=MIN(1.0,960.0/MAX(w,h));
    _dimensions=(CMVideoDimensions){MAX(2,((int)(w*scale)/2)*2),MAX(2,((int)(h*scale)/2)*2)};
    NSDictionary *pixels=@{(id)kCVPixelBufferWidthKey:@(_dimensions.width),(id)kCVPixelBufferHeightKey:@(_dimensions.height),(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),(id)kCVPixelBufferIOSurfacePropertiesKey:@{}};
    OSStatus error=CVPixelBufferPoolCreate(NULL,(__bridge CFDictionaryRef)@{(id)kCVPixelBufferPoolMinimumBufferCountKey:@2},(__bridge CFDictionaryRef)pixels,&_pool);
    if(!error)error=VTPixelTransferSessionCreate(NULL,&_transfer);
    if(!error)error=VTCompressionSessionCreate(NULL,_dimensions.width,_dimensions.height,kCMVideoCodecType_H264,NULL,NULL,NULL,output,(__bridge void *)self,&_encoder);
    if(!error){
        NSDictionary *properties=@{(id)kVTCompressionPropertyKey_RealTime:@YES,(id)kVTCompressionPropertyKey_AllowFrameReordering:@NO,(id)kVTCompressionPropertyKey_ProfileLevel:(id)kVTProfileLevel_H264_Baseline_AutoLevel,(id)kVTCompressionPropertyKey_AverageBitRate:@1500000,(id)kVTCompressionPropertyKey_ExpectedFrameRate:@30,(id)kVTCompressionPropertyKey_MaxKeyFrameInterval:@30,(id)kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration:@1};
        error=VTSessionSetProperties(_encoder,(__bridge CFDictionaryRef)properties);
        if(!error)error=VTCompressionSessionPrepareToEncodeFrames(_encoder);
    }
    if(error){if(self.failed)self.failed([NSString stringWithFormat:@"Screen encoder setup failed (%d).",(int)error]);[self closeEncoder];return NO;}
    return YES;
}
- (void)consume:(CMSampleBufferRef)sample orientation:(NSInteger)orientation {
    if(_stopped)return;CVPixelBufferRef input=CMSampleBufferGetImageBuffer(sample);if(!input)return;
    CMTime pts=CMSampleBufferGetPresentationTimeStamp(sample);if(!CMTIME_IS_NUMERIC(pts))return;
    if(CMTIME_IS_NUMERIC(_last)&&CMTimeGetSeconds(CMTimeSubtract(pts,_last))<1.0/30.0)return;
    if(!_encoder && ![self setup:input])return;
    if(_orientation && orientation!=_orientation){[self closeEncoder];if(![self setup:input])return;}
    _orientation=orientation;
    if(dispatch_semaphore_wait(_slots,DISPATCH_TIME_NOW))return;
    CVPixelBufferRef scaled=NULL;
    OSStatus error=CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(NULL,_pool,(__bridge CFDictionaryRef)@{(id)kCVPixelBufferPoolAllocationThresholdKey:@3},&scaled);
    if(!error)error=VTPixelTransferSessionTransferImage(_transfer,input,scaled);
    if(!error){_last=pts;error=VTCompressionSessionEncodeFrame(_encoder,scaled,pts,CMTimeMake(1,30),NULL,NULL,NULL);}
    if(scaled)CVPixelBufferRelease(scaled);
    if(error){dispatch_semaphore_signal(_slots);if(self.failed)self.failed([NSString stringWithFormat:@"Screen frame rejected (%d); later frames will retry.",(int)error]);}
}
- (void)encoded:(CMSampleBufferRef)sample error:(OSStatus)error {
    @try {
        if(error||!sample||_stopped)return;
        CMFormatDescriptionRef format=CMSampleBufferGetFormatDescription(sample);
        if(!_configured){const uint8_t *sps=NULL,*pps=NULL;size_t sn=0,pn=0,count=0;int length=0;
            if(CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format,0,&sps,&sn,&count,&length)||CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format,1,&pps,&pn,&count,&length)||length!=4)return;
            [_stream configureSPS:[NSData dataWithBytes:sps length:sn] PPS:[NSData dataWithBytes:pps length:pn] width:(uint16_t)_dimensions.width height:(uint16_t)_dimensions.height];_configured=YES;
        }
        CMBlockBufferRef block=CMSampleBufferGetDataBuffer(sample);size_t n=CMBlockBufferGetDataLength(block);if(!n||n>2*1024*1024)return;
        NSMutableData *data=[NSMutableData dataWithLength:n];if(CMBlockBufferCopyDataBytes(block,0,n,data.mutableBytes))return;
        CFArrayRef attachments=CMSampleBufferGetSampleAttachmentsArray(sample,NO);BOOL key=YES;
        if(attachments&&CFArrayGetCount(attachments)){CFDictionaryRef values=CFArrayGetValueAtIndex(attachments,0);key=!CFDictionaryContainsKey(values,kCMSampleAttachmentKey_NotSync);}
        double seconds=CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample));if(!isfinite(seconds)||seconds<0)return;
        [_stream appendAVCC:data timestamp:(uint64_t)(seconds*1000000) keyframe:key];if(self.frameEncoded)self.frameEncoded(_orientation?:1);
    } @finally {dispatch_semaphore_signal(_slots);}
}
- (void)stop {_stopped=YES;[self closeEncoder];[_stream reset];}
- (void)dealloc {[self closeEncoder];}
@end
