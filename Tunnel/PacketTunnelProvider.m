#import <NetworkExtension/NetworkExtension.h>
#import <sys/socket.h>
#import "LocalPacket.h"
@interface PacketTunnelProvider : NEPacketTunnelProvider
@property(atomic) BOOL reading;
@end
@implementation PacketTunnelProvider
- (void)startTunnelWithOptions:(NSDictionary<NSString *,NSObject *> *)options completionHandler:(void (^)(NSError *))completionHandler {
    NEPacketTunnelNetworkSettings *settings=[[NEPacketTunnelNetworkSettings alloc]initWithTunnelRemoteAddress:@"10.7.0.1"];
    NEIPv4Settings *ipv4=[[NEIPv4Settings alloc]initWithAddresses:@[@"10.7.1.1"] subnetMasks:@[@"255.255.255.255"]];
    ipv4.includedRoutes=@[[[NEIPv4Route alloc]initWithDestinationAddress:@"10.7.0.1" subnetMask:@"255.255.255.255"]];
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
            if(SLReflectLocalPacket(packet.mutableBytes,packet.length)){[output addObject:packet];[families addObject:@(AF_INET)];}
        }
        if(output.count)[owner.packetFlow writePackets:output withProtocols:families];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{[owner readNext];});
    }];
}
- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    self.reading=NO;completionHandler();
}
@end
