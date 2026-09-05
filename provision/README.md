# SentinelOps Provisioning

## Purpose

This directory contains the version-controlled assets and provisioning workflow required to reproduce and maintain the SentinelOps single-server environment on a supported Ubuntu Server host.

The provisioning workflow translates infrastructure that was originally configured, inspected, secured, and validated manually into a repeatable and tested automation process.

SEN-024 established the clean-host repeatable provisioning baseline.

SEN-025 hardens that baseline by adding:

```text
idempotent repeated execution
pre-change prerequisite validation
useful provisioning failure handling
conditional initial-backup behavior
explicit existing-state validation
```

The provisioning workflow is designed to support both:

```text
a clean supported Ubuntu host
an already-provisioned valid SentinelOps host
```

Repeated execution should converge the host toward the intended SentinelOps state without creating duplicate firewall rules, duplicate group membership, invalid managed configuration, or unnecessary provisioning-specific backup archives.

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

## Requirements Covered

The provisioning baseline primarily addresses:

```text
FR-41: Manual Understanding Before Automation
FR-42: Repeatable Provisioning
FR-43: Idempotent Automation
FR-44: Automation Validation
FR-45: Useful Automation Failures
```

SEN-024 established FR-41 and FR-42.

SEN-025 adds implementation and runtime evidence for:

```text
FR-43
FR-44
FR-45
```

Continuous-integration requirements remain separate work:

```text
FR-46
FR-47
FR-48
FR-49
```

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

## Repeatability Model

SentinelOps uses practical infrastructure idempotency.

This does not mean every repeated command performs zero work.

Repeated provisioning may still perform operations such as:

```text
apt-get update
Docker repository metadata refresh
managed file installation
Nginx validation and restart
Docker Compose build evaluation
UFW existing-rule evaluation
```

The required property is convergence.

Repeated execution should result in the same intended architecture and security state without accumulating invalid or duplicated configuration.

## Idempotency Boundary

The validated idempotent properties include:

```text
no duplicate UFW rules
no duplicate Docker group membership
managed configuration convergence
stable required service state
healthy application state
loopback-only backend binding
preserved SSH hardening
no unnecessary provisioning-specific backup creation
zero failed systemd units
```

The project does not claim byte-for-byte identity of every system package or transient runtime value between executions.

## Transaction Boundary

The provisioner does not implement a general transactional rollback engine.

Once preflight has succeeded, an unpredictable later failure may occur after earlier system-changing operations have completed.

Examples include:

```text
repository outage after preflight
package-manager failure
unexpected filesystem failure
service failure
network interruption
container build failure
```

The design instead:

```text
moves known prerequisite checks before modification
fails immediately when an operation cannot safely continue
provides useful failure output
validates final runtime state
```

Full transactional configuration management is outside the current SentinelOps MVP scope.

## Package Version Boundary

Exact Docker and Docker Compose package versions are not pinned.

Provisioning installs the current compatible versions available from the configured package repositories.

Repeated provisioning at different dates may therefore upgrade package versions if repository state has changed.

Idempotency means convergence to the intended configuration and supported package state rather than permanent package-version identity.

## User Creation Boundary

The provisioner does not create:

```text
emir
```

The administrator account remains a host prerequisite.

The provisioner validates the account rather than silently creating an unexpected user.

## SSH Key Boundary

The provisioner does not generate or distribute SSH keys.

Trusted public-key authentication must already exist before SSH password authentication is disabled.

Private authentication material must remain outside the repository.

## Clean-Host Compatibility

SEN-024 provided the clean-host provisioning evidence.

SEN-025 preserves that model while adding validation that accepts both:

```text
clean expected state
already-provisioned expected state
```

For example:

```text
unused TCP 80 is valid on a clean host
Nginx-owned TCP 80 is valid on a provisioned host

unused TCP 8000 is valid on a clean host
SentinelOps-owned 127.0.0.1:8000 is valid on a provisioned host
```

Unexpected conflicting state is rejected.

## Manual Understanding

Every major infrastructure component represented by this provisioning workflow was first configured, inspected, secured, and validated manually during earlier SentinelOps issues.

The automation therefore codifies an already-understood architecture.

It does not replace that understanding with an opaque configuration-management platform.

This preserves the project principle:

```text
manual understanding before automation
```

## Configuration Management Boundary

SentinelOps currently uses Bash-based provisioning.

SEN-025 does not introduce:

```text
Ansible
Terraform
remote orchestration
multi-host inventory
configuration-management agents
```

Those technologies are not required for the current single-host MVP requirements.

The existing Bash workflow is intentionally kept understandable and evidence-driven.

## Continuous Integration Boundary

This provisioning workflow does not itself implement GitHub Actions.

The remaining CI requirements are:

```text
FR-46: Continuous Integration
FR-47: Shell Validation
FR-48: Docker Project Validation
FR-49: Application Behaviour Validation
```

These are separate follow-up work after the provisioning automation baseline.

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

## Requirements Status

Current provisioning requirements status:

```text
FR-41: SATISFIED
FR-42: SATISFIED
FR-43: SATISFIED
FR-44: SATISFIED
FR-45: SATISFIED
```

SEN-024 established the repeatable clean-host provisioning baseline.

SEN-025 establishes that the SentinelOps provisioning workflow can also be executed safely against the validated already-provisioned target state, performs important prerequisite checks before modification where practical, and returns useful non-zero failure information when provisioning cannot continue safely.