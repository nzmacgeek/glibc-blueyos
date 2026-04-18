#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_PATH="${1:?usage: unpack-glibc.sh <archive-path> <destination-dir>}"
DEST_DIR="${2:?usage: unpack-glibc.sh <archive-path> <destination-dir>}"

if [ ! -f "${ARCHIVE_PATH}" ]; then
  echo "archive not found: ${ARCHIVE_PATH}" >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"

if tar -C "${DEST_DIR}" -xf "${ARCHIVE_PATH}" >/dev/null 2>&1; then
  exit 0
fi

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="$(command -v python3)"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="$(command -v python)"
else
  echo "tar with xz support or python3/python with lzma support is required" >&2
  exit 1
fi

"${PYTHON_BIN}" - "${ARCHIVE_PATH}" "${DEST_DIR}" <<'PY'
import sys
import tarfile

archive, dest = sys.argv[1], sys.argv[2]
with tarfile.open(archive, "r:*") as tf:
    tf.extractall(dest)
PY
