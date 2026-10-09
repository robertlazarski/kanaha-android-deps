# AGENTS.md — Kanaha Android Deps

## Security Threat Model

See [SECURITY.md](SECURITY.md) for the full threat model: roles and trust
levels, what is and is not a security issue, the build flow, and how to report
a vulnerability.

## What this is

This repository is **build scripts only**, with no application code. It
cross-compiles Apache httpd, Axis2/C, OpenSSL, nghttp2, APR, APR-util, expat,
PCRE2 and json-c as static arm64 Android libraries. The three Kanaha apps
(camera, audio, calcs) link them into their network-facing server binaries.

The security-relevant consequences:

- A change here ships in **all three apps at once**.
- The risk is **supply chain and build integrity**: what gets downloaded, what
  gets patched, which features are compiled in, and whether a failed build can
  look like a successful one.
- There is no request parsing or runtime behaviour to scan here.

## Highest-value scan areas

### 1. Download verification

`fetch` in `lib.sh` must verify the pinned SHA-256 **every time**, including
when the tarball is already cached, and must fail before anything is unpacked.

Check for:

- a step that bypasses `fetch`
- a URL changed without its checksum
- a checksum that looks like it came from a local download rather than the
  upstream release

Key files: `lib.sh`, `versions.env`

### 2. Version pins against known CVEs

Compare each pin in `versions.env` with the minimums in `SECURITY.md` and with
Apache Axis2/C's `docs/SECURITY.md`. A downgrade, or a pin left below a newly
published fix, is the most likely real finding in this repository.

### 3. What gets compiled in

`steps/08-httpd.sh` fixes the static module list with
`--enable-mods-static`. Every module listed there is reachable code in every
app's server, so a module added without a need is a finding. Likewise:

- an OpenSSL `Configure` option that weakens TLS
- an httpd feature that runs code, such as CGI, proxying or Lua

### 4. Patches

Each patch in `patches/` should do exactly what its step's comment says:

- `apr-android.patch` is two preprocessor conditions (bionic's `union semun`
  and XSI `strerror_r`).
- `httpd-modules-axis2.patch` adds `axis2_module` to `modules.c` in four
  places.

Anything more is a finding.

### 5. Failures that look like success

Step 08 runs `make -k || true`, because httpd's support tools cannot build
without `crypt()`. The explicit `require_arm64` list after it is therefore the
only check that the server archives were built. Verify that:

- the list still covers every archive the apps link
- `require_arm64` still fails on a missing file and on a non-arm64 archive
- no new `|| true` appears. The only other one is step 08's first
  `make gen_test_char`, whose output is overwritten by the host build on the
  next line.

### 6. Shell safety

Every script runs under `set -euo pipefail`. Check that:

- `rm -rf` targets are guarded against an empty variable (`${WORK:?}`)
- paths are quoted
- `steps/09-axis2c.sh` exports `AXIS2C_REF` with `git archive` rather than
  building from a working tree

## Project structure

```
versions.env        Pinned versions, URLs, SHA-256 sums, Axis2/C commit
lib.sh              Settings, fetch/verify, unpack, require_arm64
build-all.sh        Runs steps/ in order, writes $DEPS/BUILD-INFO
steps/01-openssl.sh .. 09-axis2c.sh   One dependency each
patches/            apr-android.patch, httpd-modules-axis2.patch
```

## Testing

A build-script change is verified by its output, not by reading it:

1. Build into a scratch directory, leaving the live prefix alone:
   `WORK=/tmp/deps-try TARBALLS=~/android-cross-builds ./build-all.sh`
2. Compare the exported symbols of each archive with the live prefix, using
   `llvm-nm --defined-only -g`. An unexpected difference is a finding to
   explain.
3. Relink at least one app against the scratch prefix, and confirm on a phone
   that the server still negotiates HTTP/2 over mTLS.

## Reporting

Report vulnerabilities privately through GitHub's security advisory form on this
repository. Do not open a public issue. See [SECURITY.md](SECURITY.md).
