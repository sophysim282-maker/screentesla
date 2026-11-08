// Build 70: website diagnostics bookkeeping (logging only).
#include <assert.h>
#include <stdio.h>
#include "../App/WebWatch.h"
int main(void){
    SLWebWatch w={0};
    assert(!sl_web_watch_tick(&w,100,6));            // no car yet: never silent
    assert(sl_web_watch_secure(&w,100)<0);           // first request
    assert(!sl_web_watch_tick(&w,105,6));            // 5 s: fine
    w.http+=3; w.tlsFailures+=2; w.busy+=1;
    assert(sl_web_watch_tick(&w,106,6));             // 6 s: report once
    assert(w.http-w.httpMark==3 && w.tlsFailures-w.tlsMark==2 && w.busy-w.busyMark==1);
    assert(!sl_web_watch_tick(&w,120,6));            // not repeated
    double gap=sl_web_watch_secure(&w,130);
    assert(gap>29.9 && gap<30.1);                    // came back after 30 s
    assert(sl_web_watch_secure(&w,131)<0);           // normal request
    assert(w.http-w.httpMark==0);
    double last=0;
    assert(sl_web_watch_allow(&last,10,5)&&!sl_web_watch_allow(&last,12,5)&&sl_web_watch_allow(&last,15,5));
    puts("web watch ok");return 0;
}
