#ifndef SL_ROUTE_PROBE_H
#define SL_ROUTE_PROBE_H
#include <stdint.h>
/* Host byte order. A probe is read-only; this permission never grants media access. */
static inline int sl_route_probe_peer(uint32_t peer,uint32_t local,uint32_t bridge,uint32_t mask,int aliasOwned) {
    if((peer>>24)==127 && (local>>24)==127)return 1;
    if(!mask || !bridge || !peer || peer==bridge || (peer&mask)!=(bridge&mask))return 0;
    if(!(peer&~mask) || (peer&~mask)==~mask)return 0;
    return local==bridge || (aliasOwned && local==0xf0030303u);
}
#endif
