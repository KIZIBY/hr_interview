#!/usr/bin/env python3
"""Локальный сервер платформы интервью — python3 scripts/serve.py [порт].

Обёртка над http.server с запретом кеширования (Cache-Control: no-store):
браузер всегда получает свежие страницы, «у меня старая версия» исключено.
Запускать из корня репозитория; по умолчанию порт 8000.
"""
import http.server
import os
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, must-revalidate")
        self.send_header("Expires", "0")
        super().end_headers()


if __name__ == "__main__":
    with http.server.ThreadingHTTPServer(("", PORT), NoCacheHandler) as httpd:
        print(f"Платформа интервью: http://localhost:{PORT} (корень: {ROOT})")
        print("Остановить: Ctrl+C")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
