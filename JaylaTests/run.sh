#!/bin/sh
#
# Compile and run the prediction-engine tests. Pure Foundation — no
# Xcode scheme, no simulator. Only the engine's pure files are compiled
# (PredictionPriors.swift depends on app types and is excluded).
#
#   ./JaylaTests/run.sh
#
set -e
cd "$(dirname "$0")/.."

OUT="$(mktemp -d)/predtests"
xcrun swiftc -parse-as-library \
    Jayla/Prediction/Prediction.swift \
    Jayla/Prediction/PredictionEngine.swift \
    JaylaTests/PredictionEngineTests.swift \
    -o "$OUT"
"$OUT"
