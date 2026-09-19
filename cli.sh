#!/usr/bin/env bash
help='
Usage: bash cli.sh COMMAND [DIRECTORY]
Generate/check routes, DocC, versions, and release manifests.
Examples:
  bash cli.sh routes_check
  bash cli.sh release_manifest .
'
set -euo pipefail
sdk_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$sdk_dir"
sdk_repo_env() {
  local help='
    ## Usage:
      sdk_repo_env
  '
  local root
  root="$(cd "$sdk_dir/../.." && pwd)"
  export PYTHONPATH="$root"
  if [[ -f "$root/isetup_env.sh" ]]; then
    # shellcheck source=/dev/null
    source "$root/isetup_env.sh"
  fi
}
sdk_routes_generate() { local help='
    ## Usage:
      bash cli.sh routes_generate
  '; swift run RouteSync generate Tests/VModalSDKTests/Fixtures/routes_contract.json Sources/VModalSDK/Routes.generated.swift; }
sdk_routes_check() { local help='
    ## Usage:
      bash cli.sh routes_check
  '; local generated; generated="$(mktemp -t vmodal-routes)"; swift run RouteSync generate Tests/VModalSDKTests/Fixtures/routes_contract.json "$generated"; cmp -s "$generated" Sources/VModalSDK/Routes.generated.swift || { rm -f -- "$generated"; echo 'Generated route source has drifted.' >&2; return 1; }; rm -f -- "$generated"; swift run RouteSync check Tests/VModalSDKTests/Fixtures/routes_contract.json Sources/VModalSDK/Routes.generated.swift; }
sdk_docs_generate() { local help='
    ## Usage:
      bash cli.sh docs_generate
  '; bash build.sh docs; }
sdk_docs_check() { local help='
    ## Usage:
      bash cli.sh docs_check
  '; bash build.sh docs_check; }
sdk_docs_precommit() { local help='
    ## Usage:
      bash cli.sh docs_precommit
  '; sdk_repo_env; if git diff --cached --name-only -- sdk_swift_apple | grep -Eq '\.(swift|md|json)$'; then sdk_routes_check; sdk_docs_generate; git diff --exit-code -- Sources/VModalSDK/Routes.generated.swift docs docs_sdk; fi; }
sdk_release_check() { local help='
    ## Usage:
      bash cli.sh release_check
  '; swift run ReleaseManifest version; }
sdk_release_manifest() { local help='
    ## Usage:
      bash cli.sh release_manifest [DIRECTORY]
  '; swift run ReleaseManifest manifest "${1:-.}"; }
sdk_dispatch() { local help='
    ## Usage:
      bash cli.sh routes_check
  '; local command="${1:-help}"; shift || true; case "$command" in routes_generate) sdk_routes_generate "$@";; routes_check) sdk_routes_check "$@";; docs_generate) sdk_docs_generate "$@";; docs_check) sdk_docs_check "$@";; docs_precommit) sdk_docs_precommit "$@";; release_check) sdk_release_check "$@";; release_manifest) sdk_release_manifest "$@";; help|-h|--help) echo "$help";; *) echo "Unknown command: $command" >&2; echo "$help" >&2; return 2;; esac; }
sdk_dispatch "$@"
