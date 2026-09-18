#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail
mkdir -p .validation/apple
while read -r sdk triple; do
  sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
  xcrun --sdk "$sdk" --show-sdk-version
  swift build -j 2 --scratch-path ".build/apple-$triple" --sdk "$sdk_path" --triple "$triple" 2>&1 | tee ".validation/apple/$triple.log"
done <<'TARGETS'
iphoneos arm64-apple-ios26.0
iphonesimulator arm64-apple-ios26.0-simulator
appletvos arm64-apple-tvos26.0
appletvsimulator arm64-apple-tvos26.0-simulator
xros arm64-apple-xros26.0
xrsimulator arm64-apple-xros26.0-simulator
watchos arm64_32-apple-watchos26.0
watchos arm64-apple-watchos26.0
watchsimulator arm64-apple-watchos26.0-simulator
TARGETS
