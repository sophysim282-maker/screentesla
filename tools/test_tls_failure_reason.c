// Build 70: a failed HTTPS handshake keeps a readable reason for the phone log.
#define _POSIX_C_SOURCE 200809L
#define _DARWIN_C_SOURCE
#include <signal.h>
#include "../App/LocalTLS.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>
static const char *attempt(SSL_CTX *ctx,const char *clientBytes,int closeClient){
    int fd[2];assert(socketpair(AF_UNIX,SOCK_STREAM,0,fd)==0);
    struct timeval timeout={1,0};setsockopt(fd[0],SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof timeout);
    if(clientBytes)assert(write(fd[1],clientBytes,strlen(clientBytes))==(ssize_t)strlen(clientBytes));
    if(closeClient)close(fd[1]);
    assert(!sl_tls_begin(ctx,fd[0]));
    assert(!sl_tls_active(fd[0]));                 // session released after failure
    static char copy[200];snprintf(copy,sizeof copy,"%s",sl_tls_last_error());
    close(fd[0]);if(!closeClient)close(fd[1]);
    return copy;
}
int main(int argc,char **argv){
    signal(SIGPIPE,SIG_IGN);assert(argc==3);SSL_CTX *ctx=sl_tls_context(argv[1],argv[2]);assert(ctx);
    const char *plain=attempt(ctx,"GET / HTTP/1.1\r\nHost: car.tesla4khmer.com\r\n\r\n",1);
    printf("plain HTTP on 443: %s\n",plain);assert(strstr(plain,"TLS protocol error"));
    const char *closed=attempt(ctx,NULL,1);
    printf("closed before hello: %s\n",closed);fflush(stdout);assert(strstr(closed,"closed"));
    const char *silent=attempt(ctx,NULL,0);
    printf("silent browser: %s\n",silent);assert(strstr(silent,"timed out"));
    SSL_CTX_free(ctx);puts("TLS failure reasons recorded for the website log");return 0;
}
