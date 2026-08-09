#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT="${TMPDIR:-/tmp}/scanmaster-core-smoke"

find "$ROOT/ScanMasterAI/Domain" -name '*.swift' -print > "$OUTPUT.sources"
set --
while IFS= read -r source; do
    set -- "$@" "$source"
done < "$OUTPUT.sources"
set -- "$@" "$ROOT/scripts/CoreSmokeTests/main.swift"

swiftc "$@" -o "$OUTPUT"
"$OUTPUT"
