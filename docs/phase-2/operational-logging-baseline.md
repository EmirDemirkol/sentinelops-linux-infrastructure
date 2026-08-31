# SentinelOps Operational Logging Baseline

## 1. Overview

SEN-020 documents and validates the operational logging baseline for SentinelOps.

The SentinelOps environment already produces useful operational evidence across multiple logging layers:

- systemd journal;
- SSH authentication logs;
- host Nginx access logs;
- host Nginx error logs;
- Docker Compose application logs;
- structured SentinelOps monitoring logs;
- automated backup service logs;
- systemd backup timer state.

Before SEN-020, these logging sources existed and were operational, but they were distributed across different commands and filesystem locations.

SEN-020 consolidates them into one documented operational logging baseline.

No new logging daemon, network service, or unnecessary custom application log file is introduced.

---

## 2. Issue

GitHub issue:

```text
SEN-020: Document operational logging baseline
```

GitHub issue number:

```text
#26
```

Feature branch:

```text
sen-020-operational-logging
```

---

## 3. Requirement Addressed

SEN-020 addresses:

```text
FR-25: Operational Logging
```

The project requires operational logs to be documented and usable across the system.

Relevant sources include:

- system logs;
- authentication logs;
- Nginx access logs;
- Nginx error logs;
- application/container logs;
- SentinelOps monitoring logs;
- backup operational logs.

---

## 4. Objective

The objective of SEN-020 is to document:

- where each operational log source exists;
- what each source records;
- how each source is inspected;
- which permissions protect filesystem-based logs;
- how host and container log sources differ;
- which source should be inspected for common operational failures.

The issue deliberately avoids introducing additional infrastructure where existing logging already satisfies the requirement.

---

## 5. Logging Architecture

The operational logging architecture is:

```text
Ubuntu host
   |
   +--> systemd journal
   |      |
   |      +--> host events
   |      +--> SSH authentication
   |      +--> systemd service events
   |      +--> backup workflow
   |
   +--> /var/log/nginx/
   |      |
   |      +--> access.log
   |      +--> error.log
   |
   +--> Docker Compose
   |      |
   |      +--> container stdout/stderr
   |      +--> container Nginx access activity
   |      +--> container Nginx errors
   |
   +--> /var/log/sentinelops/
          |
          +--> health-check.log
```

---

## 6. System Logging

General host events are available through:

```bash
journalctl
```

Example:

```bash
journalctl -n 30 --no-pager
```

Observed entries included:

- SSH login events;
- PAM session creation;
- systemd-logind activity;
- user session creation;
- systemd user manager startup;
- socket and target initialization.

This confirms systemd-journald is providing normal host operational evidence.

---

## 7. SSH Authentication Logging

SSH authentication events are available using:

```bash
sudo journalctl -u ssh --since "today" --no-pager
```

Current evidence included:

```text
Accepted publickey for emir
```

followed by:

```text
pam_unix(sshd:session): session opened for user emir
```

This confirms successful SSH public-key authentication is observable.

---

## 8. SSH Audit Value

SSH journal entries can be used to investigate:

- successful authentication;
- rejected authentication;
- session creation;
- connection timing;
- SSH service problems.

The current evidence confirms the expected secure public-key administration path.

---

## 9. SSH Socket Journal

The following command was also inspected:

```bash
sudo journalctl -u ssh.socket --since "today" --no-pager
```

It returned:

```text
-- No entries --
```

This is not a failure.

The relevant authentication evidence is currently visible under the SSH service journal.

---

## 10. Host Nginx Logging

Host Nginx writes filesystem-based logs under:

```text
/var/log/nginx/
```

The directory contains:

```text
access.log
error.log
rotated access logs
rotated error logs
```

---

## 11. Host Nginx Access Log

Current path:

```text
/var/log/nginx/access.log
```

Inspection command:

```bash
sudo tail -20 /var/log/nginx/access.log
```

Observed entry:

```text
127.0.0.1 - - [31/Aug/2026:10:34:44 +0000] "GET / HTTP/1.1" 200 1923 "-" "curl/8.5.0"
```

This confirms host Nginx access logging is operational.

---

## 12. Host Nginx Error Log

Current path:

```text
/var/log/nginx/error.log
```

Inspection command:

```bash
sudo tail -20 /var/log/nginx/error.log
```

The current file contained no recent entries.

This is a healthy valid state when no recent host-level Nginx error has occurred.

An empty error log must not be interpreted automatically as a logging failure.

---

## 13. Nginx Log Rotation

The Nginx log directory contained rotated access logs including:

```text
access.log.1
access.log.2.gz
access.log.3.gz
access.log.4.gz
access.log.5.gz
access.log.6.gz
```

This confirms that standard host log rotation is already occurring for Nginx logs.

---

## 14. Host Nginx Log Ownership

The Nginx log directory reported:

```text
owner=root:adm
mode=755
```

---

## 15. Host Nginx Access Log Permissions

The access log reported:

```text
owner=www-data:adm
mode=640
```

---

## 16. Host Nginx Error Log Permissions

The error log reported:

```text
owner=www-data:adm
mode=640
```

---

## 17. Docker / Application Logging

The application is managed using Docker Compose.

Inspection commands:

```bash
cd /home/emir/sentinelops-app
docker compose ps
docker compose logs --tail=30
```

The application container remained:

```text
running
```

with:

```text
127.0.0.1:8000->80/tcp
```

---

## 18. Container Startup Logs

Docker logs included startup information such as:

```text
Configuration complete; ready for start up
```

and:

```text
nginx/1.31.4
```

This provides useful startup and runtime evidence for the containerized application.

---

## 19. Container Access Logging

Docker logs contained application requests including:

```text
GET /health
```

and:

```text
GET /
```

with:

```text
200
```

responses.

Examples included:

```text
GET /health HTTP/1.1" 200
GET / HTTP/1.0" 200
```

---

## 20. Current Application Request Evidence

The final SEN-020 regression generated:

```text
GET /health HTTP/1.1" 200
```

for direct backend access and:

```text
GET /health HTTP/1.0" 200
```

through host Nginx.

These requests appeared in the container log.

---

## 21. Container Error Evidence

The container logs also contained a real error example:

```text
open() "/usr/share/nginx/html/favicon.ico" failed
```

The corresponding request returned:

```text
GET /favicon.ico
404
```

This demonstrates that Docker logs expose not only successful requests but also application/container-level errors.

---

## 22. Host Nginx vs Container Nginx

SentinelOps uses two separate Nginx layers.

### Host Nginx

Runs directly on Ubuntu.

Responsibilities:

- listens on TCP port `80`;
- receives incoming HTTP traffic;
- reverse proxies application requests.

Logging locations:

```text
/var/log/nginx/access.log
/var/log/nginx/error.log
```

### Container Nginx

Runs inside:

```text
sentinelops-app
```

Responsibilities:

- serves the SentinelOps application;
- responds to `/`;
- responds to `/health`.

Logging is accessed using:

```bash
docker compose logs
```

The two log layers must not be confused during incident diagnosis.

---

## 23. Example Host vs Container Error Distinction

The host Nginx error log was empty.

The container logs contained a favicon `404` error.

Therefore:

```text
host Nginx error log empty
```

did not mean:

```text
no application-layer errors exist anywhere
```

The error occurred at the container Nginx layer.

This demonstrates why operators must inspect the correct logging layer.

---

## 24. SentinelOps Structured Monitoring Log

Dedicated monitoring results are stored at:

```text
/var/log/sentinelops/health-check.log
```

---

## 25. Monitoring Log Directory

The monitoring directory reported:

```text
owner=root:emir
mode=750
```

---

## 26. Monitoring Log Permissions

The monitoring log reported:

```text
owner=emir:emir
mode=640
```

---

## 27. Structured Log Format

Monitoring entries use:

```text
timestamp=<UTC> check=<check> status=<PASS|FAIL> severity=<severity> message="<message>"
```

This is distinct from general journal or web access log formats.

---

## 28. Current Structured Checks

Observed checks included:

```text
disk_usage
backup_freshness
docker_service
nginx_service
ssh_service
compose_application
application_health
host_nginx_health
```

---

## 29. Current Monitoring Evidence

The final monitored state included:

```text
disk_usage status=PASS severity=INFO
backup_freshness status=PASS severity=INFO
docker_service status=PASS severity=INFO
nginx_service status=PASS severity=INFO
ssh_service status=PASS severity=INFO
compose_application status=PASS severity=INFO
application_health status=PASS severity=INFO
host_nginx_health status=PASS severity=INFO
```

---

## 30. Monitoring Log Purpose

The structured monitoring log provides a concise operational health history.

It is useful for:

- identifying failed checks;
- reviewing severity;
- determining when a check ran;
- observing health trends;
- correlating checks with broader system events.

---

## 31. Backup Service Logging

Backup operational activity is available using:

```bash
journalctl -u sentinelops-backup.service --no-pager
```

---

## 32. Backup Creation Evidence

The journal records:

```text
Backup created:
```

followed by the archive path.

---

## 33. Backup Size Evidence

The service journal records:

```text
Archive size:
```

and the resulting archive size.

---

## 34. Backup Integrity Logging

After SEN-018, the service journal records:

```text
SHA-256 checksum created:
```

and:

```text
Verifying backup integrity:
```

followed by:

```text
<archive>: OK
```

---

## 35. Backup Manifest Logging

After SEN-019, the service journal records:

```text
Backup manifest created:
```

and:

```text
Verifying backup manifest:
```

followed by:

```text
Backup manifest verification complete.
```

---

## 36. Backup Retention Logging

The service journal records:

```text
Removing backup archives older than 7 days:
```

and:

```text
Backup retention complete.
```

---

## 37. Successful Backup Completion

Successful systemd backup runs conclude with:

```text
Deactivated successfully
```

and:

```text
Finished sentinelops-backup.service
```

---

## 38. Backup Timer Operational Evidence

The backup timer is inspected using:

```bash
systemctl status sentinelops-backup.timer --no-pager
```

The current state was:

```text
enabled
active (waiting)
```

---

## 39. Backup Timer Value

The timer status provides:

- current state;
- next trigger;
- associated service;
- scheduling evidence.

This complements the historical execution evidence in the service journal.

---

## 40. No Dedicated Application File Log

Inspection of:

```text
/home/emir/sentinelops-app
```

showed only:

```text
compose.yaml
Dockerfile
index.html
```

No dedicated application logfile is configured.

---

## 41. Why No New Application Log File Was Added

A separate logfile is unnecessary for the current application architecture because:

```bash
docker compose logs
```

already exposes the container application's stdout and stderr.

Adding another logfile would duplicate evidence without materially improving the MVP.

---

## 42. Logging Principle

SEN-020 follows:

```text
use existing authoritative log sources
instead of creating duplicate logging systems
```

---

## 43. General Host Investigation

For general host diagnosis:

```bash
journalctl -n 100 --no-pager
```

and:

```bash
systemctl --failed
```

provide useful initial evidence.

---

## 44. SSH Investigation

For SSH problems:

```bash
sudo journalctl -u ssh --since "today" --no-pager
```

Inspect for:

- successful public-key authentication;
- rejected authentication;
- session creation;
- daemon errors.

---

## 45. Host Nginx Investigation

For host reverse-proxy problems:

```bash
sudo tail -50 /var/log/nginx/access.log
sudo tail -50 /var/log/nginx/error.log
```

---

## 46. Application Investigation

For application/container problems:

```bash
cd /home/emir/sentinelops-app
docker compose ps
docker compose logs --tail=100
```

---

## 47. Monitoring Investigation

For SentinelOps monitoring issues:

```bash
tail -100 /var/log/sentinelops/health-check.log
```

---

## 48. Backup Investigation

For backup problems:

```bash
journalctl -u sentinelops-backup.service --no-pager
```

and:

```bash
systemctl status sentinelops-backup.timer --no-pager
```

---

## 49. Final Application Regression

Direct backend health:

```bash
curl -i http://127.0.0.1:8000/health
```

returned:

```text
HTTP/1.1 200 OK
```

with:

```json
{"status":"healthy","version":"0.1.0"}
```

---

## 50. Final Reverse Proxy Regression

Host Nginx health:

```bash
curl -i http://127.0.0.1/health
```

returned:

```text
HTTP/1.1 200 OK
```

with the same application health payload.

---

## 51. Failed Unit Regression

The final check:

```bash
systemctl --failed
```

returned:

```text
0 loaded units listed
```

---

## 52. Backup Timer Regression

The backup timer remained:

```text
enabled
active (waiting)
```

No scheduling change was introduced by SEN-020.

---

## 53. UFW Regression

Final firewall state:

```text
Status: active
```

---

## 54. Default Firewall Policy

The default incoming policy remained:

```text
deny
```

---

## 55. Allowed Ports

UFW continued to allow:

```text
22/tcp
80/tcp
```

including the corresponding IPv6 rules.

---

## 56. Port 8000 Isolation

No UFW allow rule was introduced for:

```text
8000/tcp
```

---

## 57. Listener Regression

The final listener check showed:

```text
127.0.0.1:8000
0.0.0.0:80
0.0.0.0:22
[::]:80
[::]:22
```

---

## 58. Backend Isolation

The application backend remains bound to:

```text
127.0.0.1:8000
```

It is not exposed on:

```text
0.0.0.0:8000
```

---

## 59. Network Impact

SEN-020 introduces:

```text
no new daemon
no new listener
no new port
no new firewall rule
```

---

## 60. Filesystem Log Permission Baseline

Verified:

```text
/var/log/sentinelops
owner=root:emir
mode=750
```

```text
/var/log/sentinelops/health-check.log
owner=emir:emir
mode=640
```

```text
/var/log/nginx
owner=root:adm
mode=755
```

```text
/var/log/nginx/access.log
owner=www-data:adm
mode=640
```

```text
/var/log/nginx/error.log
owner=www-data:adm
mode=640
```

---

## 61. Operational Logging Coverage

The final coverage is:

```text
system activity
-> systemd journal

SSH authentication
-> systemd journal / ssh unit

host HTTP requests
-> /var/log/nginx/access.log

host Nginx errors
-> /var/log/nginx/error.log

container/application activity
-> docker compose logs

structured SentinelOps health
-> /var/log/sentinelops/health-check.log

backup activity
-> sentinelops-backup.service journal

backup scheduling
-> sentinelops-backup.timer state
```

---

## 62. Logging Limitations

SEN-020 does not provide:

- centralized remote logging;
- SIEM integration;
- external log shipping;
- distributed log aggregation;
- Grafana;
- Loki;
- Elastic Stack;
- Splunk;
- long-term remote retention;
- automated alerting from logs.

These remain outside the local MVP.

---

## 63. Same-Host Logging Limitation

Most logs remain on the same SentinelOps host.

A catastrophic host loss could therefore remove both the system and its local logging history.

This is an accepted MVP limitation.

---

## 64. Container Logging Limitation

Container logs are currently accessed through Docker.

SEN-020 does not introduce a separate persistent application logfile.

---

## 65. Host Nginx Error Log Limitation

A currently empty host Nginx error log proves only that no recent events are recorded there.

It does not prove that every application layer is error-free.

Container logs must also be inspected.

---

## 66. Security Preservation

The established security architecture remains:

```text
SSH public-key authentication
password SSH disabled
direct root SSH disabled
UFW active
default deny incoming
22/tcp allowed
80/tcp allowed
no external 8000/tcp
backend loopback-only
host Nginx reverse proxy
Docker Compose application
```

---

## 67. Acceptance Criteria Verification

### FR-25 documented

Verified.

### System logging documented

Verified.

### SSH logging documented

Verified.

### Host Nginx access logging documented

Verified.

### Host Nginx error logging documented

Verified.

### Docker/application logging documented

Verified.

### SentinelOps structured monitoring documented

Verified.

### Backup service logging documented

Verified.

### Backup timer operational evidence documented

Verified.

### Host and container Nginx distinguished

Verified.

### Live logging commands tested

Verified.

### SSH public-key events observable

Verified.

### Host Nginx access events observable

Verified.

### Docker application requests observable

Verified.

### Container errors observable

Verified.

### Structured monitoring entries observable

Verified.

### Backup creation observable

Verified.

### Manifest generation observable

Verified.

### Checksum verification observable

Verified.

### Log ownership documented

Verified.

### Log permissions documented

Verified.

### Empty host Nginx error log interpreted correctly

Verified.

### No unnecessary custom application logfile

Verified.

### No new logging daemon

Verified.

### No new network listener

Verified.

### UFW active

Verified.

### Default incoming deny

Verified.

### TCP 22 allowed

Verified.

### TCP 80 allowed

Verified.

### TCP 8000 remains private

Verified.

### Backend loopback-only

Verified.

### Application health operational

Verified.

### Backup freshness operational

Verified.

---

## 68. Commands Used During SEN-020

General journal:

```bash
journalctl -n 30 --no-pager
```

SSH journal:

```bash
sudo journalctl -u ssh --since "today" --no-pager
```

SSH socket journal:

```bash
sudo journalctl -u ssh.socket --since "today" --no-pager
```

Nginx log inventory:

```bash
ls -lh /var/log/nginx/
```

Nginx access inspection:

```bash
sudo tail -20 /var/log/nginx/access.log
```

Nginx error inspection:

```bash
sudo tail -20 /var/log/nginx/error.log
```

Docker status:

```bash
cd /home/emir/sentinelops-app
docker compose ps
```

Docker logs:

```bash
docker compose logs --tail=30
```

Monitoring inventory:

```bash
ls -lh /var/log/sentinelops/
```

Monitoring log inspection:

```bash
tail -20 /var/log/sentinelops/health-check.log
```

Backup journal:

```bash
journalctl -u sentinelops-backup.service --since "2026-08-30 00:00:00" --no-pager
```

Backup timer:

```bash
systemctl status sentinelops-backup.timer --no-pager
```

Application file inventory:

```bash
find /home/emir/sentinelops-app \
    -maxdepth 2 \
    -type f \
    -print
```

Logging configuration search:

```bash
grep -RniE 'log|access_log|error_log' \
    /home/emir/sentinelops-app \
    /etc/nginx/sites-available/sentinelops \
    2>/dev/null
```

Filesystem log permissions:

```bash
stat -c '%n | owner=%U:%G | mode=%a' \
    /var/log/sentinelops \
    /var/log/sentinelops/health-check.log \
    /var/log/nginx \
    /var/log/nginx/access.log \
    /var/log/nginx/error.log
```

Backend health:

```bash
curl -i http://127.0.0.1:8000/health
```

Host proxy health:

```bash
curl -i http://127.0.0.1/health
```

Failed units:

```bash
systemctl --failed
```

Final monitoring evidence:

```bash
tail -8 /var/log/sentinelops/health-check.log
```

Firewall:

```bash
sudo ufw status verbose
```

Listeners:

```bash
ss -tulpn | grep -E ':22|:80|:8000'
```

Final SSH evidence:

```bash
sudo journalctl -u ssh --since "today" --no-pager | tail -10
```

Final Docker evidence:

```bash
cd /home/emir/sentinelops-app
docker compose logs --tail=10
```

---

## 69. SEN-020 Completion State

Before SEN-020:

```text
system logging -> operational
SSH logging -> operational
host Nginx logging -> operational
Docker/application logging -> operational
structured monitoring logging -> operational
backup logging -> operational
central operational logging documentation -> incomplete
```

After SEN-020:

```text
system logging -> documented
SSH logging -> documented
host Nginx logging -> documented
Docker/application logging -> documented
structured monitoring logging -> documented
backup logging -> documented
operational investigation commands -> documented
permissions -> documented
logging architecture -> documented
```

No new logging service was required.

No new application logfile was required.

No network exposure changed.

The application remains healthy.

The backup timer remains active.

Structured monitoring remains operational.

The firewall remains secure.

SEN-020 is ready for repository validation, commit, pull request, review, merge, and issue closure.