#import <Foundation/Foundation.h>
#import "SLWidgetRoute.h"
#include <assert.h>
int main(void){@autoreleasepool{
 assert(SLRouteForURL([NSURL URLWithString:@"screenlink://start-youtube"])==SLWidgetRouteStart);
 assert(SLRouteForURL([NSURL URLWithString:@"screenlink://disconnect-all"])==SLWidgetRouteDisconnect);
 assert(SLRouteForURL([NSURL URLWithString:@"screenlink://resume"])==SLWidgetRouteResume);
 for(NSString *value in @[@"https://start-youtube",@"screenlink://other",@"screenlink://start-youtube/extra",@"screenlink://user:pass@start-youtube",@"screenlink://start-youtube?record=true",@"screenlink://disconnect-all:8080",@"screenlink://resume#start"]){assert(SLRouteForURL([NSURL URLWithString:value])==SLWidgetRouteNone);}
 puts("Widget routes passed: explicit Start, Resume, Disconnect All; rejects foreign/unknown/credential/path/query/port/fragment routes. No background recording route exists.");
}return 0;}
