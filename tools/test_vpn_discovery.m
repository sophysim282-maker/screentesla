#import <Foundation/Foundation.h>
#import "VPNDiscovery.h"

// Run on a Mac to verify real Bonjour local-only registration and resolution.
// This does not test the iPhone AirPlay route picker or the AirPlay handshake.
int main(void) {
    @autoreleasepool {
        VPNDiscovery *proxy=[VPNDiscovery new];
        __block BOOL verified=NO;
        proxy.status=^(NSString *message){
            puts(message.UTF8String);
            if([message hasPrefix:@"Local proxy address verified:"])verified=YES;
        };
        NSString *suffix=[NSUUID.UUID.UUIDString.lowercaseString substringToIndex:12];
        NSDictionary *profile=@{@"name":[@"ScreenLink Test " stringByAppendingString:suffix],
            @"raopName":[@"02534C000001@ScreenLink Test " stringByAppendingString:suffix],
            @"host":[NSString stringWithFormat:@"screenlink-test-%@.local.",suffix],
            @"peer":@"10.7.0.1",@"port":@7000,
            @"airplayTXT":@[@"deviceid=02:53:4c:00:00:01",@"features=0x5A7FFEE6"],
            @"raopTXT":@[@"txtvers=1",@"ch=2"]};
        if(![proxy startWithProfile:profile])return 1;
        NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:8];
        while(!verified && deadline.timeIntervalSinceNow>0)
            [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        [proxy stop];
        if(!verified){fputs("Local-only Bonjour lookup did not complete.\n",stderr);return 1;}
        puts("Local-only proxy browse, SRV resolve and IPv4 lookup passed on macOS.");
        return 0;
    }
}
