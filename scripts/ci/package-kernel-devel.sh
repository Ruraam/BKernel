#!/bin/sh
# Package the exact configured and compiled BKernel tree for external modules.
set -eu

: "${TOP_DIR:?TOP_DIR is required}"
: "${GITHUB_SHA:=unknown}"

KERNEL_BUILD_DIR="/bkernel/.kernel-source/$TOP_DIR"
OUT_DIR="/bkernel/build-evidence/kernel-devel"
KERNEL_RELEASE="$(make -s -C "$KERNEL_BUILD_DIR" LLVM=1 ARCH=x86_64 kernelrelease)"

test -f "$KERNEL_BUILD_DIR/Makefile"
test -s "$KERNEL_BUILD_DIR/.config"
test -s "$KERNEL_BUILD_DIR/Module.symvers"
test -s "$KERNEL_BUILD_DIR/include/config/auto.conf"
test -s "$KERNEL_BUILD_DIR/include/generated/autoconf.h"
test -s "$KERNEL_BUILD_DIR/include/generated/utsrelease.h"
test -d "$KERNEL_BUILD_DIR/arch/x86/include/generated"
test -x "$KERNEL_BUILD_DIR/scripts/mod/modpost"
test -x "$KERNEL_BUILD_DIR/scripts/basic/fixdep"
test "$KERNEL_RELEASE" = "7.3.4-zen2"

# Verify that the packaged tree can build a third-party module. This is a
# compile/modpost test only; the module is never loaded on the CI runner.
SMOKE_DIR="$(mktemp -d)"
trap 'rm -rf "$SMOKE_DIR"' EXIT HUP INT TERM
cat > "$SMOKE_DIR/Makefile" <<'MAKE'
obj-m += bkernel_devel_smoke.o
MAKE
cat > "$SMOKE_DIR/bkernel_devel_smoke.c" <<'C'
#include <linux/init.h>
#include <linux/module.h>

static int __init bkernel_devel_smoke_init(void)
{
    pr_info("BKernel external-module build smoke test\\n");
    return 0;
}

static void __exit bkernel_devel_smoke_exit(void)
{
}

module_init(bkernel_devel_smoke_init);
module_exit(bkernel_devel_smoke_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("BKernel kernel-devel packaging smoke test");
C

make -C "$KERNEL_BUILD_DIR" LLVM=1 ARCH=x86_64 M="$SMOKE_DIR" modules
test -s "$SMOKE_DIR/bkernel_devel_smoke.ko"
modinfo -F vermagic "$SMOKE_DIR/bkernel_devel_smoke.ko" | grep -F "$KERNEL_RELEASE"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
cat > "$OUT_DIR/build-metadata.txt" <<EOF
schema=1
kernel_release=$KERNEL_RELEASE
architecture=x86_64
source_version=7.3.4
source_archive=linux-7.3.4.tar.xz
source_sha256=b11b6df8295e8e991ff040b71aaa4994a8b55caa23b6b092907f195b5840fd1f
source_commit=$GITHUB_SHA
profile=configs/x86_64/nvidia-pascal.config
nvidia_profile_sha256=$(sha256sum /bkernel/configs/x86_64/nvidia-pascal.config | awk '{print $1}')
desktop_profile_sha256=$(sha256sum /bkernel/configs/x86_64/bubbleos-desktop.config | awk '{print $1}')
kernel_source_lock_sha256=$(sha256sum /bkernel/kernel-source.toml | awk '{print $1}')
zen_source_lock_sha256=$(sha256sum /bkernel/zen-source.toml | awk '{print $1}')
nvidia_lock_sha256=$(sha256sum /bkernel/drivers/nvidia/version.lock | awk '{print $1}')
nvidia_patch_lock_sha256=$(sha256sum /bkernel/drivers/nvidia/patches.lock | awk '{print $1}')
applied_patch_manifest_sha256=$(sha256sum /bkernel/build-evidence/nvidia-patches.manifest | awk '{print $1}')
compiler=$(clang --version | head -n 1)
linker=$(ld.lld --version | head -n 1)
llvm_ar=$(llvm-ar --version | head -n 1)
rustc=$(rustc --version)
config_sha256=$(sha256sum "$KERNEL_BUILD_DIR/.config" | awk '{print $1}')
module_symvers_sha256=$(sha256sum "$KERNEL_BUILD_DIR/Module.symvers" | awk '{print $1}')
external_module_smoke_test=passed
external_module_vermagic=$(modinfo -F vermagic "$SMOKE_DIR/bkernel_devel_smoke.ko")
EOF

# Preserve the complete source/build tree: this intentionally favors a
# reliable external-module Kbuild environment over a fragile header-only
# subset. Proprietary NVIDIA sources are extracted under /tmp, not here.
ARCHIVE="$OUT_DIR/bkernel-kernel-devel-$KERNEL_RELEASE-x86_64.tar.zst"
tar --numeric-owner --owner=0 --group=0 -C "$(dirname "$KERNEL_BUILD_DIR")" \
    -I 'zstd -T0 -10' -cf "$ARCHIVE" "$TOP_DIR"

# Read the complete compressed archive back and assert that all external
# Kbuild prerequisites are present in the published payload.
tar -I 'zstd -d' -tf "$ARCHIVE" > "$OUT_DIR/archive.inventory"
grep -Fqx "$TOP_DIR/.config" "$OUT_DIR/archive.inventory"
grep -Fqx "$TOP_DIR/Module.symvers" "$OUT_DIR/archive.inventory"
grep -Fqx "$TOP_DIR/include/config/auto.conf" "$OUT_DIR/archive.inventory"
grep -Fqx "$TOP_DIR/include/generated/autoconf.h" "$OUT_DIR/archive.inventory"
grep -Fqx "$TOP_DIR/include/generated/utsrelease.h" "$OUT_DIR/archive.inventory"
grep -Fqx "$TOP_DIR/scripts/mod/modpost" "$OUT_DIR/archive.inventory"
grep -Fqx "$TOP_DIR/scripts/basic/fixdep" "$OUT_DIR/archive.inventory"
rm -f "$OUT_DIR/archive.inventory"

(
    cd "$OUT_DIR"
    sha256sum build-metadata.txt "bkernel-kernel-devel-$KERNEL_RELEASE-x86_64.tar.zst" > SHA256SUMS
)

test -s "$OUT_DIR/SHA256SUMS"
printf 'Packaged kernel-devel for %s; external-module smoke test passed.\\n' "$KERNEL_RELEASE"
