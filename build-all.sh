#!/bin/bash
# Build every shared dependency into DEPS, in order, then record what was
# built in DEPS/BUILD-INFO. See README.md for the settings lib.sh reads.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

for s in "$REPO_DIR"/steps/[0-9]*.sh; do
    bash "$s"
done

{
    echo "kanaha-android-deps $(git -C "$REPO_DIR" describe --always --dirty 2>/dev/null || echo unknown)"
    echo "built $(date -u +%Y-%m-%dT%H:%M:%SZ) NDK $(basename "$NDK") API $API"
    grep -E '^[A-Z0-9]+_(VERSION|REF)=' "$REPO_DIR/versions.env"
} > "$DEPS/BUILD-INFO"
log "Done. $DEPS/BUILD-INFO:"
cat "$DEPS/BUILD-INFO"
