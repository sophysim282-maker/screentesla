#import "StreamNotifier.h"
#if __has_include(<UserNotifications/UserNotifications.h>)
#import <UserNotifications/UserNotifications.h>
#define SL_HAS_NOTIFICATIONS 1
#endif

@implementation SLStreamNotifier
+ (NSArray<NSDictionary *> *)rules {
 static NSArray *rules;static dispatch_once_t once;
 dispatch_once(&once,^{rules=@[
  @{@"prefix":@"YouTube PiP stopped",@"id":@"pip-stopped",@"title":@"Video window closed",
    @"body":@"The car video may stop soon. Tap to open ScreenLink and bring back the floating video (PiP).",@"cooldown":@60},
  @{@"prefix":@"PIP NOT ACTIVE",@"id":@"pip-missing",@"title":@"PiP is not running",
    @"body":@"Open ScreenLink and wait for “YOUTUBE PiP ACTIVE” before leaving, so iOS keeps the stream alive.",@"cooldown":@120},
  @{@"prefix":@"PiP is inactive and background grace expired",@"id":@"grace",@"title":@"ScreenLink may be paused",
    @"body":@"iOS can pause ScreenLink now and the car would stop. Tap to keep streaming.",@"cooldown":@60},
  @{@"prefix":@"YOUTUBE SENT SOUND ONLY",@"id":@"sound-only",@"title":@"YouTube sent sound only",
    @"body":@"The car gets no video. Tap the TV icon inside YouTube (top of the video) and choose ScreenLink VPN Phone. Not from Control Center.",@"cooldown":@60},
  @{@"prefix":@"CAR LEFT THE WI-FI",@"id":@"car-left",@"title":@"Car left the Wi-Fi",
    @"body":@"Check the car’s Wi-Fi icon and join this iPhone again. The video goes on when the car is back.",@"cooldown":@120},
  @{@"prefix":@"WEBSITE SILENT",@"id":@"car-silent",@"title":@"Car screen lost the connection",
    @"body":@"Keep the car on your iPhone hotspot Wi-Fi. If it does not come back, reload car.tesla4khmer.com/video on the car.",@"cooldown":@120},
  @{@"prefix":@"Built-in VPN disconnected",@"id":@"vpn",@"title":@"ScreenLink VPN is off",
    @"body":@"The car cannot reach your phone. Tap to open ScreenLink and press Start.",@"cooldown":@120},
  @{@"prefix":@"Built-in VPN failed",@"id":@"vpn",@"title":@"ScreenLink VPN could not connect",
    @"body":@"Tap to open ScreenLink and press Start. Accept the iOS VPN prompt if it appears.",@"cooldown":@120},
  @{@"prefix":@"VPN connection timed out",@"id":@"vpn",@"title":@"ScreenLink VPN could not connect",
    @"body":@"Tap to open ScreenLink and press Start again.",@"cooldown":@120},
  @{@"prefix":@"Local HTTPS not started",@"id":@"cert",@"title":@"Car website cannot start",
    @"body":@"The website certificate is missing or expired. Open ScreenLink → Developer → Import website certificate.",@"cooldown":@600},
  @{@"prefix":@"AIRPLAY DISCOVERY BLOCKED",@"id":@"localnet",@"title":@"Allow Local Network",
    @"body":@"Settings → ScreenLink → turn on Local Network, so YouTube can find ScreenLink.",@"cooldown":@600},
  @{@"prefix":@"CAR PLAYER: player error: Phone/media transport unavailable",@"id":@"car-error",@"title":@"Car video stopped",
    @"body":@"The car is retrying. If the screen stays black, reload the car page.",@"cooldown":@120},
  @{@"prefix":@"App backgrounded with floating preview active",@"id":@"tip-pip",@"title":@"ScreenLink keeps streaming",
    @"body":@"Keep the small video window (PiP) open — closing or pausing it can stop the car video. You can lock the phone.",@"cooldown":@43200},
  @{@"prefix":@"App backgrounded with a timed session active",@"id":@"tip-nopip",@"title":@"Start PiP to keep streaming",
    @"body":@"Without the floating video (PiP), iOS stops ScreenLink after a short time. Tap to open ScreenLink and start PiP.",@"cooldown":@300},
 ];});
 return rules;
}
+ (NSDictionary *)ruleForMessage:(NSString *)message {
 if(![message isKindOfClass:NSString.class])return nil;
 for(NSDictionary *rule in self.rules)if([message hasPrefix:rule[@"prefix"]])return rule;
 return nil;
}
+ (NSMutableDictionary *)lastShown {static NSMutableDictionary *last;static dispatch_once_t once;dispatch_once(&once,^{last=[NSMutableDictionary dictionary];});return last;}
+ (void)requestPermission {
#ifdef SL_HAS_NOTIFICATIONS
 [UNUserNotificationCenter.currentNotificationCenter requestAuthorizationWithOptions:UNAuthorizationOptionAlert|UNAuthorizationOptionSound|UNAuthorizationOptionBadge completionHandler:^(BOOL granted,NSError *error){}];
#endif
}
+ (void)handleLogMessage:(NSString *)message appActive:(BOOL)active {
 NSDictionary *rule=[self ruleForMessage:message];if(!rule||active)return;
 NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;NSString *key=rule[@"id"];
 @synchronized(self){NSNumber *last=self.lastShown[key];if(last&&now-last.doubleValue<[rule[@"cooldown"] doubleValue])return;self.lastShown[key]=@(now);}
#ifdef SL_HAS_NOTIFICATIONS
 UNMutableNotificationContent *content=[UNMutableNotificationContent new];content.title=rule[@"title"];content.body=rule[@"body"];content.sound=UNNotificationSound.defaultSound;content.threadIdentifier=@"screenlink.stream";
 if(@available(iOS 15.0,*))content.interruptionLevel=[key hasPrefix:@"tip"]?UNNotificationInterruptionLevelPassive:UNNotificationInterruptionLevelTimeSensitive;
 // Same identifier replaces an older alert of the same kind instead of stacking.
 UNNotificationRequest *request=[UNNotificationRequest requestWithIdentifier:[@"screenlink." stringByAppendingString:key] content:content trigger:nil];
 [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:nil];
#endif
}
@end
