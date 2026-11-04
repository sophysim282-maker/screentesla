#ifndef SL_ANNEX_B_H
#define SL_ANNEX_B_H
#include <stddef.h>
/* Return NAL payload ranges, excluding three/four-byte Annex B start codes. */
static size_t sl_nals(const unsigned char *p, size_t n, size_t *starts, size_t *sizes, size_t cap) {
    size_t count=0, begin=0; int found=0;
    for(size_t i=0;i+2<n;) {
        size_t prefix=0;
        if(p[i]==0 && p[i+1]==0) {
            if(p[i+2]==1) prefix=3;
            else if(i+3<n && p[i+2]==0 && p[i+3]==1) prefix=4;
        }
        if(!prefix) { i++; continue; }
        if(found && i>begin) { if(count==cap)return cap+1; starts[count]=begin;sizes[count++]=i-begin; }
        begin=i+prefix; found=1; i=begin;
    }
    if(found && n>begin) { if(count==cap)return cap+1; starts[count]=begin;sizes[count++]=n-begin; }
    return count;
}
#endif
