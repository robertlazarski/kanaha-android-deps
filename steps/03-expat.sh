#!/bin/bash
# expat: needed only because APR-util's apr_xml links it, and httpd's
# exports table pulls apr_xml in. Nothing in Kanaha parses XML with it.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

fetch "expat-$EXPAT_VERSION.tar.gz" "$EXPAT_URL" "$EXPAT_SHA256"
unpack "expat-$EXPAT_VERSION.tar.gz" "expat-$EXPAT_VERSION"
cd "$WORK/expat-$EXPAT_VERSION"

log "expat $EXPAT_VERSION"
CFLAGS="-fPIC $MAP_FLAGS" ./configure --host=$TARGET --prefix="$DEPS" \
    --disable-shared --enable-static --with-pic \
    --without-xmlwf --without-examples --without-tests --without-docbook
make -j"$JOBS"
make install
require_arm64 "$DEPS/lib/libexpat.a"
require_no_build_paths "$DEPS/lib/libexpat.a"
