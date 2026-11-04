#include "../App/LocalViewerHeader.h"
#include <assert.h>
#include <stdio.h>
int main(void){
    assert(sl_local_viewer_request_header("X-ScreenLink-Viewer: request"));
    assert(sl_local_viewer_request_header("x-screenlink-viewer:request"));
    assert(sl_local_viewer_request_header("X-SCREENLINK-VIEWER:\trequest \t"));
    assert(!sl_local_viewer_request_header("X-ScreenLink-Viewer: : request"));
    assert(!sl_local_viewer_request_header("X-ScreenLink-Viewer: request-extra"));
    assert(!sl_local_viewer_request_header("X-ScreenLink-Viewer: REQUEST"));
    assert(!sl_local_viewer_request_header("X-ScreenLink-Viewer: request\r\nInjected: yes"));
    assert(!sl_local_viewer_request_header("X-ScreenLink-Viewer: "));
    assert(!sl_local_viewer_request_header("X-ScreenLink-Viewer"));
    assert(!sl_local_viewer_request_header("Origin: request"));
    assert(!sl_local_viewer_request_header(""));
    assert(!sl_local_viewer_request_header(NULL));
    puts("Production local approval header parser passed: valid browser headers accepted; malformed, injected and wrong-value headers rejected.");
}
