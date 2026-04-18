#!/usr/bin/env bash
set -euo pipefail

MODE="${1:?usage: stage-package.sh <runtime|devel> <prefix> <package-dir>}"
PREFIX="${2:?usage: stage-package.sh <runtime|devel> <prefix> <package-dir>}"
PACKAGE_DIR="${3:?usage: stage-package.sh <runtime|devel> <prefix> <package-dir>}"
PAYLOAD_DIR="${PACKAGE_DIR}/payload"

if [ ! -d "${PREFIX}" ]; then
  echo "prefix not found: ${PREFIX}" >&2
  exit 1
fi

if [ ! -d "${PACKAGE_DIR}" ]; then
  echo "package directory not found: ${PACKAGE_DIR}" >&2
  exit 1
fi

rm -rf "${PAYLOAD_DIR}"
mkdir -p "${PAYLOAD_DIR}"
rm -f "${PAYLOAD_DIR}/.gitkeep"

copy_file() {
  local src="$1"
  local rel="$2"
  local dest
  if [ ! -e "${src}" ]; then
    return 0
  fi
  dest="${PAYLOAD_DIR}/${rel}"
  mkdir -p "$(dirname "${dest}")"
  cp -a "${src}" "${dest}"
}

copy_tree() {
  local src="$1"
  local rel="$2"
  local dest
  if [ ! -d "${src}" ]; then
    return 0
  fi
  dest="${PAYLOAD_DIR}/${rel}"
  mkdir -p "${dest}"
  ( cd "${src}" && tar -cf - . ) | ( cd "${dest}" && tar -xpf - )
}

case "${MODE}" in
  runtime)
    copy_file "${PREFIX}/lib/ld-blueyos.so.1" "lib/ld-blueyos.so.1"
    copy_file "${PREFIX}/lib/ld-linux.so.2" "lib/ld-linux.so.2"
    copy_file "${PREFIX}/lib/libc.so.6" "lib/libc.so.6"
    copy_file "${PREFIX}/lib/libm.so.6" "lib/libm.so.6"
    copy_file "${PREFIX}/lib/libpthread.so.0" "lib/libpthread.so.0"
    copy_file "${PREFIX}/lib/librt.so.1" "lib/librt.so.1"
    copy_file "${PREFIX}/lib/libdl.so.2" "lib/libdl.so.2"
    copy_file "${PREFIX}/lib/libBrokenLocale.so.1" "lib/libBrokenLocale.so.1"
    copy_file "${PREFIX}/lib/libutil.so.1" "lib/libutil.so.1"
    copy_file "${PREFIX}/lib/libresolv.so.2" "lib/libresolv.so.2"
    copy_tree "${PREFIX}/lib/gconv" "lib/gconv"
    copy_tree "${PREFIX}/etc" "etc"
    ;;
  devel)
    copy_tree "${PREFIX}/include" "usr/include"
    copy_file "${PREFIX}/lib/crt1.o" "usr/lib/crt1.o"
    copy_file "${PREFIX}/lib/Scrt1.o" "usr/lib/Scrt1.o"
    copy_file "${PREFIX}/lib/crti.o" "usr/lib/crti.o"
    copy_file "${PREFIX}/lib/crtn.o" "usr/lib/crtn.o"
    copy_file "${PREFIX}/lib/libc.a" "usr/lib/libc.a"
    copy_file "${PREFIX}/lib/libc.so" "usr/lib/libc.so"
    copy_file "${PREFIX}/lib/libc_nonshared.a" "usr/lib/libc_nonshared.a"
    copy_file "${PREFIX}/lib/libpthread.a" "usr/lib/libpthread.a"
    copy_file "${PREFIX}/lib/libpthread.so" "usr/lib/libpthread.so"
    copy_file "${PREFIX}/lib/libm.a" "usr/lib/libm.a"
    copy_file "${PREFIX}/lib/libm.so" "usr/lib/libm.so"
    copy_file "${PREFIX}/lib/libdl.a" "usr/lib/libdl.a"
    copy_file "${PREFIX}/lib/libdl.so" "usr/lib/libdl.so"
    copy_file "${PREFIX}/lib/librt.a" "usr/lib/librt.a"
    copy_file "${PREFIX}/lib/librt.so" "usr/lib/librt.so"
    copy_file "${PREFIX}/lib/libutil.a" "usr/lib/libutil.a"
    copy_file "${PREFIX}/lib/libutil.so" "usr/lib/libutil.so"
    copy_file "${PREFIX}/lib/libresolv.a" "usr/lib/libresolv.a"
    copy_file "${PREFIX}/lib/libresolv.so" "usr/lib/libresolv.so"
    ;;
  *)
    echo "unknown mode: ${MODE}" >&2
    exit 1
    ;;
esac

 echo "[OK] Staged ${MODE} payload into ${PAYLOAD_DIR}"
