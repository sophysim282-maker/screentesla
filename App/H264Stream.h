#import <Foundation/Foundation.h>
@interface H264Stream : NSObject
- (instancetype)initWithMaxBytes:(NSUInteger)bytes packets:(NSUInteger)packets;
- (void)configureSPS:(NSData *)sps PPS:(NSData *)pps width:(uint16_t)width height:(uint16_t)height;
- (void)appendAVCC:(NSData *)sample timestamp:(uint64_t)timestamp keyframe:(BOOL)keyframe;
- (NSDictionary *)info;
- (NSDictionary *)initialization;
- (NSDictionary *)readAfter:(uint64_t)sequence epoch:(NSString *)epoch;
@property(nonatomic,readonly) BOOL privacyHidden;
- (void)setPrivacyHidden:(BOOL)hidden notBefore:(uint64_t)timestamp;
- (BOOL)changePrivacyHidden:(BOOL)hidden notBefore:(uint64_t)timestamp expectedRevision:(NSUInteger)revision;
- (NSUInteger)privacyPermitForTimestamp:(uint64_t)timestamp;
- (void)appendAVCC:(NSData *)sample timestamp:(uint64_t)timestamp keyframe:(BOOL)keyframe privacyPermit:(NSUInteger)permit;
- (void)reset;
@end
