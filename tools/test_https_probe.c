#define _POSIX_C_SOURCE 200809L
#include "../App/LocalHTTPSProbe.h"
#include "../App/LocalTLS.h"
#include <assert.h>
#include <arpa/inet.h>
#include <pthread.h>
#include <signal.h>
#include <sys/time.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
enum {GOOD,WRONG_NONCE,BAD_STATUS,STALL,PLAIN};
struct server {SSL_CTX *ctx;int fd,mode;unsigned rounds;};
static void pause_ms(int ms){struct timespec t={ms/1000,(ms%1000)*1000000L};nanosleep(&t,NULL);}
static void *serve(void *arg){struct server *s=arg;for(unsigned i=0;i<s->rounds;i++){
 int fd=accept(s->fd,NULL,NULL);assert(fd>=0);struct timeval timeout={2,0};setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof timeout);setsockopt(fd,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof timeout);
 if(s->mode==PLAIN){pause_ms(250);close(fd);continue;}
 if(!sl_tls_begin(s->ctx,fd)){close(fd);continue;}
 char request[1024]={0};size_t used=0;while(used<sizeof request-1&&!strstr(request,"\r\n\r\n")){ssize_t n=sl_tls_read(fd,request+used,sizeof request-1-used);if(n<=0)break;used+=(size_t)n;}
 char *field=strstr(request,"X-ScreenLink-Health: ");assert(field);field+=strlen("X-ScreenLink-Health: ");char nonce[33];memcpy(nonce,field,32);nonce[32]=0;assert(sl_https_valid_challenge(nonce));
 assert(strstr(request,"GET /local/https-health HTTP/1.1\r\nHost: car.tesla4khmer.com\r\n"));
 if(s->mode==STALL)pause_ms(400);
 if(s->mode==WRONG_NONCE)memset(nonce,'f',32);
 char reply[256];int n=snprintf(reply,sizeof reply,"HTTP/1.1 %s\r\nContent-Length: 32\r\nConnection: close\r\n\r\n%s",s->mode==BAD_STATUS?"503 Unavailable":"200 OK",nonce);
 // Real partial response framing: one byte at a time for normal health checks.
 for(int j=0;j<n;j++)if(sl_tls_write(fd,reply+j,1)!=1)break;
 sl_tls_end();close(fd);
 }close(s->fd);return NULL;}
static SLHTTPSProbeResult run(SSL_CTX *ctx,const char *chain,int mode,unsigned timeout){
 int fd=socket(AF_INET,SOCK_STREAM,0);assert(fd>=0);struct sockaddr_in a={0};a.sin_family=AF_INET;a.sin_addr.s_addr=htonl(INADDR_LOOPBACK);assert(!bind(fd,(struct sockaddr *)&a,sizeof a));assert(!listen(fd,8));socklen_t len=sizeof a;assert(!getsockname(fd,(struct sockaddr *)&a,&len));
 struct server s={ctx,fd,mode,1};pthread_t t;assert(!pthread_create(&t,NULL,serve,&s));SLHTTPSProbeResult r=sl_https_probe(chain,ntohs(a.sin_port),timeout);pthread_join(t,NULL);return r;
}
int main(int argc,char **argv){assert(argc==4);signal(SIGPIPE,SIG_IGN);SSL_CTX *ctx=sl_tls_context(argv[1],argv[2]);assert(ctx);
 assert(run(ctx,argv[1],GOOD,1500)==SLHTTPSHealthy);
 assert(run(ctx,argv[1],WRONG_NONCE,1500)==SLHTTPSResponse);
 assert(run(ctx,argv[1],BAD_STATUS,1500)==SLHTTPSResponse);
 assert(run(ctx,argv[1],STALL,150)==SLHTTPSTimeout);
 assert(run(ctx,argv[1],PLAIN,150)==SLHTTPSTimeout);
 assert(run(ctx,argv[3],GOOD,1500)==SLHTTPSHandshake); // same hostname, wrong pinned key
 assert(sl_https_probe("/missing/identity",443,150)==SLHTTPSIdentity);
 assert(!sl_https_valid_challenge("not-a-health-challenge"));
 const char *nonce="0123456789abcdef0123456789abcdef";char reply[128];int size=snprintf(reply,sizeof reply,"HTTP/1.1 200 OK\r\nContent-Length: 32\r\n\r\n%s",nonce);
 assert(sl_https_health_allowed(1,1,"GET",0,"/local/https-health",nonce));
 assert(!sl_https_health_allowed(0,1,"GET",0,"/local/https-health",nonce));
 assert(!sl_https_health_allowed(1,0,"GET",0,"/local/https-health",nonce));
 assert(!sl_https_health_allowed(1,1,"POST",0,"/local/https-health",nonce));
 assert(!sl_https_health_allowed(1,1,"GET",1,"/local/https-health",nonce));
 assert(!sl_https_health_allowed(1,1,"GET",0,"/media/state",nonce));
 for(int i=0;i<size;i++){assert(!sl_https_valid_response(reply,(size_t)i,nonce));}
 assert(sl_https_valid_response(reply,(size_t)size,nonce));
 SLHTTPSHealthPolicy p={0};assert(!sl_https_should_repair(&p,0,100,0));assert(p.failures==1);assert(!sl_https_should_repair(&p,1,115,0));assert(p.failures==0);
 assert(!sl_https_should_repair(&p,0,130,0));assert(sl_https_should_repair(&p,0,145,0));assert(p.lastRepair==145);
 assert(!sl_https_should_repair(&p,0,160,0));assert(!sl_https_should_repair(&p,0,175,0));assert(!sl_https_should_repair(&p,0,190,0));assert(sl_https_should_repair(&p,0,205,0));
 assert(!sl_https_should_repair(&p,0,220,219));assert(p.failures==0);assert(!sl_https_should_repair(&p,0,235,234));assert(p.failures==0);
 SSL_CTX_free(ctx);puts("HTTPS_PROBE_PASSED: real TLS+hostname+leaf pin+nonce response, fragmented replies, wrong identity/status/nonce, bounded handshake/read stalls; two-failure policy, healthy reset, real-traffic suppression and repair cooldown.");return 0;
}
