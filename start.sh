#!/usr/bin/env bash
set -euo pipefail

export HOME=/app
export PATH="/app/.local/bin:${PATH}"

# Railway injecte PORT=8080 dans ton cas.
# On respecte ce port.
export PORT="${PORT:-8080}"

export III_DATA_DIR="${III_DATA_DIR:-/data}"
export AGENTMEMORY_DATA_DIR="${AGENTMEMORY_DATA_DIR:-/data}"

mkdir -p /data
mkdir -p /app

DIST_DIR="/usr/local/lib/node_modules/@agentmemory/agentmemory/dist"
SOURCE_CONFIG="${DIST_DIR}/iii-config.docker.yaml"
DEFAULT_CONFIG="${DIST_DIR}/iii-config.yaml"
RAILWAY_CONFIG="/app/iii-config.railway.yaml"

echo "[railway] Starting agentmemory"
echo "[railway] PORT=${PORT}"
echo "[railway] III_DATA_DIR=${III_DATA_DIR}"
echo "[railway] AGENTMEMORY_DATA_DIR=${AGENTMEMORY_DATA_DIR}"

if [ ! -f "$SOURCE_CONFIG" ]; then
  echo "[railway] ERROR: missing ${SOURCE_CONFIG}"
  echo "[railway] dist content:"
  ls -la "$DIST_DIR" || true
  exit 1
fi

# 1. Copier la config Docker officielle agentmemory.
cp "$SOURCE_CONFIG" "$RAILWAY_CONFIG"

# 2. Adapter le port HTTP à Railway.
# La config Docker est normalement sur 3111, mais Railway injecte 8080.
sed -i "0,/port: 3111/s//port: ${PORT}/" "$RAILWAY_CONFIG"

# 3. Sécurité : forcer le bind public interne du conteneur.
# Si la config source change un jour, on évite de retomber sur 127.0.0.1.
sed -i "s/host: 127.0.0.1/host: 0.0.0.0/g" "$RAILWAY_CONFIG"

# 4. Point critique :
# agentmemory ignore --config pour iii-engine dans tes logs.
# Donc on remplace directement la config par défaut qu'il utilise vraiment.
cp "$RAILWAY_CONFIG" "$DEFAULT_CONFIG"

echo "[railway] Overwrote default config:"
echo "[railway] ${DEFAULT_CONFIG}"
echo "[railway] Effective config preview:"
cat "$DEFAULT_CONFIG"

echo "[railway] Launching agentmemory..."

exec agentmemory \
  --port "${PORT}" \
  --verbose