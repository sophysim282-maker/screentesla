#import <Foundation/Foundation.h>
@interface SLPingPeer : NSObject
@property(nonatomic,copy) void (^status)(NSString *);
@property(nonatomic,readonly) BOOL pingOK;
- (instancetype)initWithHotspotOnly:(BOOL)strict offerer:(BOOL)offerer;
- (BOOL)enableTestVideo:(NSError **)error;
- (void)offerRestart:(BOOL)restart completion:(void (^)(NSString *sdp,NSString *gathering,NSError *error))completion;
- (void)answerOffer:(NSString *)offer completion:(void (^)(NSString *sdp,NSString *gathering,NSError *error))completion;
- (void)applyAnswer:(NSString *)answer completion:(void (^)(NSError *))completion;
- (void)snapshot:(void (^)(NSDictionary *))completion;
- (void)close;
@end
