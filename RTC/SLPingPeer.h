#import <Foundation/Foundation.h>
@interface SLPingPeer : NSObject
@property(nonatomic,copy) void (^status)(NSString *);
@property(nonatomic,readonly) BOOL pingOK;
@property(nonatomic,copy) void (^mediaMessage)(NSData *,BOOL);
@property(nonatomic,copy) void (^mediaOpened)(void);
@property(nonatomic,readonly) uint64_t mediaBufferedAmount;
@property(nonatomic,readonly) BOOL mediaOpen;
@property(nonatomic,copy) void (^screenMessage)(NSData *,BOOL);
@property(nonatomic,copy) void (^screenOpened)(void);
@property(nonatomic,readonly) uint64_t screenBufferedAmount;
@property(nonatomic,readonly) BOOL screenOpen;
- (void)enableScreenChannel;
- (BOOL)sendScreen:(NSData *)data binary:(BOOL)binary;
- (instancetype)initWithHotspotOnly:(BOOL)strict offerer:(BOOL)offerer;
- (instancetype)initWithHotspotOnly:(BOOL)strict offerer:(BOOL)offerer dataOnly:(BOOL)dataOnly;
- (void)enableMediaChannel;
- (BOOL)sendMedia:(NSData *)data binary:(BOOL)binary;
- (BOOL)enableTestVideo:(NSError **)error;
- (void)offerRestart:(BOOL)restart completion:(void (^)(NSString *sdp,NSString *gathering,NSError *error))completion;
- (void)answerOffer:(NSString *)offer completion:(void (^)(NSString *sdp,NSString *gathering,NSError *error))completion;
- (void)applyAnswer:(NSString *)answer completion:(void (^)(NSError *))completion;
- (void)snapshot:(void (^)(NSDictionary *))completion;
- (void)close;
@end
