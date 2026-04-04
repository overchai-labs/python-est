# Python-EST

A production-ready Python implementation of the **EST (Enrollment over Secure Transport)** protocol per [RFC 7030](https://datatracker.ietf.org/doc/html/rfc7030).

Built with FastAPI, designed for IoT and enterprise device certificate provisioning.

## Features

- **RFC 7030 compliant** EST protocol endpoints (`/cacerts`, `/simpleenroll`, `/simplereenroll`, `/bootstrap`)
- **Dual authentication** SRP (password-based) + client certificate (RA/gateway) authentication
- **Built-in Certificate Authority** signs CSRs and returns PKCS#7 responses
- **Nginx TLS termination** with client certificate extraction via headers
- **Device tracking dashboard** real-time web UI showing enrolled devices and stats
- **Docker-ready** single command deployment with docker-compose
- **Async architecture** FastAPI + uvicorn for high throughput
- **CLI management** `python-est init`, `python-est start`, `python-est user add`

## Quick Start

### 1. Clone and generate certificates

```bash
git clone https://github.com/your-username/python-est.git
cd python-est

# Generate CA and server certificates for development
bash scripts/generate_certs.sh
```

### 2a. Run with Docker (recommended)

```bash
docker-compose -f docker-compose-nginx.yml up -d --build
```

The server will be available at `https://localhost:8445`.

### 2b. Run locally

```bash
pip install -e .
python-est init
python-est user add myuser
python-est start
```

### 3. Test it

```bash
# Fetch CA certificates (no auth required)
curl -k https://localhost:8445/.well-known/est/cacerts -o cacerts.p7

# Generate a CSR and enroll
openssl req -new -newkey rsa:2048 -nodes \
  -keyout device.key -out device.csr -outform DER \
  -subj "/CN=my-device-001/O=My Organization"

curl -k -u estuser:estpwd \
  -H "Content-Type: application/pkcs10" \
  --data-binary @device.csr \
  https://localhost:8445/.well-known/est/simpleenroll \
  -o device-cert.p7

# Verify the issued certificate
openssl pkcs7 -print_certs -inform DER -in device-cert.p7
```

## Architecture

```
                         ┌─────────────────────────────────┐
  Devices / Gateways ──► │  Nginx (TLS termination :8445)  │
                         │  - Client cert extraction       │
                         │  - Forwards via HTTP headers     │
                         └──────────────┬──────────────────┘
                                        │ HTTP :8000
                         ┌──────────────▼──────────────────┐
                         │  Python-EST Server (FastAPI)     │
                         │  - SRP / cert authentication     │
                         │  - CSR signing (built-in CA)     │
                         │  - PKCS#7 response formatting    │
                         │  - Device tracking + dashboard   │
                         └─────────────────────────────────┘
```

## EST Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET`  | `/.well-known/est/cacerts` | None | Download CA certificates (PKCS#7) |
| `POST` | `/.well-known/est/bootstrap` | HTTP Basic | Initial device bootstrap enrollment |
| `POST` | `/.well-known/est/simpleenroll` | Basic or Client Cert | Certificate enrollment with CSR |
| `POST` | `/.well-known/est/simplereenroll` | Basic or Client Cert | Certificate renewal |

Additional endpoints:
- `GET /` Dashboard with device stats
- `GET /health` Health check
- `GET /api/stats` Server statistics (JSON)
- `GET /api/devices` All tracked devices (JSON)
- `DELETE /api/devices/{id}` Remove a device

## Project Structure

```
python-est/
├── src/python_est/           # Core EST library
│   ├── server.py             # FastAPI server + EST endpoints
│   ├── ca.py                 # Certificate Authority (signing, PKCS#7)
│   ├── auth.py               # SRP authentication
│   ├── client.py             # EST client library
│   ├── config.py             # Pydantic configuration models
│   ├── device_tracker.py     # Device tracking + statistics
│   ├── models.py             # Data models
│   ├── cli.py                # CLI interface
│   ├── utils.py              # Utilities
│   └── exceptions.py         # Custom exceptions
├── docker/
│   ├── Dockerfile            # Server container image
│   └── entrypoint.sh         # Container startup
├── nginx/
│   └── nginx.conf            # TLS termination + cert forwarding
├── scripts/
│   └── generate_certs.sh     # Certificate generation helper
├── config-nginx.yaml         # Example config (nginx proxy mode)
├── docker-compose-nginx.yml  # Docker deployment
├── pyproject.toml            # Package metadata
└── requirements.txt          # Dependencies
```

## Configuration

Configuration is YAML-based. See [config-nginx.yaml](config-nginx.yaml) for a full example.

Key settings:

```yaml
server:
  host: 0.0.0.0
  port: 8000
  debug: true

ca:
  ca_cert: certs/ca-cert.pem
  ca_key: certs/ca-key.pem
  cert_validity_days: 365
  digest_algorithm: sha256

srp:
  enabled: true
  user_db: data/srp_users.db

# Response format: 'base64' (RFC 7030) or 'der' (raw binary)
response_format: base64
```

Default bootstrap credentials can be configured via environment variables:
- `EST_DEFAULT_USER` (default: `estuser`)
- `EST_DEFAULT_PASS` (default: `estpwd`)

## Client Library

Python-EST includes a client library for programmatic access:

```python
from python_est import ESTClient

client = ESTClient(
    server_url="https://localhost:8445",
    username="myuser",
    password="mypassword",
    verify_ssl=False  # dev only
)

# Get CA certificates
ca_certs = await client.get_ca_certificates()

# Generate CSR and enroll
csr_pem, key_pem = ESTClient.generate_csr("my-device-001")
cert_pkcs7 = await client.enroll_certificate(csr_pem)
```

## Development

```bash
# Install with dev dependencies
pip install -e ".[dev]"

# Run tests
pytest

# Format code
black src/
isort src/
```

## License

MIT - see [LICENSE](LICENSE).
