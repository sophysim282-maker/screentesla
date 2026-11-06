#!/usr/bin/env python3
"""Build a minimal Foundation harness around exact production listener methods."""
from pathlib import Path
source=Path('App/Receiver.m').read_text()
def method(signature):
 start=source.index(signature)
 end=source.find('\n- (',start+len(signature))
 assert end>start
 return source[start:end]
fixture=r'''
#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <errno.h>
#import <stdatomic.h>
#import <assert.h>
typedef void SSL_CTX;
static void SSL_CTX_up_ref(SSL_CTX *c){}
static void SSL_CTX_free(SSL_CTX *c){}
static int sl_tls_begin(SSL_CTX *c,int fd){return 1;}
static void sl_tls_end(void){}
static atomic_int next_error=0,served=0;
static int fixture_accept(int fd,struct sockaddr *a,socklen_t *n){
 int error=atomic_exchange(&next_error,0);if(error){errno=error;return -1;}return accept(fd,a,n);
}
#define accept fixture_accept
@interface Receiver : NSObject {
@public
 int _socket,_httpsSocket;
 BOOL _running,_httpAccepting,_httpsAccepting;
 NSUInteger _generation,_httpListenSerial,_httpsListenSerial;
 dispatch_semaphore_t _httpSlots;
}
- (BOOL)startListener:(unsigned short)port context:(SSL_CTX *)context;
- (BOOL)listenerNeedsRepair:(BOOL)secure;
- (void)serveClient:(int)client generation:(NSUInteger)generation;
- (void)emit:(NSString *)message;
@end
@implementation Receiver
- (instancetype)init {if((self=[super init])){_socket=-1;_httpsSocket=-1;_running=YES;_generation=1;_httpSlots=dispatch_semaphore_create(12);}return self;}
- (void)emit:(NSString *)message {NSLog(@"%@",message);}
- (void)serveClient:(int)client generation:(NSUInteger)generation {atomic_fetch_add(&served,1);}
'''
fixture+=method('- (BOOL)listenerNeedsRepair:(BOOL)secure {')+'\n'
fixture+=method('- (BOOL)startListener:(unsigned short)port context:(SSL_CTX *)context {')+'\n@end\n'
fixture+=r'''
#undef accept
static int client(unsigned short port){
 int fd=socket(AF_INET,SOCK_STREAM,0);struct sockaddr_in a={0};a.sin_family=AF_INET;a.sin_port=htons(port);a.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
 assert(connect(fd,(struct sockaddr *)&a,sizeof a)==0);return fd;
}
static void wait_served(int n){for(int i=0;i<200&&atomic_load(&served)<n;i++)usleep(10000);assert(atomic_load(&served)>=n);}
int main(void){@autoreleasepool{
 Receiver *r=[Receiver new];assert([r startListener:0 context:NULL]);
 struct sockaddr_in a={0};socklen_t len=sizeof a;assert(getsockname(r->_socket,(struct sockaddr *)&a,&len)==0);unsigned short port=ntohs(a.sin_port);
 int original=r->_socket;int option=-1,defunct=-1;socklen_t optionLength=sizeof option;int get=getsockopt(original,SOL_SOCKET,SO_ACCEPTCONN,&option,&optionLength);int probeErr=errno;
#ifdef SO_ISDEFUNCT
 optionLength=sizeof defunct;int dg=getsockopt(original,SOL_SOCKET,SO_ISDEFUNCT,&defunct,&optionLength);printf("DEFUNCT rc=%d value=%d errno=%d\\n",dg,defunct,errno);
#endif
 printf("INITIAL fd=%d accepting=%d serial=%lu gen=%lu optionrc=%d listening=%d errno=%d\\n",original,r->_httpAccepting,(unsigned long)r->_httpListenSerial,(unsigned long)r->_generation,get,option,probeErr);fflush(stdout);assert(![r listenerNeedsRepair:NO]);
 atomic_store(&next_error,EINTR);int first=client(port);wait_served(1);close(first);assert(r->_socket==original);assert(![r listenerNeedsRepair:NO]);
 atomic_store(&next_error,EBADF);int broken=client(port);for(int i=0;i<200&&! [r listenerNeedsRepair:NO];i++)usleep(10000);
 assert([r listenerNeedsRepair:NO]);for(int i=0;i<200&&r->_socket>=0;i++)usleep(10000);assert(r->_socket==-1);close(broken);
 assert([r startListener:port context:NULL]);int restored=client(port);wait_served(2);close(restored);assert(![r listenerNeedsRepair:NO]);
 assert(r->_generation==1); // Media/client generation is never invalidated by rebinding.
 @synchronized(r){r->_generation++;int fd=r->_socket;r->_socket=-1;r->_httpAccepting=NO;shutdown(fd,SHUT_RDWR);close(fd);}
 puts("PASS: exact production HTTP listener tolerates EINTR, retires dead FD and rebinds without changing receiver generation");
 return 0;
}}
'''
Path('build/receiver-listener-fixture.m').write_text(fixture)
