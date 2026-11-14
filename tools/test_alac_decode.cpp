// Build 145: checks the ALAC wrapper (ThirdParty/ALAC/sl_alac.cpp) against a reference decode.
// Usage: test_alac_decode <packets.bin> <reference.raw> <samples per packet>
// packets.bin: repeated [uint32 big-endian length][packet bytes], 16-bit stereo, 44.1 kHz.
// reference.raw: the same sound as 16-bit little-endian interleaved PCM.
#include "sl_alac.h"
#include <cstdio>
#include <cstring>
#include <vector>
#include <cstdlib>

static std::vector<unsigned char> readAll(const char *path) {
    std::vector<unsigned char> data; FILE *f = fopen(path, "rb"); if (!f) return data;
    unsigned char buf[65536]; size_t n; while ((n = fread(buf, 1, sizeof buf, f)) > 0) data.insert(data.end(), buf, buf + n);
    fclose(f); return data;
}

int main(int argc, char **argv) {
    if (argc != 4) { fprintf(stderr, "usage\n"); return 2; }
    std::vector<unsigned char> packets = readAll(argv[1]), ref = readAll(argv[2]);
    unsigned frames = (unsigned)atoi(argv[3]);
    void *d = sl_alac_new(frames, 16, 2, 44100);
    if (!d) { puts("ALAC_NEW_FAILED"); return 1; }
    size_t at = 0, out = 0; int count = 0, bad = 0, mismatch = 0;
    std::vector<int16_t> buffer(frames * 2); int16_t *pcm = buffer.data();
    while (at + 4 <= packets.size()) {
        uint32_t len = (uint32_t)packets[at] << 24 | (uint32_t)packets[at + 1] << 16 | (uint32_t)packets[at + 2] << 8 | packets[at + 3];
        at += 4; if (at + len > packets.size()) break;
        int got = sl_alac_decode(d, &packets[at], len, pcm, frames);
        at += len; count++;
        if (got <= 0) { bad++; continue; }
        size_t bytes = (size_t)got * 4;
        if (out + bytes <= ref.size() && memcmp(&ref[out], pcm, bytes) != 0) mismatch++;
        out += bytes;
    }
    sl_alac_free(d);
    printf("packets %d, failed %d, different from reference %d, samples %zu of %zu\n", count, bad, mismatch, out / 4, ref.size() / 4);
    if (count < 10 || bad || mismatch || out != ref.size()) { puts("ALAC_DECODE_FAILED"); return 1; }
    puts("ALAC_DECODE_PASSED");
    return 0;
}
