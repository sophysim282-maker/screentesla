#include "../App/FMP4.h"
#include "../App/AnnexB.h"
#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
static void write_sample(FILE *file,const uint8_t *data,size_t length,uint32_t *seq,int key) {
    uint8_t *out=malloc(length+256);assert(out);++*seq;size_t n=sl_mp4_fragment(out,length+256,data,length,*seq,(uint64_t)(*seq-1)*16667,16667,key);assert(n);assert(fwrite(out,1,n,file)==n);free(out);
}
int main(int argc,char **argv) {
    const uint8_t sps[]={0x67,0x42,0xc0,0x1e,0x89},pps[]={0x68,0xcb,0x83,0xcb},avcc[]={0,0,0,2,0x65,0x88};
    uint8_t box[2048];assert(sl_mp4_init(box,sizeof box,sps,sizeof sps,pps,sizeof pps,640,360)>500);
    assert(!sl_mp4_init(box,16,sps,sizeof sps,pps,sizeof pps,640,360));
    assert(!sl_mp4_init(box,sizeof box,sps,2,pps,sizeof pps,640,360));
    assert(sl_mp4_fragment(box,sizeof box,avcc,sizeof avcc,1,0,16667,1)>sizeof avcc);
    assert(!sl_mp4_fragment(box,16,avcc,sizeof avcc,1,0,16667,1));
    if(argc==3) {
        FILE *input=fopen(argv[1],"rb");assert(input);fseek(input,0,SEEK_END);long length=ftell(input);rewind(input);assert(length>0);
        uint8_t *data=malloc((size_t)length);assert(data);assert(fread(data,1,(size_t)length,input)==(size_t)length);fclose(input);
        size_t offsets[16384],sizes[16384];size_t count=sl_nals(data,(size_t)length,offsets,sizes,16384);assert(count<=16384);
        const uint8_t *sp=NULL,*pp=NULL;size_t sn=0,pn=0;
        for(size_t i=0;i<count;i++){int type=data[offsets[i]]&31;if(type==7){sp=data+offsets[i];sn=sizes[i];}if(type==8){pp=data+offsets[i];pn=sizes[i];}}
        assert(sp&&pp);uint8_t init[4096];size_t n=sl_mp4_init(init,sizeof init,sp,sn,pp,pn,640,360);assert(n);
        FILE *output=fopen(argv[2],"wb");assert(output);assert(fwrite(init,1,n,output)==n);
        uint8_t *sample=malloc((size_t)length);size_t used=0;int key=0;uint32_t sequence=0;
        for(size_t i=0;i<count;i++) {
            int type=data[offsets[i]]&31;
            if(type==9 && used){write_sample(output,sample,used,&sequence,key);used=0;key=0;}
            if(type==7||type==8||type==9)continue;
            size_t z=sizes[i];sample[used++]=(uint8_t)(z>>24);sample[used++]=(uint8_t)(z>>16);sample[used++]=(uint8_t)(z>>8);sample[used++]=(uint8_t)z;memcpy(sample+used,data+offsets[i],z);used+=z;if(type==5)key=1;
        }
        if(used)write_sample(output,sample,used,&sequence,key);
        fclose(output);free(sample);free(data);printf("Wrote %u fragments.\n",sequence);
    }
    puts("fMP4 bounds and initialization/fragment tests passed.");return 0;
}
