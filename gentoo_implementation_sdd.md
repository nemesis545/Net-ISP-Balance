# Software Design Document (SDD)
## Net-ISP-Balance Implementation on Gentoo Linux

### 1. Introduction
**Purpose:** 
This document outlines the software design and execution plan for adapting the `Net-ISP-Balance` project for native execution and package management on Gentoo Linux.

**Scope:** 
The scope encompasses modifying Perl scripts for path detection, adapting build scripts for Gentoo Portage compliance, creating OpenRC init scripts, and developing a native Gentoo `.ebuild` package.

---

### 2. Architecture & Design Changes

#### 2.1 Configuration Paths
- **Current:** Hardcoded detection for `/etc/network` (Debian) and `/etc/sysconfig/network-scripts` (RedHat). Defaults to `/etc`.
- **Target Design:** Introduce a standard base configuration directory specific to this application (e.g., `/etc/net-isp-balance`) to align with Gentoo's modular `/etc` structure and avoid polluting the `/etc` root directory.

#### 2.2 Service Management
- **Current:** SysV init (`foolsm.init`) and systemd unit (`foolsm.service`).
- **Target Design:** Create a native OpenRC script (`/etc/init.d/foolsm`) using Gentoo's standard `start-stop-daemon` to manage the lifecycle of the link status monitor daemon.

#### 2.3 Network Lifecycle Hooks
- **Current:** Assumes Debian's `if-up.d/` hooks.
- **Target Design:** Integrate via Gentoo's `netifrc` scripts. Documentation will be provided to hook the balancer into the `/etc/conf.d/net` `postup()` and `postdown()` functions.

---

### 3. Code Modifications

#### 3.1 `lib/Net/ISP/Balance.pm`
- Modify the `install_etc` subroutine.
- Introduce a check for Gentoo (e.g., checking for the existence of `/etc/gentoo-release`).
- Set the fallback configuration path to `/etc/net-isp-balance` rather than `/etc`.

#### 3.2 `Build.PL`
- Remove or condition the `ACTION_install` hooks that execute system commands (`mkdir /var/lib/lsm` and `chmod`).
- In a Gentoo environment, directory creation and permission modifications must be handled by the package manager (Portage) during the `pkg_postinst` or `src_install` phases.

#### 3.3 `lsm/Makefile`
- **CC Overrides:** Replace `CC = gcc` with `CC ?= gcc` so Portage's `tc-getCC` toolchain function can override it.
- **CFLAGS/LDFLAGS:** Change `override CFLAGS += ...` to allow Portage to securely append system-wide optimization flags defined by the user in `make.conf`.

---

### 4. Packaging Design (Ebuild)

A new `net-misc/net-isp-balance` ebuild will be authored.

- **Eclasses:** Inherit `perl-module` and `toolchain-funcs`.
- **Dependencies:** 
  - `dev-perl/Module-Build`
  - `dev-perl/Net-Netmask`
  - `dev-perl/Net-Subnet`
  - `virtual/perl-Pod-Usage`
  - `virtual/perl-DB_File`
  - `sys-apps/iproute2`
  - `net-firewall/iptables`
- **src_prepare Phase:** Apply patches for `Build.PL`, `Balance.pm`, and `Makefile`.
- **src_compile Phase:** Compile the Perl module and trigger `make` for the `lsm` C binary using appropriate `emake` wrappers.
- **src_install Phase:** 
  - Use `perl_rm_files` to clean up unnecessary artifacts.
  - Call `keepdir /var/lib/lsm`.
  - Install the OpenRC init script via `doinitd`.
  - Install configurations to `/etc/net-isp-balance`.

---

### 5. Task Breakdown & Execution Plan

* **Task 1: Code patching for Paths**
  - Patch `lib/Net/ISP/Balance.pm` to route configs to `/etc/net-isp-balance`.
* **Task 2: Build System Fixes**
  - Patch `Build.PL` to remove strict `ACTION_install` filesystem mutations.
  - Patch `lsm/Makefile` for CC and CFLAGS compliance.
* **Task 3: OpenRC Integration**
  - Draft `/etc/init.d/foolsm` OpenRC script.
* **Task 4: Ebuild Creation**
  - Draft the `net-isp-balance-1.33.ebuild`.
* **Task 5: Documentation**
  - Write a `README.Gentoo` detailing how to hook `load_balance.pl` into `/etc/conf.d/net`.
* **Task 6: Local Overlay Testing**
  - Run `ebuild net-isp-balance-1.33.ebuild manifest clean merge` in a local portage overlay to verify compilation and installation.

---

### 6. Acceptance Criteria
1. The `lsm` binary compiles successfully under Gentoo Portage using user-defined `CFLAGS`.
2. Installation via `emerge` completes without sandbox violations.
3. `/var/lib/lsm` and configuration files are placed securely with appropriate ownership.
4. The `foolsm` service can be started and stopped cleanly via `rc-service foolsm start|stop`.
