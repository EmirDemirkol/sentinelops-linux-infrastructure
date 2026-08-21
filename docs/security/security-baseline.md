# SentinelOps Security Baseline

## Purpose

This document defines the minimum security baseline that the SentinelOps MVP must follow.

The baseline converts the Phase 0 threat model into concrete security requirements that later implementation phases must satisfy.

No security configuration is performed as part of this document.

---

# Security Baseline Goals

The SentinelOps security baseline should:

- apply least privilege
- minimise network exposure
- protect administrative access
- protect secrets and private keys
- reduce unsafe privilege escalation
- restrict container privileges
- protect logs and backups
- require configuration validation
- preserve administrator recovery access
- require security controls to be tested rather than assumed

---

# SB-01: Named Administrator Accounts

Normal administration shall use named administrator accounts.

The root account shall not be used as the normal interactive administration account.

Purpose:

- improve accountability
- reduce unnecessary direct root usage
- support clearer authentication and sudo logs

Verification:

- confirm the administrator account exists
- confirm normal SSH administration uses the named account
- confirm direct root SSH login is restricted

---

# SB-02: SSH Key Authentication

SSH administration shall use key-based authentication.

Password authentication shall only be disabled after key-based access has been confirmed successfully.

Purpose:

- reduce password-based authentication risk
- support stronger administrative authentication

Verification:

- confirm approved SSH key login succeeds
- confirm a second independent SSH session succeeds before closing the first
- later confirm password authentication is rejected after hardening

---

# SB-03: Restrict Direct Root SSH Login

Direct remote root login shall be disabled or otherwise restricted.

Purpose:

- reduce direct privileged account exposure
- encourage controlled privilege escalation

Verification:

- attempt direct root SSH login
- confirm the connection is rejected

---

# SB-04: Preserve Emergency Recovery Access

SSH hardening shall not be performed without a recovery path.

The project shall retain VM console access while remote-access changes are being tested.

Purpose:

- prevent permanent administrator lockout
- provide a recovery mechanism if SSH becomes unavailable

Verification:

- confirm the virtualisation platform provides console access
- document the recovery procedure before disabling password authentication

---

# SB-05: Controlled Sudo Access

Administrative privilege escalation shall use controlled sudo access.

Sudo permissions should be limited to users and groups with a documented administrative requirement.

Purpose:

- reduce unnecessary root-level access
- improve accountability
- support least privilege

Verification:

- inspect sudo-capable users and groups
- verify ordinary users cannot perform privileged operations
- review relevant sudo logging

---

# SB-06: Least-Privilege Users and Groups

Users and groups shall receive only the access required for their role.

The project should distinguish between:

- administrator access
- application ownership
- ordinary unprivileged access

Purpose:

- reduce accidental or malicious modification
- create clear responsibility boundaries

Verification:

- inspect account and group membership
- test protected operations using an unprivileged account

---

# SB-07: Protected File Ownership and Permissions

Infrastructure configuration, operational logs, and backups shall use restrictive ownership and permissions.

Protected files should not be writable by ordinary users.

Purpose:

- prevent unauthorised modification
- protect operational evidence
- protect recoverable data

Verification:

- inspect ownership and permissions
- attempt modification using an unprivileged account

---

# SB-08: Default-Deny Inbound Firewall

UFW shall use a deny-by-default inbound policy.

Purpose:

- reduce network attack surface
- ensure every allowed inbound service has an explicit reason

Verification:

- inspect UFW default policy
- test approved and blocked ports

---

# SB-09: Only Required Inbound Ports

Only required inbound services shall be allowed.

The expected initial MVP inbound exposure is:

```text
22/TCP  SSH
80/TCP  HTTP through Nginx
```

Possible later exposure:

```text
443/TCP HTTPS
```

All other inbound ports should remain blocked unless a documented requirement is introduced.

Verification:

- inspect firewall rules
- inspect listening sockets
- test network reachability from the MacBook

---

# SB-10: Private Application Port

The application container port shall not be directly accessible from outside the Ubuntu VM.

Nginx shall remain the approved application-facing entry point.

Purpose:

- reduce attack surface
- prevent bypassing the reverse proxy
- keep a single controlled request path

Verification:

- confirm the application works through Nginx
- attempt direct access to the application port from the MacBook and confirm failure

---

# SB-11: Configuration Validation Before Reload

Service configuration shall be validated before reload or restart where the service supports validation.

This is especially important for Nginx.

Purpose:

- reduce preventable outages
- detect syntax errors before applying unsafe configuration

Verification:

- run the supported configuration validation command
- introduce a controlled invalid configuration during a later failure exercise
- confirm the invalid configuration is detected before reload

---

# SB-12: Restrict Docker Access

Docker administration shall be treated as privileged access.

Ordinary users shall not receive Docker group membership without a documented reason.

Purpose:

- Docker access can effectively provide host-level privilege
- restrict unnecessary control over containers and host resources

Verification:

- inspect Docker group membership
- confirm ordinary users cannot manage Docker

---

# SB-13: Avoid Privileged Containers

Application containers shall not run in privileged mode unless a future documented requirement justifies it.

Purpose:

- reduce host compromise risk
- maintain stronger container isolation

Verification:

- inspect Docker or Docker Compose configuration
- confirm privileged mode is not enabled

---

# SB-14: Avoid Unnecessary Host Filesystem Mounts

Containers shall mount only the host paths required for documented application behaviour.

Dangerous broad mounts should be avoided.

Purpose:

- reduce container access to host data
- reduce tampering risk

Verification:

- review container mount configuration
- document the reason for each host mount

---

# SB-15: Do Not Expose the Docker Socket to the Application

The application container shall not receive access to the Docker daemon socket.

Purpose:

- Docker socket access could allow control over the host container runtime
- reduce elevation-of-privilege risk

Verification:

- inspect container mounts and configuration
- confirm `/var/run/docker.sock` is not mounted into the application container

---

# SB-16: Secrets Must Remain Outside Source Control

Real secrets shall not be committed to the repository.

This includes:

- private SSH keys
- real passwords
- GitHub tokens
- cloud access keys
- API secrets
- production credentials

Purpose:

- prevent credential exposure through Git history or repository access

Verification:

- review staged changes before commit
- search repository contents and history for secret patterns
- use secret scanning later where practical

---

# SB-17: Use Placeholder Configuration

Where environment variables or secrets are required, the repository should contain examples rather than real values.

Example:

```text
.env.example
```

Purpose:

- document required configuration without exposing secrets

Verification:

- confirm example files contain synthetic placeholders only
- confirm real `.env` files remain ignored

---

# SB-18: Protect SSH Private Keys

SSH private keys must remain outside the SentinelOps repository.

Local key files should use restrictive permissions.

Purpose:

- prevent unauthorised server access

Verification:

- inspect local SSH key permissions
- confirm key files are not tracked by Git

---

# SB-19: Protect Operational Logs

Operational logs shall not be writable by ordinary users where integrity matters.

Relevant logs include:

- authentication logs
- system logs
- Nginx logs
- monitoring logs
- backup logs

Purpose:

- preserve incident evidence
- reduce log tampering

Verification:

- inspect ownership and permissions
- attempt modification using an unprivileged account

---

# SB-20: Avoid Logging Secrets

Passwords, tokens, private keys, and other secrets shall not be written to logs.

Purpose:

- reduce information disclosure
- prevent credentials from appearing in troubleshooting output

Verification:

- inspect logs during normal operation
- inspect logs during failure simulations

---

# SB-21: Protect Backup Storage

Backup archives shall use restrictive ownership and permissions.

Ordinary users should not be able to read, modify, or delete protected backup archives.

Purpose:

- protect data confidentiality
- protect recoverability
- reduce tampering risk

Verification:

- inspect backup directory ownership and permissions
- attempt unauthorised access using an ordinary user

---

# SB-22: Backup Integrity Verification

Backup archives shall use integrity checksums.

Purpose:

- detect corruption
- detect unauthorised modification
- prevent restoration from unverified archives

Verification:

- verify a valid backup checksum
- deliberately modify a test archive and confirm validation failure

---

# SB-23: Backup Manifests

Backups shall provide a clear record of their intended contents.

Purpose:

- make restoration predictable
- identify missing or unexpected data

Verification:

- review a generated backup manifest
- compare the manifest with archive contents

---

# SB-24: Restoration Testing Is Mandatory

A backup shall not be considered proven until restoration succeeds.

Purpose:

- prevent false confidence from successful archive creation alone

Verification:

- delete or alter synthetic test data
- restore from backup
- validate restored data and application behaviour

---

# SB-25: Synthetic Data Only

SentinelOps shall use synthetic application data for demonstrations, testing, backup, and destructive recovery exercises.

Purpose:

- avoid exposing personal, employer, or confidential information
- keep destructive testing safe

Verification:

- review application fixtures and demonstration data
- confirm no real sensitive data is stored

---

# SB-26: Minimise Installed Software

Only packages and services required for the project should be installed.

Purpose:

- reduce attack surface
- reduce maintenance burden
- improve explainability

Verification:

- review installed project dependencies
- document why major packages are required

---

# SB-27: Trusted Package Sources

Operating-system packages and dependencies should come from trusted sources.

Purpose:

- reduce supply-chain risk

Verification:

- record important package sources
- avoid unnecessary third-party repositories

---

# SB-28: Trusted Container Images

Container images should use reputable sources and minimal base images where practical.

Purpose:

- reduce supply-chain risk
- reduce unnecessary software inside containers

Verification:

- document the chosen base image
- review image source and tag
- introduce security scanning later if useful

---

# SB-29: Version Control for Infrastructure Configuration

Important infrastructure configuration shall be stored in Git where appropriate.

Purpose:

- provide change history
- support rollback
- make configuration review possible

Verification:

- confirm project configuration is tracked
- review Git history during controlled configuration changes

---

# SB-30: Small and Reviewable Changes

Infrastructure changes should be performed in small, meaningful units.

Purpose:

- simplify troubleshooting
- reduce accidental changes
- improve rollback capability

Verification:

- use focused GitHub Issues
- use clear commit messages
- review diffs before commits

---

# SB-31: CI Validation Before MVP Release

The repository shall use automated validation before the MVP is considered complete.

Planned checks include:

- shell validation
- container configuration validation
- application testing
- secret checks where practical

Purpose:

- detect common errors before changes are accepted

Verification:

- confirm required GitHub Actions checks pass on the default branch

---

# SB-32: Security-Relevant Changes Require Verification

Security configuration must not be considered complete simply because it was applied.

Each major security control must have a corresponding verification step.

Examples:

- SSH key login test
- root login rejection
- firewall port test
- ordinary-user permission test
- application-port exposure test
- backup checksum test

Purpose:

- distinguish implemented controls from assumed controls

---

# SB-33: Destructive Testing Requires Recovery Preparation

Before destructive failure simulations:

- backups should exist where relevant
- recovery steps should be known
- synthetic data should be used
- VM console access should remain available where required

Purpose:

- prevent controlled experiments from becoming unrecoverable failures

Verification:

- complete the safety checklist before each destructive scenario

---

# SB-34: Monitor Disk Capacity

Disk usage shall be monitored.

Purpose:

- reduce denial-of-service risk from full disks
- protect logging and backup operations

Verification:

- confirm disk checks operate
- safely trigger the documented warning threshold

---

# SB-35: Control Log and Backup Growth

Logs and backup archives shall not grow without limit.

Purpose:

- reduce disk exhaustion risk

Planned controls:

- log rotation where appropriate
- backup retention
- monitoring of disk usage

Verification:

- confirm retention behaviour
- review log rotation configuration later
- inspect disk usage during failure simulations

---

# SB-36: Maintain Auditability

Important administrative and operational actions should leave enough evidence for later troubleshooting.

Expected evidence includes:

- authentication logs
- sudo logs
- Nginx logs
- container logs
- monitoring logs
- backup logs
- Git history

Purpose:

- support incident diagnosis
- support accountability

Verification:

- perform a controlled action
- identify the relevant evidence afterward

---

# SB-37: Maintain Documentation Consistency

Security documentation shall be updated when implementation decisions change.

Purpose:

- prevent outdated security assumptions
- ensure the threat model reflects the real environment

Verification:

- compare implementation against security documentation before each phase closes

---

# SB-38: Do Not Claim Production-Grade Security

SentinelOps is an educational infrastructure lab.

The MVP shall not claim:

- enterprise-grade security
- high availability
- complete disaster recovery
- formal compliance
- penetration-test certification
- production security guarantees

Purpose:

- keep claims accurate
- prevent portfolio overstatement

---

# Minimum Security Verification Set

Before MVP completion, the following controls should be demonstrated:

1. approved SSH key login succeeds
2. password SSH login is rejected after hardening
3. direct root SSH login is rejected
4. ordinary users cannot modify protected configuration
5. UFW uses a default-deny inbound policy
6. only approved inbound ports are reachable
7. the application port is not reachable directly
8. Docker group membership is restricted
9. the application container is not privileged
10. the Docker socket is not exposed to the application
11. private keys and secrets are absent from Git
12. logs use protected ownership and permissions
13. backup archives use protected ownership and permissions
14. backup checksum validation succeeds
15. corrupted backup validation fails
16. restoration succeeds using synthetic data
17. invalid Nginx configuration is detected before reload
18. monitoring detects a stopped application
19. monitoring detects a disk threshold warning
20. CI validation passes before the MVP release

---

# Security Baseline Review Points

The security baseline should be reviewed:

- before Phase 1 implementation
- before SSH hardening
- before enabling UFW
- before Docker deployment
- before application exposure
- before backup implementation
- before failure simulations
- before GitHub Actions security validation
- before any cloud deployment
- before MVP release

Any implementation decision that changes the security posture should trigger a review of this document.

---

# Baseline Acceptance Principle

A security control is considered complete only when:

1. the intended control is documented
2. the control is implemented
3. the control is verified
4. the result is recorded or demonstrated
5. the recovery or rollback path is understood where relevant

Configuration alone is not sufficient evidence.