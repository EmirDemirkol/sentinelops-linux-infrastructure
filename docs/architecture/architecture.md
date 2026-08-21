# SentinelOps Architecture Overview

## Purpose

This document defines the initial logical architecture for SentinelOps.

The architecture is intentionally simple and uses a single Ubuntu Server virtual machine for the MVP.

The purpose of the design is to demonstrate practical Linux infrastructure administration, networking, security, containerisation, monitoring, backup, recovery, and incident response without adding unnecessary distributed-system complexity.

No infrastructure implementation is performed as part of this document.

---

# Architecture Goals

The SentinelOps architecture should:

- remain simple enough to understand fully
- support secure administration
- minimise externally exposed services
- provide a clear reverse-proxy boundary
- support a containerised application
- provide monitoring and logging
- support automated backup and restoration
- allow controlled failure simulations
- remain suitable for later migration to a cloud virtual machine
- avoid technologies that are not required for the MVP

---

# MVP Architecture Decision

The SentinelOps MVP will use one Ubuntu Server virtual machine running locally on the MacBook.

The Ubuntu VM will contain:

- SSH service
- UFW firewall
- Nginx
- Docker Engine
- Docker Compose
- the SentinelOps application container
- monitoring processes
- operational logs
- backup processes
- backup storage
- systemd services and timers where required

The MacBook will act as:

- the physical host
- the virtualisation host
- the administrator workstation
- the local browser client
- the Git development environment

---

# Logical Architecture

```text
                         MACBOOK HOST
                    +----------------------+
                    |                      |
                    | Terminal             |
                    | Browser              |
                    | Git                  |
                    | GitHub access        |
                    | Virtualisation       |
                    |                      |
                    +----------+-----------+
                               |
                               | Private virtual network
                               |
                               v
              +--------------------------------------+
              |         UBUNTU SERVER VM             |
              |                                      |
              |  +--------------------------------+  |
              |  | SSH                            |  |
              |  +--------------------------------+  |
              |                                      |
              |  +--------------------------------+  |
              |  | UFW Firewall                   |  |
              |  +---------------+----------------+  |
              |                  |                   |
              |                  v                   |
              |  +--------------------------------+  |
              |  | Nginx Reverse Proxy            |  |
              |  +---------------+----------------+  |
              |                  |                   |
              |                  | localhost/internal|
              |                  v                   |
              |  +--------------------------------+  |
              |  | Docker Application             |  |
              |  | Homepage                       |  |
              |  | /health endpoint               |  |
              |  | Version information            |  |
              |  +--------------------------------+  |
              |                                      |
              |  +--------------------------------+  |
              |  | Monitoring                     |  |
              |  | Health checks                  |  |
              |  | Resource checks                |  |
              |  +---------------+----------------+  |
              |                  |                   |
              |                  v                   |
              |  +--------------------------------+  |
              |  | SentinelOps Logs               |  |
              |  +--------------------------------+  |
              |                                      |
              |  +--------------------------------+  |
              |  | Backup Process                 |  |
              |  +---------------+----------------+  |
              |                  |                   |
              |                  v                   |
              |  +--------------------------------+  |
              |  | Backup Storage                 |  |
              |  +--------------------------------+  |
              |                                      |
              +--------------------------------------+
```

# Component Responsibilities

## MacBook Host

The MacBook provides the physical environment in which the SentinelOps lab operates.

Responsibilities:

- run the virtualisation platform
- host the Ubuntu Server VM
- provide Terminal access
- provide the administrator SSH client
- provide the local browser used to access the application
- maintain the local Git repository
- communicate with GitHub
- provide VM console access if SSH recovery is required

The MacBook is not part of the fictional server workload itself.

---

## Ubuntu Server VM

The Ubuntu Server VM is the main SentinelOps infrastructure environment.

Responsibilities:

- provide the Linux operating system
- host SSH
- enforce firewall rules
- host Nginx
- run Docker
- run the application container
- run monitoring
- store operational logs
- run scheduled backup processes
- store local backup archives
- provide the environment for failure simulations and recovery exercises

The VM represents the fictional organisation's server.

---

## SSH

SSH provides remote administrative access from the MacBook to the Ubuntu VM.

Responsibilities:

- authenticate the administrator
- provide secure command-line access
- support key-based authentication
- record authentication activity through system logging

SSH is an administration interface, not an application interface.

---

## UFW Firewall

UFW controls inbound network traffic to the Ubuntu VM.

Responsibilities:

- deny unsolicited inbound traffic by default
- allow SSH through the approved administration path
- allow HTTP through Nginx
- later allow HTTPS if added
- block unnecessary inbound services

UFW reduces the server's externally reachable attack surface.

---

## Nginx Reverse Proxy

Nginx is the application-facing entry point.

Responsibilities:

- listen for approved HTTP requests
- receive client traffic
- proxy requests to the internal application service
- provide access and error logs
- provide a clear separation between external traffic and the application container

Nginx runs directly on the Ubuntu host.

---

## Docker Engine

Docker provides the container runtime for the SentinelOps application.

Responsibilities:

- isolate the application runtime from the host environment
- run the application image
- expose the application only to the required internal interface
- provide container lifecycle management
- provide container logs
- support restart behaviour

Docker access is considered privileged.

---

## Docker Compose

Docker Compose provides the declarative application service definition.

Responsibilities:

- define the application service
- define required environment variables
- define port bindings
- define restart behaviour
- allow the application environment to be started and stopped consistently

---

## SentinelOps Application

The application remains intentionally small.

Responsibilities:

- provide a homepage
- provide a `/health` endpoint
- expose application version information
- generate useful application logs
- provide synthetic data suitable for backup and recovery exercises

The application is not the main focus of SentinelOps.

---

## Monitoring Process

The monitoring component checks the operational state of the system.

Planned checks include:

- Nginx service status
- Docker container status
- application health endpoint
- disk usage
- memory usage
- CPU load or system load
- backup freshness

Monitoring results will initially be written to local logs.

---

## SentinelOps Logs

The project will use operational logs to support monitoring, troubleshooting, and incident response.

Relevant logs include:

- system logs
- authentication logs
- Nginx access logs
- Nginx error logs
- Docker container logs
- application logs
- monitoring logs
- backup logs

A dedicated SentinelOps log location will be used for custom monitoring and operational output.

---

## Backup Process

The backup component creates recoverable copies of selected data and configuration.

Responsibilities:

- collect selected files or data
- create timestamped archives
- create a backup manifest
- generate integrity checksums
- apply retention rules
- log success or failure

---

## Backup Storage

For the MVP, backup archives will remain inside the local lab environment.

This is acceptable because the MVP is intended to prove:

- backup creation
- retention
- integrity checking
- restoration
- recovery procedures

Remote or cloud backup storage may be added after the local process is proven.

---

# Administrative Access Flow

```text
MacBook Terminal
      |
      | SSH key authentication
      v
Private Virtual Network
      |
      v
Ubuntu Server VM
      |
      v
Named Administrator Account
      |
      | controlled sudo
      v
Privileged System Operations
```

The administrator should not use the root account for normal daily operations.

---

# Application Request Flow

```text
MacBook Browser
      |
      | HTTP
      v
Ubuntu VM Network Interface
      |
      v
UFW
      |
      | approved port 80
      v
Nginx
      |
      | internal/local connection
      v
Docker Application
      |
      v
Application Response
      |
      v
Nginx
      |
      v
Browser
```

The application container must not be directly exposed externally.

---

# Monitoring Flow

```text
Scheduled Monitoring Process
          |
          +--> Nginx status
          |
          +--> Docker container state
          |
          +--> /health endpoint
          |
          +--> Disk usage
          |
          +--> Memory usage
          |
          +--> CPU or system load
          |
          +--> Backup freshness
          |
          v
SentinelOps Monitoring Logs
```

The initial monitoring design deliberately avoids Prometheus and Grafana.

The goal is to understand the underlying checks before introducing a larger monitoring platform.

---

# Backup Flow

```text
Scheduled Backup Process
          |
          v
Selected Configuration and Application Data
          |
          v
Timestamped Archive
          |
          +--> Backup Manifest
          |
          +--> Integrity Checksum
          |
          v
Local Backup Storage
          |
          v
Backup Result Log
```

---

# Restoration Flow

```text
Administrator
      |
      v
Select Backup
      |
      v
Verify Checksum
      |
      v
Extract to Safe Temporary Location
      |
      v
Review Backup Contents
      |
      v
Restore Required Data or Configuration
      |
      v
Correct Ownership and Permissions
      |
      v
Restart or Reload Required Service
      |
      v
Verify Application and Health Endpoint
```

Restoration must be tested using synthetic data.

---

# Trust Boundaries

## TB-01: MacBook to Ubuntu VM

This boundary separates the administrator workstation from the server environment.

Primary concerns:

- SSH authentication
- stolen or misused credentials
- incorrect virtual network exposure
- administrator access control

---

## TB-02: Network to UFW

This boundary separates inbound traffic from services running on the Ubuntu VM.

Primary concerns:

- unnecessary exposed ports
- unauthorised service access
- firewall misconfiguration

---

## TB-03: UFW and Nginx to Application

This boundary separates externally reachable application traffic from the internal container service.

Primary concerns:

- bypassing Nginx
- direct application port exposure
- reverse-proxy misconfiguration

---

## TB-04: Administrator to Privileged Operations

This boundary separates an ordinary administrator shell from root-level system operations.

Primary concerns:

- excessive sudo privileges
- destructive commands
- privilege escalation
- accidental system modification

---

## TB-05: Docker Container to Host

This boundary separates the application container from the Ubuntu host.

Primary concerns:

- privileged containers
- unsafe filesystem mounts
- Docker socket exposure
- container escape risk
- excessive Docker group access

---

## TB-06: Services to Logs and Backup Storage

This boundary protects operational evidence and recoverable data.

Primary concerns:

- unauthorised modification
- deletion
- information disclosure
- disk exhaustion

---

## TB-07: GitHub Repository to Runtime Environment

This boundary separates source-controlled project files from the running infrastructure.

Primary concerns:

- committed secrets
- unsafe configuration changes
- malicious dependencies
- unreviewed automation

---

# Architecture Assumptions

The initial architecture assumes:

- one Ubuntu Server VM is sufficient for the MVP
- the VM uses a private virtual network
- the MacBook can reach the VM for administration and testing
- only synthetic application data is used
- public internet exposure is not required for the MVP
- the application can operate on a single internal port
- local monitoring is sufficient initially
- local backup storage is sufficient to prove backup and restoration behaviour
- the environment can later be recreated on a standard Linux cloud VM

---

# Architecture Constraints

The architecture is constrained by the following rules:

- the MVP remains a single-server environment
- the application must not bypass Nginx
- unnecessary inbound ports must remain blocked
- infrastructure complexity must remain justified
- no production data is allowed
- no cloud infrastructure is required for MVP completion
- no multi-server monitoring architecture is required
- no high-availability claim will be made
- no architecture component should be added only for portfolio appearance

---

# Architecture Decisions

## ADR-001: Single-Server MVP

**Decision:**
Use one Ubuntu Server VM for the MVP.

**Reason:**

- lower complexity
- easier troubleshooting
- sufficient for the learning objectives
- supports the complete operational lifecycle
- reduces unnecessary distributed-system problems

**Consequence:**
The MVP does not demonstrate high availability or multi-server fault tolerance.

---

## ADR-002: Nginx Runs on the Host

**Decision:**
Run Nginx directly on Ubuntu while the application runs inside Docker.

**Reason:**

- demonstrates native Linux service management
- demonstrates container operations
- provides a clear reverse-proxy boundary

**Consequence:**
Host service configuration and application container configuration must be managed separately.

---

## ADR-003: Application Port Remains Private

**Decision:**
Do not expose the application container port directly outside the VM.

**Reason:**

- reduces network exposure
- prevents bypassing Nginx
- creates one controlled application entry point

**Consequence:**
All external application requests must flow through Nginx.

---

## ADR-004: Local Monitoring First

**Decision:**
Use understandable local monitoring before adding Prometheus or Grafana.

**Reason:**

- allows the health-check logic to be understood
- avoids introducing unnecessary infrastructure early
- makes failure detection transparent

**Consequence:**
Advanced dashboards and external alerting are deferred.

---

## ADR-005: Local Backup Storage for MVP

**Decision:**
Store MVP backups within the local lab environment.

**Reason:**

- proves backup logic and restoration without cloud dependencies
- keeps the learning focus on backup correctness

**Consequence:**
The MVP does not claim protection against total loss of the local VM or host machine.

Remote backup storage may be added after the local recovery workflow is proven.

---

# Future Architecture Evolution

After the MVP is complete, possible architecture enhancements include:

- separate monitoring server
- Prometheus
- Node Exporter
- Grafana
- external alerting
- remote backup storage
- HTTPS
- public DNS
- AWS EC2
- IAM
- Security Groups
- CloudWatch
- Ansible
- Terraform after cloud architecture is understood

These are not required for the initial architecture.