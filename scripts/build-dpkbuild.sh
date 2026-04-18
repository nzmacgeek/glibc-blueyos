#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:?usage: build-dpkbuild.sh <repo-root> <dimsim-repo-url> <dimsim-dir>}"
DIMSIM_REPO_URL="${2:?usage: build-dpkbuild.sh <repo-root> <dimsim-repo-url> <dimsim-dir>}"
DIMSIM_DIR="${3:?usage: build-dpkbuild.sh <repo-root> <dimsim-repo-url> <dimsim-dir>}"

HOST_SYSROOT="${HOST_SYSROOT:-}"

if [ -z "${HOST_SYSROOT}" ] && [ -d /var/lib/snapd/hostfs/usr/include ]; then
  HOST_SYSROOT=/var/lib/snapd/hostfs
fi

if [ -n "${HOST_SYSROOT}" ]; then
  export PATH="/tmp/hostfs-bin-pathfix:${HOST_SYSROOT}/usr/bin:${HOST_SYSROOT}/usr/sbin:${HOST_SYSROOT}/bin:${PATH}"
  export LD_LIBRARY_PATH="${HOST_SYSROOT}/usr/lib/x86_64-linux-gnu:${HOST_SYSROOT}/lib/x86_64-linux-gnu:${HOST_SYSROOT}/usr/lib:${HOST_SYSROOT}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
fi

check_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "required command not found: $1" >&2
    exit 1
  }
}

download() {
  local url="$1"
  local output="$2"

  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --silent --show-error --output "${output}" "${url}"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -q -O "${output}" "${url}"
    return
  fi

  echo "curl or wget is required to fetch dimsim sources" >&2
  exit 1
}

if [ -x "${DIMSIM_DIR}/bin/dpkbuild" ]; then
  echo "[OK] Reusing ${DIMSIM_DIR}/bin/dpkbuild"
  exit 0
fi

check_command cc

REPO_PATH="${DIMSIM_REPO_URL#https://github.com/}"
REPO_PATH="${REPO_PATH#http://github.com/}"
REPO_PATH="${REPO_PATH%.git}"
RAW_BASE="https://raw.githubusercontent.com/${REPO_PATH}/main"

mkdir -p "$(dirname "${DIMSIM_DIR}")"
rm -rf "${DIMSIM_DIR}"
mkdir -p "${DIMSIM_DIR}/src" "${DIMSIM_DIR}/bin"

download "${RAW_BASE}/src/dpkbuild.c" "${DIMSIM_DIR}/src/dpkbuild.c"
download "${RAW_BASE}/src/common.c" "${DIMSIM_DIR}/src/common.c"
download "${RAW_BASE}/src/common.h" "${DIMSIM_DIR}/src/common.h"
download "${RAW_BASE}/src/manifest.c" "${DIMSIM_DIR}/src/manifest.c"
download "${RAW_BASE}/src/manifest.h" "${DIMSIM_DIR}/src/manifest.h"
download "${RAW_BASE}/src/tar.c" "${DIMSIM_DIR}/src/tar.c"
download "${RAW_BASE}/src/tar.h" "${DIMSIM_DIR}/src/tar.h"

cc -O2 -Wall -Wextra -std=c11 \
  -o "${DIMSIM_DIR}/bin/dpkbuild" \
  "${DIMSIM_DIR}/src/dpkbuild.c" \
  "${DIMSIM_DIR}/src/common.c" \
  "${DIMSIM_DIR}/src/manifest.c" \
  "${DIMSIM_DIR}/src/tar.c"

echo "[OK] Built ${DIMSIM_DIR}/bin/dpkbuild"
