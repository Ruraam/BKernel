#!/bin/sh
# Build a removable Debian package for the exact BKernel external-module tree.
set -eu

: "${TOP_DIR:?TOP_DIR is required}"
: "${GITHUB_SHA:=unknown}"

KERNEL_RELEASE="7.3.4-zen2"
PACKAGE="bkernel-headers-7.3.4-zen2"
PACKAGE_VERSION="7.3.4-zen2-1"
ARCHITECTURE="amd64"
KERNEL_DEVEL_DIR="/bkernel/build-evidence/kernel-devel"
ARCHIVE="$KERNEL_DEVEL_DIR/bkernel-kernel-devel-$KERNEL_RELEASE-x86_64.tar.zst"
METADATA="$KERNEL_DEVEL_DIR/build-metadata.txt"
OUT_DIR="/bkernel/build-evidence/deb"
STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT HUP INT TERM

test -s "$ARCHIVE"
test -s "$METADATA"
grep -Fqx "kernel_release=$KERNEL_RELEASE" "$METADATA"
grep -Fqx "architecture=x86_64" "$METADATA"
grep -Fqx "source_commit=$GITHUB_SHA" "$METADATA"

PACKAGE_ROOT="$STAGE_DIR/package"
KERNEL_PARENT="$PACKAGE_ROOT/usr/src/$PACKAGE"
KERNEL_TREE="$KERNEL_PARENT/$TOP_DIR"
mkdir -p "$KERNEL_PARENT" "$PACKAGE_ROOT/lib/modules/$KERNEL_RELEASE"

# Extract the exact CI-tested Kbuild tree. Keep its top-level directory name.
tar -I 'zstd -d' -xf "$ARCHIVE" -C "$KERNEL_PARENT" "$TOP_DIR"

test -f "$KERNEL_TREE/Makefile"
test -s "$KERNEL_TREE/.config"
test -s "$KERNEL_TREE/Module.symvers"
test -s "$KERNEL_TREE/include/config/auto.conf"
test -s "$KERNEL_TREE/include/generated/autoconf.h"
test -s "$KERNEL_TREE/include/generated/utsrelease.h"
test -x "$KERNEL_TREE/scripts/mod/modpost"
test -x "$KERNEL_TREE/scripts/basic/fixdep"

# These links are package-owned paths, so dpkg removes them with the package.
ln -s "/usr/src/$PACKAGE/$TOP_DIR" "$PACKAGE_ROOT/lib/modules/$KERNEL_RELEASE/build"
ln -s "/usr/src/$PACKAGE/$TOP_DIR" "$PACKAGE_ROOT/lib/modules/$KERNEL_RELEASE/source"

mkdir -p "$PACKAGE_ROOT/usr/share/doc/$PACKAGE"
install -m 0644 "$METADATA" "$PACKAGE_ROOT/usr/share/doc/$PACKAGE/build-metadata.txt"
cat > "$PACKAGE_ROOT/usr/share/doc/$PACKAGE/README.Debian" <<EOF
BKernel $KERNEL_RELEASE external-module build tree
=================================================

This package installs the exact kernel source/build tree validated by BKernel CI.
It does not install or select a bootable kernel, modify /boot, create an initramfs,
change a bootloader, or install proprietary NVIDIA modules.

Build external modules with the matching LLVM toolchain, for example:

  make -C /lib/modules/$KERNEL_RELEASE/build LLVM=1 M="\$PWD" modules

The build tree is installed under /usr/src/$PACKAGE/$TOP_DIR.
The build and source links under /lib/modules/$KERNEL_RELEASE are owned by dpkg.

To remove all files belonging to this package:

  sudo apt remove $PACKAGE

This package does not include NVIDIA's proprietary driver or redistribute it.
EOF

mkdir -p "$PACKAGE_ROOT/DEBIAN"
cat > "$PACKAGE_ROOT/DEBIAN/control" <<EOF
Package: $PACKAGE
Version: $PACKAGE_VERSION
Section: kernel
Priority: optional
Architecture: $ARCHITECTURE
Maintainer: BKernel Project <noreply@localhost>
Depends: clang, lld, llvm, make, kmod, perl, python3
Description: BKernel $KERNEL_RELEASE external module build headers
 Exact configured and generated Linux kernel build tree for compiling
 third-party modules against BKernel $KERNEL_RELEASE using LLVM.
 .
 This package does not install a kernel image, modify the bootloader,
 create an initramfs, or include proprietary NVIDIA driver binaries.
EOF

DEB_FILE="$OUT_DIR/${PACKAGE}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb"
mkdir -p "$OUT_DIR"
rm -f "$DEB_FILE"
dpkg-deb --build --root-owner-group -Zxz -z6 --uniform-compression "$PACKAGE_ROOT" "$DEB_FILE"

# Validate package metadata, payload and symlink targets before publication.
dpkg-deb --info "$DEB_FILE" > "$OUT_DIR/deb-info.txt"
dpkg-deb --contents "$DEB_FILE" > "$OUT_DIR/deb-contents.txt"
test "$(dpkg-deb --field "$DEB_FILE" Package)" = "$PACKAGE"
test "$(dpkg-deb --field "$DEB_FILE" Version)" = "$PACKAGE_VERSION"
test "$(dpkg-deb --field "$DEB_FILE" Architecture)" = "$ARCHITECTURE"

VERIFY_DIR="$STAGE_DIR/verify"
mkdir -p "$VERIFY_DIR"
dpkg-deb --extract "$DEB_FILE" "$VERIFY_DIR"
test -L "$VERIFY_DIR/lib/modules/$KERNEL_RELEASE/build"
test -L "$VERIFY_DIR/lib/modules/$KERNEL_RELEASE/source"
test "$(readlink "$VERIFY_DIR/lib/modules/$KERNEL_RELEASE/build")" = "/usr/src/$PACKAGE/$TOP_DIR"
test "$(readlink "$VERIFY_DIR/lib/modules/$KERNEL_RELEASE/source")" = "/usr/src/$PACKAGE/$TOP_DIR"
test -s "$VERIFY_DIR/usr/src/$PACKAGE/$TOP_DIR/Module.symvers"
test -s "$VERIFY_DIR/usr/src/$PACKAGE/$TOP_DIR/include/generated/autoconf.h"
test -s "$VERIFY_DIR/usr/share/doc/$PACKAGE/build-metadata.txt"

install -m 0644 "$METADATA" "$OUT_DIR/build-metadata.txt"
(
    cd "$OUT_DIR"
    sha256sum "${PACKAGE}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb" build-metadata.txt deb-info.txt deb-contents.txt > SHA256SUMS
)
test -s "$OUT_DIR/SHA256SUMS"
printf 'Built and inspected %s (%s).\\n' "$DEB_FILE" "$PACKAGE_VERSION"
