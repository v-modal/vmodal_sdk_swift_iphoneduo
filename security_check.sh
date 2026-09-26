#!/usr/bin/env bash
help='
Usage: bash security_check.sh COMMAND
Check workflow, toolchain, version, license, routes, package, secrets, and forbidden operations.
example:
  bash security_check.sh all
  bash security_check.sh routes
'
set -euo pipefail
sdk_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$sdk_dir"
sdk_workflow() { local help='
    ## Usage:
      bash security_check.sh workflow
  '; local file='../../.github/workflows/sdk_swift_apple_test_release.yml'; local mirror='release/public_publish.yml'; [[ -f "$file" && -f "$mirror" ]] || { echo 'Swift SDK workflow is missing.' >&2; return 1; }; grep -q '^permissions:' "$file"; grep -q 'contents: read' "$file"; grep -q 'persist-credentials: false' "$file"; grep -q 'secret_detection' "$file"; grep -q 'RELEASE_SHA' "$file"; grep -q 'environment: sdk-swift-apple-production' "$file"; grep -q 'repository: v-modal/vmodal_sdk_swift_iphoneduo' "$file"; grep -q 'ga_source_export' "$file"; grep -q 'ga_public_build' "$file"; grep -q 'ga_public_publish' "$file"; ! grep -E 'uses:' "$file" "$mirror" | grep -Ev '@[0-9a-f]{40}([[:space:]]*#.*)?$'; }
sdk_toolchain() { local help='
    ## Usage:
      bash security_check.sh toolchain
  '; [[ "$(cat .xcode-version)" == '26.6' ]]; [[ "$(cat .swift-version)" == '6.0' ]]; bash install.sh check; }
sdk_version() { local help='
    ## Usage:
      bash security_check.sh version
  '; swift run ReleaseManifest version; }
sdk_license() { local help='
    ## Usage:
      bash security_check.sh license
  '; grep -q 'MIT License' LICENSE; grep -q 'MIT License' README.md; }
sdk_routes() { local help='
    ## Usage:
      bash security_check.sh routes
  '; bash cli.sh routes_check; ! grep -RE '(/api/external/v1|/collections/external_upload)' Sources/VModalSDK --include='*.swift'; }
sdk_package() { local help='
    ## Usage:
      bash security_check.sh package
  '; local bad; bad="$(find . -path './.build' -prune -o -path './ztmp' -prune -o -path '*DerivedData*' -prune -o \( -name '.env' -o -name '*.xcuserstate' -o -name '*.checkpoint.json' -o -name '*credentials*' -o -name 'RELEASE_METADATA' \) -print)"; [[ -z "$bad" ]] || { echo "$bad" >&2; return 1; }; }
sdk_secrets() { local help='
    ## Usage:
      bash security_check.sh secrets
  '; command -v gitleaks >/dev/null || { echo 'Install gitleaks 8.24.2 and verify its official release checksum before running this gate.' >&2; return 1; }; gitleaks version | grep -q '8.24.2'; gitleaks detect --source . --config .gitleaks.toml --no-git --redact --no-banner; }
sdk_forbidden() { local help='
    ## Usage:
      bash security_check.sh forbidden
  '; local files=(install.sh build.sh run.sh test.sh cli.sh env.sh ga_release.sh release/public_publish.yml ../../.github/workflows/sdk_swift_apple_test_release.yml); ! grep -E 'git[[:space:]]+merge|push[[:space:]]+--force|--no-verify|(echo|printf)[^#]*\$\{?(VMODAL_API_KEY|VMODAL_RELEASE_TOKEN|TEST_CLIENT_CLERK_USER_API_TOKEN)' "${files[@]}"; }
sdk_all() { local help='
    ## Usage:
      bash security_check.sh all
  '; sdk_workflow; sdk_toolchain; sdk_version; sdk_license; sdk_routes; sdk_package; sdk_secrets; sdk_forbidden; }
sdk_dispatch() { local help='
    ## Usage:
      bash security_check.sh all
  '; case "${1:-help}" in workflow) sdk_workflow;; toolchain) sdk_toolchain;; version) sdk_version;; license) sdk_license;; routes) sdk_routes;; package) sdk_package;; secrets) sdk_secrets;; forbidden) sdk_forbidden;; all) sdk_all;; help|-h|--help) echo "$help";; *) echo "Unknown command: $1" >&2; echo "$help" >&2; return 2;; esac; }
sdk_dispatch "$@"
