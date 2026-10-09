# Security Threat Model — Kanaha Android Deps

## Project Description

Kanaha Android Deps is a set of shell scripts. They download, patch and
cross-compile the native libraries that the Kanaha Android apps (camera, audio
and calcs) link statically into their server binary:

- Apache httpd with mod_ssl and mod_http2
- Apache Axis2/C with mod_axis2
- OpenSSL, nghttp2, APR, APR-util, expat, PCRE2 and json-c

Nothing in this repository runs on a phone. What it produces does: every
library it builds ends up inside each app's network-facing, mutual-TLS server.
A flaw here therefore ships in all three apps at once.

| Component | Pinned | Role in the apps |
|---|---|---|
| Apache httpd | 2.4.69 | HTTP server, mod_ssl + mod_http2 |
| OpenSSL | 3.5.9 | TLS 1.2+/1.3, mutual authentication |
| nghttp2 | 1.64.0 | HTTP/2 framing |
| Axis2/C | pinned commit | Service engine, JSON-RPC dispatch |
| json-c | 0.18 | JSON parsing of every request |
| APR / APR-util | 1.7.6 / 1.6.3 | httpd runtime |
| PCRE2 | 10.44 | httpd regular expressions |
| expat | 2.9.0 | Linked in through APR-util; no Kanaha code path parses XML with it |

## Roles and Trust Levels

| Role | Trust Level | Description |
|---|---|---|
| **Maintainer** | Fully trusted | Edits the pinned versions, checksums and patches, and runs the build. |
| **Build host** | Fully trusted | Runs the scripts, the NDK and the host compilers. A compromised build host compromises every app, and this project cannot detect it. |
| **Upstream projects** | Trusted for their own code | OpenSSL, Apache, nghttp2 and the others. Their releases are taken as published. |
| **Download hosts and network** | Untrusted | GitHub release assets, archive.apache.org, and the network path to them. Every download is checked against a SHA-256 pinned in `versions.env` before it is unpacked. |
| **App repositories** | Consumers | They link whatever is in the install prefix. They do not rebuild or re-verify it. |

## Security Boundaries

### What IS a security issue

- **A download that is used without matching its pinned checksum.** This
  includes a code path in `lib.sh`'s `fetch` that skips verification, a step
  that unpacks a tarball it did not fetch, and a checksum taken from the
  download itself instead of from the upstream release.
- **A pinned version with a known vulnerability that affects the apps.** The
  apps ship these libraries statically, so an upstream fix reaches no phone
  until the pin is raised, this build is rerun and the apps are relinked. A pin
  below the minimums in [Dependency Security](#dependency-security) is a
  finding.
- **A patch or configure change that weakens what ships.** Examples: a patch
  in `patches/` that touches anything beyond its stated Android fix; enabling
  an httpd module the apps do not use, since every static module becomes
  reachable code in all three servers; disabling an OpenSSL protection; or
  pulling in a feature such as `--enable-cgi` or `mod_proxy`.
- **A build that reports success while producing the wrong output.** Step 08
  runs `make -k` because httpd's support tools cannot build on Android. That
  makes the explicit archive checks the only guard against a missing or
  host-built library. Removing or loosening those checks, or `require_arm64`,
  is a finding.
- **Axis2/C built from something other than the pinned commit.** That includes
  building from a working tree instead of `git archive` of `AXIS2C_REF`, and a
  ref that names a branch rather than a commit.
- **Unsafe shell.** That covers an unguarded `rm -rf` on a variable that can be
  empty, unquoted paths that break on spaces, and a step that keeps going after
  a failed command (every step runs under `set -euo pipefail`).

### What is NOT a security issue

- **Vulnerabilities in an upstream library's own code.** Report those
  upstream. Report here only if this repository pins a version that is known
  to be affected, or configures or patches the library unsafely.
- **The build host itself.** Securing the machine, the NDK installation and
  the host toolchain is outside this repository's scope.
- **Build paths embedded in the libraries.** OpenSSL compiles its install
  prefix into `libcrypto.a` as `OPENSSLDIR` and `ENGINESDIR`, and that prefix
  is a path on the build host. No such directory exists on a phone, and
  creating one outside an app's own storage requires root. The apps point
  mod_ssl at their certificates explicitly. The path is visible in the shipped
  binary.
- **The configure answers in steps 05 and 08.** These are the
  cross-compilation answers, such as `ac_cv_sizeof_struct_iovec`. They match
  the builds that shipped, and APR only tests the iovec size against zero.
  Report one only if it changes generated code in a way that matters for
  safety.
- **Network denial of service, request parsing, TLS policy and certificates.**
  Each app enforces these in its own configuration. See that app's
  `SECURITY.md`.

## Architecture and Attack Surface

### Build flow

```
versions.env  (version, URL, SHA-256; Axis2/C commit)
     │
     ▼
lib.sh fetch ──► download if absent ──► sha256sum -c ──► fail closed
     │
     ▼
lib.sh unpack ──► delete the old tree, extract fresh
     │
     ▼
steps/01..09 ──► patch (APR, httpd modules.c) ──► configure ──► make
     │                                                  │
     │                                     require_arm64 on every output
     ▼
$DEPS/lib, $DEPS/include, $WORK/httpd-<v>, $DEPS/BUILD-INFO
     │
     ▼
each app's link script ──► one static server binary per app
```

### Attack surface by component

| File | Exposure | Notes |
|---|---|---|
| `versions.env` | Supply chain | The single source of every version, URL and checksum. A changed checksum deserves the same scrutiny as a changed version. |
| `lib.sh` | Supply chain | `fetch` verifies on every run, including when the tarball is already cached. `unpack` refuses an archive that does not unpack to the expected directory. |
| `patches/*.patch` | Code that ships | Small Android portability fixes to APR, and the mod_axis2 registration in httpd's `modules.c`. |
| `steps/08-httpd.sh` | Code that ships | Chooses the static module set, which defines every server's surface. It also runs a host-built `gen_test_char`, and checks its archives because it uses `make -k`. |
| `steps/09-axis2c.sh` | Code that ships | Exports `AXIS2C_REF` with `git archive`, and copies only arm64 archives into the prefix. |

## Dependency Security

These minimums follow Apache Axis2/C's own
[minimum secure versions](https://github.com/apache/axis-axis2-c-core/blob/master/docs/SECURITY.md).
When that table is raised, raise the pin here.

| Component | Minimum | Reason |
|---|---|---|
| OpenSSL | 3.5.9 | 3.5 LTS; the September 2026 fixes. 3.0 and 3.2 no longer receive fixes. |
| Apache httpd | 2.4.68 | HTTP/2 double-free (2.4.67) and the mod_http2 fixes (2.4.68) |
| nghttp2 | 1.61.0 | CONTINUATION-frame DoS (CVE-2024-28182) |
| json-c | 0.18 | CVE-2020-12762 integer overflow |

After raising a pin: rebuild with `./build-all.sh`, then relink, rebuild and
release every app. Until an app is released, its users still run the old
library.

## Reporting Security Issues

**Do not open a public issue for a security vulnerability.**

Report privately through GitHub's security advisory form on this repository
(*Security* → *Report a vulnerability*). That opens a private thread visible
only to the maintainer.

Please include:

- The affected script, patch or pinned version
- What ships differently because of it, and which apps are affected
- Steps to reproduce, if it is a build behaviour

Expect an initial response within a few days. This is a personal project rather
than a funded one, so please allow reasonable time for a fix before public
disclosure. Credit will be given in the release notes unless you prefer
otherwise.
