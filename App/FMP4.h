#ifndef SCREENLINK_FMP4_H
#define SCREENLINK_FMP4_H
#include <stdint.h>
#include <stddef.h>
#include <string.h>

typedef struct { uint8_t *p;size_t n,cap;int ok; } sl_mp4_writer;
static inline void sl_bytes(sl_mp4_writer *w,const void *p,size_t n){if(!w->ok || n>w->cap-w->n){w->ok=0;return;}memcpy(w->p+w->n,p,n);w->n+=n;}
static inline void sl_u8(sl_mp4_writer *w,uint8_t v){sl_bytes(w,&v,1);}
static inline void sl_u16(sl_mp4_writer *w,uint16_t v){sl_u8(w,(uint8_t)(v>>8));sl_u8(w,(uint8_t)v);}
static inline void sl_u32(sl_mp4_writer *w,uint32_t v){sl_u16(w,(uint16_t)(v>>16));sl_u16(w,(uint16_t)v);}
static inline void sl_u64(sl_mp4_writer *w,uint64_t v){sl_u32(w,(uint32_t)(v>>32));sl_u32(w,(uint32_t)v);}
static inline void sl_zero(sl_mp4_writer *w,size_t n){for(size_t i=0;i<n;i++)sl_u8(w,0);}
static inline void sl_patch32(sl_mp4_writer *w,size_t at,uint32_t v){if(at+4>w->n){w->ok=0;return;}w->p[at]=(uint8_t)(v>>24);w->p[at+1]=(uint8_t)(v>>16);w->p[at+2]=(uint8_t)(v>>8);w->p[at+3]=(uint8_t)v;}
static inline size_t sl_box(sl_mp4_writer *w,const char *name){size_t at=w->n;sl_u32(w,0);sl_bytes(w,name,4);return at;}
static inline void sl_end(sl_mp4_writer *w,size_t at){if(w->n-at>UINT32_MAX){w->ok=0;return;}sl_patch32(w,at,(uint32_t)(w->n-at));}
static inline void sl_matrix(sl_mp4_writer *w){const uint32_t m[]={0x10000,0,0,0,0x10000,0,0,0,0x40000000};for(size_t i=0;i<9;i++)sl_u32(w,m[i]);}

static inline size_t sl_mp4_init(uint8_t *out,size_t cap,const uint8_t *sps,size_t sn,const uint8_t *pps,size_t pn,uint16_t width,uint16_t height){
    if(!out || !sps || !pps || sn<4 || sn>65535 || !pn || pn>65535 || !width || !height)return 0;
    sl_mp4_writer w={out,0,cap,1};size_t b=sl_box(&w,"ftyp");sl_bytes(&w,"iso6",4);sl_u32(&w,1);sl_bytes(&w,"iso6isommp41avc1",16);sl_end(&w,b);
    size_t moov=sl_box(&w,"moov");b=sl_box(&w,"mvhd");sl_u32(&w,0);sl_zero(&w,8);sl_u32(&w,1000000);sl_u32(&w,0);sl_u32(&w,0x10000);sl_u16(&w,0x100);sl_zero(&w,10);sl_matrix(&w);sl_zero(&w,24);sl_u32(&w,2);sl_end(&w,b);
    size_t trak=sl_box(&w,"trak");b=sl_box(&w,"tkhd");sl_u32(&w,7);sl_zero(&w,8);sl_u32(&w,1);sl_zero(&w,16);sl_zero(&w,8);sl_matrix(&w);sl_u32(&w,(uint32_t)width<<16);sl_u32(&w,(uint32_t)height<<16);sl_end(&w,b);
    size_t mdia=sl_box(&w,"mdia");b=sl_box(&w,"mdhd");sl_u32(&w,0);sl_zero(&w,8);sl_u32(&w,1000000);sl_u32(&w,0);sl_u16(&w,0x55c4);sl_u16(&w,0);sl_end(&w,b);
    b=sl_box(&w,"hdlr");sl_zero(&w,8);sl_bytes(&w,"vide",4);sl_zero(&w,12);sl_bytes(&w,"ScreenLink",11);sl_end(&w,b);
    size_t minf=sl_box(&w,"minf");b=sl_box(&w,"vmhd");sl_u32(&w,1);sl_zero(&w,8);sl_end(&w,b);
    size_t dinf=sl_box(&w,"dinf");b=sl_box(&w,"dref");sl_u32(&w,0);sl_u32(&w,1);size_t url=sl_box(&w,"url ");sl_u32(&w,1);sl_end(&w,url);sl_end(&w,b);sl_end(&w,dinf);
    size_t stbl=sl_box(&w,"stbl"),stsd=sl_box(&w,"stsd");sl_u32(&w,0);sl_u32(&w,1);size_t avc=sl_box(&w,"avc1");sl_zero(&w,6);sl_u16(&w,1);sl_zero(&w,16);sl_u16(&w,width);sl_u16(&w,height);sl_u32(&w,0x480000);sl_u32(&w,0x480000);sl_u32(&w,0);sl_u16(&w,1);sl_zero(&w,32);sl_u16(&w,24);sl_u16(&w,0xffff);
    b=sl_box(&w,"avcC");sl_u8(&w,1);sl_u8(&w,sps[1]);sl_u8(&w,sps[2]);sl_u8(&w,sps[3]);sl_u8(&w,0xff);sl_u8(&w,0xe1);sl_u16(&w,(uint16_t)sn);sl_bytes(&w,sps,sn);sl_u8(&w,1);sl_u16(&w,(uint16_t)pn);sl_bytes(&w,pps,pn);sl_end(&w,b);sl_end(&w,avc);sl_end(&w,stsd);
    const char *tables[]={"stts","stsc","stsz","stco"};for(int i=0;i<4;i++){b=sl_box(&w,tables[i]);sl_u32(&w,0);sl_u32(&w,0);if(i==2)sl_u32(&w,0);sl_end(&w,b);}sl_end(&w,stbl);sl_end(&w,minf);sl_end(&w,mdia);sl_end(&w,trak);
    size_t mvex=sl_box(&w,"mvex");b=sl_box(&w,"trex");sl_u32(&w,0);sl_u32(&w,1);sl_u32(&w,1);sl_zero(&w,12);sl_end(&w,b);sl_end(&w,mvex);sl_end(&w,moov);return w.ok?w.n:0;
}
static inline size_t sl_mp4_fragment(uint8_t *out,size_t cap,const uint8_t *avcc,size_t size,uint32_t sequence,uint64_t time,uint32_t duration,int key){
    if(!out || !avcc || !size || size>UINT32_MAX-128 || !duration)return 0;
    sl_mp4_writer w={out,0,cap,1};size_t moof=sl_box(&w,"moof"),b=sl_box(&w,"mfhd");sl_u32(&w,0);sl_u32(&w,sequence);sl_end(&w,b);
    size_t traf=sl_box(&w,"traf");b=sl_box(&w,"tfhd");sl_u32(&w,0x020000);sl_u32(&w,1);sl_end(&w,b);b=sl_box(&w,"tfdt");sl_u32(&w,0x01000000);sl_u64(&w,time);sl_end(&w,b);
    b=sl_box(&w,"trun");sl_u32(&w,0x701);sl_u32(&w,1);size_t offset=w.n;sl_u32(&w,0);sl_u32(&w,duration);sl_u32(&w,(uint32_t)size);sl_u32(&w,key?0x02000000:0x01010000);sl_end(&w,b);sl_end(&w,traf);sl_end(&w,moof);sl_patch32(&w,offset,(uint32_t)(w.n+8));
    b=sl_box(&w,"mdat");sl_bytes(&w,avcc,size);sl_end(&w,b);return w.ok?w.n:0;
}
#endif
