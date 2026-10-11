#!/bin/bash
# APR, with patches/apr-android.patch: bionic already defines union semun,
# and its strerror_r is the XSI one that returns int.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

fetch "apr-$APR_VERSION.tar.gz" "$APR_URL" "$APR_SHA256"
unpack "apr-$APR_VERSION.tar.gz" "apr-$APR_VERSION"
cd "$WORK/apr-$APR_VERSION"
patch -p1 < "$REPO_DIR/patches/apr-android.patch"

log "APR $APR_VERSION"
# configure cannot run test programs when cross-compiling, so these answers
# are supplied. They are the values the shipped builds were configured with;
# APR only tests the iovec size against zero.
CFLAGS="-fPIC $MAP_FLAGS" ./configure --host=$TARGET --prefix="$DEPS" \
    --disable-shared --enable-static --with-pic \
    ac_cv_file__dev_zero=no \
    ac_cv_func_setpgrp_void=yes \
    apr_cv_process_shared_works=yes \
    apr_cv_mutex_robust_shared=no \
    apr_cv_tcp_nodelay_with_cork=yes \
    ac_cv_sizeof_struct_iovec=8
make -j"$JOBS"
make install
require_arm64 "$DEPS/lib/libapr-1.a"
require_no_build_paths "$DEPS/lib/libapr-1.a"
