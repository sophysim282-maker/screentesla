#import <XCTest/XCTest.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import "YouTubePiP.h"
@interface YouTubePiP (Testing)
- (void)observeItem:(AVPlayerItem *)item;
- (void)installItemAtURL:(NSURL *)url;
- (void)beginIfReady;
@end
@interface SLItem : NSObject
@property(nonatomic) AVPlayerItemStatus status;
@end
@implementation SLItem
@end
@interface SLPlayer : NSObject
@property(nonatomic,strong) AVPlayerItem *currentItem;
@property(nonatomic) AVPlayerStatus status;
@property(nonatomic) BOOL muted,allowsExternalPlayback,automaticallyWaitsToMinimizeStalling;
@property(nonatomic) NSUInteger plays,replacements;
- (void)play;
- (void)pause;
- (void)replaceCurrentItemWithPlayerItem:(AVPlayerItem *)item;
@end
@implementation SLPlayer
- (void)play {self.plays++;}
- (void)pause {}
- (void)replaceCurrentItemWithPlayerItem:(AVPlayerItem *)item {self.currentItem=item;self.replacements++;}
@end
@interface SLLayer : NSObject
@property(nonatomic,strong) AVPlayer *player;
@property(nonatomic,copy) AVLayerVideoGravity videoGravity;
@end
@implementation SLLayer
@end
@interface SLPiP : NSObject
@property(nonatomic,weak) id delegate;
@property(nonatomic) BOOL pictureInPictureActive,canStartPictureInPictureAutomaticallyFromInline;
- (void)stopPictureInPicture;
@end
@implementation SLPiP
- (void)stopPictureInPicture {self.pictureInPictureActive=NO;}
@end
@interface SLPreview : YouTubePiP
@property(nonatomic) BOOL foreground;
@property(nonatomic) NSUInteger attempts;
@property(nonatomic,strong) SLLayer *testLayer;
@end
@implementation SLPreview
- (BOOL)appIsActive {return self.foreground;}
- (BOOL)pipSupported {return YES;}
- (AVPlayerLayer *)playerLayer {if(!self.testLayer)self.testLayer=[SLLayer new];return (AVPlayerLayer *)self.testLayer;}
- (void)beginIfReady {self.attempts++;}
@end
@interface PiPRecoveryTests : XCTestCase
@end
@implementation PiPRecoveryTests
- (SLPreview *)fixture {
 SLPreview *v=[[SLPreview alloc]initWithFrame:CGRectMake(0,0,320,180)];SLPlayer *p=[SLPlayer new];SLItem *i=[SLItem new];i.status=AVPlayerItemStatusReadyToPlay;p.currentItem=(AVPlayerItem *)i;
 [v setValue:p forKey:@"player"];[v setValue:[SLPiP new] forKey:@"pip"];[v setValue:@"same-epoch" forKey:@"epoch"];[v setValue:[NSURL URLWithString:@"http://127.0.0.1:8080/media/resource/test"] forKey:@"sourceURL"];[v observeItem:(AVPlayerItem *)i];return v;
}
- (void)waitForRetry {XCTestExpectation *e=[self expectationWithDescription:@"bounded deferred recovery"];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.25*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[e fulfill];});[self waitForExpectations:@[e] timeout:4];}
- (void)fail:(SLPreview *)v {
 id item=[[v valueForKey:@"player"] currentItem];
 [NSNotificationCenter.defaultCenter postNotificationName:AVPlayerItemFailedToPlayToEndTimeNotification object:item userInfo:@{AVPlayerItemFailedToPlayToEndTimeErrorKey:[NSError errorWithDomain:NSURLErrorDomain code:-1004 userInfo:nil]}];
}
- (void)testFailureWhileInactiveRecoversSameEpochOnlyOnForeground {
 SLPreview *v=[self fixture];SLPlayer *p=[v valueForKey:@"player"];id old=p.currentItem;[self fail:v];
 XCTAssertTrue([[v valueForKey:@"failedPlayback"] boolValue]);XCTAssertFalse([[v valueForKey:@"recoveryScheduled"] boolValue]);XCTAssertEqual(p.replacements,0u);
 v.foreground=YES;[v resumeAfterForeground];XCTAssertTrue([[v valueForKey:@"recoveryScheduled"] boolValue]);[self waitForRetry];
 XCTAssertNotEqual(p.currentItem,old);XCTAssertEqual(p.replacements,1u);XCTAssertFalse([[v valueForKey:@"failedPlayback"] boolValue]);XCTAssertEqualObjects([v valueForKey:@"epoch"],@"same-epoch");XCTAssertGreaterThan(v.attempts,0u);[v reset];
}
- (void)testDisconnectCancelsQueuedFailureRecovery {
 SLPreview *v=[self fixture];SLPlayer *p=[v valueForKey:@"player"];v.foreground=YES;[v setValue:@YES forKey:@"requested"];[self fail:v];XCTAssertTrue([[v valueForKey:@"recoveryScheduled"] boolValue]);[v reset];[self waitForRetry];XCTAssertEqual(p.replacements,0u);XCTAssertNil([v valueForKey:@"player"]);XCTAssertNil([v valueForKey:@"sourceURL"]);
}
- (void)testNoForegroundReopeningAndNoPausedSourceRetry {
 SLPreview *v=[self fixture];[v resumeAfterForeground];XCTAssertEqual(v.attempts,0u);[v setValue:@YES forKey:@"sourcePaused"];v.foreground=YES;[v setValue:@YES forKey:@"requested"];[self fail:v];XCTAssertFalse([[v valueForKey:@"recoveryScheduled"] boolValue]);[v reset];
}
- (void)testOldFailureCannotPoisonReplacedItem {
 SLPreview *v=[self fixture];SLPlayer *p=[v valueForKey:@"player"];id old=p.currentItem;[v installItemAtURL:[NSURL URLWithString:@"http://127.0.0.1:8080/media/resource/replacement"]];
 [NSNotificationCenter.defaultCenter postNotificationName:AVPlayerItemFailedToPlayToEndTimeNotification object:old];
 XCTAssertFalse([[v valueForKey:@"failedPlayback"] boolValue]);[v reset];
}
@end
