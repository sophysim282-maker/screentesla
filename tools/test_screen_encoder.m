#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import "ScreenEncoder.h"
#import "H264Stream.h"
#include <assert.h>
#include <unistd.h>
int main(void){@autoreleasepool{
 H264Stream *stream=[[H264Stream alloc]initWithMaxBytes:1024*1024 packets:60];ScreenEncoder *encoder=[[ScreenEncoder alloc]initWithStream:stream];__block NSUInteger frames=0;__block NSString *failure=nil;
 encoder.frameEncoded=^(NSInteger orientation){@synchronized(stream){frames++;}assert(orientation==1);};encoder.failed=^(NSString *error){failure=error;};
 CVPixelBufferRef pixel=NULL;assert(!CVPixelBufferCreate(NULL,1280,720,kCVPixelFormatType_32BGRA,(__bridge CFDictionaryRef)@{(id)kCVPixelBufferIOSurfacePropertiesKey:@{}},&pixel));
 CVPixelBufferLockBaseAddress(pixel,0);memset(CVPixelBufferGetBaseAddress(pixel),128,CVPixelBufferGetBytesPerRow(pixel)*720);CVPixelBufferUnlockBaseAddress(pixel,0);
 CMVideoFormatDescriptionRef format=NULL;assert(!CMVideoFormatDescriptionCreateForImageBuffer(NULL,pixel,&format));
 for(int i=0;i<90;i++){
  CMSampleTimingInfo timing={CMTimeMake(1,30),CMTimeMake(i,30),kCMTimeInvalid};CMSampleBufferRef sample=NULL;
  assert(!CMSampleBufferCreateReadyWithImageBuffer(NULL,pixel,format,&timing,&sample));[encoder consume:sample orientation:1];CFRelease(sample);usleep(10000);
 }
 CFRelease(format);CVPixelBufferRelease(pixel);
 NSDate *until=[NSDate dateWithTimeIntervalSinceNow:3];while([until timeIntervalSinceNow]>0){@synchronized(stream){if(frames>=5)break;}[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.02]];}
 if(failure)fprintf(stderr,"%s\n",failure.UTF8String);
 assert(!failure);assert(frames>=5);NSDictionary *info=[stream info];assert([info[@"ready"] boolValue]);NSDictionary *init=[stream initialization];assert([init[@"data"] length]>100);
 NSDictionary *packet=[stream readAfter:0 epoch:info[@"epoch"]];assert([packet[@"data"] length]>100);
 [encoder stop];assert(![[stream info][@"ready"] boolValue]);
 printf("Screen broadcast encoder passed: scaling, H.264 encoding, fMP4 output, callbacks and stop cleanup (%lu frames).\n",(unsigned long)frames);
}return 0;}
