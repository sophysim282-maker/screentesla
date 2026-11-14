#include "sl_alac.h"
#include "ALACDecoder.h"
#include "ALACBitUtilities.h"
#include <new>
#include <string.h>

struct SLAlac { ALACDecoder decoder; uint32_t frames; uint8_t channels; uint8_t bitDepth; };

static void put32(uint8_t *p, uint32_t v) { p[0] = (uint8_t)(v >> 24); p[1] = (uint8_t)(v >> 16); p[2] = (uint8_t)(v >> 8); p[3] = (uint8_t)v; }

extern "C" void *sl_alac_new(uint32_t frames, uint8_t bitDepth, uint8_t channels, uint32_t sampleRate) {
    if (!frames || frames > 16384 || !channels || channels > 2 || bitDepth != 16) return NULL;
    SLAlac *alac = new (std::nothrow) SLAlac;
    if (!alac) return NULL;
    // ALACSpecificConfig, 24 bytes big-endian: the AirPlay settings (rice 40/10/14, max run 255).
    uint8_t cookie[24];
    memset(cookie, 0, sizeof cookie);
    put32(cookie, frames);
    cookie[4] = 0; cookie[5] = bitDepth; cookie[6] = 40; cookie[7] = 10; cookie[8] = 14; cookie[9] = channels;
    cookie[10] = 0; cookie[11] = 255;
    put32(cookie + 20, sampleRate);
    if (alac->decoder.Init(cookie, sizeof cookie) != 0) { delete alac; return NULL; }
    alac->frames = frames; alac->channels = channels; alac->bitDepth = bitDepth;
    return alac;
}

extern "C" int sl_alac_decode(void *decoder, const uint8_t *packet, uint32_t length, int16_t *out, uint32_t maxFrames) {
    SLAlac *alac = (SLAlac *)decoder;
    if (!alac || !packet || !length || !out || maxFrames < alac->frames) return -1;
    // The decoder's bit reader does not stop at the end of the packet; give it a zero-padded copy big enough
    // for a whole uncompressed frame, so a short or odd packet can never read outside memory.
    uint32_t pad = alac->frames * alac->channels * 4 + 64;
    if (length > 65536) return -1;
    uint8_t *copy = new (std::nothrow) uint8_t[length + pad];
    if (!copy) return -1;
    memcpy(copy, packet, length); memset(copy + length, 0, pad);
    BitBuffer bits;
    BitBufferInit(&bits, copy, length);
    uint32_t got = 0;
    int32_t status = alac->decoder.Decode(&bits, (uint8_t *)out, alac->frames, alac->channels, &got);
    delete[] copy;
    if (status != 0 || got > maxFrames) return -1;
    return (int)got;
}

extern "C" void sl_alac_free(void *decoder) { delete (SLAlac *)decoder; }
