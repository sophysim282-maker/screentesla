#include "../App/HotspotLink.h"
#include <assert.h>
#include <stdio.h>
int main(void){
    assert(sl_hotspot_peer(0xac140a04,0xac140a01,0xac140a01,0xfffffff0));
    assert(!sl_hotspot_peer(0x0a00004e,0xac140a01,0xac140a01,0xfffffff0));
    assert(!sl_hotspot_peer(0xac140a04,0x0a00004e,0xac140a01,0xfffffff0));
    assert(!sl_hotspot_peer(0xac140a01,0xac140a01,0xac140a01,0xfffffff0));
    assert(!sl_hotspot_peer(0xac140a04,0xac140a01,0xac140a01,0));
    puts("Hotspot link passed: bridge client accepted; other networks/interfaces and invalid masks rejected.");
}
