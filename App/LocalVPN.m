#import "LocalVPN.h"
#import <NetworkExtension/NetworkExtension.h>
@interface LocalVPN ()
@property(nonatomic,strong) NETunnelProviderManager *manager;
@property(nonatomic,copy) void (^pending)(BOOL);
@property(nonatomic) BOOL busy;
@property(nonatomic) NSUInteger attempt;
@property(nonatomic,readwrite) BOOL disconnecting;
@property(nonatomic) BOOL stopRequested;
@property(nonatomic) NSUInteger quietSamples;
@property(nonatomic,strong) NSArray *ownedConnections;
@property(nonatomic) NSUInteger dnsWatchSerial;
@property(nonatomic) NSInteger dnsAnswersSeen;
@property(nonatomic) BOOL dnsWatchReplied;
@property(nonatomic) NSUInteger dnsWatchMisses;
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
- (void)connect:(void (^)(BOOL))completion { [self connectMode:NO completion:completion]; }
- (void)connectRouteProbe:(void (^)(BOOL))completion { [self connectMode:YES completion:completion]; }
- (void)waitForAliasDisconnect:(void (^)(BOOL))completion attempts:(NSUInteger)attempts generation:(NSUInteger)generation {if(generation!=self.attempt||self.disconnecting)return;if(self.manager.connection.status==NEVPNStatusDisconnected||self.manager.connection.status==NEVPNStatusInvalid){[self connectMode:YES completion:completion];return;}if(!attempts){if(completion)completion(NO);return;}dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self waitForAliasDisconnect:completion attempts:attempts-1 generation:generation];});}
- (BOOL)acceptConnectedMode:(BOOL)probe completion:(void (^)(BOOL))completion {
    BOOL activeProbe=[((NETunnelProviderProtocol *)self.manager.protocolConfiguration).providerConfiguration[@"routeProbe"] boolValue];
    if(probe && !activeProbe){[self.manager.connection stopVPNTunnel];[self waitForAliasDisconnect:completion attempts:20 generation:self.attempt];return YES;}
    [self report:activeProbe?@"EXPERIMENTAL virtual-IP probe VPN is active. This is not a verified Tesla connection.":@"Built-in VPN is connected."];
    if(completion)completion(YES);return YES;
}
- (void)connectMode:(BOOL)probe completion:(void (^)(BOOL))completion {
    if(self.disconnecting){[self report:@"VPN is disconnecting. Wait for confirmation before starting again."];if(completion)completion(NO);return;}
    self.stopRequested=NO;self.ownedConnections=nil;
    if(self.connected){[self acceptConnectedMode:probe completion:completion];return;}
    if(self.busy){[self report:@"VPN setup is already in progress. Wait for Connected before starting AirPlay."];if(completion)completion(NO);return;}
    NSString *identifier=[self providerIdentifier];
    if(!identifier){[self report:@"VPN extension is missing from this installation. Re-sign the complete IPA with its embedded extension retained."];if(completion)completion(NO);return;}
    self.busy=YES;self.pending=completion;NSUInteger attempt=++self.attempt;
    [self report:probe?@"EXPERIMENTAL ROUTE PROBE: requesting additional local virtual address 3.3.3.3. No default Internet route or media relay is added; the VPN answers name lookups for car.tesla4khmer.com with 3.3.3.3 (build 77). iOS may reject it; Tesla reachability is unverified.":@"Setting up ScreenLink local VPN. Allow iOS to add the VPN configuration when prompted. This routes only 10.7.0.1; no external VPN server or Internet routing is used."];
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> *managers,NSError *error){dispatch_async(dispatch_get_main_queue(),^{
        if(attempt!=self.attempt)return;
        if(error){[self failed:error];return;}
        NETunnelProviderManager *manager=nil;
        for(NETunnelProviderManager *candidate in managers)if([((NETunnelProviderProtocol *)candidate.protocolConfiguration).providerBundleIdentifier isEqual:identifier]){manager=candidate;break;}
        self.manager=manager?:[NETunnelProviderManager new];
        if(self.connected){[self acceptConnectedMode:probe completion:^(BOOL ok){[self complete:ok];}];return;}
        if(self.manager.connection.status!=NEVPNStatusDisconnected && self.manager.connection.status!=NEVPNStatusInvalid){[self report:@"Wait for the VPN to finish disconnecting before changing route mode."];[self complete:NO];return;}
        NETunnelProviderProtocol *config=[NETunnelProviderProtocol new];config.providerBundleIdentifier=identifier;config.serverAddress=@"ScreenLink local peer";config.disconnectOnSleep=NO;config.providerConfiguration=@{@"routeProbe":@(probe)};
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
        if(notification.object!=self.manager.connection&&![self.ownedConnections containsObject:notification.object])return;
        if(self.stopRequested){NEVPNConnection *connection=notification.object;if(connection.status!=NEVPNStatusDisconnected&&connection.status!=NEVPNStatusInvalid)[connection stopVPNTunnel];return;}
        switch(self.manager.connection.status) {
            case NEVPNStatusConnected:[self report:@"BUILT-IN VPN CONNECTED: 10.7.1.1 ↔ 10.7.0.1. LocalDevVPN is not required. The VPN does not extend the receiver app's background runtime."];[self complete:YES];[self routeProbeStatus];[self startDNSWatch];break;
            case NEVPNStatusDisconnected:case NEVPNStatusInvalid:[self report:@"Built-in VPN disconnected. Reconnect here before using iPhone VPN discovery."];break;
            case NEVPNStatusReasserting:[self report:@"Built-in VPN reconnecting…"];break;
            default:break;
        }
    });
}
- (void)routeProbeStatus {
    if(!self.connected){[self report:@"Route probe status unavailable: VPN is not connected."];return;}
    NETunnelProviderSession *session=(NETunnelProviderSession *)self.manager.connection;
    NSError *error=nil;
    BOOL sent=[session sendProviderMessage:[@"route-probe-status" dataUsingEncoding:NSUTF8StringEncoding] returnError:&error responseHandler:^(NSData *data){
        NSString *value=data.length?[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]:@"No provider response";
        dispatch_async(dispatch_get_main_queue(),^{[self report:[@"VPN ROUTE PROBE STATUS: " stringByAppendingString:value?:@"Invalid response"]];});
    }];
    if(!sent)[self report:[NSString stringWithFormat:@"Route probe status failed: %@",error.localizedDescription?:@"message not sent"]];
}
// Build 92: CAR DNS log. Every 5 s, ask the VPN how many name questions for
// car.tesla4khmer.com it answered, and log new ones. If the website loses the phone and no
// new CAR DNS line appears around that time, the car did not ask the phone for the name.
- (void)startDNSWatch {
    self.dnsWatchSerial++;self.dnsAnswersSeen=-1;self.dnsWatchReplied=NO;self.dnsWatchMisses=0;
    NSUInteger serial=self.dnsWatchSerial;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(3*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self dnsWatchTick:serial];});
}
- (void)dnsWatchTick:(NSUInteger)serial {
    if(serial!=self.dnsWatchSerial||!self.connected)return;
    NETunnelProviderSession *session=(NETunnelProviderSession *)self.manager.connection;
    [session sendProviderMessage:[@"dns-status" dataUsingEncoding:NSUTF8StringEncoding] returnError:nil responseHandler:^(NSData *data){
        NSDictionary *reply=data.length?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
        dispatch_async(dispatch_get_main_queue(),^{
            if(serial!=self.dnsWatchSerial)return;
            if(![reply isKindOfClass:NSDictionary.class]){self.dnsWatchMisses++;if(self.dnsWatchMisses==3)[self report:@"CAR DNS WATCH: the VPN does not answer status requests (no provider response), so name lookups cannot be counted on this phone. This does not stop the website."];return;}
            NSInteger total=[reply[@"localDNSAnswers"] integerValue];
            if(!self.dnsWatchReplied){self.dnsWatchReplied=YES;[self report:[NSString stringWithFormat:@"CAR DNS WATCH: VPN answers car.tesla4khmer.com → 3.3.3.3 (kept 1 day). %ld answered so far.",(long)total]];}
            else if(total>self.dnsAnswersSeen)[self report:[NSString stringWithFormat:@"CAR DNS: car.tesla4khmer.com → 3.3.3.3 answered by the phone VPN (%ld new, %ld total).",(long)(total-self.dnsAnswersSeen),(long)total]];
            self.dnsAnswersSeen=total;
        });
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self dnsWatchTick:serial];});
}
- (void)waitForOwnManagers:(NSArray<NETunnelProviderManager *> *)managers generation:(NSUInteger)generation remaining:(NSUInteger)remaining completion:(void (^)(BOOL))completion {
    if(generation!=self.attempt)return;
    BOOL stopped=YES;
    for(NETunnelProviderManager *manager in managers)if(manager.connection.status!=NEVPNStatusDisconnected&&manager.connection.status!=NEVPNStatusInvalid){stopped=NO;[manager.connection stopVPNTunnel];}
    self.quietSamples=stopped?self.quietSamples+1:0;
    if((stopped&&self.quietSamples>=3)||!remaining){
        self.disconnecting=NO;
        [self report:stopped?@"ScreenLink VPN disconnected. Its saved configuration is retained.":@"ScreenLink VPN disconnect is not confirmed. Check iOS Settings → VPN."];
        if(completion)completion(stopped);return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self waitForOwnManagers:managers generation:generation remaining:remaining-1 completion:completion];});
}
- (NSTimeInterval)disconnectDeadline {return 12;}
- (void)disconnectWithCompletion:(void (^)(BOOL))completion {
    if(self.disconnecting){if(completion)completion(NO);return;}
    self.disconnecting=YES;self.stopRequested=YES;self.quietSamples=0;NSUInteger generation=++self.attempt;[self complete:NO];
    NSString *identifier=[self providerIdentifier];
    if(!identifier.length){self.disconnecting=NO;[self report:@"ScreenLink VPN ownership cannot be verified: embedded extension missing. No other VPN was changed."];if(completion)completion(NO);return;}
    if(self.manager&&[((NETunnelProviderProtocol *)self.manager.protocolConfiguration).providerBundleIdentifier isEqual:identifier])[self.manager.connection stopVPNTunnel];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)([self disconnectDeadline]*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if(!self.disconnecting||generation!=self.attempt)return;
        self.attempt++;self.disconnecting=NO;
        [self report:@"ScreenLink VPN disconnect confirmation timed out. Automatic restart remains blocked; check iOS Settings → VPN."];
        if(completion)completion(NO);
    });
    [self report:@"Disconnecting ScreenLink VPN…"];
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> *all,NSError *error){dispatch_async(dispatch_get_main_queue(),^{
        if(generation!=self.attempt)return;
        if(error){self.disconnecting=NO;[self report:@"ScreenLink VPN disconnect could not be confirmed: saved configurations could not be read."];if(completion)completion(NO);return;}
        NSMutableArray *ours=[NSMutableArray array];
        for(NETunnelProviderManager *manager in all)if([((NETunnelProviderProtocol *)manager.protocolConfiguration).providerBundleIdentifier isEqual:identifier])[ours addObject:manager];
        if(self.manager&&[((NETunnelProviderProtocol *)self.manager.protocolConfiguration).providerBundleIdentifier isEqual:identifier]&&![ours containsObject:self.manager])[ours addObject:self.manager];
        self.ownedConnections=[ours valueForKey:@"connection"];if(!self.manager&&ours.count)self.manager=ours.firstObject;
        [self waitForOwnManagers:ours generation:generation remaining:50 completion:completion];
    });}];
}
- (void)disconnect {[self disconnectWithCompletion:nil];}
@end
