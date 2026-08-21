# SentinelOps Phase 0 Requirements

## Purpose

This document defines the initial functional and non-functional requirements for SentinelOps.

The requirements describe what the system must eventually do and the qualities the final MVP must demonstrate.

No infrastructure implementation is performed as part of this document.

---

# Functional Requirements

## FR-01: Administrator Access

The system shall provide a named administrator account for server administration.

The administrator shall not use the root account for normal daily operations.

## FR-02: SSH Authentication

The system shall support secure remote administration using SSH key authentication.

Password authentication shall only be disabled after key-based access has been verified successfully.

## FR-03: Root Access Restriction

Direct root SSH login shall be disabled or otherwise restricted.

Administrative actions shall use controlled privilege escalation.

## FR-04: User and Group Management

The system shall support clearly defined users and groups for infrastructure administration and application ownership.

## FR-05: File and Directory Permissions

Protected configuration files and directories shall use ownership and permissions that prevent unauthorised modification.

## FR-06: Firewall Protection

The system shall use UFW with a deny-by-default inbound policy.

Only explicitly required inbound services shall be permitted.

## FR-07: SSH Network Access

SSH shall be reachable only through the approved virtual network or trusted administration path.

## FR-08: HTTP Access

Nginx shall receive HTTP application traffic on the approved network interface.

## FR-09: Private Application Port

The application container port shall not be directly exposed externally.

Application requests shall pass through Nginx.

## FR-10: Reverse Proxy

Nginx shall act as the reverse proxy between the client and the application container.

## FR-11: Application Homepage

The containerised application shall provide a basic homepage that can be used to verify successful deployment.

## FR-12: Health Endpoint

The application shall expose a `/health` endpoint.

The endpoint shall provide enough information to determine whether the application is operating normally.

## FR-13: Version Information

The application shall expose its current version through the health response or another documented status mechanism.

## FR-14: Container Deployment

The application shall run inside Docker and shall be managed using Docker Compose.

## FR-15: Container Restart Behaviour

The application container shall use an appropriate restart policy.

The restart behaviour shall be tested.

## FR-16: Nginx Service Monitoring

The monitoring system shall verify whether Nginx is running.

## FR-17: Container Monitoring

The monitoring system shall verify whether the application container is running.

## FR-18: Endpoint Monitoring

The monitoring system shall verify whether the application health endpoint responds successfully.

## FR-19: Disk Monitoring

The monitoring system shall check disk usage against a documented threshold.

## FR-20: Memory Monitoring

The monitoring system shall collect or evaluate system memory usage.

## FR-21: CPU or Load Monitoring

The monitoring system shall collect or evaluate CPU utilisation or system load.

## FR-22: Backup Freshness Monitoring

The monitoring system shall be able to determine whether a sufficiently recent backup exists.

## FR-23: Monitoring Logs

Monitoring results shall be written to a dedicated SentinelOps log location.

## FR-24: Monitoring Result Format

Monitoring entries shall contain enough information to identify:

- when the check occurred;
- which check was performed;
- whether it passed or failed;
- the severity where appropriate;
- a useful human-readable message.

## FR-25: Operational Logging

The project shall document and use relevant operational logs, including:

- system logs;
- authentication logs;
- Nginx access logs;
- Nginx error logs;
- application logs;
- container logs;
- monitoring logs;
- backup logs.

## FR-26: Backup Creation

The system shall create timestamped backups of selected application data and configuration.

## FR-27: Backup Manifest

Each backup shall have a documented record of the files or data it contains.

## FR-28: Backup Integrity

The system shall generate an integrity checksum for backup archives.

## FR-29: Backup Retention

The backup system shall use a documented retention policy so that backup files do not grow without limit.

## FR-30: Scheduled Backups

Backups shall run automatically using an operating-system scheduling mechanism.

## FR-31: Backup Logging

Backup success and failure shall be recorded.

## FR-32: Backup Restoration

The project shall provide a documented restoration procedure.

## FR-33: Restoration Verification

Restored application data shall be validated after recovery.

## FR-34: Restoration Testing

At least one controlled restoration test shall be completed using synthetic data.

## FR-35: Failure Simulation

The MVP shall include at least three controlled infrastructure or application failure simulations.

## FR-36: Incident Detection

Each selected failure scenario shall demonstrate how the problem is detected.

## FR-37: Incident Diagnosis

Each selected failure scenario shall document the commands, logs, or evidence used to identify the cause.

## FR-38: Incident Recovery

Each selected failure scenario shall include documented recovery steps.

## FR-39: Recovery Verification

Each selected failure scenario shall verify that normal service has been restored.

## FR-40: Incident Prevention

Each failure runbook shall document at least one control or improvement that could reduce recurrence.

## FR-41: Manual Understanding Before Automation

Important infrastructure configuration shall first be understood and verified manually before being converted into automation.

## FR-42: Repeatable Provisioning

The completed project shall provide a documented process for configuring a clean supported Ubuntu Server environment.

## FR-43: Idempotent Automation

Provisioning automation shall eventually be safe to execute more than once without creating duplicate users, duplicate rules, or invalid configuration.

## FR-44: Automation Validation

Automation shall validate important prerequisites before making system changes.

## FR-45: Useful Automation Failures

Automation failures shall return useful output and appropriate exit behaviour.

## FR-46: Continuous Integration

The repository shall use GitHub Actions for automated project validation before the MVP release.

## FR-47: Shell Validation

Shell scripts shall be checked automatically for common errors or quality problems.

## FR-48: Container Validation

Docker-related project files shall be validated automatically where practical.

## FR-49: Application Testing

The CI process shall verify basic application behaviour.

## FR-50: Secret Protection

The repository shall not contain real passwords, private SSH keys, cloud credentials, or sensitive personal data.

---

# Non-Functional Requirements

## NFR-01: Security

The infrastructure shall follow least-privilege principles.

Users, groups, ports, files, services, and containers shall receive no more access than required.

## NFR-02: Minimum Network Exposure

Only required network services shall be exposed.

Internal application services should remain private whenever practical.

## NFR-03: Repeatability

The final deployment process shall be reproducible on a clean supported Ubuntu Server VM.

## NFR-04: Idempotency

Automation shall eventually tolerate repeated execution without damaging a correctly configured environment.

## NFR-05: Recoverability

The application and selected data shall be recoverable using documented procedures.

## NFR-06: Observability

Important infrastructure states and failures shall generate understandable operational evidence.

## NFR-07: Maintainability

Scripts, configuration files, directories, and documentation shall use clear names and focused responsibilities.

## NFR-08: Testability

Each major technical control shall include a documented method for verifying that it works.

## NFR-09: Explainability

The project owner shall be able to explain the purpose and behaviour of every major technology, command, configuration, and recovery procedure used in the project.

## NFR-10: Simplicity

The MVP shall use the minimum architecture and technologies required to demonstrate the target infrastructure skills.

## NFR-11: Portability

The architecture should be suitable for later migration from a local Ubuntu VM to a standard Linux cloud virtual machine.

## NFR-12: Auditability

Infrastructure changes shall be visible through Git history and relevant system logs.

## NFR-13: Safe Failure Testing

Failure simulations shall use synthetic data and documented recovery procedures.

## NFR-14: Documentation Consistency

Documentation shall be updated when implementation decisions change.

## NFR-15: Secret Safety

Secrets and private key material shall remain outside source control.

## NFR-16: Data Safety

Only synthetic application data shall be used in demonstrations and destructive recovery exercises.

## NFR-17: Resource Awareness

The MVP shall remain lightweight enough to operate on a single local Ubuntu virtual machine.

## NFR-18: Failure Visibility

Monitoring results shall be understandable without requiring an advanced external monitoring platform.

## NFR-19: Backup Integrity

A backup shall not be considered valid solely because an archive file exists.

Integrity verification and restoration testing shall be required.

## NFR-20: Professional Presentation

The final repository shall be understandable to a technical reviewer without requiring private project knowledge.

---

# MVP Requirement Priorities

## Must Have

The MVP must include:

- Ubuntu Server;
- user and permission management;
- secure SSH access;
- UFW;
- Nginx;
- Docker;
- Docker Compose;
- application homepage;
- health endpoint;
- application version;
- system and service monitoring;
- operational logging;
- automated backups;
- integrity verification;
- restoration;
- three failure simulations;
- GitHub Actions validation;
- professional documentation.

## Should Have

The MVP should include:

- systemd-based scheduling;
- structured monitoring output;
- backup retention;
- custom maintenance page;
- clear incident runbooks;
- measurable detection and recovery times.

## Could Have

If time permits after all mandatory requirements are complete:

- additional failure scenarios;
- stronger automated security checks;
- improved health reporting;
- more detailed operational evidence.

## Will Not Have in the Initial MVP

The initial MVP will not require:

- Kubernetes;
- Terraform;
- AWS deployment;
- Azure deployment;
- multiple servers;
- Prometheus;
- Grafana;
- Ansible;
- external alert integrations;
- automatic remediation;
- public DNS;
- HTTPS;
- high availability;
- automatic scaling;
- production data.