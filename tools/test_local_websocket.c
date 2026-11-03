#include "../App/LocalWebSocket.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
int main(void){char accept[29];assert(sl_ws_accept("dGhlIHNhbXBsZSBub25jZQ==",accept));assert(!strcmp(accept,"s3pPLMBiTxaQ9kYGzzhZRbK+xOo="));assert(!sl_ws_accept("bad",accept));assert(!sl_ws_accept("dGhlIHNhbXBsZSBub25jZR==",accept));uint8_t h[10];assert(sl_ws_header(2,70000,h)==10&&h[1]==127&&h[7]==1&&h[8]==0x11&&h[9]==0x70);assert(!sl_ws_header(2,3*1024*1024,h));assert(!sl_ws_header(9,126,h));uint8_t p[]={0x81,0x84,1,2,3,4,'n'^1,'e'^2,'x'^3,'t'^4},out[126],op;size_t size;assert(sl_ws_client(p,sizeof p,&op,out,&size)&&op==1&&size==4&&!memcmp(out,"next",4));p[1]=4;assert(!sl_ws_client(p,sizeof p,&op,out,&size));p[1]=0x84;p[0]=1;assert(!sl_ws_client(p,sizeof p,&op,out,&size));puts("WebSocket accept vector, frame lengths, masked client frames and rejection bounds passed");}
