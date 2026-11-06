#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger,NEVPNStatus){NEVPNStatusInvalid,NEVPNStatusDisconnected,NEVPNStatusConnecting,NEVPNStatusConnected,NEVPNStatusReasserting,NEVPNStatusDisconnecting};
FOUNDATION_EXPORT NSString *const NEVPNStatusDidChangeNotification;
@interface NEVPNConnection:NSObject
@property(nonatomic) NEVPNStatus status;
- (void)stopVPNTunnel;
- (BOOL)startVPNTunnelAndReturnError:(NSError **)error;
@end
@interface NETunnelProviderSession:NEVPNConnection
- (BOOL)sendProviderMessage:(NSData *)message returnError:(NSError **)error responseHandler:(void(^)(NSData *))handler;
@end
@interface NETunnelProviderProtocol:NSObject
@property(nonatomic,copy) NSString *providerBundleIdentifier,*serverAddress;
@property(nonatomic,copy) NSDictionary *providerConfiguration;
@property(nonatomic) BOOL disconnectOnSleep;
@end
@interface NETunnelProviderManager:NSObject
@property(nonatomic,strong) NETunnelProviderProtocol *protocolConfiguration;
@property(nonatomic,strong) NETunnelProviderSession *connection;
@property(nonatomic,copy) NSString *localizedDescription;
@property(nonatomic) BOOL enabled;
+ (void)loadAllFromPreferencesWithCompletionHandler:(void(^)(NSArray *,NSError *))completion;
- (void)saveToPreferencesWithCompletionHandler:(void(^)(NSError *))completion;
- (void)loadFromPreferencesWithCompletionHandler:(void(^)(NSError *))completion;
@end
