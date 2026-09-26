#!/usr/bin/env bash
help='
Usage: bash test.sh COMMAND [STEP]
Run offline gates by default; live gates require explicit invocation.
example:
  bash test.sh test
  bash test.sh regression 4
'
set -euo pipefail
sdk_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$sdk_dir"
sdk_test() { local help='
    ## Usage:
      bash test.sh test
  '; bash install.sh check; bash build.sh analyze; swift test; }
sdk_regression() { local help='
    ## Usage:
      bash test.sh regression STEP
  '; local step="${1:-}"; [[ "$step" =~ ^([1-9]|10)$ ]] || { echo 'STEP must be 1 through 10.' >&2; return 2; }; local groups=('FoundationTests' 'ConfigRoutesTests' 'AuthHTTPTests TransportTests ErrorLeakTests' 'ResourcesModelsTests' 'ScopedAPITests' 'UploadTests' 'MultipartUploadTests' 'AdaptiveUploadTests CCTVContractTests TranscodeUploadTests' 'ShellScriptsTests' 'XcodeCompatibilityTests'); local index suite suites; for ((index=0; index<step; index++)); do read -r -a suites <<< "${groups[$index]}"; for suite in "${suites[@]}"; do swift test --filter "$suite"; done; done; }
sdk_sim() { local help='
    ## Usage:
      bash test.sh sim
  '; bash run.sh sim; }
sdk_ios() { local help='
    ## Usage:
      bash test.sh ios
  '; local device; device="$(bash install.sh device_id)"; bash build.sh example_ios; xcodebuild test -project example/StarterIOS/StarterIOS.xcodeproj -scheme StarterIOS -configuration Debug -destination "platform=iOS Simulator,id=$device" CODE_SIGNING_ALLOWED=NO; sdk_framebase_ios "$device"; xcodebuild test -scheme VModalSDK-Package -destination "platform=iOS Simulator,id=$device"; }
sdk_framebase_ios() { local help='
    ## Usage:
      bash test.sh framebase_ios [DEVICE_UDID]
  '; local device="${1:-}"; [[ -n "$device" ]] || device="$(bash install.sh device_id)"; bash build.sh framebase_ios; xcodebuild test -project example/05_framebase/Framebase.xcodeproj -scheme Framebase -configuration Debug -destination "platform=iOS Simulator,id=$device" -derivedDataPath example/05_framebase/DerivedData CODE_SIGNING_ALLOWED=NO; }
# FUTURE_IPHONE_DUO_XCODE_27_1: restore the exact Duo acceptance commands later.
# sdk_duo() { bash build.sh duo_example; xcodebuild test -project example/StarterIOS/StarterIOS.xcodeproj -scheme StarterIOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone Duo' CODE_SIGNING_ALLOWED=NO; xcodebuild test -scheme VModalSDK-Package -destination 'platform=iOS Simulator,name=iPhone Duo'; }
sdk_security() { local help='
    ## Usage:
      bash test.sh security
  '; bash security_check.sh all; }
sdk_package() { local help='
    ## Usage:
      bash test.sh package
  '; bash build.sh package; }
sdk_live() { local help='
    ## Usage:
      bash test.sh live
  '; source env.sh; sdk_env_live; [[ -n "${VMODAL_API_KEY:-}" ]] || { echo 'VMODAL_API_KEY is required.' >&2; return 1; }; swift run LiveTest; }
sdk_cctv_live() { local help='
    ## Usage:
      bash test.sh cctv_live
  '; source env.sh; sdk_env_live; [[ -n "${VMODAL_API_KEY:-}" ]] || { echo 'VMODAL_API_KEY is required.' >&2; return 1; }; swift run LiveCCTVTest; }
sdk_all() { local help='
    ## Usage:
      bash test.sh all
  '; sdk_test; sdk_security; sdk_package; sdk_sim; sdk_ios; }
sdk_clean() { local help='
    ## Usage:
      bash test.sh clean
  '; bash build.sh clean; }
sdk_dispatch() { local help='
    ## Usage:
      bash test.sh test
  '; local command="${1:-help}"; shift || true; case "$command" in test) sdk_test "$@";; regression) sdk_regression "$@";; sim) sdk_sim "$@";; ios) sdk_ios "$@";; framebase_ios) sdk_framebase_ios "$@";; security) sdk_security "$@";; package) sdk_package "$@";; live) sdk_live "$@";; cctv_live) sdk_cctv_live "$@";; all) sdk_all "$@";; clean) sdk_clean "$@";; help|-h|--help) echo "$help";; *) echo "Unknown command: $command" >&2; echo "$help" >&2; return 2;; esac; }
sdk_dispatch "$@"
