#import <Foundation/Foundation.h>
#import "VPNDiscovery.h"
#import <dns_sd.h>
#include <assert.h>
struct FakeDNSRef {BOOL live;ServiceReply service;void *context;};
static struct FakeDNSRef refs[128];static NSUInteger created,closed;static BOOL failCreate,failBrowse,failResolve,failLookup;
@interface VPNDiscovery (TestCallbacks)
- (void)foundService:(const char *)name type:(const char *)type domain:(const char *)domain;
- (void)resolveHost:(const char *)host port:(uint16_t)port;
@end
static DNSServiceRef makeRef(void){assert(created<128);DNSServiceRef r=&refs[created++];r->live=YES;return r;}
DNSServiceErrorType DNSServiceCreateConnection(DNSServiceRef *r){if(failCreate)return kDNSServiceErr_ServiceNotRunning;*r=makeRef();return 0;}
DNSServiceErrorType DNSServiceRegisterRecord(DNSServiceRef r,DNSRecordRef *record,DNSServiceFlags flags,uint32_t interface,const char *host,uint16_t type,uint16_t cl,uint16_t len,const void *data,uint32_t ttl,AddressReply cb,void *ctx){return 0;}
DNSServiceErrorType DNSServiceSetDispatchQueue(DNSServiceRef r,dispatch_queue_t q){assert(r->live);return 0;}
DNSServiceErrorType DNSServiceRegister(DNSServiceRef *r,DNSServiceFlags flags,uint32_t interface,const char *name,const char *type,const char *domain,const char *host,uint16_t port,uint16_t len,const void *txt,ServiceReply cb,void *ctx){*r=makeRef();(*r)->service=cb;(*r)->context=ctx;return 0;}
DNSServiceErrorType DNSServiceBrowse(DNSServiceRef *r,DNSServiceFlags flags,uint32_t interface,const char *type,const char *domain,BrowseReply cb,void *ctx){if(failBrowse)return kDNSServiceErr_DefunctConnection;*r=makeRef();return 0;}
DNSServiceErrorType DNSServiceResolve(DNSServiceRef *r,DNSServiceFlags flags,uint32_t interface,const char *name,const char *type,const char *domain,ResolveReply cb,void *ctx){if(failResolve)return kDNSServiceErr_DefunctConnection;*r=makeRef();return 0;}
DNSServiceErrorType DNSServiceGetAddrInfo(DNSServiceRef *r,DNSServiceFlags flags,uint32_t interface,DNSServiceProtocol proto,const char *host,LookupReply cb,void *ctx){if(failLookup)return kDNSServiceErr_DefunctConnection;*r=makeRef();return 0;}
void DNSServiceRefDeallocate(DNSServiceRef r){assert(r->live);r->live=NO;closed++;}
static void drain(double seconds){NSDate *until=[NSDate dateWithTimeIntervalSinceNow:seconds];while(until.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];}
int main(void){@autoreleasepool{
 VPNDiscovery *d=[VPNDiscovery new];NSDictionary *p=@{@"name":@"test",@"peer":@"10.7.0.1",@"host":@"test.local.",@"port":@7000,@"raopName":@"test-raop",@"airplayTXT":@[@"x=1"],@"raopTXT":@[@"x=1"]};
 assert([d startWithProfile:p]);assert(created==4);DNSServiceRef stale=&refs[1];
 for(int i=0;i<5;i++){assert([d startWithProfile:p]);[d recoverOnForeground];}assert(created==4&&closed==0);
 stale->service(stale,0,-65569,"test","_airplay._tcp","local.",stale->context);
 assert(closed==0); // never deallocate inside a callback
 [d recoverOnForeground];assert(created==8&&closed==4);
 stale->service(stale,0,-65569,"test","_airplay._tcp","local.",stale->context);drain(1.2);assert(created==8); // stale callbacks/retries cannot replace new refs
 DNSServiceRef current=&refs[5];current->service(current,0,-65569,"test","_airplay._tcp","local.",current->context);
 [d stop];NSUInteger stopped=created;drain(1.2);assert(created==stopped&&closed==created); // stop revokes pending retry
 assert([d startWithProfile:p]);current=&refs[stopped+1];current->service(current,0,-65569,"test","_airplay._tcp","local.",current->context);drain(1.2);assert(created==stopped+8);
 current=&refs[created-3];NSUInteger deniedClosed=closed;current->service(current,0,kDNSServiceErr_PolicyDenied,"test","_airplay._tcp","local.",current->context);NSUInteger before=created;
 NSCAssert([[d valueForKey:@"needsRecovery"] boolValue],@"POLICY_DENIED_HANDLES_REUSED");assert(closed==deniedClosed);
 drain(1.2);assert(created==before); // no automatic denied-permission loop
 [d recoverOnForeground];assert(created==before+4&&closed==deniedClosed+4);assert(![[d valueForKey:@"needsRecovery"] boolValue]);
 [d recoverOnForeground];assert(created==before+4); // preserve healthy discovery
 current=&refs[created-3];current->service(current,0,kDNSServiceErr_PolicyDenied,"test","_airplay._tcp","local.",current->context);before=created;
 assert([d recoverIfNeeded]);assert(created==before+4); // explicit Start/Refresh, no app restart
 current->service(current,0,kDNSServiceErr_PolicyDenied,"test","_airplay._tcp","local.",current->context);assert(![[d valueForKey:@"needsRecovery"] boolValue]); // stale denial ignored
 [d stop];failCreate=YES;assert(![d startWithProfile:p]);drain(4.2);assert([[d valueForKey:@"retryCount"] unsignedIntegerValue]==3);NSUInteger generation=[[d valueForKey:@"generation"] unsignedIntegerValue];drain(1.2);assert([[d valueForKey:@"generation"] unsignedIntegerValue]==generation);
 failCreate=NO;[d recoverOnForeground];assert([d recoverIfNeeded]);[d stop];assert(closed==created);
 failBrowse=YES;assert([d startWithProfile:p]);assert([[d valueForKey:@"needsRecovery"] boolValue]);failBrowse=NO;[d recoverOnForeground];assert(![[d valueForKey:@"needsRecovery"] boolValue]);
 failResolve=YES;[d foundService:"test" type:"_airplay._tcp" domain:"local."];assert([[d valueForKey:@"needsRecovery"] boolValue]);failResolve=NO;[d recoverOnForeground];
 failLookup=YES;[d resolveHost:"test.local." port:7000];assert([[d valueForKey:@"needsRecovery"] boolValue]);failLookup=NO;[d recoverOnForeground];assert(![[d valueForKey:@"needsRecovery"] boolValue]);[d stop];drain(1.2);assert(closed==created);
 puts("Discovery recovery passed: defunct callback/foreground, healthy preservation, callback deferral, stale generation, stop during retry, bounded daemon failure, policy-denied foreground/explicit retry without loops, denied callback deferral, stale denial isolation.");
}return 0;}

