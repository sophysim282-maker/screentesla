#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
@interface Receiver : NSObject
@property(nonatomic,copy) void (^status)(NSString *);
/// Delivered on the main queue, bounded to one pending live frame.
@property(nonatomic,copy) void (^preview)(CVPixelBufferRef);
@property(nonatomic,readonly,getter=isRunning) BOOL running;
@property(nonatomic,copy,readonly) NSString *token;
/// Set before start; the Mac helper advertises the VPN peer instead of the phone.
@property(nonatomic) BOOL externalDiscovery;
@property(nonatomic,copy,readonly) NSDictionary *discoveryProfile;
- (BOOL)start;
- (void)stop;
@end
