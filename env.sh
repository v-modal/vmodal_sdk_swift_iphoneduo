#!/usr/bin/env bash
help='
Usage: source env.sh && sdk_env_live
Derive Swift SDK aliases from existing repository variables without storing values.
example:
  source env.sh && sdk_env_live
  bash env.sh release
'
sdk_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sdk_env_live() { local help='
    ## Usage:
      source env.sh && sdk_env_live
  '; : "${VMODAL_API_KEY:=${TEST_CLIENT_CLERK_USER_API_TOKEN:-}}"; : "${VMODAL_BASE_URL:=${TEST_CLIENT_SERVER_API_URL:-}}"; : "${VMODAL_USER_ID:=${TEST_CLIENT_USER_ID:-}}"; : "${VMODAL_ENV:=prd}"; : "${VMODAL_LIVE_FILE:=$sdk_dir/../sdk_flutter/example/01_full_app/asset/video_10frames.mp4}"; : "${VMODAL_CCTV_FILE:=$VMODAL_LIVE_FILE}"; export VMODAL_API_KEY VMODAL_BASE_URL VMODAL_USER_ID VMODAL_ENV VMODAL_LIVE_FILE VMODAL_CCTV_FILE; }
sdk_env_release() { local help='
    ## Usage:
      source env.sh && sdk_env_release
  '; : "${VMODAL_RELEASE_TOKEN:=${RELEASE_TOKEN:-}}"; export VMODAL_RELEASE_TOKEN; }
sdk_env_dispatch() { local help='
    ## Usage:
      bash env.sh live
  '; case "${1:-help}" in live) sdk_env_live;; release) sdk_env_release;; help|-h|--help) echo "$help";; *) echo "Unknown command: $1" >&2; echo "$help" >&2; return 2;; esac; }
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then set -euo pipefail; sdk_env_dispatch "$@"; fi
