# NVIDIA Pascal support

## Target hardware

The first hardware target is the NVIDIA GeForce GTX 1050 Ti (Pascal, GP107).
The GTX 1050 Ti is listed in NVIDIA's supported-products list for the Linux
580 driver release. The 580 driver family is the proprietary legacy branch
for Maxwell, Pascal and Volta; the newer open GPU kernel-module flavor is not
the driver path for Pascal.

References:

- NVIDIA Linux 580.76.05 official release page:
  https://www.nvidia.com/en-us/drivers/details/252613/
- Official NVIDIA archive and SHA-256:
  https://download.nvidia.com/XFree86/Linux-x86_64/580.76.05/
- NVIDIA Pascal GPU support list:
  https://nvidia.custhelp.com/app/answers/detail/a_id/5678/kw/updating
- NVIDIA open GPU kernel modules:
  https://github.com/NVIDIA/open-gpu-kernel-modules

## Driver architecture

BKernel keeps two distinct paths:

1. **Nouveau**, the in-tree upstream DRM driver, remains enabled as a modular
   fallback and for recovery.
2. **NVIDIA proprietary 580-series driver**, installed as an external module
   and rebuilt for each exact BKernel kernel release.

Do not add NVIDIA's proprietary source or binary payload to this repository.
Do not label the proprietary driver as an in-tree Linux patch. A kernel patch
is only justified if a reproducible build against the pinned kernel fails and
the incompatibility is traced to a specific upstream API change.

The proprietary module must be built against the exact BKernel build outputs:
matching kernel release, generated headers, effective .config, Module.symvers,
and compiler/toolchain metadata. CONFIG_MODVERSIONS does not provide a stable
cross-version kernel ABI.

## Kconfig fragment

Apply the fragment after the general BubbleOS desktop profile:

```sh
scripts/kconfig/merge_config.sh -m .config \
  configs/x86_64/bubbleos-desktop.config \
  configs/x86_64/nvidia-pascal.config
make LLVM=1 olddefconfig
python3 scripts/validate-nvidia-profile.py .config
```

The fragment configures Nouveau and the DRM/PCI/firmware infrastructure. It
does not claim that the proprietary NVIDIA module has been built or tested.

## Proprietary driver validation

The initial pinned target is **580.76.05** (released 2025-08-12). It is
explicitly listed by NVIDIA for the GeForce GTX 1050 Ti. The full installer
is selected rather than the `no-compat32` variant so 32-bit userspace
compatibility can be evaluated for Steam/Proton workloads.

The immutable metadata is recorded in `drivers/nvidia/version.lock`. The
official vendor SHA-256 sidecar reports:

```text
219be636b60931b021b2e8c1e0eff887363c731f8a940caa87bcc054d05d97fd  NVIDIA-Linux-x86_64-580.76.05.run
```

Before building or packaging this version:

- verify the downloaded installer against the pinned vendor SHA-256;
- record the applicable NVIDIA license and redistribution restrictions;
- extract/build the kernel module in an isolated build job;
- retain the build log and module metadata as CI evidence.

The CI must fail closed if the driver version or digest is missing or invalid.
Do not scrape a mutable "latest" URL, silently accept a changed archive, or
commit the vendor installer into Git.

The first compatibility gate is compilation of the NVIDIA kernel modules
against the exact Linux 7.3.4 + selected Zen patch-series build. A successful
compile is not proof of runtime functionality.

## Runtime test matrix

On physical GTX 1050 Ti hardware, record:

- PCI identification and firmware loading;
- module load/unload and kernel log;
- DRM/KMS modesetting and display outputs;
- OpenGL and Vulkan acceleration;
- HDMI audio;
- suspend/resume and reboot;
- Wayland compositor startup and multi-monitor operation;
- Nouveau recovery boot.

QEMU can validate the kernel build and generic DRM infrastructure, but cannot
certify a physical Pascal GPU. Do not mark this device as hardware-certified
until the physical tests have passed.

## Packaging

The future Debian and ULPM packages should contain BKernel's integration
metadata and DKMS build instructions, not redistribute NVIDIA's proprietary
installer unless the applicable license explicitly permits it. The package
must be optional and must never make the base kernel package depend on the
proprietary driver.
