# SentinelOps Security Baseline

## Purpose

This document defines the minimum security baseline that the SentinelOps MVP must follow.

The baseline converts the Phase 0 threat model into concrete security requirements that implementation, automation, validation, monitoring, recovery, and CI work must satisfy.

The document began as a pre-implementation security baseline.

As SentinelOps progressed, implementation evidence has been added through the project's issue-driven workflow while preserving the original security requirements.

No security control is considered complete merely because configuration exists.

Implementation, verification, and recorded evidence remain required.

---

# Security Baseline Goals

The SentinelOps security baseline should:

- apply least privilege;
- minimise network exposure;
- protect administrative access;
- protect secrets and private keys;
- reduce unsafe privilege escalation;
- restrict container privileges;
- protect logs and backups;
- require configuration validation;
- preserve administrator recovery access;
- require security controls to be tested rather than assumed;
- require repository changes to receive automated validation where practical;
- prevent CI workflows from introducing unnecessary credentials or permissions.

---

# SB-01: Named Administrator Accounts

Normal administration shall use named administrator accounts.

The root account shall not be used as the normal interactive administration account.

Purpose:

- improve accountability;
- reduce unnecessary direct root usage;
- support clearer authentication and sudo logs.

Verification:

- confirm the administrator account exists;
- confirm normal SSH administration uses the named account;
- confirm direct root SSH login is restricted.

---

# SB-02: SSH Key Authentication

SSH administration shall use key-based authentication.

Password authentication shall only be disabled after key-based access has been confirmed successfully.

Purpose:

- reduce password-based authentication risk;
- support stronger administrative authentication.

Verification:

- confirm approved SSH key login succeeds;
- confirm a second independent SSH session succeeds before closing the first;
- confirm password authentication is rejected after hardening.

---

# SB-03: Restrict Direct Root SSH Login

Direct remote root login shall be disabled or otherwise restricted.

Purpose:

- reduce direct privileged account exposure;
- encourage controlled privilege escalation.

Verification:

- attempt direct root SSH login;
- confirm the connection is rejected.

---

# SB-04: Preserve Emergency Recovery Access

SSH hardening shall not be performed without a recovery path.

The project shall retain VM console access while remote-access changes are being tested.

Purpose:

- prevent permanent administrator lockout;
- provide a recovery mechanism if SSH becomes unavailable.

Verification:

- confirm the virtualisation platform provides console access;
- document the recovery procedure before disabling password authentication.

---

# SB-05: Controlled Sudo Access

Administrative privilege escalation shall use controlled sudo access.

Sudo permissions should be limited to users and groups with a documented administrative requirement.

Purpose:

- reduce unnecessary root-level access;
- improve accountability;
- support least privilege.

Verification:

- inspect sudo-capable users and groups;
- verify ordinary users cannot perform privileged operations;
- review relevant sudo logging.

---

# SB-06: Least-Privilege Users and Groups

Users and groups shall receive only the access required for their role.

The project should distinguish between:

- administrator access;
- application ownership;
- ordinary unprivileged access.

Purpose:

- reduce accidental or malicious modification;
- create clear responsibility boundaries.

Verification:

- inspect account and group membership;
- test protected operations using an unprivileged account.

---

# SB-07: Protected File Ownership and Permissions

Infrastructure configuration, operational logs, and backups shall use restrictive ownership and permissions.

Protected files should not be writable by ordinary users.

Purpose:

- prevent unauthorised modification;
- protect operational evidence;
- protect recoverable data.

Verification:

- inspect ownership and permissions;
- attempt modification using an unprivileged account.

---

# SB-08: Default-Deny Inbound Firewall

UFW shall use a deny-by-default inbound policy.

Purpose:

- reduce network attack surface;
- ensure every allowed inbound service has an explicit reason.

Verification:

- inspect UFW default policy;
- test approved and blocked ports.

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

- inspect firewall rules;
- inspect listening sockets;
- test network reachability from the MacBook.

---

# SB-10: Private Application Port

The application container port shall not be directly accessible from outside the Ubuntu VM.

Nginx shall remain the approved application-facing entry point.

Purpose:

- reduce attack surface;
- prevent bypassing the reverse proxy;
- keep a single controlled request path.

Verification:

- confirm the application works through Nginx;
- attempt direct access to the application port from the MacBook and confirm failure.

Validated SentinelOps backend state:

```text
127.0.0.1:8000
```

Expected external result for TCP port 8000:

```text
not reachable
```

---

# SB-11: Configuration Validation Before Reload

Service configuration shall be validated before reload or restart where the service supports validation.

This is especially important for Nginx and OpenSSH.

Purpose:

- reduce preventable outages;
- detect syntax errors before applying unsafe configuration.

Verification:

- run the supported configuration validation command;
- introduce a controlled invalid configuration during a failure exercise where appropriate;
- confirm invalid configuration is detected before unsafe reload.

Current examples include:

```bash
nginx -t
```

and:

```bash
sshd -t
```

---

# SB-12: Restrict Docker Access

Docker administration shall be treated as privileged access.

Ordinary users shall not receive Docker group membership without a documented reason.

Purpose:

- Docker access can effectively provide host-level privilege;
- restrict unnecessary control over containers and host resources.

Verification:

- inspect Docker group membership;
- confirm ordinary users cannot manage Docker without authorised membership.

The SentinelOps administrator account currently requires Docker access for the documented infrastructure workflow.

Repeated provisioning must not create duplicate or invalid Docker group state.

---

# SB-13: Avoid Privileged Containers

Application containers shall not run in privileged mode unless a future documented requirement justifies it.

Purpose:

- reduce host compromise risk;
- maintain stronger container isolation.

Verification:

- inspect Docker or Docker Compose configuration;
- confirm privileged mode is not enabled.

---

# SB-14: Avoid Unnecessary Host Filesystem Mounts

Containers shall mount only the host paths required for documented application behaviour.

Dangerous broad mounts should be avoided.

Purpose:

- reduce container access to host data;
- reduce tampering risk.

Verification:

- review container mount configuration;
- document the reason for each host mount.

---

# SB-15: Do Not Expose the Docker Socket to the Application

The application container shall not receive access to the Docker daemon socket.

Purpose:

- Docker socket access could allow control over the host container runtime;
- reduce elevation-of-privilege risk.

Verification:

- inspect container mounts and configuration;
- confirm the Docker daemon socket is not mounted into the application container.

---

# SB-16: Secrets Must Remain Outside Source Control

Real secrets shall not be committed to the repository.

This includes:

- private SSH keys;
- real passwords;
- GitHub tokens;
- cloud access keys;
- API secrets;
- production credentials.

Purpose:

- prevent credential exposure through Git history or repository access.

Verification:

- review staged changes before commit;
- search repository contents for prohibited secret-like patterns;
- use automated CI secret-pattern validation;
- avoid displaying potentially sensitive matching values in CI logs.

SEN-026 introduces automated GitHub Actions secret-safety validation for tracked repository content.

The initial automated scan checks for obvious categories including:

```text
private-key header patterns
obvious password assignments
obvious token assignments
obvious secret assignments
```

The CI job reports affected file paths without intentionally printing matching secret-like values.

This automated check supplements manual review.

It does not replace careful secret handling.

---

# SB-17: Use Placeholder Configuration

Where environment variables or secrets are required, the repository should contain examples rather than real values.

Example:

```text
.env.example
```

Purpose:

- document required configuration without exposing secrets.

Verification:

- confirm example files contain synthetic placeholders only;
- confirm real environment files remain ignored where applicable.

---

# SB-18: Protect SSH Private Keys

SSH private keys must remain outside the SentinelOps repository.

Local key files should use restrictive permissions.

Purpose:

- prevent unauthorised server access.

Verification:

- inspect local SSH key permissions;
- confirm private key files are not tracked by Git;
- confirm CI and documentation do not require private key material.

---

# SB-19: Protect Operational Logs

Operational logs shall not be writable by ordinary users where integrity matters.

Relevant logs include:

- authentication logs;
- system logs;
- Nginx logs;
- monitoring logs;
- backup logs.

Purpose:

- preserve incident evidence;
- reduce log tampering.

Verification:

- inspect ownership and permissions;
- attempt modification using an unprivileged account.

The SentinelOps structured monitoring baseline currently expects:

```text
/var/log/sentinelops
owner: root
group: emir
mode: 0750
```

and:

```text
/var/log/sentinelops/health-check.log
owner: emir
group: emir
mode: 0640
```

---

# SB-20: Avoid Logging Secrets

Passwords, tokens, private keys, and other secrets shall not be written to logs.

Purpose:

- reduce information disclosure;
- prevent credentials from appearing in troubleshooting output.

Verification:

- inspect logs during normal operation;
- inspect logs during failure simulations;
- inspect CI failure output for unnecessary sensitive-value exposure.

The SEN-026 secret-safety workflow intentionally avoids printing matching secret-like content.

---

# SB-21: Protect Backup Storage

Backup archives shall use restrictive ownership and permissions.

Ordinary users should not be able to read, modify, or delete protected backup archives without documented authority.

Purpose:

- protect data confidentiality;
- protect recoverability;
- reduce tampering risk.

Verification:

- inspect backup directory ownership and permissions;
- attempt unauthorised access using an ordinary user.

Current SentinelOps backup artifacts use:

```text
owner: emir
group: emir
mode: 0600
```

for generated archive, checksum, and manifest files.

---

# SB-22: Backup Integrity Verification

Backup archives shall use integrity checksums.

Purpose:

- detect corruption;
- detect unauthorised modification;
- prevent restoration from unverified archives.

Verification:

- verify a valid backup checksum;
- deliberately modify a safe test archive and confirm validation failure.

Current integrity mechanism:

```text
SHA-256
```

---

# SB-23: Backup Manifests

Backups shall provide a clear record of their intended contents.

Purpose:

- make restoration predictable;
- identify missing or unexpected data.

Verification:

- review a generated backup manifest;
- compare the manifest with archive contents.

---

# SB-24: Restoration Testing Is Mandatory

A backup shall not be considered proven until restoration succeeds.

Purpose:

- prevent false confidence from successful archive creation alone.

Verification:

- delete or alter synthetic test data;
- restore from backup;
- validate restored data and application behaviour.

---

# SB-25: Synthetic Data Only

SentinelOps shall use synthetic application data for demonstrations, testing, backup, and destructive recovery exercises.

Purpose:

- avoid exposing personal, employer, or confidential information;
- keep destructive testing safe.

Verification:

- review application fixtures and demonstration data;
- confirm no real sensitive data is stored.

Controlled CI failure testing must also use synthetic and harmless content.

---

# SB-26: Minimise Installed Software

Only packages and services required for the project should be installed.

Purpose:

- reduce attack surface;
- reduce maintenance burden;
- improve explainability.

Verification:

- review installed project dependencies;
- document why major packages are required.

CI tooling should also remain limited to tools required for repository validation.

---

# SB-27: Trusted Package Sources

Operating-system packages and dependencies should come from trusted sources.

Purpose:

- reduce supply-chain risk.

Verification:

- record important package sources;
- avoid unnecessary third-party repositories.

The SentinelOps Docker installation uses Docker's documented Ubuntu package repository.

GitHub Actions currently installs ShellCheck using the GitHub-hosted Ubuntu runner package manager.

---

# SB-28: Trusted Container Images

Container images should use reputable sources and minimal base images where practical.

Purpose:

- reduce supply-chain risk;
- reduce unnecessary software inside containers.

Verification:

- document the chosen base image;
- review image source and tag;
- introduce security scanning later if useful.

Current application base image:

```text
nginx:alpine
```

---

# SB-29: Version Control for Infrastructure Configuration

Important infrastructure configuration shall be stored in Git where appropriate.

Purpose:

- provide change history;
- support rollback;
- make configuration review possible.

Verification:

- confirm project configuration is tracked;
- review Git history during controlled configuration changes.

Version-controlled SentinelOps infrastructure now includes:

```text
application assets
Nginx configuration
SSH hardening configuration
systemd backup units
monitoring script
backup script
provisioning automation
GitHub Actions workflow
```

---

# SB-30: Small and Reviewable Changes

Infrastructure changes should be performed in small, meaningful units.

Purpose:

- simplify troubleshooting;
- reduce accidental changes;
- improve rollback capability.

Verification:

- use focused GitHub Issues;
- use dedicated feature branches;
- use clear commit messages;
- review diffs before commits;
- use pull requests before merge;
- verify automated CI results where available.

---

# SB-31: CI Validation Before MVP Release

The repository shall use automated validation before the MVP is considered complete.

SEN-026 establishes the initial GitHub Actions validation baseline.

The workflow is stored at:

```text
.github/workflows/ci.yml
```

Workflow name:

```text
SentinelOps CI
```

Current automated checks include:

```text
Bash syntax validation
ShellCheck static analysis
repository secret-pattern validation
```

The workflow runs automatically for:

```text
pull requests
pushes to main
```

This provides automated validation:

```text
before merge
after changes reach the default branch
```

The workflow uses:

```yaml
permissions:
  contents: read
```

The CI jobs therefore operate with read-only repository content access.

The workflow does not require:

```text
production credentials
deployment secrets
private SSH keys
cloud credentials
repository write permissions
```

Purpose:

- detect shell syntax errors before changes are accepted;
- identify common shell quality problems;
- detect obvious prohibited secret material;
- expose automated validation results directly on pull requests;
- establish automated repository checks before MVP release;
- provide a foundation for later container and application CI validation.

Verification:

- confirm the SentinelOps workflow executes on pull requests;
- confirm the workflow is configured for pushes to `main`;
- confirm Shell validation passes for valid repository state;
- confirm Secret safety passes for valid repository state;
- confirm an intentionally invalid synthetic shell script causes Shell validation to fail;
- confirm the failing script is identified by CI;
- confirm the failed validation returns a non-zero result;
- remove the synthetic failure;
- confirm the workflow returns to a passing state;
- confirm final required checks are green before merge.

SEN-026 validation demonstrated:

```text
initial ShellCheck finding: DETECTED
specific ShellCheck correction: PASS
clean Shell validation: PASS
Secret safety: PASS
controlled invalid Bash script: DETECTED
controlled CI failure result: PASS
synthetic failure recovery: PASS
final Shell validation: PASS
final Secret safety: PASS
```

Remaining CI validation scope:

```text
FR-48: Container Validation
FR-49: Application Testing
```

Container configuration and application behaviour validation remain separate follow-up work.

---

# SB-32: Security-Relevant Changes Require Verification

Security configuration must not be considered complete simply because it was applied.

Each major security control must have a corresponding verification step.

Examples:

- SSH key login test;
- root login rejection;
- firewall port test;
- ordinary-user permission test;
- application-port exposure test;
- backup checksum test;
- repository CI validation.

Purpose:

- distinguish implemented controls from assumed controls.

---

# SB-33: Destructive Testing Requires Recovery Preparation

Before destructive failure simulations:

- backups should exist where relevant;
- recovery steps should be known;
- synthetic data should be used;
- VM console access should remain available where required.

Purpose:

- prevent controlled experiments from becoming unrecoverable failures.

Verification:

- complete the safety checklist before each destructive scenario;
- validate recovery after the controlled failure.

CI failure tests should use synthetic repository content and must be recovered before merge.

---

# SB-34: Monitor Disk Capacity

Disk usage shall be monitored.

Purpose:

- reduce denial-of-service risk from full disks;
- protect logging and backup operations.

Verification:

- confirm disk checks operate;
- safely trigger the documented warning threshold.

Current SentinelOps thresholds:

```text
warning: 80%
critical: 90%
```

---

# SB-35: Control Log and Backup Growth

Logs and backup archives shall not grow without limit.

Purpose:

- reduce disk exhaustion risk.

Current and planned controls include:

- backup retention;
- monitoring of disk usage;
- log rotation where appropriate.

Verification:

- confirm retention behaviour;
- review log rotation configuration where introduced;
- inspect disk usage during failure simulations.

Current SentinelOps backup retention policy:

```text
7 days
```

---

# SB-36: Maintain Auditability

Important administrative and operational actions should leave enough evidence for later troubleshooting.

Expected evidence includes:

- authentication logs;
- sudo logs;
- Nginx logs;
- container logs;
- monitoring logs;
- backup logs;
- Git history;
- GitHub pull-request history;
- GitHub Actions results.

Purpose:

- support incident diagnosis;
- support accountability;
- preserve implementation and validation evidence.

Verification:

- perform a controlled action;
- identify the relevant evidence afterward.

---

# SB-37: Maintain Documentation Consistency

Security documentation shall be updated when implementation decisions change.

Purpose:

- prevent outdated security assumptions;
- ensure the threat model and baseline reflect the real environment.

Verification:

- compare implementation against security documentation before each phase closes;
- update planned controls when they become implemented and validated.

SEN-026 updates the CI baseline from planned validation to implemented GitHub Actions enforcement.

---

# SB-38: Do Not Claim Production-Grade Security

SentinelOps is an educational infrastructure lab.

The MVP shall not claim:

- enterprise-grade security;
- high availability;
- complete disaster recovery;
- formal compliance;
- penetration-test certification;
- production security guarantees.

Purpose:

- keep claims accurate;
- prevent portfolio overstatement.

Automated CI validation improves repository quality but does not transform the project into a production-certified environment.

---

# GitHub Actions Security Baseline

SEN-026 introduces GitHub Actions as part of the SentinelOps security and quality model.

The initial workflow is intentionally limited to repository validation.

It must not perform production deployment.

## GitHub Actions Workflow

Current workflow:

```text
.github/workflows/ci.yml
```

Current jobs:

```text
Shell validation
Secret safety
```

## GitHub Actions Trigger Policy

The workflow executes on:

```text
pull_request
push to main
```

Pull-request execution provides pre-merge validation.

Default-branch execution provides validation after accepted changes reach `main`.

## GitHub Actions Permission Policy

The workflow explicitly declares:

```yaml
permissions:
  contents: read
```

This is the minimum current repository permission required for the validation jobs.

Additional permissions must not be added without a documented requirement.

## GitHub Actions Credential Policy

The CI workflow must not require:

```text
production SSH credentials
cloud deployment credentials
repository write tokens
VM login credentials
application secrets
```

Any future CI secret must have:

```text
a documented requirement
minimum necessary scope
secure GitHub secret storage
no plaintext repository representation
```

## Workflow Modification Authentication

Git clients modifying:

```text
.github/workflows/
```

may require GitHub authentication authorised to update workflow files.

During SEN-026, the original cached credential lacked this permission and GitHub rejected the push.

The corrected developer authentication used a repository-scoped fine-grained token with:

```text
Contents: Read and write
Workflows: Read and write
Metadata: Read-only
```

This permission belongs to the developer Git operation.

It is separate from the runtime permissions granted to the GitHub Actions workflow itself.

The workflow continues to operate with:

```text
contents: read
```

No Personal Access Token value is stored in the repository.

## Shell Validation Security Value

Automated shell validation reduces the likelihood of merging broken or unsafe automation.

Current checks include:

```text
bash -n
ShellCheck
```

SEN-026 demonstrated that ShellCheck detected a real static-analysis issue requiring review.

The finding was handled with a specific local suppression only after confirming that the relevant file was an expected operating-system runtime file.

No global ShellCheck suppression was introduced.

## Controlled CI Failure Evidence

SEN-026 created a temporary synthetic script containing deliberately invalid Bash syntax.

The workflow automatically discovered the script.

The result was:

```text
Shell validation: FAIL
Secret safety: PASS
```

The Bash syntax step reported:

```text
syntax error: unexpected end of file
```

and returned:

```text
exit code 2
```

This demonstrates that invalid shell automation can prevent the CI workflow from reaching a passing state.

The synthetic file was subsequently removed.

The final recovery run returned:

```text
Shell validation: PASS
Secret safety: PASS
```

## CI Secret-Safety Boundary

The initial automated secret-pattern check is deliberately lightweight.

It detects obvious prohibited patterns but is not equivalent to:

```text
a full credential-scanning platform
GitHub Advanced Security
entropy-based secret detection
historical Git forensic scanning
external secret-management enforcement
```

Manual review and secure credential handling remain mandatory.

Future stronger secret-scanning tooling may be introduced if justified.

---

# Minimum Security Verification Set

Before MVP completion, the following controls should be demonstrated:

1. approved SSH key login succeeds;
2. password SSH login is rejected after hardening;
3. direct root SSH login is rejected;
4. ordinary users cannot modify protected configuration;
5. UFW uses a default-deny inbound policy;
6. only approved inbound ports are reachable;
7. the application port is not reachable directly;
8. Docker group membership is restricted;
9. the application container is not privileged;
10. the Docker socket is not exposed to the application;
11. private keys and real secrets are absent from Git;
12. logs use protected ownership and permissions;
13. backup archives use protected ownership and permissions;
14. backup checksum validation succeeds;
15. corrupted backup validation fails;
16. restoration succeeds using synthetic data;
17. invalid Nginx configuration is detected before unsafe reload;
18. monitoring detects a stopped application;
19. monitoring detects a disk threshold warning;
20. GitHub Actions executes automatically for repository validation;
21. Bash syntax validation passes for valid repository scripts;
22. ShellCheck passes after reviewed findings are resolved;
23. automated Secret safety validation passes;
24. a controlled invalid shell script causes CI failure;
25. controlled CI failure recovery returns the workflow to a passing state;
26. final required CI checks pass before MVP release.

---

# CI Security Verification Set

Before SEN-026 is considered complete, verify:

```text
.github/workflows/ci.yml exists
workflow runs on pull_request
workflow is configured for push to main
workflow permissions are read-only
Bash syntax validation executes
ShellCheck executes
all current provisioning shell scripts are covered
real ShellCheck findings are reviewed
secret-pattern validation executes
workflow requires no production secrets
controlled shell failure is detected
controlled failure returns non-zero status
failing file is identified
synthetic failure is removed
final Shell validation passes
final Secret safety passes
```

SEN-026 provides evidence for all of the above on the feature branch.

A successful post-merge `main` workflow execution provides final default-branch evidence for the configured push trigger.

---

# Security Baseline Review Points

The security baseline should be reviewed:

- before Phase 1 implementation;
- before SSH hardening;
- before enabling UFW;
- before Docker deployment;
- before application exposure;
- before backup implementation;
- before failure simulations;
- before provisioning automation;
- before GitHub Actions implementation;
- after GitHub Actions security validation;
- before container and application CI expansion;
- before any cloud deployment;
- before MVP release.

Any implementation decision that changes the security posture should trigger a review of this document.

---

# Current CI Security Status

SEN-026 current feature-branch evidence:

```text
GitHub Actions workflow: IMPLEMENTED
pull-request trigger: VERIFIED
push-to-main trigger: CONFIGURED
workflow contents permission: READ-ONLY
Bash syntax validation: VERIFIED
ShellCheck integration: VERIFIED
real ShellCheck finding: DETECTED
ShellCheck finding review: COMPLETE
specific ShellCheck correction: VERIFIED
Secret safety job: VERIFIED
controlled CI shell failure: VERIFIED
controlled failure exit behavior: VERIFIED
controlled failure recovery: VERIFIED
final Shell validation: PASS
final Secret safety: PASS
production credentials required by CI: NONE
```

Remaining CI security-related implementation scope:

```text
container validation
application behaviour validation
```

These map to:

```text
FR-48
FR-49
```

and should extend the established SEN-026 workflow.

---

# Baseline Acceptance Principle

A security control is considered complete only when:

1. the intended control is documented;
2. the control is implemented;
3. the control is verified;
4. the result is recorded or demonstrated;
5. the recovery or rollback path is understood where relevant.

Configuration alone is not sufficient evidence.

Automated CI success alone is also not sufficient evidence for runtime infrastructure security.

SentinelOps combines:

```text
documented intent
manual understanding
controlled implementation
runtime verification
failure testing
recovery testing
version-control evidence
automated CI validation
```

to establish its security baseline.