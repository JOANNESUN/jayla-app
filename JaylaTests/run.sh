#!/bin/sh
#
# Compile and run the prediction-engine and forecast-engine tests.
# Pure Foundation — no Xcode scheme, no simulator. Only the engines'
# pure files are compiled (PredictionPriors.swift depends on app types
# and is excluded). Each suite is its own binary — both have @main.
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

FOUT="$(mktemp -d)/forecasttests"
xcrun swiftc -parse-as-library \
    Jayla/Prediction/ForecastEngine.swift \
    JaylaTests/ForecastEngineTests.swift \
    -o "$FOUT"
"$FOUT"
