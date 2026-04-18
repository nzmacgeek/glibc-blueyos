#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${1:?usage: sync-glibc-install.sh <glibc-build-dir> <install-root> [glibc-source-dir]}"
INSTALL_ROOT="${2:?usage: sync-glibc-install.sh <glibc-build-dir> <install-root> [glibc-source-dir]}"
SOURCE_DIR="${3:-}"

if [ ! -d "${BUILD_DIR}" ]; then
  echo "build directory not found: ${BUILD_DIR}" >&2
  exit 1
fi

mkdir -p "${INSTALL_ROOT}/lib" "${INSTALL_ROOT}/include/gnu"
: > "${INSTALL_ROOT}/include/gnu/stubs.h"

copy_if_exists() {
  local src="$1"
  local dest="$2"

  if [ ! -e "${src}" ]; then
    return 0
  fi

  mkdir -p "$(dirname "${dest}")"
  cp -a "${src}" "${dest}"
}

if [ -e "${BUILD_DIR}/elf/ld.so" ]; then
  mkdir -p "${INSTALL_ROOT}/lib"
  rm -f "${INSTALL_ROOT}/lib/ld-blueyos.so.1"
  cp -aL "${BUILD_DIR}/elf/ld-blueyos.so.1" "${INSTALL_ROOT}/lib/ld-blueyos.so.1"
  copy_if_exists "${BUILD_DIR}/elf/ld.so" "${INSTALL_ROOT}/lib/ld.so"
fi
copy_if_exists "${BUILD_DIR}/libc.so" "${INSTALL_ROOT}/lib/libc.so"
copy_if_exists "${BUILD_DIR}/libc.so.6" "${INSTALL_ROOT}/lib/libc.so.6"
copy_if_exists "${BUILD_DIR}/libc.a" "${INSTALL_ROOT}/lib/libc.a"
copy_if_exists "${BUILD_DIR}/libc_nonshared.a" "${INSTALL_ROOT}/lib/libc_nonshared.a"

copy_if_exists "${BUILD_DIR}/math/libm.so" "${INSTALL_ROOT}/lib/libm.so"
copy_if_exists "${BUILD_DIR}/math/libm.so.6" "${INSTALL_ROOT}/lib/libm.so.6"
copy_if_exists "${BUILD_DIR}/math/libm.a" "${INSTALL_ROOT}/lib/libm.a"

copy_if_exists "${BUILD_DIR}/dlfcn/libdl.so" "${INSTALL_ROOT}/lib/libdl.so"
copy_if_exists "${BUILD_DIR}/dlfcn/libdl.so.2" "${INSTALL_ROOT}/lib/libdl.so.2"
copy_if_exists "${BUILD_DIR}/dlfcn/libdl.a" "${INSTALL_ROOT}/lib/libdl.a"

copy_if_exists "${BUILD_DIR}/nptl/libpthread.so" "${INSTALL_ROOT}/lib/libpthread.so"
copy_if_exists "${BUILD_DIR}/nptl/libpthread.so.0" "${INSTALL_ROOT}/lib/libpthread.so.0"
copy_if_exists "${BUILD_DIR}/nptl/libpthread.a" "${INSTALL_ROOT}/lib/libpthread.a"

copy_if_exists "${BUILD_DIR}/rt/librt.so" "${INSTALL_ROOT}/lib/librt.so"
copy_if_exists "${BUILD_DIR}/rt/librt.so.1" "${INSTALL_ROOT}/lib/librt.so.1"
copy_if_exists "${BUILD_DIR}/rt/librt.a" "${INSTALL_ROOT}/lib/librt.a"

copy_if_exists "${BUILD_DIR}/locale/libBrokenLocale.so" "${INSTALL_ROOT}/lib/libBrokenLocale.so"
copy_if_exists "${BUILD_DIR}/locale/libBrokenLocale.so.1" "${INSTALL_ROOT}/lib/libBrokenLocale.so.1"
copy_if_exists "${BUILD_DIR}/locale/libBrokenLocale.a" "${INSTALL_ROOT}/lib/libBrokenLocale.a"

copy_if_exists "${BUILD_DIR}/csu/crt1.o" "${INSTALL_ROOT}/lib/crt1.o"
copy_if_exists "${BUILD_DIR}/csu/Scrt1.o" "${INSTALL_ROOT}/lib/Scrt1.o"
copy_if_exists "${BUILD_DIR}/csu/crti.o" "${INSTALL_ROOT}/lib/crti.o"
copy_if_exists "${BUILD_DIR}/csu/crtn.o" "${INSTALL_ROOT}/lib/crtn.o"

if [ -d "${BUILD_DIR}/iconvdata" ]; then
  rm -rf "${INSTALL_ROOT}/lib/gconv"
  mkdir -p "${INSTALL_ROOT}/lib/gconv"
  find "${BUILD_DIR}/iconvdata" -maxdepth 1 -type f -name '*.so' -exec cp -a {} "${INSTALL_ROOT}/lib/gconv/" \;
fi

if [ -n "${SOURCE_DIR}" ] && [ -d "${SOURCE_DIR}/iconvdata" ]; then
  copy_if_exists "${SOURCE_DIR}/iconvdata/gconv-modules" "${INSTALL_ROOT}/lib/gconv/gconv-modules"
  copy_if_exists "${SOURCE_DIR}/iconvdata/gconv-modules-extra.conf" "${INSTALL_ROOT}/lib/gconv/gconv-modules-extra.conf"
  copy_if_exists "${SOURCE_DIR}/iconvdata/gconv.map" "${INSTALL_ROOT}/lib/gconv/gconv.map"
fi

echo "[OK] Synced glibc build artifacts into ${INSTALL_ROOT}"
