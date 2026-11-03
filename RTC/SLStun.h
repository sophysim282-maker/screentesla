#ifndef SL_STUN_H
#define SL_STUN_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct SLStunServer SLStunServer;
typedef struct {
    uint64_t requests, responses, rejected;
    uint32_t lastAddress; /* IPv4 in host byte order; private local clients only. */
    uint16_t lastPort, boundPort;
} SLStunStats;
/* Minimal unauthenticated IPv4 Binding responder for local ICE gathering.
 * It does not implement TURN, allocate relays, forward media or accept Internet clients. */
size_t SLStunBindingResponse(const uint8_t *request, size_t length,
                            uint32_t address, uint16_t port,
                            uint8_t *response, size_t capacity);
SLStunServer *SLStunStart(const char *address, uint16_t port);
SLStunStats SLStunSnapshot(SLStunServer *server);
void SLStunStop(SLStunServer *server);
#ifdef __cplusplus
}
#endif
#endif
