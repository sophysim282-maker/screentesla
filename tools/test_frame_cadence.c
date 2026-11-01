#include "../App/FrameCadence.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    double next=0;int count=0;
    for(int i=0;i<1800;i++)count+=sl_frame_due(1.0+i/30.0,20,&next);
    assert(count>=1198 && count<=1201); // 60 seconds at ~20 fps, not 15 fps.
    next=0;count=0;
    for(int i=0;i<1800;i++) {
        double jitter=(i%3-1)*0.0005;
        count+=sl_frame_due(1.0+i/30.0+jitter,15,&next);
    }
    assert(count>=898 && count<=901);
    assert(sl_frame_due(100,20,&next));
    assert(!sl_frame_due(100.001,20,&next)); // A long pause does not create a burst.
    assert(sl_frame_due(100.051,20,&next));
    assert(!sl_frame_due(100.06,0,&next));
    puts("Frame cadence passed: non-divisible rates, jitter and pause recovery.");
    return 0;
}
