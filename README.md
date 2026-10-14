# Agentmemory Railway Template

Self-hosted persistent memory for AI agents on Railway.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/agentmemory-self-hosted-memory-for-ai-ag?referralCode=1q5cCO&utm_medium=integration&utm_source=template&utm_campaign=generic)

## What is this?

This repository contains a Railway-ready setup for running Agentmemory as a remote memory server for AI coding agents.

It exposes the Agentmemory REST API, stores persistent data on a Railway volume, and can be connected to MCP-compatible tools such as OpenAI Codex CLI, Claude Code, Cursor, Cline, and other agents.

## Railway Template

Deploy it here:

https://railway.com/deploy/agentmemory-self-hosted-memory-for-ai-ag

## Validated Versions

- Agentmemory: `0.9.30`
- iii engine and SDK: `0.22.1`
- Node.js: `22`

## Default Setup

- REST API exposed on Railway public networking
- Persistent storage mounted at `/data`
- API protected with `AGENTMEMORY_SECRET`
- Viewer on internal port `8083`, behind the template's Caddy Basic Auth proxy
- Noninteractive startup and persistent preferences under `/data/.agentmemory`
- No LLM provider required by default

## Recommended Variables

```env
PORT="8080"
NODE_ENV="production"
III_DATA_DIR="/data"
PUBLIC_AGENTMEMORY_URL="https://${{RAILWAY_PUBLIC_DOMAIN}}"
AGENTMEMORY_SECRET="${{secret(32)}}"
AGENTMEMORY_DATA_DIR="/data"
AGENTMEMORY_REQUIRE_HTTPS="1"
VIEWER_ALLOWED_HOSTS="${{agentmemory viewer caddy.RAILWAY_PUBLIC_DOMAIN}}"
VIEWER_ALLOWED_ORIGINS="https://${{agentmemory viewer caddy.RAILWAY_PUBLIC_DOMAIN}}"
```

The template generates a separate API secret and viewer password for every deployment. Copy `AGENTMEMORY_SECRET` into your MCP clients. Sign in to the viewer with `AUTH_USER` and `AUTH_PASS` from the Caddy service.

For custom domains, add the viewer hostname and its exact HTTPS origin to the two viewer allow-list variables, then redeploy Agentmemory. Keep the viewer relay private.

The startup script retains your supplied API secret, uses the official Docker engine configuration, and runs Agentmemory as the unprivileged `node` user. No compiled JavaScript patches or external LLM key are required.

## Test the API

```bash
curl -i \
  -H "Authorization: Bearer $AGENTMEMORY_SECRET" \
  "$AGENTMEMORY_URL/agentmemory/health"
```

A healthy authenticated deployment should return HTTP `200`. Railway uses the public `/agentmemory/livez` endpoint for container liveness; this endpoint contains no memory data.

## Use with Codex

Install the MCP shim:

```bash
npm install -g @agentmemory/mcp@0.9.30
```

Add this to `~/.codex/config.toml`:

```toml
[mcp_servers.agentmemory]
command = "/opt/homebrew/bin/agentmemory-mcp"
args = []
enabled = true
startup_timeout_sec = 60
tool_timeout_sec = 120

[mcp_servers.agentmemory.env]
AGENTMEMORY_URL = "https://your-railway-domain.up.railway.app"
AGENTMEMORY_SECRET = "your-secret"
AGENTMEMORY_FORCE_PROXY = "1"
```

Then run `/mcp` inside Codex and check that `agentmemory` is listed.
