# kanaha-android-deps

Builds the native dependencies shared by the Kanaha Android apps
([kanaha](https://github.com/robertlazarski/kanaha) camera,
[kanaha-audio](https://github.com/robertlazarski/kanaha-audio) and
[kanaha-calcs](https://github.com/robertlazarski/kanaha-calcs)): Apache httpd
with mod_ssl, mod_http2 and Apache Axis2/C's mod_axis2, and the libraries under
them. Everything is static, for arm64-v8a, built with NDK r28 at API 21.

Each app links its own service code against this output into one executable,
`httpd`, that its Java side starts as a child process.

## What it builds

| Step | Version | Why the apps need it |
|---|---|---|
| OpenSSL | 3.5.9 | TLS and client certificates, for mod_ssl and Axis2/C |
| nghttp2 | 1.64.0 | HTTP/2, for mod_http2 and Axis2/C's HTTP/2 client |
| expat | 2.9.0 | Linked only because APR-util's XML code is pulled in by httpd's exports table |
| PCRE2 | 10.44 | httpd's regular expressions |
| APR | 1.7.6 | httpd's portability layer; two Android patches in `patches/` |
| APR-util | 1.6.3 | httpd's utility layer |
| json-c | 0.18 | Axis2/C's JSON-RPC message receiver |
| httpd | 2.4.69 | the server, with the modules linked in statically |
| Axis2/C | a pinned commit | the web-service engine and mod_axis2 |

Versions, download URLs, SHA-256 sums and the Axis2/C commit are pinned in
[`versions.env`](versions.env).

Libraries only one app uses are built by that app's repository. For example,
whisper.cpp, TensorFlow Lite, flite, libltc and libssh2 belong to kanaha-audio.

## Building

You need Linux x86_64 with:

- Android NDK 28.0.12916984
- gcc, for one host tool httpd builds during its build
- make, cmake, autoconf, automake, libtool, perl, curl and git

To build everything:

```bash
./build-all.sh
```

The steps run in order, and each one can be run again on its own:

```bash
bash steps/09-axis2c.sh
```

The Axis2/C step needs the httpd tree, so run step 08 first. Each step unpacks
a fresh copy of its source, so a rebuild never inherits an earlier configure
run.

These settings are read from the environment:

| Variable | Default | |
|---|---|---|
| `NDK` | `~/Android/Sdk/ndk/28.0.12916984` | |
| `API` | `21` | minimum Android API level |
| `WORK` | `~/android-cross-builds` | source and build trees |
| `DEPS` | `$WORK/deps/arm64-v8a` | install prefix: `lib/` and `include/` |
| `TARBALLS` | `$WORK` | where downloads are kept |
| `AXIS2C_REPO` | `~/repos/axis-axis2-c-core` | a local checkout to export from; it is cloned if the pinned commit is not in it |

## What the apps read

- **`$DEPS/lib` and `$DEPS/include`**: the static libraries and headers. The
  Axis2/C headers are in one flat directory, `include/axis2-2.0.0`.
- **`$WORK/httpd-<version>`**: the httpd build tree. The apps link its server
  and module archives, plus `modules.o` and `buildmark.o`.
  - `modules.o` lists the modules compiled into httpd. This build adds
    mod_axis2 to it with `patches/httpd-modules-axis2.patch`. Without that
    patch, httpd starts normally but never passes a request to Axis2/C.
- **`$DEPS/BUILD-INFO`**: written at the end of `build-all.sh`. It records this
  repository's commit and every pinned version.

## Upgrading a dependency

1. Change its version and SHA-256 in `versions.env`. Take the SHA-256 from the
   upstream release, not from your own download.
2. Run `./build-all.sh`. Every step after a changed library has to rerun
   anyway, because later libraries are configured against it.
3. Relink and test each app.

The patches in `patches/` apply to the versions pinned here. A step fails if
its patch no longer applies.

## Cross-compiling notes

The comments in each step script explain its workarounds. The three most
likely to catch you out are:

- **httpd's `gen_test_char` must run on the build host.** Step 08 replaces the
  arm64 copy with a host build. Without that, make relinks the arm64 copy and
  stops with `Error 126`.
- **httpd's support tools fail to build.** htpasswd and its siblings need
  `crypt()`, which bionic lacks. Step 08 builds with `make -k` and then checks
  that every archive the apps link was produced.
- **Everything must be static.** Android apps cannot `dlopen` an Axis2/C
  service from a deployment directory. Each app's link step registers its
  service in Axis2/C's static service registry instead.

## License

Apache License 2.0; see [LICENSE](LICENSE). The libraries these scripts
download and build are under their own licenses.
