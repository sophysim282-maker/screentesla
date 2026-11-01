#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
@interface Receiver : NSObject
@property(nonatomic,copy) void (^status)(NSString *);
/// Delivered on the main queue, bounded to one pending live frame.
@property(nonatomic,copy) void (^preview)(CVPixelBufferRef);
@property(nonatomic,readonly,getter=isRunning) BOOL running;
@property(nonatomic,copy,readonly) NSString *token;
- (BOOL)start;
- (void)stop;
@end
