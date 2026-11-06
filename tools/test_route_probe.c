#include "../App/RouteProbe.h"
#include <assert.h>
#include <stdio.h>
int main(void){
    uint32_t bridge=0xac140a01u,client=0xac140a04u,mask=0xffffff00u,alias=0xf0030303u;
    assert(sl_route_probe_peer(client,bridge,bridge,mask,0));
    assert(!sl_route_probe_peer(client,alias,bridge,mask,0));
    assert(sl_route_probe_peer(client,alias,bridge,mask,1));
    assert(!sl_route_probe_peer(0xc0000201u,alias,bridge,mask,1));
    assert(!sl_route_probe_peer(client,0x0a070101u,bridge,mask,1));
    assert(!sl_route_probe_peer(client,alias,bridge,0,1));
    assert(!sl_route_probe_peer(bridge,alias,bridge,mask,1));
    assert(!sl_route_probe_peer(0xac140affu,alias,bridge,mask,1));
    assert(!sl_route_probe_peer(0xac140a00u,alias,bridge,mask,1));
    assert(sl_route_probe_peer(0x7f000001u,0x7f000001u,0,0,0));
    assert(!sl_route_probe_peer(0x7f000001u,alias,bridge,mask,1));
    puts("Read-only route probe access: bridge, owned alias, loopback and unrelated routes checked");
}
