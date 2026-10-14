ARG III_VERSION=0.22.1
FROM iiidev/iii:${III_VERSION} AS iii-image

FROM node:22-slim

ARG AGENTMEMORY_VERSION=0.9.30
ARG III_VERSION=0.22.1

ENV NODE_ENV=production \
    HOME=/data \
    AGENTMEMORY_III_VERSION=${III_VERSION} \
    TINI_SUBREAPER=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tini gosu \
    && rm -rf /var/lib/apt/lists/*

COPY --from=iii-image /app/iii /usr/local/bin/iii
RUN iii --version 2>&1 | grep -qF "${III_VERSION}"

WORKDIR /opt/agentmemory
RUN printf '{"name":"agentmemory-railway","private":true,"overrides":{"iii-sdk":"%s"}}\n' "${III_VERSION}" > package.json \
    && npm install "@agentmemory/agentmemory@${AGENTMEMORY_VERSION}" --omit=optional --no-audit --no-fund \
    && ln -s /opt/agentmemory/node_modules/.bin/agentmemory /usr/local/bin/agentmemory \
    && cp node_modules/@agentmemory/agentmemory/dist/iii-config.docker.yaml node_modules/@agentmemory/agentmemory/dist/iii-config.yaml

COPY --chmod=0755 start.sh /usr/local/bin/agentmemory-start
COPY viewer-proxy.mjs /opt/agentmemory/viewer-proxy.mjs

EXPOSE 8080
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/agentmemory-start"]
