#include "../RTC/SLStun.h"
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <unistd.h>
static volatile sig_atomic_t stopped;
static void stop(int n){(void)n;stopped=1;}
int main(int argc,char **argv){if(argc!=3)return 2;SLStunServer *s=SLStunStart(argv[1],(uint16_t)atoi(argv[2]));if(!s)return 1;signal(SIGTERM,stop);signal(SIGINT,stop);printf("%u\n",SLStunSnapshot(s).boundPort);fflush(stdout);while(!stopped)sleep(1);SLStunStats stats=SLStunSnapshot(s);SLStunStop(s);fprintf(stderr,"Local STUN: %llu requests, %llu responses\n",(unsigned long long)stats.requests,(unsigned long long)stats.responses);return 0;}
