#include "../Tunnel/LocalPacket.h"
#include <assert.h>
#include <stdio.h>
static uint16_t checksum(const uint8_t *p,size_t n,uint32_t sum){
    for(size_t i=0;i+1<n;i+=2)sum+=((uint32_t)p[i]<<8)|p[i+1];
    if(n&1)sum+=(uint32_t)p[n-1]<<8;
    while(sum>>16)sum=(sum&65535)+(sum>>16);
    return (uint16_t)~sum;
}
static uint16_t transport(const uint8_t *p,size_t n){
    uint32_t sum=p[9]+(uint32_t)(n-20);
    for(int i=12;i<20;i+=2)sum+=((uint32_t)p[i]<<8)|p[i+1];
    return checksum(p+20,n-20,sum);
}
static void put16(uint8_t *p,uint16_t n){p[0]=n>>8;p[1]=n&255;}
int main(void){
    for(int tcp=0;tcp<=1;tcp++){
        uint8_t packet[64]={0x45},original[64];size_t n=tcp?51:39;
        put16(packet+2,(uint16_t)n);packet[8]=64;packet[9]=tcp?6:17;
        const uint8_t addresses[]={10,7,1,1,10,7,0,1};memcpy(packet+12,addresses,8);
        put16(packet+20,51000);put16(packet+22,7000);
        if(tcp)packet[32]=0x50;else put16(packet+24,(uint16_t)(n-20));
        memcpy(packet+(tcp?40:28),"hello world",11);
        put16(packet+(tcp?36:26),transport(packet,n));put16(packet+10,checksum(packet,20,0));memcpy(original,packet,n);
        assert(checksum(packet,20,0)==0 && transport(packet,n)==0);
        assert(SLReflectLocalPacket(packet,n));
        assert(checksum(packet,20,0)==0 && transport(packet,n)==0);
        assert(!memcmp(packet+20,original+20,n-20));
        assert(!memcmp(packet+12,original+16,4)&&!memcmp(packet+16,original+12,4));
        assert(SLReflectLocalPacket(packet,n)&&!memcmp(packet,original,n));
        packet[16]=8;assert(!SLReflectLocalPacket(packet,n));
        memcpy(packet,original,n);assert(!SLReflectLocalPacket(packet,n-1));
        packet[0]=0x44;assert(!SLReflectLocalPacket(packet,n));
        packet[0]=0x65;assert(!SLReflectLocalPacket(packet,n));
    }
    /* IP fragments preserve header/checksum and fragment payload. */
    uint8_t fragment[28]={0x45,0,0,28,0,1,0x20,0,64,17,0,0,10,7,1,1,10,7,0,1,1,2,3,4,5,6,7,8};
    put16(fragment+10,checksum(fragment,20,0));assert(SLReflectLocalPacket(fragment,sizeof fragment));assert(!checksum(fragment,20,0));assert(fragment[20]==1 && fragment[27]==8);
    assert(!SLReflectLocalPacket(NULL,0));
    puts("Local VPN packet tests passed: TCP/UDP checksums, payloads, bidirectional reflection, fragments, unrelated and malformed packets.");
}
