#ifndef SL_LOCAL_TLS_H
#define SL_LOCAL_TLS_H
#include <stddef.h>
#include <sys/types.h>
#include <openssl/ssl.h>
SSL_CTX *sl_tls_context(const char *chain,const char *key);
int sl_tls_begin(SSL_CTX *context,int fd);
int sl_tls_active(int fd);
ssize_t sl_tls_read(int fd,void *bytes,size_t size);
ssize_t sl_tls_write(int fd,const void *bytes,size_t size);
void sl_tls_end(void);
const char *sl_tls_last_error(void);
int sl_tls_identity_check(const char *chain,const char *key,char *detail,size_t size);
#endif
