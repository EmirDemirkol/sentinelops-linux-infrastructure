# SentinelOps Phase 0 Project Charter

## Project Overview

SentinelOps is a Linux infrastructure automation and monitoring lab designed to demonstrate practical skills in Linux administration, networking, infrastructure security, automation, containerisation, monitoring, backup and recovery, incident response, and DevOps operations.

The project simulates a small fictional company environment that needs a Linux server to host and operate an application securely and reliably.

The initial version will use one Ubuntu Server virtual machine running locally on a MacBook.

The project is intentionally infrastructure-focused. The application itself will remain small so that the main emphasis stays on operating systems, networking, services, automation, monitoring, security, and recovery.

## Problem Statement

Small organisations may configure Linux servers manually without consistent security controls, monitoring, backup verification, or repeatable deployment procedures.

This can lead to:

- inconsistent server configuration;
- unnecessary user privileges;
- exposed network services;
- undocumented system changes;
- unreliable deployments;
- limited visibility into failures;
- untested backups;
- slow recovery from incidents.

SentinelOps will address these problems by creating a reproducible Linux infrastructure environment that applies a defined security baseline, hosts a containerised application behind Nginx, monitors system and service health, creates verified backups, supports restoration, and documents controlled failure recovery.

## Project Objectives

### O-01: Linux Administration

Build and operate a functioning Ubuntu Server environment using practical Linux administration skills.

### O-02: Access Control

Apply least-privilege user, group, file, and directory permissions.

### O-03: Secure Remote Access

Configure secure SSH access using key authentication and restricted root access.

### O-04: Network Security

Restrict inbound network access using UFW and expose only required services.

### O-05: Reverse Proxy

Configure Nginx to act as the entry point for application traffic.

### O-06: Containerised Application

Deploy and operate a small application using Docker and Docker Compose.

### O-07: Monitoring

Monitor service state, container health, application availability, and system resources.

### O-08: Logging

Produce useful operational, application, monitoring, backup, and system logs.

### O-09: Backup and Recovery

Create scheduled backups with integrity checks, retention, and a tested restoration procedure.

### O-10: Incident Response

Simulate realistic failures and document detection, diagnosis, recovery, and prevention.

### O-11: Automation

Convert understood manual procedures into repeatable and safe automation.

### O-12: Continuous Validation

Use GitHub Actions to validate scripts and project configuration.

### O-13: Documentation

Produce clear architecture, security, operational, and recovery documentation.

### O-14: Explainability

Ensure every major technology, command, configuration, failure, and recovery action can be explained and demonstrated.

## MVP Scope

The SentinelOps MVP will include:

- one Ubuntu Server virtual machine;
- private virtual networking;
- named administrator access;
- dedicated application or deployment ownership;
- Linux users and groups;
- file and directory permissions;
- SSH key authentication;
- restricted root SSH access;
- UFW firewall configuration;
- Nginx reverse proxy;
- Docker;
- Docker Compose;
- small application homepage;
- `/health` endpoint;
- application version information;
- container restart policy;
- monitoring of service and resource health;
- dedicated operational logs;
- automated backups;
- backup retention;
- backup integrity verification;
- tested restoration procedure;
- at least three controlled failure simulations;
- GitHub Actions validation;
- architecture documentation;
- network documentation;
- threat model;
- security baseline;
- incident runbooks;
- screenshots;
- short demonstration video.

## Out of Scope for the MVP

The following technologies and capabilities are deliberately excluded from the initial MVP:

- Kubernetes;
- Terraform;
- multi-cloud architecture;
- AWS production deployment;
- Azure production deployment;
- multiple application servers;
- high availability;
- load balancing across several servers;
- automatic scaling;
- zero-downtime deployment;
- enterprise identity providers;
- complex production databases;
- real customer information;
- real company data;
- payment systems;
- production authentication systems;
- centralised SIEM;
- full vulnerability-management platforms;
- automatic incident remediation;
- Prometheus;
- Grafana;
- Ansible;
- public DNS;
- TLS certificates;
- Slack alerts;
- email alerts.

These may be considered only after the local MVP is complete, tested, documented, and reproducible.

## Assumptions

The project assumes that:

- the MacBook can run a supported Ubuntu virtual machine;
- the local environment has enough CPU, memory, and disk space for one VM;
- the project will use synthetic application data only;
- the Ubuntu VM will have internet access when packages or container images need to be downloaded;
- GitHub will be used for source control and issue tracking;
- the application will remain intentionally small;
- the local environment is sufficient for the MVP;
- cloud infrastructure is not required to prove the initial learning objectives;
- important infrastructure will be configured manually before being automated;
- the project owner will have console access to the VM during SSH hardening.

## Constraints

The project will operate under the following constraints:

- the MVP must remain a one-server architecture;
- infrastructure implementation must not begin before the required Phase 0 planning work is complete;
- no real passwords, private SSH keys, cloud credentials, or sensitive personal information may be committed;
- unnecessary technologies must not be added for portfolio appearance;
- every important infrastructure change must include a verification step;
- destructive testing must use synthetic data;
- backup creation does not count as complete until restoration succeeds;
- automation must fail safely and provide useful output;
- scripts should eventually be safe to run more than once;
- GitHub Issues should be used for meaningful units of project work;
- documentation must remain consistent with the implementation.

## Stakeholders

### Project Owner and Infrastructure Engineer

Responsibilities:

- build and configure the environment;
- maintain server services;
- troubleshoot failures;
- manage access;
- review monitoring information;
- perform backup and recovery;
- maintain documentation.

Primary concern:

- genuine understanding of the complete system.

### Application Developer

Responsibilities:

- provide the small application;
- maintain the health endpoint;
- expose application version information;
- review application logs;
- support deployment testing.

Primary concern:

- stable and understandable application deployment.

### Security Reviewer

Responsibilities:

- review users and groups;
- review permissions;
- review SSH configuration;
- review firewall configuration;
- review secret handling;
- review threat model and security controls.

Primary concern:

- preventing unnecessary privilege and exposure.

### Operations Manager

Responsibilities:

- review system availability;
- review incident evidence;
- review backup and recovery procedures;
- review operational risks.

Primary concern:

- reliability and recoverability.

### End User

Responsibilities:

- access the hosted application through the approved interface.

Primary concern:

- application availability.

### Technical Reviewer or Recruiter

Responsibilities:

- review the repository;
- inspect documentation;
- review evidence;
- assess technical decisions;
- review demonstration material.

Primary concern:

- whether the project demonstrates genuine practical infrastructure capability.

## Development Principles

Every major infrastructure change should answer:

1. What problem does this solve?
2. Why is this technology being used?
3. What exactly is being changed?
4. How will the change be verified?
5. What could fail?
6. How can the change be reversed?
7. How would the same problem be handled in a real organisation?

Additional principles:

- understand manually before automating;
- prefer simplicity over unnecessary complexity;
- use least privilege;
- minimise network exposure;
- treat recovery as a core capability;
- test failure scenarios deliberately;
- keep documentation current;
- use small, meaningful Git commits;
- use GitHub Issues to track project work;
- do not claim knowledge that cannot be demonstrated.

## MVP Definition

The MVP is complete when SentinelOps can demonstrate the following workflow:

1. Start from a clean supported Ubuntu Server VM.
2. Configure users, permissions, SSH, and firewall controls.
3. Install and configure Nginx.
4. Deploy a containerised application.
5. Access the application through Nginx.
6. Confirm the application health endpoint works.
7. Run operational monitoring.
8. Detect a controlled service failure.
9. Investigate relevant logs.
10. Recover the failed service.
11. Create a verified backup.
12. Delete or modify synthetic test data.
13. Restore the data successfully.
14. Complete at least three documented failure simulations.
15. Validate the repository through CI.
16. Reproduce the environment using the final documentation and automation.

## Success Criteria

The project will be considered successful when:

- the application returns HTTP 200 through Nginx;
- the `/health` endpoint reports valid health and version information;
- the application container port is not exposed externally;
- only approved inbound firewall ports are accessible;
- root cannot be used for normal remote login;
- ordinary users cannot modify protected configuration;
- a stopped application container is detected by monitoring;
- the application can be recovered after a controlled failure;
- invalid Nginx configuration can be detected before an unsafe reload;
- a timestamped backup is created;
- backup integrity can be verified;
- deleted synthetic data can be successfully restored;
- at least three controlled incidents are completed and documented;
- automation can eventually be run more than once safely;
- a clean Ubuntu VM can be rebuilt using the final process;
- required GitHub Actions checks pass;
- the repository contains no real credentials or private keys;
- every major feature includes a documented verification method;
- the final README clearly explains the project;
- a short demonstration shows deployment, monitoring, failure detection, recovery, and restoration.

## Phased Development Roadmap

### Phase 0: Discovery and Planning

Define:

- project charter;
- requirements;
- architecture;
- networking;
- threat model;
- security baseline;
- risks;
- MVP;
- success criteria;
- GitHub Issues;
- implementation roadmap.

### Phase 1: Manual Linux Foundation

Learn and configure:

- Ubuntu Server;
- filesystem;
- users and groups;
- permissions;
- processes;
- packages;
- services;
- logs;
- environment variables;
- SSH;
- networking;
- UFW.

### Phase 2: Application Platform

Implement:

- Docker;
- Docker Compose;
- small application;
- `/health` endpoint;
- Nginx;
- reverse proxying;
- application and service logging.

### Phase 3: Provisioning Automation

Convert understood manual configuration into repeatable Bash automation.

Automation will cover:

- package installation;
- user configuration;
- SSH configuration;
- firewall configuration;
- Nginx configuration;
- application deployment;
- validation.

### Phase 4: Monitoring and Logging

Implement monitoring for:

- Nginx;
- Docker;
- application health;
- disk usage;
- memory;
- CPU load;
- backup freshness.

### Phase 5: Backup and Recovery

Implement:

- scheduled backups;
- timestamps;
- manifests;
- checksums;
- retention;
- restoration;
- recovery testing.

### Phase 6: Failure Simulation and Incident Response

Test failures including:

- stopped application container;
- broken Nginx configuration;
- disk usage threshold;
- failed deployment;
- deleted application data.

Document detection, diagnosis, recovery, validation, and prevention.

### Phase 7: CI and MVP Release

Implement:

- GitHub Actions;
- script validation;
- Docker validation;
- application testing;
- secret checks;
- final documentation;
- screenshots;
- demonstration video;
- clean rebuild test.

### Phase 8: Post-MVP Enhancements

Possible future improvements:

- Ansible;
- Prometheus;
- Node Exporter;
- Grafana;
- AWS EC2;
- IAM;
- Security Groups;
- CloudWatch;
- HTTPS;
- public DNS;
- external alerting;
- separate monitoring server;
- Terraform after the cloud architecture is understood.

## Phase 0 Exit Condition

Phase 0 is complete when:

- the project problem is clearly defined;
- objectives are measurable;
- MVP scope is frozen;
- exclusions are explicit;
- assumptions and constraints are documented;
- stakeholders are identified;
- architecture is documented;
- network exposure is documented;
- the initial threat model is complete;
- risks are documented;
- success criteria are measurable;
- the roadmap is agreed;
- the required GitHub Issues exist;
- no infrastructure implementation has started prematurely.