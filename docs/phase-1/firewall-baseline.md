# SentinelOps Firewall Baseline

## Purpose

This document records the implementation and verification of the host firewall baseline for the SentinelOps Ubuntu Server VM.

The firewall configuration builds on the secure SSH administration established in SEN-005.

The objective is to apply a default-deny inbound policy while preserving authorised SSH administration from the Mac host and avoiding premature exposure of future services.

---

## Initial State

Before SEN-006:

- Ubuntu Server 24.04.4 LTS was running in UTM
- the VM used IPv4 address `192.168.64.2`
- OpenSSH Server was installed
- SSH key authentication was working
- SSH password authentication was disabled
- direct root SSH login was disabled
- the `emir` administrator account retained sudo access
- SSH was listening on TCP port 22
- UFW was installed but inactive
- Nginx was not installed
- Docker was not installed
- no application service was deployed
- no HTTP or HTTPS service was listening
- UTM console access remained available as a local recovery path

The initial firewall state was confirmed with:

```bash
sudo ufw status verbose
```

Initial result:

```text
Status: inactive
```

This confirmed that firewall policy had not yet been activated.

---

## Initial Listening Socket Review

Before changing the firewall, active listening sockets were reviewed with:

```bash
ss -tulpn
```

Relevant TCP listeners included:

```text
127.0.0.54:53
0.0.0.0:22
127.0.0.53:53
[::]:22
```

SSH was therefore listening on TCP port 22 for both IPv4 and IPv6.

The port 53 listeners were local system DNS resolver services bound to loopback addresses.

UDP traffic observed on ports 68 and 546 related to network address configuration and did not represent additional externally exposed application services.

No listener was present on:

```text
80/tcp
443/tcp
```

No Nginx, Docker, or application service was present.

---

## Firewall Policy

The SentinelOps host firewall uses the following baseline policy:

```text
Incoming: deny
Outgoing: allow
Routed: disabled
```

The principle is to reject unsolicited inbound connectivity unless a specific service has a documented operational requirement.

At the current phase, the only required inbound service is SSH.

---

## Default Incoming Policy

The default incoming policy was configured with:

```bash
sudo ufw default deny incoming
```

Result:

```text
Default incoming policy changed to 'deny'
```

This establishes default-deny behaviour for inbound traffic.

Services must therefore be explicitly permitted before they can be accessed through the firewall.

---

## Default Outgoing Policy

The default outgoing policy was configured with:

```bash
sudo ufw default allow outgoing
```

Result:

```text
Default outgoing policy changed to 'allow'
```

The VM can therefore initiate normal outbound connections required for activities such as:

- package management
- DNS resolution
- software installation
- future application dependencies
- operating system updates

No unnecessary outbound restriction was introduced during this phase.

---

## SSH Firewall Rule

SSH was explicitly allowed before UFW was enabled.

The rule was created with:

```bash
sudo ufw allow 22/tcp
```

Result:

```text
Rules updated
Rules updated (v6)
```

The configured user rules were then reviewed with:

```bash
sudo ufw show added
```

Result:

```text
Added user rules (see 'ufw status' for running firewall):
ufw allow 22/tcp
```

This step was completed before firewall activation to prevent accidental loss of remote administrative access.

---

## Firewall Activation

After confirming that SSH had been explicitly permitted, UFW was enabled with:

```bash
sudo ufw enable
```

UFW displayed the standard warning:

```text
Command may disrupt existing ssh connections. Proceed with operation (y|n)?
```

The operation was confirmed only after verifying that the SSH rule already existed.

Result:

```text
Firewall is active and enabled on system startup
```

The existing SSH connection remained operational.

---

## Active Firewall State

The running firewall configuration was verified with:

```bash
sudo ufw status verbose
```

Result:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
```

This confirms:

- UFW is active
- logging is enabled at the default low level
- inbound traffic is denied by default
- outbound traffic is allowed by default
- routed traffic is disabled
- SSH is explicitly permitted
- the SSH rule exists for both IPv4 and IPv6
- no HTTP rule exists
- no HTTPS rule exists
- no application-specific inbound rule exists

---

## SSH Availability After Firewall Activation

The original SSH session was deliberately kept open while UFW was enabled.

A second independent macOS Terminal session was then opened.

From the Mac host:

```bash
ssh emir@192.168.64.2
```

The connection succeeded using the previously configured SSH public-key authentication.

No Ubuntu account password was required for SSH authentication.

This proved that activation of UFW did not disrupt the approved Mac-to-VM administration path.

---

## Post-Activation Socket Review

From the second SSH session, listening sockets were reviewed again:

```bash
ss -tulpn
```

Relevant TCP listeners remained:

```text
127.0.0.54:53
0.0.0.0:22
127.0.0.53:53
[::]:22
```

SSH remained available on TCP port 22 for IPv4 and IPv6.

No service was listening on TCP ports 80 or 443.

No new listener was introduced as a result of firewall configuration.

---

## Firewall Rules Versus Listening Services

Firewall rules and listening sockets represent different aspects of network exposure.

A listening socket indicates that a service is accepting connections on the operating system.

A firewall rule determines whether network traffic is permitted to reach that service.

For the current SentinelOps baseline:

```text
Service                  Listening        UFW Rule
SSH 22/tcp               Yes              Allow
HTTP 80/tcp              No               No allow rule
HTTPS 443/tcp            No               No allow rule
Application ports        No               No allow rule
```

This provides defence in depth.

Future services must both:

1. exist and listen on the required interface
2. have an intentional firewall rule before remote access is possible

---

## Local Port Verification

Initial connectivity tests from inside the Ubuntu VM confirmed the service state.

TCP port 22:

```bash
nc -vz 192.168.64.2 22
```

Result:

```text
Connection to 192.168.64.2 22 port [tcp/ssh] succeeded!
```

TCP port 80:

```bash
nc -vz -w 2 192.168.64.2 80
```

Result:

```text
nc: connect to 192.168.64.2 port 80 (tcp) failed: Connection refused
```

TCP port 443:

```bash
nc -vz -w 2 192.168.64.2 443
```

Result:

```text
nc: connect to 192.168.64.2 port 443 (tcp) failed: Connection refused
```

These local tests confirmed that no HTTP or HTTPS service was listening.

They were not treated as the primary firewall-boundary test because they originated from the VM itself.

---

## External Mac-to-VM Port Verification

The firewall boundary was tested from the Mac host.

### SSH

From macOS:

```bash
nc -vz 192.168.64.2 22
```

Result:

```text
Connection to 192.168.64.2 port 22 [tcp/ssh] succeeded!
```

This confirmed that the explicitly permitted SSH service remained reachable through UFW.

### HTTP

From macOS:

```bash
nc -vz -w 2 192.168.64.2 80
```

Result:

```text
nc: connectx to 192.168.64.2 port 80 (tcp) failed: Operation timed out
```

This confirmed that unsolicited inbound TCP traffic to port 80 was not permitted through the firewall.

### HTTPS

From macOS:

```bash
nc -vz -w 2 192.168.64.2 443
```

No connection was established.

The command remained without a successful response and was manually terminated.

This behaviour was consistent with UFW silently dropping unsolicited inbound traffic to a port that had no allow rule.

No HTTPS service was exposed.

---

## HTTP and HTTPS Exposure Decision

No firewall rule was added for:

```text
80/tcp
443/tcp
```

This was intentional.

Nginx has not yet been installed and no web service currently requires inbound HTTP or HTTPS connectivity.

Opening these ports before a service requirement exists would create unnecessary network exposure.

HTTP and HTTPS rules will be introduced only when the corresponding reverse-proxy or application architecture is implemented and verified.

---

## Application Port Exposure

No application-specific port was allowed through UFW.

The project intentionally avoids prematurely exposing ports that may later be used by:

- Django
- Docker containers
- monitoring tools
- databases
- internal application services

Future application services should remain private where possible and be exposed only through the documented architecture.

---

## Reboot Persistence Test

Firewall persistence was tested by rebooting the Ubuntu Server VM.

From an active SSH session:

```bash
sudo reboot
```

The existing SSH connection terminated as expected while the operating system rebooted.

An immediate reconnection attempt temporarily timed out because the VM had not yet completed startup.

After the VM finished booting, SSH connectivity from the Mac was restored successfully:

```bash
ssh emir@192.168.64.2
```

This confirmed that the approved SSH path remained functional after reboot.

---

## Firewall State After Reboot

After reconnecting to the rebooted VM, UFW was checked again:

```bash
sudo ufw status verbose
```

Result:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
```

This proves that:

- UFW automatically returned to the active state
- the default inbound deny policy persisted
- the default outbound allow policy persisted
- the SSH rule persisted
- IPv4 and IPv6 SSH rules persisted
- no additional inbound rule appeared after reboot

---

## SSH Persistence After Reboot

SSH administration was also retested after the reboot.

The Mac host successfully established a new connection to:

```text
emir@192.168.64.2
```

The existing SEN-005 security controls remained operational.

The firewall therefore did not interfere with secure administrative access across a system restart.

---

## Recovery Access

UTM console access remains available independently of SSH.

This provides a local recovery path if a future firewall or SSH configuration error prevents remote access.

No change was made to the UTM console configuration during SEN-006.

This recovery path was intentionally preserved before and throughout firewall activation.

---

## Network Configuration

No change was made to the existing UTM network architecture.

The VM continued using:

```text
IPv4: 192.168.64.2/24
Gateway: 192.168.64.1
```

No changes were made to:

- UTM Shared Network mode
- static addressing
- NAT configuration
- port forwarding
- bridging
- DNS architecture
- routing configuration

SEN-006 changed only the Ubuntu host firewall policy.

---

## Security Result

At completion of SEN-006, the SentinelOps VM has the following firewall posture:

- UFW enabled
- UFW enabled automatically at system startup
- inbound traffic denied by default
- outbound traffic allowed by default
- routed traffic disabled
- low-level UFW logging enabled
- SSH explicitly permitted on TCP port 22
- SSH accessible from the approved Mac administration host
- IPv4 SSH access supported
- IPv6 SSH rule present
- HTTP not permitted
- HTTPS not permitted
- no application-specific port permitted
- no Nginx exposure
- no Docker exposure
- no database exposure
- no monitoring port exposure
- firewall state verified after reboot
- secure SSH administration preserved
- local UTM recovery access preserved

---

## Verification Summary

The following checks were successfully completed:

- reviewed UFW before configuration
- confirmed UFW was initially inactive
- reviewed listening sockets before configuration
- confirmed SSH was listening on TCP port 22
- confirmed no HTTP or HTTPS listener existed
- configured default-deny incoming traffic
- configured default-allow outgoing traffic
- explicitly allowed TCP port 22 before firewall activation
- reviewed the pending UFW rule
- enabled UFW
- verified UFW became active
- verified the active default policies
- verified only SSH was explicitly permitted
- confirmed the existing SSH session survived activation
- established a second independent SSH session from macOS
- reviewed listening sockets after activation
- confirmed TCP port 22 was reachable externally from the Mac
- confirmed TCP port 80 was not reachable externally
- confirmed TCP port 443 did not establish a connection externally
- rebooted the VM
- re-established SSH after reboot
- confirmed UFW remained active after reboot
- confirmed firewall rules persisted after reboot
- confirmed no unrelated infrastructure service was introduced

---

## Out of Scope

SEN-006 did not introduce:

- Nginx
- HTTP service exposure
- HTTPS service exposure
- TLS certificates
- Docker
- Docker Compose
- application deployment
- database services
- monitoring
- backups
- cloud security groups
- port forwarding
- bridged networking
- Ansible
- Terraform
- Kubernetes

These capabilities remain reserved for later SentinelOps issues.

---

## Completion State

The SentinelOps Ubuntu Server VM now operates with an active host firewall enforcing a default-deny inbound security policy.

Secure SSH administration from the Mac remains available through the explicitly permitted TCP port 22 rule.

All other unsolicited inbound traffic is denied unless a future SentinelOps issue introduces and documents an explicit requirement.

The firewall configuration survives reboot, and UTM console access remains available as an independent recovery mechanism.

This provides the network-security foundation required before web, container, and application services are introduced.