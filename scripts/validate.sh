#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:?usage: validate.sh <repo-root>}"
PYTHON_BIN="${PYTHON:-}"

if [ -z "${PYTHON_BIN}" ]; then
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3)"
  elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python)"
  else
    echo "python3 or python is required for validation" >&2
    exit 1
  fi
fi

check_file() {
  local path="$1"
  [ -e "${path}" ] || { echo "missing required file: ${path}" >&2; exit 1; }
}

check_file "${REPO_ROOT}/README.md"
check_file "${REPO_ROOT}/Makefile"
check_file "${REPO_ROOT}/docs/abi-audit.md"
check_file "${REPO_ROOT}/patches/glibc/README.md"
check_file "${REPO_ROOT}/patches/gcc/gcc-13.2.0-add-blueyos-target.patch"
check_file "${REPO_ROOT}/packages/glibc-runtime/meta/manifest.json"
check_file "${REPO_ROOT}/packages/glibc-devel/meta/manifest.json"
check_file "${REPO_ROOT}/scripts/build-gcc-target.sh"
check_file "${REPO_ROOT}/scripts/build-glibc.sh"
check_file "${REPO_ROOT}/scripts/sync-glibc-install.sh"
check_file "${REPO_ROOT}/scripts/sync-gcc-sysroot.sh"
check_file "${REPO_ROOT}/scripts/build-dpkbuild.sh"
check_file "${REPO_ROOT}/scripts/fetch-glibc.sh"
check_file "${REPO_ROOT}/scripts/apply-patches.sh"
check_file "${REPO_ROOT}/scripts/unpack-glibc.sh"
check_file "${REPO_ROOT}/scripts/stage-package.sh"

"${PYTHON_BIN}" -m json.tool "${REPO_ROOT}/packages/glibc-runtime/meta/manifest.json" >/dev/null
"${PYTHON_BIN}" -m json.tool "${REPO_ROOT}/packages/glibc-devel/meta/manifest.json" >/dev/null

for script in \
  "${REPO_ROOT}/scripts/fetch-glibc.sh" \
  "${REPO_ROOT}/scripts/apply-patches.sh" \
  "${REPO_ROOT}/scripts/build-gcc-target.sh" \
  "${REPO_ROOT}/scripts/build-glibc.sh" \
  "${REPO_ROOT}/scripts/sync-glibc-install.sh" \
  "${REPO_ROOT}/scripts/sync-gcc-sysroot.sh" \
  "${REPO_ROOT}/scripts/build-dpkbuild.sh" \
  "${REPO_ROOT}/scripts/unpack-glibc.sh" \
  "${REPO_ROOT}/scripts/stage-package.sh" \
  "${REPO_ROOT}/scripts/validate.sh"
do
  test -x "${script}" || { echo "script is not executable: ${script}" >&2; exit 1; }
done

grep -q "GLIBC_VERSION" "${REPO_ROOT}/Makefile"
grep -q "build-gcc-target" "${REPO_ROOT}/Makefile"
grep -q "build-glibc-target" "${REPO_ROOT}/Makefile"
grep -q "sync-glibc-install" "${REPO_ROOT}/Makefile"
grep -q "sync-gcc-sysroot" "${REPO_ROOT}/Makefile"
grep -q "build-dpkbuild" "${REPO_ROOT}/Makefile"
grep -q '"name": "glibc-runtime"' "${REPO_ROOT}/packages/glibc-runtime/meta/manifest.json"
grep -q '"name": "glibc-devel"' "${REPO_ROOT}/packages/glibc-devel/meta/manifest.json"

echo "[OK] Repository bootstrap files validated"
