#include "../App/LocalTLS.h"
#include <pthread.h>
#include <sys/socket.h>
#include <assert.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>
struct server {SSL_CTX *ctx;int fd;};
static void *serve(void *arg){struct server *s=arg;assert(sl_tls_begin(s->ctx,s->fd));char in[4];size_t n=0;while(n<4){ssize_t got=sl_tls_read(s->fd,in+n,4-n);assert(got>0);n+=(size_t)got;}assert(!memcmp(in,"ping",4));assert(sl_tls_write(s->fd,"pong",4)==4);sl_tls_end();close(s->fd);return NULL;}
int main(int argc,char **argv){assert(argc==3);SSL_CTX *ctx=sl_tls_context(argv[1],argv[2]);assert(ctx);assert(!sl_tls_context("/missing/certificate","/missing/key"));int fd[2];assert(socketpair(AF_UNIX,SOCK_STREAM,0,fd)==0);struct server server={ctx,fd[0]};pthread_t thread;assert(!pthread_create(&thread,NULL,serve,&server));SSL_CTX *client=SSL_CTX_new(TLS_client_method());assert(client);assert(SSL_CTX_load_verify_locations(client,argv[1],NULL)==1);SSL_CTX_set_verify(client,SSL_VERIFY_PEER,NULL);SSL *ssl=SSL_new(client);SSL_set_fd(ssl,fd[1]);assert(SSL_set1_host(ssl,"car.tesla4khmer.com")==1);assert(SSL_connect(ssl)==1);assert(SSL_get_verify_result(ssl)==X509_V_OK);assert(SSL_write(ssl,"ping",4)==4);char reply[4];assert(SSL_read(ssl,reply,4)==4);assert(!memcmp(reply,"pong",4));SSL_free(ssl);close(fd[1]);pthread_join(thread,NULL);SSL_CTX_free(client);SSL_CTX_free(ctx);puts("Local TLS verified handshake, hostname, encrypted request/response and context cleanup passed");return 0;}
