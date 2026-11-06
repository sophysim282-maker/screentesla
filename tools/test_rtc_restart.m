#import <Foundation/Foundation.h>
#import "SLMediaSession.h"
@interface SLMediaSession (RestartTest)
- (void)restart;
@end
@interface FailedGatherPeer : NSObject
@property(nonatomic) NSUInteger attempts;
@property(nonatomic) BOOL mediaOpen,screenOpen;
- (void)offerRestart:(BOOL)restart completion:(void (^)(NSString *,NSString *,NSError *))completion;
- (void)close;
@end
@implementation FailedGatherPeer
- (void)offerRestart:(BOOL)restart completion:(void (^)(NSString *,NSString *,NSError *))completion {self.attempts++;completion(nil,@"timeout",[NSError errorWithDomain:@"fixture" code:1 userInfo:@{NSLocalizedDescriptionKey:@"No candidate fixture"}]);}
- (void)close {}
@end
static void require(BOOL value,NSString *why){if(!value)@throw [NSException exceptionWithName:@"RestartRegression" reason:why userInfo:nil];}
int main(void){@autoreleasepool{SLMediaSession *host=[[SLMediaSession alloc]initWithMedia:nil hotspotOnly:NO];FailedGatherPeer *fake=[FailedGatherPeer new];[host setValue:fake forKey:@"peer"];[host setValue:@"fixture-session" forKey:@"sessionId"];[host setValue:@1 forKey:@"revision"];
 @try {
  for(NSUInteger i=0;i<10;i++)[host restart];require(fake.attempts==1,@"Same server restart request repeatedly reset ICE");require([[[host control:@"status"] objectForKey:@"phase"] isEqual:@"failed"],@"Failed restart still claimed connecting");
  [host setValue:@2 forKey:@"revision"];[host restart];require(fake.attempts==2,@"A new revision was not allowed");[host setValue:@3 forKey:@"revision"];[host restart];require(fake.attempts==2,@"Session restart budget was unbounded");
  [host control:@"stop"];require([[host valueForKey:@"restartCount"] unsignedIntegerValue]==0&&[[host valueForKey:@"lastRestartRevision"] unsignedIntegerValue]==0,@"New-session retry state was not reset");
  puts("ICE restart regression passed: repeated failed request processed once, new revision allowed, session budget bounded, failure honest and Stop resets fence.");
 }@catch(NSException *error){fprintf(stderr,"Restart regression failed: %s\n",error.reason.UTF8String);return 1;}return 0;
}}
