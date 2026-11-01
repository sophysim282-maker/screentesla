#!/usr/bin/env python3
"""Announce the phone's AirPlay receiver at a LocalDevVPN peer; no video relay."""
import argparse
import ipaddress
import json
import shutil
import signal
import subprocess
import sys
import time
import urllib.parse
import urllib.request


def load_profile(viewer_url):
    url = urllib.parse.urlsplit(viewer_url)
    if url.scheme != 'http' or not url.hostname:
        raise ValueError('Paste the complete http:// viewer link from ScreenLink.')
    token = urllib.parse.parse_qs(url.query).get('token', [None])[0]
    if not token:
        raise ValueError('The viewer link must include its ?token= value.')
    endpoint = urllib.parse.urlunsplit((url.scheme, url.netloc, '/discovery.json', urllib.parse.urlencode({'token': token}), ''))
    # This is a local phone endpoint; do not send the bearer token to a web proxy.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(endpoint, timeout=4) as response:
        profile = json.loads(response.read(16384))
    if not profile.get('externalDiscovery'):
        raise ValueError('Turn ON Mac VPN discovery in ScreenLink, stop/start the receiver, and copy its new viewer link.')
    for key in ('airplayTXT', 'raopTXT'):
        values = profile.get(key)
        if not isinstance(values, list) or not values or any(not isinstance(v, str) or len(v.encode()) > 255 or '\x00' in v for v in values):
            raise ValueError('Invalid receiver discovery metadata.')
    port = profile.get('port')
    if type(port) is not int or not 1 <= port <= 65535:
        raise ValueError('Invalid AirPlay port.')
    return profile


def commands(profile, peer, dns_sd):
    result = []
    for name, service, records in ((profile['name'], '_airplay._tcp', profile['airplayTXT']),
                                    (profile['raopName'], '_raop._tcp', profile['raopTXT'])):
        result.append([dns_sd, '-P', name, service, 'local.', str(profile['port']), profile['host'], peer, *records])
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('viewer_url', nargs='?', help='Complete hotspot viewer link, including token')
    parser.add_argument('--peer', default='10.7.0.1', help='LocalDevVPN peer address (not the interface address)')
    args = parser.parse_args()
    if not args.viewer_url:
        args.viewer_url = input('Paste the complete ScreenLink hotspot viewer link: ').strip()
    try:
        peer = str(ipaddress.IPv4Address(args.peer))
        dns_sd = shutil.which('dns-sd')
        if not dns_sd:
            raise ValueError('Run this helper on your Mac; dns-sd is required.')
        profile = load_profile(args.viewer_url)
    except Exception as error:
        print('Cannot start discovery:', error, file=sys.stderr)
        return 1
    children = []
    def finish(signum=None, frame=None):
        for child in children:
            if child.poll() is None:
                child.terminate()
    signal.signal(signal.SIGINT, finish)
    signal.signal(signal.SIGTERM, finish)
    try:
        for command in commands(profile, peer, dns_sd):
            children.append(subprocess.Popen(command))
        print('\nKeep this window open. On iPhone select:', profile['name'], flush=True)
        print('Video viewer:', args.viewer_url.split('?')[0], '(use your complete link in the browser)', flush=True)
        print('Press Control-C to remove both advertisements.', flush=True)
        while all(child.poll() is None for child in children):
            time.sleep(0.25)
    finally:
        finish()
        for child in children:
            child.wait(timeout=5)
    return 0


if __name__ == '__main__':
    sys.exit(main())
