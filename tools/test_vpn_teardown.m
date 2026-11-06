#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>
#import "LocalVPN.h"
#include <assert.h>
NSString *const NEVPNStatusDidChangeNotification=@"FakeVPNStatus";
static NSArray *savedManagers;static NSMutableArray *loads;static NSUInteger starts,stops,otherStops;
@implementation NEVPNConnection
- (void)stopVPNTunnel {stops++;self.status=NEVPNStatusDisconnected;}
- (BOOL)startVPNTunnelAndReturnError:(NSError **)error {starts++;self.status=NEVPNStatusConnecting;return YES;}
@end
@implementation NETunnelProviderSession
- (BOOL)sendProviderMessage:(NSData *)m returnError:(NSError **)e responseHandler:(void(^)(NSData *))handler {if(handler)handler([@"{}" dataUsingEncoding:NSUTF8StringEncoding]);return YES;}
@end
@implementation NETunnelProviderProtocol @end
@implementation NETunnelProviderManager
- (instancetype)init {if((self=[super init])){self.connection=[NETunnelProviderSession new];self.connection.status=NEVPNStatusDisconnected;}return self;}
+ (void)loadAllFromPreferencesWithCompletionHandler:(void(^)(NSArray *,NSError *))completion {[loads addObject:[completion copy]];}
- (void)saveToPreferencesWithCompletionHandler:(void(^)(NSError *))c {c(nil);}
- (void)loadFromPreferencesWithCompletionHandler:(void(^)(NSError *))c {c(nil);}
@end
@interface OtherSession:NETunnelProviderSession @end
@implementation OtherSession
- (void)stopVPNTunnel {otherStops++;[super stopVPNTunnel];}
@end
@interface TestVPN:LocalVPN @end
@implementation TestVPN
- (NSString *)providerIdentifier {return @"test.own";}
@end
static void drain(double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];}
static NETunnelProviderManager *manager(NSString *identifier,BOOL other){NETunnelProviderManager *m=[NETunnelProviderManager new];m.protocolConfiguration=[NETunnelProviderProtocol new];m.protocolConfiguration.providerBundleIdentifier=identifier;m.protocolConfiguration.providerConfiguration=@{@"routeProbe":@NO};if(other)m.connection=[OtherSession new];m.connection.status=NEVPNStatusConnected;return m;}
static void deliver(NSUInteger index){void(^c)(NSArray *,NSError *)=loads[index];c(savedManagers,nil);drain(.05);}
int main(void){@autoreleasepool{
 loads=[NSMutableArray array];NETunnelProviderManager *ours=manager(@"test.own",NO),*other=manager(@"other.vpn",YES);savedManagers=@[ours,other];TestVPN *vpn=[TestVPN new];
 __block NSUInteger callbacks=0;[vpn connectRouteProbe:^(BOOL ok){callbacks++;}];assert(loads.count==1);
 __block BOOL finished=NO,confirmed=NO;[vpn disconnectWithCompletion:^(BOOL ok){finished=YES;confirmed=ok;}];assert(vpn.disconnecting&&loads.count==2&&callbacks==1);
 deliver(0);assert(starts==0); // preferences load from cancelled start cannot start anything
 deliver(1);drain(.6);assert(finished&&confirmed&&!vpn.disconnecting&&otherStops==0&&other.connection.status==NEVPNStatusConnected);
 // A late system Connected notification after disconnect is stopped again.
 ours.connection.status=NEVPNStatusConnected;[NSNotificationCenter.defaultCenter postNotificationName:NEVPNStatusDidChangeNotification object:ours.connection];drain(.05); // manager may not be cached if original load cancelled
 assert(otherStops==0&&ours.connection.status==NEVPNStatusDisconnected);
 // Enter connected alias-mode transition, then disconnect during its delayed retry.
 ours.connection.status=NEVPNStatusConnected;[vpn connectRouteProbe:^(BOOL ok){callbacks++;}];deliver(2);assert(ours.connection.status==NEVPNStatusDisconnected); // alias transition stopped existing VPN
 finished=NO;[vpn disconnectWithCompletion:^(BOOL ok){finished=YES;confirmed=ok;}];deliver(3);drain(1.2);assert(finished&&confirmed&&starts==0&&otherStops==0);
 assert(savedManagers.count==2);puts("VPN teardown passed: cancelled preferences callback, alias retry generation, confirmed own-VPN stop, unrelated VPN preservation, saved configurations retained and no delayed reconnect.");
}return 0;}
