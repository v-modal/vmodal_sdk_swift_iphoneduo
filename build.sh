#!/usr/bin/env bash
help='
Usage: bash build.sh COMMAND
Build, test, document, package, or clean VModalSDK.
example:
  bash build.sh build
  bash build.sh analyze
  bash build.sh docs
  bash build.sh docs_check

##todo 2026-09-20
- [wiring] Keep docs/sdk_reference_index.html aligned with the advertised root URL
  in docs_sdk/README.md:5 and the deployment URL in
  .github/workflows/sdk_swift_apple_test_release.yml:256.
- [contract] Verify the route-specific DocC shell uses the repository base path;
  .github/workflows/sdk_swift_apple_test_release.yml:308 must reject a root
  baseUrl that would load assets from the organization site.
'
set -euo pipefail
sdk_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$sdk_dir"
sdk_resolve() { local help='
    ## Usage:
      bash build.sh resolve
  '; bash install.sh check; swift package resolve; }
sdk_format() { local help='
    ## Usage:
      bash build.sh format
  '; local bin; bin="$(xcrun --find swift-format)"; "$bin" lint --recursive Sources Tests Tools example; }
sdk_analyze() { local help='
    ## Usage:
      bash build.sh analyze
  '; swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors; }
sdk_test() { local help='
    ## Usage:
      bash build.sh test
  '; local device; swift test; if [[ -d example/StarterIOS/StarterIOSTests ]]; then device="$(bash install.sh device_id)"; xcodebuild test -project example/StarterIOS/StarterIOS.xcodeproj -scheme StarterIOS -configuration Debug -destination "platform=iOS Simulator,id=$device" CODE_SIGNING_ALLOWED=NO; fi; }
sdk_docs() { local help='
    ## Usage:
      bash build.sh docs
  '; local work archive site dest base_flag; work="$(mktemp -d "${TMPDIR:-/tmp}/vmodal-swift-docs.XXXXXX")"; site="$work/site"; dest="$sdk_dir/docs_sdk"; xcodebuild docbuild -scheme VModalSDK-Package -destination 'generic/platform=iOS Simulator' OTHER_SWIFT_FLAGS='-warnings-as-errors' -derivedDataPath "$work/DerivedData" DOCC_HOSTING_BASE_PATH='vmodal_sdk_swift_iphoneduo' CODE_SIGNING_ALLOWED=NO; archive="$(find "$work/DerivedData" -type d -name 'VModalSDK.doccarchive' -print -quit)"; [[ -n "$archive" ]] || { echo 'VModalSDK.doccarchive was not generated.' >&2; return 1; }; mkdir -p "$dest"; if xcrun docc process-archive transform-for-static-hosting --help 2>&1 | grep -q -- '--hosting-base-path'; then base_flag='--hosting-base-path'; else base_flag='--static-hosting-base-path'; fi; xcrun docc process-archive transform-for-static-hosting "$archive" "$base_flag" 'vmodal_sdk_swift_iphoneduo' --output-path "$site"; touch "$site/.nojekyll"; cp "$dest/README.md" "$site/README.md"; cp "$sdk_dir/docs/sdk_reference_index.html" "$site/index.html"; rsync -a --delete "$site/" "$dest/"; rm -rf -- "$work"; sdk_docs_check; }
sdk_docs_check() { local help='
    ## Usage:
      bash build.sh docs_check
  '; local dest="$sdk_dir/docs_sdk"; test -f "$dest/README.md"; test -f "$dest/.nojekyll"; test -f "$dest/index.html"; test -f "$dest/data/documentation/vmodalsdk.json"; test -f "$dest/documentation/vmodalsdk/index.html"; grep -q 'url=documentation/vmodalsdk/' "$dest/index.html"; grep -q 'var baseUrl = "/vmodal_sdk_swift_iphoneduo/"' "$dest/documentation/vmodalsdk/index.html"; }
sdk_example_ios() { local help='
    ## Usage:
      bash build.sh example_ios
  '; xcodebuild build -project example/StarterIOS/StarterIOS.xcodeproj -scheme StarterIOS -destination 'generic/platform=iOS Simulator' -derivedDataPath example/StarterIOS/DerivedData CODE_SIGNING_ALLOWED=NO; }
sdk_framebase_ios() { local help='
    ## Usage:
      bash build.sh framebase_ios
  '; xcodebuild build -project example/05_framebase/Framebase.xcodeproj -scheme Framebase -destination 'generic/platform=iOS Simulator' -derivedDataPath example/05_framebase/DerivedData CODE_SIGNING_ALLOWED=NO; }
# FUTURE_IPHONE_DUO_XCODE_27_1: restore when Xcode 27.1 is available in CI.
# sdk_duo_example() { local device; device="$(xcrun simctl list devices available | awk '/iPhone Duo/ {gsub(/[()]/,""); print $(NF-1); exit}')"; [[ -n "$device" ]] || return 1; xcodebuild build -project example/StarterIOS/StarterIOS.xcodeproj -scheme StarterIOS -destination "platform=iOS Simulator,id=$device" -derivedDataPath example/StarterIOS/DerivedData CODE_SIGNING_ALLOWED=NO; }
sdk_package() { local help='
    ## Usage:
      bash build.sh package
  '; local out; out="$(mktemp -d "${TMPDIR:-/tmp}/vmodal-swift.XXXXXX")"; swift run ReleaseManifest export "$sdk_dir" "$out"; (cd "$out" && swift package resolve && swift build); echo "$out"; }
sdk_build() { local help='
    ## Usage:
      bash build.sh build
  '; sdk_resolve; sdk_format; sdk_analyze; sdk_test; sdk_docs; sdk_package; sdk_example_ios; sdk_framebase_ios; }
sdk_clean() { local help='
    ## Usage:
      bash build.sh clean
  '; [[ -f Package.swift && "$(pwd)" == *'/sdk_swift_apple' ]] || { echo 'Refusing cleanup outside VModalSDK package.' >&2; return 1; }; grep -q 'name: "VModalSDK"' Package.swift || { echo 'VModalSDK product guard failed.' >&2; return 1; }; rm -rf -- "$sdk_dir/.build" "$sdk_dir/docs/generated" "$sdk_dir/example/StarterIOS/DerivedData" "$sdk_dir/example/05_framebase/DerivedData"; }
sdk_dispatch() { local help='
    ## Usage:
      bash build.sh build
  '; case "${1:-help}" in resolve) sdk_resolve;; format) sdk_format;; analyze) sdk_analyze;; test) sdk_test;; docs) sdk_docs;; docs_check) sdk_docs_check;; example_ios) sdk_example_ios;; framebase_ios) sdk_framebase_ios;; package) sdk_package;; build) sdk_build;; clean) sdk_clean;; help|-h|--help) echo "$help";; *) echo "Unknown command: $1" >&2; echo "$help" >&2; return 2;; esac; }
sdk_dispatch "$@"
