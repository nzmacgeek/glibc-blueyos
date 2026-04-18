#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:?usage: build-gcc-target.sh <repo-root> <gcc-version> <target> <prefix> <sysroot>}"
GCC_VERSION="${2:?usage: build-gcc-target.sh <repo-root> <gcc-version> <target> <prefix> <sysroot>}"
TARGET="${3:?usage: build-gcc-target.sh <repo-root> <gcc-version> <target> <prefix> <sysroot>}"
PREFIX="${4:?usage: build-gcc-target.sh <repo-root> <gcc-version> <target> <prefix> <sysroot>}"
SYSROOT="${5:?usage: build-gcc-target.sh <repo-root> <gcc-version> <target> <prefix> <sysroot>}"

UPSTREAM_DIR="${UPSTREAM_DIR:-${REPO_ROOT}/upstream}"
BUILD_ROOT="${BUILD_ROOT:-${REPO_ROOT}/build}"
ARCHIVE_PATH="${ARCHIVE_PATH:-${UPSTREAM_DIR}/gcc-${GCC_VERSION}.tar.xz}"
SOURCE_PARENT="${SOURCE_PARENT:-${BUILD_ROOT}/src}"
SOURCE_DIR="${SOURCE_DIR:-${SOURCE_PARENT}/gcc-${GCC_VERSION}}"
BUILD_DIR="${BUILD_DIR:-${BUILD_ROOT}/gcc-build-${TARGET}}"
PATCH_FILE="${PATCH_FILE:-${REPO_ROOT}/patches/gcc/gcc-${GCC_VERSION}-add-blueyos-target.patch}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}"
DOWNLOAD_PREREQUISITES="${DOWNLOAD_PREREQUISITES:-1}"
INSTALL_AFTER_BUILD="${INSTALL_AFTER_BUILD:-1}"
GCC_URL="${GCC_URL:-https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz}"
HOST_SYSROOT="${HOST_SYSROOT:-}"
BOOTSTRAP_HEADERS_DIR="${BOOTSTRAP_HEADERS_DIR:-}"

if [ -z "${HOST_SYSROOT}" ] && [ -d /var/lib/snapd/hostfs/usr/include ]; then
  HOST_SYSROOT=/var/lib/snapd/hostfs
fi

if [ -n "${HOST_SYSROOT}" ]; then
  if [ -z "${CC:-}" ] && command -v gcc >/dev/null 2>&1; then
    export CC="$(command -v gcc) --sysroot=${HOST_SYSROOT}"
  fi

  if [ -z "${CXX:-}" ] && command -v g++ >/dev/null 2>&1; then
    export CXX="$(command -v g++) --sysroot=${HOST_SYSROOT}"
  fi

  if [ -z "${CPP:-}" ] && command -v gcc >/dev/null 2>&1; then
    export CPP="$(command -v gcc) --sysroot=${HOST_SYSROOT} -E"
  fi

  if [ -z "${CXXCPP:-}" ] && command -v g++ >/dev/null 2>&1; then
    export CXXCPP="$(command -v g++) --sysroot=${HOST_SYSROOT} -E"
  fi
fi

if [ -z "${CPP:-}" ] && command -v cpp >/dev/null 2>&1; then
  export CPP="$(command -v cpp)"
fi

if [ -z "${CXXCPP:-}" ] && [ -n "${CPP:-}" ]; then
  export CXXCPP="${CPP}"
fi

check_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "required command not found: $1" >&2
    exit 1
  }
}

write_tool_wrapper() {
  local out="$1"
  local arg=""
  shift

  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'set -e'
    printf '%s' 'exec'
    for arg in "$@"; do
      printf ' %q' "${arg}"
    done
    printf ' "$@"\n'
  } > "${out}"
  chmod +x "${out}"
}

download_with_python() {
  local url="$1"
  local out="$2"
  local python_bin=""

  if command -v python3 >/dev/null 2>&1; then
    python_bin="$(command -v python3)"
  elif command -v python >/dev/null 2>&1; then
    python_bin="$(command -v python)"
  else
    return 1
  fi

  "${python_bin}" - "$url" "$out" <<'PY'
import sys
from urllib.request import urlopen

url, out = sys.argv[1], sys.argv[2]
with urlopen(url) as response, open(out, "wb") as fh:
    while True:
        chunk = response.read(1024 * 1024)
        if not chunk:
            break
        fh.write(chunk)
PY
}

fetch_archive() {
  mkdir -p "${UPSTREAM_DIR}"
  if [ -f "${ARCHIVE_PATH}" ]; then
    echo "[SKIP] ${ARCHIVE_PATH} already exists"
    return
  fi

  echo "[GET] ${GCC_URL}"
  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --output "${ARCHIVE_PATH}" "${GCC_URL}"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "${ARCHIVE_PATH}" "${GCC_URL}"
  elif download_with_python "${GCC_URL}" "${ARCHIVE_PATH}"; then
    :
  else
    echo "curl, wget, or python3/python is required to download GCC" >&2
    exit 1
  fi
}

extract_archive() {
  mkdir -p "${SOURCE_PARENT}"
  rm -rf "${SOURCE_DIR}"
  if tar -C "${SOURCE_PARENT}" -xf "${ARCHIVE_PATH}"; then
    :
  else
    check_command python3
    python3 - "${ARCHIVE_PATH}" "${SOURCE_PARENT}" <<'PY'
import lzma
import sys
import tarfile

archive, out_dir = sys.argv[1], sys.argv[2]
with lzma.open(archive, "rb") as compressed:
    with tarfile.open(fileobj=compressed) as tf:
        tf.extractall(out_dir)
PY
  fi
  echo "[OK] Extracted ${ARCHIVE_PATH} -> ${SOURCE_DIR}"
}

apply_target_patch() {
  [ -f "${PATCH_FILE}" ] || {
    echo "patch file not found: ${PATCH_FILE}" >&2
    exit 1
  }
  echo "[PATCH] $(basename "${PATCH_FILE}")"
  patch -d "${SOURCE_DIR}" -p1 < "${PATCH_FILE}"
}

download_prerequisites() {
  if [ "${DOWNLOAD_PREREQUISITES}" != "1" ]; then
    return
  fi
  if [ -x "${SOURCE_DIR}/contrib/download_prerequisites" ]; then
    echo "[FETCH] GCC prerequisites"
    ( cd "${SOURCE_DIR}" && ./contrib/download_prerequisites )
  fi
}

prepare_target_tools() {
  local target_bindir="${PREFIX}/${TARGET}/bin"
  local target_libdir="${PREFIX}/${TARGET}/lib"
  local target_includedir="${PREFIX}/${TARGET}/include"
  local target_sysincludedir="${PREFIX}/${TARGET}/sys-include"

  mkdir -p "${target_bindir}" "${target_libdir}" "${target_includedir}" "${target_sysincludedir}"

  for tool in ar as ld nm objcopy objdump ranlib strip readelf; do
    if command -v "${tool}" >/dev/null 2>&1; then
      ln -sf "$(command -v "${tool}")" "${target_bindir}/${TARGET}-${tool}"
    fi
  done

  if ! [ -e "${target_bindir}/${TARGET}-lipo" ]; then
    ln -sf /bin/true "${target_bindir}/${TARGET}-lipo"
  fi

  if command -v as >/dev/null 2>&1; then
    rm -f "${target_bindir}/${TARGET}-as"
    write_tool_wrapper "${target_bindir}/${TARGET}-as" "$(command -v as)" --32
  fi

  if command -v ld >/dev/null 2>&1; then
    rm -f "${target_bindir}/${TARGET}-ld"
    write_tool_wrapper "${target_bindir}/${TARGET}-ld" "$(command -v ld)" -m elf_i386
  fi

  export AR_FOR_TARGET="${target_bindir}/${TARGET}-ar"
  export AS_FOR_TARGET="${target_bindir}/${TARGET}-as"
  export LD_FOR_TARGET="${target_bindir}/${TARGET}-ld"
  export NM_FOR_TARGET="${target_bindir}/${TARGET}-nm"
  export OBJCOPY_FOR_TARGET="${target_bindir}/${TARGET}-objcopy"
  export OBJDUMP_FOR_TARGET="${target_bindir}/${TARGET}-objdump"
  export RANLIB_FOR_TARGET="${target_bindir}/${TARGET}-ranlib"
  export READELF_FOR_TARGET="${target_bindir}/${TARGET}-readelf"
  export STRIP_FOR_TARGET="${target_bindir}/${TARGET}-strip"
}

seed_bootstrap_headers() {
  if [ -z "${BOOTSTRAP_HEADERS_DIR}" ]; then
    return
  fi

  if ! [ -d "${BOOTSTRAP_HEADERS_DIR}" ]; then
    echo "bootstrap headers directory not found: ${BOOTSTRAP_HEADERS_DIR}" >&2
    exit 1
  fi

  mkdir -p "${SYSROOT}/include"
  cp -a "${BOOTSTRAP_HEADERS_DIR}/." "${SYSROOT}/include/"
}

configure_build() {
  mkdir -p "${BUILD_DIR}" "${PREFIX}" "${SYSROOT}" "${SYSROOT}/include"
  (
    cd "${BUILD_DIR}"
    "${SOURCE_DIR}/configure" \
      --target="${TARGET}" \
      --prefix="${PREFIX}" \
      --with-sysroot="${SYSROOT}" \
      --disable-nls \
      --enable-languages=c \
      --without-headers \
      --disable-bootstrap \
      --disable-multilib \
      --disable-shared \
      --disable-threads \
      --disable-libatomic \
      --disable-libgomp \
      --disable-libquadmath \
      --disable-libssp \
      --disable-libsanitizer \
      --disable-libstdcxx
  )
}

build_gcc() {
  echo "[BUILD] all-gcc all-target-libgcc"
  make -C "${BUILD_DIR}" -j"${JOBS}" all-gcc all-target-libgcc
  if [ "${INSTALL_AFTER_BUILD}" = "1" ]; then
    echo "[INSTALL] install-gcc install-target-libgcc"
    make -C "${BUILD_DIR}" install-gcc install-target-libgcc
    install_gcc_startfiles
    install_gcc_tool_shims
  fi
}

install_gcc_startfiles() {
  local gcc_runtime_dir="${PREFIX}/lib/gcc/${TARGET}/${GCC_VERSION}"
  local host_file=""
  local crt=""

  mkdir -p "${gcc_runtime_dir}"

  command -v gcc >/dev/null 2>&1 || return

  for crt in crtbegin.o crtbeginS.o crtbeginT.o crtend.o crtendS.o; do
    host_file="$(gcc -m32 -print-file-name="${crt}" 2>/dev/null || true)"
    if [ -n "${host_file}" ] && [ "${host_file}" != "${crt}" ] && [ -f "${host_file}" ] && ! [ -f "${gcc_runtime_dir}/${crt}" ]; then
      install -m 644 "${host_file}" "${gcc_runtime_dir}/${crt}"
    fi
  done
}

install_gcc_tool_shims() {
  local gcc_tool_dir=""
  local target_bindir="${PREFIX}/${TARGET}/bin"

  for gcc_tool_dir in \
    "${PREFIX}/libexec/gcc/${TARGET}/${GCC_VERSION}" \
    "${PREFIX}/lib/gcc/${TARGET}/${GCC_VERSION}"; do
    mkdir -p "${gcc_tool_dir}"
    write_tool_wrapper "${gcc_tool_dir}/as" "${target_bindir}/${TARGET}-as"
    write_tool_wrapper "${gcc_tool_dir}/ld" "${target_bindir}/${TARGET}-ld"
  done
}

check_command make
check_command patch
check_command tar
check_command sed

fetch_archive
extract_archive
apply_target_patch
download_prerequisites
prepare_target_tools
seed_bootstrap_headers
configure_build
build_gcc

echo "[OK] GCC target bootstrap completed"
echo "      target : ${TARGET}"
echo "      prefix : ${PREFIX}"
echo "      sysroot: ${SYSROOT}"
