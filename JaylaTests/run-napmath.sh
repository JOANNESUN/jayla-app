#!/bin/sh
#
# Compile and run the just-woke-nap rule tests. Pure Foundation — no
# Xcode scheme, no simulator. NapMath.swift deliberately imports
# nothing but Foundation so it compiles alone here.
#
#   ./JaylaTests/run-napmath.sh
#
set -e
cd "$(dirname "$0")/.."

OUT="$(mktemp -d)/napmathtests"
xcrun swiftc -parse-as-library \
    Jayla/Utilities/NapMath.swift \
    JaylaTests/NapMathTests.swift \
    -o "$OUT"
"$OUT"
