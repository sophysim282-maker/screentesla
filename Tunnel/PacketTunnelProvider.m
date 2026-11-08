#import <NetworkExtension/NetworkExtension.h>
#import <sys/socket.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import "LocalPacket.h"
#import "LocalDNS.h"
@interface PacketTunnelProvider : NEPacketTunnelProvider
@property(atomic) BOOL reading;
@property(atomic) BOOL routeProbe;
@property(atomic) NSUInteger virtualPacketsSeen;
@property(atomic) NSUInteger virtualTCPPackets;
@property(atomic) NSUInteger virtualUDPPackets;
@property(atomic) NSUInteger localDNSAnswers;
@end
@implementation PacketTunnelProvider
- (void)startTunnelWithOptions:(NSDictionary<NSString *,NSObject *> *)options completionHandler:(void (^)(NSError *))completionHandler {
    NEPacketTunnelNetworkSettings *settings=[[NEPacketTunnelNetworkSettings alloc]initWithTunnelRemoteAddress:@"10.7.0.1"];
    self.routeProbe=[((NETunnelProviderProtocol *)self.protocolConfiguration).providerConfiguration[@"routeProbe"] boolValue];
    self.virtualPacketsSeen=0;self.virtualTCPPackets=0;self.virtualUDPPackets=0;self.localDNSAnswers=0;
    // Optional owned alias only: does not configure the hotspot client's routes or DNS.
    NSArray *addresses=self.routeProbe?@[@"10.7.1.1",@"240.3.3.3"]:@[@"10.7.1.1"];
    NSArray *masks=self.routeProbe?@[@"255.255.255.255",@"255.255.255.255"]:@[@"255.255.255.255"];
    NEIPv4Settings *ipv4=[[NEIPv4Settings alloc]initWithAddresses:addresses subnetMasks:masks];
    ipv4.includedRoutes=@[[[NEIPv4Route alloc]initWithDestinationAddress:@"10.7.0.1" subnetMask:@"255.255.255.255"]];
    if(self.routeProbe)ipv4.includedRoutes=[ipv4.includedRoutes arrayByAddingObjectsFromArray:@[[[NEIPv4Route alloc]initWithDestinationAddress:@"240.3.3.3" subnetMask:@"255.255.255.255"],[[NEIPv4Route alloc]initWithDestinationAddress:@"10.7.0.53" subnetMask:@"255.255.255.255"]]];
    if(self.routeProbe){
        // Build 77: answer car.tesla4khmer.com locally (split DNS for that one name only),
        // so the car's website does not depend on an internet DNS answer.
        NEDNSSettings *dns=[[NEDNSSettings alloc]initWithServers:@[@"10.7.0.53"]];
        dns.matchDomains=@[@"car.tesla4khmer.com"];dns.matchDomainsNoSearch=YES;settings.DNSSettings=dns;
    }
    ipv4.excludedRoutes=@[NEIPv4Route.defaultRoute];
    settings.IPv4Settings=ipv4;settings.MTU=@1500;
    [self setTunnelNetworkSettings:settings completionHandler:^(NSError *error){
        if(!error){self.reading=YES;[self readNext];}
        completionHandler(error);
    }];
}
- (void)readNext {
    if(!self.reading)return;
    __weak PacketTunnelProvider *weak=self;
    [self.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> *packets,NSArray<NSNumber *> *protocols){
        PacketTunnelProvider *owner=weak;if(!owner || !owner.reading)return;
        NSMutableArray *output=[NSMutableArray array], *families=[NSMutableArray array];
        for(NSUInteger i=0;i<packets.count && i<protocols.count;i++) {
            if(protocols[i].intValue!=AF_INET)continue;
            NSMutableData *packet=[packets[i] mutableCopy];
            const uint8_t *bytes=packet.bytes;
            if(owner.routeProbe && packet.length>=20 && (bytes[0]>>4)==4 && bytes[16]==240 && bytes[17]==3 && bytes[18]==3 && bytes[19]==3){
                owner.virtualPacketsSeen++;if(bytes[9]==6)owner.virtualTCPPackets++;if(bytes[9]==17)owner.virtualUDPPackets++;
            }
            // Probe traffic observed in packetFlow is counted, not reflected or relayed.
            // A full TCP/IP proxy is intentionally not claimed by this experiment.
            if(owner.routeProbe){
                size_t length=packet.length;packet.length=length+64;
                size_t reply=SLAnswerLocalDNS(packet.mutableBytes,length,packet.length);
                if(reply){packet.length=reply;owner.localDNSAnswers++;[output addObject:packet];[families addObject:@(AF_INET)];continue;}
                packet.length=length;
            }
            if(SLReflectLocalPacket(packet.mutableBytes,packet.length)){[output addObject:packet];[families addObject:@(AF_INET)];}
        }
        if(output.count)[owner.packetFlow writePackets:output withProtocols:families];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{[owner readNext];});
    }];
}
- (void)handleAppMessage:(NSData *)messageData completionHandler:(void (^)(NSData *))completionHandler {
    NSString *command=[[NSString alloc]initWithData:messageData encoding:NSUTF8StringEncoding];
    BOOL aliasPresent=NO;struct ifaddrs *head=NULL;
    if(getifaddrs(&head)==0){for(struct ifaddrs *p=head;p;p=p->ifa_next)if(p->ifa_addr && p->ifa_addr->sa_family==AF_INET && ntohl(((struct sockaddr_in *)p->ifa_addr)->sin_addr.s_addr)==0xf0030303u)aliasPresent=YES;freeifaddrs(head);}
    NSDictionary *result=[command isEqual:@"route-probe-status"]?@{@"settingsAccepted":@(self.reading),@"experimentalAliasRequested":@(self.routeProbe),@"aliasPresentInInterfaces":@(aliasPresent),@"virtualPacketsSeen":@(self.virtualPacketsSeen),@"virtualTCPPackets":@(self.virtualTCPPackets),@"virtualUDPPackets":@(self.virtualUDPPackets),@"localDNSAnswers":@(self.localDNSAnswers),@"teslaReachabilityVerified":@NO}:@{@"error":@"unknown command"};
    if(completionHandler)completionHandler([NSJSONSerialization dataWithJSONObject:result options:0 error:nil]);
}
- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    self.reading=NO;completionHandler();
}
@end
