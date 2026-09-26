#!/usr/bin/env bash
help='
Usage: bash run.sh COMMAND [--device DEVICE_UDID]
Run the offline simulation or StarterIOS on an explicitly selected simulator.
example:
  bash run.sh sim
  bash run.sh example --device ABC-123
'
set -euo pipefail
sdk_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$sdk_dir"
sdk_sim() { local help='
    ## Usage:
      bash run.sh sim
  '; swift run SDKSimulation; }
sdk_device_arg() { local help='
    ## Usage:
      sdk_device_arg --device DEVICE_UDID
  '; [[ "${1:-}" == '--device' && -n "${2:-}" ]] || { echo '--device DEVICE_UDID is required.' >&2; return 2; }; echo "$2"; }
sdk_example() { local help='
    ## Usage:
      bash run.sh example --device DEVICE_UDID
  '; local device app; device="$(sdk_device_arg "$@")"; xcrun simctl bootstatus "$device" -b; bash build.sh example_ios; app="$(find example/StarterIOS/DerivedData -name StarterIOS.app -type d -print -quit)"; [[ -n "$app" ]] || { echo 'StarterIOS.app was not built.' >&2; return 1; }; xcrun simctl install "$device" "$app"; xcrun simctl launch "$device" com.vmodal.StarterIOS; }
sdk_framebase() { local help='
    ## Usage:
      bash run.sh framebase --device DEVICE_UDID
  '; local device app; device="$(sdk_device_arg "$@")"; xcrun simctl bootstatus "$device" -b; bash build.sh framebase_ios; app="$(find example/05_framebase/DerivedData -name Framebase.app -type d -print -quit)"; [[ -n "$app" ]] || { echo 'Framebase.app was not built.' >&2; return 1; }; xcrun simctl install "$device" "$app"; xcrun simctl launch "$device" com.vmodal.Framebase; }
# FUTURE_IPHONE_DUO_XCODE_27_1: restore automatic Duo simulator selection later.
# sdk_duo() { local devices count; devices="$(xcrun simctl list devices available | awk '/iPhone Duo/ {gsub(/[()]/,""); print $(NF-1)}')"; count="$(printf '%s\n' "$devices" | awk 'NF {n++} END {print n+0}')"; [[ "$count" == 1 ]] || return 1; sdk_example --device "$devices"; }
sdk_dispatch() { local help='
    ## Usage:
      bash run.sh sim
  '; local command="${1:-help}"; shift || true; case "$command" in sim) sdk_sim "$@";; example) sdk_example "$@";; framebase) sdk_framebase "$@";; help|-h|--help) echo "$help";; *) echo "Unknown command: $command" >&2; echo "$help" >&2; return 2;; esac; }
sdk_dispatch "$@"
