#if defined(__APPLE__)
#define _DARWIN_C_SOURCE
#endif
#define _POSIX_C_SOURCE 200809L
#include "LocalHTTPSProbe.h"
#include <openssl/ssl.h>
#include <openssl/pem.h>
#include <openssl/rand.h>
#include <openssl/err.h>
#include <openssl/x509v3.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <poll.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <limits.h>

static double milliseconds(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec*1000.0+t.tv_nsec/1000000.0;}
static int ready(int fd,short events,double deadline){for(;;){double left=deadline-milliseconds();if(left<=0)return 0;struct pollfd p={fd,events,0};int n=poll(&p,1,(int)left+1);if(n>0)return (p.revents&(events|POLLERR|POLLHUP))!=0;if(n==0)return 0;if(errno!=EINTR)return -1;}}
static int waitTLS(SSL *ssl,int result,int fd,double deadline){int error=SSL_get_error(ssl,result);if(error!=SSL_ERROR_WANT_READ&&error!=SSL_ERROR_WANT_WRITE)return -1;return ready(fd,error==SSL_ERROR_WANT_READ?POLLIN:POLLOUT,deadline);}
int sl_https_valid_challenge(const char *s){if(!s||strlen(s)!=32)return 0;for(int i=0;i<32;i++)if(!((s[i]>='0'&&s[i]<='9')||(s[i]>='a'&&s[i]<='f')))return 0;return 1;}
int sl_https_valid_response(const char *bytes,size_t size,const char *challenge){
 if(!bytes||size<13||!sl_https_valid_challenge(challenge)||memcmp(bytes,"HTTP/1.1 200 ",13))return 0;
 for(size_t i=0;i+4<=size;i++)if(!memcmp(bytes+i,"\r\n\r\n",4))return size-i-4==32&&!memcmp(bytes+i+4,challenge,32);
 return 0;
}
const char *sl_https_probe_name(SLHTTPSProbeResult r){switch(r){case SLHTTPSHealthy:return "healthy";case SLHTTPSIdentity:return "identity invalid";case SLHTTPSConnect:return "TCP unavailable";case SLHTTPSTimeout:return "deadline expired";case SLHTTPSHandshake:return "TLS verification/handshake failed";default:return "HTTPS response invalid";}}
SLHTTPSProbeResult sl_https_probe(const char *chain,uint16_t port,unsigned timeout_ms){
 SSL_CTX *ctx=NULL;SSL *ssl=NULL;BIO *file=NULL;X509 *expected=NULL,*actual=NULL;int fd=-1;SLHTTPSProbeResult outcome=SLHTTPSIdentity;
 if(!chain||!port||timeout_ms<100||timeout_ms>5000)return outcome;
 const double deadline=milliseconds()+timeout_ms;ERR_clear_error();
 file=BIO_new_file(chain,"r");if(!file)goto done;expected=PEM_read_bio_X509(file,NULL,NULL,NULL);BIO_free(file);file=NULL;
 if(!expected||X509_check_host(expected,"car.tesla4khmer.com",0,0,NULL)!=1||X509_cmp_current_time(X509_get0_notBefore(expected))>=0||X509_cmp_current_time(X509_get0_notAfter(expected))<=0)goto done;
 ctx=SSL_CTX_new(TLS_client_method());if(!ctx)goto done;
 SSL_CTX_set_min_proto_version(ctx,TLS1_2_VERSION);SSL_CTX_set_verify(ctx,SSL_VERIFY_PEER,NULL);
 /* Pin the app's already-validated leaf for this loopback-only self test.
  * Hostname, expiry, chain verification and exact leaf comparison remain on. */
 if(X509_STORE_add_cert(SSL_CTX_get_cert_store(ctx),expected)!=1)goto done;
 X509_VERIFY_PARAM_set_flags(SSL_CTX_get0_param(ctx),X509_V_FLAG_PARTIAL_CHAIN);
 fd=socket(AF_INET,SOCK_STREAM,0);if(fd<0){outcome=SLHTTPSConnect;goto done;}
#ifdef SO_NOSIGPIPE
 int one=1;setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof one);
#endif
 int flags=fcntl(fd,F_GETFL,0);if(flags<0||fcntl(fd,F_SETFL,flags|O_NONBLOCK)<0){outcome=SLHTTPSConnect;goto done;}
 struct sockaddr_in address={0};address.sin_family=AF_INET;address.sin_port=htons(port);address.sin_addr.s_addr=htonl(0x7f000001u);
 if(connect(fd,(struct sockaddr *)&address,sizeof address)!=0){if(errno!=EINPROGRESS){outcome=SLHTTPSConnect;goto done;}int status=ready(fd,POLLOUT,deadline);if(status<=0){outcome=status==0?SLHTTPSTimeout:SLHTTPSConnect;goto done;}int error=0;socklen_t length=sizeof error;if(getsockopt(fd,SOL_SOCKET,SO_ERROR,&error,&length)||error){outcome=SLHTTPSConnect;goto done;}}
 ssl=SSL_new(ctx);if(!ssl)goto done;SSL_set_fd(ssl,fd);if(SSL_set1_host(ssl,"car.tesla4khmer.com")!=1||SSL_set_tlsext_host_name(ssl,"car.tesla4khmer.com")!=1)goto done;
 for(;;){int result=SSL_connect(ssl);if(result==1)break;int wait=waitTLS(ssl,result,fd,deadline);if(wait<=0){outcome=wait==0?SLHTTPSTimeout:SLHTTPSHandshake;goto done;}}
 actual=SSL_get_peer_certificate(ssl);if(!actual||SSL_get_verify_result(ssl)!=X509_V_OK||X509_cmp(expected,actual)!=0){outcome=SLHTTPSHandshake;goto done;}
 unsigned char random[16];char challenge[33],request[256];if(RAND_bytes(random,sizeof random)!=1)goto done;for(int i=0;i<16;i++)snprintf(challenge+i*2,3,"%02x",random[i]);
 int length=snprintf(request,sizeof request,"GET /local/https-health HTTP/1.1\r\nHost: car.tesla4khmer.com\r\nX-ScreenLink-Health: %s\r\nConnection: close\r\n\r\n",challenge);
 if(length<=0||(size_t)length>=sizeof request){outcome=SLHTTPSResponse;goto done;}
 for(int sent=0;sent<length;){int result=SSL_write(ssl,request+sent,length-sent);if(result>0){sent+=result;continue;}int wait=waitTLS(ssl,result,fd,deadline);if(wait<=0){outcome=wait==0?SLHTTPSTimeout:SLHTTPSResponse;goto done;}}
 char response[2048];size_t used=0;outcome=SLHTTPSResponse;
 while(used<sizeof response){int result=SSL_read(ssl,response+used,(int)(sizeof response-used));if(result>0){used+=(size_t)result;if(sl_https_valid_response(response,used,challenge)){outcome=SLHTTPSHealthy;goto done;}continue;}int wait=waitTLS(ssl,result,fd,deadline);if(wait<=0){if(wait==0)outcome=SLHTTPSTimeout;goto done;}}
done:
 if(file)BIO_free(file);
 if(actual)X509_free(actual);
 if(expected)X509_free(expected);
 if(ssl)SSL_free(ssl);
 if(fd>=0)close(fd);
 if(ctx)SSL_CTX_free(ctx);
 ERR_clear_error();return outcome;
}
