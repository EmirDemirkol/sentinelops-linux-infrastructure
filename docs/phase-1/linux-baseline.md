# SentinelOps Linux Baseline

## Purpose

This document records the initial manual Linux baseline for the SentinelOps Ubuntu Server virtual machine.

The purpose of this baseline is to capture the system state before later infrastructure configuration begins.

At this stage:

- no SSH server has been installed
- UFW has not been enabled
- Nginx has not been installed
- Docker has not been installed
- no application services have been deployed
- no infrastructure hardening has been applied
- no provisioning automation has been introduced

The baseline provides a known starting point that later SentinelOps changes can be compared against.

---

## Virtual Machine Overview

The SentinelOps MVP begins with a single Ubuntu Server virtual machine running locally through UTM on an Apple Silicon MacBook.

### VM Configuration

- VM name: `SentinelOps-Ubuntu`
- Virtualization engine: QEMU
- Architecture: ARM64 / AArch64
- CPU allocation: 2 virtual CPU cores
- Memory allocation: 3 GB
- Virtual disk: 30 GB
- Network mode: UTM Shared Network
- Network adapter: `virtio-net-pci`
- Shared directory: disabled
- Installation medium removed after installation

The VM is intentionally small because the initial SentinelOps environment is designed as a focused Linux infrastructure lab rather than a large production workload.

---

## Operating System

Observed operating-system information:

- Distribution: Ubuntu
- Version: Ubuntu 24.04.4 LTS
- Codename: Noble Numbat
- Version ID: `24.04`
- Architecture: `arm64` / `aarch64`
- Kernel: Linux `6.8.0-138-generic`
- Virtualization platform: QEMU

The system is running the normal Ubuntu Server installation rather than the minimized installation.

No Ubuntu Pro subscription was attached during installation.

---

## System Identity

### Hostname

The configured hostname is:

```text
sentinelops-ubuntu
```

### Administrator Account

The initial named administrator account is:

```text
emir
```

Observed account information:

- UID: `1000`
- primary GID: `1000`
- primary group: `emir`
- home directory: `/home/emir`
- login shell: `/bin/bash`

The administrator account is a member of the following groups:

```text
emir
adm
cdrom
sudo
dip
plugdev
lxd
```

The account has access to `sudo`.

Observed sudo capability:

```text
(ALL : ALL) ALL
```

This represents the initial installation state.

No sudo restriction or least-privilege refinement has yet been applied.

---

## Home Directory Permissions

The administrator home directory is:

```text
/home/emir
```

Observed permissions:

```text
drwxr-x---
```

This means:

- the owner has read, write, and execute permissions
- the owning group has read and execute permissions
- other users have no access

The visible contents of the home directory were empty at the time of baseline inspection.

---

## CPU Baseline

Ubuntu detected:

```text
2
```

available processing units.

This matches the two virtual CPU cores allocated in UTM.

---

## Memory Baseline

Observed memory state shortly after installation:

```text
Total memory: approximately 2.9 GiB
Used memory: approximately 225 MiB
Available memory: approximately 2.7 GiB
Swap: approximately 2.7 GiB
```

Memory utilisation was low and consistent with a newly installed server with no application workload.

---

## Storage Baseline

The VM uses one 30 GB virtual disk.

Observed block-device layout:

```text
vda
├── vda1
├── vda2
└── vda3
    └── ubuntu--vg-ubuntu--lv
```

### Partition Layout

Observed layout:

- `/boot/efi`: approximately 1 GB
- `/boot`: approximately 2 GB
- LVM physical volume: approximately 26.9 GB
- root logical volume: approximately 13.5 GB

Ubuntu created an LVM volume group named:

```text
ubuntu-vg
```

and a logical volume named:

```text
ubuntu-lv
```

Approximately half of the LVM volume-group capacity remained unallocated after installation, leaving room for later logical-volume expansion if required.

### Root Filesystem Usage

Observed shortly after installation:

```text
Filesystem size: approximately 14 GB
Used: approximately 5.4 GB
Available: approximately 7.2 GB
Usage: approximately 43%
```

The root filesystem is mounted at:

```text
/
```

---

## Network Baseline

The VM uses UTM Shared Network mode.

The primary network interface is:

```text
enp0s1
```

### IPv4 Address

Observed IPv4 address:

```text
192.168.64.2/24
```

The address was assigned dynamically using DHCP.

### Default Gateway

Observed default gateway:

```text
192.168.64.1
```

### DNS

Observed DNS server:

```text
192.168.64.1
```

The VM successfully obtained working network connectivity through the UTM shared network.

No bridged network configuration was used.

---

## Listening Network Services

The listening-socket baseline showed only normal local system networking and resolver-related sockets.

No SentinelOps application service was listening.

The following had not yet been installed or exposed:

- SSH server
- Nginx
- Docker
- application container
- monitoring services

This confirms that later-phase infrastructure had not been introduced prematurely.

---

## Time Configuration

The system timezone was:

```text
Etc/UTC
```

Observed time status:

```text
System clock synchronized: yes
NTP service: active
RTC in local TZ: no
```

The `systemd-timesyncd` service was running successfully.

The service contacted an Ubuntu NTP server and completed initial clock synchronization.

---

## System Services

The system was inspected immediately after installation.

Observed result:

```text
0 failed units
```

Core running services included:

- `cron.service`
- `dbus.service`
- `getty@tty1.service`
- `ModemManager.service`
- `multipathd.service`
- `polkit.service`
- `rsyslog.service`
- `systemd-journald.service`
- `systemd-logind.service`
- `systemd-networkd.service`
- `systemd-resolved.service`
- `systemd-timesyncd.service`
- `systemd-udevd.service`
- `udisks2.service`
- `unattended-upgrades.service`
- `user@1000.service`

The exact running-service list may change after package updates or later infrastructure phases.

---

## Process Baseline

The system process table was reviewed after installation.

Expected operating-system processes were present, including:

- kernel worker processes
- systemd
- journald
- network services
- cron
- rsyslog
- login services
- user session processes

No unexpected SentinelOps application or infrastructure processes were present.

---

## Package Baseline

The installed package database was inspected successfully.

Standard Ubuntu Server packages were present, including:

- `adduser`
- `apparmor`
- `apt`
- `apt-utils`
- `base-files`
- `base-passwd`
- `bash`
- `bash-completion`
- `bind9-dnsutils`
- `busybox-initramfs`
- `busybox-static`

The exact package inventory is significantly larger than this representative sample.

---

## Pending Updates

The fresh installation reported multiple packages available for upgrade.

At the time of inspection:

```text
39 updates were reported as available.
```

The available updates included system and operating-system components such as:

- AppArmor
- cloud-init
- console setup
- core utilities
- fwupd
- keyboard configuration
- Kerberos libraries
- Netplan
- Plymouth
- Python support packages
- Snapd
- systemd hardware database
- Ubuntu driver components

These updates were intentionally observed before performing package maintenance so that the original installation state could be documented.

Package updating will be handled as an explicit later step rather than being silently mixed into baseline discovery.

---

## Sudo Baseline

The named administrator account can currently execute commands through `sudo`.

Observed configuration:

```text
User emir may run the following commands on sentinelops-ubuntu:

    (ALL : ALL) ALL
```

This is the default administrative capability created during installation.

It is recorded as baseline state and is not yet treated as the final SentinelOps least-privilege configuration.

---

## Firewall Baseline

UFW is available on the system but is currently:

```text
Status: inactive
```

This is intentional.

The firewall has not yet been enabled because firewall policy and safe administrative access will be introduced and verified during the appropriate security implementation work.

---

## SSH Baseline

The OpenSSH server was deliberately not installed during Ubuntu installation.

Observed result:

```text
Unit ssh.service could not be found.
```

No `sshd` executable was returned during baseline verification.

This confirms that remote SSH administration has not yet been introduced.

SSH will be implemented manually and verified during later security work.

---

## Nginx Baseline

Nginx is not installed.

No `nginx` executable was detected during baseline verification.

Nginx will be introduced only when the reverse-proxy and application-platform phase begins.

---

## Docker Baseline

Docker is not installed.

No `docker` executable was detected during baseline verification.

Docker and Docker Compose will be introduced during the application-platform phase rather than during the initial Linux baseline.

---

## Environment Baseline

The environment for the administrator account showed expected Ubuntu shell variables, including:

```text
SHELL=/bin/bash
PWD=/home/emir
LOGNAME=emir
HOME=/home/emir
LANG=en_US.UTF-8
USER=emir
TERM=linux
```

The session was running directly through the UTM virtual console.

No SentinelOps application environment variables or secrets had been configured.

---

## Observed Warnings

The boot journal contained several warnings.

One notable warning was:

```text
PAM unable to dlopen(pam_lastlog.so)
PAM adding faulty module: pam_lastlog.so
```

The administrator was still able to authenticate successfully and no failed systemd units were reported.

The warning is recorded as baseline evidence.

No PAM configuration was modified during SEN-004 because authentication hardening and troubleshooting should not be mixed into initial baseline discovery without a specific requirement and verification plan.

Other boot warnings were also observed, including messages related to:

- device mapper IMA configuration
- LVM initialization
- an unset `cron.service` environment variable
- suppressed kernel audit callbacks

These observations did not prevent normal server operation during baseline verification.

---

## Security State

At the completion of the baseline:

- a named administrator account exists
- normal administration does not require direct root login
- the administrator can use `sudo`
- SSH server is not installed
- UFW is inactive
- Docker is not installed
- Nginx is not installed
- no application service is deployed
- no shared Mac directory is mounted inside the VM
- no real application credentials are stored on the server
- no infrastructure secrets were added to Git
- system time synchronization is active
- no failed systemd units were reported

This represents the clean pre-hardening state of the SentinelOps Ubuntu VM.

---

## Baseline Verification Summary

The following baseline characteristics were successfully verified:

- Ubuntu Server boots successfully from its virtual disk
- the installation ISO has been removed
- the server hostname is configured
- the named administrator account works
- CPU and memory allocations match the planned VM configuration
- storage and LVM layout are operational
- the root filesystem is mounted successfully
- networking through UTM Shared Network works
- DHCP addressing works
- DNS configuration is present
- the default route is configured
- system time is synchronized
- no failed systemd units are present
- standard Ubuntu services are running
- the package database is accessible
- pending updates are visible
- UFW remains inactive
- SSH server remains absent
- Docker remains absent
- Nginx remains absent
- no later-phase services were introduced

---

## SEN-004 Completion State

SEN-004 establishes the initial manual Linux baseline only.

The issue does not:

- harden SSH
- enable the firewall
- install Docker
- install Nginx
- deploy an application
- configure monitoring
- configure backups
- introduce automation

The resulting environment provides a clean and documented Ubuntu Server foundation for later SentinelOps implementation work.