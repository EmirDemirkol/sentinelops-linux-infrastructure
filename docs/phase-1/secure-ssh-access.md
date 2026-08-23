# SentinelOps Secure SSH Access

## Purpose

This document records the implementation and verification of secure SSH administration for the SentinelOps Ubuntu Server virtual machine.

The work builds directly on the clean Linux baseline established in SEN-004.

The goal is to provide secure remote administration from the Mac host while preserving recovery access through the UTM console and avoiding unrelated infrastructure changes.

---

## Initial State

Before SEN-005:

- OpenSSH Server was not installed
- `ssh.service` was not present
- UFW was installed but inactive
- the named administrator account `emir` existed
- `emir` was a member of the `sudo` group
- no SSH key authentication was configured
- password-based remote access had not yet been introduced
- no firewall changes had been made

The Ubuntu VM remained reachable only through the local UTM console.

---

## Administrator Account

The existing administrator account was retained:

```text
emir
```

Observed identity:

```text
uid=1000(emir)
gid=1000(emir)
```

Relevant group membership included:

```text
sudo
```

The account retained administrative access through `sudo`.

Observed sudo capability:

```text
(ALL : ALL) ALL
```

No new privileged administrator account was created during this issue.

---

## OpenSSH Installation

OpenSSH Server was installed manually using the Ubuntu package manager.

The package installation completed successfully.

Ubuntu 24.04 configured SSH using systemd socket activation.

The SSH socket was enabled automatically and began listening on the standard SSH port:

```text
22/tcp
```

Observed listening addresses:

```text
0.0.0.0:22
[::]:22
```

This means the SSH socket was available on all IPv4 and IPv6 interfaces inside the VM.

---

## Socket-Activated SSH

The installed OpenSSH configuration uses `ssh.socket`.

Observed state:

```text
Loaded: loaded
Active: active (running)
Listen: 0.0.0.0:22
Listen: [::]:22
```

The `ssh.service` unit itself may remain inactive until a connection triggers it.

This is expected behaviour for the Ubuntu 24.04 installation used by SentinelOps.

---

## Initial SSH Connectivity Test

The first remote SSH test was performed from the Mac host.

The Mac connected to:

```text
192.168.64.2
```

using:

```text
emir
```

The first connection required host-key trust confirmation.

The ED25519 server host key was added to the Mac user's `known_hosts` file.

Password authentication was initially used for this first remote connection.

The connection succeeded and produced an interactive shell on:

```text
sentinelops-ubuntu
```

This confirmed that:

- the VM was reachable from the Mac host
- SSH transport was working
- the named administrator account could authenticate remotely
- port 22 was reachable through the UTM shared network

---

## SSH Key Authentication

The Mac already contained an SSH key pair:

```text
~/.ssh/id_rsa
~/.ssh/id_rsa.pub
```

The private key remained on the Mac.

Only the public key was copied to the Ubuntu administrator account.

The public key was installed for:

```text
emir
```

using the standard SSH authorized-keys mechanism.

The key was stored under the Ubuntu user's home directory in:

```text
/home/emir/.ssh/authorized_keys
```

No private key material was transferred to the Ubuntu VM.

No private key material was committed to Git.

---

## Key Authentication Verification

After the public key was installed, a second SSH connection was initiated from the Mac.

The connection succeeded without requesting the Ubuntu account password.

This verified successful public-key authentication from:

```text
Mac host -> SSH -> SentinelOps Ubuntu VM
```

The named administrator account reached:

```text
emir@sentinelops-ubuntu
```

using the configured SSH key.

---

## SSH Configuration Backup

Before applying SSH hardening, the original server configuration was backed up locally on the Ubuntu VM.

Backup file:

```text
/etc/ssh/sshd_config.backup
```

This backup provides a local recovery reference if later SSH configuration changes need to be compared or reverted.

The backup remains on the VM and is not committed to Git.

---

## SentinelOps SSH Hardening Configuration

A dedicated configuration file was created under:

```text
/etc/ssh/sshd_config.d/00-sentinelops.conf
```

This approach avoids unnecessary modification of the main distribution-provided `sshd_config` file.

The SentinelOps SSH hardening configuration is:

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
```

These settings implement the required access controls while retaining PAM account and session processing through the existing Ubuntu configuration.

---

## Root SSH Restriction

Direct root SSH login is disabled.

Effective configuration:

```text
permitrootlogin no
```

This ensures the root account cannot be used as a normal remote administrative entry point.

Administrative work must instead use the named administrator account and `sudo`.

---

## Password Authentication

Password-based SSH authentication is disabled.

Effective configuration:

```text
passwordauthentication no
```

This setting was not applied until key-based authentication from the Mac had already been tested successfully.

This sequencing reduced the risk of administrative lockout.

---

## Public-Key Authentication

Public-key authentication remains enabled.

Effective configuration:

```text
pubkeyauthentication yes
```

The Mac administrator workstation holds the private key.

The Ubuntu server stores only the corresponding public key.

---

## Keyboard-Interactive Authentication

Keyboard-interactive authentication is disabled.

Effective configuration:

```text
kbdinteractiveauthentication no
```

This prevents keyboard-interactive authentication from acting as an alternative password-based authentication path.

---

## Configuration Validation

Before applying the SSH hardening configuration, the SSH daemon configuration was validated.

The validation completed without output, which indicates valid SSH configuration syntax.

The effective SSH configuration was then inspected.

Observed values:

```text
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
kbdinteractiveauthentication no
```

These values match the intended SentinelOps SSH security baseline.

---

## Safe Restart Procedure

After configuration validation, the SSH service was restarted.

The existing SSH session was deliberately kept open during this step.

This preserved a known-good administrative session in case the new configuration prevented additional connections.

A second independent Mac Terminal window was then used to create a new SSH session.

The second connection succeeded using public-key authentication.

Only after the second connection succeeded was the hardened configuration considered operational.

---

## Password Login Rejection Verification

A test connection was attempted with public-key authentication explicitly disabled and password authentication explicitly requested.

The connection was rejected.

Observed result:

```text
Permission denied (publickey).
```

This confirms password-based SSH login is no longer available.

---

## Root Login Rejection Verification

A direct SSH connection was attempted using:

```text
root
```

The connection was rejected.

Observed result:

```text
Permission denied (publickey).
```

Combined with the effective configuration:

```text
permitrootlogin no
```

this confirms direct root SSH access is blocked.

---

## Sudo Verification

After SSH hardening, the `emir` account retained administrative capability.

Observed sudo configuration:

```text
User emir may run the following commands on sentinelops-ubuntu:

    (ALL : ALL) ALL
```

A privilege escalation test was also performed.

Observed result:

```text
root
```

This confirms the named administrator account can still perform required privileged administration using `sudo`.

---

## Recovery Access

The UTM console remains available as a local recovery path.

This is important because SSH is now restricted to key-based authentication.

If remote SSH configuration becomes unavailable in a later phase, the administrator can still access the VM locally through UTM.

No changes were made that remove or restrict UTM console login.

---

## Firewall State

UFW remained inactive throughout SEN-005.

Observed state:

```text
Status: inactive
```

No firewall rule was added, removed, or modified.

Firewall configuration remains reserved for the dedicated firewall hardening issue.

---

## Network State

The VM retained its existing UTM shared-network configuration.

Observed IPv4 address:

```text
192.168.64.2
```

No network-mode changes were made.

No static address was configured.

No port-forwarding configuration was introduced.

---

## Security Result

At the completion of SEN-005:

- OpenSSH Server is installed
- SSH is available through systemd socket activation
- port 22 is listening
- the Mac can reach the Ubuntu VM over SSH
- the named administrator account `emir` can authenticate remotely
- SSH key authentication is working
- the Mac private key remains on the Mac
- only the public key was copied to the server
- password SSH authentication is disabled
- keyboard-interactive authentication is disabled
- direct root SSH login is disabled
- `emir` retains working sudo access
- a second independent SSH session was successfully tested
- UTM console recovery access remains available
- UFW remains inactive
- no Docker configuration was introduced
- no Nginx configuration was introduced
- no application service was deployed
- no private key or secret material was added to Git

---

## Verification Summary

SEN-005 verification successfully demonstrated:

- SSH package installation
- SSH socket activation
- listening on TCP port 22
- successful initial Mac-to-VM SSH connection
- successful public-key installation
- successful key-based SSH login
- successful second independent SSH session
- valid SSH configuration syntax
- effective root-login restriction
- effective password-authentication restriction
- effective keyboard-interactive restriction
- working public-key authentication
- rejected forced-password SSH login
- rejected direct root SSH login
- retained sudo access
- retained UTM console recovery access
- unchanged firewall state

---

## Out of Scope

SEN-005 did not:

- enable UFW
- configure firewall rules
- install Nginx
- install Docker
- deploy an application
- configure monitoring
- configure backups
- introduce Ansible
- introduce Terraform
- change the UTM network mode
- introduce cloud infrastructure

These remain reserved for later SentinelOps issues.

---

## SEN-005 Completion State

SEN-005 establishes secure remote administration for the SentinelOps Ubuntu Server VM.

The server now supports named-administrator SSH access using public-key authentication while rejecting both password-based SSH login and direct root SSH login.

The UTM console remains available as a recovery path.

This provides the secure administrative foundation required before firewall and application-platform work begins.