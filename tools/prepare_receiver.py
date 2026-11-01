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
