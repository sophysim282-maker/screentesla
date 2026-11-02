#import <ReplayKit/ReplayKit.h>
#import "Receiver.h"
#import "ScreenEncoder.h"
@interface SampleHandler : RPBroadcastSampleHandler
@property(nonatomic,strong) Receiver *receiver;
@property(nonatomic,strong) ScreenEncoder *encoder;
@end
@implementation SampleHandler
- (void)broadcastStartedWithSetupInfo:(NSDictionary<NSString *,NSObject *> *)setupInfo {
    self.receiver=[Receiver new];self.receiver.discoveryMode=SLDiscoveryPhoneVPN;
    __weak SampleHandler *weak=self;
    self.receiver.broadcastStop=^{[weak finishBroadcastWithError:[NSError errorWithDomain:@"ScreenLink.Broadcast" code:0 userInfo:@{NSLocalizedDescriptionKey:@"ScreenLink screen broadcast stopped."}]];};
    if(![self.receiver start]){[self finishBroadcastWithError:[NSError errorWithDomain:@"ScreenLink.Broadcast" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Receiver could not start. Return to ScreenLink, stop normal sharing, and start the screen broadcast again. Keep ScreenLink Local VPN connected."}]];return;}
    self.encoder=[[ScreenEncoder alloc]initWithStream:self.receiver.screenStream];
    self.encoder.frameEncoded=^(NSInteger orientation){[weak.receiver screenFrameWithOrientation:orientation];};
    self.encoder.failed=^(NSString *message){[weak.receiver broadcastMessage:message];};
    [self.receiver broadcastMessage:@"SCREEN BROADCAST ACTIVE: this extension owns AirPlay and the website. Open YouTube and select ScreenLink VPN Phone, then open Google Maps. Physical-device coexistence still requires testing."];
}
- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer withType:(RPSampleBufferType)type {
    @autoreleasepool {if(type==RPSampleBufferTypeVideo){CFTypeRef value=CMGetAttachment(sampleBuffer,(__bridge CFStringRef)RPVideoSampleOrientationKey,NULL);NSInteger orientation=value?[(NSNumber *)(__bridge id)value integerValue]:1;[self.encoder consume:sampleBuffer orientation:orientation];}}
}
- (void)broadcastPaused {[self.receiver broadcastMessage:@"Screen broadcast paused by iOS. Waiting for capture to resume."];}
- (void)broadcastResumed {[self.receiver broadcastMessage:@"Screen broadcast resumed. Browser reconnects to the existing receiver."];}
- (void)broadcastFinished {[self.encoder stop];self.encoder=nil;[self.receiver stop];self.receiver=nil;}
@end
