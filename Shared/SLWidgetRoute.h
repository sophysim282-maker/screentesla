#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger,SLWidgetRoute){SLWidgetRouteNone,SLWidgetRouteStart,SLWidgetRouteResume,SLWidgetRouteDisconnect,SLWidgetRouteOpen,SLWidgetRouteMaps};
static inline SLWidgetRoute SLRouteForURL(NSURL *url){
 if(![url.scheme.lowercaseString isEqual:@"screenlink"]||url.user.length||url.password.length||url.port||url.query.length||url.fragment.length||url.path.length>1)return SLWidgetRouteNone;
 NSString *host=url.host.lowercaseString;
 if([host isEqual:@"start-youtube"])return SLWidgetRouteStart;
 if([host isEqual:@"resume"])return SLWidgetRouteResume;
 if([host isEqual:@"disconnect-all"])return SLWidgetRouteDisconnect;
 if([host isEqual:@"open"])return SLWidgetRouteOpen;
 if([host isEqual:@"maps"])return SLWidgetRouteMaps;
 return SLWidgetRouteNone;
}

