#import "VPNDiscovery.h"
#import <dns_sd.h>
#import <arpa/inet.h>

@interface VPNDiscovery () {
    DNSServiceRef _addressConnection;
    DNSServiceRef _airplay;
    DNSServiceRef _raop;
}
- (void)report:(NSString *)message;
@end

static void addressReply(DNSServiceRef service, DNSRecordRef record, DNSServiceFlags flags,
                         DNSServiceErrorType error, void *context) {
    VPNDiscovery *owner=(__bridge VPNDiscovery *)context;
    [owner report:error?[NSString stringWithFormat:@"VPN address registration failed: %d",error]:@"VPN peer address registered. This is DNS publication, not yet an AirPlay connection."];
}
static void serviceReply(DNSServiceRef service, DNSServiceFlags flags, DNSServiceErrorType error,
                         const char *name, const char *type, const char *domain, void *context) {
    VPNDiscovery *owner=(__bridge VPNDiscovery *)context;
    if(error)[owner report:[NSString stringWithFormat:@"VPN service registration failed: %d. Save the test log.",error]];
    else [owner report:[NSString stringWithFormat:@"Published %s (%s) at the VPN peer. Check Screen Mirroring for ScreenLink VPN Phone.",name,type]];
}
static NSData *encodedTXT(NSArray<NSString *> *strings) {
    NSMutableData *data=[NSMutableData data];
    for(NSString *value in strings) {
        NSData *item=[value dataUsingEncoding:NSUTF8StringEncoding];
        if(!item || item.length>255 || data.length+item.length+1>65535)return nil;
        uint8_t size=(uint8_t)item.length;[data appendBytes:&size length:1];[data appendData:item];
    }
    return data;
}
@implementation VPNDiscovery
- (void)report:(NSString *)message { if(self.status)self.status(message); }
- (BOOL)startWithProfile:(NSDictionary *)profile {
    NSAssert(NSThread.isMainThread,@"Discovery must use the main queue");
    [self stop];
    NSString *peer=profile[@"peer"],*host=profile[@"host"],*name=profile[@"name"];
    NSData *airplayTXT=encodedTXT(profile[@"airplayTXT"]),*raopTXT=encodedTXT(profile[@"raopTXT"]);
    struct in_addr address;
    if(inet_pton(AF_INET,peer.UTF8String,&address)!=1 || !airplayTXT.length || !raopTXT.length){[self report:@"Invalid VPN discovery profile."];return NO;}
    DNSServiceErrorType error=DNSServiceCreateConnection(&_addressConnection);
    DNSRecordRef record=NULL;
    if(!error)error=DNSServiceRegisterRecord(_addressConnection,&record,kDNSServiceFlagsUnique,kDNSServiceInterfaceIndexAny,
        host.UTF8String,kDNSServiceType_A,kDNSServiceClass_IN,sizeof address,&address,120,addressReply,(__bridge void *)self);
    if(!error)error=DNSServiceSetDispatchQueue(_addressConnection,dispatch_get_main_queue());
    uint16_t port=htons([profile[@"port"] unsignedShortValue]);
    if(!error)error=DNSServiceRegister(&_airplay,kDNSServiceFlagsNoAutoRename,kDNSServiceInterfaceIndexAny,
        name.UTF8String,"_airplay._tcp","local.",host.UTF8String,port,(uint16_t)airplayTXT.length,airplayTXT.bytes,serviceReply,(__bridge void *)self);
    if(!error)error=DNSServiceSetDispatchQueue(_airplay,dispatch_get_main_queue());
    if(!error)error=DNSServiceRegister(&_raop,kDNSServiceFlagsNoAutoRename,kDNSServiceInterfaceIndexAny,
        [profile[@"raopName"] UTF8String],"_raop._tcp","local.",host.UTF8String,port,(uint16_t)raopTXT.length,raopTXT.bytes,serviceReply,(__bridge void *)self);
    if(!error)error=DNSServiceSetDispatchQueue(_raop,dispatch_get_main_queue());
    if(error){[self report:[NSString stringWithFormat:@"Could not publish VPN discovery: %d. Mac VPN mode remains available.",error]];[self stop];return NO;}
    [self report:[NSString stringWithFormat:@"iPhone VPN discovery requested: %@ → %@:%@. Keep LocalDevVPN connected. Same-phone visibility still needs a test.",name,peer,profile[@"port"]]];
    return YES;
}
- (void)stop {
    if(_airplay){DNSServiceRefDeallocate(_airplay);_airplay=NULL;}
    if(_raop){DNSServiceRefDeallocate(_raop);_raop=NULL;}
    if(_addressConnection){DNSServiceRefDeallocate(_addressConnection);_addressConnection=NULL;}
}
- (void)dealloc { [self stop]; }
@end
