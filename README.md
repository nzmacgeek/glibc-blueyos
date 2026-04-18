# glibc-blueyos

Bootstrap workspace for porting **GNU glibc 2.43** to **BlueyOS** and packaging it with **dimsim**.

This repository is intentionally honest about the current state of the port:

- **What exists here now:** source-fetching, patch application, ABI notes, dimsim package layouts, a working stage-1 `i686-pc-blueyos` GCC/libgcc bootstrap, a growing BlueyOS glibc sysdeps patch series, a real bootstrap runtime/devel package flow, and a successful install image under `build/glibc-root/i686-pc-blueyos/`.
- **What does not exist yet:** end-to-end BlueyOS boot validation of a glibc-linked userland program.

The current BlueyOS kernel is close enough to Linux i386 to justify a glibc porting effort, and the dedicated kernel branch for this work now covers the minimum ABI needed to get through musl-based threading/process validation:

- `futex`
- thread-capable `clone`
- `set_tid_address` / `clear_child_tid`
- working `fork` / `waitpid`
- file-backed `mmap`

What is still missing is the bulk of the glibc port and final runtime integration:

- full syscall/startup glue beyond initial target recognition
- dynamic-loader/runtime integration

That means the immediate target for this repo is a **static-first bootstrap** that can grow into a full glibc port now that the kernel/runtime substrate is in much better shape.

## Current design

1. Keep the **kernel toolchain** on the existing `i686-elf` flow from `biscuits`.
2. Introduce a separate **userland target**: `i686-pc-blueyos`.
3. Build and package glibc in two layers:
   - `glibc-runtime` — loader/shared runtime files once they exist
   - `glibc-devel` — headers, crt objects, linker scripts, and static/development libraries
4. Use dimsim packages so BlueyOS images can consume the port through the same packaging path as the rest of the userland.

## Repository layout

```text
docs/                  ABI audit and porting notes
packages/              dimsim package trees
patches/glibc/         BlueyOS-specific glibc patch queue
patches/gcc/           GCC target scaffolding for i686-pc-blueyos
scripts/               fetch, patch, stage, and validation helpers
```

## Prerequisites

- `curl` or `wget`, `tar`, `patch`, `make`
- `python3` for the repo validation helper
- `dpkbuild` on `PATH` to produce `.dpk` archives
- the existing BlueyOS cross toolchain from `biscuits/tools/make-libc-toolchain.sh`

If you later move from bootstrap packaging to actual glibc builds, expect to also need:

- kernel headers for BlueyOS
- a BlueyOS-aware GCC target (scaffolded here)
- enough kernel ABI for glibc startup, TLS, signals, and threads

## Commands

```bash
# Download the pinned upstream release tarball into upstream/
make fetch

# Unpack it into build/src/glibc-2.43
make unpack

# Apply every patch from patches/glibc/
make apply-patches

# Fetch, patch, configure, and build a stage-1 GCC/libgcc for i686-pc-blueyos.
# BOOTSTRAP_HEADERS_DIR should point at a temporary libc header tree; the musl
# port's installed headers work for this bootstrap phase.
BOOTSTRAP_HEADERS_DIR=/tmp/blueyos-musl/include \
make build-gcc-target GCC_PREFIX=$PWD/build/toolchains/i686-pc-blueyos SYSROOT=$PWD/build/sysroots/i686-pc-blueyos

# Patch, configure, and bootstrap-install glibc headers/startfiles into
# build/glibc-root/i686-pc-blueyos/.
make build-glibc-target

# Copy the runtime/dev artifacts that were built successfully into the
# install image used for packaging.
make sync-glibc-install

# Point the GCC target sysroot at the glibc install image so dynamic
# glibc-linked programs build against glibc instead of the earlier musl
# bootstrap headers.
make sync-gcc-sysroot

# Stage files from an installed glibc prefix into dimsim package payload trees
make stage-runtime PREFIX=/path/to/glibc-prefix
make stage-devel PREFIX=/path/to/glibc-prefix

# Build dimsim packages (requires dpkbuild)
make dpk

# Sanity-check scripts, manifests, and repo wiring
make validate
```

## BlueyOS ABI notes

The important findings from the current kernel and musl port are summarized in [`docs/abi-audit.md`](docs/abi-audit.md). The short version:

- syscall numbering is intentionally Linux-like on i386
- TLS registration exists through `set_thread_area`
- `set_robust_list` is accepted and recorded
- `rseq` returns `ENOSYS`
- the dedicated `biscuits` branch `copilot/glibc-kernel-abi` now carries validated `futex`, thread-style `clone`, `set_tid_address`, `fork`/`waitpid`, file-backed `mmap`, and BlueyFS init-exec fixes
- that branch has been boot-tested with a musl init smoke binary that now passes heap, anonymous `mmap`, `fork`, file-backed `mmap`, BlueyFS, and pthread smoke checks in QEMU
- the stage-1 **userland GCC target** is now verified: `i686-pc-blueyos-gcc` installs, defines `__blueyos__`, and compiles target objects once the helper seeds its target tool shims
- the glibc patch series now teaches glibc 2.43 to recognize `*-blueyos*`, reuse the Linux sysdeps stack for bootstrap purposes, name the loader `ld-blueyos.so.1`, and supply the first BlueyOS-specific Linux UAPI compatibility headers needed for bootstrap
- `make build-glibc-target` now drives far enough to produce the core runtime shared libraries and loader in the build tree, and `make sync-glibc-install` stages them into `build/glibc-root/i686-pc-blueyos/`
- `make dpk-runtime` and `make dpk-devel` now build real dimsim packages from that install image
- `make sync-gcc-sysroot` repoints the `i686-pc-blueyos` GCC sysroot at the staged glibc image so dynamic glibc-linked programs build with the correct `/lib/ld-blueyos.so.1` interpreter
- the next major milestone is booting BlueyOS with those packages installed and running a glibc-linked program end-to-end

That combination is sufficient for early libc bring-up work, headers/startfiles packaging, and the start of a real glibc port. It is **not** yet the same thing as a finished glibc runtime package set.

## GCC and Clang

This repo includes **GCC target scaffolding** because a real glibc port needs it sooner than later.

Clang/LLVM support is intentionally deferred for now. The kernel ABI is still moving, and GCC is the lower-friction path for first glibc integration on a new target.

The `make build-gcc-target` helper is intentionally a **stage-1 userland compiler** flow: it fetches GCC 13.2.0, applies the BlueyOS patch, seeds bootstrap headers into the target sysroot, installs GCC-owned `as`/`ld` shims for the cross driver, and builds `all-gcc` plus `all-target-libgcc` into a separate prefix/sysroot without disturbing the kernel's existing `i686-elf` toolchain.
