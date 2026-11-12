# BKernel

BKernel is the Linux kernel distribution and integration layer for BubbleOS.

Its primary objective is to provide a BubbleOS-tuned Linux kernel while preserving the broad hardware, driver, userspace, and boot compatibility of upstream Linux.

## Core design decision

BKernel is **not a ground-up kernel rewrite**. It tracks upstream Linux and carries a small, reviewable set of BubbleOS-specific patches and configuration profiles.

Rust is the first-class implementation language for BKernel's own tooling and new eligible kernel components. The upstream kernel remains a mixed C, assembly, and Rust codebase; the Linux build system and supported compiler toolchain remain authoritative for building the kernel itself.

## Compatibility priorities

1. Preserve upstream Linux hardware support and driver coverage.
2. Keep upstream interfaces and userspace behavior wherever possible.
3. Avoid unnecessary configuration reductions and out-of-tree patches.
4. Support external modules through matching headers, configuration, symbol versions, and build metadata.
5. Boot through Limine using its Linux boot protocol, with a tested initramfs and documented kernel command line.
6. Keep a known-good fallback kernel and a recoverable boot entry.
7. Make every compatibility claim traceable to a test, upstream guarantee, or documented limitation.

Absolute binary compatibility cannot be promised across arbitrary kernel versions, architectures, configurations, or third-party modules. In particular, Linux does not promise a stable in-kernel driver ABI. BKernel therefore targets maximum practical compatibility and explicit regression testing, not an impossible universal ABI guarantee.

## Initial scope

- Architecture: x86_64 first.
- Kernel source: unmodified upstream Linux baseline, pinned to an explicit stable release and commit.
- Boot: Limine, UEFI and BIOS where supported by the selected platform and kernel configuration.
- Build: upstream Linux Kbuild; Rust-based orchestration and validation tools.
- Packaging: Debian packages first; ULPM LPK as a second delivery format.
- Testing: configuration validation, build checks, module smoke tests, QEMU boot tests, and hardware testing before release.

## Repository layout

```text
.
├── .github/workflows/       # CI pipelines
├── config/                  # versioned kernel configuration fragments
├── docs/                    # architecture, compatibility and release policy
├── patches/                 # minimal, ordered BubbleOS patches
├── scripts/                 # bootstrap and developer helpers
├── tools/bkernel/           # Rust workspace for orchestration and validation
└── packaging/               # Debian and LPK packaging metadata
```

The upstream Linux source tree is not vendored into this repository. Builds fetch or use a separately verified source checkout at the exact revision recorded by the build manifest.

## Non-goals

- Replacing Linux with a new microkernel or hobby kernel.
- Reimplementing existing Linux drivers in Rust.
- Claiming a stable binary ABI for arbitrary third-party kernel modules.
- Applying performance tweaks that silently remove hardware support.
- Requiring Limine-specific changes to upstream Linux when the standard Linux boot protocol is sufficient.

## Project status

The repository is at its initial architecture/scaffolding stage. No kernel release, supported hardware matrix, or compatibility certification is claimed yet.
