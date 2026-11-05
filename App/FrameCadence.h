#ifndef SCREENLINK_FRAME_CADENCE_H
#define SCREENLINK_FRAME_CADENCE_H

// Preserve cadence phase across irregular source arrivals. Scheduling from each
// accepted arrival loses a whole source-frame interval whenever the periods do
// not divide evenly (for example, a 30 fps source capped at 20 fps).
static inline int sl_frame_due(double now, double fps, double *deadline) {
    if(fps<=0 || now<*deadline)return 0;
    double interval=1.0/fps;
    if(*deadline>0 && (now-*deadline)>interval*2.0){
        *deadline=now+interval;
    }else{
        *deadline=(*deadline>0 && now-*deadline<interval)?*deadline+interval:now+interval;
    }
    return 1;
}

#endif
