#include "../App/MJPEG.h"
#include <assert.h>
#include <unistd.h>

int main(void) {
    int pair[2];assert(socketpair(AF_UNIX,SOCK_STREAM,0,pair)==0);
#ifdef SO_NOSIGPIPE
    int one=1;setsockopt(pair[0],SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof one);
#endif
    const unsigned char jpeg[]={0xff,0xd8,0,1,0xff,0xd9};
    assert(sl_mjpeg_begin(pair[0]));
    assert(sl_mjpeg_frame(pair[0],jpeg,sizeof jpeg,41));
    assert(sl_mjpeg_frame(pair[0],jpeg,sizeof jpeg,44)); // Sequence gaps are legal.
    shutdown(pair[0],SHUT_WR);
    char response[4096];size_t total=0;ssize_t count;
    while((count=read(pair[1],response+total,sizeof response-1-total))>0)total+=(size_t)count;
    response[total]=0;
    const char *first=strstr(response,"X-Frame-ID: 41\r\n\r\n");assert(first);
    first+=strlen("X-Frame-ID: 41\r\n\r\n");
    assert(memcmp(first,jpeg,sizeof jpeg)==0);
    const char *next=first+sizeof jpeg;
    assert(memcmp(next,"\r\n--screenlink\r\nContent-Type: image/jpeg\r\nContent-Length: 6\r\nX-Frame-ID: 44\r\n\r\n",strlen("\r\n--screenlink\r\nContent-Type: image/jpeg\r\nContent-Length: 6\r\nX-Frame-ID: 44\r\n\r\n"))==0);
    close(pair[1]);assert(!sl_mjpeg_frame(pair[0],jpeg,sizeof jpeg,45));close(pair[0]);
    puts("MJPEG framing passed: binary JPEGs, length-delimited parts, skipped IDs and disconnected client.");
    return 0;
}
