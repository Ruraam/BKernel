#!/bin/sh
# Execute the BKernel NVIDIA compatibility build inside the pinned toolchain image.
set -eu
          dump_mount_state() {
            label="$1"
            printf "\n===== BKernel mount diagnostic: %s =====\n" "$label"
            printf "cwd: "; pwd -P 2>&1 || true
            printf "root: "; stat -c "%d:%i %n" / 2>&1 || true
            printf "workspace: "; stat -c "%d:%i %n" /bkernel 2>&1 || true
            printf "evidence: "; stat -c "%d:%i %n" /bkernel/build-evidence 2>&1 || true
            printf "manifest: "; stat -c "%d:%i %s bytes %n" /bkernel/build-evidence/nvidia-patches.manifest 2>&1 || true
            printf "mountinfo entries (complete):\n"
            cat /proc/self/mountinfo 2>&1 || true
            printf "proc mounts for workspace/temp:\n"
            grep -E " /bkernel( |/)| /tmp( |/)" /proc/mounts 2>&1 || true
            printf "filesystem capacity:\n"
            df -hT / /bkernel /tmp 2>&1 || true
            printf "inode capacity:\n"
            df -i / /bkernel /tmp 2>&1 || true
            printf "relevant environment:\n"
            env | sort | grep -E "^(HOME|PWD|OLDPWD|TOP_DIR|NVIDIA_|PATH|TMPDIR)=" || true
            if command -v findmnt >/dev/null 2>&1; then
              findmnt -T /bkernel 2>&1 || true
              findmnt -T /bkernel/build-evidence 2>&1 || true
            fi
            printf "top-level entries:\n"
            ls -lad /bkernel /bkernel/.kernel-source /bkernel/build-evidence 2>&1 || true
            printf "workspace listing:\n"
            ls -la /bkernel 2>&1 | head -100 || true
            printf "evidence listing:\n"
            ls -lah /bkernel/build-evidence 2>&1 | head -150 || true
            printf "============================================\n"
          }
          trap 'rc=$?; dump_mount_state "container exit status=$rc"; exit "$rc"' EXIT
          dump_mount_state "container start"
          KERNEL_BUILD_DIR="/bkernel/.kernel-source/$TOP_DIR"
          KERNEL_BUILD_DIR="$(readlink -f "$KERNEL_BUILD_DIR")"
          printf "Kernel source directory: <%s>\n" "$KERNEL_BUILD_DIR"
          test -f "$KERNEL_BUILD_DIR/Makefile"
          make LLVM=1 ARCH=x86_64 allmodconfig
          python3 /bkernel/scripts/validate-hardware-coverage.py .config --report /bkernel/build-evidence/hardware-coverage.txt
          cp .config /bkernel/build-evidence/allmodconfig.config

          # Validate the Pascal/Nouveau profile separately from allmodconfig.
          make LLVM=1 rustavailable
          make LLVM=1 ARCH=x86_64 x86_64_defconfig
          scripts/kconfig/merge_config.sh -m .config \
            /bkernel/configs/x86_64/bubbleos-desktop.config \
            /bkernel/configs/x86_64/nvidia-pascal.config
          make LLVM=1 ARCH=x86_64 olddefconfig
          grep -qx 'CONFIG_RUST=y' .config
          python3 /bkernel/scripts/validate-nvidia-profile.py .config
          make LLVM=1 ARCH=x86_64 modules_prepare

          # Compile the complete kernel image and all configured modules.
          make LLVM=1 ARCH=x86_64 -j2 bzImage modules
          dump_mount_state "after kernel image and modules build"
          test -s arch/x86/boot/bzImage
          test -s vmlinux

          # Preserve the Nouveau object as explicit fallback-driver evidence.
          test -s drivers/gpu/drm/nouveau/nouveau.o
          cp .config /bkernel/build-evidence/nvidia-pascal.config
          cp arch/x86/boot/bzImage /bkernel/build-evidence/bzImage
          cp vmlinux /bkernel/build-evidence/vmlinux
          cp System.map /bkernel/build-evidence/System.map
          cp drivers/gpu/drm/nouveau/nouveau.o /bkernel/build-evidence/
          make LLVM=1 ARCH=x86_64 modules_install INSTALL_MOD_PATH=/bkernel/build-evidence/modules

          # Derive the release from the modules_install output. This is the
          # release Kbuild actually installed for this exact compiled tree.
          set -- /bkernel/build-evidence/modules/lib/modules/*
          test "$#" -eq 1
          test -d "$1"
          KERNEL_RELEASE="${1##*/}"
          test "$KERNEL_RELEASE" = "7.3.4-zen2"
          printf "Verified installed kernel release: <%s>\n" "$KERNEL_RELEASE"

          # Compile NVIDIA's proprietary Pascal modules against this exact build.
          NVIDIA_WORK=/tmp/bkernel-nvidia-build
          mkdir -p "$NVIDIA_WORK"
          curl --fail --location --retry 3 --output "$NVIDIA_WORK/$NVIDIA_PACKAGE" "$NVIDIA_URL"
          printf "%s  %s\n" "$NVIDIA_SHA256" "$NVIDIA_WORK/$NVIDIA_PACKAGE" | sha256sum --check --strict
          sh "$NVIDIA_WORK/$NVIDIA_PACKAGE" --check
          dump_mount_state "after NVIDIA --check"
          (
            cd "$NVIDIA_WORK"
            sh "./$NVIDIA_PACKAGE" --extract-only
          )
          dump_mount_state "after NVIDIA --extract-only"
          NVIDIA_SOURCE="$NVIDIA_WORK/NVIDIA-Linux-x86_64-$NVIDIA_VERSION"
          printf "NVIDIA extraction directory: <%s>\n" "$NVIDIA_SOURCE"
          if [ ! -f "$NVIDIA_SOURCE/kernel/Makefile" ]; then
            printf "ERROR: NVIDIA kernel Makefile missing. Extracted directory contents:\n"
            find "$NVIDIA_WORK" -maxdepth 3 -type f -name Makefile -print | head -50
            exit 1
          fi
          printf "NVIDIA kernel Makefile found.\n"
 
          # Apply the reviewed CachyOS Pascal/580 patches to the extracted
          # proprietary driver, never to the Linux kernel source tree.
          PATCH_WORK=/tmp/bkernel-nvidia-patches
          PATCH_MANIFEST=/bkernel/build-evidence/nvidia-patches.manifest
          mkdir -p "$PATCH_WORK"
          printf "NVIDIA patch manifest diagnostics:\n"
          printf "  manifest path: <%s>\n" "$PATCH_MANIFEST"
          printf "  build-evidence mount: "
          if [ -d /bkernel/build-evidence ]; then
            printf "present\n"
            ls -ld /bkernel/build-evidence
          else
            printf "MISSING\n"
          fi
          if [ -e "$PATCH_MANIFEST" ]; then
            ls -l "$PATCH_MANIFEST"
            printf "  manifest bytes: "
            wc -c < "$PATCH_MANIFEST"
            printf "  manifest contents:\n"
            cat "$PATCH_MANIFEST"
          else
            printf "ERROR: patch manifest does not exist inside the container.\n"
            find /bkernel -maxdepth 3 -type f -name '*manifest*' -print 2>&1 || true
            exit 1
          fi
          if [ ! -s "$PATCH_MANIFEST" ]; then
            printf "ERROR: patch manifest exists but is empty.\n"
            exit 1
          fi
          while read -r patch_repository patch_commit patch_target patch_name patch_path patch_blob_sha1; do
            patch_file="$PATCH_WORK/$patch_name.patch"
            patch_url="https://raw.githubusercontent.com/$patch_repository/$patch_commit/$patch_path"
            curl --fail --location --retry 3 --output "$patch_file" "$patch_url"
            actual_blob_sha1="$(git hash-object "$patch_file")"
            if [ "$actual_blob_sha1" != "$patch_blob_sha1" ]; then
              printf "ERROR: CachyOS patch blob mismatch for %s: expected <%s>, got <%s>\n" "$patch_name" "$patch_blob_sha1" "$actual_blob_sha1"
              exit 1
            fi
            printf "Verified CachyOS patch: %s (%s)\n" "$patch_name" "$actual_blob_sha1"
          done < "$PATCH_MANIFEST"
          while read -r patch_repository patch_commit patch_target patch_name patch_path patch_blob_sha1; do
            patch --dry-run --batch --forward -Np1 -d "$NVIDIA_SOURCE/$patch_target" < "$PATCH_WORK/$patch_name.patch"
          done < "$PATCH_MANIFEST"
          while read -r patch_repository patch_commit patch_target patch_name patch_path patch_blob_sha1; do
            patch --batch --forward -Np1 -d "$NVIDIA_SOURCE/$patch_target" < "$PATCH_WORK/$patch_name.patch"
            printf "Applied CachyOS patch: %s\n" "$patch_name"
          done < "$PATCH_MANIFEST"

          # Keep the canonical source path resolved and validated before
          # compilation. Do not replace it with pwd: the current directory
          # may no longer resolve to the mounted source tree after extraction.
          if [ -z "$KERNEL_BUILD_DIR" ] || [ ! -f "$KERNEL_BUILD_DIR/Makefile" ]; then
            printf "ERROR: kernel source path invalid: <%s> (TOP_DIR=<%s>)\n" "$KERNEL_BUILD_DIR" "$TOP_DIR"
            ls -ld "/bkernel/.kernel-source" "/bkernel/.kernel-source/$TOP_DIR" 2>&1 || true
            exit 1
          fi
          if [ "$KERNEL_RELEASE" != "7.3.4-zen2" ]; then
            printf "ERROR: unexpected installed kernel release: <%s>\n" "$KERNEL_RELEASE"
            exit 1
          fi
          test -n "$KERNEL_BUILD_DIR"
          test -n "$KERNEL_RELEASE"
          printf "Verified NVIDIA build inputs: source=<%s> release=<%s>\n" "$KERNEL_BUILD_DIR" "$KERNEL_RELEASE"
          printf "NVIDIA build target: kernel_dir=<%s> kernel_release=<%s>\n" "$KERNEL_BUILD_DIR" "$KERNEL_RELEASE"
          mkdir -p "/lib/modules/$KERNEL_RELEASE"
          ln -sfn "$KERNEL_BUILD_DIR" "/lib/modules/$KERNEL_RELEASE/build"
          ln -sfn "$KERNEL_BUILD_DIR" "/lib/modules/$KERNEL_RELEASE/source"
          {
            printf "Driver: %s\nKernel: %s\n" "$NVIDIA_VERSION" "$KERNEL_RELEASE"
            printf "Compiler: %s\n" "$(clang --version | head -n 1)"
          } > /bkernel/build-evidence/nvidia-build-environment.txt
          if ! make -C "$NVIDIA_SOURCE/kernel" KERNEL_UNAME="$KERNEL_RELEASE" SYSSRC="$KERNEL_BUILD_DIR" SYSOUT="$KERNEL_BUILD_DIR" LLVM=1 CC=clang LD=ld.lld -j2 > /bkernel/build-evidence/nvidia-build.log 2>&1; then
            cat /bkernel/build-evidence/nvidia-build.log
            exit 1
          fi
          cat /bkernel/build-evidence/nvidia-build.log

          find "$NVIDIA_SOURCE/kernel" -maxdepth 1 -type f -name '*.ko' -printf '%f\n' | sort > /bkernel/build-evidence/nvidia-modules.txt
          grep -qx 'nvidia.ko' /bkernel/build-evidence/nvidia-modules.txt
          grep -qx 'nvidia-modeset.ko' /bkernel/build-evidence/nvidia-modules.txt
          grep -qx 'nvidia-uvm.ko' /bkernel/build-evidence/nvidia-modules.txt
          grep -qx 'nvidia-drm.ko' /bkernel/build-evidence/nvidia-modules.txt

          # Record the exact kernel ABI and verify every required module's vermagic.
          printf '%s\n' "$KERNEL_RELEASE" > /bkernel/build-evidence/kernelrelease
          for module in nvidia.ko nvidia-modeset.ko nvidia-uvm.ko nvidia-drm.ko; do
            vermagic="$(modinfo -F vermagic "$NVIDIA_SOURCE/kernel/$module")"
            case "$vermagic" in
              "$KERNEL_RELEASE "*) ;;
              *) printf "Unexpected vermagic for %s: %s\\n" "$module" "$vermagic" >&2; exit 1 ;;
            esac
          done
          (cd "$NVIDIA_SOURCE/kernel" && sha256sum nvidia.ko nvidia-modeset.ko nvidia-uvm.ko nvidia-drm.ko) > /bkernel/build-evidence/nvidia-modules.SHA256SUMS
          sha256sum /bkernel/build-evidence/nvidia-build.log /bkernel/build-evidence/nvidia-build-environment.txt /bkernel/build-evidence/nvidia-modules.txt /bkernel/build-evidence/nvidia-modules.SHA256SUMS /bkernel/build-evidence/kernelrelease /bkernel/build-evidence/nvidia-patches.manifest > /bkernel/build-evidence/nvidia-build-evidence.SHA256SUMS
          rm -rf "$NVIDIA_WORK"
          sha256sum /bkernel/build-evidence/nvidia-pascal.config /bkernel/build-evidence/bzImage /bkernel/build-evidence/vmlinux /bkernel/build-evidence/System.map /bkernel/build-evidence/nouveau.o /bkernel/build-evidence/kernelrelease > /bkernel/build-evidence/kernel.SHA256SUMS
