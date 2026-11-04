#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
typedef NS_ENUM(NSInteger, SLDiscoveryMode) {
    SLDiscoveryNative=0,
    SLDiscoveryMacVPN=1,
    SLDiscoveryPhoneVPN=2
};
typedef NS_ENUM(NSInteger, SLVideoProfile) { SLVideoFast=0, SLVideoBalanced=1, SLVideoSharp=2 };
@class H264Stream;
@interface Receiver : NSObject
@property(nonatomic,copy) void (^status)(NSString *);
/// Delivered on the main queue, bounded to one pending live frame.
@property(nonatomic,copy) void (^preview)(CVPixelBufferRef);
@property(nonatomic,readonly,getter=isRunning) BOOL running;
@property(nonatomic,copy,readonly) NSString *token;
/// Set before start. Both VPN modes use the external peer as the service target.
@property(nonatomic) SLDiscoveryMode discoveryMode;
@property(nonatomic) SLVideoProfile videoProfile;
/// H.264 forwarding without local GPU/VideoToolbox work in a continued task.
@property(nonatomic) BOOL compressedOnlyInBackground;
@property(nonatomic,readonly) BOOL videoIsLive;
@property(nonatomic,readonly) BOOL externalDiscovery;
@property(nonatomic,copy,readonly) NSDictionary *discoveryProfile;
@property(nonatomic,strong,readonly) H264Stream *screenStream;
@property(nonatomic,copy) void (^broadcastStop)(void);
@property(nonatomic,readonly) BOOL screenHidden;
- (void)setScreenHidden:(BOOL)hidden;
- (void)screenFrameWithOrientation:(NSInteger)orientation;
- (void)broadcastMessage:(NSString *)message;
@property(nonatomic) BOOL mediaOnly;
- (void)prepareMediaOnly;
- (void)authorizeNextLocalViewer;
- (BOOL)start;
- (void)refreshDiscovery;
- (void)stop;
@end
