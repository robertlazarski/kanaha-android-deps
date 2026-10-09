#!/bin/bash
# OpenSSL: libssl.a and libcrypto.a, static, for mod_ssl and Axis2/C.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

fetch "openssl-$OPENSSL_VERSION.tar.gz" "$OPENSSL_URL" "$OPENSSL_SHA256"
unpack "openssl-$OPENSSL_VERSION.tar.gz" "openssl-$OPENSSL_VERSION"
cd "$WORK/openssl-$OPENSSL_VERSION"

log "OpenSSL $OPENSSL_VERSION"
# OpenSSL's android targets read ANDROID_NDK_ROOT and want bare tool names on
# PATH, so unset the full-path CC the other steps use.
export ANDROID_NDK_ROOT=$NDK
export PATH=$TOOLCHAIN/bin:$PATH
env -u CC -u CXX -u AR -u RANLIB ./Configure android-arm64 \
    --prefix="$DEPS" --libdir=lib -D__ANDROID_API__="$API" no-shared no-tests
env -u CC -u CXX -u AR -u RANLIB make -j"$JOBS"
env -u CC -u CXX -u AR -u RANLIB make install_sw
require_arm64 "$DEPS/lib/libssl.a" "$DEPS/lib/libcrypto.a"
