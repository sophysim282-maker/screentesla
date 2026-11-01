#ifndef SCREENLINK_MJPEG_H
#define SCREENLINK_MJPEG_H
#include <sys/socket.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

static inline int sl_mjpeg_send(int fd,const void *bytes,size_t length) {
    const char *cursor=bytes;
    while(length) {
        int flags=0;
#ifdef MSG_NOSIGNAL
        flags=MSG_NOSIGNAL;
#endif
        ssize_t sent=send(fd,cursor,length,flags);
        if(sent<0 && errno==EINTR)continue;
        if(sent<=0)return 0;
        cursor+=sent;length-=(size_t)sent;
    }
    return 1;
}
static inline int sl_mjpeg_begin(int fd) {
    const char *header="HTTP/1.1 200 OK\r\nContent-Type: multipart/x-mixed-replace; boundary=screenlink\r\nCache-Control: no-store, no-cache\r\nPragma: no-cache\r\nConnection: close\r\nX-Content-Type-Options: nosniff\r\n\r\n--screenlink\r\n";
    return sl_mjpeg_send(fd,header,strlen(header));
}
static inline int sl_mjpeg_frame(int fd,const void *bytes,size_t length,uint64_t sequence) {
    if(!bytes || !length)return 0;
    char header[160];
    int size=snprintf(header,sizeof header,"Content-Type: image/jpeg\r\nContent-Length: %zu\r\nX-Frame-ID: %llu\r\n\r\n",length,(unsigned long long)sequence);
    if(size<=0 || (size_t)size>=sizeof header)return 0;
    const char *boundary="\r\n--screenlink\r\n";
    return sl_mjpeg_send(fd,header,(size_t)size) && sl_mjpeg_send(fd,bytes,length) && sl_mjpeg_send(fd,boundary,strlen(boundary));
}
#endif
