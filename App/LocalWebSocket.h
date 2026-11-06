#ifndef SL_LOCAL_WEBSOCKET_H
#define SL_LOCAL_WEBSOCKET_H
#include <stddef.h>
#include <stdint.h>
/* RFC 6455 accept value; accepts only a canonical 16-byte client nonce. */
int sl_ws_accept(const char *key,char output[29]);
/* Server frame header, FIN set, no compression/masking, 2 MiB hard bound. */
size_t sl_ws_header(uint8_t opcode,size_t length,uint8_t output[10]);
/* One complete small masked client control/text frame. No fragmentation. */
int sl_ws_client(const uint8_t *bytes,size_t length,uint8_t *opcode,uint8_t output[126],size_t *size);
#endif
