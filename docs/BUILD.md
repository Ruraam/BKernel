# Build workflow

This document describes the intended workflow. The repository does not yet pin a Linux release, so a complete kernel build is intentionally not enabled.

## Prerequisites

- Rust toolchain (stable) for BKernel tools;
- Git;
- the build dependencies documented by the selected upstream Linux release;
- a supported C compiler, assembler, linker and kernel build utilities;
- QEMU for virtual boot testing;
- Limine and an initramfs generator for integration testing.

The exact dependency list will be pinned per CI image and release profile.

## Current checks

Run the Rust workspace checks from the repository root:

```sh
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
```

## Planned kernel build

A kernel build becomes reproducible only after `kernel-source.toml` records:
- upstream repository URL;
- release tag;
- full commit SHA;
- supported architecture/profile;
- patch-series digest;
- configuration-fragment digest.

Do not build from a moving branch such as `master` or `stable` without pinning the resolved commit.

## Build outputs

Each release build will publish:
- kernel image and matching modules;
- headers/build metadata needed for external modules;
- `Module.symvers` when applicable;
- initramfs integration metadata;
- effective `.config`;
- source/patch/toolchain manifest;
- checksums and signature metadata;
- test reports.
