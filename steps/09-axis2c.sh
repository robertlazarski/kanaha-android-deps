#!/bin/bash
# Axis2/C at AXIS2C_REF, built from a clean export so neither a local
# checkout's state nor this build touches the other. Needs httpd's tree for
# mod_axis2.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

SRC=$WORK/axis2c-src-${AXIS2C_REF:0:9}
H=$WORK/httpd-$HTTPD_VERSION
[ -f "$H/include/httpd.h" ] || die "run steps/08-httpd.sh first"

if git -C "$AXIS2C_REPO" cat-file -e "$AXIS2C_REF^{commit}" 2>/dev/null; then
    GIT_DIR_ARGS=(-C "$AXIS2C_REPO")
else
    log "Fetching Axis2/C $AXIS2C_REF"
    rm -rf "$WORK/axis2c.git"
    git clone --bare --filter=blob:none "$AXIS2C_GIT" "$WORK/axis2c.git"
    GIT_DIR_ARGS=(--git-dir="$WORK/axis2c.git")
fi
rm -rf "$SRC" && mkdir -p "$SRC"
git "${GIT_DIR_ARGS[@]}" archive "$AXIS2C_REF" | tar -x -C "$SRC"
cd "$SRC"

log "Axis2/C ${AXIS2C_REF:0:9}"
./autogen.sh
CFLAGS="-fPIC -I$DEPS/include -I$DEPS/include/apr-1 -I$H/include -I$DEPS/include/json-c" \
CPPFLAGS="-I$DEPS/include -I$DEPS/include/apr-1 -I$H/include -I$DEPS/include/json-c" \
LDFLAGS="-L$DEPS/lib" \
LIBS="-lapr-1 -laprutil-1 -lexpat -lssl -lcrypto -lnghttp2 -ljson-c -llog" \
./configure \
    --host=$TARGET \
    --prefix="$DEPS" \
    --with-apr="$DEPS" \
    --with-apache2="$H" \
    --with-openssl="$DEPS" \
    --enable-json --enable-http2 \
    --enable-static --disable-shared
make -j"$JOBS"

# Install by copying, not make install: the apps link the static archives and
# read headers from one flat directory. Only arm64 archives are copied, so a
# stray host-built archive cannot replace a cross-built one.
find . -name '*.a' -path '*/.libs/*' | while read -r f; do
    if "$AR" p "$f" | file - | grep -q "ARM aarch64"; then
        cp "$f" "$DEPS/lib/"
    else
        echo "skipped non-arm64: $f"
    fi
done
INC=$DEPS/include/axis2-2.0.0
mkdir -p "$INC/platforms/unix"
cp include/*.h util/include/*.h axiom/include/*.h guththila/include/*.h \
   neethi/include/*.h "$INC/"
cp util/include/platforms/unix/*.h "$INC/platforms/unix/"
require_arm64 "$DEPS/lib/libaxis2_engine.a" "$DEPS/lib/libmod_axis2.a" "$DEPS/lib/libaxutil.a"
