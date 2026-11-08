# ScreenLink build 77 — local name lookup for the car website

Car test (build 75): https://car.tesla4khmer.com/capabilities?check=1 → "server IP address could not
be found", while https://240.3.3.3/ still worked. The phone log had no HTTPS lines at all: the car never
reached the phone because the internet DNS lookup for car.tesla4khmer.com failed.

Build 77: in the 240.3.3.3 VPN mode, the ScreenLink VPN adds split DNS for car.tesla4khmer.com only
(server 10.7.0.53, inside the VPN) and answers it itself: A → 240.3.3.3, AAAA → none, other names
REFUSED. Other lookups and internet traffic are unchanged. Developer → Route probe status shows
`localDNSAnswers`.

Tested: `tools/test_local_dns.c` and replies decoded with the dnslib library. Not verified on iPhone:
whether iOS sends hotspot clients' lookups through the VPN's split DNS. If it does not,
localDNSAnswers stays 0 and the internet lookup is used as before.
Includes build 76 read-ahead and the website certificate packaging.
