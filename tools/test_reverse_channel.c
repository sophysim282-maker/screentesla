#include "../App/ReverseChannel.h"
#include <assert.h>
#include <stdio.h>
int main(void){
 sl_reverse_buffer b={0};
 const char ack[]="HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n";
 const unsigned char event[]="EVENT/1.0\r\nContent-Type: application/x-apple-binary-plist\r\nContent-Length: 4\r\n\r\na\0bc";
 int messages=0;for(size_t i=0;i<sizeof(event)-1;i++){int n=sl_reverse_feed(&b,event+i,1);assert(n>=0);messages+=n;}assert(messages==1&&!b.length);
 unsigned char together[sizeof(ack)+sizeof(event)];size_t used=sizeof(ack)-1;memcpy(together,ack,used);memcpy(together+used,event,sizeof(event)-1);used+=sizeof(event)-1;
 assert(sl_reverse_feed(&b,together,used)==2);assert(!b.length);
 const char *bad="EVENT/1.0\r\nContent-Length: 3\r\nContent-Length: 4\r\n\r\n";assert(sl_reverse_feed(&b,bad,strlen(bad))==-1);sl_reverse_reset(&b);
 const char *huge="EVENT/1.0\r\nContent-Length: 9999999\r\n\r\n";assert(sl_reverse_feed(&b,huge,strlen(huge))==-1);sl_reverse_reset(&b);
 const char *request="POST /play HTTP/1.1\r\nContent-Length: 0\r\n\r\n";assert(sl_reverse_feed(&b,request,strlen(request))==-1);sl_reverse_reset(&b);
 puts("Reverse AirPlay passed: EVENT/1.0, binary bodies, bytewise fragmentation, coalesced HTTP acknowledgements, and bounded malformed input.");return 0;
}
