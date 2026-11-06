#ifndef SL_LOCAL_PACKET_H
#define SL_LOCAL_PACKET_H
#include <stddef.h>
#include <stdint.h>
#include <string.h>
/* Point-to-point reflection: only the configured local endpoint pair is accepted.
   Swapping both addresses preserves IPv4 and transport pseudoheader checksums. */
static inline int SLReflectLocalPacket(uint8_t *p, size_t n) {
    if(!p || n<20 || (p[0]>>4)!=4)return 0;
    size_t header=(p[0]&15)*4, total=((size_t)p[2]<<8)|p[3];
    if(header<20 || header>n || total<header || total!=n)return 0;
    const uint8_t iface[4]={10,7,1,1}, peer[4]={10,7,0,1};
    if(!((!memcmp(p+12,iface,4)&&!memcmp(p+16,peer,4)) ||
         (!memcmp(p+12,peer,4)&&!memcmp(p+16,iface,4))))return 0;
    uint8_t address[4];memcpy(address,p+12,4);memcpy(p+12,p+16,4);memcpy(p+16,address,4);
    return 1;
}
#endif
