// Build 71: import the website certificate from an earlier ScreenLink IPA.
#include "../App/ZipEntry.h"
#include "../App/LocalTLS.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static int isChain(const char *n){return !strncmp(n,"Payload/",8)&&strstr(n,".app/PrivateTLS/fullchain.pem")&&!strstr(n,"/PlugIns/");}
static int isKey(const char *n){return !strncmp(n,"Payload/",8)&&strstr(n,".app/PrivateTLS/private.key")&&!strstr(n,"/PlugIns/");}
static void save(const char *path,const unsigned char *d,size_t n){FILE *f=fopen(path,"wb");assert(f);assert(fwrite(d,1,n,f)==n);fclose(f);}
int main(int argc,char **argv){
 assert(argc==5); // ipa, ipa-without-identity, output dir, wrong-host ipa
 char error[160],detail[200],chainPath[512],keyPath[512];unsigned char *data;size_t size;
 assert(sl_zip_extract(argv[1],isChain,&data,&size,error,sizeof error));assert(strstr((char *)data,"BEGIN CERTIFICATE")||size>0);
 snprintf(chainPath,sizeof chainPath,"%s/fullchain.pem",argv[3]);save(chainPath,data,size);free(data);
 assert(sl_zip_extract(argv[1],isKey,&data,&size,error,sizeof error));
 snprintf(keyPath,sizeof keyPath,"%s/private.key",argv[3]);save(keyPath,data,size);free(data);
 assert(sl_tls_identity_check(chainPath,keyPath,detail,sizeof detail));printf("good IPA: %s\n",detail);assert(strstr(detail,"valid until"));
 assert(!sl_zip_extract(argv[2],isChain,&data,&size,error,sizeof error));printf("raw IPA: %s\n",error);assert(strstr(error,"No website certificate"));
 assert(!sl_zip_extract(chainPath,isChain,&data,&size,error,sizeof error));printf("not a zip: %s\n",error);
 assert(sl_zip_extract(argv[4],isChain,&data,&size,error,sizeof error));save(chainPath,data,size);free(data);
 assert(sl_zip_extract(argv[4],isKey,&data,&size,error,sizeof error));save(keyPath,data,size);free(data);
 assert(!sl_tls_identity_check(chainPath,keyPath,detail,sizeof detail));printf("wrong site: %s\n",detail);assert(strstr(detail,"not for car.tesla4khmer.com"));
 puts("Website certificate import from IPA verified");return 0;
}
