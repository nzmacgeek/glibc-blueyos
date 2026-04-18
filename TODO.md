# TODO for Copilot: continue the BlueyOS glibc port

This file is the ordered execution plan for continuing the port from the current bootstrap state.

It is written as **exact work Copilot should perform**, not as a generic wishlist.

## Goal

Reach the first **real glibc-on-BlueyOS milestone**:

1. a BlueyOS-aware GCC target exists for userland (`i686-pc-blueyos`)
2. the kernel supports the minimum ABI that glibc startup and early threading need
3. glibc source carries an initial BlueyOS port patch set
4. the resulting files can be staged and packaged with dimsim

## Phase 1 - unblock the kernel ABI in `biscuits`

Copilot should work in `../biscuits/biscuits` first, because a modern glibc port is blocked there today.

Status update:

- first-pass kernel ABI work has been captured on the separate branch `copilot/glibc-kernel-abi`
- the edited kernel tree lives in the isolated worktree `.worktrees/biscuits-kernel`
- kernel validation now passes the musl init smoke flow through `fork`, file-backed `mmap`, BlueyFS checks, and a pthread smoke test
- the remaining kernel work is to commit/rebase the validated branch cleanly, not to rediscover the ABI work

### 1. Implement a real `futex` syscall

1. Add syscall numbers and declarations if any are still missing in:
   - `kernel/syscall.h`
   - `kernel/syscall.c`
2. Implement at least:
   - `FUTEX_WAIT`
   - `FUTEX_WAKE`
   - `FUTEX_REQUEUE` if needed by musl/glibc locking paths
3. Start with process-private futexes only if that shortens the path, but return Linux-like errors for unsupported operations rather than silent success.
4. Reuse the scheduler/blocking primitives already present in the kernel instead of inventing a second wait subsystem.
5. Add kernel-side tests or at least small userland probes that confirm:
   - wait sleeps when the value matches
   - wake releases the waiter
   - mismatched values return `EAGAIN`

### 2. Make `clone` usable for threading

1. Extend `sys_clone` in `kernel/syscall.c` beyond the current fork/vfork-only subset.
2. Support the minimum flag combination glibc/NPTL will expect for i386 threading:
   - `CLONE_VM`
   - `CLONE_FS`
   - `CLONE_FILES`
   - `CLONE_SIGHAND`
   - `CLONE_THREAD`
   - `CLONE_SYSVSEM`
   - `CLONE_SETTLS`
   - `CLONE_PARENT_SETTID`
   - `CLONE_CHILD_CLEARTID`
3. Wire `CLONE_SETTLS` to the existing TLS base handling instead of leaving TLS setup to process-global state.
4. Wire `PARENT_SETTID` / `CHILD_CLEARTID` to correct user memory updates.
5. Preserve current fork/vfork behavior for the old flag subsets.

### 3. Finish `set_tid_address` semantics

1. Track the clear-on-exit TID pointer in the process/thread state.
2. On thread exit:
   - write `0` to the child TID address
   - perform the futex wake required by Linux semantics
3. Keep the current simple startup path working for single-threaded processes.

### 4. Validate the kernel ABI before touching glibc

1. Keep the isolated `copilot/glibc-kernel-abi` branch as the landing branch for the validated kernel fixes.
2. Preserve the musl-linked init smoke test as the regression check for:
   - pthread mutexes
   - condition variables
   - stdio locking
   - `fork` / `waitpid`
   - file-backed `mmap`
3. Record any remaining ABI deviations in `docs/abi-audit.md` before continuing.

## Phase 2 - make GCC capable of targeting BlueyOS userland

Copilot should then work on the GCC target scaffold currently stored under `patches/gcc/`.

### 5. Turn the GCC scaffold into a buildable target patch

1. Start from the current `patches/gcc/gcc-13.2.0-add-blueyos-target.patch`.
2. Expand it so GCC can actually build a C compiler for `i686-pc-blueyos`, not just recognize the target.
3. Verify at minimum:
   - target recognition in `config.sub`
   - `gcc/config.gcc`
   - `libgcc/config.host`
   - startfile/endfile specs
   - dynamic linker path (`/lib/ld-blueyos.so.1`)
4. Add any missing `t-*` or `xm-*` config files GCC needs rather than overloading unrelated Linux targets.

### 6. Create a repeatable GCC build helper in this repo

1. Add a script such as `scripts/build-gcc-target.sh`.
2. The script should:
   - fetch or use a prepared GCC source tree
   - apply the BlueyOS patch
   - configure a target compiler for `i686-pc-blueyos`
   - build `all-gcc` and `all-target-libgcc`
3. Document the exact command in `README.md`.
4. Do **not** replace the kernel's existing `i686-elf` toolchain flow; this is a second userland toolchain.

## Phase 3 - start the actual glibc port in this repo

This phase has now started: the stage-1 GCC target is verified and the first real glibc patch is in the queue.

### 7. Add the initial glibc target-recognition patch

1. Populate `patches/glibc/` with the first real patch file.
2. Teach glibc's config logic to recognize `*-blueyos*`.
3. Keep reusing the Linux/i386 sysdeps path where it matches BlueyOS.
4. Grow the existing `sysdeps/unix/sysv/linux/blueyos/` bootstrap layer as concrete build failures expose the remaining BlueyOS-specific pieces.

### 8. Implement the minimum BlueyOS glibc sysdeps layer

1. Add the startup/runtime files needed for a static-first bring-up:
   - syscall wrappers where Linux assumptions are wrong
   - loader naming and path decisions
   - signal glue if BlueyOS differs
   - TLS setup glue if the Linux default path is insufficient
2. Keep the first milestone narrow:
   - `libc.so`
   - crt objects
   - static libraries
   - headers
3. Defer ambitious features until after the first working libc build:
   - NSS
   - locales beyond what glibc already installs
   - advanced resolver behavior
   - non-i386 architectures

### 9. Add a real glibc configure/build helper

1. Add a script such as `scripts/build-glibc.sh`.
2. It should:
   - use the patched upstream tree in `build/src/glibc-<version>`
   - create an out-of-tree build dir
   - configure against the `i686-pc-blueyos` compiler
   - install into a staging prefix
3. Capture the exact flags in the script rather than leaving them implicit in docs.
4. Fail early if the target compiler, kernel headers, or install prefix are missing.

## Phase 4 - wire the output into dimsim packages

### 10. Replace the placeholder staging assumptions with actual install layouts

1. After the first successful glibc install, inspect the real prefix tree.
2. Update `scripts/stage-package.sh` so it copies the actual produced files, not just expected names.
3. Split package contents cleanly:
   - `glibc-runtime`: loader, shared libraries, runtime data
   - `glibc-devel`: headers, crt objects, linker scripts, static libs, development symlinks
4. If the first real build shows a better package split, adjust the manifests instead of forcing a bad layout.

### 11. Add package lifecycle scripts only if the runtime needs them

1. Keep package scripts empty unless glibc really requires post-install actions.
2. If loader symlinks or cache generation become necessary, add them under:
   - `packages/glibc-runtime/meta/scripts/`
   - `packages/glibc-devel/meta/scripts/`
3. Keep the package install path compatible with offline dimsim/sysroot installs.

## Phase 5 - integrate with the wider BlueyOS build

### 12. Teach `biscuits-baker` about glibc once the packages are real

1. Add a new source repo entry for `glibc-blueyos` in `../biscuits-baker/baker.yaml`.
2. Add one or more recipes in `../biscuits-baker/recipes/` for:
   - `glibc-runtime`
   - `glibc-devel`
3. Keep musl and glibc flows separate until there is an intentional switch-over plan.
4. Do not silently replace `musl-blueyos` as the default system libc without an explicit migration step.

## Phase 6 - validation milestones Copilot should hit

### 13. First toolchain milestone

Copilot should stop and verify after:

1. GCC builds for `i686-pc-blueyos`
2. `libgcc` builds for the target
3. trivial C programs compile with the new compiler driver

### 14. First glibc milestone

Copilot should stop and verify after:

1. glibc configures successfully for `i686-pc-blueyos`
2. crt objects and headers install into a staging prefix
3. the staged files package cleanly with `dpkbuild`

### 15. First runtime milestone

Copilot should stop and verify after:

1. a trivial dynamically linked test binary starts on BlueyOS
2. `/lib/ld-blueyos.so.1` is found and executed
3. basic libc calls work:
   - `write`
   - `malloc`
   - `open` / `read`
   - `clock_gettime`
4. a pthread smoke test works without deadlock or early abort

## Immediate next action

The next Copilot session should begin with this exact sequence:

1. open `docs/abi-audit.md`
2. confirm the validated kernel worktree state on branch `copilot/glibc-kernel-abi`
3. update `docs/abi-audit.md` with the current musl/QEMU validation result
4. rerun `make build-gcc-target` in this repo only if the stage-1 toolchain needs refreshing
5. rerun `make build-glibc-target` and inspect `build/glibc-root/i686-pc-blueyos/`
6. wire the real bootstrap headers/crt outputs into `stage-devel` / dimsim packaging
7. continue extending the BlueyOS glibc sysdeps patch set as later library/runtime build steps expose the next gaps
