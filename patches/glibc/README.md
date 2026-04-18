# glibc patch queue

This directory is intentionally small at bootstrap time.

The immediate goal is to keep a stable place for BlueyOS-specific glibc patches once the userland target and kernel ABI settle enough to support them.

Expected early patch areas:

1. target recognition in build/config scripts
2. initial `sysdeps/unix/sysv/blueyos/` tree
3. startup files / dynamic linker naming
4. signal, thread, and TLS ABI glue
5. packaging-friendly install layout adjustments if BlueyOS diverges from the upstream defaults

`make apply-patches` will apply every `*.patch` file in this directory in lexical order.

