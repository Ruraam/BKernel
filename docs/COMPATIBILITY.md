# Compatibility policy

BKernel's compatibility contract is to stay as close to upstream Linux as possible.

## Compatibility layers

| Layer | Policy |
|---|---|
| Hardware discovery | Preserve upstream buses, IDs, firmware interfaces and discovery paths. |
| In-tree drivers | Do not disable driver families without measured evidence and an explicit decision. |
| External modules | Ship the exact build configuration and generated headers for each kernel build. |
| Module versioning | Enable `CONFIG_MODVERSIONS` where supported by the selected configuration; retain the matching `Module.symvers`. |
| Userspace | Preserve standard Linux syscalls, device nodes, uevents, procfs, sysfs and netlink behavior. |
| Boot | Test Limine's Linux boot path, initramfs handoff, command line and fallback entry. |
| Power management | Retain upstream ACPI, CPU frequency, suspend/resume and platform driver support. |

## ABI reality

Linux intentionally does not promise a stable internal kernel ABI for third-party modules. A module built for one kernel release/configuration may not load on another. Symbol versioning detects some mismatches; it does not turn the internal ABI into a stable one.

For every published kernel build, retain:
- exact upstream source commit and patch series;
- complete effective kernel configuration;
- kernel release string and compiler/toolchain versions;
- generated headers and `Module.symvers`;
- build logs and test results.

DKMS modules must be rebuilt against the exact target kernel headers. Do not advertise cross-version binary module compatibility.

## Configuration rules

- Start from the upstream architecture defaults.
- Apply small, named configuration fragments.
- Do not use `localmodconfig` as a release baseline: it can remove support for hardware not currently attached.
- Preserve broad storage, filesystem, network, input, USB, sound, GPU, virtualization and firmware support.
- Record every intentional deviation from upstream defaults.
- Reject unknown or silently ignored Kconfig symbols in validation.

## Release gates

A release candidate must pass:
1. configuration generation and consistency checks;
2. kernel build for every declared target profile;
3. module metadata/header artifact checks;
4. initramfs generation and inspection;
5. Limine boot test in QEMU for supported firmware modes;
6. basic userspace, storage, network and input smoke tests;
7. regression comparison against the previous supported BKernel release.

Hardware compatibility claims must name the tested device, firmware, kernel configuration and test result. QEMU success is not proof of physical hardware compatibility.
