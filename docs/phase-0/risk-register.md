# SentinelOps Phase 0 Risk Register

## Purpose

This document records the main technical, operational, security, project-management, and delivery risks identified during Phase 0.

The purpose of the risk register is to make important failure modes visible before implementation begins.

Each risk includes:

- an identifier;
- a description;
- likelihood;
- impact;
- planned response;
- verification or review action where applicable.

---

## Risk Rating Scale

### Likelihood

- Low: unlikely to occur during the MVP.
- Medium: realistic possibility during implementation.
- High: likely to occur unless actively managed.

### Impact

- Low: limited inconvenience with minimal project disruption.
- Medium: noticeable delay, rework, or reduced project quality.
- High: major security issue, data loss, project failure, or inability to demonstrate the MVP.

---

# Risk Register

## R-01: Scope Creep

**Description:**
The project expands into technologies such as AWS, Terraform, Kubernetes, Prometheus, Grafana, or multi-server architecture before the local MVP is complete.

**Likelihood:** High

**Impact:** High

**Response:**

- freeze the MVP scope during Phase 0;
- keep advanced technologies in the post-MVP backlog;
- require a clear problem before adding a new technology;
- do not begin cloud deployment until the local environment is reproducible.

**Review:**
Check each new GitHub Issue against the agreed MVP scope.

---

## R-02: SSH Lockout

**Description:**
SSH hardening is applied incorrectly and prevents the administrator from reconnecting to the Ubuntu server.

**Likelihood:** Medium

**Impact:** High

**Response:**

- maintain VM console access;
- verify SSH key authentication before disabling password login;
- keep an existing SSH session open while testing a new session;
- document emergency recovery steps;
- avoid modifying multiple SSH security settings at once.

**Verification:**
Successfully open a second SSH session after every major SSH configuration change.

---

## R-03: Accidental Secret Exposure

**Description:**
A password, private SSH key, token, cloud credential, or other secret is accidentally committed to GitHub.

**Likelihood:** Medium

**Impact:** High

**Response:**

- use `.gitignore`;
- never store private keys inside the repository;
- use `.env.example` for placeholder configuration;
- use synthetic values only;
- review staged changes before every commit;
- add secret scanning in CI later.

**Verification:**
Search repository history and working files for known secret patterns before MVP release.

---

## R-04: Excessive Privileges

**Description:**
Users, sudo rules, file permissions, or service accounts receive more privileges than required.

**Likelihood:** Medium

**Impact:** High

**Response:**

- apply least privilege;
- define administrator and application ownership responsibilities;
- review group membership;
- restrict protected configuration files;
- document sudo requirements;
- test access using unprivileged accounts.

**Verification:**
Confirm an ordinary user cannot modify protected infrastructure configuration.

---

## R-05: Docker Privilege Exposure

**Description:**
Docker access effectively grants root-level control over the host.

**Likelihood:** Medium

**Impact:** High

**Response:**

- restrict Docker group membership;
- treat Docker administration as privileged access;
- avoid unnecessary privileged containers;
- avoid unsafe host filesystem mounts;
- document why Docker permissions are security-sensitive.

**Verification:**
Review Docker group membership and container privileges.

---

## R-06: Unsafe Firewall Configuration

**Description:**
Incorrect UFW rules expose unnecessary services or block required administrative access.

**Likelihood:** Medium

**Impact:** High

**Response:**

- document required ports before enabling the firewall;
- use deny-by-default inbound policy;
- allow SSH before enabling UFW;
- verify every permitted service;
- inspect listening sockets separately from firewall rules.

**Verification:**
Test approved and blocked ports from the host network.

---

## R-07: Application Port Exposure

**Description:**
The application container port is reachable directly, bypassing Nginx.

**Likelihood:** Medium

**Impact:** Medium

**Response:**

- bind the application service to localhost where practical;
- expose only Nginx externally;
- document expected listening ports;
- validate network exposure after deployment.

**Verification:**
Attempt direct access to the application port from outside the VM and confirm failure.

---

## R-08: Broken Nginx Configuration

**Description:**
An invalid Nginx configuration causes the hosted application to become unavailable.

**Likelihood:** Medium

**Impact:** Medium

**Response:**

- validate Nginx configuration before reload;
- keep configuration in Git;
- change one logical configuration unit at a time;
- document rollback steps;
- maintain a known-working configuration.

**Verification:**
Test an intentionally invalid configuration during a controlled failure simulation.

---

## R-09: Automation Causes System Damage

**Description:**
A Bash script performs unsafe or unintended changes to the server.

**Likelihood:** Medium

**Impact:** High

**Response:**

- understand each change manually first;
- validate prerequisites;
- use clear error handling;
- fail safely;
- avoid destructive defaults;
- print understandable output;
- review scripts before execution.

**Verification:**
Test automation in the lab environment before relying on it for clean rebuilds.

---

## R-10: Automation Is Not Idempotent

**Description:**
Running automation more than once creates duplicate users, duplicate firewall rules, repeated configuration, or broken services.

**Likelihood:** High

**Impact:** Medium

**Response:**

- check current state before making changes;
- avoid blindly appending configuration;
- validate resulting configuration;
- require a second-run test.

**Verification:**
Run the completed provisioning process twice and confirm the second execution does not damage the environment.

---

## R-11: Backup Exists but Is Unusable

**Description:**
Backup files are created successfully but cannot be restored.

**Likelihood:** Medium

**Impact:** High

**Response:**

- generate checksums;
- document backup contents;
- test restoration using synthetic data;
- verify permissions after restoration;
- record backup success and failure.

**Verification:**
Delete test data and restore it from a verified backup.

---

## R-12: Backup Corruption

**Description:**
A backup archive is incomplete, corrupted, or modified.

**Likelihood:** Low

**Impact:** High

**Response:**

- generate integrity checksums;
- use a backup manifest;
- validate archives before restoration;
- retain multiple recent backup copies.

**Verification:**
Modify or corrupt a test backup and confirm integrity verification detects the problem.

---

## R-13: Disk Exhaustion

**Description:**
Logs, backups, temporary files, or application data fill the VM disk.

**Likelihood:** Medium

**Impact:** High

**Response:**

- monitor disk usage;
- define warning thresholds;
- apply backup retention;
- use log rotation where appropriate;
- include disk pressure as a controlled failure scenario.

**Verification:**
Trigger a safe disk-usage warning using synthetic test data.

---

## R-14: Monitoring Produces False Confidence

**Description:**
Monitoring appears healthy even though important service failures are not detected.

**Likelihood:** Medium

**Impact:** High

**Response:**

- monitor multiple layers;
- check Nginx status;
- check container status;
- check the application endpoint;
- check system resources;
- test monitoring using deliberate failures.

**Verification:**
Stop a monitored service and confirm the monitoring system detects it.

---

## R-15: Monitoring Produces Excessive Noise

**Description:**
Thresholds are poorly chosen and generate frequent non-actionable warnings.

**Likelihood:** Medium

**Impact:** Medium

**Response:**

- use simple documented thresholds;
- distinguish informational results from warnings and failures;
- tune thresholds only after observing normal behaviour.

**Verification:**
Review monitoring logs during normal operation and controlled stress tests.

---

## R-16: Logs Become Unmanageable

**Description:**
Logs grow without limit or become difficult to interpret.

**Likelihood:** Medium

**Impact:** Medium

**Response:**

- define dedicated SentinelOps logging locations;
- use timestamps;
- use consistent message formats;
- apply log rotation where appropriate;
- avoid logging unnecessary sensitive values.

**Verification:**
Review log growth and readability during failure simulations.

---

## R-17: Failure Simulation Damages the Environment

**Description:**
A deliberate outage or destructive test causes more damage than intended.

**Likelihood:** Medium

**Impact:** Medium

**Response:**

- use synthetic data;
- define safety steps before each simulation;
- take appropriate VM snapshots where useful;
- ensure backups exist before destructive tests;
- document rollback procedures.

**Verification:**
Confirm the recovery procedure before beginning each destructive simulation.

---

## R-18: VM Platform Compatibility Problems

**Description:**
The Ubuntu VM or container images are incompatible with the MacBook hardware architecture or virtualisation platform.

**Likelihood:** Medium

**Impact:** Medium

**Response:**

- use supported Ubuntu images;
- use container images compatible with the host architecture;
- verify Docker platform support;
- avoid architecture-specific dependencies without a reason.

**Verification:**
Record VM architecture and confirm required images run successfully before application development begins.

---

## R-19: Insufficient Local Resources

**Description:**
The MacBook does not have enough available memory, CPU, or disk space to run the VM comfortably.

**Likelihood:** Low to Medium

**Impact:** Medium

**Response:**

- keep the MVP to one server;
- use a small application;
- avoid unnecessary services;
- monitor host and VM resource usage;
- delay Prometheus, Grafana, and multi-server architecture until post-MVP.

**Verification:**
Measure normal VM memory, CPU, and disk usage during operation.

---

## R-20: Documentation Becomes Outdated

**Description:**
The implementation changes but the documentation still describes an older design.

**Likelihood:** High

**Impact:** Medium

**Response:**

- update documentation in the same issue or pull request as implementation changes;
- maintain architecture decision records;
- review README consistency before milestone completion.

**Verification:**
Compare final implementation against the documentation before each phase closes.

---

## R-21: Project Becomes a Collection of Copied Commands

**Description:**
Commands and configuration are copied without genuine understanding.

**Likelihood:** Medium

**Impact:** High

**Response:**

- explain every important command;
- perform important changes manually before automation;
- record why technologies are used;
- require verification after configuration;
- include troubleshooting exercises;
- maintain architecture decisions.

**Verification:**
The project owner must be able to explain what each major command changes and how to reverse it.

---

## R-22: Repository Looks Good but Is Not Reproducible

**Description:**
The project documentation and screenshots appear complete, but another clean Ubuntu VM cannot be built successfully.

**Likelihood:** Medium

**Impact:** High

**Response:**

- perform a clean rebuild before MVP release;
- document dependencies;
- automate understood configuration;
- verify every major step;
- remove hidden manual assumptions.

**Verification:**
Complete a fresh VM rebuild using only the documented process and repository.

---

## R-23: Invalid Configuration Reaches Main Branch

**Description:**
Broken scripts, Docker files, or configuration are merged without validation.

**Likelihood:** Medium

**Impact:** Medium

**Response:**

- use small commits;
- review changes before commit;
- add GitHub Actions;
- use syntax and configuration validation tools;
- avoid merging failing CI checks.

**Verification:**
Require all mandatory CI checks to pass before MVP release.

---

## R-24: Dependency or Supply Chain Risk

**Description:**
A package, container image, or dependency introduces vulnerabilities or malicious code.

**Likelihood:** Low to Medium

**Impact:** High

**Response:**

- use trusted package repositories;
- use reputable container images;
- minimise dependencies;
- record dependency sources;
- pin versions where appropriate;
- add security scanning later where useful.

**Verification:**
Review image and package sources before the final MVP release.

---

## R-25: Unexpected Cloud Costs

**Description:**
Post-MVP cloud experimentation creates unexpected charges.

**Likelihood:** Low during MVP

**Impact:** Medium

**Response:**

- keep cloud deployment outside the initial MVP;
- use budget controls before later cloud work;
- document resource teardown;
- avoid leaving unnecessary resources running.

**Verification:**
Before cloud deployment, create a cost-control checklist.

---

# Highest Priority Risks

The highest-priority risks during the MVP are:

1. scope creep;
2. SSH lockout;
3. accidental secret exposure;
4. excessive privileges;
5. unsafe automation;
6. unusable backups;
7. disk exhaustion;
8. monitoring false confidence;
9. non-reproducible infrastructure;
10. lack of genuine technical understanding.

These risks should be reviewed throughout implementation rather than only during Phase 0.

---

# Risk Review Process

The risk register should be reviewed:

- when a new project phase begins;
- before major security changes;
- before destructive failure simulations;
- before cloud deployment;
- before the MVP release.

New risks should be added when discovered.

Existing risks should be updated if their likelihood, impact, or mitigation changes.