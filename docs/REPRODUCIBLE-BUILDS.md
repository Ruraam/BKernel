# Reproducible builds

Reproducibility is a release requirement, not a best-effort optimization.

## Source identity

The root `kernel-source.toml` is the authoritative upstream source pin. It records:
- exact upstream release and channel;
- immutable archive URL and filename;
- SHA-256 digest;
- expected extracted top-level directory;
- fixed source-date epoch.

The initial baseline is Linux 7.3.4 stable. Its SHA-256 is taken from the kernel.org v7.x signed checksum manifest. Before changing the pin, verify the checksum manifest's OpenPGP signature against a trusted kernel maintainer key, record the verification evidence, and review the new archive digest.

Never build from a moving branch, an unversioned URL, or an archive whose digest is absent.

## Toolchain identity

- Rust tooling is pinned by `rust-toolchain.toml`.
- The Rust dependency graph is pinned by `tools/Cargo.lock`.
- Kernel compiler, assembler, linker, make, bc, flex, bison, OpenSSL, pahole and other build dependencies must be recorded with exact versions in the build manifest.
- CI runner labels alone are not a reproducible build environment. The kernel build environment must ultimately be a container or Nix derivation pinned by immutable digest/revision.
- Do not silently use whichever compiler happens to be on PATH.

## Deterministic environment

Kernel builds must export a fixed environment derived from the source/build manifest:
- `SOURCE_DATE_EPOCH`;
- `KBUILD_BUILD_TIMESTAMP`;
- `KBUILD_BUILD_USER`;
- `KBUILD_BUILD_HOST`;
- `KBUILD_BUILD_VERSION`;
- `LC_ALL=C` and `TZ=UTC`;
- a stable build path or compiler prefix-map settings where supported.

Use a clean output directory for every build. Never reuse a developer's `.config`, generated headers, object files or ccache state as an undeclared input.

## Inputs that must be archived

For each build, publish and retain:
- source archive digest and source pin;
- ordered patch list and patch digests;
- merged effective `.config`;
- Rust toolchain and Cargo lockfile;
- exact kernel build toolchain versions and environment;
- build command line and build logs;
- output artifact SHA-256 sums;
- test reports and QEMU/Limine boot results.

## Verification

A release candidate must be built twice from clean workspaces. Compare outputs with a documented reproducibility procedure. Any differing artifact must be explained; do not label the build reproducible merely because both builds succeed.

The first implementation milestone verifies source download integrity and stable Rust tooling. Full bit-for-bit kernel reproducibility is not claimed until the pinned kernel toolchain/container, configuration, timestamps and double-build comparison are implemented.
