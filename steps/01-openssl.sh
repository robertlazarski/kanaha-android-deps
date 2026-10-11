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
# The prefix is compiled in as OPENSSLDIR, ENGINESDIR and MODULESDIR, so
# configure with the neutral one and install through a staging directory.
# MAP_FLAGS is not passed: OpenSSL already compiles with relative paths, and
# it embeds its compiler flags (openssl version -a), so the flag would itself
# put WORK back into the library.
STAGE=$WORK/openssl-$OPENSSL_VERSION-stage
rm -rf "${STAGE:?}"
env -u CC -u CXX -u AR -u RANLIB ./Configure android-arm64 \
    --prefix="$NEUTRAL_PREFIX" --openssldir="$NEUTRAL_PREFIX/ssl" --libdir=lib \
    -D__ANDROID_API__="$API" no-shared no-tests
env -u CC -u CXX -u AR -u RANLIB make -j"$JOBS"
env -u CC -u CXX -u AR -u RANLIB make install_sw DESTDIR="$STAGE"
cp -a "$STAGE$NEUTRAL_PREFIX/." "$DEPS/"
rm -rf "${STAGE:?}"
# CMake's config locates itself; pkg-config's files need the real prefix.
sed -i "s|^prefix=.*|prefix=$DEPS|" "$DEPS"/lib/pkgconfig/{libssl,libcrypto,openssl}.pc
require_arm64 "$DEPS/lib/libssl.a" "$DEPS/lib/libcrypto.a"
require_no_build_paths "$DEPS/lib/libssl.a" "$DEPS/lib/libcrypto.a"
