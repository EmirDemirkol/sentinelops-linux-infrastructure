FROM nginx:alpine

ARG SENTINELOPS_VERSION=0.1.0

COPY index.html /usr/share/nginx/html/index.html

RUN printf '{"status":"healthy","version":"%s"}\n' "$SENTINELOPS_VERSION" \
    > /usr/share/nginx/html/health
