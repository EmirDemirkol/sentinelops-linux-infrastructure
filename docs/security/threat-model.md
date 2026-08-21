# SentinelOps Threat Model

## Purpose

This document defines the initial threat model for the SentinelOps MVP.

The goal is to identify important assets, realistic threat actors, trust boundaries, likely security threats, planned controls, and verification methods before implementation begins.

This is a defensive design document.

No security configuration is performed as part of this document.

---

# Threat Model Scope

The threat model covers the SentinelOps MVP architecture, including:

- the MacBook administrator workstation;
- the Ubuntu Server VM;
- SSH administration;
- UFW firewall controls;
- Nginx;
- Docker;
- the SentinelOps application;
- monitoring;
- logs;
- backups;
- restoration;
- GitHub repository content;
- CI configuration;
- environment variables and secrets.

The threat model does not claim to represent a production enterprise security assessment.

---

# Security Objectives

SentinelOps should protect:

- confidentiality of credentials and sensitive configuration;
- integrity of the operating system and infrastructure configuration;
- integrity of logs and backups;
- availability of the hosted application;
- availability of administrative access;
- recoverability of synthetic application data;
- integrity of source-controlled project files.

The project should also reduce:

- unnecessary privilege;
- unnecessary network exposure;
- unsafe container permissions;
- accidental destructive changes;
- unverified recovery assumptions.

---

# Assets

## A-01: SSH Private Keys

SSH private keys provide administrative access to the Ubuntu VM.

Compromise could allow unauthorised server access.

---

## A-02: Administrator Access

Named administrator accounts and their privileges must be protected from misuse.

---

## A-03: Operating-System Integrity

The Ubuntu operating system must remain free from unauthorised or accidental destructive modification.

---

## A-04: SSH Configuration

SSH configuration controls remote administrative access.

Incorrect or malicious modification could cause compromise or administrator lockout.

---

## A-05: Firewall Configuration

UFW configuration determines which services are reachable.

Incorrect rules could expose unnecessary services or block legitimate administration.

---

## A-06: Nginx Configuration

Nginx configuration controls the main application-facing entry point.

Incorrect configuration could cause service interruption or unintended exposure.

---

## A-07: Docker Configuration

Docker configuration controls application runtime behaviour and can influence host security.

---

## A-08: Application Availability

The application should remain accessible through the intended Nginx path.

---

## A-09: Application Data

Synthetic application data must remain recoverable and protected from accidental loss.

---

## A-10: Monitoring Logs

Monitoring logs provide evidence about service and resource health.

Tampering could hide failures.

---

## A-11: Authentication and System Logs

System logs help explain access attempts, privilege usage, and incidents.

---

## A-12: Backup Archives

Backup archives must remain readable, intact, and restorable.

---

## A-13: Backup Checksums and Manifests

Integrity metadata must remain trustworthy so corrupted or modified backups can be detected.

---

## A-14: Restoration Procedures

Recovery instructions must remain accurate and protected from unsafe modification.

---

## A-15: Git Repository Integrity

Repository content must accurately represent intended infrastructure configuration and documentation.

---

## A-16: GitHub Actions Configuration

CI workflows must not introduce unsafe behaviour or expose secrets.

---

## A-17: Environment Variables and Secrets

Any future runtime secrets must remain outside source control and inaccessible to unauthorised users.

---

# Threat Actors

## TA-01: Opportunistic External Attacker

An attacker attempting to discover and access exposed services.

---

## TA-02: Automated Scanning Bot

Automated systems that scan reachable hosts and services for common weaknesses.

---

## TA-03: Malicious Local User

A user with legitimate local access attempting to exceed authorised privileges.

---

## TA-04: Careless Local User

A legitimate user who accidentally modifies, deletes, exposes, or misconfigures resources.

---

## TA-05: Project Operator Error

The administrator may accidentally apply unsafe commands or configuration.

This is one of the most realistic threats in the lab.

---

## TA-06: Compromised Container Image

A container image may contain vulnerable or malicious software.

---

## TA-07: Vulnerable or Malicious Dependency

A package or dependency may introduce security weaknesses.

---

## TA-08: Untrusted Repository Change

A future contribution or accidental commit may introduce unsafe configuration, secrets, or broken automation.

---

## TA-09: Excessively Privileged Process

A service or container running with unnecessary privileges may cause wider system compromise if exploited.

---

# Trust Boundaries

## TB-01: MacBook to Ubuntu VM

Separates the administrator workstation from the server.

Primary concerns:

- stolen SSH credentials;
- incorrect network exposure;
- unauthorised administration.

---

## TB-02: Network to UFW

Separates inbound traffic from server services.

Primary concerns:

- unnecessary exposed ports;
- firewall mistakes;
- automated scanning.

---

## TB-03: UFW and Nginx to Docker Application

Separates application-facing traffic from the containerised service.

Primary concerns:

- bypassing Nginx;
- direct application exposure;
- proxy misconfiguration.

---

## TB-04: Administrator Shell to Privileged Operations

Separates ordinary administration from root-level system modification.

Primary concerns:

- excessive sudo rights;
- accidental destructive commands;
- privilege escalation.

---

## TB-05: Docker Container to Ubuntu Host

Separates containerised application execution from the host operating system.

Primary concerns:

- privileged containers;
- dangerous mounts;
- Docker socket exposure;
- excessive Docker group membership.

---

## TB-06: Running Services to Logs and Backup Storage

Separates operational processes from evidence and recoverable data.

Primary concerns:

- tampering;
- deletion;
- information disclosure;
- disk exhaustion.

---

## TB-07: GitHub Repository to Runtime Environment

Separates source-controlled project changes from the running infrastructure.

Primary concerns:

- committed secrets;
- malicious dependencies;
- unsafe automation;
- unreviewed configuration.

---

# Threat Register

## T-01: Unauthorised SSH Authentication

**Category:** Spoofing

**Scenario:**
An attacker attempts to gain shell access using passwords, guessed credentials, or unauthorised accounts.

**Assets affected:**

- administrator access;
- operating-system integrity;
- application availability;
- configuration integrity.

**Impact:** High

**Planned controls:**

- SSH key authentication;
- named administrator accounts;
- direct root SSH restriction;
- password authentication disabled only after key access is verified;
- limited network exposure;
- review authentication logs.

**Verification:**

- attempt password authentication after hardening and confirm rejection;
- attempt direct root SSH login and confirm rejection;
- verify approved key authentication still succeeds.

---

## T-02: SSH Private Key Exposure

**Category:** Spoofing / Information Disclosure

**Scenario:**
An administrator SSH private key is committed to Git, copied insecurely, or becomes readable by unauthorised users.

**Assets affected:**

- SSH private keys;
- administrator access;
- server integrity.

**Impact:** High

**Planned controls:**

- never commit private key files;
- `.gitignore` patterns;
- restrictive local key permissions;
- optional key passphrase;
- documented replacement procedure;
- later secret scanning.

**Verification:**

- inspect repository for key files;
- review file permissions;
- confirm private keys are stored outside the repository.

---

## T-03: Unsafe Root or Sudo Usage

**Category:** Elevation of Privilege

**Scenario:**
Users receive more privileged access than required, or unrestricted sudo usage causes accidental or malicious system changes.

**Assets affected:**

- operating-system integrity;
- configuration;
- logs;
- backups;
- application availability.

**Impact:** High

**Planned controls:**

- named administrator accounts;
- controlled sudo usage;
- least privilege;
- review group membership;
- avoid ordinary root sessions;
- document privileged operations.

**Verification:**

- inspect sudo configuration;
- test ordinary-user access;
- review administrator group membership.

---

## T-04: SSH Hardening Causes Administrator Lockout

**Category:** Denial of Service

**Scenario:**
Password authentication or root access is disabled before working key-based access is confirmed.

**Assets affected:**

- administrative availability.

**Impact:** High

**Planned controls:**

- maintain VM console access;
- keep an existing SSH session open;
- test a second SSH session before closing the first;
- document recovery steps;
- change one logical security setting at a time.

**Verification:**

- confirm second SSH session works after hardening;
- verify VM console recovery remains available.

---

## T-05: Firewall Misconfiguration Exposes Services

**Category:** Information Disclosure / Elevation of Privilege

**Scenario:**
UFW rules expose ports or services that have no documented requirement.

**Assets affected:**

- server integrity;
- application;
- network services.

**Impact:** High

**Planned controls:**

- default-deny inbound policy;
- allow only documented ports;
- document every inbound rule;
- inspect listening sockets;
- verify exposure from the MacBook.

**Verification:**

- test approved ports;
- test blocked ports;
- inspect UFW status;
- inspect listening services.

---

## T-06: Firewall Misconfiguration Blocks SSH

**Category:** Denial of Service

**Scenario:**
Firewall rules are applied before SSH access is allowed, causing administrative lockout.

**Assets affected:**

- administrative availability.

**Impact:** High

**Planned controls:**

- explicitly allow SSH before enabling UFW;
- maintain console access;
- review rules before activation.

**Verification:**

- establish SSH access after firewall enablement;
- confirm console access remains available.

---

## T-07: Direct Application Port Exposure

**Category:** Information Disclosure / Elevation of Privilege

**Scenario:**
The Docker application port is published externally and allows clients to bypass Nginx.

**Assets affected:**

- application interface;
- network security controls;
- application availability.

**Impact:** Medium to High

**Planned controls:**

- bind the application internally;
- expose only Nginx externally;
- inspect Docker port mappings;
- inspect listening sockets;
- validate UFW behaviour.

**Verification:**

- confirm Nginx can reach the application;
- attempt direct application-port access from the MacBook and confirm failure.

---

## T-08: Nginx Configuration Tampering

**Category:** Tampering

**Scenario:**
Nginx configuration is modified incorrectly or maliciously.

**Assets affected:**

- application availability;
- request routing;
- network exposure.

**Impact:** High

**Planned controls:**

- root-owned configuration;
- Git version control;
- controlled sudo access;
- configuration validation before reload;
- known-good rollback version.

**Verification:**

- attempt modification as an unprivileged user;
- run Nginx configuration validation;
- test recovery from a controlled invalid configuration.

---

## T-09: Docker Group Grants Excessive Privilege

**Category:** Elevation of Privilege

**Scenario:**
A user in the Docker group can control containers in ways that effectively provide root-level host access.

**Assets affected:**

- operating-system integrity;
- secrets;
- application;
- backups;
- logs.

**Impact:** High

**Planned controls:**

- restrict Docker group membership;
- treat Docker administration as privileged;
- document the security implications of Docker access.

**Verification:**

- inspect Docker group membership;
- confirm ordinary users cannot run privileged Docker commands.

---

## T-10: Privileged Container or Unsafe Mount

**Category:** Elevation of Privilege

**Scenario:**
The application container receives unnecessary privileges or dangerous host filesystem access.

**Assets affected:**

- host operating system;
- configuration;
- logs;
- backup data.

**Impact:** High

**Planned controls:**

- avoid privileged containers;
- avoid unnecessary host mounts;
- do not expose the Docker socket;
- minimise container permissions;
- review Compose configuration.

**Verification:**

- inspect container privileges;
- inspect mounted host paths;
- inspect Docker Compose configuration.

---

## T-11: Secret Committed to GitHub

**Category:** Information Disclosure

**Scenario:**
A password, token, SSH private key, cloud credential, or other secret is committed to the repository.

**Assets affected:**

- credentials;
- GitHub account;
- future cloud resources;
- server access.

**Impact:** High

**Planned controls:**

- `.gitignore`;
- `.env.example`;
- placeholders only;
- staged-diff review;
- later secret scanning;
- immediate rotation if exposure occurs.

**Verification:**

- search working tree and Git history for secret patterns;
- review staged files before commit.

---

## T-12: Sensitive Values Written to Logs

**Category:** Information Disclosure

**Scenario:**
Passwords, tokens, environment values, or other secrets are accidentally written to operational logs.

**Assets affected:**

- credentials;
- environment configuration;
- logs.

**Impact:** Medium to High

**Planned controls:**

- avoid logging secrets;
- keep logs synthetic;
- restrict log permissions;
- review log content;
- redact sensitive values if required.

**Verification:**

- inspect logs during normal operation and failure simulations.

---

## T-13: Log Tampering

**Category:** Tampering / Repudiation

**Scenario:**
Operational or authentication logs are modified or deleted.

**Assets affected:**

- incident evidence;
- monitoring evidence;
- auditability.

**Impact:** Medium

**Planned controls:**

- restrictive ownership and permissions;
- normal users cannot modify protected logs;
- retain relevant system logs;
- maintain Git-based operational documentation.

**Verification:**

- test access using an unprivileged user;
- inspect log ownership and permissions.

---

## T-14: Missing or Inadequate Logging

**Category:** Repudiation

**Scenario:**
Important administrative, service, monitoring, or backup actions cannot be reconstructed after a failure.

**Assets affected:**

- auditability;
- incident response;
- troubleshooting.

**Impact:** Medium

**Planned controls:**

- named accounts;
- authentication logging;
- sudo logging;
- timestamped monitoring logs;
- backup logs;
- application and Nginx logs.

**Verification:**

- perform controlled actions and confirm relevant logs exist.

---

## T-15: Application Container Stops

**Category:** Denial of Service

**Scenario:**
The application container crashes, is stopped, or fails to start.

**Assets affected:**

- application availability.

**Impact:** Medium to High

**Planned controls:**

- container restart policy;
- monitoring of container state;
- `/health` monitoring;
- documented recovery runbook.

**Verification:**

- deliberately stop the application container;
- confirm detection;
- recover the service;
- verify the health endpoint.

---

## T-16: Invalid Nginx Configuration Causes Outage

**Category:** Denial of Service

**Scenario:**
A syntax or routing error prevents Nginx from serving traffic.

**Assets affected:**

- application availability.

**Impact:** High

**Planned controls:**

- configuration test before reload;
- Git version history;
- rollback procedure;
- controlled changes.

**Verification:**

- introduce a safe invalid test configuration;
- confirm validation detects it;
- restore the known-good version.

---

## T-17: Disk Exhaustion

**Category:** Denial of Service

**Scenario:**
Logs, backups, temporary files, or application data consume all available disk capacity.

**Assets affected:**

- application availability;
- logging;
- backups;
- operating-system stability.

**Impact:** High

**Planned controls:**

- disk monitoring;
- warning thresholds;
- backup retention;
- log rotation;
- controlled disk-usage testing.

**Verification:**

- safely trigger a disk threshold warning using synthetic files;
- confirm alerting;
- remove the test data;
- verify recovery.

---

## T-18: Backup Archive Tampering or Corruption

**Category:** Tampering

**Scenario:**
A backup archive is changed, truncated, corrupted, or replaced.

**Assets affected:**

- backup integrity;
- recoverability.

**Impact:** High

**Planned controls:**

- checksums;
- manifests;
- restricted permissions;
- multiple recent backups;
- validation before restoration.

**Verification:**

- modify a test backup;
- confirm integrity verification fails.

---

## T-19: Backup Exists but Cannot Restore

**Category:** Denial of Service / Integrity Failure

**Scenario:**
Backup creation appears successful, but the data cannot actually be recovered.

**Assets affected:**

- recoverability;
- application data.

**Impact:** High

**Planned controls:**

- mandatory restoration testing;
- documented restore steps;
- checksum validation;
- post-restore application testing;
- synthetic recovery exercises.

**Verification:**

- delete test data;
- restore from backup;
- confirm the restored data and application state.

---

## T-20: Backup Data Is Readable by Unauthorised Users

**Category:** Information Disclosure

**Scenario:**
Backup archives contain configuration or application data that can be read by ordinary users.

**Assets affected:**

- application data;
- configuration;
- future secrets.

**Impact:** Medium to High

**Planned controls:**

- restrictive ownership and permissions;
- limited backup directory access;
- avoid unnecessary sensitive content.

**Verification:**

- test backup-file access as an ordinary user.

---

## T-21: Malicious or Vulnerable Container Image

**Category:** Supply Chain / Elevation of Privilege

**Scenario:**
A container image includes vulnerable, malicious, or unnecessary software.

**Assets affected:**

- application;
- host security;
- network security.

**Impact:** High

**Planned controls:**

- use reputable image sources;
- minimise image contents;
- record image source;
- pin versions where practical;
- add scanning later where useful.

**Verification:**

- review image source and tag;
- inspect dependency choices;
- run future CI security checks if introduced.

---

## T-22: Vulnerable Operating-System Package or Dependency

**Category:** Supply Chain

**Scenario:**
A package or dependency contains a known vulnerability or malicious change.

**Assets affected:**

- server integrity;
- application;
- network services.

**Impact:** High

**Planned controls:**

- use official or trusted repositories;
- minimise dependencies;
- apply supported updates;
- record important dependencies;
- review security notices where appropriate.

**Verification:**

- inspect package sources;
- document dependency installation sources.

---

## T-23: Unsafe Repository Change

**Category:** Tampering

**Scenario:**
A bad configuration or automation change is committed and later applied to the server.

**Assets affected:**

- operating-system integrity;
- service availability;
- security controls.

**Impact:** Medium to High

**Planned controls:**

- Git history;
- small commits;
- GitHub Issues;
- staged-diff review;
- CI validation;
- configuration tests.

**Verification:**

- require passing checks before MVP release;
- review commits before implementation.

---

## T-24: Monitoring Fails Silently

**Category:** Denial of Service / Repudiation

**Scenario:**
The monitoring process stops or reports healthy results while important services are actually failing.

**Assets affected:**

- observability;
- incident detection.

**Impact:** High

**Planned controls:**

- monitor multiple layers;
- test monitoring through deliberate outages;
- monitor backup freshness;
- log check failures clearly.

**Verification:**

- stop a monitored service;
- confirm detection;
- verify monitoring logs.

---

## T-25: Monitoring Creates Excessive Noise

**Category:** Operational Risk

**Scenario:**
Poor thresholds create repeated false alarms and reduce the usefulness of monitoring.

**Assets affected:**

- operational clarity;
- incident response.

**Impact:** Medium

**Planned controls:**

- simple documented thresholds;
- severity levels;
- observe normal behaviour before tuning;
- distinguish information from actionable failures.

**Verification:**

- review monitoring output under normal and controlled-load conditions.

---

# Security Control Principles

The SentinelOps security design follows these principles:

1. least privilege;
2. minimum network exposure;
3. named administrator access;
4. SSH key authentication;
5. no ordinary root SSH usage;
6. controlled sudo;
7. restricted Docker access;
8. private application port;
9. configuration validation before reload;
10. secrets outside source control;
11. synthetic data only;
12. protected logs;
13. protected backups;
14. integrity verification;
15. tested restoration;
16. deliberate security verification;
17. documented recovery paths;
18. simple architecture before advanced security tooling.

---

# Threat Verification Strategy

Security controls must be tested rather than assumed.

Verification should later include:

- rejected password SSH login;
- rejected root SSH login;
- successful approved key login;
- ordinary-user permission tests;
- firewall port tests;
- direct application-port rejection;
- Docker group review;
- container privilege review;
- protected-log permission tests;
- protected-backup permission tests;
- backup checksum failure test;
- restoration test;
- invalid Nginx configuration test;
- stopped-container monitoring test;
- disk threshold test;
- repository secret review.

---

# Residual Risk

Even after the planned controls are implemented, the MVP will retain residual risks.

Examples include:

- monitoring and the application share one VM;
- local backups share the same physical host environment;
- the project does not provide high availability;
- the project does not provide enterprise-grade centralised logging;
- local administrator compromise could still affect the entire lab;
- supply-chain risk cannot be eliminated completely;
- the project is not a production security platform.

These limitations are accepted because SentinelOps is an educational infrastructure lab.

They must not be presented as production-grade guarantees.

---

# Threat Model Review Points

The threat model should be reviewed:

- before SSH hardening;
- before enabling UFW;
- before Docker deployment;
- before introducing new exposed ports;
- before backup implementation;
- before destructive failure simulations;
- before CI security checks;
- before any future cloud deployment;
- before the MVP release.

New threats discovered during implementation should be added to this document.