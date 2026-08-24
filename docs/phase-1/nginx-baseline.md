# SentinelOps Nginx Baseline

## Purpose

This document records the installation, configuration, firewall exposure, and verification of Nginx on the SentinelOps Ubuntu Server VM.

The Nginx baseline builds on the secure SSH configuration from SEN-005 and the host firewall baseline from SEN-006.

The objective is to introduce Nginx as the host-level web entry point while preserving the existing default-deny firewall model and avoiding premature exposure of HTTPS or future application ports.

---

## Initial State

Before SEN-007:

- Ubuntu Server 24.04.4 LTS was running in UTM
- the VM used IPv4 address `192.168.64.2`
- secure SSH administration was working
- SSH key authentication was enabled
- SSH password authentication was disabled
- direct root SSH login was disabled
- the `emir` administrator account retained sudo access
- UFW was active
- default incoming traffic was denied
- default outgoing traffic was allowed
- TCP port 22 was explicitly allowed
- TCP port 80 was blocked by UFW
- TCP port 443 was blocked by UFW
- Nginx was not installed
- Docker was not installed
- no application service was deployed
- UTM console access remained available as a local recovery path

---

## Nginx Baseline Verification Before Installation

Before installing Nginx, its presence was checked with:

```bash
nginx -v
```

Result:

```text
Command 'nginx' not found, but can be installed with:
sudo apt install nginx
```

The service state was also checked:

```bash
systemctl status nginx
```

Result:

```text
Unit nginx.service could not be found.
```

This confirmed that Nginx was not installed before SEN-007.

---

## Firewall State Before Installation

The existing firewall state was reviewed with:

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

This confirmed that SSH was the only explicitly permitted inbound service before Nginx installation.

No HTTP or HTTPS rule existed.

---

## Listening Socket Review Before Installation

Listening sockets were reviewed with:

```bash
ss -tulpn
```

Relevant TCP listeners were:

```text
127.0.0.54:53
127.0.0.53:53
0.0.0.0:22
[::]:22
```

No process was listening on TCP port 80 or TCP port 443.

This confirmed there was no existing web service before Nginx installation.

---

## Nginx Installation

Nginx was installed using the Ubuntu package manager:

```bash
sudo apt install nginx -y
```

The installation completed successfully.

Nginx was automatically configured as a systemd service.

---

## Installed Nginx Version

The installed version was verified with:

```bash
nginx -v
```

Result:

```text
nginx version: nginx/1.24.0 (Ubuntu)
```

This confirms the Ubuntu-packaged Nginx version used for the SEN-007 baseline.

---

## Nginx Service State

The Nginx service was inspected using:

```bash
systemctl status nginx
```

The service reported:

```text
Loaded: loaded
enabled
Active: active (running)
```

This confirms that:

- the Nginx service is installed
- the service is enabled
- the service starts automatically with the operating system
- the service is currently running

The service was started successfully by systemd during package installation.

---

## Nginx Configuration Validation

Before relying on the service, the Nginx configuration was validated with:

```bash
sudo nginx -t
```

Result:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

This confirms that the active Nginx configuration contains valid syntax.

Configuration validation should continue to be performed before future Nginx reloads or restarts.

---

## Port 80 Listening State

After Nginx installation, TCP port 80 was inspected using:

```bash
ss -tulpn | grep ':80'
```

Result:

```text
tcp LISTEN 0 511 0.0.0.0:80 0.0.0.0:*
tcp LISTEN 0 511 [::]:80 [::]:*
```

This confirms that Nginx listens on TCP port 80 for both IPv4 and IPv6.

At this stage, no listener was introduced on TCP port 443.

---

## UFW Application Profiles

Nginx installation added UFW application profiles.

These were reviewed with:

```bash
sudo ufw app list
```

Available profiles included:

```text
Nginx Full
Nginx HTTP
Nginx HTTPS
OpenSSH
```

The `Nginx HTTP` profile was selected because SEN-007 requires only TCP port 80.

The `Nginx Full` profile was not used because it would also allow HTTPS on TCP port 443 before TLS had been configured.

The `Nginx HTTPS` profile was not used because HTTPS is outside the scope of SEN-007.

---

## HTTP Firewall Rule

HTTP access was enabled with:

```bash
sudo ufw allow 'Nginx HTTP'
```

Result:

```text
Rule added
Rule added (v6)
```

This created HTTP allow rules for both IPv4 and IPv6.

---

## Firewall State After HTTP Rule

The resulting firewall configuration was verified with:

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
80/tcp (Nginx HTTP)        ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
80/tcp (Nginx HTTP (v6))   ALLOW IN    Anywhere (v6)
```

This confirms the intended network exposure:

```text
22/tcp    ALLOW    SSH
80/tcp    ALLOW    HTTP/Nginx
443/tcp   BLOCKED
```

No application-specific inbound rule was added.

---

## External HTTP Verification

The Nginx service was tested externally from the Mac host.

From macOS:

```bash
curl -I http://192.168.64.2
```

Result:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Content-Type: text/html
Content-Length: 615
Connection: keep-alive
```

This confirms:

- TCP port 80 is reachable from the Mac
- UFW permits the HTTP connection
- Nginx accepts the connection
- Nginx returns a successful HTTP response
- the response is generated by Nginx

---

## Default Nginx Page Verification

The response body was also tested from the Mac:

```bash
curl http://192.168.64.2 | head
```

Relevant response content included:

```text
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
```

This confirms that the default Nginx web page was served successfully.

No custom application or reverse-proxy backend was connected during SEN-007.

---

## HTTPS Exposure Verification

HTTPS was intentionally left closed.

From the Mac host:

```bash
nc -vz -w 2 192.168.64.2 443
```

Result:

```text
nc: connectx to 192.168.64.2 port 443 (tcp) failed: Operation timed out
```

This confirms that no externally reachable HTTPS service was available.

No UFW rule was added for TCP port 443.

No TLS certificate or HTTPS configuration was introduced.

---

## Nginx Access Log Verification

Nginx access logs were inspected with:

```bash
sudo tail -n 20 /var/log/nginx/access.log
```

The log contained entries corresponding to the Mac HTTP tests, including:

```text
192.168.64.1 - - [24/Aug/2026:22:01:07 +0000] "HEAD / HTTP/1.1" 200 0 "-" "curl/8.7.1"
192.168.64.1 - - [24/Aug/2026:22:01:10 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/8.7.1"
```

This confirms that Nginx recorded the external HTTP requests successfully.

The source address appeared as `192.168.64.1`, which is consistent with the UTM Shared Network/NAT path used by the Mac host.

---

## Nginx Error Log Verification

The Nginx error log was inspected with:

```bash
sudo tail -n 20 /var/log/nginx/error.log
```

A notice-level entry was present:

```text
using inherited sockets
```

No configuration failure or critical Nginx error was observed during the SEN-007 verification process.

---

## Reboot Persistence Test

Persistence was tested by rebooting the Ubuntu Server VM:

```bash
sudo reboot
```

The active SSH connection terminated as expected during the reboot.

An immediate SSH reconnection attempt timed out while the VM was still starting.

After startup completed, the Mac successfully reconnected using:

```bash
ssh emir@192.168.64.2
```

This confirmed that secure SSH administration remained available after reboot.

---

## Nginx State After Reboot

After reconnecting, the Nginx service was checked again:

```bash
systemctl status nginx
```

The service reported:

```text
Loaded: loaded
enabled
Active: active (running)
```

This confirms that Nginx started automatically during system boot and remained operational after restart.

---

## Firewall State After Reboot

UFW was rechecked after reboot:

```bash
sudo ufw status verbose
```

Result:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)

22/tcp                     ALLOW IN    Anywhere
80/tcp (Nginx HTTP)        ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
80/tcp (Nginx HTTP (v6))   ALLOW IN    Anywhere (v6)
```

This confirms that:

- UFW remained active
- the default-deny inbound policy persisted
- SSH remained allowed
- HTTP remained allowed
- IPv6 rules persisted
- HTTPS remained without an allow rule

---

## Nginx Configuration Validation After Reboot

The active configuration was validated again after reboot:

```bash
sudo nginx -t
```

Result:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

This confirms the configuration remained valid after system restart.

---

## External HTTP Verification After Reboot

After reboot, the Mac host tested Nginx again:

```bash
curl -I http://192.168.64.2
```

Result:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Content-Type: text/html
Content-Length: 615
Connection: keep-alive
```

This proves that the complete path remained operational after reboot:

```text
Mac Host
   |
   | HTTP :80
   v
UFW
   |
   v
Nginx
```

---

## SSH Preservation

SEN-007 did not alter the SSH hardening configuration introduced in SEN-005.

SSH remained accessible from the Mac using public-key authentication.

TCP port 22 remained explicitly permitted through UFW.

No SSH password authentication or root SSH access was re-enabled.

---

## Reverse Proxy Architecture

Nginx is installed on the Ubuntu host in accordance with the SentinelOps architecture decision to keep the reverse proxy outside future application containers.

At the completion of SEN-007, Nginx is not yet proxying traffic to an application.

Current traffic flow:

```text
Mac Host
   |
   | TCP 80
   v
UFW
   |
   v
Nginx default site
```

Future architecture:

```text
Client
   |
   | HTTP/HTTPS
   v
Nginx
   |
   | private backend connection
   v
Application
```

The backend application port should remain inaccessible through UFW.

---

## Security Result

At completion of SEN-007, the SentinelOps VM has the following web-server posture:

- Nginx installed from Ubuntu packages
- Nginx version `1.24.0`
- Nginx managed by systemd
- Nginx enabled at system startup
- Nginx active and running
- Nginx configuration syntax validated
- Nginx listening on TCP port 80
- HTTP explicitly permitted through UFW
- SSH explicitly permitted through UFW
- HTTPS not permitted through UFW
- no TLS configuration introduced
- no application backend exposed
- no Docker service introduced
- default-deny inbound firewall policy preserved
- HTTP externally verified from the Mac
- default Nginx page verified
- access logs verified
- error logs inspected
- Nginx persistence verified after reboot
- UFW persistence verified after reboot
- SSH persistence verified after reboot
- UTM console recovery access preserved

---

## Verification Summary

The following checks were successfully completed:

- confirmed Nginx was absent before installation
- confirmed `nginx.service` did not exist before installation
- reviewed the existing UFW configuration
- reviewed listening sockets before installation
- installed Nginx
- verified Nginx version
- verified Nginx service is active
- verified Nginx service is enabled
- validated Nginx configuration syntax
- confirmed Nginx listens on TCP port 80
- reviewed Nginx UFW application profiles
- allowed only the `Nginx HTTP` UFW profile
- verified HTTP firewall rules for IPv4 and IPv6
- confirmed HTTPS remained blocked
- confirmed SSH remained permitted
- confirmed the default-deny inbound policy remained active
- tested HTTP response headers from the Mac
- confirmed `HTTP/1.1 200 OK`
- verified the default Nginx HTML page
- confirmed TCP port 443 remained inaccessible
- inspected Nginx access logs
- inspected Nginx error logs
- rebooted the Ubuntu VM
- re-established SSH after reboot
- confirmed Nginx automatically restarted
- confirmed UFW rules persisted
- revalidated Nginx configuration
- confirmed external HTTP remained operational after reboot

---

## Out of Scope

SEN-007 did not introduce:

- HTTPS
- TLS certificates
- Certbot
- Let's Encrypt
- domain names
- public Internet exposure
- custom Nginx virtual hosts
- application reverse-proxy configuration
- Docker
- Docker Compose
- Django
- Gunicorn
- database services
- monitoring
- backups
- cloud infrastructure
- port forwarding
- bridged networking
- Ansible
- Terraform
- Kubernetes

These remain reserved for later SentinelOps issues.

---

## Completion State

The SentinelOps Ubuntu Server VM now has a functioning Nginx web-server baseline.

Nginx runs directly on the Ubuntu host, starts automatically with the operating system, and serves HTTP traffic on TCP port 80.

UFW preserves the default-deny inbound model while explicitly allowing only the required SSH and HTTP services.

HTTPS and future application ports remain unexposed.

The web service, firewall configuration, and secure SSH administration path all survive reboot.

This establishes the host-level web and reverse-proxy foundation required for later application deployment.