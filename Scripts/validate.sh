#!/bin/bash
# SPDX-License-Identifier: MIT
# Run from the repository root. Uses Xcode headlessly without changing xcode-select.
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
mkdir -p .build/evidence
xcrun swift --version > .build/evidence/toolchain.txt 2>&1
xcodebuild -version >> .build/evidence/toolchain.txt 2>&1
xcrun swift build --disable-sandbox --build-system native -c debug > .build/evidence/build-debug.log 2>&1
xcrun swift test --disable-sandbox --build-system native -c debug --xunit-output .build/evidence/debug-tests.xml > .build/evidence/test-debug.log 2>&1
xcrun swift build --disable-sandbox --build-system native -c release > .build/evidence/build-release.log 2>&1
xcrun swift test --disable-sandbox --build-system native -c release --xunit-output .build/evidence/release-tests.xml > .build/evidence/test-release.log 2>&1
xcrun swift run --disable-sandbox --build-system native --package-path Examples/Consumer Consumer > .build/evidence/consumer.log 2>&1
xcrun swift test --disable-sandbox --build-system native --sanitize=address --scratch-path .build/asan --xunit-output .build/evidence/asan-tests.xml > .build/evidence/asan.log 2>&1
xcrun swift test --disable-sandbox --build-system native --sanitize=thread --scratch-path .build/tsan --xunit-output .build/evidence/tsan-tests.xml > .build/evidence/tsan.log 2>&1
