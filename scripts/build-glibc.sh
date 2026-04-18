#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:?usage: build-glibc.sh <repo-root> <glibc-version> <target> <gcc-prefix> <sysroot> <install-root>}"
GLIBC_VERSION="${2:?usage: build-glibc.sh <repo-root> <glibc-version> <target> <gcc-prefix> <sysroot> <install-root>}"
TARGET="${3:?usage: build-glibc.sh <repo-root> <glibc-version> <target> <gcc-prefix> <sysroot> <install-root>}"
GCC_PREFIX="${4:?usage: build-glibc.sh <repo-root> <glibc-version> <target> <gcc-prefix> <sysroot> <install-root>}"
SYSROOT="${5:?usage: build-glibc.sh <repo-root> <glibc-version> <target> <gcc-prefix> <sysroot> <install-root>}"
INSTALL_ROOT="${6:?usage: build-glibc.sh <repo-root> <glibc-version> <target> <gcc-prefix> <sysroot> <install-root>}"

UPSTREAM_DIR="${UPSTREAM_DIR:-${REPO_ROOT}/upstream}"
BUILD_ROOT="${BUILD_ROOT:-${REPO_ROOT}/build}"
ARCHIVE_PATH="${ARCHIVE_PATH:-${UPSTREAM_DIR}/glibc-${GLIBC_VERSION}.tar.xz}"
SOURCE_PARENT="${SOURCE_PARENT:-${BUILD_ROOT}/src}"
SOURCE_DIR="${SOURCE_DIR:-${SOURCE_PARENT}/glibc-${GLIBC_VERSION}}"
BUILD_DIR="${BUILD_DIR:-${BUILD_ROOT}/glibc-build-${TARGET}}"
PATCH_DIR="${PATCH_DIR:-${REPO_ROOT}/patches/glibc}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}"
HOST_SYSROOT="${HOST_SYSROOT:-}"
CONFIGURE_ONLY="${CONFIGURE_ONLY:-0}"
MAKE_TARGETS="${MAKE_TARGETS:-install-headers csu/subdir_lib}"
GLIBC_PREFIX="${GLIBC_PREFIX:-/}"

if [ -z "${HOST_SYSROOT}" ] && [ -d /var/lib/snapd/hostfs/usr/include ]; then
  HOST_SYSROOT=/var/lib/snapd/hostfs
fi

if [ -n "${HOST_SYSROOT}" ]; then
  export PATH="/tmp/hostfs-bin-pathfix:${HOST_SYSROOT}/usr/bin:${HOST_SYSROOT}/usr/sbin:${HOST_SYSROOT}/bin:${PATH}"
  export LD_LIBRARY_PATH="${HOST_SYSROOT}/usr/lib/x86_64-linux-gnu:${HOST_SYSROOT}/lib/x86_64-linux-gnu:${HOST_SYSROOT}/usr/lib:${HOST_SYSROOT}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  if [ -d "${HOST_SYSROOT}/usr/share/bison" ]; then
    export BISON_PKGDATADIR="${HOST_SYSROOT}/usr/share/bison"
  fi
  if [ -x "${HOST_SYSROOT}/usr/bin/m4" ]; then
    export M4="${HOST_SYSROOT}/usr/bin/m4"
  fi
fi

check_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "required command not found: $1" >&2
    exit 1
  }
}

check_file() {
  local path="$1"
  [ -e "${path}" ] || {
    echo "required file not found: ${path}" >&2
    exit 1
  }
}

apply_patches() {
  local patch_file=""

  shopt -s nullglob
  local patches=("${PATCH_DIR}"/*.patch)
  shopt -u nullglob

  for patch_file in "${patches[@]}"; do
    echo "[PATCH] $(basename "${patch_file}")"
    patch -d "${SOURCE_DIR}" -p1 < "${patch_file}"
  done
}

seed_kernel_uapi() {
  local blueyos_sysdeps="${SOURCE_DIR}/sysdeps/unix/sysv/linux/blueyos"
  local src=""

  [ -n "${HOST_SYSROOT}" ] || return

  mkdir -p "${blueyos_sysdeps}/linux" "${blueyos_sysdeps}/asm" "${blueyos_sysdeps}/asm-generic"

  for src in \
    "${HOST_SYSROOT}/usr/include/linux" \
    "${HOST_SYSROOT}/usr/include/asm-generic"; do
    if [ -d "${src}" ]; then
      cp -an "${src}/." "${blueyos_sysdeps}/$(basename "${src}")/"
    fi
  done

  for src in \
    "${HOST_SYSROOT}/usr/include/asm" \
    "${HOST_SYSROOT}/usr/include/x86_64-linux-gnu/asm"; do
    if [ -d "${src}" ]; then
      cp -an "${src}/." "${blueyos_sysdeps}/asm/"
      break
    fi
  done
}

configure_build() {
  local gcc="${GCC_PREFIX}/bin/${TARGET}-gcc"

  check_file "${gcc}"
  mkdir -p "${BUILD_DIR}" "${INSTALL_ROOT}"

  (
    cd "${BUILD_DIR}"
    "${SOURCE_DIR}/configure" \
      --host="${TARGET}" \
      --build="$(gcc -dumpmachine)" \
      --prefix="${GLIBC_PREFIX}" \
      --with-headers="${SYSROOT}/include" \
      --disable-werror \
      --enable-kernel=3.2.0 \
      CC="${gcc}"
  )
}

build_glibc() {
  local target=""

  if [ "${CONFIGURE_ONLY}" = "1" ]; then
    return
  fi

  echo "[BUILD] ${MAKE_TARGETS}"
  for target in ${MAKE_TARGETS}; do
    make -C "${BUILD_DIR}" -j"${JOBS}" \
      install_root="${INSTALL_ROOT}" \
      install-bootstrap-headers=yes \
      "${target}"
  done

  mkdir -p "${INSTALL_ROOT}/include/gnu"
  : > "${INSTALL_ROOT}/include/gnu/stubs.h"

  if [ -f "${BUILD_DIR}/csu/crt1.o" ]; then
    mkdir -p "${INSTALL_ROOT}/lib"
    install -m 644 "${BUILD_DIR}/csu/crt1.o" "${INSTALL_ROOT}/lib/crt1.o"
  fi
  if [ -f "${BUILD_DIR}/csu/crti.o" ]; then
    mkdir -p "${INSTALL_ROOT}/lib"
    install -m 644 "${BUILD_DIR}/csu/crti.o" "${INSTALL_ROOT}/lib/crti.o"
  fi
  if [ -f "${BUILD_DIR}/csu/crtn.o" ]; then
    mkdir -p "${INSTALL_ROOT}/lib"
    install -m 644 "${BUILD_DIR}/csu/crtn.o" "${INSTALL_ROOT}/lib/crtn.o"
  fi
}

check_command make
check_command patch
check_command tar
check_command gcc

check_file "${ARCHIVE_PATH}"
rm -rf "${SOURCE_DIR}" "${BUILD_DIR}" "${INSTALL_ROOT}"
"${REPO_ROOT}/scripts/unpack-glibc.sh" "${ARCHIVE_PATH}" "${SOURCE_PARENT}"
apply_patches
seed_kernel_uapi
configure_build
build_glibc

echo "[OK] glibc bootstrap helper completed"
echo "      target      : ${TARGET}"
echo "      build dir   : ${BUILD_DIR}"
echo "      install root: ${INSTALL_ROOT}"
