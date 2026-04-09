#!/bin/sh
set -eu

mkdir -p /opt/app/data

export SUB_STORE_DOCKER="${SUB_STORE_DOCKER:-true}"
export SUB_STORE_FRONTEND_PATH="${SUB_STORE_FRONTEND_PATH:-/opt/app/frontend}"
export SUB_STORE_DATA_BASE_PATH="${SUB_STORE_DATA_BASE_PATH:-/opt/app/data}"
export META_FOLDER="${META_FOLDER:-/opt/app/http-meta}"

node /opt/app/http-meta.bundle.js &
http_meta_pid=$!

node /opt/app/sub-store.bundle.js &
sub_store_pid=$!

cleanup() {
  kill "${sub_store_pid}" "${http_meta_pid}" 2>/dev/null || true
}

trap cleanup INT TERM

while :; do
  if ! kill -0 "${sub_store_pid}" 2>/dev/null; then
    if wait "${sub_store_pid}"; then
      status=0
    else
      status=$?
    fi
    kill "${http_meta_pid}" 2>/dev/null || true
    wait "${http_meta_pid}" 2>/dev/null || true
    exit "${status}"
  fi

  if ! kill -0 "${http_meta_pid}" 2>/dev/null; then
    if wait "${http_meta_pid}"; then
      status=0
    else
      status=$?
    fi
    kill "${sub_store_pid}" 2>/dev/null || true
    wait "${sub_store_pid}" 2>/dev/null || true
    exit "${status}"
  fi

  sleep 1
done
