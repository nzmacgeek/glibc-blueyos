# Copilot instructions for glibc-blueyos

## Build and validation commands

This repo is currently a **glibc port bootstrap workspace**, not a finished libc build.

Use the repo `Makefile` entry points instead of calling scripts directly when possible:

```bash
make fetch
make unpack
make apply-patches
make validate
make stage-runtime PREFIX=/path/to/glibc-prefix
make stage-devel PREFIX=/path/to/glibc-prefix
make dpk
```

There is no standalone unit-test or lint suite yet. The closest repo-level validation target is:

```bash
make validate
```

If you need to exercise one packaging path instead of the full flow:

```bash
make stage-runtime PREFIX=/path/to/glibc-prefix
# or
make stage-devel PREFIX=/path/to/glibc-prefix
```

## High-level architecture

The repo is split into four layers that work together:

1. `docs/abi-audit.md` records the BlueyOS kernel/runtime facts that constrain the glibc port. Read this before making assumptions about threads, futexes, TLS, or the loader ABI.
2. `patches/glibc/` is the future BlueyOS glibc patch queue. `make apply-patches` applies every `*.patch` there in lexical order to the unpacked upstream tree in `build/src/glibc-<version>/`.
3. `patches/gcc/` holds the compiler-target scaffolding for `i686-pc-blueyos`. This repo deliberately keeps kernel work on `i686-elf` and userland/glibc work on a separate BlueyOS target.
4. `packages/glibc-runtime/` and `packages/glibc-devel/` are dimsim package trees. `scripts/stage-package.sh` maps an installed glibc prefix into those payload trees so `dpkbuild` can turn them into `.dpk` archives.

The important big-picture constraint is that BlueyOS is **Linux-like enough for bootstrap work but not yet complete enough for a full modern glibc runtime**. In particular, the current kernel still lacks a real `futex` implementation and only supports a narrow `clone` subset, so changes should not assume working NPTL/pthreads semantics.

## Key conventions

- Treat this repo as **static-first/bootstrap-first** until the kernel grows real `futex`, fuller `clone`, and settled dynamic-loader behavior.
- Keep the **userland target triple** as `i686-pc-blueyos`; do not collapse it back into the kernel's existing `i686-elf` toolchain.
- Package outputs through **dimsim** layout under `packages/`; runtime files belong in `glibc-runtime`, while headers, crt objects, linker scripts, and development libraries belong in `glibc-devel`.
- Use `/lib/ld-blueyos.so.1` as the intended dynamic loader path unless the loader ABI is deliberately changed across the repo.
- Prefer adding BlueyOS behavior as explicit patches under `patches/glibc/` or `patches/gcc/` rather than baking ad-hoc edits into generated build directories.
- When deciding whether to extend this repo or the kernel/toolchain repos instead, use the current split:
  - kernel ABI changes live in `biscuits`
  - existing libc behavior references live in `musl-blueyos`
  - package/image integration expectations live in `dimsim` and `biscuits-baker`

