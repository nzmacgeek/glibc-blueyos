GLIBC_VERSION ?= 2.43
GLIBC_PACKAGE_VERSION ?= 2.43.0
GCC_VERSION ?= 13.2.0
TARGET ?= i686-pc-blueyos
ARCH ?= i386
GCC_PREFIX ?= $(CURDIR_ABS)/build/toolchains/$(TARGET)
SYSROOT ?= $(CURDIR_ABS)/build/sysroots/$(TARGET)
DIMSIM_REPO_URL ?= https://github.com/nzmacgeek/dimsim.git

CURDIR_ABS := $(CURDIR)
UPSTREAM_DIR ?= $(CURDIR_ABS)/upstream
BUILD_DIR ?= $(CURDIR_ABS)/build
DIST_DIR ?= $(CURDIR_ABS)/dist
PATCHES_DIR ?= $(CURDIR_ABS)/patches
PACKAGES_DIR ?= $(CURDIR_ABS)/packages
TOOLS_DIR ?= $(BUILD_DIR)/tools
DIMSIM_DIR ?= $(TOOLS_DIR)/dimsim
DPKBUILD ?= $(DIMSIM_DIR)/bin/dpkbuild

UPSTREAM_ARCHIVE := $(UPSTREAM_DIR)/glibc-$(GLIBC_VERSION).tar.xz
SOURCE_DIR := $(BUILD_DIR)/src/glibc-$(GLIBC_VERSION)

RUNTIME_PKG := $(PACKAGES_DIR)/glibc-runtime
DEVEL_PKG := $(PACKAGES_DIR)/glibc-devel

.PHONY: help fetch unpack apply-patches build-gcc-target build-glibc-target sync-glibc-install sync-gcc-sysroot build-dpkbuild stage-runtime stage-devel dpk-runtime dpk-devel dpk validate clean distclean

.DEFAULT_GOAL := help

help:
	@echo "glibc-blueyos"
	@echo ""
	@echo "Targets:"
	@echo "  make fetch                         Download glibc $(GLIBC_VERSION) into upstream/"
	@echo "  make unpack                        Extract glibc into build/src/"
	@echo "  make apply-patches                 Apply every patch from patches/glibc/"
	@echo "  make build-gcc-target              Fetch, patch, and build GCC for $(TARGET)"
	@echo "  make build-glibc-target            Patch, configure, and bootstrap glibc for $(TARGET)"
	@echo "  make sync-glibc-install            Copy built glibc runtime/dev artifacts into build/glibc-root/"
	@echo "  make sync-gcc-sysroot              Replace the GCC target sysroot with build/glibc-root/"
	@echo "  make build-dpkbuild               Fetch and build dpkbuild locally if needed"
	@echo "  make stage-runtime PREFIX=/path    Stage runtime files into packages/glibc-runtime/payload/"
	@echo "  make stage-devel PREFIX=/path      Stage headers/libs into packages/glibc-devel/payload/"
	@echo "  make dpk-runtime                   Build glibc-runtime .dpk"
	@echo "  make dpk-devel                     Build glibc-devel .dpk"
	@echo "  make dpk                           Build both .dpk packages"
	@echo "  make validate                      Validate manifests, scripts, and repo wiring"
	@echo "  make clean                         Remove build/ and dist/"
	@echo "  make distclean                     Remove build/, dist/, and upstream/"
	@echo ""
	@echo "Variables:"
	@echo "  GLIBC_VERSION=$(GLIBC_VERSION)"
	@echo "  GLIBC_PACKAGE_VERSION=$(GLIBC_PACKAGE_VERSION)"
	@echo "  GCC_VERSION=$(GCC_VERSION)"
	@echo "  TARGET=$(TARGET)"
	@echo "  ARCH=$(ARCH)"
	@echo "  GCC_PREFIX=$(GCC_PREFIX)"
	@echo "  SYSROOT=$(SYSROOT)"
	@echo "  DPKBUILD=$(DPKBUILD)"

fetch:
	@mkdir -p "$(UPSTREAM_DIR)"
	@/bin/bash scripts/fetch-glibc.sh "$(GLIBC_VERSION)" "$(UPSTREAM_ARCHIVE)"

unpack: $(UPSTREAM_ARCHIVE)
	@mkdir -p "$(BUILD_DIR)/src"
	@rm -rf "$(SOURCE_DIR)"
	@/bin/bash scripts/unpack-glibc.sh "$(UPSTREAM_ARCHIVE)" "$(BUILD_DIR)/src"
	@echo "[OK] Extracted $(UPSTREAM_ARCHIVE) -> $(SOURCE_DIR)"

apply-patches: unpack
	@/bin/bash scripts/apply-patches.sh "$(SOURCE_DIR)" "$(PATCHES_DIR)/glibc"

build-gcc-target:
	@/bin/bash scripts/build-gcc-target.sh \
		"$(CURDIR_ABS)" \
		"$(GCC_VERSION)" \
		"$(TARGET)" \
		"$(GCC_PREFIX)" \
		"$(SYSROOT)"

build-glibc-target:
	@/bin/bash scripts/build-glibc.sh \
		"$(CURDIR_ABS)" \
		"$(GLIBC_VERSION)" \
		"$(TARGET)" \
		"$(GCC_PREFIX)" \
		"$(SYSROOT)" \
		"$(BUILD_DIR)/glibc-root/$(TARGET)"

sync-glibc-install:
	@/bin/bash scripts/sync-glibc-install.sh \
		"$(BUILD_DIR)/glibc-build-$(TARGET)" \
		"$(BUILD_DIR)/glibc-root/$(TARGET)" \
		"$(SOURCE_DIR)"

sync-gcc-sysroot:
	@/bin/bash scripts/sync-gcc-sysroot.sh \
		"$(BUILD_DIR)/glibc-root/$(TARGET)" \
		"$(SYSROOT)" \
		"$(GCC_PREFIX)/bin/$(TARGET)-gcc"

build-dpkbuild:
	@/bin/bash scripts/build-dpkbuild.sh \
		"$(CURDIR_ABS)" \
		"$(DIMSIM_REPO_URL)" \
		"$(DIMSIM_DIR)"

stage-runtime:
	@test -n "$(PREFIX)" || { echo "PREFIX=/path/to/glibc-prefix is required"; exit 1; }
	@/bin/bash scripts/stage-package.sh runtime "$(PREFIX)" "$(RUNTIME_PKG)"

stage-devel:
	@test -n "$(PREFIX)" || { echo "PREFIX=/path/to/glibc-prefix is required"; exit 1; }
	@/bin/bash scripts/stage-package.sh devel "$(PREFIX)" "$(DEVEL_PKG)"

dpk-runtime: build-dpkbuild
	@mkdir -p "$(DIST_DIR)"
	@( cd "$(DIST_DIR)" && "$(DPKBUILD)" build "$(RUNTIME_PKG)" )

dpk-devel: build-dpkbuild
	@mkdir -p "$(DIST_DIR)"
	@( cd "$(DIST_DIR)" && "$(DPKBUILD)" build "$(DEVEL_PKG)" )

dpk: dpk-runtime dpk-devel
	@echo "[OK] .dpk archives written to $(DIST_DIR)"

validate:
	@/bin/bash scripts/validate.sh "$(CURDIR_ABS)"

clean:
	@rm -rf "$(BUILD_DIR)" "$(DIST_DIR)"

distclean: clean
	@rm -rf "$(UPSTREAM_DIR)"
