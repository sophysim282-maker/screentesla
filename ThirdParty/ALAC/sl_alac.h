// Build 145: small C wrapper around Apple's open-source Apple Lossless (ALAC) decoder, used for the sound of
// other apps that the iPhone sends over AirPlay (kind 2). The iPhone's own unpacker refused every packet.
#ifndef SL_ALAC_H
#define SL_ALAC_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
void *sl_alac_new(uint32_t frames, uint8_t bitDepth, uint8_t channels, uint32_t sampleRate);
// Returns the number of samples per channel written to out (16-bit interleaved), or -1 on error.
int sl_alac_decode(void *decoder, const uint8_t *packet, uint32_t length, int16_t *out, uint32_t maxFrames);
void sl_alac_free(void *decoder);
#ifdef __cplusplus
}
#endif
#endif
