// Build 145: Objective-C door to the ALAC decoder for Maps/AirPlaySound.swift (found with NSClassFromString).
#import <Foundation/Foundation.h>
#import "sl_alac.h"

@interface SLALAC : NSObject
+ (NSData *)decode:(NSData *)packet frames:(NSNumber *)frames;
@end

@implementation SLALAC
static void *decoder; static uint32_t decoderFrames;
+ (NSData *)decode:(NSData *)packet frames:(NSNumber *)frames {
    uint32_t want = frames.unsignedIntValue ?: 352;
    @synchronized(self) {
        if (!decoder || decoderFrames != want) { if (decoder) sl_alac_free(decoder); decoder = sl_alac_new(want, 16, 2, 44100); decoderFrames = want; }
        if (!decoder || !packet.length) return nil;
        NSMutableData *out = [NSMutableData dataWithLength:(NSUInteger)want * 2 * sizeof(int16_t)];
        int got = sl_alac_decode(decoder, packet.bytes, (uint32_t)packet.length, out.mutableBytes, want);
        if (got <= 0) return nil;
        out.length = (NSUInteger)got * 2 * sizeof(int16_t);
        return out;
    }
}
@end
