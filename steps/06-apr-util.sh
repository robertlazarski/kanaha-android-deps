#!/bin/bash
# APR-util, against the APR and expat installed by the previous steps.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

fetch "apr-util-$APRUTIL_VERSION.tar.gz" "$APRUTIL_URL" "$APRUTIL_SHA256"
unpack "apr-util-$APRUTIL_VERSION.tar.gz" "apr-util-$APRUTIL_VERSION"
cd "$WORK/apr-util-$APRUTIL_VERSION"

log "APR-util $APRUTIL_VERSION"
CFLAGS="-fPIC -I$DEPS/include" LDFLAGS="-L$DEPS/lib" \
./configure --host=$TARGET --prefix="$DEPS" \
    --with-apr="$DEPS" --with-expat="$DEPS" \
    --disable-shared --enable-static --with-pic
make -j"$JOBS"
make install
require_arm64 "$DEPS/lib/libaprutil-1.a"
