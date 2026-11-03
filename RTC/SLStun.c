#include "SLStun.h"
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>
static uint16_t r16(const uint8_t *p){return (uint16_t)((p[0]<<8)|p[1]);}
static uint32_t r32(const uint8_t *p){return ((uint32_t)p[0]<<24)|((uint32_t)p[1]<<16)|((uint32_t)p[2]<<8)|p[3];}
static void w16(uint8_t *p,uint16_t n){p[0]=(uint8_t)(n>>8);p[1]=(uint8_t)n;}
static void w32(uint8_t *p,uint32_t n){p[0]=(uint8_t)(n>>24);p[1]=(uint8_t)(n>>16);p[2]=(uint8_t)(n>>8);p[3]=(uint8_t)n;}
static uint32_t crc32(const uint8_t *p,size_t n){uint32_t c=0xffffffffu;while(n--){c^=*p++;for(unsigned k=0;k<8;k++)c=(c>>1)^((c&1)?0xedb88320u:0);}return ~c;}
size_t SLStunBindingResponse(const uint8_t *in,size_t n,uint32_t address,uint16_t port,uint8_t *out,size_t cap){
    if(!in||!out||cap<40||n<20||n>512||r16(in)!=1||r32(in+4)!=0x2112a442u||r16(in+2)!=n-20||(r16(in+2)&3)||!port)return 0;
    for(size_t i=20;i<n;){
        if(n-i<4)return 0;
        uint16_t type=r16(in+i),len=r16(in+i+2);size_t padded=((size_t)len+3)&~(size_t)3;
        if(padded>n-i-4)return 0;
        /* Gathering Binding requests need no credentials. ICE connectivity checks,
         * authentication, CHANGE-REQUEST and unsupported required extensions are not served. */
        if(type<0x8000)return 0;
        if(type==0x8028&&(len!=4||i+8!=n||(crc32(in,i)^0x5354554eu)!=r32(in+i+4)))return 0;
        i+=4+padded;
    }
    memset(out,0,40);w16(out,0x0101);w16(out+2,20);w32(out+4,0x2112a442u);memcpy(out+8,in+8,12);
    w16(out+20,0x0020);w16(out+22,8);out[25]=1;w16(out+26,(uint16_t)(port^0x2112));w32(out+28,address^0x2112a442u);
    w16(out+32,0x8028);w16(out+34,4);w32(out+36,crc32(out,32)^0x5354554eu);return 40;
}
struct SLStunServer {int socket;pthread_t thread;pthread_mutex_t lock;atomic_bool stopping;bool loopback;SLStunStats stats;};
static bool allowed(SLStunServer *s,uint32_t ip){return s->loopback?(ip>>24)==127:(ip&0xffffff00u)==0xac140a00u;}
static void *serve(void *context){
    SLStunServer *s=context;
    while(!atomic_load(&s->stopping)){
        struct pollfd fd={.fd=s->socket,.events=POLLIN};int ready=poll(&fd,1,100);
        if(ready<0){if(errno==EINTR)continue;break;}
        if(!ready||!(fd.revents&POLLIN))continue;
        for(unsigned burst=0;burst<32&&!atomic_load(&s->stopping);burst++){
            uint8_t in[513],out[40];struct sockaddr_in source;socklen_t size=sizeof source;
            ssize_t n=recvfrom(s->socket,in,sizeof in,0,(struct sockaddr *)&source,&size);
            if(n<0){if(errno==EINTR)continue;break;}
            uint32_t ip=ntohl(source.sin_addr.s_addr);uint16_t port=ntohs(source.sin_port);
            size_t response=source.sin_family==AF_INET&&allowed(s,ip)?SLStunBindingResponse(in,(size_t)n,ip,port,out,sizeof out):0;
            pthread_mutex_lock(&s->lock);
            if(response){s->stats.requests++;s->stats.lastAddress=ip;s->stats.lastPort=port;}else s->stats.rejected++;
            pthread_mutex_unlock(&s->lock);
            if(response&&sendto(s->socket,out,response,0,(struct sockaddr *)&source,size)==(ssize_t)response){pthread_mutex_lock(&s->lock);s->stats.responses++;pthread_mutex_unlock(&s->lock);}
        }
    }return NULL;
}
SLStunServer *SLStunStart(const char *address,uint16_t port){
    struct sockaddr_in bindTo;memset(&bindTo,0,sizeof bindTo);bindTo.sin_family=AF_INET;bindTo.sin_port=htons(port);
    if(!address||inet_pton(AF_INET,address,&bindTo.sin_addr)!=1)return NULL;
    uint32_t ip=ntohl(bindTo.sin_addr.s_addr);bool loopback=(ip>>24)==127;
    if(!loopback&&ip!=0xac140a01u)return NULL;
    SLStunServer *s=calloc(1,sizeof *s);if(!s)return NULL;s->socket=-1;s->loopback=loopback;atomic_init(&s->stopping,false);pthread_mutex_init(&s->lock,NULL);
    s->socket=socket(AF_INET,SOCK_DGRAM,0);if(s->socket<0)goto fail;
    if(fcntl(s->socket,F_SETFD,FD_CLOEXEC)<0||fcntl(s->socket,F_SETFL,O_NONBLOCK)<0||bind(s->socket,(struct sockaddr *)&bindTo,sizeof bindTo)<0)goto fail;
    socklen_t size=sizeof bindTo;if(getsockname(s->socket,(struct sockaddr *)&bindTo,&size)<0)goto fail;s->stats.boundPort=ntohs(bindTo.sin_port);
    if(pthread_create(&s->thread,NULL,serve,s)!=0)goto fail;
    return s;
fail:if(s->socket>=0)close(s->socket);pthread_mutex_destroy(&s->lock);free(s);return NULL;
}
SLStunStats SLStunSnapshot(SLStunServer *s){SLStunStats result={0};if(s){pthread_mutex_lock(&s->lock);result=s->stats;pthread_mutex_unlock(&s->lock);}return result;}
void SLStunStop(SLStunServer *s){if(!s)return;atomic_store(&s->stopping,true);pthread_join(s->thread,NULL);close(s->socket);pthread_mutex_destroy(&s->lock);free(s);}
