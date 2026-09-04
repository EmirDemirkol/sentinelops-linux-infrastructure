# SentinelOps Repeatable Provisioning

## Purpose

This directory contains the version-controlled assets and provisioning workflow required to reproduce the SentinelOps single-server environment from a clean supported Ubuntu Server baseline.

The provisioning baseline translates the infrastructure that was originally configured and verified manually into a repeatable process.

SEN-024 focuses on repeatable provisioning.

Full idempotency and advanced provisioning failure handling are intentionally treated as later work.

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

The provisioning script validates Ubuntu 24.04 before making changes.

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

## Prerequisites

The provisioning script does not create the primary administrator account.

Before running the script, the target host must already contain:

```text
user: emir
group: emir
home: /home/emir
```

The `emir` account must have administrative `sudo` access.

### SSH Access Prerequisite

Before password authentication is disabled, public-key SSH access must already be configured and tested for the `emir` account.

Expected key location:

```text
/home/emir/.ssh/authorized_keys
```

Do not run the provisioning workflow remotely unless public-key authentication has already been independently verified.

Console access to the VM should remain available during initial provisioning.

No private SSH key is stored in this repository.

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

### SSH

The SentinelOps SSH hardening drop-in is:

```text
provision/ssh/00-sentinelops.conf
```

Expected effective settings:

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
```

The deployed path is:

```text
/etc/ssh/sshd_config.d/00-sentinelops.conf
```

The configuration is syntax-tested before any running SSH service is reloaded.

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

## Docker Repository

Docker is installed from Docker's Ubuntu package repository.

The provisioning workflow creates:

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

## Provisioning Order

The current workflow executes in this order:

```text
1. require root execution
2. validate Ubuntu release
3. validate target user and group
4. validate repository provisioning assets
5. install base packages
6. configure Docker repository
7. install Docker Engine and Docker Compose
8. create required directories
9. deploy application files
10. deploy monitoring
11. deploy backup workflow
12. deploy host Nginx configuration
13. deploy backup systemd units
14. deploy SSH hardening
15. configure UFW
16. build and start the Docker Compose application
17. run an initial backup
18. validate service enablement and state
19. validate SSH security settings
20. validate direct application health
21. validate host Nginx health
22. validate network listeners and firewall
23. validate backup integrity and manifest
24. run the monitoring workflow
25. verify there are no failed systemd units
```

## Running the Provisioner

From the root of a checked-out SentinelOps repository on the Ubuntu host:

```bash
sudo ./provision/scripts/provision.sh
```

The script uses:

```bash
set -euo pipefail
```

so an unexpected command failure terminates provisioning rather than silently continuing.

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

## Expected Network State

Expected listeners include:

```text
0.0.0.0:22
0.0.0.0:80
127.0.0.1:8000
```

IPv6 listeners may also exist for SSH and Nginx.

There must not be an external listener such as:

```text
0.0.0.0:8000
[::]:8000
```

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

## Backup Validation

The provisioning workflow performs an initial backup.

The newest archive must have:

```text
.tar.gz
.tar.gz.sha256
.tar.gz.manifest
```

The checksum must pass:

```bash
sha256sum --check
```

The manifest must match the current archive listing.

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
22/tcp allowed
80/tcp allowed
8000/tcp not allowed
```

## Nginx Validation

Validate host configuration:

```bash
sudo nginx -t
```

The test must succeed before the host configuration is considered valid.

## Failure Validation

Check systemd after provisioning:

```bash
systemctl --failed
```

Expected:

```text
0 loaded units listed.
```

## Secret Handling

The repository must not contain:

- private SSH keys;
- passwords;
- API tokens;
- authentication secrets;
- private credentials.

Public SSH keys remain host-specific prerequisites and are not embedded into the provisioning assets.

## Repeatability Boundary

SEN-024 establishes a repeatable provisioning baseline.

It demonstrates how a clean supported Ubuntu host can be transformed into the documented SentinelOps architecture using version-controlled infrastructure assets.

SEN-024 does not claim full idempotency.

Repeated execution behavior, stronger prerequisite enforcement, and more advanced provisioning error handling are intentionally treated as separate follow-up work.

## Manual Understanding

Every major component represented by this provisioning baseline was first configured, inspected, secured, and validated manually during earlier SentinelOps issues.

The provisioning workflow therefore codifies an already-understood architecture rather than introducing an opaque configuration-management layer.

This maintains the project's manual-understanding-before-automation principle.