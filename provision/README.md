# SentinelOps Provisioning

## Purpose

This directory contains the version-controlled assets and provisioning workflow required to reproduce and maintain the SentinelOps single-server environment on a supported Ubuntu Server host.

The provisioning workflow translates infrastructure that was originally configured, inspected, secured, and validated manually into a repeatable and tested automation process.

SEN-024 established the clean-host repeatable provisioning baseline.

SEN-025 hardened that baseline by adding:

```text
idempotent repeated execution
pre-change prerequisite validation
useful provisioning failure handling
conditional initial-backup behavior
explicit existing-state validation
```

SEN-026 added the first GitHub Actions continuous-integration baseline for automated repository validation.

SEN-027 extends that CI baseline with:

```text
Docker Compose configuration validation
container security-state validation
Docker image build validation
application startup validation
health endpoint availability validation
HTTP status validation
health response content validation
automatic Compose cleanup
```

The provisioning workflow is designed to support both:

```text
a clean supported Ubuntu host
an already-provisioned valid SentinelOps host
```

Repeated execution should converge the host toward the intended SentinelOps state without creating duplicate firewall rules, duplicate group membership, invalid managed configuration, or unnecessary provisioning-specific backup archives.

Repository changes affecting the provisioning workflow are additionally validated automatically through GitHub Actions.

## Supported Environment

The current supported baseline is:

- Ubuntu Server 24.04 LTS
- systemd
- OpenSSH
- UFW
- host Nginx
- Docker Engine
- Docker Compose

The original SentinelOps environment was validated on:

```text
Ubuntu Server 24.04.4 LTS
aarch64
```

The disposable automation test environment was also validated on:

```text
Ubuntu Server 24.04.4 LTS
arm64
```

The provisioning script validates:

```text
operating system: Ubuntu
release: 24.04
architecture: amd64 or arm64
```

before entering the system-changing provisioning phase.

## Target Architecture

The resulting host should implement:

```text
Client
  |
  v
UFW
  |
  v
Host Nginx :80
  |
  v
127.0.0.1:8000
  |
  v
Docker Compose application :80
```

The application backend must remain bound only to:

```text
127.0.0.1:8000
```

TCP port 8000 must not be exposed externally.

The expected externally reachable host services are:

```text
22/tcp
80/tcp
```

## Repository Structure

Provisioning assets are stored under:

```text
provision/
├── README.md
├── application/
│   ├── Dockerfile
│   ├── compose.yaml
│   └── index.html
├── backup/
│   └── backup-sentinelops.sh
├── monitoring/
│   └── health-check.sh
├── nginx/
│   └── sentinelops
├── scripts/
│   └── provision.sh
├── ssh/
│   └── 00-sentinelops.conf
└── systemd/
    ├── sentinelops-backup.service
    └── sentinelops-backup.timer
```

Repository-level CI configuration is stored separately at:

```text
.github/workflows/ci.yml
```

## Requirements Covered

The provisioning and automation baseline currently provides implementation and validation evidence for:

```text
FR-41: Manual Understanding Before Automation
FR-42: Repeatable Provisioning
FR-43: Idempotent Automation
FR-44: Automation Validation
FR-45: Useful Automation Failures
FR-46: Continuous Integration
FR-47: Shell Validation
FR-48: Container Validation
FR-49: Application Testing
FR-50: Secret Protection
```

SEN-024 established:

```text
FR-41
FR-42
```

SEN-025 established:

```text
FR-43
FR-44
FR-45
```

SEN-026 established:

```text
FR-46
FR-47
FR-50
```

SEN-027 establishes:

```text
FR-48
FR-49
```

The CI requirements defined for the current SentinelOps MVP are therefore implemented through the shared GitHub Actions workflow.

## Prerequisites

The provisioning script does not create the primary administrator account.

Before running the script, the target host must already contain:

```text
user: emir
group: emir
home: /home/emir
```

The `emir` account must have administrative `sudo` access.

The provisioner validates the user, group, and expected home-directory relationship before continuing.

## SSH Access Prerequisite

Before password authentication is disabled, public-key SSH access must already be configured for the `emir` account.

Expected SSH directory:

```text
/home/emir/.ssh
```

Expected authorized-key file:

```text
/home/emir/.ssh/authorized_keys
```

The provisioner requires the `authorized_keys` file to:

```text
exist
be non-empty
contain a recognized SSH public-key entry
```

Recognized key prefixes include:

```text
ssh-ed25519
ssh-rsa
ecdsa-sha2-*
```

Do not run the provisioning workflow remotely unless public-key authentication has already been independently verified.

Console access to the VM should remain available during initial provisioning.

No private SSH key is stored in this repository.

## Provisioning Preflight

SEN-025 introduces a dedicated preflight stage.

The preflight runs before package installation, managed configuration deployment, firewall modification, application deployment, or provisioning-specific backup creation.

The preflight validates:

```text
root execution
supported operating system
supported architecture
target user
target group
target home directory
required repository assets
repository-managed shell-script syntax
SSH public-key readiness
available root-filesystem capacity
required repository name resolution
managed Nginx path assumptions
important TCP port conflicts
```

Successful preflight completion is reported as:

```text
[SEN-025] Provisioning preflight completed successfully
```

Only after this point does the provisioner enter the system-changing phase.

## Root Execution

The provisioner must run as root.

Normal execution from the repository root is:

```bash
sudo ./provision/scripts/provision.sh
```

Running without root privileges produces a controlled error instead of continuing partially.

## Operating System Validation

The provisioner reads:

```text
/etc/os-release
```

and requires:

```text
ID=ubuntu
VERSION_ID=24.04
```

The architecture is determined using:

```bash
dpkg --print-architecture
```

Supported architectures are:

```text
amd64
arm64
```

Unsupported operating systems, releases, or architectures stop provisioning during preflight.

## Target Account Validation

The required target account state is:

```text
user: emir
group: emir
home: /home/emir
```

The provisioner verifies:

```text
the user exists
the group exists
the expected home directory exists
the passwd database reports /home/emir as the account home
```

Provisioning stops if the account layout does not match the supported SentinelOps model.

## Source Asset Validation

Before deployment, the provisioner verifies that all required repository assets exist and are readable.

Required application assets:

```text
provision/application/Dockerfile
provision/application/compose.yaml
provision/application/index.html
```

Required monitoring asset:

```text
provision/monitoring/health-check.sh
```

Required backup asset:

```text
provision/backup/backup-sentinelops.sh
```

Required Nginx asset:

```text
provision/nginx/sentinelops
```

Required systemd assets:

```text
provision/systemd/sentinelops-backup.service
provision/systemd/sentinelops-backup.timer
```

Required SSH asset:

```text
provision/ssh/00-sentinelops.conf
```

A missing required asset stops provisioning before live configuration changes begin.

## Repository-Managed Script Validation

Before deployment, the provisioner syntax-checks the operational shell scripts using:

```bash
bash -n
```

Validated scripts include:

```text
provision/monitoring/health-check.sh
provision/backup/backup-sentinelops.sh
```

The main provisioner should also be checked before deployment:

```bash
bash -n provision/scripts/provision.sh
```

A syntax-invalid managed operational script is therefore not intentionally deployed by a successful preflight.

GitHub Actions additionally performs automated Bash syntax and ShellCheck validation against repository shell scripts before merge.

## Filesystem Capacity Validation

The current provisioning policy requires at least:

```text
1048576 KiB
```

of free space on:

```text
/
```

before the system-changing provisioning phase starts.

This is approximately:

```text
1 GiB
```

The check is intended to reject obviously insufficient filesystem capacity before package installation and container build activity begin.

## Repository Resolution Validation

The preflight checks name resolution for repositories required by the workflow.

Docker repository resolution is mandatory for:

```text
download.docker.com
```

Ubuntu mirror hostnames are also inspected:

```text
ports.ubuntu.com
archive.ubuntu.com
security.ubuntu.com
```

Ubuntu mirror selection can vary by architecture and environment, so the Ubuntu mirror checks are informative where appropriate.

Actual package and repository operations remain authoritative later through:

```text
apt-get update
curl -fsSL
```

If those operations fail, provisioning terminates.

## Managed Path Validation

The provisioner checks the managed Nginx enabled-site path:

```text
/etc/nginx/sites-enabled/sentinelops
```

Valid states are:

```text
path absent
path present as a symbolic link
```

If the path exists as an unexpected non-symbolic-link object, provisioning stops rather than overwriting unknown administrator-managed state.

An already-existing SentinelOps symbolic link is valid repeated-provisioning state.

## Port Conflict Validation

Important existing TCP listener state is checked before deployment.

The provisioner uses:

```bash
ss -Hltnp
```

The `-H` option suppresses the normal `ss` heading so an empty listener result can be correctly identified.

### TCP Port 80

Valid states include:

```text
port 80 unused on a clean host
port 80 already owned by Nginx on a provisioned host
```

If port 80 is occupied by another process, provisioning stops.

### TCP Port 8000

The intended application backend state is:

```text
127.0.0.1:8000
```

On an already-provisioned SentinelOps host, this listener is accepted when the expected application container is running.

The following externally bound states are rejected:

```text
0.0.0.0:8000
[::]:8000
*:8000
```

An unexpected process occupying TCP 8000 is also rejected.

## Provisioning Assets

### Application

The application assets are stored in:

```text
provision/application/
```

They are deployed to:

```text
/home/emir/sentinelops-app/
```

Expected deployed files include:

```text
Dockerfile
compose.yaml
index.html
```

The Compose application publishes:

```text
127.0.0.1:8000 -> container port 80
```

The application provides:

```text
/health
```

Expected health response:

```json
{"status":"healthy","version":"0.1.0"}
```

SEN-027 verifies this same behaviour automatically in GitHub Actions.

### Monitoring

The monitoring script is stored at:

```text
provision/monitoring/health-check.sh
```

and deployed to:

```text
/home/emir/sentinelops-monitoring/health-check.sh
```

The structured monitoring log is:

```text
/var/log/sentinelops/health-check.log
```

Expected log permissions:

```text
owner: emir
group: emir
mode: 0640
```

Expected log directory:

```text
owner: root
group: emir
mode: 0750
```

The monitoring workflow evaluates operational state including:

```text
disk usage
backup freshness
Docker service
Nginx service
SSH service
Compose application
application health
host Nginx health
```

### Backup

The backup script is stored at:

```text
provision/backup/backup-sentinelops.sh
```

and deployed to:

```text
/home/emir/backups/sentinelops/backup-sentinelops.sh
```

The backup workflow preserves:

- UTC timestamped archives;
- SHA-256 checksum generation;
- SHA-256 verification;
- manifest generation;
- manifest verification;
- seven-day retention;
- restrictive backup artifact permissions.

Backup archives are stored under:

```text
/home/emir/backups/sentinelops/
```

### Nginx

The host Nginx site configuration is stored at:

```text
provision/nginx/sentinelops
```

and deployed to:

```text
/etc/nginx/sites-available/sentinelops
```

It is enabled through:

```text
/etc/nginx/sites-enabled/sentinelops
```

The configuration proxies traffic to:

```text
http://127.0.0.1:8000
```

The managed configuration is syntax-tested before Nginx is restarted.

### systemd

The backup units are stored under:

```text
provision/systemd/
```

and deployed to:

```text
/etc/systemd/system/sentinelops-backup.service
/etc/systemd/system/sentinelops-backup.timer
```

The timer runs daily and uses:

```ini
Persistent=true
```

The required timer should remain:

```text
enabled
active
```

after successful provisioning.

### SSH

The SentinelOps SSH hardening drop-in is:

```text
provision/ssh/00-sentinelops.conf
```

The deployed path is:

```text
/etc/ssh/sshd_config.d/00-sentinelops.conf
```

Expected effective settings:

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
```

The configuration is syntax-tested with:

```bash
sshd -t
```

before any running SSH service is reloaded.

### Firewall

The provisioning workflow establishes:

```text
default incoming: deny
default outgoing: allow
default routed: deny
logging: low
```

Allowed inbound services:

```text
22/tcp
80/tcp
```

TCP port 8000 is not added to UFW.

Repeated execution relies on UFW's existing-rule detection and must not accumulate duplicate rules.

## Docker Repository

Docker is installed from Docker's Ubuntu package repository.

The provisioning workflow creates or converges:

```text
/etc/apt/keyrings/docker.asc
/etc/apt/sources.list.d/docker.sources
```

The repository suite is derived from the Ubuntu release codename.

The machine architecture is derived using:

```bash
dpkg --print-architecture
```

The workflow therefore does not hard-code the original VM's `arm64` architecture.

Exact Docker package versions are not pinned.

Provisioning installs the compatible versions currently available from the configured repository.

## Docker Group Membership

The `emir` account requires membership in:

```text
docker
```

SEN-025 checks existing membership before running:

```bash
usermod -aG docker emir
```

If membership already exists, no group modification is required.

If membership is newly added, a fresh login session is required before the supplementary group is available to the user's shell.

Repeated provisioning must not create duplicate or invalid group state.

## Provisioning Order

The hardened provisioning workflow executes in this order:

```text
1. start provisioning preflight
2. require root execution
3. validate Ubuntu release
4. validate supported architecture
5. validate target user
6. validate target group
7. validate target home directory
8. validate required repository assets
9. validate managed shell-script syntax
10. validate SSH public-key readiness
11. validate available root-filesystem capacity
12. validate required repository resolution
13. validate managed Nginx path assumptions
14. validate important TCP port conflicts
15. complete provisioning preflight
16. install base packages
17. configure Docker repository
18. install Docker Engine and Docker Compose
19. converge Docker group membership
20. create required directories
21. deploy application assets
22. deploy monitoring
23. deploy backup workflow
24. deploy host Nginx configuration
25. deploy backup systemd units
26. deploy SSH hardening
27. configure UFW
28. build and start the Docker Compose application
29. ensure an initial backup exists
30. validate service enablement
31. validate service activity
32. validate effective SSH security
33. validate direct application health
34. validate host Nginx health
35. validate network listeners
36. validate firewall state
37. validate newest backup integrity
38. validate newest backup manifest
39. run SentinelOps monitoring
40. verify there are no failed systemd units
```

## Running the Provisioner

From the root of a checked-out SentinelOps repository on the Ubuntu host:

```bash
sudo ./provision/scripts/provision.sh
```

The script uses:

```bash
set -Eeuo pipefail
```

This provides:

```text
exit on unhandled command failure
unset-variable protection
pipeline failure propagation
ERR trap inheritance
```

The provisioner also uses explicit validation failures and an unexpected-error trap.

## Successful Preflight Output

A successful preflight should progress through checks such as:

```text
[SEN-025] Starting SentinelOps provisioning preflight
[SEN-025] Preflight: validating supported operating system
[SEN-025] Preflight: validating target user and group
[SEN-025] Preflight: validating provisioning source assets
[SEN-025] Preflight: validating repository-managed shell scripts
[SEN-025] Preflight: validating SSH public-key readiness
[SEN-025] Preflight: validating available filesystem capacity
[SEN-025] Preflight: validating required repository name resolution
[SEN-025] Preflight: validating managed configuration paths
[SEN-025] Preflight: validating important TCP port conflicts
[SEN-025] Provisioning preflight completed successfully
```

Only after successful completion should package installation and host modification begin.

## Expected Final Service State

These components should be enabled:

```text
nginx
docker
ssh.socket
sentinelops-backup.timer
```

These components should also be active:

```text
nginx
docker
ssh.socket
sentinelops-backup.timer
```

Validation commands:

```bash
systemctl is-enabled nginx
systemctl is-enabled docker
systemctl is-enabled ssh.socket
systemctl is-enabled sentinelops-backup.timer
```

and:

```bash
systemctl is-active nginx
systemctl is-active docker
systemctl is-active ssh.socket
systemctl is-active sentinelops-backup.timer
```

Expected result for each required component:

```text
enabled
active
```

## Expected Network State

Expected listeners include:

```text
0.0.0.0:22
0.0.0.0:80
127.0.0.1:8000
```

IPv6 listeners may also exist for SSH and Nginx.

There must not be an external application-backend listener such as:

```text
0.0.0.0:8000
[::]:8000
```

The provisioner validates that the backend remains loopback-only.

SEN-027 CI additionally confirms that the repository Compose configuration contains:

```text
127.0.0.1:8000:80
```

before the application is built and started.

## Expected Health State

Direct backend request:

```bash
curl http://127.0.0.1:8000/health
```

Expected:

```json
{"status":"healthy","version":"0.1.0"}
```

Host reverse-proxy request:

```bash
curl http://127.0.0.1/health
```

Expected:

```json
{"status":"healthy","version":"0.1.0"}
```

Both requests should return HTTP 200.

SEN-027 CI automatically verifies the direct Compose application health endpoint in a GitHub-hosted runner.

## Backup Initialization

The provisioning workflow ensures that at least one SentinelOps backup exists.

On a newly provisioned host where no SentinelOps backup archive exists, the provisioner runs:

```bash
systemctl start sentinelops-backup.service
```

to generate the initial backup.

On an already-provisioned host where at least one backup archive exists, the provisioner does not create an additional backup solely because provisioning was executed again.

Expected repeated-run output:

```text
Existing SentinelOps backup archive found.
Skipping initial backup creation during repeated provisioning.
```

This separates provisioning initialization from normal scheduled backup creation.

Normal backups remain controlled by:

```text
sentinelops-backup.timer
```

## Backup Validation

The newest archive must have corresponding:

```text
.tar.gz
.tar.gz.sha256
.tar.gz.manifest
```

artifacts.

The checksum must pass:

```bash
sha256sum --check
```

The manifest must match the actual archive listing.

The provisioner validates the newest backup before successful completion.

Repeated provisioning must preserve existing valid backups.

## Security Validation

After provisioning, verify:

```bash
sudo sshd -T | grep -Ei \
'passwordauthentication|permitrootlogin|pubkeyauthentication|kbdinteractiveauthentication'
```

Expected effective configuration:

```text
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
kbdinteractiveauthentication no
```

Verify UFW:

```bash
sudo ufw status verbose
```

Expected security properties:

```text
Status: active
Default: deny incoming
Default: allow outgoing
Default: deny routed
22/tcp allowed
80/tcp allowed
8000/tcp not allowed
```

The application backend must still be:

```text
127.0.0.1:8000
```

## Nginx Validation

Validate host configuration:

```bash
sudo nginx -t
```

The test must succeed before the host configuration is considered valid.

Repository-managed Nginx configuration should converge with:

```text
provision/nginx/sentinelops
```

The live managed file is:

```text
/etc/nginx/sites-available/sentinelops
```

A repository-to-host comparison can be performed with:

```bash
sudo diff -u \
  provision/nginx/sentinelops \
  /etc/nginx/sites-available/sentinelops
```

No output means the compared files are identical.

## Managed Configuration Convergence

The provisioning workflow owns and repeatedly deploys managed configuration including:

```text
/etc/nginx/sites-available/sentinelops
/etc/ssh/sshd_config.d/00-sentinelops.conf
/etc/systemd/system/sentinelops-backup.service
/etc/systemd/system/sentinelops-backup.timer
```

Repeated provisioning should converge these paths toward the repository versions.

Runtime validation during SEN-025 confirmed `diff -u` produced no output for the managed configuration comparisons tested after provisioning.

The validated Nginx repository/live SHA-256 value was:

```text
31be518b3e0d3ff632022cb30b3d3005d279bbe6e6addd9fbfb0d1fddbbffd5a
```

The validated SSH hardening SHA-256 value was:

```text
976d699973524cbe1ca0cd0e29898771e7b1030cb1b1d0476fd9ce9ee6fed831
```

The validated backup-service SHA-256 value was:

```text
6f7f6a5d8d49fb8cb41b55bd3721ff57855584d387577a47d3a6f47fabb7b69d
```

The validated backup-timer SHA-256 value was:

```text
da345fc89a90863e3c2bcfaba2dce14a9d3c00b55cd26f831082fd0c1562fce1
```

These hashes are evidence from the SEN-025 validation environment, not permanent package or configuration-version identifiers.

## Idempotent Repeated Execution

SEN-025 validates the provisioner against an already-provisioned SentinelOps host.

Before hardening, the unchanged SEN-024 provisioner was deliberately executed a second time to measure actual repeated behavior.

The baseline run demonstrated that several existing operations already converged safely:

```text
APT package installation
Docker package installation
Docker service enablement
Docker group membership
UFW rules
Nginx enablement
SSH configuration deployment
systemd unit deployment
Docker Compose application state
service activity
network isolation
```

SEN-025 then hardened the areas that required clearer validation or reduced repeated side effects.

## UFW Idempotency

During repeated provisioning, UFW reported:

```text
Skipping adding existing rule
Skipping adding existing rule (v6)
```

rather than duplicating existing rules.

The final numbered rule set remained:

```text
[1] 22/tcp
[2] Nginx HTTP
[3] 22/tcp (v6)
[4] Nginx HTTP (v6)
```

Repeated execution must not cause this rule count to grow merely because provisioning is rerun.

## Docker Group Idempotency

The target account already belonged to:

```text
docker
```

during SEN-025 repeated execution.

The final effective groups remained:

```text
emir adm cdrom sudo dip plugdev lxd docker
```

SEN-025 explicitly detects existing membership and avoids an unnecessary `usermod` operation.

## Docker Compose Idempotency

Repeated:

```bash
docker compose up -d --build
```

may evaluate the build and reconcile the Compose project.

The required property is convergence to the intended application state.

Expected final application state:

```text
sentinelops-app
Up
127.0.0.1:8000->80/tcp
```

During the SEN-025 repeated-run validation, the healthy existing container remained running.

## Backup Idempotency

The SEN-024 baseline ran the backup service during every successful provisioning execution.

That behavior caused the baseline repeated-run archive count to change:

```text
1 -> 2
```

SEN-025 replaces that unconditional behavior with an initial-backup existence check.

During the hardened repeated run, backup count remained:

```text
2 -> 2
```

The existing validated archives were:

```text
sentinelops-backup-20260904T194723Z.tar.gz
sentinelops-backup-20260904T221432Z.tar.gz
```

The scheduled backup mechanism remains unchanged.

## Failure Handling

SEN-025 centralizes known validation failures through:

```bash
fail()
```

Expected controlled failure format:

```text
[SEN-025] ERROR: <failure reason>
```

The failure helper exits with a non-zero status.

Unexpected command failures are handled by an `ERR` trap.

Unexpected failures report:

```text
[SEN-025] ERROR: Provisioning stopped unexpectedly.
[SEN-025] ERROR: Exit code: <code>
[SEN-025] ERROR: Line: <line>
[SEN-025] ERROR: Command: <command>
```

This provides useful troubleshooting information while preserving immediate failure behavior.

## Controlled Failure Validation

SEN-025 was tested with a deliberately missing repository prerequisite.

Inside the disposable test repository copy:

```text
provision/application/Dockerfile
```

was temporarily renamed to:

```text
provision/application/Dockerfile.sen-025-test
```

The live SentinelOps runtime was not deliberately altered for this test.

Running the provisioner produced:

```text
[SEN-025] Starting SentinelOps provisioning preflight

[SEN-025] Preflight: validating supported operating system

[SEN-025] Preflight: validating target user and group

[SEN-025] Preflight: validating provisioning source assets

[SEN-025] ERROR: Required provisioning asset missing: /home/emir/sentinelops-linux-infrastructure/provision/application/Dockerfile
```

The captured exit result was:

```text
EXIT_CODE=1
```

The script stopped before:

```text
base package installation
Docker repository configuration
application deployment
Nginx deployment
UFW changes
Docker Compose deployment
backup creation
```

## Controlled Failure State Preservation

Before the controlled preflight failure, the live Nginx SHA-256 value was:

```text
31be518b3e0d3ff632022cb30b3d3005d279bbe6e6addd9fbfb0d1fddbbffd5a
```

After the failed provisioning attempt, it remained:

```text
31be518b3e0d3ff632022cb30b3d3005d279bbe6e6addd9fbfb0d1fddbbffd5a
```

Backup archive count remained:

```text
2
```

Failed systemd units remained:

```text
0 loaded units listed.
```

The deliberately renamed source file was then restored before successful runtime validation continued.

## Successful Repeated-Run Validation

The hardened SEN-025 provisioner was executed successfully on the already-provisioned disposable test VM.

The preflight correctly accepted:

```text
Ubuntu 24.04.4 LTS
arm64
existing emir account
existing trusted SSH public key
adequate filesystem capacity
working repository resolution
existing SentinelOps Nginx symlink
existing Nginx TCP port 80 listener
existing SentinelOps 127.0.0.1:8000 listener
running SentinelOps application container
```

The provisioner completed successfully without treating valid existing state as a conflict.

## Successful Repeated-Run Final State

After the hardened repeated run:

```text
nginx: enabled
docker: enabled
ssh.socket: enabled
sentinelops-backup.timer: enabled
```

and:

```text
nginx: active
docker: active
ssh.socket: active
sentinelops-backup.timer: active
```

The application remained:

```text
sentinelops-app
Up
127.0.0.1:8000->80/tcp
```

UFW remained:

```text
[1] 22/tcp
[2] Nginx HTTP
[3] 22/tcp (v6)
[4] Nginx HTTP (v6)
```

Backup count remained:

```text
2
```

Failed systemd units remained:

```text
0
```

## External Validation

From the Mac host, external health validation used:

```bash
curl -i http://192.168.64.3/health
```

The test returned:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
```

with:

```json
{"status":"healthy","version":"0.1.0"}
```

This confirms external HTTP still reaches the application through host Nginx.

External backend isolation was checked using:

```bash
nc -vz -w 3 192.168.64.3 8000
```

The result was:

```text
nc: connectx to 192.168.64.3 port 8000 (tcp) failed: Operation timed out
```

TCP port 8000 therefore remained externally inaccessible.

## Failed Unit Validation

Check systemd after provisioning:

```bash
systemctl --failed
```

Expected:

```text
0 loaded units listed.
```

SEN-025 validation ended with no failed systemd units.

## Monitoring Validation

The provisioner executes:

```text
/home/emir/sentinelops-monitoring/health-check.sh
```

after deployment.

A successful final monitoring run should verify the expected operational state and complete without reporting a failed SentinelOps health condition.

Monitoring does not replace the provisioner's direct configuration and security validations.

It provides an additional operational regression check.

## Secret Handling

The repository must not contain:

- private SSH keys;
- passwords;
- API tokens;
- authentication secrets;
- private credentials.

Public SSH keys remain host-specific prerequisites and are not embedded into the provisioning assets.

The provisioning preflight verifies public-key readiness without distributing or storing private authentication material.

SEN-026 additionally introduces automated GitHub Actions secret-pattern validation for tracked repository files.

The CI secret-safety job checks for obvious prohibited secret-like content including:

```text
private-key header patterns
obvious password assignments
obvious token assignments
obvious secret assignments
```

When suspicious content is detected, CI reports affected file paths without intentionally printing the matching value.

The CI workflow itself requires no production credentials.

SEN-027 does not change that credential boundary.

## GitHub Actions CI

SEN-026 introduced:

```text
.github/workflows/ci.yml
```

Workflow name:

```text
SentinelOps CI
```

SEN-026 established:

```text
Shell validation
Secret safety
```

SEN-027 extends the same workflow with:

```text
Container and application validation
```

The current workflow therefore contains three independent validation jobs:

```text
Shell validation
Secret safety
Container and application validation
```

The workflow is designed to provide automated repository, container, and application validation before changes are accepted.

## CI Triggers

The GitHub Actions workflow runs automatically for:

```text
pull requests
pushes to main
```

This provides:

```text
pre-merge validation
default-branch validation
```

The pull-request trigger was exercised directly during SEN-026 and SEN-027.

The push-to-main trigger was successfully verified after SEN-026 was merged.

SEN-027 preserves the same trigger model.

## CI Permissions

The workflow declares:

```yaml
permissions:
  contents: read
```

The workflow therefore uses read-only repository content access.

The validation jobs do not require:

```text
production credentials
private SSH keys
deployment secrets
cloud access credentials
repository write permissions
VM login credentials
```

## CI Shell Discovery

The shell-validation job discovers shell scripts using the repository provisioning tree.

Current shell scripts include:

```text
provision/scripts/provision.sh
provision/monitoring/health-check.sh
provision/backup/backup-sentinelops.sh
```

New `*.sh` files created under the provisioning tree are also included automatically.

This behavior was demonstrated during the controlled SEN-026 failure test.

## Automated Bash Syntax Validation

GitHub Actions runs:

```bash
bash -n
```

against discovered provisioning shell scripts.

A syntax-invalid script causes:

```text
Shell validation
```

to fail with a non-zero workflow result.

During SEN-026, an intentionally malformed synthetic script was detected automatically.

## Automated ShellCheck Validation

GitHub Actions installs ShellCheck inside the GitHub-hosted Ubuntu runner.

The workflow then performs static analysis against the discovered provisioning shell scripts.

ShellCheck therefore does not need to be installed on the developer Mac.

## ShellCheck Finding During SEN-026

The first real CI execution reported:

```text
Shell validation: FAIL
Secret safety: PASS
```

ShellCheck identified:

```text
SC1091
```

in:

```text
provision/scripts/provision.sh
```

for a runtime source of:

```text
/etc/os-release
```

used while determining the Ubuntu release codename.

The operating-system file exists on the target host but is not part of the repository checkout, so ShellCheck cannot statically follow it.

## ShellCheck Resolution

The finding was reviewed rather than disabled globally.

A specific directive was added immediately before the relevant runtime source operation:

```text
# shellcheck disable=SC1091
```

No broad ShellCheck configuration was introduced.

No unrelated warning category was suppressed.

After the specific fix was pushed:

```text
Shell validation: PASS
Secret safety: PASS
```

## Controlled SEN-026 CI Failure

After establishing the first clean CI state, SEN-026 deliberately demonstrated workflow enforcement using a temporary synthetic script:

```text
provision/sen-026-ci-failure-test.sh
```

The file contained a deliberately incomplete Bash conditional.

Local syntax validation returned:

```text
syntax error: unexpected end of file
EXIT_CODE=2
```

The synthetic script contained no secret material and did not alter real SentinelOps runtime code.

## Controlled SEN-026 CI Failure Result

The temporary script was committed and pushed to the SEN-026 feature branch.

GitHub Actions automatically discovered the new shell script.

The resulting CI state was:

```text
Shell validation: FAIL
Secret safety: PASS
```

The failed step identified:

```text
provision/sen-026-ci-failure-test.sh
```

and reported:

```text
syntax error: unexpected end of file
```

GitHub Actions completed the shell-validation step with:

```text
exit code 2
```

This demonstrated that invalid shell syntax is automatically rejected.

## Controlled SEN-026 Recovery

After failure evidence was captured, the synthetic file was deleted.

The real SentinelOps shell scripts were revalidated locally.

The removal was committed and pushed.

The final pull-request CI state returned to:

```text
Shell validation: PASS
Secret safety: PASS
```

The temporary failure script does not remain in the final repository tree.

## SEN-026 CI Run Sequence

The important SEN-026 pull-request sequence was:

```text
Run 1
Shell validation: FAIL
Secret safety: PASS
Reason: real ShellCheck SC1091 finding

Run 2
Shell validation: PASS
Secret safety: PASS
Reason: specific SC1091 handling applied

Run 3
Shell validation: FAIL
Secret safety: PASS
Reason: controlled synthetic Bash syntax failure

Run 4
Shell validation: PASS
Secret safety: PASS
Reason: synthetic failure removed
```

This provides both successful and failing repository-validation evidence.

## SEN-026 CI Commit Sequence

The important SEN-026 implementation commits were:

```text
8ef73ba ci: add SEN-026 GitHub Actions foundation
63f5c68 fix: resolve SEN-026 ShellCheck finding
6d14acd test: demonstrate SEN-026 CI shell failure
5a40a22 test: recover SEN-026 CI failure simulation
```

## Container and Application CI Validation

SEN-027 adds:

```text
container-application-validation
```

displayed in GitHub Actions as:

```text
Container and application validation
```

The job runs on:

```text
ubuntu-latest
```

and uses:

```text
provision/application
```

as its working directory.

## Docker Tooling Verification

The SEN-027 job begins with:

```bash
docker --version
docker compose version
```

This verifies that the GitHub-hosted runner provides the Docker tooling required by the job.

The developer Mac does not need Docker installed for this CI workflow.

If Docker tooling becomes unavailable in the selected runner environment, CI fails visibly before container validation continues.

## Docker Compose Configuration Validation

The workflow executes:

```bash
docker compose config
```

This verifies that:

```text
provision/application/compose.yaml
```

can be parsed successfully.

Invalid Docker Compose configuration therefore causes CI failure before application startup.

## Container Security Configuration Validation

SEN-027 performs explicit checks against the Compose configuration.

The expected loopback-only publication is:

```text
127.0.0.1:8000:80
```

If this mapping is absent, CI fails.

The workflow also rejects:

```text
privileged: true
```

if privileged container mode is explicitly enabled.

These checks preserve two important SentinelOps properties:

```text
application backend remains loopback-only
application container does not run privileged
```

## Docker Image Build Validation

The workflow runs:

```bash
docker compose build
```

The CI job therefore verifies that the repository Dockerfile and associated application assets can produce a valid image.

Build failure causes the job to fail.

## Application Startup Validation

After a successful build, CI runs:

```bash
docker compose up -d
```

The application must start successfully inside the GitHub-hosted runner before application behaviour testing continues.

## Health Endpoint Availability Validation

CI repeatedly requests:

```text
http://127.0.0.1:8000/health
```

The wait loop performs up to:

```text
30 attempts
```

with:

```text
2 seconds
```

between unsuccessful attempts.

If the endpoint never becomes available, the workflow reports:

```bash
docker compose ps
docker compose logs
```

and exits non-zero.

## HTTP Status Validation

After application availability is confirmed, CI makes a dedicated request to:

```text
http://127.0.0.1:8000/health
```

Expected HTTP status:

```text
200
```

Any other status causes the validation to fail.

## Health Response Validation

The health body is parsed as JSON.

Expected result:

```json
{
  "status": "healthy",
  "version": "0.1.0"
}
```

Both values must match.

The workflow therefore verifies actual application behaviour rather than merely confirming that a container process exists.

## CI Application Cleanup

The final step uses:

```text
if: always()
```

and executes:

```bash
docker compose down --volumes --remove-orphans
```

The cleanup therefore executes after both successful validation and failed application testing.

## Initial SEN-027 CI Validation

The first SEN-027 pull-request workflow was:

```text
SentinelOps CI #7
```

Result:

```text
Shell validation: PASS
Secret safety: PASS
Container and application validation: PASS
```

The new container/application job completed:

```text
Docker version verification: PASS
Docker Compose configuration: PASS
container security configuration: PASS
Docker image build: PASS
application startup: PASS
health endpoint wait: PASS
health response validation: PASS
application cleanup: PASS
```

This established the first clean SEN-027 container/application CI baseline.

## SEN-027 Initial Implementation Commit

The container and application CI job was introduced in:

```text
e09c00b ci: add SEN-027 container and application validation
```

## Controlled SEN-027 Application Failure

After the initial clean CI run, a safe controlled application-test failure was introduced.

The real application remained unchanged.

The actual application continued to return:

```json
{"status":"healthy","version":"0.1.0"}
```

The CI expectation was temporarily changed from:

```text
0.1.0
```

to:

```text
9.9.9
```

This created an intentional expectation mismatch without breaking the real Dockerfile, Compose configuration, or application content.

## Controlled SEN-027 Failure Commit

The controlled mismatch was committed as:

```text
b63ea8f test: demonstrate SEN-027 application CI failure
```

## Controlled SEN-027 Failure Result

The controlled failure produced:

```text
SentinelOps CI #8
```

with:

```text
Shell validation: PASS
Secret safety: PASS
Container and application validation: FAIL
```

The failing step was:

```text
Validate application health response
```

Earlier steps still passed:

```text
Docker version verification
Docker Compose configuration validation
container security validation
Docker image build
application startup
health endpoint availability
```

The workflow reported:

```text
ERROR: Unexpected health response: {'status': 'healthy', 'version': '0.1.0'}
```

and:

```text
Process completed with exit code 1.
```

This directly proves that an unexpected application response prevents CI from passing.

## Controlled SEN-027 Failure Cleanup

Although application response validation failed, the Compose cleanup step still executed.

This confirms the intended:

```text
if: always()
```

cleanup behavior.

## Controlled SEN-027 Recovery

The temporary CI expectation was restored from:

```text
9.9.9
```

to:

```text
0.1.0
```

The application itself required no correction because its behaviour was already valid.

## SEN-027 Recovery Commit

Recovery was committed as:

```text
41497c5 test: recover SEN-027 application CI failure
```

## SEN-027 Recovery Result

The recovery produced:

```text
SentinelOps CI #9
```

with:

```text
Shell validation: PASS
Secret safety: PASS
Container and application validation: PASS
```

Workflow status:

```text
Success
```

## SEN-027 CI Run Sequence

The important SEN-027 sequence is:

```text
Run #7
Shell validation: PASS
Secret safety: PASS
Container and application validation: PASS
Reason: initial SEN-027 implementation

Run #8
Shell validation: PASS
Secret safety: PASS
Container and application validation: FAIL
Reason: controlled application version mismatch

Run #9
Shell validation: PASS
Secret safety: PASS
Container and application validation: PASS
Reason: correct application expectation restored
```

This demonstrates:

```text
successful validation
controlled failure enforcement
successful recovery
```

## SEN-027 Commit Sequence

The important SEN-027 implementation/testing commits are:

```text
e09c00b ci: add SEN-027 container and application validation
b63ea8f test: demonstrate SEN-027 application CI failure
41497c5 test: recover SEN-027 application CI failure
```

## CI Authentication Boundary

Creating or modifying:

```text
.github/workflows/
```

requires developer authentication permitted to modify workflow files.

That developer authentication is separate from the runtime permissions granted to the workflow.

The workflow itself remains:

```yaml
permissions:
  contents: read
```

No Personal Access Token value is stored in repository content.

## CI Secret Safety

The Secret safety job scans tracked repository content for obvious prohibited secret-like patterns.

The job is intentionally designed to identify affected files without echoing matching sensitive values.

SEN-027 preserves this job unchanged.

During all three SEN-027 validation runs:

```text
Secret safety: PASS
```

including during the controlled application failure.

## CI Security Considerations

The workflow does not:

```text
deploy SentinelOps to the live VM
connect to the Ubuntu VM
modify production infrastructure
store SSH private keys
store cloud credentials
require deployment secrets
write repository contents
publish Docker images
push images to a registry
expose the CI application publicly
```

Its purpose remains automated validation.

## CI Warning Boundary

GitHub Actions may display external runtime compatibility warnings associated with actions used by the workflow.

These warnings are distinct from SentinelOps validation failures when all job steps complete successfully.

They should continue to be monitored and the relevant action version should be updated when appropriate.

## Current CI Scope

The current workflow now provides automated validation for:

```text
FR-46: Continuous Integration
FR-47: Shell Validation
FR-48: Container Validation
FR-49: Application Testing
FR-50: Secret Protection
```

Current CI jobs:

```text
Shell validation
Secret safety
Container and application validation
```

Current automated checks include:

```text
Bash syntax validation
ShellCheck
secret-pattern validation
Docker availability verification
Docker Compose configuration parsing
loopback-only publication validation
privileged-mode rejection
Docker image build
application startup
health endpoint availability
HTTP 200 validation
health status validation
health version validation
Compose cleanup
```

Future CI improvements may add additional security or quality controls, but FR-46 through FR-50 no longer remain pending.

## Validation Checklist

Before considering a provisioning run successful, verify:

```text
preflight completed successfully
base package installation completed
Docker repository configured
Docker installed and active
target user has expected Docker membership
managed directories exist
application assets deployed
monitoring deployed
backup workflow deployed
Nginx configuration valid
backup systemd units deployed
SSH configuration valid
UFW active
application container healthy
backend bound to 127.0.0.1:8000
at least one valid backup exists
backup checksum valid
backup manifest valid
monitoring completes
required services enabled
required services active
SSH security baseline preserved
no external TCP 8000 exposure
no failed systemd units
```

For repository changes, also verify:

```text
GitHub Actions workflow executes
Shell validation passes
Secret safety passes
Container and application validation passes
Docker Compose configuration parses
Docker image builds successfully
application starts successfully
/health becomes available
/health returns HTTP 200
health status equals healthy
health version equals 0.1.0
required pull-request checks are green
```

## SEN-025 Validated Result

The SEN-025 runtime validation demonstrated:

```text
unchanged second provisioning execution: PASS
APT convergence: PASS
Docker package convergence: PASS
Docker group convergence: PASS
UFW duplicate-rule prevention: PASS
Compose convergence: PASS
managed configuration convergence: PASS
baseline repeated-backup side effect identified: PASS
preflight validation implementation: PASS
controlled missing-asset failure: PASS
controlled failure exit code: 1
controlled failure before deployment: PASS
controlled failure live Nginx state unchanged: PASS
controlled failure backup count unchanged: PASS
controlled failure failed units: 0
controlled failure recovery: PASS
hardened repeated provisioning: PASS
repeated backup count stable at 2: PASS
UFW rules stable at 4: PASS
required services enabled: PASS
required services active: PASS
application backend health: PASS
host Nginx health: PASS
SSH security regression: PASS
external HTTP health: PASS
external TCP 8000 isolation: PASS
failed systemd units: 0
```

## SEN-026 Validated Result

The SEN-026 CI validation demonstrated:

```text
GitHub Actions workflow introduced: PASS
pull-request trigger: PASS
push-to-main trigger configured: PASS
push-to-main trigger verified: PASS
read-only workflow permissions: PASS
Bash syntax automation: PASS
ShellCheck automation: PASS
real ShellCheck finding detected: PASS
SC1091 finding reviewed: PASS
specific ShellCheck handling applied: PASS
clean ShellCheck recovery: PASS
secret-pattern automation: PASS
Secret safety job: PASS
controlled shell failure created: PASS
controlled shell failure detected: PASS
failing script identified: PASS
non-zero CI result: PASS
Secret safety remained independent: PASS
synthetic failure removed: PASS
final Shell validation: PASS
final Secret safety: PASS
```

## SEN-027 Validated Result

The SEN-027 CI validation demonstrated:

```text
existing SEN-026 CI jobs preserved: PASS
Docker tooling verification: PASS
Docker Compose configuration parsing: PASS
loopback-only mapping validation: PASS
privileged-mode rejection: PASS
Docker image build: PASS
application startup: PASS
health endpoint availability: PASS
HTTP 200 validation: PASS
health status validation: PASS
health version validation: PASS
Compose cleanup: PASS
initial container/application CI run: PASS

controlled application mismatch introduced: PASS
controlled mismatch detected: PASS
Container and application validation failed as expected: PASS
failing step identified: PASS
exit code 1: PASS
Shell validation remained green: PASS
Secret safety remained green: PASS
cleanup after failure: PASS

controlled expectation restored: PASS
controlled recovery commit: PASS
final recovery Shell validation: PASS
final recovery Secret safety: PASS
final recovery Container and application validation: PASS
final recovery workflow status: SUCCESS
```

## Requirements Status

Current provisioning and automation requirements status:

```text
FR-41: SATISFIED
FR-42: SATISFIED
FR-43: SATISFIED
FR-44: SATISFIED
FR-45: SATISFIED
FR-46: SATISFIED
FR-47: SATISFIED
FR-48: SATISFIED
FR-49: SATISFIED
FR-50: SATISFIED
```

Related CI success criteria:

```text
SC-36: SATISFIED
SC-37: SATISFIED
SC-38: SATISFIED
SC-39: SATISFIED
SC-40: SATISFIED
```

SEN-024 established the repeatable clean-host provisioning baseline.

SEN-025 established safe repeated provisioning, prerequisite validation, and useful provisioning failures.

SEN-026 established the first automated GitHub Actions repository-validation baseline, including Bash syntax checking, ShellCheck, secret-pattern safety checks, controlled CI failure detection, clean recovery, and successful default-branch CI execution.

SEN-027 extends that baseline with automated Docker Compose configuration validation, container security-state checks, Docker image build validation, application startup testing, direct `/health` behaviour validation, controlled application-test failure, automatic cleanup, and successful recovery.