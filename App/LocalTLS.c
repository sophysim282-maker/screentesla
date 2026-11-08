#include "LocalTLS.h"
#include <openssl/x509v3.h>
#include <sys/socket.h>
#include <limits.h>
#include <errno.h>
#include <stdio.h>
#include <openssl/err.h>
#ifdef SSL_R_UNEXPECTED_EOF_WHILE_READING
#define SL_TLS_PEER_EOF(detail) (ERR_GET_REASON(detail)==SSL_R_UNEXPECTED_EOF_WHILE_READING)
#else
#define SL_TLS_PEER_EOF(detail) 0
#endif
static _Thread_local SSL *session;
static _Thread_local char lastError[200];
SSL_CTX *sl_tls_context(const char *chain,const char *key){
 SSL_CTX *ctx=SSL_CTX_new(TLS_server_method());if(!ctx)return NULL;
 SSL_CTX_set_min_proto_version(ctx,TLS1_2_VERSION);
 SSL_CTX_set_options(ctx,SSL_OP_NO_COMPRESSION|SSL_OP_NO_RENEGOTIATION);
 SSL_CTX_set_session_cache_mode(ctx,SSL_SESS_CACHE_OFF);
 if(SSL_CTX_use_certificate_chain_file(ctx,chain)!=1 || SSL_CTX_use_PrivateKey_file(ctx,key,SSL_FILETYPE_PEM)!=1 || SSL_CTX_check_private_key(ctx)!=1)goto fail;
 X509 *cert=SSL_CTX_get0_certificate(ctx);
 if(!cert || X509_check_host(cert,"car.tesla4khmer.com",0,0,NULL)!=1 || X509_cmp_current_time(X509_get0_notBefore(cert))>=0 || X509_cmp_current_time(X509_get0_notAfter(cert))<=0)goto fail;
 return ctx;
 fail:SSL_CTX_free(ctx);return NULL;
}
int sl_tls_active(int fd){return session && SSL_get_fd(session)==fd;}
int sl_tls_begin(SSL_CTX *ctx,int fd){
 if(session)return 0;
 session=SSL_new(ctx);if(!session)return 0;
 SSL_set_fd(session,fd);
 SSL_set_mode(session,SSL_MODE_ENABLE_PARTIAL_WRITE|SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER);
 lastError[0]=0;
 errno=0;int result=SSL_accept(session),saved=errno;if(result==1)return 1;
 // Build 70: keep the reason for the website diagnostics log.
 int code=SSL_get_error(session,result);unsigned long detail=ERR_get_error();char reason[120]="none";
 if(detail)ERR_error_string_n(detail,reason,sizeof reason);
 const char *kind=(code==SSL_ERROR_WANT_READ||code==SSL_ERROR_WANT_WRITE)?"timed out waiting for the browser":code==SSL_ERROR_SYSCALL?(saved==EAGAIN||saved==EWOULDBLOCK?"timed out waiting for the browser":(result==0||!saved?"browser closed the connection":"network error")):code==SSL_ERROR_SSL?(SL_TLS_PEER_EOF(detail)?"browser closed the connection":"TLS protocol error"):code==SSL_ERROR_ZERO_RETURN?"browser closed TLS":"other";
 snprintf(lastError,sizeof lastError,"%s (ssl %d, errno %d, %s)",kind,code,saved,reason);
 ERR_clear_error();
 sl_tls_end();return 0;
}
ssize_t sl_tls_read(int fd,void *bytes,size_t size){
 if(!sl_tls_active(fd))return recv(fd,bytes,size,0);
 int n=SSL_read(session,bytes,(int)(size>INT_MAX?INT_MAX:size));
 if(n>0)return n;
 if(SSL_get_error(session,n)==SSL_ERROR_ZERO_RETURN)return 0;
 errno=EIO;return -1;
}
ssize_t sl_tls_write(int fd,const void *bytes,size_t size){
 if(!sl_tls_active(fd))return send(fd,bytes,size,0);
 int n=SSL_write(session,bytes,(int)(size>INT_MAX?INT_MAX:size));if(n>0)return n;errno=EIO;return -1;
}
void sl_tls_end(void){if(session){SSL_free(session);session=NULL;}}
const char *sl_tls_last_error(void){return lastError[0]?lastError:"unknown";}
