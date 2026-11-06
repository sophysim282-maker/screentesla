#import <Foundation/Foundation.h>
#import "SLWidgetRoute.h"
#include <assert.h>
int main(void){@autoreleasepool{
 assert(SLRouteForURL([NSURL URLWithString:@"screenlink3333://start-youtube"])==SLWidgetRouteStart);
 assert(SLRouteForURL([NSURL URLWithString:@"screenlink3333://disconnect-all"])==SLWidgetRouteDisconnect);
 assert(SLRouteForURL([NSURL URLWithString:@"screenlink3333://resume"])==SLWidgetRouteResume);
 for(NSString *value in @[@"screenlink://start-youtube",@"https://start-youtube",@"screenlink3333://other",@"screenlink3333://start-youtube/extra",@"screenlink3333://user:pass@start-youtube",@"screenlink3333://start-youtube?record=true",@"screenlink3333://disconnect-all:8080",@"screenlink3333://resume#start"]){assert(SLRouteForURL([NSURL URLWithString:value])==SLWidgetRouteNone);}
 puts("Widget routes passed: explicit Start, Resume, Disconnect All; rejects foreign/unknown/credential/path/query/port/fragment routes. No background recording route exists.");
}return 0;}
