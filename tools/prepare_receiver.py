#!/usr/bin/env python3
"""Fetch a pinned receiver core; retain upstream license and surface DNS errors."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parent.parent
vendor = root / 'Vendor' / 'RPiPlay'
revision = '64d0341ed3bef098c940c9ed0675948870a271f9'
if not (vendor / '.git').is_dir():
    vendor.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['git', 'clone', '--no-checkout', 'https://github.com/FD-/RPiPlay.git', str(vendor)], check=True)
subprocess.run(['git', '-C', str(vendor), 'checkout', '--detach', revision], check=True)
p = vendor / 'lib' / 'dnssd.c'
s = p.read_text()
if 'DNSServiceErrorType registration_error =' not in s:
    s = s.replace('    dnssd->DNSServiceRegister(&dnssd->', '    DNSServiceErrorType registration_error = dnssd->DNSServiceRegister(&dnssd->')
    s = s.replace('    return 1;', '    return registration_error == 0 ? 1 : -3;')
    p.write_text(s)

# Method-only diagnostics for native handshakes rejected before route dispatch.
p = vendor / 'lib' / 'httpd.c'
s = p.read_text()
if 'sl_method_prefix' not in s:
    s = s.replace('    http_request_t *request;', '    http_request_t *request;\n    char sl_method_prefix[25];\n    unsigned int sl_method_length;\n    int sl_method_done;', 1)
    marker = '                connection->request = http_request_init();'
    assert marker in s
    s = s.replace(marker, marker+'\n                connection->sl_method_length=0; connection->sl_method_done=0; connection->sl_method_prefix[0]=0;', 1)
    marker = '            /* Parse HTTP request from data read from connection */'
    assert marker in s
    s = s.replace(marker, r'''            /* Save only the method token; never a URL, header or body. */
            if (ret < 0) { httpd_remove_connection(httpd, connection); continue; }
            for (int j=0; j<ret && !connection->sl_method_done; j++) {
                unsigned char c=(unsigned char)buffer[j];
                if (c==' ' || c=='\r' || c=='\n' || connection->sl_method_length>=24) {
                    connection->sl_method_done=1;
                } else if ((c>='A' && c<='Z') || c=='_') {
                    connection->sl_method_prefix[connection->sl_method_length++]=(char)c;
                    connection->sl_method_prefix[connection->sl_method_length]=0;
                } else {
                    if (!connection->sl_method_length) snprintf(connection->sl_method_prefix, sizeof(connection->sl_method_prefix), "non-text byte 0x%02X", c);
                    connection->sl_method_done=1;
                }
            }
''' + marker, 1)
    marker = 'logger_log(httpd->logger, LOGGER_ERR, "httpd error in parsing: %s", http_request_get_error_name(connection->request));'
    assert marker in s
    s = s.replace(marker, 'logger_log(httpd->logger, LOGGER_ERR, "httpd parse rejected method [%s]: %s (%s)", connection->sl_method_prefix, http_request_get_error_name(connection->request), http_request_get_error_description(connection->request));', 1)
    p.write_text(s)
print('Receiver core prepared at pinned revision', revision)

# Darwin uses IPPROTO_TCP and TCP_KEEPALIVE for these Linux socket options.
p = vendor / 'lib' / 'raop_rtp_mirror.c'
s = p.read_text()
marker = '#include <netinet/tcp.h>'
patch = """#include <netinet/tcp.h>
#include <netinet/in.h>
#if defined(__APPLE__)
#ifndef SOL_TCP
#define SOL_TCP IPPROTO_TCP
#endif
#ifndef TCP_KEEPIDLE
#define TCP_KEEPIDLE TCP_KEEPALIVE
#endif
#endif"""
if '#define TCP_KEEPIDLE TCP_KEEPALIVE' not in s:
    assert marker in s
    p.write_text(s.replace(marker, patch, 1))

# External discovery keeps protocol metadata available while a Mac advertises the
# VPN peer. No phone-side duplicate services are published in this mode.
p = vendor / 'lib' / 'dnssd.c'
s = p.read_text()
if 'sl_dnssd_set_external' not in s:
    s = s.replace('struct dnssd_s {', 'struct dnssd_s {\n    int sl_external, sl_raop_ready, sl_airplay_ready;', 1)
    for record in ('raop', 'airplay'):
        marker = f'    dnssd->TXTRecordCreate(&dnssd->{record}_record, 0, NULL);'
        assert marker in s
        s = s.replace(marker, marker + f'\n    dnssd->sl_{record}_ready = 1;', 1)
    marker = '    /* Register the service */'
    assert s.count(marker) == 2
    s = s.replace(marker, '    if (dnssd->sl_external) return 1;\n\n' + marker)
    marker = '    if (dnssd) {\n#ifdef WIN32'
    assert marker in s
    s = s.replace(marker, '''    if (dnssd) {
        if (dnssd->sl_external) {
            if (dnssd->sl_raop_ready) dnssd->TXTRecordDeallocate(&dnssd->raop_record);
            if (dnssd->sl_airplay_ready) dnssd->TXTRecordDeallocate(&dnssd->airplay_record);
            free(dnssd->name);
            free(dnssd->hw_addr);
        }
#ifdef WIN32''', 1)
    s += '''
void sl_dnssd_set_external(dnssd_t *dnssd, int enabled) { dnssd->sl_external = enabled; }
const char *sl_dnssd_get_raop_txt(dnssd_t *dnssd, int *length) {
    *length = dnssd->TXTRecordGetLength(&dnssd->raop_record);
    return dnssd->TXTRecordGetBytesPtr(&dnssd->raop_record);
}
'''
    p.write_text(s)

# AirPlay HTTP media shares the same paired listener as mirroring. Delegate
# media requests before the RTSP CSeq gate; retain all original mirror handlers.
p = vendor / 'lib' / 'httpd.h'
s = p.read_text()
if 'sl_httpd_connection_socket' not in s:
    s += '\nint sl_httpd_connection_socket(httpd_t *httpd, void *user_data);\n'
    p.write_text(s)
p = vendor / 'lib' / 'httpd.c'
s = p.read_text()
if 'sl_httpd_connection_socket' not in s:
    s += '''
int sl_httpd_connection_socket(httpd_t *httpd, void *user_data) {
    for (int i=0;i<httpd->max_connections;i++)
        if (httpd->connections[i].connected && httpd->connections[i].user_data==user_data)
            return httpd->connections[i].socket_fd;
    return -1;
}
'''
    p.write_text(s)
p = vendor / 'lib' / 'http_request.c'
s = p.read_text()
s = s.replace('llhttp_init(&request->parser, HTTP_REQUEST,', 'llhttp_init(&request->parser, HTTP_BOTH,')
s = s.replace('request->method = llhttp_method_name(request->parser.method);', 'request->method = request->parser.type == HTTP_RESPONSE ? "RESPONSE" : llhttp_method_name(request->parser.method);')
s = s.replace('return (llhttp_get_errno(&request->parser) != HPE_OK);', 'return (llhttp_get_errno(&request->parser) != HPE_OK && !(request->complete && llhttp_get_errno(&request->parser) == HPE_PAUSED_UPGRADE));')
p.write_text(s)
p = vendor / 'lib' / 'raop.c'
s = p.read_text()
if 'sl_media_handle' not in s:
    marker = 'static void\nconn_request('
    assert marker in s
    s = s.replace(marker, '''extern int sl_media_handle(void *, void *, int, http_request_t *, http_response_t **);
extern void sl_media_closed(void *, void *);

''' + marker, 1)
    marker = '    if (!method || !cseq) {'
    assert marker in s
    s = s.replace(marker, '''    if (sl_media_handle(conn->raop->callbacks.cls, ptr,
                        sl_httpd_connection_socket(conn->raop->httpd, ptr), request, response)) return;
    if (!method) {''', 1)
    s = s.replace('http_response_init("RTSP/1.0", 200, "OK")', 'http_response_init(cseq ? "RTSP/1.0" : "HTTP/1.1", 200, "OK")', 1)
    s = s.replace('    http_response_add_header(*response, "CSeq", cseq);', '    if (cseq) http_response_add_header(*response, "CSeq", cseq);', 1)
    marker = '    logger_log(conn->raop->logger, LOGGER_INFO, "Destroying connection");'
    assert marker in s
    s = s.replace(marker, marker+'\n    sl_media_closed(conn->raop->callbacks.cls, ptr);', 1)
    p.write_text(s)
# Enable video, HLS and video-volume flags, without advertising protected media.
p = vendor / 'lib' / 'dnssdint.h'
s = p.read_text().replace('"0x5A7FFEE6"', '"0x5A7FFEFB"')
p.write_text(s)

# Pair/control HTTP requests can also complete with an empty 200 response.
# Keep original RTSP framing while making HTTP/1.1 completion unambiguous.
p = vendor / 'lib' / 'raop.c'
s = p.read_text()
marker = '    http_response_finish(*response, response_data, response_datalen);'
if 'if (!cseq && response_datalen == 0)' not in s:
    assert marker in s
    s = s.replace(marker, '    if (!cseq && response_datalen == 0) http_response_add_header(*response, "Content-Length", "0");\n' + marker, 1)
    p.write_text(s)
