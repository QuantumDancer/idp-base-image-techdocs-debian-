FROM node:24.13.1-trixie-slim

# npm upgraded to clear fixable CVEs in its bundled internal dependencies (same
# rationale as base-image-node-debian). @techdocs/cli is baked in so consuming
# pipelines don't reinstall it on every run.
RUN apt-get update \
     && apt-get install -y --no-install-recommends \
     python3=3.13.5-1 \
     python3-venv=3.13.5-1 \
     && npm install -g npm@11.10.1 @techdocs/cli@1.9.2 \
     && rm -rf /var/lib/apt/lists/*

# Trixie's system Python is externally managed (PEP 668), so mkdocs and its
# plugins go in a venv. Putting the venv first on PATH makes `mkdocs` resolve
# here without activation.
RUN python3 -m venv /opt/venv \
     && /opt/venv/bin/pip install --no-cache-dir mkdocs-techdocs-core==1.4.2
ENV PATH="/opt/venv/bin:$PATH"

USER node
