#!/bin/bash
# APR-util, against the APR and expat installed by the previous steps.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

fetch "apr-util-$APRUTIL_VERSION.tar.gz" "$APRUTIL_URL" "$APRUTIL_SHA256"
unpack "apr-util-$APRUTIL_VERSION.tar.gz" "apr-util-$APRUTIL_VERSION"
cd "$WORK/apr-util-$APRUTIL_VERSION"

log "APR-util $APRUTIL_VERSION"
CFLAGS="-fPIC $MAP_FLAGS -I$DEPS/include" LDFLAGS="-L$DEPS/lib" \
./configure --host=$TARGET --prefix="$DEPS" \
    --with-apr="$DEPS" --with-expat="$DEPS" \
    --disable-shared --enable-static --with-pic
# The DSO directory is compiled in from the prefix; nothing is loaded from it
# in a static build, so point it somewhere neutral.
sed -i "s|^#define APU_DSO_LIBDIR .*|#define APU_DSO_LIBDIR \"$NEUTRAL_PREFIX/lib/apr-util-1\"|" \
    include/private/apu_config.h
grep -qF "\"$NEUTRAL_PREFIX/lib/apr-util-1\"" include/private/apu_config.h \
    || die "APU_DSO_LIBDIR was not replaced"
make -j"$JOBS"
make install
require_arm64 "$DEPS/lib/libaprutil-1.a"
require_no_build_paths "$DEPS/lib/libaprutil-1.a"
