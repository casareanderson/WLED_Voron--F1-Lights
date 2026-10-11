#!/usr/bin/env python3
"""Stand-in WLED for the setup check: records every POST to /json/state and
returns the last one from GET /_last. CI has no printer and no LED strip.

    python3 scripts/fake_wled.py 18090
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

LAST = {}


class H(BaseHTTPRequestHandler):
    def _send(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/_last":
            return self._send(LAST)
        self.send_error(404)

    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        LAST.clear()
        LAST.update(path=self.path, ctype=self.headers.get("Content-Type"), body=json.loads(raw))
        return self._send({"success": True})

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
