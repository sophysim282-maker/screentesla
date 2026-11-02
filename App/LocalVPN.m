#import "LocalVPN.h"
#import <NetworkExtension/NetworkExtension.h>
@interface LocalVPN ()
@property(nonatomic,strong) NETunnelProviderManager *manager;
@property(nonatomic,copy) void (^pending)(BOOL);
@property(nonatomic) BOOL busy;
@property(nonatomic) NSUInteger attempt;
@end
@implementation LocalVPN
- (instancetype)init {
    if((self=[super init]))[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(changed:) name:NEVPNStatusDidChangeNotification object:nil];
    return self;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (BOOL)connected { return self.manager.connection.status==NEVPNStatusConnected; }
- (NSString *)providerIdentifier {
    NSURL *plugins=NSBundle.mainBundle.builtInPlugInsURL;
    for(NSURL *url in [NSFileManager.defaultManager contentsOfDirectoryAtURL:plugins includingPropertiesForKeys:nil options:0 error:nil]) {
        NSBundle *bundle=[NSBundle bundleWithURL:url];
        if([bundle.infoDictionary[@"NSExtension"][@"NSExtensionPointIdentifier"] isEqual:@"com.apple.networkextension.packet-tunnel"])return bundle.bundleIdentifier;
    }
    return nil;
}
- (void)report:(NSString *)message { if(self.status)self.status(message); }
- (void)complete:(BOOL)ok {
    self.busy=NO;void (^callback)(BOOL)=self.pending;self.pending=nil;if(callback)callback(ok);
}
- (void)failed:(NSError *)error {
    [self report:[NSString stringWithFormat:@"Built-in VPN failed: %@ (%@/%ld). In KravaSign, keep the embedded VPN extension and sign both targets with a profile allowing packet-tunnel-provider. Disconnect any other VPN before retrying.",error.localizedDescription,error.domain,(long)error.code]];
    [self complete:NO];
}
- (void)connect:(void (^)(BOOL))completion {
    if(self.connected){if(completion)completion(YES);return;}
    if(self.busy){[self report:@"VPN setup is already in progress. Wait for Connected before starting AirPlay."];return;}
    NSString *identifier=[self providerIdentifier];
    if(!identifier){[self report:@"VPN extension is missing from this installation. Re-sign the complete IPA with its embedded extension retained."];if(completion)completion(NO);return;}
    self.busy=YES;self.pending=completion;NSUInteger attempt=++self.attempt;
    [self report:@"Setting up ScreenLink local VPN. Allow iOS to add the VPN configuration when prompted. This routes only 10.7.0.1; no external VPN server or Internet routing is used."];
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> *managers,NSError *error){dispatch_async(dispatch_get_main_queue(),^{
        if(attempt!=self.attempt)return;
        if(error){[self failed:error];return;}
        NETunnelProviderManager *manager=nil;
        for(NETunnelProviderManager *candidate in managers)if([((NETunnelProviderProtocol *)candidate.protocolConfiguration).providerBundleIdentifier isEqual:identifier]){manager=candidate;break;}
        self.manager=manager?:[NETunnelProviderManager new];
        if(self.connected){[self report:@"Built-in VPN connected: 10.7.1.1 ↔ 10.7.0.1."];[self complete:YES];return;}
        NETunnelProviderProtocol *config=[NETunnelProviderProtocol new];config.providerBundleIdentifier=identifier;config.serverAddress=@"ScreenLink local peer";config.disconnectOnSleep=NO;
        self.manager.protocolConfiguration=config;self.manager.localizedDescription=@"ScreenLink Local VPN";self.manager.enabled=YES;
        [self.manager saveToPreferencesWithCompletionHandler:^(NSError *saveError){dispatch_async(dispatch_get_main_queue(),^{
            if(attempt!=self.attempt)return;
            if(saveError){[self failed:saveError];return;}
            [self.manager loadFromPreferencesWithCompletionHandler:^(NSError *loadError){dispatch_async(dispatch_get_main_queue(),^{
                if(attempt!=self.attempt)return;
                if(loadError){[self failed:loadError];return;}
                NSError *startError=nil;
                if(![self.manager.connection startVPNTunnelAndReturnError:&startError]){[self failed:startError];return;}
                [self report:@"Built-in VPN connecting…"];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,30*NSEC_PER_SEC),dispatch_get_main_queue(),^{
                    if(self.busy && attempt==self.attempt){[self report:@"VPN connection timed out. Check the VPN entitlement and embedded extension in your signer, then reconnect."];[self complete:NO];}
                });
            });}];
        });}];
    });}];
}
- (void)changed:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(),^{
        if(notification.object!=self.manager.connection)return;
        switch(self.manager.connection.status) {
            case NEVPNStatusConnected:[self report:@"BUILT-IN VPN CONNECTED: 10.7.1.1 ↔ 10.7.0.1. LocalDevVPN is not required. The VPN does not extend the receiver app's background runtime."];[self complete:YES];break;
            case NEVPNStatusDisconnected:case NEVPNStatusInvalid:[self report:@"Built-in VPN disconnected. Reconnect here before using iPhone VPN discovery."];break;
            case NEVPNStatusReasserting:[self report:@"Built-in VPN reconnecting…"];break;
            default:break;
        }
    });
}
- (void)disconnect {
    self.attempt++;[self.manager.connection stopVPNTunnel];[self complete:NO];[self report:@"Built-in VPN disconnect requested. Its saved configuration remains available in iOS Settings → VPN."];
}
@end
