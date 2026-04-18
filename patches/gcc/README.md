# GCC target scaffolding for BlueyOS

glibc will eventually need a userland compiler target that is distinct from the kernel's existing `i686-elf` toolchain.

This repo uses:

- `i686-elf` for kernel and bare-metal work
- `i686-pc-blueyos` for future glibc-linked userland work

The patch in this directory is a bootstrap starting point for GCC 13.2.0. It is not presented as a finished compiler port; it exists so the glibc effort has a concrete place to continue instead of starting from another empty tree later.

