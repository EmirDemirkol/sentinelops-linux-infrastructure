# SentinelOps

**Linux Infrastructure Automation and Monitoring Lab**

SentinelOps is a practical infrastructure engineering project designed to demonstrate Linux administration, networking, security, automation, containerisation, monitoring, backup and recovery, incident response, and DevOps fundamentals.

The project simulates a small fictional company environment that requires a Linux server to securely host and operate an application.

## Project Goal

The goal of SentinelOps is to build a Linux environment that can eventually be:

- securely configured;
- accessed using controlled user permissions;
- protected with firewall rules;
- used to host a containerised application;
- served through an Nginx reverse proxy;
- monitored for service and resource failures;
- backed up automatically;
- restored after data loss;
- tested using deliberate failure scenarios;
- rebuilt through repeatable automation.

The project focuses on understanding and operating infrastructure rather than simply installing tools.

## Current Status

**Phase 0: Discovery and Planning**

Infrastructure implementation has not started yet.

Phase 0 defines:

- problem statement;
- objectives;
- project scope;
- exclusions;
- stakeholders;
- functional requirements;
- non-functional requirements;
- architecture;
- networking;
- threat model;
- security baseline;
- risks;
- MVP;
- success criteria;
- development roadmap.

## Planned MVP Architecture

The first version of SentinelOps will use a single Ubuntu Server virtual machine.

Planned request flow:

```text
Host Browser
     |
     | HTTP
     v
Ubuntu Server VM
     |
     v
UFW Firewall
     |
     v
Nginx Reverse Proxy
     |
     v
Docker Application

The same server will later provide:

- health monitoring
- operational logging
- scheduled backups
- restoration procedures
- controlled failure simulations

The initial application will remain intentionally small because SentinelOps is an infrastructure project rather than an application-development project.

## Planned Core Technologies

### Initial MVP

- Ubuntu Linux
- Bash
- Git
- GitHub
- SSH
- UFW
- Nginx
- Docker
- Docker Compose
- systemd
- GitHub Actions

### Possible Post-MVP Enhancements

- Ansible
- Prometheus
- Node Exporter
- Grafana
- AWS EC2
- IAM
- Security Groups
- CloudWatch

Technologies such as Kubernetes, Terraform, multi-cloud architecture, and complex distributed systems are deliberately excluded from the initial MVP.

## Security Principles

SentinelOps will follow several core security principles:

- least privilege
- minimum network exposure
- SSH key authentication
- restricted root access
- controlled sudo privileges
- secure file ownership and permissions
- separation of secrets from source control
- no real credentials or private keys in Git
- synthetic application data only
- tested backup restoration
- documented recovery procedures

## Repository Structure

```text
sentinelops-linux-infrastructure/
├── README.md
├── LICENSE
├── .gitignore
└── docs/
    ├── phase-0/
    │   ├── project-charter.md
    │   ├── requirements.md
    │   ├── risk-register.md
    │   └── success-criteria.md
    ├── architecture/
    │   ├── architecture.md
    │   ├── network-design.md
    │   └── diagrams/
    ├── security/
    │   ├── threat-model.md
    │   └── security-baseline.md
    └── adr/
```

Additional application, automation, monitoring, testing, and CI directories will be created only when their development phases begin.

## Development Principles

Every major infrastructure change should answer:

1. What problem does this solve?
2. Why is this technology being used?
3. What exactly is being changed?
4. How can the change be verified?
5. What could fail?
6. How can the change be reversed?
7. How would the same problem be handled in a real organisation?

Important infrastructure will first be understood manually before being automated.

## Planned Development Phases

### Phase 0

Discovery and planning.

### Phase 1

Manual Linux administration and security foundation.

### Phase 2

Application platform with Docker and Nginx.

### Phase 3

Repeatable provisioning automation.

### Phase 4

Monitoring and operational logging.

### Phase 5

Backup and recovery.

### Phase 6

Failure simulation and incident response.

### Phase 7

CI validation and MVP release.

### Phase 8

Optional advanced infrastructure and cloud deployment.

## Project Status

SentinelOps is currently under active development.

Current milestone:

```text
Phase 0
```