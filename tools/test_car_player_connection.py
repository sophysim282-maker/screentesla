"""Run the widget's actual request against a loopback fixture on the cloud Mac."""
import http.server
import json
import subprocess
import threading


class Handler(http.server.BaseHTTPRequestHandler):
    actions = []
    redirected = False

    def do_GET(self):
        type(self).redirected = True
        self.send_error(404)

    def do_POST(self):
        assert self.path == "/local/viewer/playback"
        assert self.headers["X-ScreenLink-Control"] == "app"
        assert self.headers["Host"] == "127.0.0.1:8080"
        assert self.headers["Content-Type"] == "application/json"
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        action = body["action"]
        type(self).actions.append(action)
        if action == "volumeUp":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'{"accepted":true}')
        elif action == "playPause":
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b'{"accepted":false}')
        else:
            self.send_response(302)
            self.send_header("Location", "http://127.0.0.1:8080/redirect")
            self.end_headers()


with http.server.HTTPServer(("127.0.0.1", 8080), Handler) as server:
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        subprocess.run(["build/test-car-player-connection"], check=True, timeout=15)
        assert Handler.actions == ["volumeUp", "playPause", "auto"]
        assert not Handler.redirected
    finally:
        server.shutdown()
        thread.join()
print("WIDGET_LOOPBACK_PASSED: accepted command, inactive-session rejection, no redirects")
