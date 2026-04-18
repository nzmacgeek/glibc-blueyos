# BlueyOS ABI audit for glibc

This audit is based on the current `biscuits` kernel, the existing `musl-blueyos` port, and the BlueyOS packaging/toolchain repos.

## What already aligns well with libc bring-up

BlueyOS intentionally tracks many Linux i386 syscall numbers, which is why musl could be brought up without inventing a fully separate ABI first.

The kernel already exposes or partially exposes:

- file I/O and metadata syscalls (`read`, `write`, `open`, `close`, `stat`, `fstat`, `lseek`, `getdents`, `unlink`, `mkdir`, `rmdir`)
- memory management (`brk`, `mmap`, `mmap2`, `munmap`, `mprotect`)
- process control (`fork`, `vfork`, `execve`, `waitpid`, `wait4`, `exit`, `exit_group`, `kill`)
- signal entry points (`rt_sigaction`, `rt_sigprocmask`, `sigreturn`)
- time APIs (`gettimeofday`, `clock_gettime`, `nanosleep`, `sched_yield`)
- TLS setup via `SYS_SET_THREAD_AREA`
- socket support for `AF_UNIX`, `AF_INET`, and BlueyOS-specific `AF_NETCTL`

## Current glibc-facing gaps

Modern glibc on i386 still assumes a more Linux-like runtime than BlueyOS provides out of the box, but the kernel branch being prepared for this port now covers the minimum threading/process substrate needed for early libc bring-up and pthread smoke validation.

### 1. Threading/process primitives are now present on the porting branch

On `biscuits` branch `copilot/glibc-kernel-abi`, the kernel now carries:

- `futex` wait/wake/requeue support
- thread-capable `clone` groundwork aligned to the musl i386 ABI
- `set_tid_address` / `clear_child_tid` exit wake semantics
- a fixed `fork` address-space clone path
- correct address-space teardown for private page tables that still reference inherited kernel mappings
- a BlueyFS path lookup fix so packaged `/sbin/claw` and `/bin/init` can actually be executed from the guest image

That branch has now been boot-validated with the musl init smoke binary, which reaches:

- `brk`
- anonymous `mmap`
- `fork` / `waitpid`
- file-backed `mmap`
- BlueyFS file-size checks
- a `pthread` smoke test using mutexes, condition variables, stdio, and `pthread_join`

### 2. Dynamic loader and glibc integration work is still ahead

The remaining glibc-side risk is no longer “basic threads cannot work”; it is the usual new-libc-port work:

- choosing/finalizing the glibc dynamic loader path (`/lib/ld-blueyos.so.1` in this repo)
- settling shared-library search paths and package layout
- carrying a small BlueyOS Linux-UAPI compatibility layer where reused Linux sysdeps expect headers such as `linux/errno.h`, `linux/limits.h`, `linux/types.h`, `linux/falloc.h`, and `asm/socket.h`
- confirming any remaining signal/TLS details where glibc is stricter than musl

### 3. `rseq` intentionally falls back

The kernel records the registration and returns `ENOSYS`, which is fine for bootstrap work because libc can fall back to non-rseq code paths.

## Practical conclusion

The right near-term milestone is now:

1. keep the validated kernel branch ready to land/rebase as the libc work proceeds
2. build out **headers/startfiles/static-library packaging**
3. package the now-real glibc bootstrap install artifacts (headers and startfiles)
4. push from headers/startfiles into more of the runtime and shared-library build
5. revisit remaining runtime integration details as glibc itself starts linking and running
6. tighten any remaining syscall, signal, or TLS mismatches that real glibc objects expose

## References used

- `biscuits/biscuits/kernel/syscall.h`
- `biscuits/biscuits/kernel/syscall.c`
- `biscuits/biscuits/docs/musl-port.md`
- `musl-blueyos/src/env/__init_tls.c`
- `musl-blueyos/arch/i386/bits/TARGET_BLUEYOS.md`
- `biscuits-baker/baker.yaml`
- `blueyos-bash/README.md`
