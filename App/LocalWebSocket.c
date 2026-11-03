#include "LocalWebSocket.h"
#include <openssl/sha.h>
#include <openssl/evp.h>
#include <string.h>
int sl_ws_accept(const char *key,char out[29]){
 if(!key || strlen(key)!=24 || key[22]!='=' || key[23]!='=')return 0;
 for(int i=0;i<22;i++)if(!((key[i]>='A'&&key[i]<='Z')||(key[i]>='a'&&key[i]<='z')||(key[i]>='0'&&key[i]<='9')||key[i]=='+'||key[i]=='/'))return 0;
 unsigned char raw[32],canonical[32];if(EVP_DecodeBlock(raw,(const unsigned char *)key,24)!=18)return 0;
 EVP_EncodeBlock(canonical,raw,16);if(memcmp(canonical,key,24))return 0;
 char joined[61];memcpy(joined,key,24);memcpy(joined+24,"258EAFA5-E914-47DA-95CA-C5AB0DC85B11",36);
 unsigned char digest[SHA_DIGEST_LENGTH];SHA1((const unsigned char *)joined,60,digest);EVP_EncodeBlock((unsigned char *)out,digest,sizeof digest);out[28]=0;return 1;
}
size_t sl_ws_header(uint8_t opcode,size_t n,uint8_t out[10]){
 if(n>2*1024*1024 || !(opcode==1||opcode==2||opcode==8||opcode==9||opcode==10) || (opcode>=8&&n>125))return 0;
 out[0]=0x80|opcode;
 if(n<126){out[1]=(uint8_t)n;return 2;}
 if(n<=65535){out[1]=126;out[2]=(uint8_t)(n>>8);out[3]=(uint8_t)n;return 4;}
 out[1]=127;for(int i=0;i<8;i++)out[2+i]=(uint8_t)((uint64_t)n>>(56-i*8));return 10;
}
int sl_ws_client(const uint8_t *p,size_t n,uint8_t *opcode,uint8_t out[126],size_t *size){
 if(!p || n<6 || (p[0]&0xf0)!=0x80 || !(p[1]&0x80))return 0;
 size_t length=p[1]&127;uint8_t op=p[0]&15;
 if(length>125 || n!=length+6 || !(op==1||op==8||op==9||op==10) || (op==8&&length==1))return 0;
 for(size_t i=0;i<length;i++)out[i]=p[6+i]^p[2+(i&3)];
 out[length]=0;*opcode=op;*size=length;return 1;
}
