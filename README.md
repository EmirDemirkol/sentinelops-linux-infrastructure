# SentinelOps

**Linux Infrastructure Automation and Monitoring Lab**

SentinelOps is a practical single-server infrastructure project that demonstrates Linux administration, secure access, networking, container deployment, monitoring, backup, recovery, failure simulation, repeatable provisioning and CI validation.

The project uses a fictional application environment so that the infrastructure lifecycle can be built, inspected, deliberately failed, recovered and explained without using production data.

## Current Status

The SentinelOps MVP implementation is substantially complete through SEN-029.

Completed areas include:

- Ubuntu Server administration and secure SSH access;
- UFW firewall protection with a deny-by-default inbound policy;
- host-side Nginx reverse proxy;
- Docker and Docker Compose application deployment;
- private application binding on `127.0.0.1:8000`;
- application homepage and `/health` endpoint;
- structured monitoring records;
- scheduled monitoring through systemd;
- monitoring failure detection and recovery validation;
- automated local backups;
- backup manifests, checksums, retention and restoration;
- controlled failure simulations;
- repeatable and idempotent provisioning;
- GitHub Actions shell, secret, container and application validation.

SEN-030 completes the professional README and ADR documentation. Clean rebuild verification and final demonstration evidence remain separate finalisation work.

## Project Goal

SentinelOps demonstrates how a small Linux environment can be securely configured, operated, monitored, backed up, recovered and reproduced through understandable automation.

The project prioritises manual understanding before automation. Each major change is documented with its purpose, implementation, validation method, failure mode and recovery path.

## MVP Architecture

The MVP uses one Ubuntu Server virtual machine running on a local MacBook.

```text
MacBook terminal and browser
          |
          | private virtual network
          v
Ubuntu Server VM
          |
          +--> SSH for administration
          +--> UFW host firewall
          +--> Nginx reverse proxy :80
          |          |
          |          +--> 127.0.0.1:8000
          |                    |
          |                    +--> Docker Compose application
          +--> systemd monitoring service and timer
          +--> monitoring log
          +--> systemd backup service and timer
          +--> local backup storage
```

Nginx is the application-facing entry point. The application backend is published only on the host loopback interface, so normal traffic must pass through Nginx.

## Network Exposure

| Port | Service | Exposure | Purpose |
|---|---|---|---|
| 22/TCP | SSH | Approved administration path | Remote administration |
| 80/TCP | Host Nginx | Approved application path | HTTP application access |
| 8000/TCP | Application backend | `127.0.0.1` only | Nginx to application traffic |
| Other inbound ports | None | Blocked by default | Reduce attack surface |

The MVP does not require public DNS, public HTTPS, a public IP address or multi-server networking.

## Application

The application is intentionally small because SentinelOps is an infrastructure project.

It provides:

- a basic homepage;
- a `/health` endpoint;
- documented version information;
- synthetic data suitable for backup and recovery testing.

The expected health response is:

```json
{"status":"healthy","version":"0.1.0"}
```

## Monitoring

The monitoring workflow checks and records:

- Nginx service state;
- Docker service state;
- SSH service state;
- Compose application state;
- application health;
- host Nginx health;
- filesystem usage;
- backup freshness;
- memory samples from `/proc/meminfo`;
- load samples from `/proc/loadavg`.

The scheduled monitoring service runs the protected root-owned copy of the health-check script. The timer executes it every minute after boot. Results are written to:

```text
/var/log/sentinelops/health-check.log
```

The monitoring log uses structured records containing a timestamp, check name, status, severity and message.

Memory and load records are collection records. They do not claim that a threshold has been evaluated unless a threshold is explicitly documented.

## Backups and Recovery

The backup workflow uses systemd to run the repository-managed backup script. It creates timestamped archives, manifests and checksums, applies the documented retention policy and records the result.

Backups are stored locally for the MVP so that creation, integrity verification, restoration and recovery can be understood and validated before introducing remote storage.

The documented restoration flow is:

1. select a backup;
2. verify its checksum;
3. extract it to a safe temporary location;
4. review the manifest and contents;
5. restore the required data or configuration;
6. correct ownership and permissions;
7. restart or reload the required service;
8. verify the application and health endpoint.

## Provisioning

The main provisioner is:

```text
provision/scripts/provision.sh
```

It validates prerequisites, installs or configures required packages, deploys application and monitoring assets, configures Nginx, installs systemd units, applies SSH and firewall configuration, starts the application, ensures an initial backup and validates the resulting services.

The provisioner is designed to be repeatable and to avoid duplicate firewall rules, duplicate group membership and unnecessary provisioning-specific backup archives.

Important failures are rejected during preflight with useful output and a non-zero exit status.

## Security Principles

SentinelOps preserves these boundaries:

- named administrator access instead of normal root login;
- SSH key authentication and SSH hardening;
- UFW deny-by-default inbound policy;
- host Nginx as the approved application entry point;
- loopback-only application backend exposure;
- least-privilege file ownership and permissions;
- non-privileged application container operation;
- no real credentials or private keys in Git;
- synthetic application data only;
- documented backup and recovery procedures.

Docker access is treated as privileged. The project does not claim production high availability, public cloud security or multi-server resilience.

## Repository Structure

```text
.
├── .github/workflows/ci.yml
├── docs/
│   ├── adr/
│   ├── architecture/
│   ├── phase-0/
│   ├── phase-1/
│   ├── phase-2/
│   ├── phase-3/
│   ├── phase-4/
│   └── security/
└── provision/
    ├── application/
    ├── backup/
    ├── monitoring/
    ├── nginx/
    ├── scripts/
    ├── ssh/
    ├── systemd/
    └── README.md
```

## Validation and Evidence

The repository contains documented evidence for:

- manual Linux and security configuration;
- Nginx and backend isolation;
- application health;
- backup creation, integrity and restoration;
- controlled application, backup and Nginx failures;
- repeatable and idempotent provisioning;
- shell validation and secret safety;
- container configuration and application testing;
- scheduled monitoring, reboot persistence and measured failure detection.

Pull-request CI, merge verification and default-branch CI are separate completion gates. The completed SEN-028 and SEN-029 changes passed those gates.

## Development Principles

Every major infrastructure change should answer:

1. What problem does this solve?
2. Why is this technology being used?
3. What exactly is changing?
4. How can the change be verified?
5. What could fail?
6. How can the change be reversed?
7. How would the same problem be handled in a real organisation?

## Remaining MVP Work

The remaining finalisation work is deliberately separate from the completed implementation:

- clean rebuild from a supported Ubuntu Server VM;
- final MVP verification against the success criteria;
- organised screenshots and runtime evidence;
- final demonstration video;
- criterion-by-criterion MVP completion audit.

## Post-MVP Scope

The following are deliberately excluded from the initial MVP:

- Ansible;
- Prometheus;
- Node Exporter;
- Grafana;
- Terraform;
- Kubernetes;
- AWS or multi-server infrastructure;
- public DNS and HTTPS deployment;
- automatic remediation;
- external alerting;
- application architecture expansion.

## Documentation

Detailed evidence and decisions are documented in:

- `docs/architecture/architecture.md`;
- `docs/architecture/network-design.md`;
- `docs/security/security-baseline.md`;
- `docs/security/threat-model.md`;
- `docs/phase-2/automated-monitoring-baseline.md`;
- `docs/phase-2/resource-monitoring-logging-baseline.md`;
- `docs/phase-3/application-container-failure-simulation.md`;
- `docs/phase-3/backup-workflow-failure-simulation.md`;
- `docs/phase-3/host-nginx-failure-simulation.md`;
- `docs/phase-4/repeatable-provisioning-baseline.md`;
- `docs/phase-4/provisioning-idempotency-validation-baseline.md`;
- `docs/phase-4/github-actions-ci-baseline.md`;
- `provision/README.md`.
