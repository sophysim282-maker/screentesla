#ifndef SCREENLINK_TEST_DNS_SD_H
#define SCREENLINK_TEST_DNS_SD_H
#include <stdint.h>
#include <sys/socket.h>
#include <dispatch/dispatch.h>
typedef struct FakeDNSRef *DNSServiceRef;
typedef void *DNSRecordRef;
typedef uint32_t DNSServiceFlags, DNSServiceProtocol;
typedef int32_t DNSServiceErrorType;
enum {kDNSServiceFlagsAdd=2,kDNSServiceFlagsUnique=32,kDNSServiceFlagsNoAutoRename=8,kDNSServiceInterfaceIndexLocalOnly=0xffffffff,kDNSServiceType_A=1,kDNSServiceClass_IN=1,kDNSServiceProtocol_IPv4=1,kDNSServiceErr_DefunctConnection=-65569,kDNSServiceErr_PolicyDenied=-65570,kDNSServiceErr_ServiceNotRunning=-65563};
typedef void (*AddressReply)(DNSServiceRef,DNSRecordRef,DNSServiceFlags,DNSServiceErrorType,void *);
typedef void (*ServiceReply)(DNSServiceRef,DNSServiceFlags,DNSServiceErrorType,const char *,const char *,const char *,void *);
typedef void (*BrowseReply)(DNSServiceRef,DNSServiceFlags,uint32_t,DNSServiceErrorType,const char *,const char *,const char *,void *);
typedef void (*ResolveReply)(DNSServiceRef,DNSServiceFlags,uint32_t,DNSServiceErrorType,const char *,const char *,uint16_t,uint16_t,const unsigned char *,void *);
typedef void (*LookupReply)(DNSServiceRef,DNSServiceFlags,uint32_t,DNSServiceErrorType,const char *,const struct sockaddr *,uint32_t,void *);
DNSServiceErrorType DNSServiceCreateConnection(DNSServiceRef *);
DNSServiceErrorType DNSServiceRegisterRecord(DNSServiceRef,DNSRecordRef *,DNSServiceFlags,uint32_t,const char *,uint16_t,uint16_t,uint16_t,const void *,uint32_t,AddressReply,void *);
DNSServiceErrorType DNSServiceSetDispatchQueue(DNSServiceRef,dispatch_queue_t);
DNSServiceErrorType DNSServiceRegister(DNSServiceRef *,DNSServiceFlags,uint32_t,const char *,const char *,const char *,const char *,uint16_t,uint16_t,const void *,ServiceReply,void *);
DNSServiceErrorType DNSServiceBrowse(DNSServiceRef *,DNSServiceFlags,uint32_t,const char *,const char *,BrowseReply,void *);
DNSServiceErrorType DNSServiceResolve(DNSServiceRef *,DNSServiceFlags,uint32_t,const char *,const char *,const char *,ResolveReply,void *);
DNSServiceErrorType DNSServiceGetAddrInfo(DNSServiceRef *,DNSServiceFlags,uint32_t,DNSServiceProtocol,const char *,LookupReply,void *);
void DNSServiceRefDeallocate(DNSServiceRef);
#endif

