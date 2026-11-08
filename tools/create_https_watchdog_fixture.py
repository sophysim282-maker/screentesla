"""Exercise exact production listener/watchdog methods with real local TLS.

Only the fixed port and bundled test-identity path are redirected for a CLI test.
Media/approval/VPN are untouched sentinel values; no iOS frameworks are mocked.
"""
from pathlib import Path
source=Path('App/Receiver.m').read_text()
def method(signature):
    start=source.index(signature)
    end=source.index('\n- (',start+len(signature))
    return source[start:end].replace('NSBundle.mainBundle.bundlePath','testDirectory').replace('startListener:443','startListener:testPort').replace('chain.fileSystemRepresentation,443,2000','chain.fileSystemRepresentation,testPort,300')
fixture=r'''
#import <Foundation/Foundation.h>
#include "LocalTLS.h"
#include "LocalHTTPSProbe.h"
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>
#include <stdatomic.h>
#include <assert.h>
static NSString *testDirectory;
static unsigned short testPort;
static atomic_int stallHTTPS=0,secureBinds=0;
static int fixture_bind(int fd,const struct sockaddr *a,socklen_t length){
 int result=bind(fd,a,length);
 if(!result&&ntohs(((const struct sockaddr_in *)a)->sin_port)==testPort){atomic_fetch_add(&secureBinds,1);atomic_store(&stallHTTPS,0);}
 return result;
}
#define bind fixture_bind
@interface Receiver : NSObject {
@public
 int _socket,_httpsSocket;
 BOOL _running,_httpAccepting,_httpsAccepting;
 NSUInteger _generation,_httpListenSerial,_httpsListenSerial;
 dispatch_semaphore_t _httpSlots,_httpsProbeSlots;
 dispatch_queue_t _webHealthQueue;
 dispatch_source_t _httpsWatchdog;
 SLHTTPSHealthPolicy _httpsHealth;
 NSTimeInterval _lastTLSFailureLog,_lastExternalHTTPSResponse,_lastHTTPSHealthLog;
 NSString *_viewerToken,*_mediaEpoch,*_vpnSentinel,*_pipSentinel;
}
- (BOOL)startListener:(unsigned short)port context:(SSL_CTX *)context;
- (BOOL)listenerNeedsRepair:(BOOL)secure;
- (BOOL)repairHTTPSListenerAtGeneration:(NSUInteger)generation serial:(NSUInteger)serial;
- (void)checkHTTPSHealth;
- (void)serveClient:(int)client generation:(NSUInteger)generation;
- (void)emit:(NSString *)message;
@end
@implementation Receiver
- (instancetype)init {if((self=[super init])){_socket=-1;_httpsSocket=-1;_running=YES;_generation=7;_httpSlots=dispatch_semaphore_create(12);_httpsProbeSlots=dispatch_semaphore_create(2);_webHealthQueue=dispatch_queue_create("test.health",DISPATCH_QUEUE_SERIAL);_httpsWatchdog=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,_webHealthQueue);dispatch_source_set_timer(_httpsWatchdog,DISPATCH_TIME_FOREVER,NSEC_PER_SEC,0);dispatch_resume(_httpsWatchdog);_viewerToken=@"unchanged-approval";_mediaEpoch=@"playing-video";_vpnSentinel=@"connected";_pipSentinel=@"active";}return self;}
- (void)emit:(NSString *)message {NSLog(@"%@",message);}
- (void)serveClient:(int)fd generation:(NSUInteger)generation {
 if(!sl_tls_active(fd)){const char *response="HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK";send(fd,response,strlen(response),0);return;}
 char request[1024]={0};size_t used=0;while(used<sizeof request-1&&!strstr(request,"\r\n\r\n")){ssize_t n=sl_tls_read(fd,request+used,sizeof request-1-used);if(n<=0)return;used+=(size_t)n;}
 NSString *healthChallenge=nil;
 for(NSString *field in [[NSString stringWithUTF8String:request] componentsSeparatedByString:@"\r\n"]){
 __PRODUCTION_HEALTH_HEADER_PARSE__
 }
 assert(sl_https_valid_challenge(healthChallenge.UTF8String));char nonce[33];memcpy(nonce,healthChallenge.UTF8String,33);
 assert(sl_https_health_allowed(1,1,"GET",0,"/local/https-health",nonce));
 if(atomic_load(&stallHTTPS)){usleep(450000);return;}
 char response[256];int size=snprintf(response,sizeof response,"HTTP/1.1 200 OK\r\nContent-Length: 32\r\n\r\n%s",nonce);sl_tls_write(fd,response,(size_t)size);
}
'''
for signature in ['- (BOOL)listenerNeedsRepair:(BOOL)secure {','- (BOOL)startListener:(unsigned short)port context:(SSL_CTX *)context {','- (BOOL)repairHTTPSListenerAtGeneration:(NSUInteger)generation serial:(NSUInteger)serial {','- (void)checkHTTPSHealth {']:
    fixture+=method(signature)+'\n'
fixture+=r'''
@end
#undef bind
static unsigned short freePort(void){int fd=socket(AF_INET,SOCK_STREAM,0);struct sockaddr_in a={0};a.sin_family=AF_INET;a.sin_addr.s_addr=htonl(INADDR_LOOPBACK);assert(bind(fd,(struct sockaddr *)&a,sizeof a)==0);socklen_t len=sizeof a;assert(getsockname(fd,(struct sockaddr *)&a,&len)==0);close(fd);return ntohs(a.sin_port);}
static void check(Receiver *r){dispatch_sync(r->_webHealthQueue,^{[r checkHTTPSHealth];});}
static void preserved(Receiver *r,int http){assert(r->_generation==7&&r->_socket==http&&r->_httpAccepting);assert([r->_viewerToken isEqual:@"unchanged-approval"]);assert([r->_mediaEpoch isEqual:@"playing-video"]);assert([r->_vpnSentinel isEqual:@"connected"]);assert([r->_pipSentinel isEqual:@"active"]);}
int main(int argc,char **argv){@autoreleasepool{
 assert(argc==2);testDirectory=[NSString stringWithUTF8String:argv[1]];testPort=freePort();Receiver *r=[Receiver new];assert([r startListener:0 context:NULL]);
 SSL_CTX *ctx=sl_tls_context([[testDirectory stringByAppendingPathComponent:@"PrivateTLS/fullchain.pem"] fileSystemRepresentation],[[testDirectory stringByAppendingPathComponent:@"PrivateTLS/private.key"] fileSystemRepresentation]);assert(ctx);assert([r startListener:testPort context:ctx]);SSL_CTX_free(ctx);
 int http=r->_socket;NSUInteger serial=r->_httpsListenSerial;check(r);assert(r->_httpsListenSerial==serial);preserved(r,http);
 atomic_store(&stallHTTPS,1);check(r);assert(r->_httpsListenSerial==serial); // one timeout never rebinds
 usleep(180000);check(r);assert(r->_httpsListenSerial>serial);assert(atomic_load(&secureBinds)==2);preserved(r,http);usleep(500000);check(r);assert(r->_httpsHealth.failures==0);
 serial=r->_httpsListenSerial;atomic_store(&stallHTTPS,1);r->_lastExternalHTTPSResponse=NSProcessInfo.processInfo.systemUptime;check(r);usleep(180000);check(r);assert(r->_httpsListenSerial==serial);preserved(r,http); // real traffic wins
 r->_lastExternalHTTPSResponse=0;check(r);usleep(180000);check(r);assert(r->_httpsListenSerial==serial); // cooldown blocks repeated rebinds
 NSUInteger generation=r->_generation;assert(![r repairHTTPSListenerAtGeneration:generation-1 serial:serial]);assert(![r repairHTTPSListenerAtGeneration:generation serial:serial-1]);preserved(r,http);
 atomic_store(&stallHTTPS,0);usleep(500000);check(r);
 dispatch_source_t timer=r->_httpsWatchdog;r->_httpsWatchdog=nil;dispatch_source_cancel(timer);serial=r->_httpsListenSerial;check(r);assert(r->_httpsListenSerial==serial);
 @synchronized(r){r->_running=NO;r->_generation++;shutdown(r->_socket,SHUT_RDWR);close(r->_socket);r->_socket=-1;shutdown(r->_httpsSocket,SHUT_RDWR);close(r->_httpsSocket);r->_httpsSocket=-1;}
 puts("HTTPS_WATCHDOG_PASSED: exact production methods detect TLS response stall, rebind only HTTPS after two failures, preserve HTTP/approval/media/PiP/VPN, suppress on real HTTPS success, respect cooldown/stale generation/listener leases and stop cancellation.");return 0;
}}
'''
header_parse=next(line for line in source.splitlines() if 'healthChallenge=[[field substringFromIndex:' in line)
fixture=fixture.replace('__PRODUCTION_HEALTH_HEADER_PARSE__',header_parse)
Path('build/https-watchdog-fixture.m').write_text(fixture)
