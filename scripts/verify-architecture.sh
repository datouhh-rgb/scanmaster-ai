#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT="${TMPDIR:-/tmp}/scanmaster-architecture-smoke"

find \
    "$ROOT/ScanMasterAI/Domain" \
    "$ROOT/ScanMasterAI/Application" \
    "$ROOT/ScanMasterAI/Infrastructure/Persistence" \
    -name '*.swift' -print > "$OUTPUT.sources"

set --
while IFS= read -r source; do
    set -- "$@" "$source"
done < "$OUTPUT.sources"
set -- "$@" "$ROOT/scripts/ArchitectureSmokeTests/main.swift"

swiftc "$@" -o "$OUTPUT"
"$OUTPUT"
