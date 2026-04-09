# syntax=docker/dockerfile:1.7

ARG NODE_VERSION=22.16.0
ARG ALPINE_VERSION=3.20
ARG GO_VERSION=1.24.2
ARG PNPM_VERSION=9.15.9

FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION} AS pnpm-base

ARG PNPM_VERSION

ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH

RUN corepack enable \
 && corepack prepare pnpm@${PNPM_VERSION} --activate


FROM pnpm-base AS frontend-build

WORKDIR /src/third_party/Sub-Store-Front-End

COPY third_party/Sub-Store-Front-End/package.json ./
COPY third_party/Sub-Store-Front-End/pnpm-lock.yaml ./

RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store \
    pnpm install --frozen-lockfile

COPY third_party/Sub-Store-Front-End/ ./

RUN pnpm build


FROM pnpm-base AS backend-build

WORKDIR /src/third_party/Sub-Store/backend

COPY third_party/Sub-Store/backend/package.json ./
COPY third_party/Sub-Store/backend/pnpm-lock.yaml ./
COPY third_party/Sub-Store/backend/patches ./patches

RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store \
    pnpm install --frozen-lockfile

COPY third_party/Sub-Store/backend/ ./

RUN pnpm bundle:esbuild


FROM pnpm-base AS http-meta-build

WORKDIR /src/third_party/http-meta

COPY third_party/http-meta/package.json ./
COPY third_party/http-meta/pnpm-lock.yaml ./

RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store \
    pnpm install --frozen-lockfile

COPY third_party/http-meta/ ./

RUN pnpm bundle


FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS go-base

RUN apk add --no-cache ca-certificates git


FROM go-base AS shoutrrr-build

WORKDIR /src/third_party/shoutrrr

COPY third_party/shoutrrr/go.mod ./
COPY third_party/shoutrrr/go.sum ./

RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY third_party/shoutrrr/ ./

ARG TARGETARCH
ARG TARGETVARIANT

RUN set -eux; \
    export GOOS=linux; \
    export CGO_ENABLED=0; \
    case "${TARGETARCH:-amd64}/${TARGETVARIANT:-}" in \
      "amd64/") export GOARCH=amd64 GOAMD64=v1 ;; \
      "arm64/") export GOARCH=arm64 ;; \
      "arm/v7") export GOARCH=arm GOARM=7 ;; \
      *) echo "Unsupported target platform: ${TARGETARCH:-amd64}/${TARGETVARIANT:-}" >&2; exit 1 ;; \
    esac; \
    mkdir -p /out; \
    go build -trimpath -ldflags="-w -s" -o /out/shoutrrr ./shoutrrr


FROM go-base AS mihomo-build

WORKDIR /src/third_party/mihomo

COPY third_party/mihomo/go.mod ./
COPY third_party/mihomo/go.sum ./

RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY third_party/mihomo/ ./

ARG TARGETARCH
ARG TARGETVARIANT
ARG MIHOMO_BUILD_VERSION=meta-source

RUN --mount=type=cache,target=/root/.cache/go-build \
    set -eux; \
    buildtime="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; \
    export GOOS=linux; \
    export CGO_ENABLED=0; \
    case "${TARGETARCH:-amd64}/${TARGETVARIANT:-}" in \
      "amd64/") export GOARCH=amd64 GOAMD64=v1 ;; \
      "arm64/") export GOARCH=arm64 ;; \
      "arm/v7") export GOARCH=arm GOARM=7 ;; \
      *) echo "Unsupported target platform: ${TARGETARCH:-amd64}/${TARGETVARIANT:-}" >&2; exit 1 ;; \
    esac; \
    mkdir -p /out; \
    go build -tags with_gvisor -trimpath \
      -ldflags="-X github.com/metacubex/mihomo/constant.Version=${MIHOMO_BUILD_VERSION} -X github.com/metacubex/mihomo/constant.BuildTime=${buildtime} -w -s -buildid=" \
      -o /out/http-meta .


FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION} AS runtime

ENV TIME_ZONE=Asia/Shanghai \
    HOST=127.0.0.1 \
    SUB_STORE_DOCKER=true \
    SUB_STORE_FRONTEND_PATH=/opt/app/frontend \
    SUB_STORE_DATA_BASE_PATH=/opt/app/data \
    META_FOLDER=/opt/app/http-meta

RUN apk add --no-cache ca-certificates procps tzdata \
 && cp /usr/share/zoneinfo/${TIME_ZONE} /etc/localtime \
 && echo ${TIME_ZONE} > /etc/timezone \
 && mkdir -p /opt/app/data /opt/app/http-meta

WORKDIR /opt/app

COPY --from=frontend-build --chown=node:node /src/third_party/Sub-Store-Front-End/dist ./frontend
COPY --from=backend-build --chown=node:node /src/third_party/Sub-Store/backend/dist/sub-store.bundle.js ./sub-store.bundle.js
COPY --from=http-meta-build --chown=node:node /src/third_party/http-meta/dist/http-meta.bundle.js ./http-meta.bundle.js
COPY --from=http-meta-build --chown=node:node /src/third_party/http-meta/meta/tpl.yaml ./http-meta/tpl.yaml
COPY --from=mihomo-build --chown=node:node /out/http-meta ./http-meta/http-meta
COPY --from=shoutrrr-build --chown=node:node /out/shoutrrr /usr/local/bin/shoutrrr
COPY --chown=node:node docker/entrypoint.sh /usr/local/bin/sub-store-entrypoint

RUN chown -R node:node /opt/app \
 && chmod 755 /usr/local/bin/sub-store-entrypoint /usr/local/bin/shoutrrr /opt/app/http-meta/http-meta

USER node

EXPOSE 3000 3001 9876

ENTRYPOINT ["/usr/local/bin/sub-store-entrypoint"]
