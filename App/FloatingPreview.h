#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>
@interface FloatingPreview : UIView
@property(nonatomic,copy) void (^status)(NSString *);
@property(nonatomic,copy) void (^activityChanged)(BOOL);
@property(nonatomic,readonly) BOOL active;
- (void)receivePixelBuffer:(CVPixelBufferRef)pixel;
- (void)startFloating;
- (void)reset;
@end
