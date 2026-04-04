#!/bin/bash
#
# Generate CA and server certificates for Python-EST development/testing.
#
# Usage:
#   bash scripts/generate_certs.sh
#
# This creates:
#   certs/ca-cert.pem    - CA certificate
#   certs/ca-key.pem     - CA private key
#   certs/server.crt     - Server certificate (signed by CA)
#   certs/server.key     - Server private key
#

set -e

CERT_DIR="certs"
DAYS_CA=3650
DAYS_SERVER=365
KEY_SIZE=2048

echo "=== Python-EST Certificate Generator ==="
echo ""

# Create certificate directory
mkdir -p "$CERT_DIR"

# ── 1. Generate CA ──────────────────────────────────────────────

if [ -f "$CERT_DIR/ca-cert.pem" ] && [ -f "$CERT_DIR/ca-key.pem" ]; then
    echo "[*] CA certificate already exists, skipping..."
else
    echo "[+] Generating CA certificate..."
    openssl req -x509 -newkey rsa:$KEY_SIZE -nodes \
        -keyout "$CERT_DIR/ca-key.pem" \
        -out "$CERT_DIR/ca-cert.pem" \
        -days $DAYS_CA \
        -subj "/C=US/ST=Development/L=EST/O=Python-EST CA/CN=Python-EST Root CA"

    echo "    CA certificate:  $CERT_DIR/ca-cert.pem"
    echo "    CA private key:  $CERT_DIR/ca-key.pem"
fi

# ── 2. Generate Server Certificate ─────────────────────────────

if [ -f "$CERT_DIR/server.crt" ] && [ -f "$CERT_DIR/server.key" ]; then
    echo "[*] Server certificate already exists, skipping..."
else
    echo "[+] Generating server certificate..."

    # Generate server key and CSR
    openssl req -newkey rsa:$KEY_SIZE -nodes \
        -keyout "$CERT_DIR/server.key" \
        -out "$CERT_DIR/server.csr" \
        -subj "/C=US/ST=Development/L=EST/O=Python-EST/CN=localhost"

    # Create extensions file for SAN
    cat > "$CERT_DIR/server_ext.cnf" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=@alt_names

[alt_names]
DNS.1=localhost
DNS.2=python-est-server
IP.1=127.0.0.1
EOF

    # Sign server certificate with CA
    openssl x509 -req \
        -in "$CERT_DIR/server.csr" \
        -CA "$CERT_DIR/ca-cert.pem" \
        -CAkey "$CERT_DIR/ca-key.pem" \
        -CAcreateserial \
        -out "$CERT_DIR/server.crt" \
        -days $DAYS_SERVER \
        -extfile "$CERT_DIR/server_ext.cnf"

    # Clean up temp files
    rm -f "$CERT_DIR/server.csr" "$CERT_DIR/server_ext.cnf" "$CERT_DIR/ca-cert.srl"

    echo "    Server certificate: $CERT_DIR/server.crt"
    echo "    Server private key: $CERT_DIR/server.key"
fi

echo ""
echo "=== Done ==="
echo ""
echo "Certificates are in ./$CERT_DIR/"
echo ""
echo "Next steps:"
echo "  docker-compose -f docker-compose-nginx.yml up -d --build"
echo "  # or"
echo "  python-est start --config config-nginx.yaml"
