#ifndef SL_LOCAL_VIEWER_HEADER_H
#define SL_LOCAL_VIEWER_HEADER_H
#include <string.h>
#include <strings.h>
/* HTTP names are case-insensitive; the request marker is an exact value.
   Derive the offset from the complete name INCLUDING ':' instead of a magic index. */
static inline int sl_local_viewer_request_header(const char *field) {
    static const char prefix[]="x-screenlink-viewer:";
    if(!field || strncasecmp(field,prefix,sizeof(prefix)-1)!=0)return 0;
    const char *value=field+sizeof(prefix)-1;
    while(*value==' ' || *value=='\t')value++;
    if(strncmp(value,"request",7)!=0)return 0;
    value+=7;while(*value==' ' || *value=='\t')value++;
    return *value=='\0';
}
#endif
