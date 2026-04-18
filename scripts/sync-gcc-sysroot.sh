#!/usr/bin/env bash
set -euo pipefail

GLIBC_PREFIX="${1:?usage: sync-gcc-sysroot.sh <glibc-prefix> <sysroot> <target-gcc>}"
SYSROOT="${2:?usage: sync-gcc-sysroot.sh <glibc-prefix> <sysroot> <target-gcc>}"
TARGET_GCC="${3:?usage: sync-gcc-sysroot.sh <glibc-prefix> <sysroot> <target-gcc>}"

if [ ! -d "${GLIBC_PREFIX}" ]; then
  echo "glibc prefix not found: ${GLIBC_PREFIX}" >&2
  exit 1
fi

if [ ! -x "${TARGET_GCC}" ]; then
  echo "target gcc not found: ${TARGET_GCC}" >&2
  exit 1
fi

mkdir -p "${SYSROOT}"
rm -rf "${SYSROOT}/include" "${SYSROOT}/lib"

if [ -d "${GLIBC_PREFIX}/include" ]; then
  cp -a "${GLIBC_PREFIX}/include" "${SYSROOT}/"
fi

if [ -d "${GLIBC_PREFIX}/lib" ]; then
  cp -a "${GLIBC_PREFIX}/lib" "${SYSROOT}/"
fi

gcc_include_dir="$("${TARGET_GCC}" -print-file-name=include)"
gcc_fixed_dir="$(dirname "${gcc_include_dir}")/include-fixed"
rm -f "${gcc_fixed_dir}/stdio.h"

echo "[OK] Synced ${GLIBC_PREFIX} into ${SYSROOT}"
echo "[OK] Cleared stale GCC fixed header ${gcc_fixed_dir}/stdio.h"
