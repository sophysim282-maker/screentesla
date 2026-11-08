#ifndef SL_HTTPS_PROBE_H
#define SL_HTTPS_PROBE_H
#include <stdint.h>
#include <stddef.h>
#include <string.h>
typedef enum { SLHTTPSHealthy=0, SLHTTPSIdentity, SLHTTPSConnect, SLHTTPSTimeout, SLHTTPSHandshake, SLHTTPSResponse } SLHTTPSProbeResult;
SLHTTPSProbeResult sl_https_probe(const char *chain, uint16_t port, unsigned timeout_ms);
const char *sl_https_probe_name(SLHTTPSProbeResult result);
int sl_https_valid_challenge(const char *challenge);
int sl_https_valid_response(const char *bytes,size_t size,const char *challenge);
static inline int sl_https_health_allowed(int secure,int loopback,const char *method,size_t bodyLength,const char *path,const char *challenge){
 if(!secure||!loopback||bodyLength||!method||!path)return 0;
 /* Fixed route and method; local diagnostics never authenticate a viewer. */
 return method[0]=='G'&&method[1]=='E'&&method[2]=='T'&&method[3]==0&&
        strcmp(path,"/local/https-health")==0&&sl_https_valid_challenge(challenge);
}
typedef struct {unsigned failures;double lastRepair;} SLHTTPSHealthPolicy;
/* A successful external response outweighs a failed local probe. A repair is
 * permitted after two failures, with a 60-second cooldown, never on one hiccup. */
static inline int sl_https_should_repair(SLHTTPSHealthPolicy *policy,int healthy,double now,double lastExternalSuccess){
 if(healthy||(lastExternalSuccess>0&&now-lastExternalSuccess<20)){policy->failures=0;return 0;}
 if(policy->failures<2)policy->failures++;
 if(policy->failures<2||(policy->lastRepair>0&&now-policy->lastRepair<60))return 0;
 policy->lastRepair=now;policy->failures=0;return 1;
}
#endif
