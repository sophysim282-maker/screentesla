#ifndef SCREENLINK_REVERSE_CHANNEL_H
#define SCREENLINK_REVERSE_CHANNEL_H
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <ctype.h>
#define SL_REVERSE_LIMIT (256u*1024u)
#define SL_REVERSE_HEADER_LIMIT (16u*1024u)
typedef struct { unsigned char *data;size_t length; } sl_reverse_buffer;
static inline void sl_reverse_reset(sl_reverse_buffer *b){free(b->data);b->data=NULL;b->length=0;}
// Reverse AirPlay carries HTTP response acknowledgements and EVENT/1.0 frames,
// not HTTP requests. Drain all length-delimited frames, including binary bodies.
// Returns the number of completed frames, or -1 for invalid/bounded-out input.
static inline int sl_reverse_feed(sl_reverse_buffer *b,const void *data,size_t length){
    if(length>SL_REVERSE_LIMIT-b->length)return -1;
    if(length){void *p=realloc(b->data,b->length+length);if(!p)return -1;b->data=p;memcpy(b->data+b->length,data,length);b->length+=length;}
    int messages=0;
    while(b->length){
        size_t end=0;for(size_t i=0;i+3<b->length;i++)if(!memcmp(b->data+i,"\r\n\r\n",4)){end=i+4;break;}
        if(!end)return b->length>SL_REVERSE_HEADER_LIMIT?-1:messages;
        if(end>SL_REVERSE_HEADER_LIMIT)return -1;
        if(!((end>=9&&!memcmp(b->data,"HTTP/1.1 ",9)) || (end>=10&&!memcmp(b->data,"EVENT/1.0",9)&&(b->data[9]==' '||b->data[9]=='\r'))))return -1;
        size_t body=0;int found=0;
        size_t line=0;while(line+1<end){size_t next=line;while(next+1<end && !(b->data[next]=='\r'&&b->data[next+1]=='\n'))next++;
            if(next-line>=15 && !strncasecmp((const char *)b->data+line,"Content-Length:",15)){
                size_t p=line+15,value=0;while(p<next&&(b->data[p]==' '||b->data[p]=='\t'))p++;size_t digits=p;
                while(p<next && isdigit(b->data[p])){unsigned n=(unsigned)(b->data[p++]-'0');if(value>(SL_REVERSE_LIMIT-n)/10)return -1;value=value*10+n;}
                if(p==digits)return -1;
                while(p<next&&(b->data[p]==' '||b->data[p]=='\t'))p++;
                if(p!=next || (found&&body!=value))return -1;
                body=value;found=1;
            }
            line=next+2;
        }
        if(body>SL_REVERSE_LIMIT-end)return -1;
        size_t total=end+body;if(b->length<total)return messages;
        memmove(b->data,b->data+total,b->length-total);b->length-=total;messages++;
    }
    return messages;
}
#endif
