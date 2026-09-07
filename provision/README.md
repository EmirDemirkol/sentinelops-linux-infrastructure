# SentinelOps Provisioning

## Purpose

This directory contains the version-controlled assets and provisioning workflow used to reproduce and maintain the SentinelOps single-server environment on Ubuntu Server.

The workflow translates infrastructure originally configured and validated manually into repeatable automation.

| Issue | Contribution |
|---|---|
| SEN-024 | Clean-host repeatable provisioning |
| SEN-025 | Preflight validation, repeated execution and useful failure handling |
| SEN-026 | GitHub Actions shell validation and secret-safety checks |
| SEN-027 | Container configuration, image build and application CI validation |
| SEN-028 | Structured memory and system-load collection |
| SEN-029 | Scheduled monitoring and measured failure detection |

The provisioner supports:

- a clean supported Ubuntu host with the required administrator account and SSH access;
- an already-provisioned SentinelOps host.

Repeated execution should converge the host toward the intended state without duplicate firewall rules, duplicate group membership or unnecessary provisioning-specific backup archives.

SEN-029 runtime validation has been completed on the disposable test VM. Its pull-request CI, merge and default-branch CI remain separate completion steps.

## Supported Environment

The supported baseline includes:

- Ubuntu Server 24.04 LTS;
- systemd;
- OpenSSH;
- UFW;
- host Nginx;
- Docker Engine;
- Docker Compose.

Preflight requires:

```text
operating system: Ubuntu
release: 24.04
architecture: amd64 or arm64
```

Recorded runtime validation used Ubuntu Server 24.04.4 LTS on arm64. Acceptance of amd64 by preflight does not itself establish runtime validation on that architecture.

## Target Architecture

Host Nginx receives HTTP traffic on TCP 80 and proxies it to the Compose application published on the loopback interface.

| Component | Address or port | Exposure |
|---|---|---|
| SSH | TCP 22 | Allowed through UFW |
| Host Nginx | TCP 80 | Allowed through UFW |
| Application backend | `127.0.0.1:8000` | Host loopback only |
| Application container | TCP 80 inside the container | Published through the loopback mapping |

Expected Compose publication:

```text
127.0.0.1:8000:80
```

TCP 8000 must not be exposed externally.

The application provides:

```text
/health
```

Expected response:

```json
{"status":"healthy","version":"0.1.0"}
```

## Repository Assets

| Path | Purpose |
|---|---|
| `provision/scripts/provision.sh` | Main provisioner |
| `provision/application/Dockerfile` | Application image |
| `provision/application/compose.yaml` | Compose configuration |
| `provision/application/index.html` | Application content |
| `provision/monitoring/health-check.sh` | Host and application monitoring |
| `provision/backup/backup-sentinelops.sh` | Backup workflow |
| `provision/nginx/sentinelops` | Host reverse-proxy configuration |
| `provision/ssh/00-sentinelops.conf` | SSH hardening |
| `provision/systemd/sentinelops-backup.service` | Backup service |
| `provision/systemd/sentinelops-backup.timer` | Backup schedule |
| `provision/systemd/sentinelops-monitoring.service` | Monitoring service |
| `provision/systemd/sentinelops-monitoring.timer` | Monitoring schedule |

Repository-level CI is configured in:

```text
.github/workflows/ci.yml
```

## Requirements Covered

The existing provisioning and CI baselines provide implementation and validation evidence for:

| Requirement | Description | Baseline |
|---|---|---|
| FR-41 | Manual Understanding Before Automation | SEN-024 |
| FR-42 | Repeatable Provisioning | SEN-024 |
| FR-43 | Idempotent Automation | SEN-025 |
| FR-44 | Automation Validation | SEN-025 |
| FR-45 | Useful Automation Failures | SEN-025 |
| FR-46 | Continuous Integration | SEN-026 |
| FR-47 | Shell Validation | SEN-026 |
| FR-48 | Container Validation | SEN-027 |
| FR-49 | Application Testing | SEN-027 |
| FR-50 | Secret Protection | SEN-026 |

SEN-028 completed the structured resource-collection gap associated with SC-14.

SEN-029 adds automatic monitoring and observed detection-time evidence for SC-15. The selected failure must be detected within two monitoring intervals.

These mappings do not imply that every remaining MVP requirement is complete.

## Administrator Prerequisites

The provisioner does not create the administrator account.

The host must already contain:

```text
user: emir
group: emir
home: /home/emir
```

The account must have administrative sudo access.

Preflight verifies:

- the user exists;
- the group exists;
- the expected home directory exists;
- the account database reports `/home/emir` as the user's home.

Provisioning stops if these assumptions do not match.

## SSH Access Prerequisite

Public-key SSH access must already work before provisioning applies SSH hardening.

Expected paths:

```text
/home/emir/.ssh
/home/emir/.ssh/authorized_keys
```

The authorized-key file must exist, be non-empty and contain a recognised public-key entry.

Recognised prefixes include:

```text
ssh-ed25519
ssh-rsa
ecdsa-sha2-*
```

Verify key-based SSH access independently before running provisioning remotely. Console access should remain available during initial configuration.

Private SSH keys are not stored in the repository.

## Running the Provisioner

Run provisioning on the supported Ubuntu host, from the repository root:

```bash
sudo ./provision/scripts/provision.sh
```

An explicit Bash invocation is also supported:

```bash
sudo bash provision/scripts/provision.sh
```

Before deployment, check local shell syntax:

```bash
bash -n provision/scripts/provision.sh
bash -n provision/monitoring/health-check.sh
bash -n provision/backup/backup-sentinelops.sh
git diff --check
```

The provisioner uses:

```bash
set -Eeuo pipefail
```

It also provides explicit validation errors and an unexpected-error trap.

## Provisioning Preflight

Preflight runs before package installation, managed configuration deployment, firewall changes or provisioning-specific backup creation.

It validates:

1. Root execution.
2. Ubuntu release and architecture.
3. Target account and home directory.
4. Required source assets.
5. Operational shell-script syntax.
6. SSH public-key readiness.
7. Available root-filesystem capacity.
8. Repository hostname resolution.
9. Managed Nginx path assumptions.
10. Protected scheduled-monitoring paths.
11. Existing TCP port usage.

Successful completion is reported as:

```text
[SEN-025] Provisioning preflight completed successfully
```

The provisioner retains the existing `[SEN-025]` logging prefix.

### Source Assets

Every required deployment asset must exist and be readable.

This includes both backup units and both monitoring units.

A missing source asset stops provisioning before the system-changing phase.

### Shell Syntax

Preflight runs Bash syntax validation against:

```text
provision/monitoring/health-check.sh
provision/backup/backup-sentinelops.sh
```

GitHub Actions separately validates discovered provisioning shell scripts with Bash syntax checks and ShellCheck.

### Filesystem Capacity

The root filesystem must have at least:

```text
1048576 KiB
```

of available capacity, approximately 1 GiB.

This rejects obviously insufficient space before package installation and container build activity.

### Repository Resolution

Docker repository resolution is required for:

```text
download.docker.com
```

Ubuntu mirror checks inspect:

```text
ports.ubuntu.com
archive.ubuntu.com
security.ubuntu.com
```

Ubuntu mirror selection can vary by architecture and environment. Actual package and download operations remain authoritative during installation.

### Managed Nginx Path

The following path may be absent or a symbolic link:

```text
/etc/nginx/sites-enabled/sentinelops
```

An unexpected non-symbolic-link object causes preflight to stop.

### Protected Monitoring Paths

Preflight checks:

```text
/usr
/usr/local
/usr/local/lib
/usr/local/lib/sentinelops
```

Existing directories must:

- be directories;
- be root-owned;
- not be symbolic links;
- not be group- or world-writable.

The scheduled script path must not be a symbolic link or an unexpected non-regular file.

### TCP Port Conflicts

TCP 80 may be unused or already occupied by Nginx.

An incompatible listener causes provisioning to stop.

An existing TCP 8000 listener must match the expected SentinelOps application state and use:

```text
127.0.0.1:8000
```

Externally bound backend listeners are rejected, including:

```text
0.0.0.0:8000
[::]:8000
*:8000
```

The listener inspection uses `ss -Hltnp`. Suppressing the heading allows an empty result to be identified correctly.

## Provisioning Order

After successful preflight, provisioning:

1. Pauses any existing scheduled monitoring.
2. Installs base packages.
3. Configures Docker's package repository.
4. Installs Docker Engine and Compose.
5. Checks Docker group membership.
6. Creates application, monitoring, backup and log directories.
7. Deploys application assets.
8. Deploys manual and protected monitoring script copies.
9. Deploys the backup script.
10. Deploys and validates host Nginx configuration.
11. Deploys backup and monitoring units.
12. Validates monitoring units and reloads systemd.
13. Enables the backup timer.
14. Deploys and validates SSH hardening.
15. Configures UFW.
16. Builds and starts the Compose application.
17. Ensures an initial backup exists.
18. Validates services, SSH, application health and network state.
19. Validates the newest backup checksum and manifest.
20. Executes the monitoring service.
21. Checks for failed systemd units.
22. Enables the monitoring timer.
23. Checks monitoring timer state and log permissions.

The monitoring timer is activated after the operational validation sequence.

## Application Deployment

Application assets are deployed to:

```text
/home/emir/sentinelops-app/
```

Expected files:

```text
Dockerfile
compose.yaml
index.html
```

Provisioning runs:

```bash
docker compose up -d --build
```

The expected final application state includes:

```text
sentinelops-app
Up
127.0.0.1:8000->80/tcp
```

The provisioner verifies HTTP 200 from both:

```text
http://127.0.0.1:8000/health
http://127.0.0.1/health
```

CI additionally parses the direct application's health response and checks its status and version values.

## Monitoring

The monitoring source is:

```text
provision/monitoring/health-check.sh
```

Provisioning installs two copies:

| Purpose | Path | Owner | Mode |
|---|---|---|---|
| Manual monitoring | `/home/emir/sentinelops-monitoring/health-check.sh` | `emir:emir` | `0775` |
| Scheduled monitoring | `/usr/local/lib/sentinelops/health-check.sh` | `root:root` | `0755` |

The scheduled directory is owned by `root:root` with mode `0755`.

The root service executes the protected copy.

The workflow records:

- system-load samples;
- memory samples;
- disk usage;
- backup freshness;
- Docker service health;
- Nginx service health;
- SSH health;
- Compose application state;
- application endpoint health;
- host Nginx endpoint health.

### Structured Resource Records

SEN-028 added:

| Check | Source | Recorded values |
|---|---|---|
| `memory_usage` | `/proc/meminfo` | `total_kib`, `available_kib` |
| `system_load` | `/proc/loadavg` | `load_1m`, `load_5m`, `load_15m` |

Memory values are recorded in kibibytes.

Load values are the 1-minute, 5-minute and 15-minute load averages.

For these checks, `PASS` with severity `INFO` means collection and input validation succeeded. No memory or load threshold is evaluated. Load averages are not CPU percentages.

Missing, unreadable or invalid input produces a `FAIL` record with severity `CRITICAL`, and the collector returns exit code `1`.

The main monitoring workflow continues with its remaining checks.

Collectors accept an optional input-file path for isolated tests. Source the script using Bash. Sourcing defines the functions without executing the host monitoring workflow.

### Monitoring Service

Repository source:

```text
provision/systemd/sentinelops-monitoring.service
```

Installed path:

```text
/etc/systemd/system/sentinelops-monitoring.service
```

Configuration:

```ini
[Unit]
Description=SentinelOps scheduled host and application monitoring
After=network.target docker.service nginx.service

[Service]
Type=oneshot
User=root
Group=root
WorkingDirectory=/usr/local/lib/sentinelops
ExecStart=/usr/bin/bash /usr/local/lib/sentinelops/health-check.sh
TimeoutStartSec=45s
UMask=0027
StandardOutput=journal
StandardError=journal
```

The complete script includes privileged host inspection. Running the scheduled service as root avoids an interactive authentication dependency.

No passwordless sudo rule is introduced.

The service has a 45-second execution timeout. Output and execution errors are available in the systemd journal.

An `inactive (dead)` service state is expected after a successful oneshot run.

### Monitoring Timer

Repository source:

```text
provision/systemd/sentinelops-monitoring.timer
```

Installed path:

```text
/etc/systemd/system/sentinelops-monitoring.timer
```

Configuration:

```ini
[Unit]
Description=Run SentinelOps monitoring every minute

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
AccuracySec=1s
RandomizedDelaySec=0
Unit=sentinelops-monitoring.service

[Install]
WantedBy=timers.target
```

The timer requests execution after one minute of boot time and at one-minute intervals relative to the service's last activation.

Actual start times can vary slightly.

Systemd does not start another instance of the same service while it is already active.

The timer should remain enabled and active between runs. It does not replay every monitoring interval missed while the VM was powered off.

### Monitoring Logs

Structured records are written to:

```text
/var/log/sentinelops/health-check.log
```

Expected permissions:

| Path | Owner | Mode |
|---|---|---|
| `/var/log/sentinelops` | `root:emir` | `0750` |
| `/var/log/sentinelops/health-check.log` | `emir:emir` | `0640` |

Records retain:

```text
timestamp
check
status
severity
message
```

A successful service exit means execution completed. It does not establish that every monitored condition passed.

Inspect individual structured records for health outcomes.

### Monitoring Inspection

Run on the Ubuntu host:

```bash
systemctl list-timers --all --no-pager sentinelops-monitoring.timer

systemctl status sentinelops-monitoring.timer sentinelops-monitoring.service --no-pager

sudo journalctl -b -u sentinelops-monitoring.service --no-pager

tail -n 30 /var/log/sentinelops/health-check.log
```

To inspect resource records:

```bash
grep -E 'check=(memory_usage|system_load)' \
  /var/log/sentinelops/health-check.log | tail -n 12
```

To inspect Nginx service records:

```bash
grep 'check=nginx_service ' \
  /var/log/sentinelops/health-check.log | tail -n 10
```

### Repeated Provisioning and Monitoring

After preflight succeeds, provisioning stops an existing monitoring timer and service before redeploying managed assets.

It starts the monitoring service during final validation and enables the timer after those checks succeed.

If preflight fails, monitoring has not yet been paused.

If provisioning fails after the pause, monitoring remains stopped until the problem is corrected and provisioning completes successfully.

## Backup

The backup source is:

```text
provision/backup/backup-sentinelops.sh
```

It is deployed to:

```text
/home/emir/backups/sentinelops/backup-sentinelops.sh
```

The workflow provides:

- UTC timestamped archives;
- SHA-256 checksum generation and verification;
- manifest generation and verification;
- seven-day retention;
- restrictive artifact permissions.

Backup artifacts are stored under:

```text
/home/emir/backups/sentinelops/
```

### Backup Scheduling

Repository units:

```text
provision/systemd/sentinelops-backup.service
provision/systemd/sentinelops-backup.timer
```

Installed units:

```text
/etc/systemd/system/sentinelops-backup.service
/etc/systemd/system/sentinelops-backup.timer
```

The backup timer uses:

```ini
OnCalendar=daily
Persistent=true
```

The daily calendar follows the host's timezone. The validated lab baseline uses UTC.

The backup timer should remain enabled and active after provisioning.

### Initial Backup

If no SentinelOps archive exists, provisioning runs:

```bash
systemctl start sentinelops-backup.service
```

If an archive already exists, provisioning reports:

```text
Existing SentinelOps backup archive found.
Skipping initial backup creation during repeated provisioning.
```

This avoids creating another archive solely because provisioning was repeated.

Normal scheduled backups remain controlled by the backup timer.

### Backup Validation

The newest archive must have corresponding files:

```text
.tar.gz
.tar.gz.sha256
.tar.gz.manifest
```

The provisioner verifies the checksum and compares the manifest with the archive listing.

Existing valid backups are preserved during repeated provisioning.

## Host Nginx

Repository configuration:

```text
provision/nginx/sentinelops
```

Deployed configuration:

```text
/etc/nginx/sites-available/sentinelops
```

Enabled through:

```text
/etc/nginx/sites-enabled/sentinelops
```

Upstream:

```text
http://127.0.0.1:8000
```

Provisioning tests the configuration before restarting Nginx.

Manual validation:

```bash
sudo nginx -t
```

Repository-to-host comparison:

```bash
sudo diff -u \
  provision/nginx/sentinelops \
  /etc/nginx/sites-available/sentinelops
```

No diff output means the compared files match.

## SSH Hardening

Repository drop-in:

```text
provision/ssh/00-sentinelops.conf
```

Installed path:

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

Provisioning syntax-checks the configuration before reloading an active SSH service.

Inspect effective settings:

```bash
sudo sshd -T | grep -Ei \
  'passwordauthentication|permitrootlogin|pubkeyauthentication|kbdinteractiveauthentication'
```

## Firewall

Provisioning establishes:

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

TCP 8000 is not added to UFW.

Repeated execution relies on UFW's existing-rule handling and must not accumulate duplicate rules.

Inspect:

```bash
sudo ufw status verbose
```

## Docker Installation

Docker is installed from Docker's Ubuntu package repository.

Managed repository files:

```text
/etc/apt/keyrings/docker.asc
/etc/apt/sources.list.d/docker.sources
```

The Ubuntu codename and machine architecture determine repository configuration.

Docker package versions are not pinned. Provisioning installs compatible versions available from the configured repository at execution time.

### Docker Group Membership

The administrator account uses the Docker group.

Provisioning checks existing membership before adding it:

```bash
usermod -aG docker emir
```

A new login session is required when membership is first added.

Docker group membership grants powerful host administration capabilities. Protecting the scheduled script path does not remove those existing privileges.

## Expected Final State

These components should be enabled and active:

```text
nginx
docker
ssh.socket
sentinelops-backup.timer
sentinelops-monitoring.timer
```

Inspect enablement:

```bash
systemctl is-enabled \
  nginx \
  docker \
  ssh.socket \
  sentinelops-backup.timer \
  sentinelops-monitoring.timer
```

Inspect activity:

```bash
systemctl is-active \
  nginx \
  docker \
  ssh.socket \
  sentinelops-backup.timer \
  sentinelops-monitoring.timer
```

The monitoring service itself normally becomes inactive between runs.

### Network State

Expected listeners include:

```text
0.0.0.0:22
0.0.0.0:80
127.0.0.1:8000
```

IPv6 listeners may also exist for SSH and Nginx.

The backend must not listen externally.

### Health State

On the Ubuntu host:

```bash
curl --fail http://127.0.0.1:8000/health
curl --fail http://127.0.0.1/health
```

Expected response from both:

```json
{"status":"healthy","version":"0.1.0"}
```

### Failed Units

```bash
systemctl --failed
```

Expected:

```text
0 loaded units listed.
```

## Failure Handling

Controlled validation errors use:

```text
[SEN-025] ERROR: <failure reason>
```

Unexpected command failures report:

```text
[SEN-025] ERROR: Provisioning stopped unexpectedly.
[SEN-025] ERROR: Exit code: <code>
[SEN-025] ERROR: Line: <line>
[SEN-025] ERROR: Command: <command>
```

The provisioner exits non-zero on these failures.

Provisioning is not a transactional rollback system. A failure after host changes begin can leave some changes applied.

For SEN-029, a failure after monitoring is paused also leaves the timer stopped until successful recovery.

## Repeated Execution

Repeated provisioning is intended to converge:

- package installation;
- Docker group membership;
- managed configuration;
- firewall rules;
- application state;
- backup initialization;
- monitoring deployment and scheduling.

Build evaluation or service restarts may still occur. Idempotency here means convergence to the intended state, not zero work on every repeated run.

### Historical SEN-025 Evidence

The initial repeated SEN-024 run showed an unnecessary provisioning-specific backup:

```text
archive count: 1 -> 2
```

SEN-025 added conditional initialization. Its hardened repeated run showed:

```text
archive count: 2 -> 2
```

UFW reported existing rules rather than creating duplicates.

The validated final rule set contained:

```text
22/tcp
Nginx HTTP
22/tcp (v6)
Nginx HTTP (v6)
```

Managed Nginx, SSH and backup-unit comparisons matched the repository versions.

Historical configuration hashes were:

| Configuration | SHA-256 |
|---|---|
| Nginx | `31be518b3e0d3ff632022cb30b3d3005d279bbe6e6addd9fbfb0d1fddbbffd5a` |
| SSH | `976d699973524cbe1ca0cd0e29898771e7b1030cb1b1d0476fd9ce9ee6fed831` |
| Backup service | `6f7f6a5d8d49fb8cb41b55bd3721ff57855584d387577a47d3a6f47fabb7b69d` |
| Backup timer | `da345fc89a90863e3c2bcfaba2dce14a9d3c00b55cd26f831082fd0c1562fce1` |

These are historical evidence values, not permanent configuration identifiers.

### Historical SEN-025 Preflight Failure

A source Dockerfile was temporarily renamed in the disposable test copy.

Provisioning returned exit code `1` before deployment.

The live Nginx configuration hash remained unchanged, the backup count remained two, and no failed units were reported.

The source was restored before successful validation continued.

## SEN-029 Runtime Evidence

Validation was performed on:

```text
hostname: sentinelops-test
address: 192.168.64.3
operating system: Ubuntu Server 24.04.4 LTS
architecture: arm64
date: 2026-09-07
```

The provisioning tree was staged under:

```text
/home/emir/sen029-validation/provision
```

### Scheduled Execution

The provisioner completed successfully and enabled the timer.

Scheduled runs were observed at:

```text
2026-09-07T20:58:13Z
2026-09-07T20:59:13Z
```

Both resource collection and the complete service execution succeeded.

### Reboot Persistence

| Event | UTC timestamp |
|---|---|
| Timer started automatically | `2026-09-07T21:01:09Z` |
| Monitoring service started | `2026-09-07T21:02:06Z` |
| Monitoring service completed | `2026-09-07T21:02:08Z` |

The service reported exit status `0/SUCCESS`.

Both application and host Nginx HTTP checks returned 200.

The initial empty journal checks occurred before the first scheduled execution.

### Controlled Failure Detection

The test stopped Nginx and waited for new structured records without manually triggering monitoring.

| Event | UTC timestamp |
|---|---|
| Failure test started | `2026-09-07T21:08:10Z` |
| Scheduled Nginx FAIL | `2026-09-07T21:08:12Z` |
| Nginx restored | `2026-09-07T21:08:12Z` |
| Scheduled recovery PASS | `2026-09-07T21:09:13Z` |

Failure record:

```text
timestamp=2026-09-07T21:08:12Z check=nginx_service status=FAIL severity=CRITICAL message="Nginx service is not active"
```

Recovery record:

```text
timestamp=2026-09-07T21:09:13Z check=nginx_service status=PASS severity=INFO message="Nginx service is active"
```

Observed detection time:

```text
2 seconds
```

This met the 120-second SC-15 target for the selected lab test.

Timing used whole-second UTC timestamps recorded immediately before the stop request. The result includes stop-command execution time and does not guarantee two-second detection for every failure.

The health endpoint returned the expected healthy JSON after recovery.

### Repeated Provisioning

The updated provisioner was executed again.

Observed results included:

- monitoring paused and redeployed;
- existing backup retained;
- backup checksum and manifest passed;
- application and proxy returned HTTP 200;
- SSH validation passed;
- backend remained loopback-only;
- no failed units;
- monitoring timer re-enabled and active.

### Missing Monitoring Asset

The timer source was temporarily renamed in the test staging directory.

Provisioning reported:

```text
[SEN-025] ERROR: Required provisioning asset missing: /home/emir/sen029-validation/provision/systemd/sentinelops-monitoring.timer
```

Exit code:

```text
1
```

The source was restored. The installed monitoring timer remained active because the failure occurred before the pause stage.

### Evidence Boundary

These tests establish runtime behaviour on the disposable test VM.

They do not establish SEN-029 deployment to the primary VM.

The runtime tests were performed manually and are not added to the current CI workflow.

Full evidence belongs in:

```text
docs/phase-2/automated-monitoring-baseline.md
```

## GitHub Actions CI

Workflow:

```text
.github/workflows/ci.yml
```

Name:

```text
SentinelOps CI
```

Current jobs:

1. Shell validation.
2. Secret safety.
3. Container and application validation.

### Triggers

The workflow runs for:

```text
pull requests
pushes to main
```

This provides pre-merge and default-branch validation.

### Permissions

```yaml
permissions:
  contents: read
```

The workflow does not require VM credentials, deployment secrets or repository write permissions.

Developer authentication used to modify workflow files is separate from workflow runtime permissions.

### Shell Validation

The job discovers shell scripts under the provisioning tree and runs:

- Bash syntax validation;
- ShellCheck static analysis.

ShellCheck is installed in the GitHub-hosted runner. It does not need to be installed on the developer Mac for CI to operate.

SEN-026 demonstrated discovery of a newly added synthetic shell script and rejection of invalid Bash syntax.

### Secret Safety

The job checks tracked content for obvious prohibited secret-like patterns.

It reports affected paths without intentionally printing matching sensitive values.

This is a basic repository safety check, not a guarantee that all possible secrets are detected.

### Container Configuration

CI checks:

- Docker tooling availability;
- Compose configuration parsing;
- the expected loopback-only port mapping;
- rejection of explicitly privileged container mode.

Expected mapping:

```text
127.0.0.1:8000:80
```

### Image Build and Startup

CI runs:

```bash
docker compose build
docker compose up -d
```

from:

```text
provision/application
```

Build or startup failure causes validation to fail.

### Application Health

CI waits for:

```text
http://127.0.0.1:8000/health
```

The availability loop allows up to 30 attempts with two seconds between unsuccessful attempts.

Failure reports Compose state and logs.

After availability, CI verifies:

- HTTP 200;
- valid JSON;
- `status` equals `healthy`;
- `version` equals `0.1.0`.

### Cleanup

The cleanup step uses:

```yaml
if: always()
```

and runs:

```bash
docker compose down --volumes --remove-orphans
```

Cleanup therefore runs after successful validation and after application-test failures.

### CI Boundary

CI does not:

- connect to the Ubuntu lab VM;
- run full host provisioning;
- validate the installed monitoring timer at runtime;
- perform the Nginx stop-and-recovery timing test;
- deploy infrastructure;
- publish container images.

Host runtime validation remains a separate workflow.

## Historical CI Evidence

### SEN-026

| Stage | Shell validation | Secret safety | Reason |
|---|---|---|---|
| Initial run | FAIL | PASS | SC1091 on runtime `/etc/os-release` sourcing |
| Correction | PASS | PASS | Specific SC1091 handling |
| Controlled failure | FAIL | PASS | Synthetic invalid Bash script |
| Recovery | PASS | PASS | Synthetic script removed |

The SC1091 directive was applied specifically to the runtime source operation. ShellCheck was not disabled globally.

The temporary failure script was:

```text
provision/sen-026-ci-failure-test.sh
```

It does not remain in the final repository tree.

Implementation and test commits:

```text
8ef73ba ci: add SEN-026 GitHub Actions foundation
63f5c68 fix: resolve SEN-026 ShellCheck finding
6d14acd test: demonstrate SEN-026 CI shell failure
5a40a22 test: recover SEN-026 CI failure simulation
```

### SEN-027

| Run | Shell | Secret safety | Container/application | Result |
|---|---|---|---|---|
| #7 | PASS | PASS | PASS | Initial validation |
| #8 | PASS | PASS | FAIL | Controlled version mismatch |
| #9 | PASS | PASS | PASS | Recovery |

The controlled failure changed the expected version to `9.9.9` while the application continued to return `0.1.0`.

CI rejected the mismatch with exit code `1`. Cleanup still executed.

Implementation and test commits:

```text
e09c00b ci: add SEN-027 container and application validation
b63ea8f test: demonstrate SEN-027 application CI failure
41497c5 test: recover SEN-027 application CI failure
```

### SEN-028

The first pull-request run identified ShellCheck findings SC2120 and SC2119 because collector calls did not explicitly pass input paths.

The correction passed:

```text
/proc/loadavg
/proc/meminfo
```

to the respective collector calls.

Observed workflow sequence:

| Run | Result |
|---|---|
| #13 | Shell validation failed |
| #14 | All three jobs passed after correction |
| #15 | All three jobs passed after documentation update |
| #16 | Default-branch CI passed after merge |

Implementation commits:

```text
1b5394f feat: complete SEN-028 structured resource monitoring logs
30423cd fix: pass explicit resource paths for SEN-028 ShellCheck
298f2b6 docs: record SEN-028 CI recovery and runtime validation
```

Merge commit:

```text
b353f1e
```

### SEN-029

Runtime validation is recorded above.

Pull-request CI, merge verification and default-branch CI have not yet been established for SEN-029 at this documentation stage.

## Secret Handling

Repository content must not include:

- passwords;
- private SSH keys;
- API tokens;
- authentication secrets;
- private credentials.

Public-key readiness is a host prerequisite. Private authentication material is not distributed through provisioning assets.

Do not include sensitive values in validation evidence or screenshots.

## Validation Checklist

Before accepting a provisioning run, verify:

- preflight completed;
- packages and Docker repository configuration succeeded;
- required directories and assets were deployed;
- Nginx and SSH syntax validation passed;
- application startup succeeded;
- initial backup handling completed;
- backup checksum and manifest passed;
- SSH and firewall expectations were preserved;
- backend TCP 8000 remained loopback-only;
- monitoring service execution completed;
- individual monitoring records were inspected;
- required services and timers were enabled and active;
- scheduled script and log permissions were correct;
- no failed systemd units remained.

For SEN-029, also verify:

- repeated scheduled execution;
- execution after reboot;
- failure detection within two intervals;
- scheduled recovery;
- repeated provisioning;
- missing monitoring asset rejection.

For repository completion, verify separately:

- pull-request checks passed;
- the intended changes were merged;
- default-branch CI passed;
- local main was synchronised;
- the working tree was clean.

## Known Limitations

- Docker package versions are not pinned.
- Provisioning can restart services and rebuild application images.
- Provisioning does not perform full transactional rollback.
- Failed provisioning after the monitoring pause leaves monitoring stopped.
- The monitoring service timeout can terminate an incomplete run.
- Service exit status does not aggregate every health-check result.
- Memory and load records represent validated collection without thresholds.
- Log rotation is not introduced by SEN-029.
- Monitoring cannot run while the VM is powered off.
- The monitoring log remains writable by the existing administrator account.
- Detection-time evidence covers a selected lab failure.
- Root-owned script deployment does not remove the administrator's existing sudo or Docker privileges.
- CI does not replace host runtime validation.

## Out of Scope

The current SEN-029 change does not introduce:

- external alerts;
- automatic remediation;
- memory or load thresholds;
- log rotation;
- overall health-check exit-status redesign;
- changes to backup scheduling or retention;
- Prometheus or Grafana;
- cloud infrastructure;
- multi-server monitoring;
- public DNS or HTTPS;
- application architecture expansion.

## Evidence Documents

| Area | Document |
|---|---|
| Repeatable provisioning | `docs/phase-4/repeatable-provisioning-baseline.md` |
| Provisioning idempotency | `docs/phase-4/provisioning-idempotency-validation-baseline.md` |
| CI foundation | `docs/phase-4/github-actions-ci-baseline.md` |
| Structured resource logging | `docs/phase-2/resource-monitoring-logging-baseline.md` |
| Automated monitoring | `docs/phase-2/automated-monitoring-baseline.md` |

Historical validation describes the environment and revision tested at that time. Current changes require their own validation evidence.

## Requirements Status

The previously established provisioning and CI baselines record FR-41 through FR-50 and SC-36 through SC-40 as satisfied within their documented scope.

SEN-028 completed structured resource logging and passed pull-request and default-branch CI.

SEN-029 has demonstrated scheduled execution, reboot persistence, repeated provisioning and SC-15 detection timing on the test VM.

SEN-029 repository completion remains pending until its pull-request CI, merge and default-branch CI are verified.