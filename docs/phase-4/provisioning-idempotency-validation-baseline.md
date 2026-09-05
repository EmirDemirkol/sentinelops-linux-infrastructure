# SEN-025 Provisioning Idempotency and Validation Baseline

## Purpose

SEN-025 hardens the SentinelOps provisioning workflow established by SEN-024.

SEN-024 demonstrated that the documented SentinelOps architecture could be reconstructed on a clean supported Ubuntu Server host from version-controlled provisioning assets.

SEN-025 addresses the automation-hardening requirements deliberately deferred from that baseline.

The issue focuses on three properties:

```text
safe repeated execution
pre-change prerequisite validation
useful provisioning failures
```

The implementation continues to use understandable Bash-based provisioning rather than introducing a separate configuration-management platform.

## Requirements Mapping

SEN-025 targets:

```text
FR-43: Idempotent Automation
FR-44: Automation Validation
FR-45: Useful Automation Failures
```

FR-43 requires:

```text
Provisioning automation shall eventually be safe to execute more than once without creating duplicate users, duplicate rules, or invalid configuration.
```

FR-44 requires:

```text
Automation shall validate important prerequisites before making system changes.
```

FR-45 requires:

```text
Automation failures shall return useful output and appropriate exit behaviour.
```

Continuous-integration requirements:

```text
FR-46
FR-47
FR-48
FR-49
```

remain separate follow-up work.

## Relationship to SEN-024

SEN-024 created the first repository-controlled provisioning baseline under:

```text
provision/
```

and successfully applied it to a disposable clean Ubuntu Server 24.04.4 LTS virtual machine.

SEN-024 deliberately did not claim complete idempotency.

Its documentation explicitly identified later work for:

```text
repeated execution behaviour
stronger prerequisite enforcement
more detailed provisioning failure handling
```

SEN-025 begins from that known-good baseline rather than redesigning the infrastructure.

## Test Environment

Runtime validation continued on the disposable:

```text
SentinelOps-Test
```

virtual machine.

Observed identity:

```text
hostname: sentinelops-test
IPv4: 192.168.64.3
Ubuntu: 24.04.4 LTS
architecture: arm64
```

The original known-good:

```text
SentinelOps-Ubuntu
```

VM was not used as the first target of the SEN-025 changes.

This preserved separation between the disposable automation test environment and the previously established reference environment.

## Repository Branch

SEN-025 development used:

```text
sen-025-provisioning-idempotency-validation
```

The issue was created before the feature branch so that the actual GitHub issue identifier was known.

GitHub issue:

```text
#36
```

## Initial Repository State

Before implementation, the Mac repository was synchronized with:

```text
main
origin/main
```

and had a clean working tree.

The latest merged SEN-024 commit was:

```text
09c24c6 Merge pull request #35 from EmirDemirkol/sen-024-repeatable-provisioning
```

The SEN-024 implementation commit was:

```text
4d33ced feat: implement SEN-024 repeatable provisioning baseline
```

The merged provisioning tree contained:

```text
provision/README.md
provision/application/Dockerfile
provision/application/compose.yaml
provision/application/index.html
provision/backup/backup-sentinelops.sh
provision/monitoring/health-check.sh
provision/nginx/sentinelops
provision/scripts/provision.sh
provision/ssh/00-sentinelops.conf
provision/systemd/sentinelops-backup.service
provision/systemd/sentinelops-backup.timer
```

## Requirements Audit

The Phase 0 requirements confirmed:

```text
FR-43
Provisioning automation shall eventually be safe to execute more than once without creating duplicate users, duplicate rules, or invalid configuration.

FR-44
Automation shall validate important prerequisites before making system changes.

FR-45
Automation failures shall return useful output and appropriate exit behaviour.
```

These requirements defined the SEN-025 scope.

## Initial Provisioner Audit

The SEN-024 provisioner was inspected in full before modification.

Initial line count:

```text
487
```

Repeat-sensitive operations included:

```text
apt-get update
apt-get install
Docker GPG key download
Docker repository rewrite
systemctl enable --now
usermod -aG docker
ln -sfn
ufw allow
docker compose up -d --build
systemctl start sentinelops-backup.service
```

The objective was not to assume that these operations were unsafe.

Their actual repeated behavior was measured on the disposable test VM.

## Pre-Second-Run Runtime Baseline

Before executing the unchanged SEN-024 provisioner a second time, the test VM reported:

```text
nginx: active
docker: active
ssh.socket: active
sentinelops-backup.timer: active
failed systemd units: 0
```

UFW contained exactly:

```text
[1] 22/tcp
[2] Nginx HTTP
[3] 22/tcp (v6)
[4] Nginx HTTP (v6)
```

The target user's groups were:

```text
emir
adm
cdrom
sudo
dip
plugdev
lxd
docker
```

The application was:

```text
sentinelops-app
Up
127.0.0.1:8000->80/tcp
```

Both application health paths returned:

```json
{"status":"healthy","version":"0.1.0"}
```

The initial backup archive count was:

```text
1
```

with:

```text
sentinelops-backup-20260904T194723Z.tar.gz
```

## Managed Configuration Baseline

Before the unchanged repeated run, managed configuration SHA-256 values were captured.

Nginx:

```text
65c4a029e9112483b4396b34b573a70abb3a5bc72acd2f5d8e0f23bd30519bd3
```

SSH hardening:

```text
976d699973524cbe1ca0cd0e29898771e7b1030cb1b1d0476fd9ce9ee6fed831
```

Backup service:

```text
6f7f6a5d8d49fb8cb41b55bd3721ff57855584d387577a47d3a6f47fabb7b69d
```

Backup timer:

```text
da345fc89a90863e3c2bcfaba2dce14a9d3c00b55cd26f831082fd0c1562fce1
```

These values provided before/after comparison evidence.

## Baseline Repeated Execution

Before SEN-025 changes were made, the unchanged SEN-024 provisioner was transferred to the test VM and executed again.

Syntax validation before execution returned:

```text
0
```

The repeated run completed successfully.

Package management reported existing base packages as already current.

Docker packages were also already installed.

No duplicate installation state was created.

## Existing Package Idempotency

APT reported:

```text
0 upgraded
0 newly installed
```

for the already-present base packages.

Docker reported its existing packages as already the newest versions.

This demonstrated that package-installation commands naturally converged on the existing installed state.

## Existing Docker Group Idempotency

The provisioner used:

```bash
usermod -aG docker emir
```

during the baseline repeated execution.

The effective group set after the run still showed one Docker group membership:

```text
emir adm cdrom sudo dip plugdev lxd docker
```

No duplicated group entry or invalid account state was produced.

SEN-025 later made this behavior explicit by checking membership before invoking `usermod`.

## Existing UFW Idempotency

During the unchanged second run, UFW reported:

```text
Skipping adding existing rule
Skipping adding existing rule (v6)
Skipping adding existing rule
Skipping adding existing rule (v6)
```

Afterwards the rule set remained exactly:

```text
[1] 22/tcp
[2] Nginx HTTP
[3] 22/tcp (v6)
[4] Nginx HTTP (v6)
```

No duplicate firewall rules were created.

This provided direct FR-43 evidence.

## Existing Docker Compose Convergence

The repeated:

```bash
docker compose up -d --build
```

operation rebuilt using cached layers and left the existing container running.

The application remained:

```text
Up
127.0.0.1:8000->80/tcp
```

The container creation age remained older than the repeated provisioning execution, showing that the existing healthy container was not unnecessarily recreated.

## Existing Service Convergence

After the unchanged repeated run:

```text
nginx: active
docker: active
ssh.socket: active
sentinelops-backup.timer: active
```

and:

```text
0 loaded units listed.
```

were still reported.

The required services remained enabled and active.

## Existing SSH Security Convergence

Effective SSH state after the baseline repeated run remained:

```text
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
kbdinteractiveauthentication no
```

No SSH security regression occurred.

## Baseline Backup Side Effect

The unchanged SEN-024 provisioner explicitly ran:

```bash
systemctl start sentinelops-backup.service
```

during every provisioning execution.

Therefore the baseline repeated run created:

```text
sentinelops-backup-20260904T221432Z.tar.gz
```

and changed the backup archive count:

```text
1 -> 2
```

The archive passed checksum and manifest validation.

This behavior was safe but unnecessary for idempotent provisioning because backup creation is already scheduled independently through the persistent systemd timer.

SEN-025 therefore changed provisioning-specific backup behavior.

## Nginx Checksum Observation

After the unchanged second run, the live Nginx checksum became:

```text
31be518b3e0d3ff632022cb30b3d3005d279bbe6e6addd9fbfb0d1fddbbffd5a
```

while the other captured managed-file hashes remained unchanged.

This was investigated before being classified as drift.

The repository Nginx source also returned:

```text
31be518b3e0d3ff632022cb30b3d3005d279bbe6e6addd9fbfb0d1fddbbffd5a
```

and:

```bash
diff -u
```

between repository source and deployed configuration produced no output.

The difference resulted from the final whitespace-only cleanup performed on the repository Nginx asset after the original clean-host provisioning test.

The repeated run therefore converged the host toward the final repository version.

It was not an ongoing idempotency defect.

## Managed File Convergence

After the baseline repeated execution, repository-to-host comparisons for:

```text
Nginx configuration
SSH hardening configuration
backup service
backup timer
```

produced no `diff -u` output.

This demonstrated convergence to repository-managed state.

## SEN-025 Design

The SEN-025 provisioner retains the existing understandable Bash model and adds:

```text
centralized failure handling
unexpected-error diagnostics
dedicated preflight stage
source shell-script validation
SSH key readiness validation
filesystem-capacity validation
repository-resolution validation
managed-path validation
port-conflict validation
explicit Docker-group convergence
conditional initial-backup behavior
stronger post-deployment validation messages
```

The script continues to use:

```bash
set -Eeuo pipefail
```

## Failure Helper

Known validation failures use:

```bash
fail()
```

The helper emits:

```text
[SEN-025] ERROR: <reason>
```

to standard error and exits:

```text
1
```

This provides one predictable failure path for deliberate provisioning validation failures.

## Unexpected Error Trap

The provisioner installs an `ERR` trap.

Unexpected command failures report:

```text
Provisioning stopped unexpectedly.
Exit code
Line
Command
```

This improves operational troubleshooting compared with a silent or context-free shell exit.

The trap does not provide transactional rollback.

Its purpose is useful failure reporting.

## Dedicated Preflight

The main provisioning sequence now begins with:

```text
run_preflight
```

before package installation or managed host deployment.

The preflight validates:

```text
root execution
supported operating system
supported architecture
target user
target group
target home
required source assets
source shell-script syntax
SSH public-key readiness
root-filesystem capacity
required repository resolution
managed Nginx path assumptions
important TCP listener state
```

Successful preflight ends with:

```text
[SEN-025] Provisioning preflight completed successfully
```

Only then does the provisioner enter the system-changing phase.

## Operating System Validation

The supported operating system remains:

```text
Ubuntu 24.04 LTS
```

The provisioner validates:

```text
ID=ubuntu
VERSION_ID=24.04
```

and supports:

```text
amd64
arm64
```

architectures.

Unsupported states fail before package installation.

## Target Account Validation

The provisioner requires:

```text
user: emir
group: emir
home: /home/emir
```

It validates all three before deployment.

It also checks that the account's actual passwd-database home matches:

```text
/home/emir
```

This prevents provisioning into an unexpected account layout.

## Source Asset Validation

All required repository-managed provisioning assets must exist and be readable.

The required set includes:

```text
application Dockerfile
Compose file
application index
monitoring script
backup script
Nginx site
backup systemd service
backup systemd timer
SSH hardening drop-in
```

Missing assets stop provisioning during preflight.

## Source Script Syntax Validation

Before deployment, the provisioner validates:

```text
provision/monitoring/health-check.sh
provision/backup/backup-sentinelops.sh
```

with:

```bash
bash -n
```

A syntax-invalid managed operational script therefore cannot be deployed by a successful preflight.

The main provisioner itself is separately syntax-checked before runtime testing.

## SSH Public-Key Readiness

SEN-025 formalizes the SSH safety prerequisite.

Before applying the drop-in that disables password authentication, the provisioner checks:

```text
/home/emir/.ssh
/home/emir/.ssh/authorized_keys
```

The `authorized_keys` file must:

```text
exist
be non-empty
contain a recognized public-key entry
```

Accepted public-key prefixes include:

```text
ssh-ed25519
ssh-rsa
ecdsa-sha2-*
```

This prevents the normal supported workflow from intentionally hardening SSH before trusted key-based access has been prepared.

## SSH Secret Boundary

The provisioner validates only the presence of public-key authentication material.

It does not distribute:

```text
private keys
passwords
tokens
credentials
```

through the repository.

This preserves the existing SentinelOps secret-handling model.

## Filesystem Capacity Validation

The current preflight requires:

```text
1048576 KiB
```

of free space on:

```text
/
```

before system-changing provisioning begins.

This is approximately:

```text
1 GiB
```

The value is deliberately simple and understandable rather than an attempt to predict every possible future package requirement.

The test VM had sufficient capacity and passed.

## Repository Resolution Validation

SEN-025 checks name resolution before package installation.

Docker repository reachability requires successful resolution of:

```text
download.docker.com
```

Ubuntu mirror hostnames are also inspected:

```text
ports.ubuntu.com
archive.ubuntu.com
security.ubuntu.com
```

Ubuntu mirror resolution is treated flexibly because the appropriate Ubuntu mirror can differ by architecture and environment.

Docker repository resolution is mandatory because the provisioning workflow explicitly depends on that repository.

## Managed Nginx Path Validation

SEN-025 inspects:

```text
/etc/nginx/sites-enabled/sentinelops
```

before deployment.

If the path exists as a symbolic link, that is valid already-provisioned SentinelOps state.

If it does not yet exist, that is valid clean-host state.

If it exists as an unexpected non-symlink object, provisioning stops instead of overwriting unknown configuration.

This reduces the risk of silently replacing conflicting administrator-managed state.

## TCP Port Validation

SEN-025 checks important existing listeners before deployment.

The checks use:

```bash
ss -Hltnp
```

The `-H` option suppresses the normal `ss` header so that an empty result is not mistaken for an existing listener.

This was caught during local review before the hardened provisioner was executed successfully.

## TCP Port 80 Policy

On an already-provisioned SentinelOps host, port 80 is expected to be owned by Nginx.

That state is accepted.

If port 80 is occupied by a process other than Nginx, the preflight fails.

On a clean host with no listener, the port is considered available.

## TCP Port 8000 Policy

The intended application backend is:

```text
127.0.0.1:8000
```

An existing loopback listener is accepted only when the expected:

```text
sentinelops-app
```

container is running.

Externally exposed forms such as:

```text
0.0.0.0:8000
[::]:8000
*:8000
```

are rejected.

An unexpected process on TCP 8000 is also rejected.

This allows repeated provisioning of the expected application while protecting the backend isolation requirement.

## Explicit Docker Group Convergence

SEN-025 checks whether the target user already belongs to:

```text
docker
```

before invoking:

```bash
usermod -aG docker
```

On an already-provisioned host it reports that membership already exists.

On a clean supported host without membership, it adds the group and explains that a new login session is required before the supplementary group becomes effective.

## Backup Idempotency Change

SEN-025 replaces unconditional initial-backup execution with:

```text
ensure_initial_backup
```

The function checks for an existing:

```text
sentinelops-backup-*.tar.gz
```

archive.

If none exists, the provisioner creates the first backup.

If one already exists, the provisioner reports:

```text
Existing SentinelOps backup archive found.
Skipping initial backup creation during repeated provisioning.
```

Scheduled backups remain the responsibility of:

```text
sentinelops-backup.timer
```

This separates provisioning initialization from ongoing backup scheduling.

## Controlled Preflight Failure Test

Before executing the hardened provisioner successfully, a controlled prerequisite failure was created entirely inside the disposable repository copy.

The command renamed:

```text
provision/application/Dockerfile
```

to:

```text
provision/application/Dockerfile.sen-025-test
```

No live system configuration was deliberately damaged.

The provisioner was then executed.

## Controlled Failure Output

The script progressed through:

```text
Starting SentinelOps provisioning preflight
Preflight: validating supported operating system
Preflight: validating target user and group
Preflight: validating provisioning source assets
```

and stopped with:

```text
[SEN-025] ERROR: Required provisioning asset missing: /home/emir/sentinelops-linux-infrastructure/provision/application/Dockerfile
```

The captured exit result was:

```text
EXIT_CODE=1
```

This directly demonstrated useful non-zero failure behavior.

## Controlled Failure Change Boundary

The failure occurred before:

```text
Installing base packages
Configuring Docker package repository
Deploying application assets
Deploying host Nginx configuration
Configuring UFW
Building and starting SentinelOps application
Ensuring SentinelOps initial backup exists
```

This demonstrated that the known missing prerequisite was detected before relevant system-changing operations.

## Controlled Failure State Comparison

Before the failure test, the live Nginx SHA-256 value was:

```text
31be518b3e0d3ff632022cb30b3d3005d279bbe6e6addd9fbfb0d1fddbbffd5a
```

After the failed provisioning attempt, it remained:

```text
31be518b3e0d3ff632022cb30b3d3005d279bbe6e6addd9fbfb0d1fddbbffd5a
```

Backup archive count before:

```text
2
```

Backup archive count after:

```text
2
```

Failed systemd units after:

```text
0 loaded units listed.
```

The test therefore produced no observed change to those live-state indicators.

## Controlled Failure Recovery

The deliberately renamed Dockerfile was restored to:

```text
provision/application/Dockerfile
```

before successful provisioning validation continued.

The test was reversible and did not require repair of the live SentinelOps runtime.

## Hardened Provisioner Static Validation

The rewritten provisioner passed:

```bash
bash -n provision/scripts/provision.sh
```

with exit status:

```text
0
```

`git diff --check` produced no output before runtime deployment.

The updated provisioner grew from approximately:

```text
487 lines
```

to:

```text
768 lines
```

during SEN-025 implementation.

The increase primarily represents explicit preflight checks, error handling, and explanatory validation rather than additional architecture components.

## Successful Hardened Repeated Run

After the controlled failure was restored and the `ss -H` correction was applied, the hardened provisioner was transferred to:

```text
sentinelops-test
```

and executed against the already-provisioned host.

The full preflight completed successfully.

It recognized the existing SentinelOps environment rather than treating correct existing state as a conflict.

## Existing State Recognition

The successful preflight accepted:

```text
existing trusted SSH public-key state
sufficient root-filesystem capacity
required repository resolution
existing SentinelOps Nginx symlink
existing Nginx TCP 80 listener
existing SentinelOps loopback TCP 8000 listener
running sentinelops-app container
```

This is important for FR-43 because validation itself must also tolerate valid repeated state.

## Successful Package Convergence

The hardened repeated run retained the package-manager behavior established by SEN-024.

Already-installed packages were treated as current.

No duplicate package state was created.

The Docker repository definition remained valid.

## Successful UFW Convergence

UFW again skipped existing rules.

The final numbered rule set remained:

```text
[1] 22/tcp
[2] Nginx HTTP
[3] 22/tcp (v6)
[4] Nginx HTTP (v6)
```

The rule count did not grow.

## Successful Docker Group Convergence

The target user remained in:

```text
docker
```

and the SEN-025 logic recognized existing membership rather than invoking an unnecessary group modification.

The effective groups remained:

```text
emir adm cdrom sudo dip plugdev lxd docker
```

## Successful Application Convergence

The application remained:

```text
sentinelops-app
Up
127.0.0.1:8000->80/tcp
```

Both direct and proxied application health returned:

```json
{"status":"healthy","version":"0.1.0"}
```

The required backend binding therefore remained unchanged.

## Successful Backup Convergence

Immediately before the hardened repeated execution, the backup archive count was:

```text
2
```

The provisioner detected an existing archive and skipped provisioning-specific backup creation.

After the run, the archive list remained:

```text
sentinelops-backup-20260904T194723Z.tar.gz
sentinelops-backup-20260904T221432Z.tar.gz
```

and the archive count remained:

```text
2
```

This demonstrated the SEN-025 backup idempotency change.

## Managed Configuration After Hardened Run

Final SHA-256 values included:

Nginx:

```text
31be518b3e0d3ff632022cb30b3d3005d279bbe6e6addd9fbfb0d1fddbbffd5a
```

SSH hardening:

```text
976d699973524cbe1ca0cd0e29898771e7b1030cb1b1d0476fd9ce9ee6fed831
```

Backup service:

```text
6f7f6a5d8d49fb8cb41b55bd3721ff57855584d387577a47d3a6f47fabb7b69d
```

Backup timer:

```text
da345fc89a90863e3c2bcfaba2dce14a9d3c00b55cd26f831082fd0c1562fce1
```

Repository-to-live `diff -u` checks produced no output for the managed configurations tested.

## Required Service Enablement

Final service enablement:

```text
nginx: enabled
docker: enabled
ssh.socket: enabled
sentinelops-backup.timer: enabled
```

## Required Service Activity

Final runtime state:

```text
nginx: active
docker: active
ssh.socket: active
sentinelops-backup.timer: active
```

## SSH Security Regression

Final effective SSH configuration remained:

```text
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
kbdinteractiveauthentication no
```

SEN-025 therefore preserved the established SSH security baseline.

## Firewall Security Regression

Final UFW state retained:

```text
active
default deny incoming
allow outgoing
deny routed
logging low
```

Allowed inbound application-facing rules remained limited to:

```text
22/tcp
80/tcp
```

with corresponding IPv6 rules.

No inbound UFW rule for TCP 8000 was introduced.

## Backend Isolation Regression

Docker Compose continued to publish:

```text
127.0.0.1:8000->80/tcp
```

The backend remained loopback-only.

No:

```text
0.0.0.0:8000
```

or:

```text
[::]:8000
```

listener was observed.

## External HTTP Regression

From the Mac host:

```bash
curl -i http://192.168.64.3/health
```

returned:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
```

with:

```json
{"status":"healthy","version":"0.1.0"}
```

This confirmed continued external access through host Nginx.

## External Backend Isolation

From the Mac host:

```bash
nc -vz -w 3 192.168.64.3 8000
```

returned:

```text
nc: connectx to 192.168.64.3 port 8000 (tcp) failed: Operation timed out
```

The private backend therefore remained externally inaccessible after repeated hardened provisioning.

## Failed systemd Unit Regression

Final:

```bash
systemctl --failed
```

reported:

```text
0 loaded units listed.
```

No failed systemd units were left by the controlled failure or successful repeated provisioning.

## FR-43 Assessment

FR-43 requires provisioning automation to be safe to execute more than once without creating duplicate users, duplicate rules, or invalid configuration.

Evidence includes:

```text
unchanged UFW rule count
no duplicate Docker group membership
managed files converged to repository state
services remained enabled and active
Compose application remained healthy
backend remained loopback-only
SSH hardening remained valid
backup count remained stable during hardened repeated execution
zero failed systemd units
```

The implementation also explicitly avoids unnecessary group modification when Docker membership already exists.

Result:

```text
FR-43: SATISFIED
```

## FR-44 Assessment

FR-44 requires important prerequisites to be validated before system changes.

SEN-025 adds a dedicated preflight validating:

```text
execution privilege
supported OS
architecture
target account
source assets
source script syntax
SSH key readiness
filesystem capacity
repository resolution
managed path assumptions
important port conflicts
```

A missing required asset was deliberately tested and stopped the provisioner before the deployment phase.

Result:

```text
FR-44: SATISFIED
```

## FR-45 Assessment

FR-45 requires useful output and appropriate exit behavior when automation fails.

The controlled missing-asset test returned:

```text
[SEN-025] ERROR: Required provisioning asset missing: ...
EXIT_CODE=1
```

Known validation failures use centralized `fail()` handling.

Unexpected command failures are supplemented with:

```text
exit code
line number
command
```

through the `ERR` trap.

Result:

```text
FR-45: SATISFIED
```

## Idempotency Scope

SEN-025 uses practical infrastructure idempotency rather than claiming that every command performs zero work on every repeated invocation.

For example:

```text
apt-get update may refresh repository metadata
Docker repository files may be rewritten to the same intended content
managed files may be reinstalled with the intended content and permissions
Nginx may be restarted
docker compose may perform a build check
UFW may evaluate existing rules
```

The required property is that repeated execution converges to valid intended state without accumulating duplicates or producing invalid configuration.

This is the behavior tested by SEN-025.

## Transaction Boundary

SEN-025 does not implement a general transactional rollback engine.

Once preflight has passed, an unpredictable later external failure could still leave some earlier deployment actions completed.

Examples include:

```text
repository outage after preflight
package-manager failure
unexpected disk failure
service failure during deployment
network interruption
```

The design instead reduces avoidable partial execution by moving known prerequisite validation before modification and ensures failures terminate with useful diagnostics.

Full transactional configuration management remains outside the current SentinelOps MVP scope.

## Network Validation Boundary

Repository preflight currently validates DNS resolution rather than performing an exhaustive download simulation for every Ubuntu package source.

Actual:

```text
apt-get update
curl -fsSL
```

operations remain authoritative checks during the modification phase and fail the script if the remote operation does not succeed.

## Package Version Boundary

Exact Docker package versions remain unpinned.

Provisioning installs current compatible packages from the configured repository.

Idempotency therefore means convergence to the repository-defined current package state, not permanent byte-for-byte package-version identity across different dates.

## Clean-Host Compatibility

SEN-025 preserves the clean-host model established by SEN-024.

The new preflight is designed to accept both:

```text
a valid clean supported host
an already-provisioned valid SentinelOps host
```

The `ss -H` correction was specifically made before successful runtime execution so an empty clean-host listener query is correctly treated as no conflict.

A completely new third clean Ubuntu VM was not created solely for SEN-025 because SEN-024 already provided the clean-host provisioning evidence and SEN-025 focused on repeated execution and validation hardening.

## Security Model

SEN-025 does not change the intended architecture:

```text
Mac/client
    |
    v
UFW
    |
    v
host Nginx :80
    |
    v
127.0.0.1:8000
    |
    v
Docker Compose application :80
```

Security properties remain:

```text
key-based SSH
no root SSH login
no SSH password authentication
default-deny inbound firewall
only required host-facing ports
loopback-only application backend
repository contains no private key material
```

## Operational Model

Operational components remain:

```text
host Nginx reverse proxy
Docker Compose application
health endpoint
structured monitoring
backup freshness monitoring
backup integrity verification
backup manifest verification
systemd backup service
persistent daily backup timer
```

SEN-025 hardens how these are provisioned rather than replacing them.

## Evidence Summary

SEN-025 produced evidence for:

```text
initial healthy repeated-run baseline
unchanged provisioner second execution
UFW idempotency
Docker-group idempotency
Compose convergence
managed-file convergence
baseline repeated-backup side effect
new preflight implementation
useful failure implementation
controlled missing-source failure
non-zero exit behavior
no live-state change during controlled preflight failure
successful hardened repeated execution
conditional initial-backup behavior
service regression validation
SSH regression validation
UFW regression validation
application health validation
external HTTP validation
external TCP 8000 isolation
zero failed systemd units
```

## Known Limitations

SEN-025 does not introduce:

```text
Ansible
Terraform
remote orchestration
multi-host inventory
transactional rollback
package-version locking
GitHub Actions
automated CI
```

These are not required to satisfy FR-43 through FR-45.

CI requirements remain separate work.

## SEN-025 Result

The provisioning workflow now moves beyond the SEN-024 repeatable clean-host baseline into tested repeated-execution automation.

The implementation demonstrates that an already-correct SentinelOps host can be provisioned again without:

```text
duplicate firewall rules
duplicate Docker group membership
invalid managed configuration
external backend exposure
SSH security regression
service failure
unnecessary provisioning-specific backup creation
```

It also demonstrates that an important missing prerequisite can terminate the workflow before deployment with an understandable error and non-zero exit status.

## Final Status

SEN-025 provisioning idempotency and validation baseline:

```text
Initial repository checkpoint: PASS

Requirements audit: PASS

Provisioner audit: PASS

Pre-second-run runtime baseline: PASS

Unchanged second provisioning execution: PASS

APT convergence: PASS

Docker package convergence: PASS

Docker group convergence: PASS

UFW duplicate-rule prevention: PASS

Compose convergence: PASS

Managed configuration convergence: PASS

Baseline backup side effect identified: PASS

Preflight implementation: PASS

Root validation: PASS

OS validation: PASS

Architecture validation: PASS

Target user/group/home validation: PASS

Source asset validation: PASS

Source shell syntax validation: PASS

SSH public-key readiness validation: PASS

Filesystem capacity validation: PASS

Repository resolution validation: PASS

Managed Nginx path validation: PASS

Port conflict validation: PASS

Central failure helper: PASS

Unexpected error diagnostics: PASS

Controlled missing-asset failure: PASS

Controlled failure exit code: 1

Controlled failure before deployment: PASS

Controlled failure Nginx state unchanged: PASS

Controlled failure backup count unchanged: PASS

Controlled failure failed units: 0

Controlled failure recovery: PASS

Hardened repeated provisioning: PASS

Repeated backup count stable at 2: PASS

UFW rules stable at 4: PASS

Required services enabled: PASS

Required services active: PASS

Application backend health: PASS

Host Nginx health: PASS

SSH security regression: PASS

External HTTP health: PASS

External TCP 8000 isolation: PASS

Failed systemd units: 0

FR-43: SATISFIED

FR-44: SATISFIED

FR-45: SATISFIED
```

SEN-025 establishes that the SentinelOps provisioning workflow is safely repeatable for the validated target architecture, checks important prerequisites before modification where practical, and produces useful non-zero failures when provisioning cannot safely continue.