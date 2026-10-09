#!/bin/bash
# PCRE2: httpd's regular expressions (mod_rewrite, <LocationMatch>).
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

fetch "pcre2-$PCRE2_VERSION.tar.gz" "$PCRE2_URL" "$PCRE2_SHA256"
unpack "pcre2-$PCRE2_VERSION.tar.gz" "pcre2-$PCRE2_VERSION"
cd "$WORK/pcre2-$PCRE2_VERSION"

log "PCRE2 $PCRE2_VERSION"
./configure --host=$TARGET --prefix="$DEPS" --disable-shared --enable-static
make -j"$JOBS"
make install
require_arm64 "$DEPS/lib/libpcre2-8.a"
