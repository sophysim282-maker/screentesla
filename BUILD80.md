# ScreenLink build 80 — keep HTTPS connections open

Car log (build 78): playback stayed smooth through 7–8 s drops thanks to the 20 s buffer, but the
website kept going silent with `0 handshake failures · 0 connections open` (the car did not even try to
connect) while http://240.3.3.3:8080 kept working — the name lookup kept failing. The website opened a
new connection, name lookup and TLS handshake for every request (`Connection: close`).

Build 80: HTTPS replies use `Connection: keep-alive` (10 s idle, up to 500 requests per connection);
the browser reuses open connections without new name lookups or handshakes. HTTP 240.3.3.3 is
unchanged. Test: `tools/test_keep_alive_tls.c` (3 requests over one TLS connection; idle close).
Includes builds 76–79.
