# SEN-024 Repeatable Provisioning Baseline

## Purpose

SEN-024 establishes the first repeatable provisioning baseline for SentinelOps.

The objective is to translate the infrastructure that was previously configured, secured, inspected, and validated manually into a version-controlled provisioning workflow capable of reproducing the SentinelOps environment from a clean supported Ubuntu Server installation.

This issue focuses on repeatability and reproducibility.

Full idempotency, advanced prerequisite enforcement, rollback behavior, and CI validation remain separate later concerns.

## Requirements Mapping

SEN-024 primarily addresses:

```text
FR-41: Manual Understanding Before Automation
FR-42: Repeatable Provisioning
```

The implementation also prepares the project for later work concerning:

```text
FR-43: Idempotent Automation
FR-44: Automation Validation
FR-45: Useful Automation Failures
```

SEN-024 does not claim that FR-43 through FR-45 are fully complete.

## Manual-First Principle

The SentinelOps environment was not designed by starting with automation.

Each major component was previously implemented and verified manually during earlier issues, including:

```text
Linux baseline
SSH hardening
UFW
host Nginx
Docker
Docker Compose application
application health endpoint
monitoring
backup creation
backup automation
backup retention
backup freshness monitoring
backup integrity verification
backup manifest verification
operational logging
controlled failure simulations
```

SEN-024 therefore codifies an already-understood environment instead of introducing an opaque automation layer.

## Original Known-Good Architecture

Before SEN-024, the live SentinelOps VM implemented:

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

The design intentionally keeps the application backend private.

The host publishes HTTP through Nginx on port 80.

The containerized application is bound only to:

```text
127.0.0.1:8000
```

TCP port 8000 is not externally exposed.

## Pre-Implementation Repository Audit

Before SEN-024, the repository contained project documentation but did not contain the runtime assets necessary to reconstruct the host directly.

The repository already contained documentation under:

```text
docs/
```

but did not contain version-controlled copies of:

```text
Dockerfile
compose.yaml
index.html
health-check.sh
backup-sentinelops.sh
Nginx site configuration
backup systemd service
backup systemd timer
SSH hardening drop-in
provisioning script
```

No existing non-Markdown provisioning implementation was found.

This created a reproducibility gap.

The running VM contained the authoritative deployed versions of the infrastructure assets, while the Git repository primarily described them.

## Live Host Audit

The existing known-good SentinelOps VM was inspected before provisioning assets were created.

The audited operating system baseline was:

```text
Ubuntu Server 24.04.4 LTS
architecture: aarch64
```

The live service baseline included:

```text
nginx: enabled and active
docker: enabled and active
ssh.socket: enabled and active
sentinelops-backup.timer: enabled and active
```

The live application architecture included:

```text
host Nginx: port 80
SSH: port 22
Docker backend: 127.0.0.1:8000
```

The health endpoint returned:

```json
{"status":"healthy","version":"0.1.0"}
```

through both:

```text
http://127.0.0.1:8000/health
http://127.0.0.1/health
```

## Live Security Baseline

The effective SSH security configuration was:

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
```

The configuration was implemented through:

```text
/etc/ssh/sshd_config.d/00-sentinelops.conf
```

The UFW baseline was:

```text
Status: active
Default incoming: deny
Default outgoing: allow
Default routed: deny
Logging: low
```

Allowed inbound services were:

```text
22/tcp
80/tcp
```

No external UFW allowance existed for TCP port 8000.

## Live Docker Repository Configuration

The existing VM used Docker's official Ubuntu package repository.

The repository definition was stored at:

```text
/etc/apt/sources.list.d/docker.sources
```

with Docker's signing key at:

```text
/etc/apt/keyrings/docker.asc
```

The deployed architecture was ARM64.

SEN-024 intentionally derives the target architecture dynamically rather than hard-coding ARM64.

## Runtime Assets Captured

The following known-good application assets were copied into version control:

```text
provision/application/Dockerfile
provision/application/compose.yaml
provision/application/index.html
```

The monitoring implementation was captured as:

```text
provision/monitoring/health-check.sh
```

The backup implementation was captured as:

```text
provision/backup/backup-sentinelops.sh
```

The host Nginx configuration was captured as:

```text
provision/nginx/sentinelops
```

The systemd backup units were captured as:

```text
provision/systemd/sentinelops-backup.service
provision/systemd/sentinelops-backup.timer
```

The SSH hardening configuration was represented as:

```text
provision/ssh/00-sentinelops.conf
```

The provisioning logic was implemented as:

```text
provision/scripts/provision.sh
```

The provisioning runbook was implemented as:

```text
provision/README.md
```

## Final Provisioning Repository Structure

The resulting structure is:

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

## Provisioning Script

The main provisioning script is:

```text
provision/scripts/provision.sh
```

It uses:

```bash
set -euo pipefail
```

to terminate when unexpected command failures, unset variables, or failed pipeline commands occur.

The script is intended to be executed as root through:

```bash
sudo ./provision/scripts/provision.sh
```

## Root Requirement

The script validates that it is being executed with root privileges.

This is necessary because provisioning modifies:

```text
APT packages
Docker repository configuration
systemd units
Nginx configuration
SSH configuration
UFW
system directories
file ownership
service state
```

Execution without root privileges terminates with an error.

## Supported Operating System Validation

The script verifies:

```text
ID=ubuntu
VERSION_ID=24.04
```

through:

```text
/etc/os-release
```

An unsupported distribution or unsupported Ubuntu release causes provisioning to stop.

The architecture is detected through:

```bash
dpkg --print-architecture
```

rather than being hard-coded.

## Target User Validation

The current SentinelOps provisioning baseline expects:

```text
user: emir
group: emir
home: /home/emir
```

The provisioner validates that the required user and group already exist.

User creation is not currently automated.

This is an intentional SEN-024 boundary.

## Source Asset Validation

Before installation begins, the provisioner verifies the presence of all required source assets.

Required assets include:

```text
application/Dockerfile
application/compose.yaml
application/index.html
monitoring/health-check.sh
backup/backup-sentinelops.sh
nginx/sentinelops
systemd/sentinelops-backup.service
systemd/sentinelops-backup.timer
ssh/00-sentinelops.conf
```

A missing required file causes the script to terminate rather than silently creating an incomplete deployment.

## Base Package Installation

The provisioning workflow installs or verifies:

```text
ca-certificates
curl
gnupg
nginx
openssh-server
sudo
ufw
```

APT package metadata is refreshed before installation.

## Docker Repository Configuration

The provisioning script creates:

```text
/etc/apt/keyrings
```

and downloads Docker's Ubuntu signing key to:

```text
/etc/apt/keyrings/docker.asc
```

It then creates:

```text
/etc/apt/sources.list.d/docker.sources
```

The Ubuntu codename is derived from:

```text
/etc/os-release
```

The architecture is derived through:

```bash
dpkg --print-architecture
```

This avoids coupling the repository definition to the original ARM64 VM.

## Docker Installation

The Docker installation includes:

```text
docker-ce
docker-ce-cli
containerd.io
docker-buildx-plugin
docker-compose-plugin
```

Docker is enabled and started through systemd.

The `emir` account is added to the:

```text
docker
```

group.

A new login session is required before that supplementary group becomes effective for the user.

## Directory Provisioning

The workflow creates the application directory:

```text
/home/emir/sentinelops-app
```

the monitoring directory:

```text
/home/emir/sentinelops-monitoring
```

the backup root:

```text
/home/emir/backups
```

the SentinelOps backup directory:

```text
/home/emir/backups/sentinelops
```

and the structured monitoring log directory:

```text
/var/log/sentinelops
```

## Monitoring Log Permissions

The monitoring log directory is created with:

```text
owner: root
group: emir
mode: 0750
```

The monitoring log is:

```text
/var/log/sentinelops/health-check.log
```

with:

```text
owner: emir
group: emir
mode: 0640
```

## Application Deployment

Version-controlled application assets are installed into:

```text
/home/emir/sentinelops-app
```

The deployed files are:

```text
Dockerfile
compose.yaml
index.html
```

The application continues to use the established SentinelOps semantic version:

```text
0.1.0
```

## Docker Compose Network Binding

The Compose configuration preserves:

```text
127.0.0.1:8000 -> container port 80
```

This is a critical security design property.

The backend is reachable locally by host Nginx but is not directly exposed on the VM's external interface.

## Monitoring Deployment

The version-controlled monitoring script is deployed to:

```text
/home/emir/sentinelops-monitoring/health-check.sh
```

The existing structured monitoring behavior is preserved.

The monitoring workflow includes system, service, application, backup, listener, and firewall visibility.

## Backup Deployment

The version-controlled backup script is deployed to:

```text
/home/emir/backups/sentinelops/backup-sentinelops.sh
```

The backup workflow preserves:

```text
UTC timestamped archive naming
SHA-256 checksum generation
SHA-256 verification
manifest generation
manifest comparison
seven-day retention
artifact ownership
restrictive artifact permissions
temporary staging cleanup
```

## Nginx Deployment

The SentinelOps host Nginx site is deployed to:

```text
/etc/nginx/sites-available/sentinelops
```

The default Nginx site is removed from the enabled configuration.

The SentinelOps site is enabled through:

```text
/etc/nginx/sites-enabled/sentinelops
```

The configuration is validated using:

```bash
nginx -t
```

before the Nginx service is considered ready.

## systemd Deployment

The backup service is deployed to:

```text
/etc/systemd/system/sentinelops-backup.service
```

The backup timer is deployed to:

```text
/etc/systemd/system/sentinelops-backup.timer
```

After installation:

```bash
systemctl daemon-reload
```

is executed.

The backup timer is then enabled and started.

## Backup Schedule

The timer preserves the existing daily backup model and:

```text
Persistent=true
```

This means a missed scheduled execution may be triggered after the machine becomes available again.

## SSH Hardening Deployment

The SSH hardening configuration is deployed to:

```text
/etc/ssh/sshd_config.d/00-sentinelops.conf
```

with:

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
```

Before the running service is reloaded, the configuration is syntax-tested with:

```bash
sshd -t
```

If the SSH service is active, it is reloaded only after syntax validation succeeds.

## SSH Safety Prerequisite

Public-key SSH authentication must already be tested before the provisioning workflow disables password-based SSH authentication.

The clean-host validation therefore installed the Mac public key before executing the provisioner.

The repository does not contain a private SSH key.

## UFW Deployment

The provisioning workflow configures:

```text
default incoming: deny
default outgoing: allow
default routed: deny
logging: low
```

It permits:

```text
22/tcp
Nginx HTTP
```

and enables UFW.

The application backend port 8000 is deliberately not allowed through UFW.

## Application Build and Start

After infrastructure assets are deployed, the script enters:

```text
/home/emir/sentinelops-app
```

and runs:

```bash
docker compose up -d --build
```

This builds and starts the SentinelOps application.

## Initial Backup

The provisioning workflow immediately runs:

```text
sentinelops-backup.service
```

after the application is deployed.

This establishes an initial valid backup artifact set for the provisioned host.

## Provisioning Validation

The script performs its own post-deployment validation.

It checks:

```text
service enablement
service active state
effective SSH configuration
Docker Compose application state
direct backend health
host Nginx health
TCP listeners
UFW
loopback-only backend binding
backup checksum
backup manifest
monitoring
failed systemd units
```

## Static Script Validation

Before runtime testing, the following scripts were syntax-checked with Bash:

```text
provision/scripts/provision.sh
provision/monitoring/health-check.sh
provision/backup/backup-sentinelops.sh
```

Each completed with exit status:

```text
0
```

The provisioning script was not executed against the original known-good VM during initial testing.

## Secret Scan

The provisioning directory was searched for common private key and credential patterns.

The scan produced no findings.

The repository contains no private SSH key, password, token, or other required secret for provisioning.

## Clean-Host Validation Strategy

A separate disposable VM was created specifically for SEN-024.

This avoided using the existing known-good SentinelOps VM as the first provisioning target.

Using a separate VM provided direct evidence that the version-controlled provisioning workflow could transform a clean supported Ubuntu environment into the expected SentinelOps architecture.

## Disposable Test VM

The test VM was created in UTM with:

```text
Name: SentinelOps-Test
Engine: QEMU
Architecture: ARM64 / aarch64
CPU: 2 cores
Memory: 4 GB
Virtual disk: 30 GB
Networking: UTM shared network
```

The installer image was:

```text
ubuntu-24.04.4-live-server-arm64.iso
```

## Clean Operating System Baseline

After installation, the test host reported:

```text
hostname: sentinelops-test
Ubuntu 24.04.4 LTS
architecture: aarch64
```

The test VM received:

```text
192.168.64.3/24
```

through DHCP.

The address is environment-specific and is not hard-coded into provisioning.

## Clean User Baseline

The test host contained:

```text
uid=1000(emir)
gid=1000(emir)
```

The `emir` user was a member of:

```text
emir
adm
cdrom
sudo
dip
plugdev
lxd
```

This satisfied the current user prerequisite.

## Clean SSH Preparation

OpenSSH Server was installed on the clean host before the provisioning run.

The service was enabled and started.

The Mac public key:

```text
~/.ssh/id_rsa.pub
```

was copied to the test host using:

```bash
ssh-copy-id
```

Key-based login from the Mac was verified before password authentication was disabled.

## Clean Pre-Provisioning Runtime Baseline

Before provisioning:

```text
nginx: inactive / not installed as application service
docker: inactive / not installed
ssh: active
UFW: inactive
```

The only relevant externally listening service was SSH on:

```text
22/tcp
```

No listener existed on:

```text
80/tcp
8000/tcp
```

This established that the SentinelOps runtime did not already exist on the clean VM.

## Provisioning Execution

The actual clean-host provisioning command was:

```bash
sudo ./provision/scripts/provision.sh
```

The script successfully completed all major phases:

```text
operating system validation
target user validation
source asset validation
base package installation
Docker repository configuration
Docker installation
directory creation
application deployment
monitoring deployment
backup deployment
Nginx deployment
systemd deployment
SSH hardening
UFW configuration
Docker application build
initial backup
service validation
SSH validation
application validation
network validation
backup validation
monitoring execution
failed-unit validation
```

The final script message was:

```text
[SEN-024] SentinelOps provisioning completed successfully
```

## Clean-Host Package Results

During clean-host provisioning, Nginx was installed from the Ubuntu repository.

The resulting host Nginx version was:

```text
nginx/1.24.0 (Ubuntu)
```

Docker was installed from Docker's official Ubuntu repository.

The resulting versions were:

```text
Docker 29.8.0
Docker Compose v5.5.1
```

The test host also reported:

```text
UFW 0.36.2
OpenSSH 9.6p1
```

## Version Difference Observation

The original known-good VM had previously reported:

```text
Docker 29.7.2
Docker Compose v5.5.0
```

while the clean provisioning run installed:

```text
Docker 29.8.0
Docker Compose v5.5.1
```

This is expected because SEN-024 installs current packages from the configured repositories rather than pinning exact Docker package versions.

The provisioning baseline therefore reproduces the required architecture and configuration, not an exact binary snapshot of every package.

Exact package pinning is not part of SEN-024.

## Service Enablement Validation

After provisioning, the following were enabled:

```text
nginx
docker
ssh.socket
sentinelops-backup.timer
```

All four checks returned:

```text
enabled
```

## Service Active-State Validation

After provisioning, the same components reported:

```text
active
```

for:

```text
nginx
docker
ssh.socket
sentinelops-backup.timer
```

## SSH Security Validation

The effective SSH configuration after provisioning was:

```text
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
kbdinteractiveauthentication no
```

This reproduced the established SentinelOps SSH baseline.

## Application Container Validation

The provisioner successfully built and started:

```text
sentinelops-app
```

The resulting Compose mapping was:

```text
127.0.0.1:8000->80/tcp
```

After a fresh login session, the `emir` user was confirmed to belong to:

```text
docker
```

and:

```bash
docker compose ps
```

worked without `sudo`.

## Application Health Validation

The direct backend health endpoint returned:

```text
HTTP 200
```

with:

```json
{"status":"healthy","version":"0.1.0"}
```

through:

```text
http://127.0.0.1:8000/health
```

## Host Nginx Health Validation

The host reverse-proxy path returned:

```text
HTTP 200
```

with the same application health body through:

```text
http://127.0.0.1/health
```

## Listener Validation

After provisioning, the relevant listeners included:

```text
0.0.0.0:22
0.0.0.0:80
127.0.0.1:8000
```

IPv6 listeners also existed for SSH and Nginx.

No external:

```text
0.0.0.0:8000
```

or:

```text
[::]:8000
```

listener existed.

The provisioner explicitly reported:

```text
Backend port 8000 remains loopback-only.
```

## UFW Validation

After provisioning, UFW reported:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
```

Allowed inbound rules were:

```text
22/tcp
80/tcp (Nginx HTTP)
```

with corresponding IPv6 rules.

No inbound port 8000 rule existed.

## External Host Validation

After provisioning, the test VM was validated from the Mac.

A request to:

```text
http://192.168.64.3/health
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

This confirmed external traffic reached host Nginx successfully.

## External Backend Isolation Validation

From the Mac:

```bash
nc -vz -w 3 192.168.64.3 8000
```

failed with:

```text
Operation timed out
```

This confirmed that the private backend was not externally reachable.

The exact network failure mode may vary depending on firewall behavior.

The required security property is that an external client cannot establish a TCP connection to port 8000.

## Post-Hardening SSH Validation

After provisioning disabled password authentication, a fresh SSH connection from the Mac to:

```text
emir@192.168.64.3
```

succeeded using the configured public-key authentication.

This confirmed that the hardened SSH state remained operational.

## Docker Group Session Observation

Immediately after the provisioning script added `emir` to the Docker group, an already-existing SSH session could not access:

```text
/var/run/docker.sock
```

without elevated privileges.

This was expected because supplementary group membership is established when a login session begins.

After exiting and reconnecting through SSH, the `groups` command included:

```text
docker
```

and:

```bash
docker compose ps
```

worked successfully without `sudo`.

This is a normal Linux session behavior and not a provisioning failure.

## Backup Creation Validation

The initial provisioning run produced:

```text
sentinelops-backup-20260904T194723Z.tar.gz
sentinelops-backup-20260904T194723Z.tar.gz.sha256
sentinelops-backup-20260904T194723Z.tar.gz.manifest
```

The artifacts were owned by:

```text
emir:emir
```

and used restrictive:

```text
0600
```

permissions.

## Backup Integrity Validation

The generated SHA-256 checksum passed:

```text
sentinelops-backup-20260904T194723Z.tar.gz: OK
```

## Backup Manifest Validation

The archive manifest matched the archive contents.

The provisioner reported:

```text
Backup integrity and manifest validation passed.
```

## Backup Freshness Validation

The monitoring workflow identified the newly generated backup as:

```text
0 hour(s)
```

old.

Backup freshness was:

```text
OK
```

## Monitoring Validation

The SentinelOps health check completed successfully after provisioning.

It reported:

```text
Docker: active
Nginx: active
SSH: active
```

Application health returned:

```text
HTTP 200
```

Host Nginx health returned:

```text
HTTP 200
```

The monitoring output also confirmed:

```text
127.0.0.1:8000
0.0.0.0:80
0.0.0.0:22
```

and an active UFW policy.

## Resource Monitoring Validation

The monitoring workflow successfully collected:

```text
uptime
load averages
memory usage
swap usage
filesystem usage
container CPU
container memory
container network I/O
container block I/O
container process count
```

The root filesystem threshold check reported:

```text
OK
```

during the clean-host run.

## Failed systemd Unit Validation

During provisioning:

```bash
systemctl --failed
```

reported:

```text
0 loaded units listed.
```

The final post-provisioning check also reported:

```text
0 loaded units listed.
```

No failed systemd units remained after provisioning.

## Final Clean-Host Architecture

The disposable host finished with:

```text
Mac / client
      |
      | TCP 22
      | TCP 80
      v
+-----------------------------+
| SentinelOps-Test            |
| Ubuntu Server 24.04.4 LTS   |
|                             |
| UFW                         |
| deny incoming by default    |
| allow 22                    |
| allow 80                    |
|                             |
| SSH                         |
| key authentication          |
| no password authentication  |
| no root login               |
|                             |
| host Nginx :80              |
|        |                    |
|        v                    |
| 127.0.0.1:8000              |
|        |                    |
|        v                    |
| Docker Compose application  |
| container port 80           |
|                             |
| monitoring                  |
| backup service              |
| backup timer                |
+-----------------------------+
```

## Comparison With Original Host

The clean-host result reproduced the important architecture of the original SentinelOps VM:

```text
Ubuntu 24.04
host Nginx
Docker Engine
Docker Compose
loopback-only backend
HTTP reverse proxy
SSH hardening
UFW deny-by-default policy
monitoring
backup script
backup timer
checksum verification
manifest verification
application version 0.1.0
```

The clean-host test therefore demonstrated that the environment was no longer dependent on undocumented manual state existing only on the original VM.

## FR-41 Assessment

FR-41 requires important infrastructure configuration to be manually understood and verified before automation.

SEN-024 satisfies this principle because all major components were built, inspected, validated, and failure-tested manually before they were translated into provisioning assets.

The automation reflects existing documented architecture decisions.

It does not replace understanding with an unrelated configuration-management abstraction.

## FR-42 Assessment

FR-42 requires a documented process for configuring a clean supported Ubuntu Server environment.

SEN-024 provides:

```text
version-controlled runtime configuration
version-controlled provisioning logic
documented prerequisites
documented provisioning order
documented security expectations
documented validation
clean-host execution evidence
```

A separate clean Ubuntu Server 24.04.4 VM was successfully transformed into the intended SentinelOps environment.

This provides direct evidence for repeatable provisioning.

## Idempotency Boundary

SEN-024 does not claim full idempotency.

Some operations are naturally repeatable, including:

```text
package installation
directory creation
install-based file deployment
systemd enablement
UFW rule addition
Docker Compose deployment
```

However, repeated full executions have not yet been formally tested and assessed for:

```text
duplicate or changed state
repeated backup generation
service restart behavior
repository rewrite behavior
firewall rule behavior
error handling
side effects
```

Formal idempotency belongs to later work.

## Prerequisite Validation Boundary

SEN-024 includes basic prerequisite validation for:

```text
root execution
Ubuntu 24.04
target user
target group
required source files
```

More advanced validation remains future work.

Potential later checks include:

```text
internet connectivity
APT repository reachability
sufficient disk space
required public-key SSH state
required sudo privileges
port conflicts
Docker repository trust state
existing incompatible service configuration
```

## Failure Handling Boundary

The provisioner uses:

```bash
set -euo pipefail
```

and explicit validation failures.

However, SEN-024 does not yet implement advanced transactional rollback or detailed recovery handling for every possible partial-provisioning failure.

This remains separate later work.

## Package Version Boundary

SEN-024 does not pin exact Docker or Docker Compose versions.

It uses the configured repositories and installs current packages available at execution time.

This means repeated provisioning at different dates may install newer compatible versions.

The required target is architectural and configuration equivalence rather than byte-for-byte package reproduction.

## User Creation Boundary

SEN-024 does not create the `emir` account.

The supported clean-host procedure requires that the administrator account already exist.

This boundary is documented explicitly.

## SSH Key Boundary

SEN-024 does not distribute a public or private SSH key automatically.

A trusted key must be installed before password authentication is disabled.

This prevents a repository-specific provisioning script from embedding private authentication material.

## Clean Test VM Disposition

The `SentinelOps-Test` VM exists only as a disposable validation environment.

The original:

```text
SentinelOps-Ubuntu
```

VM remained separate from the clean-host provisioning test.

The known-good production-style lab environment was therefore not used as the first target of the new automation.

## Security Regression Result

The clean provisioning run preserved the required SentinelOps security properties:

```text
SSH key authentication enabled
SSH password authentication disabled
root SSH login disabled
keyboard-interactive SSH disabled
UFW active
default incoming deny
TCP 22 allowed
TCP 80 allowed
TCP 8000 not externally allowed
backend bound to 127.0.0.1:8000
no failed systemd units
```

## Operational Regression Result

The provisioned system retained:

```text
host Nginx reverse proxy
Docker Compose application
application health endpoint
structured monitoring
backup freshness monitoring
SHA-256 verification
backup manifest verification
daily persistent backup timer
```

## SEN-024 Result

SEN-024 successfully moved SentinelOps from a documentation-heavy manually configured environment toward a reproducible infrastructure repository.

Before SEN-024, the live VM contained critical runtime configuration that was not directly represented as deployable repository assets.

After SEN-024, those components are captured under:

```text
provision/
```

and a clean Ubuntu Server 24.04.4 VM was successfully provisioned from those assets.

The clean host reached the expected:

```text
application state
service state
security state
network state
monitoring state
backup state
```

without relying on the original SentinelOps VM's existing configuration.

## Final Status

SEN-024 repeatable provisioning baseline:

```text
Repository audit: PASS
Live-host audit: PASS
Runtime assets version controlled: PASS
Provisioning script syntax: PASS
Operational script syntax: PASS
Secret scan: PASS
Clean Ubuntu host created: PASS
Clean pre-provisioning baseline captured: PASS
Provisioning execution: PASS
Nginx deployment: PASS
Docker deployment: PASS
Application deployment: PASS
Monitoring deployment: PASS
Backup deployment: PASS
systemd deployment: PASS
SSH hardening: PASS
UFW deployment: PASS
Application HTTP health: PASS
External HTTP access: PASS
External port 8000 isolation: PASS
SSH key access after hardening: PASS
Docker non-root access after fresh login: PASS
Backup checksum verification: PASS
Backup manifest verification: PASS
Monitoring execution: PASS
Failed systemd units: 0
FR-41: SATISFIED
FR-42: SATISFIED
```

SEN-024 establishes the repeatable provisioning baseline required to reconstruct SentinelOps from a clean supported Ubuntu Server environment while preserving the project's manually understood architecture and security model.