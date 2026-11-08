#ifndef SL_WEB_WATCH_H
#define SL_WEB_WATCH_H
// Build 70 website diagnostics. Pure bookkeeping only: nothing here changes
// how requests are served, how media is delivered or how the player runs.
// Times are monotonic seconds (systemUptime). Callers hold their own lock.

typedef struct {
    double lastSecure;      // last HTTPS request from the car (0 = none yet)
    int silent;             // a silence report was emitted and not yet cleared
    unsigned long http, https, tlsFailures, busy, wrongHost; // running totals
    unsigned long httpMark, tlsMark, busyMark, wrongHostMark; // totals at lastSecure
} SLWebWatch;

// Record an HTTPS request. Returns the silent gap in seconds when the car comes
// back after a reported silence, otherwise -1.
static inline double sl_web_watch_secure(SLWebWatch *w, double now) {
    double gap = (w->silent && w->lastSecure > 0) ? now - w->lastSecure : -1;
    w->https++;
    w->silent = 0;
    w->lastSecure = now;
    w->httpMark = w->http; w->tlsMark = w->tlsFailures;
    w->busyMark = w->busy; w->wrongHostMark = w->wrongHost;
    return gap;
}

// Periodic check. Returns 1 once per silence when the car has made no HTTPS
// request for at least threshold seconds after having made at least one.
static inline int sl_web_watch_tick(SLWebWatch *w, double now, double threshold) {
    if (w->lastSecure <= 0 || w->silent || now - w->lastSecure < threshold) return 0;
    w->silent = 1;
    return 1;
}

// Allows one log line per interval for repeating failures.
static inline int sl_web_watch_allow(double *last, double now, double interval) {
    if (*last > 0 && now - *last < interval) return 0;
    *last = now;
    return 1;
}
#endif
