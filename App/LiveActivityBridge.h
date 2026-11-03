#pragma once
#import <Foundation/Foundation.h>
#import <objc/message.h>

// Optional Swift adapter: native macOS test executables do not link ActivityKit.
static inline void SLPublishLiveActivity(NSDictionary *snapshot, BOOL canStart) {
    if (@available(iOS 16.2, *)) {
    Class adapter=NSClassFromString(@"SLLiveActivityController");
    SEL selector=NSSelectorFromString(@"publishSnapshot:canStart:");
    if([adapter respondsToSelector:selector])
        ((void (*)(id,SEL,NSDictionary *,BOOL))objc_msgSend)(adapter,selector,snapshot,canStart);
    }
}
