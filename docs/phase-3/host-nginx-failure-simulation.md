# SEN-022: Host Nginx Failure Simulation

## Summary

SEN-022 completes the second controlled SentinelOps failure simulation by intentionally stopping the host-level Nginx reverse proxy and documenting the complete incident lifecycle.

The simulation demonstrates:

- healthy pre-failure state;
- controlled host Nginx service failure;
- monitoring detection;
- operational diagnosis;
- fault-domain isolation;
- recovery;
- recovery verification;
- security regression verification;
- resilience and prevention considerations.

The failure was introduced using a reversible systemd service operation:

```bash
sudo systemctl stop nginx
```

No Nginx configuration was deleted or modified.

The Docker application remained healthy throughout the incident.

This produced a deliberate separation between:

```text
application health
```

and:

```text
public reverse-proxy availability
```

The environment was fully restored to its verified healthy state before completion.

---

## Purpose

The purpose of SEN-022 is to prove that SentinelOps can detect, diagnose, recover from, and document a failure of the host reverse-proxy layer without confusing that failure with an application-container failure.

The scenario specifically tests the host Nginx component.

The normal request path is:

```text
Client
  |
  v
Host Nginx
TCP 80
  |
  v
127.0.0.1:8000
  |
  v
Docker application container
TCP 80 inside container
```

SEN-021 previously tested failure of the application container while host Nginx remained operational.

SEN-022 intentionally tests the inverse condition:

```text
Host Nginx
-> unavailable

Application container
-> healthy
```

This distinction is important because a monitoring system should identify the layer that failed rather than simply reporting that the overall service is unavailable.

---

## Requirements Mapping

SEN-022 contributes directly to the controlled failure simulation requirements.

### FR-35

> Perform at least three controlled infrastructure or application failure simulations.

SEN-022 represents the host reverse-proxy failure scenario.

The failure was deliberately introduced by stopping the host Nginx service.

### FR-36

> Demonstrate failure detection.

SentinelOps monitoring detected both:

```text
nginx_service
```

and:

```text
host_nginx_health
```

as failed.

Structured monitoring recorded both failures with:

```text
status=FAIL
severity=CRITICAL
```

### FR-37

> Document diagnosis evidence.

Diagnosis used:

- systemd service state;
- Nginx configuration validation;
- TCP listener state;
- Docker Compose state;
- direct application health;
- reverse-proxy health;
- monitoring output;
- structured monitoring logs;
- Nginx systemd journal;
- UFW state;
- failed systemd unit state.

### FR-38

> Document recovery steps.

Recovery used the smallest appropriate action:

```bash
sudo systemctl start nginx
```

No application restart, Docker restart, firewall modification, or configuration change was required.

### FR-39

> Verify restoration of normal service.

Following recovery:

- Nginx returned to `active`;
- TCP port `80` returned;
- the backend remained available on `127.0.0.1:8000`;
- direct application health returned HTTP 200;
- proxied application health returned HTTP 200;
- structured monitoring returned to PASS;
- no unexpected failed systemd units existed;
- UFW remained unchanged.

### FR-40

> Document prevention or improvement controls.

Existing controls and future resilience improvements are documented later in this report.

---

## Scope

SEN-022 covers:

```text
host Nginx reverse-proxy failure
```

The simulation does not intentionally fail:

- the Docker daemon;
- the application container;
- SSH;
- UFW;
- the VM;
- backups;
- storage;
- networking;
- the host operating system.

---

## Architecture Under Test

The SentinelOps HTTP architecture is:

```text
Mac / client
    |
    | TCP 80
    v
Ubuntu Server
    |
    | host Nginx
    v
127.0.0.1:8000
    |
    | Docker port mapping
    v
sentinelops-app
    |
    v
container Nginx :80
```

The backend is intentionally bound only to:

```text
127.0.0.1:8000
```

The backend is therefore not intended to be directly exposed to external systems.

Host Nginx provides the externally reachable HTTP entry point.

---

## Environment

The simulation was performed on the SentinelOps Ubuntu Server VM.

Relevant environment components included:

```text
Operating system:
Ubuntu Server 24.04.4 LTS

Hostname:
sentinelops-ubuntu

Application directory:
/home/emir/sentinelops-app

Application service:
sentinelops-app

Host reverse proxy:
nginx.service

Host Nginx version:
nginx/1.24.0 (Ubuntu)

Container Nginx version:
nginx/1.31.4

Backend bind:
127.0.0.1:8000

Public HTTP:
TCP 80

SSH:
TCP 22

Application version:
0.1.0
```

---

# Healthy Pre-Failure Baseline

Before introducing the controlled failure, the existing environment was verified.

## Service State

The following commands were executed:

```bash
systemctl is-active nginx
systemctl is-active docker
systemctl is-active ssh.socket
systemctl --failed
```

Observed state:

```text
nginx
active

docker
active

ssh.socket
active
```

Failed systemd units:

```text
UNIT LOAD ACTIVE SUB DESCRIPTION

0 loaded units listed.
```

This established that the infrastructure began the test without an existing systemd service failure.

---

## Docker Compose State

The application stack was inspected with:

```bash
cd /home/emir/sentinelops-app
docker compose ps
```

Observed state:

```text
NAME              IMAGE                 COMMAND                  SERVICE   CREATED      STATUS       PORTS
sentinelops-app   sentinelops-app-app   "/docker-entrypoint.…"   app       2 days ago   Up 5 hours   127.0.0.1:8000->80/tcp
```

The application container was running.

The published application port remained:

```text
127.0.0.1:8000
```

This confirmed the backend was loopback-only.

---

## Direct Backend Health

The private backend was tested directly:

```bash
curl -i http://127.0.0.1:8000/health
```

Response:

```text
HTTP/1.1 200 OK
Server: nginx/1.31.4
Content-Type: application/octet-stream
```

Health body:

```json
{"status":"healthy","version":"0.1.0"}
```

This verified:

```text
backend application
-> healthy

application version
-> 0.1.0
```

---

## Host Reverse-Proxy Health

The same health endpoint was requested through host Nginx:

```bash
curl -i http://127.0.0.1/health
```

Response:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Content-Type: application/octet-stream
```

Health body:

```json
{"status":"healthy","version":"0.1.0"}
```

This verified the complete request path:

```text
host Nginx
-> backend
-> health endpoint
```

was operational before the test.

---

## Healthy TCP Listener State

Listeners were inspected with:

```bash
ss -tulpn | grep -E ':22|:80|:8000'
```

Relevant output showed:

```text
127.0.0.1:8000
0.0.0.0:80
0.0.0.0:22
[::]:80
[::]:22
```

The baseline therefore established:

```text
TCP 22
-> listening

TCP 80
-> listening

TCP 8000
-> loopback-only
```

---

## Nginx Configuration Validation

Before the failure, the host Nginx configuration was validated:

```bash
sudo nginx -t
```

Result:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

The incident therefore did not begin with an invalid Nginx configuration.

---

## Firewall Baseline

The firewall was inspected with:

```bash
sudo ufw status verbose
```

State:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
```

Allowed inbound services:

```text
22/tcp                  ALLOW IN
80/tcp (Nginx HTTP)     ALLOW IN
```

IPv6 equivalents were also present.

There was no rule allowing external access to TCP port 8000.

---

## Healthy Monitoring Baseline

The monitoring script was executed:

```bash
~/sentinelops-monitoring/health-check.sh
```

Relevant service output showed:

```text
Docker: active
Nginx:  active
SSH:    active
```

Application health:

```text
HTTP 200
Application health endpoint reachable
```

Host Nginx health:

```text
HTTP 200
Nginx reachable
```

---

## Healthy Structured Monitoring State

Relevant structured monitoring entries were extracted:

```bash
grep -E 'check=(docker_service|nginx_service|ssh_service|compose_application|application_health|host_nginx_health)' \
    /var/log/sentinelops/health-check.log | tail -6
```

Baseline entries:

```text
timestamp=2026-08-31T23:58:15Z check=docker_service status=PASS severity=INFO message="Docker service is active"

timestamp=2026-08-31T23:58:15Z check=nginx_service status=PASS severity=INFO message="Nginx service is active"

timestamp=2026-08-31T23:58:15Z check=ssh_service status=PASS severity=INFO message="SSH socket is active"

timestamp=2026-08-31T23:58:15Z check=compose_application status=PASS severity=INFO message="Compose application service is running"

timestamp=2026-08-31T23:58:17Z check=application_health status=PASS severity=INFO message="Application health endpoint returned HTTP 200"

timestamp=2026-08-31T23:58:17Z check=host_nginx_health status=PASS severity=INFO message="Host Nginx returned HTTP 200"
```

The healthy baseline therefore consisted of six PASS results.

---

# Controlled Failure Injection

## Failure Action

The controlled failure was introduced with:

```bash
sudo systemctl stop nginx
```

This intentionally stopped only the host Nginx service.

No destructive configuration change was performed.

---

## Safety Boundary

The following components were deliberately left untouched:

```text
Docker daemon
sentinelops-app container
SSH
UFW
Nginx configuration
Docker Compose configuration
application image
monitoring logs
backup configuration
backup artifacts
```

The simulation therefore represented a controlled service outage rather than destructive infrastructure damage.

---

# Failed State

## Host Nginx Service

Immediately after failure injection:

```bash
systemctl is-active nginx
systemctl status nginx --no-pager
```

returned:

```text
inactive
```

Detailed service state included:

```text
Active: inactive (dead)
```

The service was shown as:

```text
Loaded: loaded
enabled
preset: enabled
```

systemd recorded the stop operation as successful.

---

## systemd Stop Evidence

The Nginx service journal showed:

```text
Aug 31 23:59:53 sentinelops-ubuntu systemd[1]: Stopping nginx.service - A high performance web server and a reverse proxy server...

Aug 31 23:59:53 sentinelops-ubuntu systemd[1]: nginx.service: Deactivated successfully.

Aug 31 23:59:53 sentinelops-ubuntu systemd[1]: Stopped nginx.service - A high performance web server and a reverse proxy server.
```

This confirmed that Nginx did not unexpectedly crash.

It was intentionally and cleanly stopped.

---

# Listener Failure Evidence

TCP listeners were checked again:

```bash
ss -tulpn | grep -E ':22|:80|:8000'
```

Observed state:

```text
127.0.0.1:8000
0.0.0.0:22
[::]:22
```

The host Nginx listener on TCP port 80 disappeared.

The private application listener remained.

This produced:

```text
TCP 80
-> absent

127.0.0.1:8000
-> present

TCP 22
-> present
```

---

# Application Isolation Evidence

## Direct Backend Remained Healthy

The private backend was requested while host Nginx was stopped:

```bash
curl -i http://127.0.0.1:8000/health
```

Response:

```text
HTTP/1.1 200 OK
Server: nginx/1.31.4
```

Body:

```json
{"status":"healthy","version":"0.1.0"}
```

This was critical evidence.

It proved that:

```text
application
-> healthy

container
-> healthy

backend listener
-> healthy

health endpoint
-> healthy
```

The failure was therefore not an application failure.

---

## Host HTTP Path Failed

The host-level request was then tested:

```bash
curl -i --max-time 5 http://127.0.0.1/health
```

Result:

```text
curl: (7) Failed to connect to 127.0.0.1 port 80 after 0 ms: Couldn't connect to server
```

Unlike SEN-021, this did not return HTTP 502.

There was no process listening on TCP 80.

Therefore curl could not establish an HTTP connection at all.

---

# Docker and SSH Isolation

The following were checked while Nginx remained down:

```bash
cd /home/emir/sentinelops-app
docker compose ps

systemctl is-active docker
systemctl is-active ssh.socket
systemctl --failed
```

Docker Compose still showed:

```text
sentinelops-app
Up 5 hours
127.0.0.1:8000->80/tcp
```

Service state:

```text
Docker
active

SSH
active
```

Failed systemd units:

```text
0 loaded units listed.
```

This demonstrated that the incident was isolated to the host reverse-proxy layer.

---

# Monitoring Detection

The SentinelOps monitoring script was executed while Nginx remained stopped:

```bash
~/sentinelops-monitoring/health-check.sh
```

Monitoring observed:

```text
Docker: active
Nginx:  inactive
SSH:    active
```

The application health check returned:

```text
HTTP 200
Application health endpoint reachable
```

The host Nginx check returned:

```text
curl: (7) Failed to connect to 127.0.0.1 port 80
HTTP 000
Nginx health check FAILED
```

---

# Structured Monitoring Failure Evidence

Structured entries showed:

```text
timestamp=2026-09-01T00:00:25Z check=docker_service status=PASS severity=INFO message="Docker service is active"

timestamp=2026-09-01T00:00:25Z check=nginx_service status=FAIL severity=CRITICAL message="Nginx service is not active"

timestamp=2026-09-01T00:00:25Z check=ssh_service status=PASS severity=INFO message="SSH socket is active"

timestamp=2026-09-01T00:00:25Z check=compose_application status=PASS severity=INFO message="Compose application service is running"

timestamp=2026-09-01T00:00:26Z check=application_health status=PASS severity=INFO message="Application health endpoint returned HTTP 200"

timestamp=2026-09-01T00:00:26Z check=host_nginx_health status=FAIL severity=CRITICAL message="Host Nginx returned HTTP 000"
```

The resulting monitoring matrix was:

```text
docker_service
PASS / INFO

nginx_service
FAIL / CRITICAL

ssh_service
PASS / INFO

compose_application
PASS / INFO

application_health
PASS / INFO

host_nginx_health
FAIL / CRITICAL
```

---

# Failure-Domain Isolation

This pattern provides strong diagnostic evidence.

The following checks remained healthy:

```text
docker_service
compose_application
application_health
ssh_service
```

The following checks failed:

```text
nginx_service
host_nginx_health
```

Therefore the fault domain was:

```text
host Nginx reverse-proxy layer
```

rather than:

```text
Docker
application container
application health endpoint
SSH
firewall
```

---

# Comparison with SEN-021

SEN-021 and SEN-022 intentionally demonstrate opposite failure patterns.

## SEN-021

Application container stopped:

```text
Host Nginx service
PASS

Application container
FAIL

Application health
FAIL

Host Nginx health
FAIL
```

Host Nginx remained operational but could not connect to its upstream backend.

The result was:

```text
HTTP 502 Bad Gateway
```

The architecture looked like:

```text
Client
  |
  v
Host Nginx
HEALTHY
  |
  X
Backend unavailable
```

---

## SEN-022

Host Nginx stopped:

```text
Host Nginx service
FAIL

Application container
PASS

Application health
PASS

Host Nginx health
FAIL
```

There was no process listening on TCP 80.

The result was:

```text
connection failure
HTTP 000
```

The architecture looked like:

```text
Client
  |
  X
Host Nginx unavailable

127.0.0.1:8000
  |
  v
Application
HEALTHY
```

---

## Diagnostic Difference

The important distinction is:

```text
SEN-021:
proxy alive
backend dead

SEN-022:
proxy dead
backend alive
```

This proves the monitoring design provides useful fault isolation.

A single generic:

```text
website down
```

alert would provide much less diagnostic value.

Structured component-level checks make the failure domain immediately clearer.

---

# Firewall During Failure

UFW was inspected while Nginx remained stopped:

```bash
sudo ufw status verbose
```

The firewall remained:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
```

Allowed ports remained:

```text
22/tcp
80/tcp
```

There was no new TCP 8000 firewall rule.

An important distinction is:

```text
firewall permits TCP 80
```

does not imply:

```text
a service is listening on TCP 80
```

During the failure:

```text
UFW allowed TCP 80
```

but:

```text
Nginx was stopped
```

therefore:

```text
TCP 80 had no listener
```

and HTTP remained unavailable.

---

# Backup Isolation

During the failure simulation, the automated backup workflow also ran.

Monitoring observed:

```text
Newest backup:
sentinelops-backup-20260901T000013Z.tar.gz

Backup age:
0 hour(s)

Backup freshness:
OK
```

This provided incidental additional fault-isolation evidence.

The Nginx outage did not prevent the backup subsystem from operating.

The backup workflow remained independent from the reverse-proxy service.

---

# Formal Diagnosis

Before recovery, additional diagnostic evidence was captured.

## Configuration Validation

The Nginx configuration was tested while the service remained stopped:

```bash
sudo nginx -t
```

Result:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok

nginx: configuration file /etc/nginx/nginx.conf test is successful
```

This ruled out Nginx syntax failure.

---

## Exact systemd State

The following command was used:

```bash
systemctl show nginx \
    -p ActiveState \
    -p SubState \
    -p UnitFileState
```

Result:

```text
ActiveState=inactive
SubState=dead
UnitFileState=enabled
```

This established three separate facts.

### ActiveState

```text
inactive
```

The service was not currently active.

### SubState

```text
dead
```

The Nginx process was no longer running.

### UnitFileState

```text
enabled
```

The service remained enabled for normal system startup.

The incident therefore did not involve disabling the service.

---

# Root Cause

The root cause was intentional:

```bash
sudo systemctl stop nginx
```

The causal chain was:

```text
controlled systemctl stop
        |
        v
nginx.service becomes inactive
        |
        v
host Nginx processes terminate cleanly
        |
        v
TCP port 80 listener disappears
        |
        v
host HTTP request cannot establish connection
        |
        v
host_nginx_health returns HTTP 000
        |
        v
SentinelOps records FAIL / CRITICAL
```

Meanwhile:

```text
Docker remains active
        |
        v
sentinelops-app remains running
        |
        v
127.0.0.1:8000 remains listening
        |
        v
application_health remains HTTP 200
```

---

# Diagnosis Conclusion

The evidence supports the following diagnosis:

```text
Incident type:
host reverse-proxy outage

Failed component:
nginx.service

Application state:
healthy

Docker state:
healthy

SSH state:
healthy

Firewall state:
unchanged

Nginx configuration:
valid

Backend state:
healthy

Public HTTP listener:
absent
```

No application rebuild or container recovery was necessary.

---

# Recovery

## Recovery Strategy

The smallest appropriate recovery action was selected.

Because:

```text
configuration
-> valid

application
-> healthy

Docker
-> healthy

firewall
-> unchanged
```

there was no reason to:

- restart Docker;
- restart the application;
- rebuild the image;
- modify Nginx configuration;
- modify UFW;
- reboot the VM.

The correct recovery action was:

```bash
sudo systemctl start nginx
```

---

# Recovered Service State

After recovery:

```bash
systemctl is-active nginx
systemctl status nginx --no-pager
```

returned:

```text
active
```

Detailed state showed:

```text
Active: active (running)
```

with the new Nginx master and worker processes running.

The service started at:

```text
2026-09-01 00:22:01 UTC
```

---

# Recovered Listener State

Listeners were inspected again:

```bash
ss -tulpn | grep -E ':22|:80|:8000'
```

Recovered output showed:

```text
127.0.0.1:8000
0.0.0.0:80
0.0.0.0:22
[::]:80
[::]:22
```

The architecture returned to:

```text
TCP 22
-> listening

TCP 80
-> listening

127.0.0.1:8000
-> loopback-only and listening
```

No additional listener was introduced.

---

# Direct Backend Recovery Verification

The direct backend was tested:

```bash
curl -i http://127.0.0.1:8000/health
```

Result:

```text
HTTP/1.1 200 OK
Server: nginx/1.31.4
```

Body:

```json
{"status":"healthy","version":"0.1.0"}
```

The backend remained healthy.

It did not require recovery.

---

# Reverse-Proxy Recovery Verification

The host path was tested:

```bash
curl -i http://127.0.0.1/health
```

Result:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
```

Body:

```json
{"status":"healthy","version":"0.1.0"}
```

This confirmed restoration of the complete path:

```text
Host Nginx
  |
  v
127.0.0.1:8000
  |
  v
sentinelops-app
```

---

# Application Version Verification

Both direct and proxied health checks reported:

```json
{"status":"healthy","version":"0.1.0"}
```

The application version remained:

```text
0.1.0
```

No deployment or application image change occurred during incident recovery.

---

# Monitoring Recovery Verification

After Nginx recovery:

```bash
~/sentinelops-monitoring/health-check.sh
```

reported:

```text
Docker: active
Nginx:  active
SSH:    active
```

Application health:

```text
HTTP 200
Application health endpoint reachable
```

Host Nginx health:

```text
HTTP 200
Nginx reachable
```

---

# Structured Monitoring Recovered State

The recovered structured entries were:

```text
timestamp=2026-09-01T00:22:29Z check=docker_service status=PASS severity=INFO message="Docker service is active"

timestamp=2026-09-01T00:22:29Z check=nginx_service status=PASS severity=INFO message="Nginx service is active"

timestamp=2026-09-01T00:22:29Z check=ssh_service status=PASS severity=INFO message="SSH socket is active"

timestamp=2026-09-01T00:22:29Z check=compose_application status=PASS severity=INFO message="Compose application service is running"

timestamp=2026-09-01T00:22:30Z check=application_health status=PASS severity=INFO message="Application health endpoint returned HTTP 200"

timestamp=2026-09-01T00:22:30Z check=host_nginx_health status=PASS severity=INFO message="Host Nginx returned HTTP 200"
```

The recovered matrix was:

```text
docker_service
PASS / INFO

nginx_service
PASS / INFO

ssh_service
PASS / INFO

compose_application
PASS / INFO

application_health
PASS / INFO

host_nginx_health
PASS / INFO
```

---

# Incident Timeline

The observed incident timeline was:

```text
2026-08-31 23:58:15 UTC
Healthy monitoring baseline begins.

2026-08-31 23:58:17 UTC
Application and host Nginx health confirmed HTTP 200.

2026-08-31 23:59:53 UTC
nginx.service intentionally stopped.

2026-08-31 23:59:53 UTC
systemd records successful Nginx deactivation.

2026-09-01 00:00:25 UTC
SentinelOps monitoring detects nginx_service failure.

2026-09-01 00:00:25 UTC
nginx_service recorded FAIL / CRITICAL.

2026-09-01 00:00:26 UTC
Application health remains HTTP 200.

2026-09-01 00:00:26 UTC
host_nginx_health records HTTP 000 and FAIL / CRITICAL.

2026-09-01 00:22:01 UTC
Nginx recovery begins.

2026-09-01 00:22:01 UTC
systemd records successful Nginx start.

2026-09-01 00:22:15 UTC
Direct and proxied health endpoints both return HTTP 200.

2026-09-01 00:22:29 UTC
Recovered monitoring pass begins.

2026-09-01 00:22:30 UTC
host_nginx_health returns PASS / INFO with HTTP 200.
```

---

# Nginx Journal Recovery Evidence

The systemd journal provided a concise incident lifecycle:

```text
Aug 31 23:59:53 sentinelops-ubuntu systemd[1]: Stopping nginx.service - A high performance web server and a reverse proxy server...

Aug 31 23:59:53 sentinelops-ubuntu systemd[1]: nginx.service: Deactivated successfully.

Aug 31 23:59:53 sentinelops-ubuntu systemd[1]: Stopped nginx.service - A high performance web server and a reverse proxy server.

Sep 01 00:22:01 sentinelops-ubuntu systemd[1]: Starting nginx.service - A high performance web server and a reverse proxy server...

Sep 01 00:22:01 sentinelops-ubuntu systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.
```

This demonstrates:

```text
controlled failure
-> successful stop

recovery
-> successful start
```

There was no unexpected Nginx crash recorded.

---

# Failed systemd Unit Verification

After recovery:

```bash
systemctl --failed
```

returned:

```text
UNIT LOAD ACTIVE SUB DESCRIPTION

0 loaded units listed.
```

Stopping Nginx cleanly did not place the unit into a systemd `failed` state.

This is an important operational distinction.

A service can be:

```text
inactive
```

without being:

```text
failed
```

Therefore service-specific monitoring remains necessary.

---

# Security Regression Verification

## UFW

After recovery:

```bash
sudo ufw status verbose
```

still reported:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
```

Allowed inbound services remained:

```text
22/tcp
80/tcp
```

No external rule was added for:

```text
8000/tcp
```

---

## Backend Privacy

Listener verification confirmed:

```text
127.0.0.1:8000
```

The backend remained loopback-only.

The incident recovery did not expose the application directly to the network.

---

## SSH Preservation

SSH remained active throughout the test.

Port:

```text
22
```

remained listening.

The controlled HTTP failure therefore did not remove the administrative access path.

---

# Resilience Analysis

## systemd Management

Host Nginx is managed by systemd.

Observed unit state included:

```text
UnitFileState=enabled
```

This means Nginx is configured to start as part of the normal system boot process.

However, an enabled service is not the same as a service that automatically overrides an explicit administrative stop.

The scenario therefore demonstrates the difference between:

```text
enabled
```

and:

```text
currently running
```

---

## Configuration Validation

The existing operational control:

```bash
sudo nginx -t
```

provides a method of validating Nginx configuration before reload or restart operations.

In this scenario it proved the configuration was still syntactically valid.

This prevented unnecessary configuration troubleshooting.

---

## Component Separation

The architecture separates:

```text
host reverse proxy
```

from:

```text
Docker application
```

This allowed the application to remain operational even though the public entry point failed.

That separation improves diagnosis because each layer can be tested independently.

---

## Structured Monitoring

The existing structured monitoring design provided high diagnostic value.

The following combination:

```text
nginx_service=FAIL
host_nginx_health=FAIL

compose_application=PASS
application_health=PASS
```

immediately narrowed the incident to the host proxy layer.

---

# Prevention and Improvement

## Existing Controls

The environment already has several relevant controls.

### systemd Service Management

Nginx is managed as a systemd service.

This provides:

- standardized service control;
- service state inspection;
- startup management;
- journal integration.

### Enabled Boot State

The Nginx unit is:

```text
enabled
```

which supports restoration across normal machine boots.

### Configuration Validation

```bash
sudo nginx -t
```

can detect syntax errors before configuration activation.

### Health Monitoring

The SentinelOps monitoring script checks:

```text
nginx_service
```

and:

```text
host_nginx_health
```

independently.

### Application Monitoring

The application itself is checked independently using:

```text
application_health
```

This provides layer-specific diagnosis.

### Operational Logs

systemd and Nginx logs provide historical evidence for diagnosis.

---

## Potential Future Improvements

Future improvements could include:

- automated alert delivery when monitoring detects CRITICAL state;
- external HTTP probes from outside the VM;
- centralised monitoring;
- service outage notifications;
- service restart policy analysis;
- availability dashboards;
- redundant reverse proxies;
- high-availability deployment architecture;
- automated incident escalation;
- additional synthetic end-to-end checks.

These improvements are outside the implementation scope of SEN-022.

---

# Recovery Runbook

If the same failure pattern occurs operationally, the following diagnostic sequence can be used.

## 1. Check Nginx

```bash
systemctl is-active nginx
systemctl status nginx --no-pager
```

## 2. Check the Backend

```bash
cd /home/emir/sentinelops-app
docker compose ps
curl -i http://127.0.0.1:8000/health
```

## 3. Check the Host Path

```bash
curl -i --max-time 5 http://127.0.0.1/health
```

## 4. Check Listeners

```bash
ss -tulpn | grep -E ':22|:80|:8000'
```

## 5. Validate Configuration

```bash
sudo nginx -t
```

## 6. Review Logs

```bash
sudo journalctl -u nginx --no-pager
```

## 7. Recover the Service

If configuration is valid and recovery is appropriate:

```bash
sudo systemctl start nginx
```

## 8. Verify Recovery

```bash
systemctl is-active nginx

curl -i http://127.0.0.1:8000/health
curl -i http://127.0.0.1/health
```

## 9. Run Monitoring

```bash
~/sentinelops-monitoring/health-check.sh
```

## 10. Verify Security Controls

```bash
sudo ufw status verbose
ss -tulpn | grep -E ':22|:80|:8000'
systemctl --failed
```

---

# What Not to Do

This incident did not require:

```bash
sudo reboot
```

It did not require restarting Docker.

It did not require stopping or recreating the application container.

It did not require opening TCP 8000 in UFW.

It did not require deleting or rewriting Nginx configuration.

It did not require rebuilding the application image.

The correct response was to isolate the failed layer and recover only that layer.

---

# Lessons Learned

## Service Availability and Application Health Are Different

The application can remain fully healthy while users cannot reach it through the normal public path.

This occurred during SEN-022.

The backend health endpoint returned:

```text
HTTP 200
```

while the host request returned:

```text
connection failure
```

---

## An Allowed Firewall Port Does Not Guarantee a Listener

UFW continued allowing TCP 80 throughout the incident.

However, when Nginx was stopped:

```text
TCP 80 listener
-> absent
```

Therefore firewall state and service state must be evaluated separately.

---

## `inactive` Is Not the Same as `failed`

Nginx was:

```text
inactive
```

but:

```bash
systemctl --failed
```

continued reporting:

```text
0 loaded units listed.
```

This demonstrates why a health check cannot rely exclusively on the failed-units list.

---

## Direct Backend Testing Is Valuable

Testing:

```bash
curl http://127.0.0.1:8000/health
```

made it possible to prove the application was healthy independently of Nginx.

Without this test, an operator might incorrectly restart the application.

---

## Layer-Specific Monitoring Improves Diagnosis

The simultaneous result:

```text
nginx_service
FAIL

application_health
PASS
```

provides substantially more operational information than a single generic availability probe.

---

## Recovery Should Be Minimal

Because the fault was isolated to Nginx, the appropriate recovery was:

```bash
sudo systemctl start nginx
```

Recovering only the affected component reduces unnecessary changes during an incident.

---

# Acceptance Criteria Verification

- [x] FR-35 through FR-40 mapped to the scenario.
- [x] Healthy Nginx state documented before failure.
- [x] Healthy application state documented before failure.
- [x] Host Nginx intentionally stopped.
- [x] No destructive Nginx configuration change used.
- [x] `nginx.service` became inactive.
- [x] TCP `80` listener disappeared.
- [x] Host HTTP request became unavailable.
- [x] Direct backend `/health` remained HTTP 200.
- [x] Application container remained running.
- [x] Backend `127.0.0.1:8000` remained listening.
- [x] SentinelOps monitoring detected Nginx failure.
- [x] `nginx_service` recorded FAIL / CRITICAL.
- [x] `host_nginx_health` recorded FAIL / CRITICAL.
- [x] Docker remained PASS.
- [x] Compose application remained PASS.
- [x] Application health remained PASS.
- [x] SSH remained PASS.
- [x] Structured monitoring evidence captured.
- [x] Failure correctly diagnosed as host Nginx failure.
- [x] Nginx configuration remained valid.
- [x] Nginx recovered using systemd.
- [x] TCP `80` listener returned.
- [x] Host `/health` returned HTTP 200 after recovery.
- [x] Direct backend `/health` remained HTTP 200 after recovery.
- [x] Application version remained `0.1.0`.
- [x] Monitoring returned to PASS.
- [x] Structured monitoring recorded recovered PASS state.
- [x] Docker remained active.
- [x] SSH remained active.
- [x] `systemctl --failed` reported no unexpected failed units.
- [x] UFW configuration remained unchanged.
- [x] TCP `22` remained allowed.
- [x] TCP `80` remained allowed.
- [x] No external TCP `8000` rule introduced.
- [x] Backend remained bound to `127.0.0.1:8000`.
- [x] Prevention and resilience controls documented.
- [x] Recovery steps documented.
- [x] No credentials, private keys, tokens, or secrets documented.

Git diff checks are completed during the repository validation and commit stage.

---

# Final Verified State

At completion of the live simulation:

```text
nginx.service
active

docker.service
active

ssh.socket
active

sentinelops-app
running

TCP 22
listening

TCP 80
listening

127.0.0.1:8000
listening

direct backend health
HTTP 200

host proxied health
HTTP 200

application status
healthy

application version
0.1.0

nginx configuration
valid

UFW
active

default incoming
deny

external TCP 8000
not allowed

failed systemd units
0
```

Structured monitoring returned to:

```text
docker_service
PASS / INFO

nginx_service
PASS / INFO

ssh_service
PASS / INFO

compose_application
PASS / INFO

application_health
PASS / INFO

host_nginx_health
PASS / INFO
```

The SentinelOps environment was therefore restored to its verified healthy and secure state.

---

# Commands Used

## Healthy Baseline

```bash
systemctl is-active nginx
systemctl is-active docker
systemctl is-active ssh.socket
systemctl --failed

cd /home/emir/sentinelops-app
docker compose ps

curl -i http://127.0.0.1:8000/health
curl -i http://127.0.0.1/health

ss -tulpn | grep -E ':22|:80|:8000'

sudo nginx -t
sudo ufw status verbose

~/sentinelops-monitoring/health-check.sh

grep -E 'check=(docker_service|nginx_service|ssh_service|compose_application|application_health|host_nginx_health)' \
    /var/log/sentinelops/health-check.log | tail -6
```

## Failure Injection

```bash
sudo systemctl stop nginx
```

## Failed-State Verification

```bash
systemctl is-active nginx
systemctl status nginx --no-pager

ss -tulpn | grep -E ':22|:80|:8000'

curl -i http://127.0.0.1:8000/health

curl -i --max-time 5 http://127.0.0.1/health

cd /home/emir/sentinelops-app
docker compose ps

systemctl is-active docker
systemctl is-active ssh.socket
systemctl --failed

~/sentinelops-monitoring/health-check.sh

grep -E 'check=(docker_service|nginx_service|ssh_service|compose_application|application_health|host_nginx_health)' \
    /var/log/sentinelops/health-check.log | tail -6

sudo journalctl -u nginx --since "2026-08-31 23:55:00" --no-pager

sudo ufw status verbose
```

## Formal Diagnosis

```bash
sudo nginx -t

systemctl show nginx \
    -p ActiveState \
    -p SubState \
    -p UnitFileState
```

## Recovery

```bash
sudo systemctl start nginx
```

## Recovery Verification

```bash
systemctl is-active nginx
systemctl status nginx --no-pager

ss -tulpn | grep -E ':22|:80|:8000'

curl -i http://127.0.0.1:8000/health
curl -i http://127.0.0.1/health

~/sentinelops-monitoring/health-check.sh

grep -E 'check=(docker_service|nginx_service|ssh_service|compose_application|application_health|host_nginx_health)' \
    /var/log/sentinelops/health-check.log | tail -6

systemctl --failed

sudo ufw status verbose

sudo journalctl -u nginx --since "2026-08-31 23:55:00" --no-pager
```

---

# Conclusion

SEN-022 successfully demonstrated a controlled failure of the SentinelOps host Nginx reverse proxy.

The test proved that stopping host Nginx caused:

```text
nginx.service
-> inactive

TCP 80
-> unavailable

host HTTP
-> unavailable

host_nginx_health
-> FAIL / CRITICAL
```

while preserving:

```text
Docker
-> healthy

application container
-> healthy

direct backend health
-> HTTP 200

127.0.0.1:8000
-> available locally

SSH
-> healthy

UFW
-> unchanged
```

The monitoring system correctly distinguished the host reverse-proxy failure from an application failure.

Diagnosis confirmed that the Nginx configuration remained valid and that the service was simply inactive.

Recovery required only:

```bash
sudo systemctl start nginx
```

Following recovery:

```text
TCP 80
-> restored

direct /health
-> HTTP 200

proxied /health
-> HTTP 200

application version
-> 0.1.0

monitoring
-> all relevant checks PASS / INFO

UFW
-> unchanged

failed systemd units
-> 0
```

SEN-022 therefore satisfies the intended detection, diagnosis, recovery, restoration, and prevention-documentation objectives for the host reverse-proxy failure scenario.