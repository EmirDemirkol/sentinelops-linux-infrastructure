# SentinelOps Network Design

## Purpose

This document defines the initial network design for the SentinelOps MVP.

The network design describes:

- how the MacBook communicates with the Ubuntu Server VM
- which services are reachable
- which ports are exposed
- which ports remain private
- how application traffic flows
- how administrative traffic flows
- how network exposure is minimised

No network configuration is performed as part of this document.

---

# Network Design Goals

The network design should:

- minimise exposed services
- keep administration separate from application access
- prevent direct access to the application container
- provide a clear path through UFW and Nginx
- support local testing from the MacBook
- remain simple enough to troubleshoot
- remain suitable for later migration to a cloud VM
- follow least-exposure principles

---

# Network Topology

The MVP will use a local virtual network between the MacBook and the Ubuntu Server VM.

```text
+---------------------------+
| MacBook Host              |
|                           |
| Terminal                  |
| Browser                   |
| Git                       |
+-------------+-------------+
              |
              | Private virtual network
              |
              v
+---------------------------+
| Ubuntu Server VM          |
|                           |
| SSH                       |
| UFW                       |
| Nginx                     |
| Docker                    |
| Application container     |
+---------------------------+
```

The VM will not require public internet exposure for normal application access.

Internet access may still be used by the VM for:

- package installation
- operating-system updates
- downloading trusted container images
- downloading required dependencies

---

# Administrative Network Path

Administrative access will originate from the MacBook.

```text
MacBook Terminal
      |
      | TCP 22
      | SSH key authentication
      v
Ubuntu VM
      |
      v
Named Administrator Account
```

The SSH service is intended for administration only.

Direct root SSH login will not be used for normal administration.

---

# Application Network Path

Application requests will originate from the browser on the MacBook.

```text
MacBook Browser
      |
      | TCP 80
      v
Ubuntu VM
      |
      v
UFW
      |
      v
Nginx
      |
      | localhost/internal connection
      v
Docker Application
```

The Docker application must not be directly reachable from the MacBook.

All normal application traffic must pass through Nginx.

---

# Planned Port Exposure

| Port | Protocol | Service | Exposure | Purpose |
| --- | --- | --- | --- | --- |
| 22 | TCP | SSH | Trusted administration path | Remote server administration |
| 80 | TCP | Nginx HTTP | Host/test network | Application access |
| 443 | TCP | Nginx HTTPS | Not required for initial MVP | Possible later HTTPS |
| 8000 | TCP | Application | Localhost/internal only | Nginx to application |
| Other inbound ports | Any | None | Blocked | Reduce attack surface |

The exact application port may change during implementation.

If it changes, the principle remains the same:

**the application service must remain private and must not be exposed directly outside the Ubuntu VM.**

---

# Firewall Design

UFW will provide the host firewall.

The planned inbound policy is:

```text
Default incoming: deny
Default outgoing: allow
```

Approved inbound traffic for the MVP:

```text
22/TCP   SSH
80/TCP   HTTP
```

Possible later traffic:

```text
443/TCP  HTTPS
```

All other inbound traffic should remain blocked unless a documented requirement is introduced.

---

# Firewall Principles

The firewall design follows these rules:

1. deny inbound traffic by default
2. allow only required services
3. verify SSH access before enabling restrictive firewall changes
4. do not expose the Docker application port externally
5. review listening sockets separately from firewall rules
6. verify firewall persistence after reboot
7. document every new inbound rule

A service listening on a port and a firewall allowing that port are separate concerns.

Both must be checked.

---

# Application Port Design

The initial application is expected to run on an internal port such as:

```text
127.0.0.1:8000
```

Nginx will proxy application requests to that internal service.

Example logical flow:

```text
Browser
  |
  | TCP 80
  v
Nginx
  |
  | localhost:8000
  v
Application
```

The application should bind only to a local or otherwise non-public interface where practical.

---

# Why the Application Port Is Private

The application port remains private because direct exposure would:

- bypass Nginx
- increase attack surface
- create multiple application entry points
- weaken network control
- make the architecture harder to reason about
- allow clients to avoid reverse-proxy behaviour

Nginx should remain the single approved application-facing entry point.

---

# SSH Exposure

SSH should only be reachable through the trusted administration path.

For the local MVP, this means the MacBook should be able to reach TCP port 22 on the Ubuntu VM.

The design should not require SSH to be exposed publicly to the internet.

Later cloud deployment would require a separate security review.

---

# HTTP Exposure

HTTP access will initially be available from the MacBook to the Ubuntu VM.

The purpose is to allow the hosted application to be tested through Nginx.

The MVP does not require a public domain or public internet accessibility.

---

# HTTPS

HTTPS is not mandatory for the initial local MVP.

Possible post-MVP work may include:

- TLS certificate configuration
- HTTPS on TCP port 443
- HTTP-to-HTTPS redirect
- public DNS
- certificate renewal

These are deliberately deferred until the local HTTP architecture is complete and understood.

---

# Docker Networking

Docker will provide internal container networking.

For the initial single-application design, networking should remain simple.

The application container will:

- run on the Ubuntu VM
- expose its application service only as required internally
- communicate with Nginx through the host or approved Docker networking path
- avoid unnecessary published ports

Docker networking must not introduce externally reachable services that bypass UFW or Nginx.

---

# Listening Socket Validation

During implementation, listening services should be inspected using appropriate Linux tools.

The final expected design should show:

- SSH listening on the required administrative interface
- Nginx listening on the required HTTP interface
- the application listening only internally
- no unexplained network services

Any unexpected listening socket should be investigated.

---

# Network Trust Boundaries

## NTB-01: MacBook to Ubuntu VM

This boundary separates the administrator workstation and browser client from the Linux server.

Primary risks:

- unauthorised SSH access
- incorrect VM network exposure
- leaked authentication credentials

---

## NTB-02: Network to UFW

This boundary controls which inbound traffic reaches services on the Ubuntu host.

Primary risks:

- unnecessary open ports
- firewall misconfiguration
- accidental service exposure

---

## NTB-03: UFW to Nginx

This boundary represents approved application traffic entering the server.

Primary risks:

- incorrect firewall rules
- unexpected application-facing services
- bypass of the intended reverse proxy path

---

## NTB-04: Nginx to Docker Application

This boundary separates the host reverse proxy from the containerised application.

Primary risks:

- direct container exposure
- incorrect proxy destination
- application binding to public interfaces

---

# Network Data Flows

## NDF-01: SSH Administration

```text
MacBook
  |
  | TCP 22
  v
UFW
  |
  v
SSH Service
  |
  v
Administrator Shell
```

---

## NDF-02: Application Request

```text
MacBook Browser
  |
  | TCP 80
  v
UFW
  |
  v
Nginx
  |
  | Internal application port
  v
Docker Application
```

---

## NDF-03: Package and Dependency Access

The Ubuntu VM may initiate outbound internet connections for:

- Ubuntu package repositories
- trusted container registries
- required project dependencies

These connections are outbound and do not require unsolicited inbound access.

---

## NDF-04: GitHub Access

GitHub access originates from the development environment for:

- Git push
- Git pull
- repository access
- issue management

The running application does not require GitHub to serve normal local traffic.

---

# Network Assumptions

The initial network design assumes:

- the MacBook and Ubuntu VM can communicate through a private virtual network
- the VM can obtain outbound internet access when required
- no public IP address is required
- no public DNS name is required
- the application can run on one internal port
- the MacBook is the only required administration workstation
- the network design is for a local lab rather than production

---

# Network Constraints

The initial design must follow these constraints:

- one Ubuntu Server VM
- no direct external application port
- no unnecessary inbound ports
- no public SSH requirement
- no multi-server network architecture
- no public load balancer
- no Kubernetes networking
- no cloud security groups during the MVP
- no production network claims

---

# Network Verification Plan

During later implementation, the design should be verified by confirming:

- the MacBook can reach SSH on the Ubuntu VM
- the MacBook can reach Nginx over HTTP
- the MacBook cannot directly reach the application port
- unnecessary ports are blocked
- UFW reports the intended policy
- listening sockets match the documented design
- application traffic successfully passes through Nginx
- firewall behaviour survives reboot

---

# Expected MVP Network State

The desired final network state is:

```text
Externally reachable from MacBook:

22/TCP  -> SSH
80/TCP  -> Nginx

Not externally reachable:

Application port
Database ports if introduced
Monitoring internals
Backup processes
Other system services
```

Only services with a documented reason should be reachable.

---

# Future Network Enhancements

Possible post-MVP network improvements include:

- HTTPS
- public DNS
- cloud security groups
- restricted SSH source addresses
- separate monitoring server
- separate application network
- remote backup destination
- VPN administration
- cloud private networking

These are not required for the SentinelOps MVP.