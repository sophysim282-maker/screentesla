#include "ZipEntry.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <zlib.h>
static uint16_t le16(const unsigned char *p){return (uint16_t)(p[0]|p[1]<<8);}
static uint32_t le32(const unsigned char *p){return (uint32_t)p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24;}
static int fail(char *error,size_t size,const char *message){if(error&&size)snprintf(error,size,"%s",message);return 0;}
int sl_zip_extract(const char *path,sl_zip_match match,unsigned char **data,size_t *size,char *error,size_t errorSize){
 *data=NULL;*size=0;
 FILE *f=fopen(path,"rb");if(!f)return fail(error,errorSize,"File could not be opened.");
 int ok=0;unsigned char *tail=NULL,*dir=NULL,*packed=NULL,*out=NULL;
 if(fseek(f,0,SEEK_END)!=0){fail(error,errorSize,"File could not be read.");goto done;}
 long length=ftell(f);if(length<22){fail(error,errorSize,"Not a ZIP or IPA file.");goto done;}
 long span=length<65557?length:65557;tail=malloc((size_t)span);
 if(!tail||fseek(f,length-span,SEEK_SET)!=0||fread(tail,1,(size_t)span,f)!=(size_t)span){fail(error,errorSize,"File could not be read.");goto done;}
 long end=-1;for(long i=span-22;i>=0;i--)if(le32(tail+i)==0x06054b50){end=i;break;}
 if(end<0){fail(error,errorSize,"Not a ZIP or IPA file.");goto done;}
 uint32_t dirSize=le32(tail+end+12),dirOffset=le32(tail+end+16);uint16_t count=le16(tail+end+10);
 if(dirOffset==0xffffffffu||(long)dirOffset+(long)dirSize>length){fail(error,errorSize,"Unsupported ZIP layout.");goto done;}
 dir=malloc(dirSize?dirSize:1);
 if(!dir||fseek(f,(long)dirOffset,SEEK_SET)!=0||fread(dir,1,dirSize,f)!=dirSize){fail(error,errorSize,"File could not be read.");goto done;}
 size_t p=0;
 for(uint16_t n=0;n<count;n++){
  if(p+46>dirSize||le32(dir+p)!=0x02014b50){fail(error,errorSize,"Damaged ZIP directory.");goto done;}
  uint16_t method=le16(dir+p+10),nameLength=le16(dir+p+28),extraLength=le16(dir+p+30),commentLength=le16(dir+p+32);
  uint32_t packedSize=le32(dir+p+20),plainSize=le32(dir+p+24),local=le32(dir+p+42);
  if(p+46+nameLength>dirSize){fail(error,errorSize,"Damaged ZIP directory.");goto done;}
  char name[1024];size_t copy=nameLength<sizeof name-1?nameLength:sizeof name-1;memcpy(name,dir+p+46,copy);name[copy]=0;
  p+=46+(size_t)nameLength+extraLength+commentLength;
  if(copy!=nameLength||!match(name))continue;
  if(plainSize>4*1024*1024||packedSize>4*1024*1024){fail(error,errorSize,"Certificate file is too large.");goto done;}
  unsigned char header[30];
  if(fseek(f,(long)local,SEEK_SET)!=0||fread(header,1,30,f)!=30||le32(header)!=0x04034b50){fail(error,errorSize,"Damaged ZIP entry.");goto done;}
  if(fseek(f,(long)local+30+le16(header+26)+le16(header+28),SEEK_SET)!=0){fail(error,errorSize,"Damaged ZIP entry.");goto done;}
  packed=malloc(packedSize?packedSize:1);out=malloc(plainSize?plainSize:1);
  if(!packed||!out||fread(packed,1,packedSize,f)!=packedSize){fail(error,errorSize,"File could not be read.");goto done;}
  if(method==0){if(packedSize!=plainSize){fail(error,errorSize,"Damaged ZIP entry.");goto done;}memcpy(out,packed,plainSize);}
  else if(method==8){
   z_stream z;memset(&z,0,sizeof z);if(inflateInit2(&z,-MAX_WBITS)!=Z_OK){fail(error,errorSize,"Decompression failed.");goto done;}
   z.next_in=packed;z.avail_in=packedSize;z.next_out=out;z.avail_out=plainSize;
   int r=inflate(&z,Z_FINISH);uLong produced=z.total_out;inflateEnd(&z);
   if(r!=Z_STREAM_END||produced!=plainSize){fail(error,errorSize,"Decompression failed.");goto done;}
  }else{fail(error,errorSize,"Unsupported ZIP compression.");goto done;}
  if(crc32(crc32(0L,Z_NULL,0),out,plainSize)!=le32(dir+p-(46+(size_t)nameLength+extraLength+commentLength)+16)){fail(error,errorSize,"Damaged ZIP entry (checksum).");goto done;}
  *data=out;*size=plainSize;out=NULL;ok=1;goto done;
 }
 fail(error,errorSize,"No website certificate found in this file.");
 done:
 free(tail);free(dir);free(packed);free(out);fclose(f);return ok;
}
