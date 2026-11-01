#import <Foundation/Foundation.h>
#import "VideoInbox.h"
#include <assert.h>
#include <stdio.h>
static void exercise(NSUInteger maxBytes,NSUInteger maxPackets,NSUInteger accepted) {
    dispatch_queue_t queue=dispatch_queue_create("inbox.test",DISPATCH_QUEUE_SERIAL);
    dispatch_semaphore_t entered=dispatch_semaphore_create(0),release=dispatch_semaphore_create(0);
    NSMutableArray *events=[NSMutableArray array];
    VideoInbox *inbox=[[VideoInbox alloc]initWithQueue:queue maxBytes:maxBytes maxPackets:maxPackets consume:^(NSData *data,uint64_t timestamp,NSUInteger generation){
        assert(generation==7);assert(data.length==3);
        [events addObject:@(timestamp)];
        if(timestamp==1){dispatch_semaphore_signal(entered);assert(dispatch_semaphore_wait(release,dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC))==0);}
    } discontinuity:^(NSUInteger generation){assert(generation==7);[events addObject:@"reset"]; }];
    NSData *packet=[@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    assert([inbox offer:packet timestamp:1 generation:7]);
    assert(dispatch_semaphore_wait(entered,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC))==0);
    NSTimeInterval before=NSProcessInfo.processInfo.systemUptime;
    for(NSUInteger i=2;i<=accepted;i++)assert([inbox offer:packet timestamp:i generation:7]);
    assert(![inbox offer:packet timestamp:99 generation:7]);
    assert(![inbox offer:packet timestamp:100 generation:7]);
    // A deliberately blocked decoder cannot hold the producer thread.
    assert(NSProcessInfo.processInfo.systemUptime-before<0.2);
    dispatch_semaphore_signal(release);dispatch_sync(queue,^{});
    assert(events.count==accepted+1);assert([events.lastObject isEqual:@"reset"]);
    for(NSUInteger i=0;i<accepted;i++)assert([events[i] unsignedIntegerValue]==i+1);
    assert([inbox offer:packet timestamp:101 generation:7]);dispatch_sync(queue,^{});
    assert([events.lastObject isEqual:@101]);
}
int main(void){@autoreleasepool{exercise(1024,3,3);exercise(4,100,1);puts("Video inbox passed: non-blocking producer, packet/byte bounds, ordered discontinuity and recovery.");}return 0;}
