// Build 89: log events that need the user's action map to the right notification.
#import <Foundation/Foundation.h>
#import "StreamNotifier.h"
#include <assert.h>
int main(void){@autoreleasepool{
 NSDictionary *(^r)(NSString *)=^NSDictionary *(NSString *m){return [SLStreamNotifier ruleForMessage:m];};
 assert([r(@"YouTube PiP stopped. Return to ScreenLink to restore your selected PiP mode")[@"id"] isEqual:@"pip-stopped"]);
 assert([r(@"PIP NOT ACTIVE: the saved PiP request is not a running floating window.")[@"id"] isEqual:@"pip-missing"]);
 assert([r(@"PiP is inactive and background grace expired. Receiver remains armed")[@"id"] isEqual:@"grace"]);
 assert([r(@"WEBSITE SILENT: no HTTPS request from the car for 6 s.")[@"id"] isEqual:@"car-silent"]);
 assert([r(@"YOUTUBE SENT SOUND ONLY: YouTube is using ScreenLink as a speaker")[@"id"] isEqual:@"sound-only"]);
 assert([r(@"Built-in VPN disconnected. Reconnect here before using iPhone VPN discovery.")[@"id"] isEqual:@"vpn"]);
 assert([r(@"Local HTTPS not started: no website certificate in this build.")[@"id"] isEqual:@"cert"]);
 assert([r(@"AIRPLAY DISCOVERY BLOCKED: Local Network permission")[@"id"] isEqual:@"localnet"]);
 assert([r(@"CAR PLAYER: player error: Phone/media transport unavailable after retries: Failed to fetch at 135.2s")[@"id"] isEqual:@"car-error"]);
 assert([r(@"App backgrounded with floating preview active. Test whether the viewer keeps updating.")[@"id"] isEqual:@"tip-pip"]);
 // Normal or user-initiated events never notify.
 for(NSString *quiet in @[@"WEBSITE BACK: car HTTPS requests resumed after 7 s of silence.",@"ScreenLink VPN disconnected. Its saved configuration is retained.",@"DISCONNECT ALL CONFIRMED: sharing, PiP",@"MEDIA: sender stopped native playback.",@"CAR PLAYER: summary: webcodecs",@"YOUTUBE PiP ACTIVE: real received YouTube preview",@"MEDIA PLAYLIST RESPONSE: 3561 bytes",@"CAR PLAYER: player error: Media HTTP 410 at 0.0s",@"MEDIA: no reverse AirPlay channel. Re-select ScreenLink"])assert(r(quiet)==nil);
 for(NSDictionary *rule in @[r(@"YouTube PiP stopped"),r(@"WEBSITE SILENT"),r(@"Built-in VPN failed")]){assert([rule[@"title"] length]>5&&[rule[@"body"] length]>20&&[rule[@"cooldown"] doubleValue]>=60);}
 puts("Stream notifications passed: actionable events notify with clear steps; normal and user-initiated events stay quiet.");
}return 0;}
