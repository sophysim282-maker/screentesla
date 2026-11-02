#include "http_request.h"
#include "http_response.h"
#include <assert.h>
#include <stdio.h>
static void check(int explicit_length,int expected_complete){
    http_response_t *response=http_response_init("HTTP/1.1",200,"OK");
    if(explicit_length)http_response_add_header(response,"Content-Length","0");
    http_response_finish(response,NULL,0);int length=0;const char *wire=http_response_get_data(response,&length);
    http_request_t *parser=http_request_init();
    // A client must be able to finish this response while the socket stays open.
    http_request_add_data(parser,wire,length/2);assert(!http_request_has_error(parser));assert(!http_request_is_complete(parser));
    http_request_add_data(parser,wire+length/2,length-length/2);assert(!http_request_has_error(parser));assert(http_request_is_complete(parser)==expected_complete);
    http_request_destroy(parser);http_response_destroy(response);
}
int main(void){check(0,0);check(1,1);puts("HTTP framing regression reproduced: missing length waits for EOF; Content-Length: 0 completes on a live connection.");return 0;}
