#!/bin/sh
#
# Compile and run the history-page day-bucketing tests. Pure Foundation —
# no Xcode scheme, no simulator. DayLog.swift deliberately imports
# nothing but Foundation so it compiles alone here.
#
#   ./JaylaTests/run-daylog.sh
#
set -e
cd "$(dirname "$0")/.."

OUT="$(mktemp -d)/daylogtests"
xcrun swiftc -parse-as-library \
    Jayla/Utilities/DayLog.swift \
    JaylaTests/DayLogTests.swift \
    -o "$OUT"
"$OUT"
