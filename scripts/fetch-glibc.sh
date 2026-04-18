#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?usage: fetch-glibc.sh <version> <archive-path>}"
ARCHIVE_PATH="${2:?usage: fetch-glibc.sh <version> <archive-path>}"
URL="https://ftp.gnu.org/gnu/glibc/glibc-${VERSION}.tar.xz"

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

mkdir -p "$(dirname "${ARCHIVE_PATH}")"

if [ -f "${ARCHIVE_PATH}" ]; then
  echo "[SKIP] ${ARCHIVE_PATH} already exists"
  exit 0
fi

echo "[GET] ${URL}"
if command -v curl >/dev/null 2>&1; then
  curl --fail --location --output "${ARCHIVE_PATH}" "${URL}"
elif command -v wget >/dev/null 2>&1; then
  wget -O "${ARCHIVE_PATH}" "${URL}"
elif download_with_python "${URL}" "${ARCHIVE_PATH}"; then
  :
else
  echo "curl, wget, or python3/python is required to download glibc" >&2
  exit 1
fi
echo "[OK] Downloaded ${ARCHIVE_PATH}"
