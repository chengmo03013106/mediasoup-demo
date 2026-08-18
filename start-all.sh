#!/usr/bin/env bash
# ============================================================================
#  mediasoup-demo one-click startup script (macOS)
#
#  What it does:
#    1. Check Node.js
#    2. Install server/app dependencies if missing (skip if present)
#    3. Generate config.mjs from config.example.mjs if missing
#    4. Generate self-signed TLS certificate if missing (via openssl)
#    5. Start mediasoup SFU server (port 4443 signaling / 44444 media)
#    6. Wait until server port 4443 is ready
#    7. Start frontend Vite service (port 5555, HTTPS), which auto-opens
#       two pages: producer (publish) and consumer (subscribe only)
#
#  Usage:   ./start-all.sh
#  Stop:    ./stop-all.sh
# ============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$ROOT/server"
APP_DIR="$ROOT/app"
# Use a fresh user-owned cache dir as a workaround if ~/.npm has root-owned
# files (a common issue after `sudo npm install`). Override with NPM_CACHE.
NPM_CACHE="${NPM_CACHE:-$HOME/.npm-cache}"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

echo "============================================================"
echo "  mediasoup-demo one-click startup (macOS)"
echo "============================================================"
log "Project root: $ROOT"
echo

# ---------------------------------------------------------------------------
# 1. Check Node.js
# ---------------------------------------------------------------------------
if ! command -v node >/dev/null 2>&1; then
	echo "[ERROR] Node.js not found. Install Node.js >= 22: https://nodejs.org/"
	exit 1
fi
log "[OK] Node.js installed: $(node --version)"

# ---------------------------------------------------------------------------
# 2. Install server dependencies (skip if already present)
# ---------------------------------------------------------------------------
if [ ! -d "$SERVER_DIR/node_modules" ]; then
	log "[INFO] server dependencies not found, installing..."
	(cd "$SERVER_DIR" && npm ci --cache "$NPM_CACHE")
	log "[OK] server dependencies installed"
else
	log "[OK] server dependencies already present, skip"
fi

# Ensure TypeScript is compiled to lib/ (npm ci normally does this via prepare)
if [ ! -d "$SERVER_DIR/lib" ]; then
	log "[INFO] server lib/ missing, building TypeScript..."
	(cd "$SERVER_DIR" && npm run typescript:build)
	log "[OK] server TypeScript built"
fi

# ---------------------------------------------------------------------------
# 3. Install app dependencies (skip if already present)
# ---------------------------------------------------------------------------
if [ ! -d "$APP_DIR/node_modules" ]; then
	log "[INFO] app dependencies not found, installing..."
	(cd "$APP_DIR" && npm ci --legacy-peer-deps --cache "$NPM_CACHE")
	log "[OK] app dependencies installed"
else
	log "[OK] app dependencies already present, skip"
fi

# ---------------------------------------------------------------------------
# 4. Generate config.mjs from config.example.mjs if missing
# ---------------------------------------------------------------------------
if [ ! -f "$SERVER_DIR/config.mjs" ]; then
	log "[INFO] config.mjs not found, generating from config.example.mjs..."
	cp "$SERVER_DIR/config.example.mjs" "$SERVER_DIR/config.mjs"
	perl -pi -e "s/import \* as os from 'node:os';/import * as os from 'node:os';\\nimport * as path from 'node:path';/" "$SERVER_DIR/config.mjs"
	perl -pi -e "s/'ABSOLUTE_PATH_TO_YOUR_TLS_CERTIFICATE_FULLCHAIN'/path.join(import.meta.dirname, 'cert.pem')/" "$SERVER_DIR/config.mjs"
	perl -pi -e "s/'ABSOLUTE_PATH_TO_YOUR_TLS_CERTIFICATE_PRIVATE_KEY'/path.join(import.meta.dirname, 'key.pem')/" "$SERVER_DIR/config.mjs"
	log "[OK] config.mjs generated"
else
	log "[OK] config.mjs already present, skip"
fi

# ---------------------------------------------------------------------------
# 5. Generate self-signed TLS certificate if missing
# ---------------------------------------------------------------------------
if [ ! -f "$SERVER_DIR/cert.pem" ] || [ ! -f "$SERVER_DIR/key.pem" ]; then
	log "[INFO] TLS certificate not found, generating self-signed certificate..."
	(cd "$SERVER_DIR" && openssl req -x509 -newkey rsa:2048 \
		-keyout key.pem -out cert.pem -days 365 -nodes \
		-subj "/CN=localhost" \
		-addext "subjectAltName=DNS:localhost,IP:127.0.0.1")
	log "[OK] TLS certificate generated"
else
	log "[OK] TLS certificate already present, skip"
fi

echo
echo "============================================================"
echo "  Starting services"
echo "============================================================"

# ---------------------------------------------------------------------------
# 6. Start SFU server (background), wait for port 4443
# ---------------------------------------------------------------------------
if lsof -i :4443 >/dev/null 2>&1; then
	log "[WARN] port 4443 already in use, skip server start"
else
	log "[INFO] Starting mediasoup SFU server..."
	(
		cd "$SERVER_DIR"
		DEBUG="mediasoup-demo-server*" nohup node lib/index.js >>"$ROOT/server.log" 2>&1 &
	)
	for i in $(seq 1 30); do
		if lsof -i :4443 >/dev/null 2>&1; then
			log "[OK] server started (port 4443)"
			break
		fi
		if [ "$i" -eq 30 ]; then
			echo "[ERROR] server startup timeout (30s). Check server.log"
			exit 1
		fi
		sleep 1
	done
fi

# ---------------------------------------------------------------------------
# 7. Start frontend (foreground), auto-opens producer + consumer pages
# ---------------------------------------------------------------------------
log "[INFO] Starting frontend Vite service (port 5555)..."
log "[INFO] Press Ctrl+C to stop the frontend, then run ./stop-all.sh to stop the server"

echo
echo "============================================================"
echo "  Startup complete"
echo "============================================================"
echo "  Server (SFU):    https://localhost:4443  (WSS signaling)"
echo "  Frontend page:   https://localhost:5555"
echo
echo "  The frontend auto-opens two browser pages:"
echo "    - producer: capture camera/mic and publish"
echo "    - consumer: subscribe and play only (single camera/mic test)"
echo
echo "  On first visit, the browser will warn about the self-signed"
echo "  certificate. Click Advanced -> Proceed, and allow camera and"
echo "  microphone permissions."
echo
echo "  To stop services, run ./stop-all.sh"
echo "============================================================"

(cd "$APP_DIR" && npm start)
