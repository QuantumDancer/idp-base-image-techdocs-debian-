# Build stage: @techdocs/cli pulls in better-sqlite3, a native addon with no
# prebuilt binary for Node 24, so npm compiles it via node-gyp. That needs a
# toolchain (make + g++, from build-essential) which we keep out of the runtime
# image. npm is upgraded here to clear fixable CVEs in its bundled deps.
FROM node:24.13.1-trixie-slim AS build
RUN apt-get update \
     && apt-get install -y --no-install-recommends \
     python3=3.13.5-1 \
     build-essential=12.12 \
     && npm install -g npm@11.10.1 @techdocs/cli@1.9.2 \
     && rm -rf /var/lib/apt/lists/*

# Runtime stage: no compiler. Python (+venv) for mkdocs, plus the already-built
# techdocs CLI and upgraded npm copied from the build stage. Same base image, so
# the compiled better-sqlite3 addon stays ABI-compatible.
FROM node:24.13.1-trixie-slim
RUN apt-get update \
     && apt-get install -y --no-install-recommends \
     python3=3.13.5-1 \
     python3-venv=3.13.5-1 \
     && rm -rf /var/lib/apt/lists/*
COPY --from=build /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=build /usr/local/bin /usr/local/bin

# Trixie's system Python is externally managed (PEP 668), so mkdocs and its
# plugins go in a venv. Putting the venv first on PATH resolves `mkdocs` without
# activation.
RUN python3 -m venv /opt/venv \
     && /opt/venv/bin/pip install --no-cache-dir mkdocs-techdocs-core==1.4.2
ENV PATH="/opt/venv/bin:$PATH"

USER node
