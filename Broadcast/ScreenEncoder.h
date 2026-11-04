#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
@class H264Stream;
@interface ScreenEncoder : NSObject
@property(nonatomic,copy) void (^frameEncoded)(NSInteger orientation);
@property(nonatomic,copy) void (^failed)(NSString *);
- (instancetype)initWithStream:(H264Stream *)stream;
- (void)consume:(CMSampleBufferRef)sample orientation:(NSInteger)orientation;
- (void)stop;
@end
