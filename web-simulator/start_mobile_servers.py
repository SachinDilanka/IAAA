import http.server
import socketserver
import ssl
import threading
import os

DIRECTORY = os.path.dirname(os.path.abspath(__file__))
os.chdir(DIRECTORY)

class CORSHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()

def run_port_80():
    try:
        with socketserver.TCPServer(("", 80), CORSHTTPRequestHandler) as httpd:
            print("[Server Engine] HTTP Port 80 Active!")
            httpd.serve_forever()
    except Exception as e:
        print("[Port 80 Note]:", e)

def run_port_8000():
    try:
        with socketserver.TCPServer(("", 8000), CORSHTTPRequestHandler) as httpd:
            print("[Server Engine] HTTP Port 8000 Active!")
            httpd.serve_forever()
    except Exception as e:
        print("[Port 8000 Note]:", e)

def run_port_8443():
    try:
        CERT_FILE = "cert.pem"
        KEY_FILE = "key.pem"
        server_address = ("0.0.0.0", 8443)
        httpd = http.server.HTTPServer(server_address, CORSHTTPRequestHandler)
        if os.path.exists(CERT_FILE) and os.path.exists(KEY_FILE):
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(certfile=CERT_FILE, keyfile=KEY_FILE)
            httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
            print("[Server Engine] HTTPS Port 8443 Active!")
            httpd.serve_forever()
    except Exception as e:
        print("[Port 8443 Note]:", e)

if __name__ == "__main__":
    t1 = threading.Thread(target=run_port_80, daemon=True)
    t2 = threading.Thread(target=run_port_8000, daemon=True)
    t3 = threading.Thread(target=run_port_8443, daemon=True)

    t1.start()
    t2.start()
    t3.start()

    print("==================================================")
    print("[SERVER ACTIVE] ACOUSTIC AWARE MOBILE SERVER ONLINE!")
    print("   - Direct iPhone Link: http://172.20.10.6")
    print("   - Mobile Port 8000:   http://172.20.10.6:8000")
    print("   - HTTPS Secure Link:  https://172.20.10.6:8443")
    print("==================================================")

    t1.join()
    t2.join()
    t3.join()
