#include <assert.h>
#include <errno.h>
#include <stdatomic.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
static atomic_int next_accept_error=0,opened=0,destroyed=0;
static int fault_accept(int fd,struct sockaddr *address,socklen_t *length){
 int injected=atomic_exchange(&next_accept_error,0);
 if(injected){errno=injected;return -1;}
 return accept(fd,address,length);
}
#define accept fault_accept
#include "../Vendor/RPiPlay/lib/httpd.c"
#undef accept
static void *created(void *opaque,unsigned char *local,int llen,unsigned char *remote,int rlen){atomic_fetch_add(&opened,1);return malloc(1);}
static void removed(void *p){free(p);atomic_fetch_add(&destroyed,1);}
static void request(void *p,http_request_t *req,http_response_t **res){}
static int connect_to(unsigned short port){
 int fd=socket(AF_INET,SOCK_STREAM,0);assert(fd>=0);
 struct sockaddr_in address={0};address.sin_family=AF_INET;address.sin_port=htons(port);address.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
 assert(connect(fd,(struct sockaddr *)&address,sizeof address)==0);return fd;
}
static void wait_open(int count){for(int i=0;i<200&&atomic_load(&opened)<count;i++)usleep(10000);assert(atomic_load(&opened)>=count);}
int main(void){
 logger_t *logger=logger_init();logger_set_level(logger,LOGGER_ERR);
 httpd_callbacks_t callbacks={0};callbacks.conn_init=created;callbacks.conn_destroy=removed;callbacks.conn_request=request;
 httpd_t *httpd=httpd_init(logger,&callbacks,8);assert(httpd);
 unsigned short port=0;assert(httpd_start(httpd,&port)==1);assert(port>0);
 int first=connect_to(port);wait_open(1);
 atomic_store(&next_accept_error,EINTR);int second=connect_to(port);wait_open(2);
 assert(httpd_is_running(httpd));close(second);
 // A fatal listener failure closes the old connection and makes liveness false.
 atomic_store(&next_accept_error,EBADF);int fatal=connect_to(port);
 for(int i=0;i<300&&httpd_is_running(httpd);i++)usleep(10000);
 assert(!httpd_is_running(httpd));assert(!httpd->joined);
 httpd_stop(httpd);assert(httpd->joined);close(fatal);close(first);
 unsigned short same_port=port;assert(httpd_start(httpd,&same_port)==1);assert(same_port==port);
 int recovered=connect_to(port);wait_open(3);assert(httpd_is_running(httpd));close(recovered);
 httpd_stop(httpd);assert(!httpd_is_running(httpd));assert(httpd->joined);
 httpd_destroy(httpd);logger_destroy(logger);
 puts("PASS: transient accept preserves listener; fatal failure is reported dead, joined and rebound on same port");
 return 0;
}
