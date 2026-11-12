# BKernel architecture

## Principles

- Upstream-first: Linux is the kernel; BKernel is a reproducible kernel build and integration project.
- Rust-first tooling: repository-owned orchestration, manifest handling, validation and packaging tools are written in Rust.
- Minimal kernel delta: BubbleOS patches must be isolated, ordered, documented and independently reviewable.
- Compatibility before tuning: configuration changes must not casually reduce upstream driver coverage.
- Reproducibility: every build records source, patches, configuration and toolchain identities.

## Components

### Linux kernel

The kernel source is obtained from an authenticated upstream release or verified source mirror. The selected tag and full commit SHA are recorded in a machine-readable manifest before a release build is enabled.

Linux Kbuild remains responsible for compiling C, assembly and supported Rust kernel code. BKernel must not replace or bypass Kbuild.

### Rust tooling

The Rust workspace will provide:
- source and manifest validation;
- deterministic patch-series application checks;
- kernel configuration fragment validation;
- build command orchestration without inventing compiler flags;
- artifact and metadata verification;
- packaging and release manifest generation.

Rust tools are not part of the kernel's trusted boot path.

### Boot integration

Limine loads the Linux kernel using its Linux boot support and passes the configured kernel command line and initramfs. BKernel supplies documented Limine entry examples, but does not fork Limine or require a custom boot protocol.

### Packaging

The first supported artifact format is Debian `.deb`. ULPM `.lpk` packaging follows once the Debian artifact layout and install/remove/upgrade behavior are tested.

Packages must preserve the distribution's normal kernel coexistence and fallback behavior. Installing a BKernel package must not remove the currently working kernel.

## Initial platform

x86_64 is the first engineering target. BIOS and UEFI boot paths are tested separately where the selected Limine and QEMU setup support them. Additional architectures are not claimed until their configurations and boot paths are implemented and tested.
