# Sourced by build-all.sh and every steps/*.sh. Each setting below can be
# overridden from the environment, e.g. WORK=/tmp/try ./build-all.sh.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.env
. "$REPO_DIR/versions.env"

: "${NDK:=$HOME/Android/Sdk/ndk/28.0.12916984}"
: "${API:=21}"
# Source and build trees. The app link scripts read httpd's tree from here.
: "${WORK:=$HOME/android-cross-builds}"
# Install prefix: the static libraries and headers the apps link against.
: "${DEPS:=$WORK/deps/arm64-v8a}"
# Where downloaded tarballs are kept; defaults to WORK.
: "${TARBALLS:=$WORK}"
# A local Axis2/C checkout saves a clone; AXIS2C_REF must exist in it.
: "${AXIS2C_REPO:=$HOME/repos/axis-axis2-c-core}"
: "${JOBS:=$(nproc)}"

TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64
TARGET=aarch64-linux-android
# Full paths: httpd's configure reads CC back out of apr-1-config and can
# truncate a bare name.
CC=$TOOLCHAIN/bin/${TARGET}${API}-clang
CXX=$TOOLCHAIN/bin/${TARGET}${API}-clang++
AR=$TOOLCHAIN/bin/llvm-ar
RANLIB=$TOOLCHAIN/bin/llvm-ranlib
STRIP=$TOOLCHAIN/bin/llvm-strip
export CC CXX AR RANLIB STRIP

log() { printf '\n=== %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# fetch NAME URL SHA256: download into TARBALLS unless present, then verify.
fetch() {
    local name=$1 url=$2 sha=$3 file="$TARBALLS/$1"
    mkdir -p "$TARBALLS"
    if [ ! -f "$file" ]; then
        log "Downloading $name"
        curl -fL --retry 3 -o "$file.part" "$url"
        mv "$file.part" "$file"
    fi
    echo "$sha  $file" | sha256sum -c --quiet - \
        || die "$name does not match its pinned SHA-256; delete it to re-download"
}

# unpack TARBALL DIR: replace WORK/DIR with a fresh extraction, so a rebuild
# never inherits a previous configure or a half-applied patch.
unpack() {
    rm -rf "${WORK:?}/$2"
    tar -xzf "$TARBALLS/$1" -C "$WORK"
    [ -d "$WORK/$2" ] || die "$1 did not unpack to $2"
}

# require_arm64 FILE...: fail unless every archive member is aarch64 code.
require_arm64() {
    local f
    for f in "$@"; do
        [ -f "$f" ] || die "missing $f"
        "$AR" p "$f" | file - | grep -q "ARM aarch64" || die "$f is not arm64"
    done
}

[ -x "$CC" ] || die "no NDK compiler at $CC (set NDK)"
mkdir -p "$WORK" "$DEPS"
