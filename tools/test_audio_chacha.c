// Build 145: the newer AirPlay 2 sound lock (ChaCha20-Poly1305 with the stream's "shk" key) is opened by the
// patched raop_buffer_decrypt, and a packet with a wrong tag falls back instead of being accepted.
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <openssl/evp.h>
#include "raop_buffer.h"
unsigned char sl_audio_shk[32];
int sl_audio_shk_len = 0;
extern int sl_audio_chacha_ok, sl_audio_chacha_fail;

int main(void) {
    for (int i = 0; i < 32; i++) sl_audio_shk[i] = (unsigned char)(i * 7 + 1);
    sl_audio_shk_len = 32;
    unsigned char key[16] = {0}, iv[16] = {0}, secret[32] = {0};
    raop_buffer_t *buffer = raop_buffer_init(NULL, key, iv, secret);
    assert(buffer);
    unsigned char plain[40]; for (int i = 0; i < 40; i++) plain[i] = (unsigned char)(0x20 + i);
    unsigned char packet[12 + 40 + 16 + 8];
    for (int i = 0; i < 12; i++) packet[i] = (unsigned char)(0x80 + i);
    unsigned char nonce8[8] = {1, 2, 3, 4, 5, 6, 7, 8}, nonce[12] = {0};
    memcpy(nonce + 4, nonce8, 8);
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new(); int len = 0;
    assert(EVP_EncryptInit_ex(ctx, EVP_chacha20_poly1305(), NULL, NULL, NULL));
    assert(EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_IVLEN, 12, NULL));
    assert(EVP_EncryptInit_ex(ctx, NULL, NULL, sl_audio_shk, nonce));
    assert(EVP_EncryptUpdate(ctx, NULL, &len, packet + 4, 8));
    assert(EVP_EncryptUpdate(ctx, packet + 12, &len, plain, 40));
    assert(EVP_EncryptFinal_ex(ctx, packet + 12 + len, &len));
    assert(EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_GET_TAG, 16, packet + 12 + 40));
    EVP_CIPHER_CTX_free(ctx);
    memcpy(packet + 12 + 40 + 16, nonce8, 8);
    unsigned char out[64]; unsigned int outlen = 0;
    assert(raop_buffer_decrypt(buffer, packet, out, 40 + 24, &outlen) == 1);
    assert(outlen == 40 && memcmp(out, plain, 40) == 0 && sl_audio_chacha_ok == 1);
    packet[12 + 40] ^= 1;   // broken tag: must not be accepted as ChaCha sound
    assert(raop_buffer_decrypt(buffer, packet, out, 40 + 24, &outlen) == 1);
    assert(sl_audio_chacha_fail == 1 && outlen == 64);
    raop_buffer_destroy(buffer);
    puts("AUDIO_CHACHA_PASSED");
    return 0;
}
