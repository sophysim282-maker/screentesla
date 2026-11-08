// Build 80: one TLS connection serves several requests; idle connections close.
#define _POSIX_C_SOURCE 200809L
#define _DARWIN_C_SOURCE
#include "../App/LocalTLS.h"
#include <assert.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>
struct server{SSL_CTX *ctx;int fd;int served;};
static void *serve(void *arg){struct server *s=arg;assert(sl_tls_begin(s->ctx,s->fd));
 struct timeval t={2,0};setsockopt(s->fd,SOL_SOCKET,SO_RCVTIMEO,&t,sizeof t);
 for(;;){char req[512];size_t n=0;
  while(n<sizeof req-1){ssize_t got=sl_tls_read(s->fd,req+n,sizeof req-1-n);if(got<=0)goto done;n+=(size_t)got;req[n]=0;if(strstr(req,"\r\n\r\n"))break;}
  s->served++;char reply[128];int len=snprintf(reply,sizeof reply,"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: keep-alive\r\n\r\n%02d",s->served);
  assert(sl_tls_write(s->fd,reply,(size_t)len)==len);
  if(!sl_tls_wait_readable(s->fd,800))break; /* idle: close like the phone does after 10 s */
 }
 done:sl_tls_end();close(s->fd);return NULL;}
static void request(SSL *ssl,const char *want){const char *q="GET /media/state HTTP/1.1\r\nHost: car.tesla4khmer.com\r\n\r\n";assert(SSL_write(ssl,q,(int)strlen(q))==(int)strlen(q));
 char buf[256];int n=0,r;while((r=SSL_read(ssl,buf+n,(int)sizeof buf-1-n))>0){n+=r;buf[n]=0;char *b=strstr(buf,"\r\n\r\n");if(b&&strlen(b+4)>=2)break;}
 assert(strstr(buf,"keep-alive")&&!strcmp(strstr(buf,"\r\n\r\n")+4,want));}
int main(int argc,char **argv){signal(SIGPIPE,SIG_IGN);assert(argc==3);SSL_CTX *ctx=sl_tls_context(argv[1],argv[2]);assert(ctx);
 int fd[2];assert(socketpair(AF_UNIX,SOCK_STREAM,0,fd)==0);struct server s={ctx,fd[0],0};pthread_t th;assert(!pthread_create(&th,NULL,serve,&s));
 SSL_CTX *cc=SSL_CTX_new(TLS_client_method());SSL_CTX_load_verify_locations(cc,argv[1],NULL);SSL_CTX_set_verify(cc,SSL_VERIFY_PEER,NULL);
 SSL *ssl=SSL_new(cc);SSL_set_fd(ssl,fd[1]);SSL_set1_host(ssl,"car.tesla4khmer.com");assert(SSL_connect(ssl)==1);
 request(ssl,"01");request(ssl,"02");struct timespec w={0,300000000};nanosleep(&w,NULL);request(ssl,"03");
 puts("three requests reused one TLS connection (one handshake)");
 char x;struct timeval t={3,0};setsockopt(fd[1],SOL_SOCKET,SO_RCVTIMEO,&t,sizeof t);int r=SSL_read(ssl,&x,1);assert(r<=0);
 puts("idle connection closed by the server after its wait");
 pthread_join(th,NULL);assert(s.served==3);SSL_free(ssl);close(fd[1]);SSL_CTX_free(cc);SSL_CTX_free(ctx);puts("KEEP_ALIVE_TLS_PASSED");return 0;}
