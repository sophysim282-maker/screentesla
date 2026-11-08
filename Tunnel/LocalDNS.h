#ifndef SL_LOCAL_DNS_H
#define SL_LOCAL_DNS_H
#include <stddef.h>
#include <stdint.h>
#include <string.h>
/* Build 77: the VPN answers name lookups for car.tesla4khmer.com itself, so the
   car's website no longer depends on an internet DNS answer (which failed with
   "server IP address could not be found" while https://240.3.3.3 still worked).
   Only UDP queries sent to SL_DNS_SERVER:53 are handled; everything else is left
   alone. A -> 240.3.3.3, AAAA -> no IPv6 (NOERROR, empty), other names REFUSED.
   The packet is rewritten in place as the reply; returns the reply length or 0. */
static const uint8_t SL_DNS_SERVER[4]={10,7,0,53};
static const uint8_t SL_DNS_ANSWER[4]={240,3,3,3};
static inline uint16_t sl_dns_ip_checksum(const uint8_t *p,size_t n){
    uint32_t sum=0;for(size_t i=0;i+1<n;i+=2)sum+=(uint32_t)(p[i]<<8|p[i+1]);
    while(sum>>16)sum=(sum&0xffff)+(sum>>16);
    return (uint16_t)~sum;
}
static inline int sl_dns_name_is_car(const uint8_t *q,size_t n,size_t *end){
    static const char *labels[3]={"car","tesla4khmer","com"};size_t p=0;int index=0;
    while(p<n){uint8_t len=q[p];if(len==0){*end=p+1;return index==3;}
        if(len&0xc0||len>63||p+1+len>n)return -1;
        int match=index<3&&strlen(labels[index])==len;
        for(size_t i=0;match&&i<len;i++){uint8_t c=q[p+1+i];if(c>='A'&&c<='Z')c+=32;if(c!=(uint8_t)labels[index][i])match=0;}
        if(!match)index=99;else index++;p+=1+len;}
    return -1;
}
static inline size_t SLAnswerLocalDNS(uint8_t *p,size_t n,size_t capacity){
    if(!p||n<20||(p[0]>>4)!=4||p[9]!=17)return 0;
    size_t ihl=(size_t)(p[0]&15)*4,total=((size_t)p[2]<<8)|p[3];
    if(ihl<20||total!=n||n<ihl+8+12||memcmp(p+16,SL_DNS_SERVER,4))return 0;
    if(((p[6]&0x3f)|p[7])!=0)return 0; /* no fragments */
    uint8_t *u=p+ihl,*d=u+8;if(((u[2]<<8)|u[3])!=53)return 0;
    size_t udp=((size_t)u[4]<<8)|u[5];if(udp<8+12||ihl+udp>n)return 0;
    size_t dns=udp-8;if(d[2]&0x80)return 0; /* not a query */
    if(((d[4]<<8)|d[5])!=1)return 0;
    size_t qend=0;int car=sl_dns_name_is_car(d+12,dns-12,&qend);if(car<0)return 0;
    size_t question=12+qend+4;if(question>dns)return 0;
    uint16_t qtype=(uint16_t)(d[12+qend]<<8|d[13+qend]),qclass=(uint16_t)(d[14+qend]<<8|d[15+qend]);
    int answerA=car&&qtype==1&&qclass==1;
    size_t reply=question+(answerA?16:0);if(ihl+8+reply>capacity)return 0;
    uint8_t opcode=d[2]&0x78;
    d[2]=0x80|opcode|0x04|(d[2]&0x01); /* QR, AA, keep RD */
    d[3]=0x80|(car?0:5);                 /* RA, NOERROR or REFUSED */
    d[6]=0;d[7]=answerA?1:0;d[8]=d[9]=d[10]=d[11]=0;
    if(answerA){uint8_t *a=d+question;const uint8_t rr[16]={0xc0,0x0c,0,1,0,1,0,0,0,60,0,4,SL_DNS_ANSWER[0],SL_DNS_ANSWER[1],SL_DNS_ANSWER[2],SL_DNS_ANSWER[3]};memcpy(a,rr,16);}
    uint8_t tmp[4];memcpy(tmp,u,2);memcpy(u,u+2,2);memcpy(u+2,tmp,2);
    size_t udpLen=8+reply;u[4]=(uint8_t)(udpLen>>8);u[5]=(uint8_t)udpLen;u[6]=u[7]=0; /* UDP checksum optional on IPv4 */
    memcpy(tmp,p+12,4);memcpy(p+12,p+16,4);memcpy(p+16,tmp,4);
    size_t out=ihl+udpLen;p[2]=(uint8_t)(out>>8);p[3]=(uint8_t)out;p[8]=64;p[10]=p[11]=0;
    uint16_t sum=sl_dns_ip_checksum(p,ihl);p[10]=(uint8_t)(sum>>8);p[11]=(uint8_t)sum;
    return out;
}
#endif
