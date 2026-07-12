#!/bin/sh
#
# Compile and run the Formatters tests. Pure Foundation — no Xcode
# scheme, no simulator.
#
#   ./JaylaTests/run-formatters.sh
#
set -e
cd "$(dirname "$0")/.."

OUT="$(mktemp -d)/formatterstests"
xcrun swiftc -parse-as-library \
    Jayla/Utilities/Formatters.swift \
    JaylaTests/FormattersTests.swift \
    -o "$OUT"
"$OUT"
