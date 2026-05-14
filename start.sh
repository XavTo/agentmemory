#!/usr/bin/env bash
set -euo pipefail

export HOME=/app
export PATH="/app/.local/bin:${PATH}"

# Railway injecte parfois PORT automatiquement.
# On force 3111 par défaut si PORT n'existe pas.
export PORT="${PORT:-3111}"

# Dossiers persistants
export III_DATA_DIR="${III_DATA_DIR:-/data}"
export AGENTMEMORY_DATA_DIR="${AGENTMEMORY_DATA_DIR:-/data}"

# URLs internes par défaut
export AGENTMEMORY_URL="${AGENTMEMORY_URL:-http://0.0.0.0:${PORT}}"
export AGENTMEMORY_VIEWER_URL="${AGENTMEMORY_VIEWER_URL:-http://0.0.0.0:3113}"

mkdir -p /data
mkdir -p /app

# Config Railway/Docker explicite.
# Le point critique est host: 0.0.0.0 pour que Railway puisse router vers le conteneur.
cat > /app/iii-config.railway.yaml <<EOF
version: 1

engine:
  host: 0.0.0.0
  port: 49134
  dataDir: /data

plugins:
  - name: iii-http
    enabled: true
    config:
      host: 0.0.0.0
      port: ${PORT}
      basePath: /agentmemory

  - name: iii-ws
    enabled: true
    config:
      host: 0.0.0.0
      port: 3112

  - name: agentmemory
    enabled: true
    config:
      dataDir: /data
      viewer:
        host: 0.0.0.0
        port: 3113
EOF

echo "[railway] Starting agentmemory"
echo "[railway] PORT=${PORT}"
echo "[railway] III_DATA_DIR=${III_DATA_DIR}"
echo "[railway] AGENTMEMORY_DATA_DIR=${AGENTMEMORY_DATA_DIR}"
echo "[railway] Config: /app/iii-config.railway.yaml"

exec agentmemory \
  --config /app/iii-config.railway.yaml \
  --port "${PORT}" \
  --verbose