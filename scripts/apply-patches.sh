#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${1:?usage: apply-patches.sh <source-dir> <patch-dir>}"
PATCH_DIR="${2:?usage: apply-patches.sh <source-dir> <patch-dir>}"

if [ ! -d "${SOURCE_DIR}" ]; then
  echo "source directory not found: ${SOURCE_DIR}" >&2
  exit 1
fi

if [ ! -d "${PATCH_DIR}" ]; then
  echo "patch directory not found: ${PATCH_DIR}" >&2
  exit 1
fi

shopt -s nullglob
patches=("${PATCH_DIR}"/*.patch)
shopt -u nullglob

if [ "${#patches[@]}" -eq 0 ]; then
  echo "[SKIP] no glibc patches found in ${PATCH_DIR}"
  exit 0
fi

for patch_file in "${patches[@]}"; do
  echo "[PATCH] $(basename "${patch_file}")"
  patch -d "${SOURCE_DIR}" -p1 < "${patch_file}"
done

echo "[OK] Applied ${#patches[@]} patch(es)"

