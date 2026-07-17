# Build stage: install @techdocs/cli with npm overrides (techdocs/package.json)
# that force patched transitive deps — the versions its ranges otherwise resolve
# to are flagged HIGH by Trivy. @techdocs/cli pulls in better-sqlite3, a native
# addon with no Node 24 prebuilt, so npm compiles it here with build-essential —
# a toolchain deliberately kept out of the runtime image.
FROM node:24.18.0-trixie-slim AS build
RUN apt-get update \
     && apt-get install -y --no-install-recommends \
     python3=3.13.5-1 \
     build-essential=12.12 \
     && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/techdocs
COPY techdocs/package.json ./package.json
# Smoke-test the CLI so a bad override that breaks module resolution fails here.
RUN npm install --omit=dev \
     && ./node_modules/.bin/techdocs-cli --version

# Runtime stage: no compiler. Python (+venv) for mkdocs plus the prebuilt CLI
# bundle from the build stage. libcap2 is upgraded to the trixie-security build
# (CVE-2026-4878) because the base image still ships the vulnerable one. npm is
# removed — techdocs-cli and mkdocs never call it, and its bundled deps
# (minimatch, tar, sigstore, ...) are a standing source of Trivy HIGH findings.
FROM node:24.18.0-trixie-slim
RUN apt-get update \
     && apt-get install -y --no-install-recommends \
     python3=3.13.5-1 \
     python3-venv=3.13.5-1 \
     libcap2=1:2.75-10+deb13u1+b1 \
     && rm -rf /var/lib/apt/lists/* \
     && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx
COPY --from=build /opt/techdocs /opt/techdocs

# Trixie's system Python is externally managed (PEP 668), so mkdocs and its
# plugins go in a venv. The venv and the CLI's bin dir go first on PATH so
# `mkdocs` and `techdocs-cli` resolve without activation.
RUN python3 -m venv /opt/venv \
     && /opt/venv/bin/pip install --no-cache-dir mkdocs-techdocs-core==1.4.2
ENV PATH="/opt/venv/bin:/opt/techdocs/node_modules/.bin:$PATH"

USER node
