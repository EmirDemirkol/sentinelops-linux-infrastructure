# SentinelOps Phase 0 Success Criteria

## Purpose

This document defines the measurable conditions that determine whether the SentinelOps MVP has been completed successfully.

The success criteria are designed to prevent vague claims such as "the server works" or "monitoring is configured."

Each major project capability must be demonstrated through observable behaviour, verification output, recovery evidence, or documented testing.

---

# Core Success Criteria

## SC-01: Application Availability Through Nginx

The application shall be accessible through Nginx using the approved HTTP endpoint.

Success condition:

- the application returns HTTP status `200`;
- the response is served through Nginx rather than through direct container access.

---

## SC-02: Health Endpoint

The application shall provide a working `/health` endpoint.

Success condition:

- the endpoint returns HTTP status `200`;
- the response indicates that the application is healthy;
- the response includes application version information.

---

## SC-03: Private Application Port

The application container port shall not be directly reachable from outside the Ubuntu VM.

Success condition:

- Nginx can reach the application internally;
- the host MacBook cannot directly access the application container port;
- external application requests must pass through Nginx.

---

## SC-04: Firewall Enforcement

The Ubuntu server shall use a deny-by-default inbound firewall policy.

Success condition:

- UFW is enabled;
- only explicitly required inbound ports are allowed;
- unnecessary inbound ports remain blocked;
- firewall rules remain active after reboot.

---

## SC-05: Secure SSH Authentication

Remote administration shall use SSH key authentication.

Success condition:

- the authorised administrator can connect using the expected SSH key;
- password authentication is disabled only after key authentication is confirmed;
- normal administration does not require direct root login.

---

## SC-06: Root SSH Restriction

Direct root SSH access shall be disabled or otherwise restricted.

Success condition:

- an attempted normal remote login as root is rejected;
- administrative actions are performed through a named account using controlled privilege escalation.

---

## SC-07: Least-Privilege File Access

Protected infrastructure configuration shall not be modifiable by ordinary users.

Success condition:

- protected configuration ownership is correct;
- permissions restrict unauthorised modification;
- an unprivileged user cannot modify protected configuration files.

---

## SC-08: Nginx Configuration Validation

Nginx configuration shall be validated before reload or restart.

Success condition:

- valid configuration passes the Nginx configuration test;
- intentionally invalid configuration is detected;
- invalid configuration is not applied blindly.

---

## SC-09: Container Deployment

The application shall run successfully through Docker and Docker Compose.

Success condition:

- the application image builds successfully;
- the application container starts;
- Docker Compose reports the expected service state;
- the application remains reachable through Nginx.

---

## SC-10: Container Restart Behaviour

The application container shall use a defined restart policy.

Success condition:

- the restart policy is documented;
- the behaviour is tested during a controlled container stop or service restart;
- the observed behaviour matches the intended configuration.

---

## SC-11: Nginx Monitoring

The monitoring system shall detect whether Nginx is running.

Success condition:

- a healthy Nginx service produces a healthy monitoring result;
- a controlled Nginx failure produces a failure result.

---

## SC-12: Container Monitoring

The monitoring system shall detect whether the application container is running.

Success condition:

- a running container produces a healthy monitoring result;
- a deliberately stopped container is detected.

---

## SC-13: Endpoint Monitoring

The monitoring system shall verify application availability through the health endpoint.

Success condition:

- a healthy endpoint produces a successful result;
- an unavailable or failing endpoint produces a failure result.

---

## SC-14: Resource Monitoring

The monitoring system shall evaluate important server resources.

Success condition:

- disk usage is checked;
- memory usage is checked;
- CPU utilisation or system load is checked;
- results are written to SentinelOps monitoring logs.

---

## SC-15: Failure Detection Time

A selected service failure shall be detected within two monitoring intervals.

Target:

- if monitoring runs once per minute, the failure should be detected within two minutes.

This is an educational target rather than a production service-level agreement.

---

## SC-16: Dedicated Monitoring Logs

Monitoring results shall be recorded in a dedicated SentinelOps log location.

Success condition:

- monitoring output is timestamped;
- each result identifies the check performed;
- success or failure is clear;
- warning or severity information is included where appropriate.

---

## SC-17: Operational Log Awareness

The project shall demonstrate the ability to locate and interpret relevant operational logs.

Success condition:

The project owner can identify and use:

- system logs;
- authentication logs;
- Nginx access logs;
- Nginx error logs;
- application logs;
- Docker container logs;
- monitoring logs;
- backup logs.

---

# Backup and Recovery Success Criteria

## SC-18: Automated Backup Creation

The system shall create backups automatically.

Success condition:

- a scheduled mechanism runs the backup process;
- a timestamped backup archive is created;
- backup success or failure is logged.

---

## SC-19: Backup Manifest

Each backup shall have a clear record of its intended contents.

Success condition:

- the backup process produces or preserves a manifest;
- the operator can determine what data and configuration are contained in the backup.

---

## SC-20: Backup Integrity Verification

Backup integrity shall be verifiable.

Success condition:

- a checksum is generated for the backup;
- the checksum can later be validated;
- a deliberately modified test backup fails the integrity check.

---

## SC-21: Backup Retention

Backups shall not grow without limit.

Success condition:

- a retention policy is documented;
- expired test backups are removed according to that policy;
- recent valid backups remain available.

---

## SC-22: Successful Restoration

Synthetic application data shall be recoverable from backup.

Success condition:

1. create identifiable synthetic test data;
2. create a valid backup;
3. delete or modify the test data;
4. verify the data is missing or damaged;
5. restore from backup;
6. verify that the original data has been recovered.

---

## SC-23: Restoration Integrity

Restoration shall preserve expected ownership, permissions, and application functionality.

Success condition:

- restored files have the required ownership;
- restored files have the required permissions;
- the application remains operational after restoration.

---

## SC-24: Recovery Time Objective

The project shall demonstrate a target recovery time for application data restoration.

Educational target:

- restore the selected synthetic application data within 15 minutes.

This target is used to measure the recovery exercise and is not a production guarantee.

---

## SC-25: Recovery Point Objective

The project shall define an educational recovery point objective.

Target:

- no more than 24 hours of synthetic application data should be lost under the planned backup schedule.

This target may be improved later if the backup frequency changes.

---

# Incident Response Success Criteria

## SC-26: Minimum Failure Simulations

The MVP shall complete at least three controlled failure simulations.

Eligible scenarios include:

- stopped application container;
- invalid Nginx configuration;
- disk usage warning;
- failed application deployment;
- synthetic data loss and restoration.

---

## SC-27: Incident Detection

Each selected failure scenario shall demonstrate how the problem was detected.

Success condition:

- the symptom is documented;
- relevant monitoring output or logs are captured.

---

## SC-28: Incident Diagnosis

Each selected failure scenario shall demonstrate diagnosis.

Success condition:

- relevant commands or logs are identified;
- the root cause is explained;
- evidence supporting the diagnosis is recorded.

---

## SC-29: Incident Recovery

Each selected failure scenario shall include successful recovery.

Success condition:

- recovery actions are documented;
- normal service is restored;
- post-recovery validation is completed.

---

## SC-30: Incident Prevention

Each completed incident runbook shall include at least one recommendation that could reduce the likelihood or impact of recurrence.

---

## SC-31: Application Recovery Time

A controlled application container failure should be recoverable within five minutes.

This is an educational operational target.

---

# Automation Success Criteria

## SC-32: Manual Understanding Before Automation

Important infrastructure actions shall first be understood and verified manually.

Success condition:

- the project documentation explains the manual process;
- the project owner can explain what the later automation is changing.

---

## SC-33: Repeatable Provisioning

The final provisioning process shall successfully configure a clean supported Ubuntu Server environment.

Success condition:

- the process can be followed from a clean VM;
- required services and configuration are created successfully;
- hidden manual steps are not required.

---

## SC-34: Idempotent Automation

Provisioning automation shall be safe to execute more than once.

Success condition:

A second execution does not:

- create duplicate users;
- create duplicate firewall rules;
- repeatedly append configuration;
- damage working services;
- produce invalid system state.

---

## SC-35: Automation Validation

Automation shall validate important prerequisites and configuration.

Success condition:

- missing dependencies generate understandable failures;
- invalid configuration is detected where practical;
- scripts return useful exit behaviour.

---

# CI and Repository Success Criteria

## SC-36: GitHub Actions Validation

The repository shall contain a GitHub Actions workflow before MVP release.

Success condition:

- the workflow runs automatically on the configured Git events;
- required checks complete successfully on the default branch.

---

## SC-37: Shell Script Validation

Shell automation shall receive automated static validation.

Success condition:

- a suitable shell validation tool is included in CI;
- identified problems are reviewed before the final MVP release.

---

## SC-38: Container Configuration Validation

Docker-related project files shall be validated automatically where practical.

Success condition:

- the container build succeeds;
- Docker Compose configuration can be parsed successfully;
- invalid container configuration causes CI failure where applicable.

---

## SC-39: Application Test

The CI process shall validate basic application behaviour.

Success condition:

- the application test verifies expected behaviour;
- health endpoint behaviour is included where practical.

---

## SC-40: Secret-Free Repository

The repository shall contain no real credentials or private key material.

Success condition:

The repository contains no:

- private SSH keys;
- real passwords;
- GitHub tokens;
- cloud access keys;
- confidential employer information;
- sensitive personal data.

---

# Documentation and Reproducibility Success Criteria

## SC-41: Professional README

The README shall allow a technical reviewer to understand:

- the problem SentinelOps solves;
- the project objectives;
- the architecture;
- the core technologies;
- the security principles;
- the development phases;
- the current project status.

---

## SC-42: Architecture Documentation

The project shall include current architecture and network documentation.

Success condition:

- the logical architecture is documented;
- network exposure is documented;
- relevant ports are documented;
- trust boundaries and major data flows are understandable.

---

## SC-43: Security Documentation

The project shall include:

- an initial threat model;
- a documented security baseline;
- access-control documentation;
- secret-handling rules.

---

## SC-44: Recovery Documentation

The project shall include:

- backup procedure;
- restoration procedure;
- recovery evidence;
- incident runbooks.

---

## SC-45: Clean Rebuild Test

Before MVP release, the environment shall be rebuilt from a clean supported Ubuntu Server VM.

Success condition:

- the repository and documentation provide enough information to reproduce the environment;
- the rebuild does not rely on undocumented manual configuration.

---

## SC-46: Demonstration Evidence

The final project shall contain professional evidence of the working environment.

Success condition:

- useful screenshots are organised;
- failure simulation evidence is included;
- restoration evidence is included;
- a short demonstration video is recorded.

---

## SC-47: Technical Explainability

The project owner shall be able to explain:

- why each major technology is used;
- what each major service does;
- how traffic reaches the application;
- how access is controlled;
- how monitoring works;
- how backups work;
- how restoration works;
- how failures are diagnosed;
- what major security risks exist.

A feature that cannot be explained should not be presented as genuine project knowledge.

---

# MVP Completion Gate

The SentinelOps MVP shall not be considered complete until all mandatory success criteria are either:

- verified successfully; or
- explicitly documented as deferred with a justified reason.

Mandatory MVP areas are:

1. Linux administration;
2. secure access;
3. firewall protection;
4. Nginx reverse proxy;
5. Docker application deployment;
6. health endpoint;
7. monitoring;
8. operational logging;
9. automated backup;
10. backup integrity;
11. successful restoration;
12. controlled failure simulations;
13. repeatable automation;
14. CI validation;
15. security documentation;
16. architecture documentation;
17. clean rebuild;
18. professional project evidence.

Post-MVP enhancements such as AWS, Ansible, Prometheus, Grafana, Terraform, and Kubernetes are not required to satisfy the MVP completion gate.