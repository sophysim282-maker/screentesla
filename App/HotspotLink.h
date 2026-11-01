#ifndef SCREENLINK_HOTSPOT_LINK_H
#define SCREENLINK_HOTSPOT_LINK_H
#include <stdint.h>
// Addresses use the same byte order. Match the actual bridge interface/mask,
// rather than assuming every iPhone hotspot always uses 172.20.10.1.
static inline int sl_hotspot_peer(uint32_t peer,uint32_t local,uint32_t bridge,uint32_t mask){
    return mask && bridge && local==bridge && peer!=bridge && peer && (peer&mask)==(bridge&mask);
}
#endif
