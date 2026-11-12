#import <Foundation/Foundation.h>
#import "../RTC/SLMediaProvider.h"
#import "http_request.h"
#import "http_response.h"
/// Native AirPlay media control and unprotected HLS delivery. No screen capture.
@interface MediaCast : NSObject <SLMediaProvider>
@property(nonatomic,copy) void (^status)(NSString *);
@property(nonatomic,copy) NSString *token;
@property(nonatomic,copy) NSString *deviceID;
/// Build 114: the quality the car will ask for (0 = Auto). Used to download the first pieces early.
@property(atomic) NSInteger warmHeight;
@property(nonatomic,readonly) BOOL active;
@property(nonatomic,readonly) BOOL videoIsLive;
- (BOOL)handle:(http_request_t *)request connection:(void *)connection socket:(int)socket response:(http_response_t **)response;
- (void)connectionClosed:(void *)connection;
- (NSDictionary *)state;
- (void)report:(NSDictionary *)report;
- (NSDictionary *)resource:(NSString *)identifier range:(NSString *)range;
- (void)stop;
/// Build 122 (TikTok): where the car is in the current video; and download a whole file video early.
+ (NSDictionary *)currentProgress;
+ (void)prefetchFile:(NSString *)location;
@end
