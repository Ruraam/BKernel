# Build workflow

BKernel separates source identity, build-environment identity, kernel configuration and output verification. A successful build is not called reproducible until two clean builds produce matching artifacts.

## Pinned source

The initial upstream baseline is Linux 7.3.4 stable. Its official archive URL and SHA-256 are recorded in `kernel-source.toml`. The digest is cross-checked against kernel.org's signed checksum manifest; production releases must additionally verify the upstream developer signature.

Fetch and verify the source with the Rust CLI:

```sh
cd tools
cargo +1.85.1 run --locked -- source fetch ../target/sources
```

The command downloads to a temporary file, checks SHA-256 before promoting it to the cache, then extracts the archive.

## Pinned build environment

The kernel build container is defined by:
- `containers/kernel-build.Dockerfile`;
- `containers/build-environment.lock`;
- an immutable Debian OCI image digest;
- Debian Trixie package repositories frozen at snapshot `20261104T000000Z`.

Build and inspect it:

```sh
docker build --platform linux/amd64 -f containers/kernel-build.Dockerfile -t bkernel-kernel-build .
docker run --rm bkernel-kernel-build gcc --version
```

CI captures the complete installed package inventory. Any change to the base digest, Debian snapshot, package set, or Dockerfile is a reviewed build-environment change.

## Deterministic build inputs

Kernel builds must set:
- `SOURCE_DATE_EPOCH` from the source pin;
- `KBUILD_BUILD_TIMESTAMP` derived from that epoch;
- `KBUILD_BUILD_USER=bkernel`;
- `KBUILD_BUILD_HOST=reproducible`;
- `KBUILD_BUILD_VERSION=1`;
- `LC_ALL=C` and `TZ=UTC`;
- a stable source/build path or compiler prefix-map options where supported.

Every build uses a fresh output directory. A developer's existing `.config`, generated headers, object files, ccache state or host environment must never become an undeclared input.

## Kernel configuration

Start with upstream `x86_64_defconfig`, then apply small, documented BubbleOS fragments. Do not disable hardware support merely to reduce image size. The merged effective `.config` is an output artifact and must be archived with every build.

## Double-build acceptance

A release candidate must be built twice in independent clean workspaces using the same pinned inputs. Compare the kernel image, modules, DTBs, BTF and other release artifacts byte-for-byte. Differences must be investigated and explained; successful compilation alone does not prove reproducibility.

## Release artifacts

Publish and retain:
- source archive digest and provenance;
- ordered patch list and patch digests;
- effective `.config`;
- container digest and complete package inventory;
- Rust toolchain and Cargo lockfile;
- build command, environment and logs;
- output SHA-256 sums;
- `Module.symvers` and matching headers/build metadata;
- initramfs/Limine integration metadata;
- QEMU and hardware test reports.
