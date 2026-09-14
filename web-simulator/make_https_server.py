import os
import ssl
import datetime
from http.server import HTTPServer, SimpleHTTPRequestHandler
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
import ipaddress

CERT_FILE = "cert.pem"
KEY_FILE = "key.pem"
PORT = 8443

def generate_self_signed_cert():
    if os.path.exists(CERT_FILE) and os.path.exists(KEY_FILE):
        print(f"[SSL Engine] Certificate files '{CERT_FILE}' and '{KEY_FILE}' already exist.")
        return

    print("[SSL Engine] Generating 2048-bit RSA Self-Signed Certificate for HTTPS Secure Connection...")
    key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
    )

    subject = issuer = x509.Name([
        x509.NameAttribute(NameOID.COMMON_NAME, u"192.168.1.193"),
        x509.NameAttribute(NameOID.ORGANIZATION_NAME, u"AcousticAware DEAF AI System"),
    ])

    alt_names = [
        x509.DNSName(u"localhost"),
        x509.IPAddress(ipaddress.ip_address("127.0.0.1")),
        x509.IPAddress(ipaddress.ip_address("192.168.1.193")),
    ]

    cert = x509.CertificateBuilder().subject_name(
        subject
    ).issuer_name(
        issuer
    ).public_key(
        key.public_key()
    ).serial_number(
        x509.random_serial_number()
    ).not_valid_before(
        datetime.datetime.now(datetime.timezone.utc)
    ).not_valid_after(
        datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=365)
    ).add_extension(
        x509.SubjectAlternativeName(alt_names),
        critical=False,
    ).sign(key, hashes.SHA256())

    with open(KEY_FILE, "wb") as f:
        f.write(key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.TraditionalOpenSSL,
            encryption_algorithm=serialization.NoEncryption()
        ))

    with open(CERT_FILE, "wb") as f:
        f.write(cert.public_bytes(serialization.Encoding.PEM))

    print(f"[SSL Engine] Generated {CERT_FILE} and {KEY_FILE} successfully!")

def run_https_server():
    generate_self_signed_cert()
    server_address = ("0.0.0.0", PORT)
    httpd = HTTPServer(server_address, SimpleHTTPRequestHandler)

    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(certfile=CERT_FILE, keyfile=KEY_FILE)
    httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

    print(f"[HTTPS SECURE SERVER ACTIVE AT]:")
    print(f"   HTTPS Mobile Link: https://192.168.1.193:{PORT}/")
    print(f"   HTTPS Local Link:  https://localhost:{PORT}/")
    httpd.serve_forever()

if __name__ == "__main__":
    run_https_server()
