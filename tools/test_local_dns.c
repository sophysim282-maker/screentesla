// Build 77: the VPN's own answer for car.tesla4khmer.com.
#include "../Tunnel/LocalDNS.h"
#include <assert.h>
#include <stdio.h>
static size_t query(uint8_t *p,const char *name,uint16_t type,int edns,uint16_t port){
    memset(p,0,600);uint8_t *u=p+20,*d=u+8;size_t q=12;
    for(const char *s=name;*s;){const char *dot=strchr(s,'.');size_t len=dot?(size_t)(dot-s):strlen(s);d[q++]=(uint8_t)len;memcpy(d+q,s,len);q+=len;s+=len+(dot?1:0);if(!dot)break;}
    d[q++]=0;d[q++]=type>>8;d[q++]=type&255;d[q++]=0;d[q++]=1;
    d[0]=0x12;d[1]=0x34;d[2]=0x01;d[5]=1;
    if(edns){d[11]=1;const uint8_t opt[11]={0,0,41,0x10,0,0,0,0,0,0,0};memcpy(d+q,opt,11);q+=11;}
    size_t udp=8+q,total=20+udp;
    p[0]=0x45;p[2]=total>>8;p[3]=total&255;p[8]=64;p[9]=17;
    const uint8_t src[4]={172,20,10,2};memcpy(p+12,src,4);memcpy(p+16,SL_DNS_SERVER,4);
    u[0]=0xd4;u[1]=0x31;u[2]=port>>8;u[3]=port&255;u[4]=udp>>8;u[5]=udp&255;
    uint16_t s=sl_dns_ip_checksum(p,20);p[10]=s>>8;p[11]=s&255;return total;
}
int main(void){
    uint8_t p[600];size_t n,r;
    n=query(p,"car.tesla4khmer.com",1,1,53);r=SLAnswerLocalDNS(p,n,sizeof p);assert(r>0);
    uint8_t *d=p+28;assert(sl_dns_ip_checksum(p,20)==0);assert(p[12]==10&&p[13]==7&&p[14]==0&&p[15]==53);assert(p[16]==172&&p[19]==2);
    assert(p[20]==0&&p[21]==53&&p[22]==0xd4&&p[23]==0x31);assert(d[0]==0x12&&d[1]==0x34&&(d[2]&0x80)&&(d[2]&0x04)&&(d[2]&0x01)&&(d[3]&0x0f)==0);
    assert(d[7]==1&&d[11]==0);assert(!memcmp(p+r-4,SL_DNS_ANSWER,4));assert((size_t)((p[2]<<8)|p[3])==r);
    puts("A car.tesla4khmer.com -> 240.3.3.3 (with EDNS, header checksum valid)");
    n=query(p,"CAR.Tesla4Khmer.COM",1,0,53);r=SLAnswerLocalDNS(p,n,sizeof p);assert(r>0&&!memcmp(p+r-4,SL_DNS_ANSWER,4));puts("case-insensitive name");
    n=query(p,"car.tesla4khmer.com",28,0,53);r=SLAnswerLocalDNS(p,n,sizeof p);assert(r>0&&p[28+7]==0&&(p[28+3]&0x0f)==0);puts("AAAA -> no IPv6, NOERROR");
    n=query(p,"www.google.com",1,0,53);r=SLAnswerLocalDNS(p,n,sizeof p);assert(r>0&&(p[28+3]&0x0f)==5&&p[28+7]==0);puts("other name -> REFUSED");
    n=query(p,"x.car.tesla4khmer.com",1,0,53);r=SLAnswerLocalDNS(p,n,sizeof p);assert(r>0&&(p[28+3]&0x0f)==5);puts("subdomain -> REFUSED");
    n=query(p,"car.tesla4khmer.com",1,0,5353);assert(SLAnswerLocalDNS(p,n,sizeof p)==0);puts("other port ignored");
    n=query(p,"car.tesla4khmer.com",1,0,53);p[16]=8;p[17]=8;p[18]=8;p[19]=8;assert(SLAnswerLocalDNS(p,n,sizeof p)==0);puts("other DNS server ignored");
    n=query(p,"car.tesla4khmer.com",1,0,53);assert(SLAnswerLocalDNS(p,n-1,sizeof p)==0);assert(SLAnswerLocalDNS(p,n,n)==0);puts("truncated/too-small buffers ignored");
    n=query(p,"car.tesla4khmer.com",1,0,53);p[28+12]=0xc0;assert(SLAnswerLocalDNS(p,n,sizeof p)==0);puts("compressed/garbled names ignored");
    puts("LOCAL_DNS_PASSED");return 0;
}
