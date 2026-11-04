#import "VPNDiscovery.h"
#import <dns_sd.h>
#import <arpa/inet.h>

@interface VPNDiscovery () {
    DNSServiceRef _addressConnection;
    DNSServiceRef _airplay;
    DNSServiceRef _raop;
    DNSServiceRef _verifyBrowse, _verifyResolve, _verifyAddress;
    NSString *_expectedName, *_expectedPeer;
    BOOL _resolvedPeer;
    NSUInteger _generation;
}
- (void)report:(NSString *)message;
- (void)foundService:(const char *)name type:(const char *)type domain:(const char *)domain;
- (void)resolveHost:(const char *)host port:(uint16_t)port;
- (void)verifiedAddress:(const struct sockaddr *)address;
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
static void browseReply(DNSServiceRef service, DNSServiceFlags flags, uint32_t interface,
                        DNSServiceErrorType error, const char *name, const char *type, const char *domain, void *context) {
    VPNDiscovery *owner=(__bridge VPNDiscovery *)context;
    if(error)[owner report:[NSString stringWithFormat:@"Local browse error: %d",error]];
    else if(flags & kDNSServiceFlagsAdd)[owner foundService:name type:type domain:domain];
}
static void resolveReply(DNSServiceRef service, DNSServiceFlags flags, uint32_t interface,
                         DNSServiceErrorType error, const char *fullname, const char *host, uint16_t port,
                         uint16_t txtLength, const unsigned char *txt, void *context) {
    VPNDiscovery *owner=(__bridge VPNDiscovery *)context;
    if(error)[owner report:[NSString stringWithFormat:@"Local service resolve error: %d",error]];
    else [owner resolveHost:host port:port];
}
static void lookupReply(DNSServiceRef service, DNSServiceFlags flags, uint32_t interface,
                        DNSServiceErrorType error, const char *host, const struct sockaddr *address,
                        uint32_t ttl, void *context) {
    VPNDiscovery *owner=(__bridge VPNDiscovery *)context;
    if(error)[owner report:[NSString stringWithFormat:@"Local address lookup error: %d",error]];
    else if(flags & kDNSServiceFlagsAdd)[owner verifiedAddress:address];
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
    _expectedName=profile[@"name"];_expectedPeer=profile[@"peer"];_resolvedPeer=NO;
    NSString *peer=profile[@"peer"],*host=profile[@"host"],*name=profile[@"name"];
    NSData *airplayTXT=encodedTXT(profile[@"airplayTXT"]),*raopTXT=encodedTXT(profile[@"raopTXT"]);
    struct in_addr address;
    if(inet_pton(AF_INET,peer.UTF8String,&address)!=1 || !airplayTXT.length || !raopTXT.length){[self report:@"Invalid VPN discovery profile."];return NO;}
    DNSServiceErrorType error=DNSServiceCreateConnection(&_addressConnection);
    DNSRecordRef record=NULL;
    if(!error)error=DNSServiceRegisterRecord(_addressConnection,&record,kDNSServiceFlagsUnique,kDNSServiceInterfaceIndexLocalOnly,
        host.UTF8String,kDNSServiceType_A,kDNSServiceClass_IN,sizeof address,&address,120,addressReply,(__bridge void *)self);
    if(!error)error=DNSServiceSetDispatchQueue(_addressConnection,dispatch_get_main_queue());
    uint16_t port=htons([profile[@"port"] unsignedShortValue]);
    if(!error)error=DNSServiceRegister(&_airplay,kDNSServiceFlagsNoAutoRename,kDNSServiceInterfaceIndexLocalOnly,
        name.UTF8String,"_airplay._tcp","local.",host.UTF8String,port,(uint16_t)airplayTXT.length,airplayTXT.bytes,serviceReply,(__bridge void *)self);
    if(!error)error=DNSServiceSetDispatchQueue(_airplay,dispatch_get_main_queue());
    if(!error)error=DNSServiceRegister(&_raop,kDNSServiceFlagsNoAutoRename,kDNSServiceInterfaceIndexLocalOnly,
        [profile[@"raopName"] UTF8String],"_raop._tcp","local.",host.UTF8String,port,(uint16_t)raopTXT.length,raopTXT.bytes,serviceReply,(__bridge void *)self);
    if(!error)error=DNSServiceSetDispatchQueue(_raop,dispatch_get_main_queue());
    if(error){[self report:[NSString stringWithFormat:@"Could not publish VPN discovery: %d. Mac VPN mode remains available.",error]];[self stop];return NO;}
    error=DNSServiceBrowse(&_verifyBrowse,0,kDNSServiceInterfaceIndexLocalOnly,"_airplay._tcp","local.",browseReply,(__bridge void *)self);
    if(!error)error=DNSServiceSetDispatchQueue(_verifyBrowse,dispatch_get_main_queue());
    if(error)[self report:[NSString stringWithFormat:@"Local discovery verification could not start: %d",error]];
    NSUInteger generation=_generation;__weak VPNDiscovery *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        VPNDiscovery *owner=weak;
        if(owner && owner->_generation==generation && owner->_airplay && !owner->_resolvedPeer)
            [owner report:@"Local proxy lookup has not completed after 5 seconds. Save this log; registration alone is not a successful lookup."];
    });
    [self report:[NSString stringWithFormat:@"LOCAL-ONLY iPhone VPN discovery requested: %@ → %@:%@. Keep ScreenLink Local VPN connected. Same-phone visibility still needs a test.",name,peer,profile[@"port"]]];
    return YES;
}
- (void)foundService:(const char *)name type:(const char *)type domain:(const char *)domain {
    if(_verifyResolve || ![_expectedName isEqualToString:[NSString stringWithUTF8String:name]])return;
    [self report:@"Local Bonjour browser found this proxy. Resolving its target next."];
    DNSServiceErrorType error=DNSServiceResolve(&_verifyResolve,0,kDNSServiceInterfaceIndexLocalOnly,name,type,domain,resolveReply,(__bridge void *)self);
    if(!error)error=DNSServiceSetDispatchQueue(_verifyResolve,dispatch_get_main_queue());
    if(error)[self report:[NSString stringWithFormat:@"Local resolve could not start: %d",error]];
}
- (void)resolveHost:(const char *)host port:(uint16_t)port {
    if(_verifyAddress)return;
    [self report:[NSString stringWithFormat:@"Local proxy target resolved: %s:%u",host,ntohs(port)]];
    DNSServiceErrorType error=DNSServiceGetAddrInfo(&_verifyAddress,0,kDNSServiceInterfaceIndexLocalOnly,kDNSServiceProtocol_IPv4,host,lookupReply,(__bridge void *)self);
    if(!error)error=DNSServiceSetDispatchQueue(_verifyAddress,dispatch_get_main_queue());
    if(error)[self report:[NSString stringWithFormat:@"Local address lookup could not start: %d",error]];
}
- (void)verifiedAddress:(const struct sockaddr *)address {
    if(!address || address->sa_family!=AF_INET)return;
    char text[INET_ADDRSTRLEN];const struct sockaddr_in *ipv4=(const void *)address;
    if(!inet_ntop(AF_INET,&ipv4->sin_addr,text,sizeof text))return;
    if([_expectedPeer isEqualToString:[NSString stringWithUTF8String:text]]) {
        _resolvedPeer=YES;
        [self report:[NSString stringWithFormat:@"Local proxy address verified: %s. DNS lookup passed; Screen Mirroring visibility and video are separate tests.",text]];
    } else [self report:[NSString stringWithFormat:@"Unexpected proxy address: %s (expected %@)",text,_expectedPeer]];
}
- (void)stop {
    _generation++;
    if(_verifyAddress){DNSServiceRefDeallocate(_verifyAddress);_verifyAddress=NULL;}
    if(_verifyResolve){DNSServiceRefDeallocate(_verifyResolve);_verifyResolve=NULL;}
    if(_verifyBrowse){DNSServiceRefDeallocate(_verifyBrowse);_verifyBrowse=NULL;}
    if(_airplay){DNSServiceRefDeallocate(_airplay);_airplay=NULL;}
    if(_raop){DNSServiceRefDeallocate(_raop);_raop=NULL;}
    if(_addressConnection){DNSServiceRefDeallocate(_addressConnection);_addressConnection=NULL;}
}
- (void)dealloc { [self stop]; }
@end
