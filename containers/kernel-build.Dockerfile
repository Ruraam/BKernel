# Immutable Debian multi-architecture OCI index; CI builds explicitly for linux/amd64.
FROM debian@sha256:fbfb4059d2127120aa05b6e6064523d2102552f0cf0026ddf0701c12f1f8f3e0

ARG DEBIAN_SNAPSHOT=20261104T212339Z
ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C \
    LANG=C \
    TZ=UTC \
    SOURCE_DATE_EPOCH=1794335460 \
    KBUILD_BUILD_USER=bkernel \
    KBUILD_BUILD_HOST=reproducible \
    KBUILD_BUILD_VERSION=1
ENV KBUILD_BUILD_TIMESTAMP="Tue Nov 10 18:31:00 UTC 2026" \
    RUST_LIB_SRC=/usr/src/rustc-1.85.0/library

RUN rm -f /etc/apt/sources.list /etc/apt/sources.list.d/debian.sources \
    && printf 'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/%s trixie main\n' "${DEBIAN_SNAPSHOT}" > /etc/apt/sources.list \
    && printf 'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian-security/%s trixie-security main\n' "${DEBIAN_SNAPSHOT}" >> /etc/apt/sources.list \
    && apt-get -o Acquire::Check-Valid-Until=false update \
    && apt-get install -y --no-install-recommends \
       bc bison build-essential ca-certificates clang cpio curl dwarves flex \
       git kmod libelf-dev libncurses-dev libssl-dev libudev-dev libclang-dev \
       lld llvm make openssl perl python3 rsync rustc rust-src bindgen rustfmt rust-clippy cargo xz-utils zstd \
    && test -d /usr/src/rustc-1.85.0/library \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
CMD ["bash"]
