#!/bin/bash
# Apache httpd: the static server and module archives the apps link, plus
# modules.o (with mod_axis2 registered) and buildmark.o. The tree is left in
# WORK because the app link scripts read it from there.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

fetch "httpd-$HTTPD_VERSION.tar.gz" "$HTTPD_URL" "$HTTPD_SHA256"
unpack "httpd-$HTTPD_VERSION.tar.gz" "httpd-$HTTPD_VERSION"
H=$WORK/httpd-$HTTPD_VERSION
cd "$H"

log "httpd $HTTPD_VERSION"
CFLAGS="-fPIC -I$DEPS/include -I$DEPS/include/apr-1" \
CPPFLAGS="-I$DEPS/include -I$DEPS/include/apr-1" \
LDFLAGS="-L$DEPS/lib" \
LIBS="-llog" \
ap_cv_void_ptr_lt_long=no \
ac_cv_file__dev_zero=yes \
ac_cv_func_setpgrp_void=yes \
apr_cv_process_shared_works=yes \
apr_cv_mutex_robust_shared=no \
ac_cv_sizeof_struct_iovec=16 \
./configure \
    --host=$TARGET \
    --prefix=/data/local/tmp/apache2 \
    --with-apr="$DEPS" \
    --with-apr-util="$DEPS" \
    --with-ssl="$DEPS" \
    --with-nghttp2="$DEPS" \
    --with-pcre="$DEPS/bin/pcre2-config" \
    --with-mpm=worker \
    --enable-ssl --enable-ssl-staticlib-deps \
    --enable-http2 --enable-nghttp2-staticlib-deps \
    --enable-mods-static="ssl http2 unixd authz_core log_config mime dir headers rewrite" \
    --disable-shared --enable-static \
    --without-lua --disable-brotli --disable-xml2enc --disable-proxy-html \
    --disable-cgid --disable-cgi --disable-deflate

# gen_test_char runs at build time to write test_char.h, so it must be a host
# binary. Let make build its arm64 copy, replace that with a host build, and
# touch both outputs so make does not relink the arm64 one (Error 126).
cd server
make gen_test_char >/dev/null 2>&1 || true
gcc -DCROSS_COMPILE -I../include -I../os/unix gen_test_char.c -o gen_test_char
./gen_test_char > test_char.h
touch gen_test_char test_char.h
cd ..

# -k: the support tools (htpasswd, htdigest, htdbm) need crypt(), which bionic
# lacks, and fail. Nothing links them; the archives below are checked instead.
make -k -j"$JOBS" || true

# configure writes modules.c from the modules it knows. mod_axis2 comes from
# the Axis2/C build, so register it by hand; without it httpd starts and
# Axis2/C never sees a request.
patch modules.c < "$REPO_DIR/patches/httpd-modules-axis2.patch"
[ "$(grep -c axis2_module modules.c)" = 4 ] || die "modules.c patch did not apply"
make modules.o
$(make -n -B modules.o | tail -1 | sed 's# -c modules.c$# -c server/buildmark.c#')

require_arm64 \
    server/.libs/libmain.a \
    modules/aaa/.libs/libmod_authz_core.a \
    modules/core/.libs/libmod_so.a \
    modules/http/.libs/libmod_http.a \
    modules/http/.libs/libmod_mime.a \
    modules/loggers/.libs/libmod_log_config.a \
    modules/metadata/.libs/libmod_headers.a \
    modules/ssl/.libs/libmod_ssl.a \
    modules/http2/.libs/libmod_http2.a \
    modules/arch/unix/.libs/libmod_unixd.a \
    modules/mappers/.libs/libmod_dir.a \
    modules/mappers/.libs/libmod_rewrite.a \
    server/mpm/worker/.libs/libworker.a \
    os/unix/.libs/libos.a
for o in modules.o buildmark.o; do
    file "$o" | grep -q "ARM aarch64" || die "$o is not arm64"
done
