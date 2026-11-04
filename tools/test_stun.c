#include "../RTC/SLStun.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
static unsigned short r16(const unsigned char *p){return (unsigned short)((p[0]<<8)|p[1]);}
static unsigned r32(const unsigned char *p){return ((unsigned)p[0]<<24)|((unsigned)p[1]<<16)|((unsigned)p[2]<<8)|p[3];}
int main(void){
 unsigned char in[520]={0,1,0,0,0x21,0x12,0xa4,0x42,1,2,3,4,5,6,7,8,9,10,11,12},out[40];
 assert(SLStunBindingResponse(in,20,0xac140a04,54321,out,40)==40);assert(r16(out)==0x0101&&r16(out+2)==20&&memcmp(in+4,out+4,16)==0);assert(r16(out+20)==0x0020&&out[25]==1);assert((r16(out+26)^0x2112)==54321);assert((r32(out+28)^0x2112a442u)==0xac140a04);assert(r16(out+32)==0x8028);
 assert(!SLStunBindingResponse(in,19,0xac140a04,54321,out,40));assert(!SLStunBindingResponse(in,20,0xac140a04,54321,out,39));assert(!SLStunBindingResponse(in,20,0xac140a04,0,out,40));
 in[0]=1;assert(!SLStunBindingResponse(in,20,1,1,out,40));in[0]=0;in[4]=0;assert(!SLStunBindingResponse(in,20,1,1,out,40));in[4]=0x21;
 in[3]=4;in[20]=0;in[21]=6;assert(!SLStunBindingResponse(in,24,1,1,out,40));in[20]=0x80;in[21]=0x22;assert(SLStunBindingResponse(in,24,1,1,out,40)==40);
 in[23]=8;assert(!SLStunBindingResponse(in,24,1,1,out,40));in[23]=0;in[3]=0;assert(!SLStunBindingResponse(in,513,1,1,out,40));
 assert(!SLStunStart("0.0.0.0",0));assert(!SLStunStart("8.8.8.8",0));assert(!SLStunStart("192.168.93.142",0));
 puts("Local STUN packet tests passed: observed IPv4/port, transaction, bounded Binding response, fingerprint attribute, malformed/unsupported request rejection and restricted bind addresses.");return 0;
}
