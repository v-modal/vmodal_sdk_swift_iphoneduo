#!/usr/bin/env bash
help='
Usage: bash install.sh COMMAND
Verify the selected Apple toolchain without installing or switching it.
example:
  bash install.sh check
  bash install.sh device_list
'
set -euo pipefail
sdk_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$sdk_dir"

sdk_xcrun() { local help='
    ## Usage:
      sdk_xcrun swift
  '; xcrun --find "$1"; }
sdk_xcode_path() { local help='
    ## Usage:
      bash install.sh xcode_path
  '; xcode-select -p; }
sdk_swift_bin() { local help='
    ## Usage:
      bash install.sh swift_bin
  '; sdk_xcrun swift; }
sdk_xcodebuild_bin() { local help='
    ## Usage:
      bash install.sh xcodebuild_bin
  '; sdk_xcrun xcodebuild; }
sdk_simctl_bin() { local help='
    ## Usage:
      bash install.sh simctl_bin
  '; sdk_xcrun simctl; }
sdk_device_list() { local help='
    ## Usage:
      bash install.sh device_list
  '; xcrun simctl list devices available; }
sdk_device_id() { local help='
    ## Usage:
      bash install.sh device_id
  '; local device; device="$(xcrun simctl list devices available | awk '/iPhone/ {gsub(/[()]/,""); print $(NF-1); exit}')"; [[ -n "$device" ]] || { echo 'An available iPhone simulator is required.' >&2; return 1; }; echo "$device"; }
sdk_check() {
  local help='
    ## Usage:
      bash install.sh check
  '
  command -v xcrun >/dev/null || { echo 'Xcode command-line tools are required.' >&2; return 1; }
  local xcodebuild_path swift_path xcode_version swift_version xcode_output swift_output
  xcodebuild_path="$(sdk_xcodebuild_bin 2>/dev/null)" || { echo 'Full Xcode 26.6 or newer is required; set DEVELOPER_DIR to its Contents/Developer.' >&2; return 1; }
  swift_path="$(sdk_swift_bin)"
  xcode_output="$("$xcodebuild_path" -version 2>&1)" || { echo 'Full Xcode 26.6 or newer is required; set DEVELOPER_DIR to its Contents/Developer.' >&2; return 1; }
  swift_output="$("$swift_path" --version)"
  printf '%s\n%s\n' "$xcode_output" "$swift_output"
  xcode_version="$(awk 'NR==1 {print $2}' <<< "$xcode_output")"
  swift_version="$(awk 'NR==1 {for (i=1;i<=NF;i++) if ($i=="version") {print $(i+1); exit}}' <<< "$swift_output")"
  awk -v actual="$xcode_version" -v required="$(cat .xcode-version)" 'BEGIN {split(actual,a,"."); split(required,r,"."); exit !((a[1]>r[1]) || (a[1]==r[1] && a[2]>=r[2]))}' || { echo "Xcode $(cat .xcode-version) or newer is required; selected $xcode_version." >&2; return 1; }
  awk -v actual="$swift_version" -v required="$(cat .swift-version)" 'BEGIN {split(actual,a,"."); split(required,r,"."); exit !((a[1]>r[1]) || (a[1]==r[1] && a[2]>=r[2]))}' || { echo "Swift $(cat .swift-version) or newer is required; selected $swift_version." >&2; return 1; }
  "$xcodebuild_path" -license check >/dev/null || { echo 'Accept the selected Xcode license before continuing.' >&2; return 1; }
  local ios_version
  ios_version="$(xcrun --sdk iphoneos --show-sdk-version)" || { echo 'The selected Xcode needs the iOS SDK.' >&2; return 1; }
  [[ "$ios_version" == '26.5'* ]] || { echo "The iOS 26.5 SDK supplied by Xcode 26.6 is required; selected $ios_version." >&2; return 1; }
  # FUTURE_IPHONE_DUO_XCODE_27_1: restore these exact device gates with Xcode 27.1.
  # devices="$(xcrun simctl list devices available)" || { echo 'Install an iOS 27.1 simulator runtime.' >&2; return 1; }
  # grep -q 'iPhone Duo' <<< "$devices" || { echo 'Create one iPhone Duo simulator for the Duo acceptance gate.' >&2; return 1; }
  swift package resolve
}
sdk_dispatch() {
  local help='
    ## Usage:
      bash install.sh check
  '
  case "${1:-help}" in
    check) sdk_check ;;
    xcode_path) sdk_xcode_path ;;
    swift_bin) sdk_swift_bin ;;
    xcodebuild_bin) sdk_xcodebuild_bin ;;
    simctl_bin) sdk_simctl_bin ;;
    device_list) sdk_device_list ;;
    device_id) sdk_device_id ;;
    help|-h|--help) echo "$help" ;;
    *) echo "Unknown command: $1" >&2; echo "$help" >&2; return 2 ;;
  esac
}
sdk_dispatch "$@"
