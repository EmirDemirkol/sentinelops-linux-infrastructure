# SentinelOps Structured Monitoring Baseline

## 1. Overview

SEN-016 extends the existing SentinelOps monitoring workflow with persistent structured monitoring logs and threshold-based disk evaluation.

Before this issue, the monitoring script already provided useful interactive visibility into:

- host uptime and load;
- memory usage;
- filesystem usage;
- failed systemd units;
- Docker state;
- Nginx state;
- SSH state;
- Docker Compose application state;
- container resource usage;
- application `/health`;
- host Nginx reachability;
- listening TCP ports;
- UFW state.

However, the monitoring results existed only in terminal output.

There was no dedicated SentinelOps monitoring log location, no persistent structured monitoring history, and no threshold evaluation for root filesystem usage.

SEN-016 adds:

- `/var/log/sentinelops`;
- `/var/log/sentinelops/health-check.log`;
- controlled ownership and permissions;
- structured line-oriented monitoring entries;
- UTC timestamps;
- named checks;
- PASS/FAIL status;
- INFO/WARNING/CRITICAL severity;
- useful human-readable messages;
- root filesystem warning and critical thresholds;
- repeat-run append behaviour;
- preservation of the existing interactive monitoring output;
- preservation of the existing network and security architecture.

---

## 2. Issue

GitHub issue:

```text
SEN-016: Implement structured monitoring logs and thresholds
```

Feature branch:

```text
sen-016-structured-monitoring
```

---

## 3. Objective

The objective of SEN-016 is to make SentinelOps monitoring results persistent, structured, and operationally useful.

The implementation must provide:

- a dedicated monitoring log directory;
- a dedicated health-check log file;
- structured monitoring entries;
- persistent append behaviour;
- UTC timestamps;
- named checks;
- pass/fail state;
- severity state;
- readable messages;
- disk threshold evaluation;
- continued application-health monitoring;
- continued host and service checks;
- no new public network service;
- no new firewall rule;
- no weakening of existing permissions or security controls.

---

## 4. Requirements Addressed

SEN-016 directly addresses the following established SentinelOps requirements:

```text
FR-19: Disk Monitoring
FR-23: Monitoring Logs
FR-24: Monitoring Result Format
```

The issue also contributes to the broader operational logging requirement:

```text
FR-25: Operational Logging
```

The requirements establish that monitoring should do more than print raw command output.

Monitoring results must provide enough information to identify:

- when a check occurred;
- what was checked;
- whether it passed or failed;
- severity where appropriate;
- a useful message.

SEN-016 implements this as a dedicated structured monitoring log.

---

## 5. Architecture Before SEN-016

Before SEN-016, the application and monitoring architecture was:

```text
Mac
 |
 | HTTP :80
 v
Ubuntu Server VM
 |
 v
UFW
 |
 v
host Nginx
 |
 v
127.0.0.1:8000
 |
 v
Docker Compose
 |
 v
sentinelops-app
 |
 v
/health
```

Monitoring was performed using:

```text
/home/emir/sentinelops-monitoring/health-check.sh
```

The script wrote only to:

```text
stdout / terminal
```

There was no dedicated monitoring log persistence layer.

---

## 6. Initial Monitoring Script Behaviour

Before SEN-016, the script displayed:

```text
SentinelOps Health Check
Timestamp
Host uptime/load
Memory
Filesystem
Failed systemd units
Service health
Compose application
Container resource usage
Application health
Host Nginx health
Listening TCP ports
UFW
```

This was useful during manual administration but created no persistent SentinelOps-specific monitoring history.

Once the terminal output was gone, the result of the monitoring run was no longer available.

---

## 7. Initial Log State

Before implementation, the following check was performed:

```bash
ls -ld /var/log/sentinelops 2>/dev/null || echo "/var/log/sentinelops does not exist"
```

Result:

```text
/var/log/sentinelops does not exist
```

A second check:

```bash
find /var/log/sentinelops -maxdepth 1 -type f -ls 2>/dev/null
```

returned no files.

This confirmed there was no pre-existing SentinelOps monitoring log directory or dedicated log file.

---

## 8. Existing Monitoring Ownership

The monitoring directory was inspected using:

```bash
ls -ld ~/sentinelops-monitoring
```

The monitoring directory was owned by:

```text
emir:emir
```

with normal directory permissions.

The script:

```text
/home/emir/sentinelops-monitoring/health-check.sh
```

was also owned by:

```text
emir:emir
```

and was executable.

---

## 9. User Context

The monitoring workflow runs under the normal SentinelOps administrative user:

```text
emir
```

The user was confirmed using:

```bash
whoami
```

Result:

```text
emir
```

User identity and groups were inspected before choosing the log ownership model.

This allowed the logging implementation to avoid running the entire monitoring workflow as root.

---

## 10. `/var/log` Parent State

The parent logging directory:

```text
/var/log
```

was inspected before creating SentinelOps-specific logging.

This confirmed the implementation would be placed under the standard Linux log hierarchy rather than creating an arbitrary logging location inside the user's home directory.

---

## 11. Log Ownership Design

The following ownership model was selected:

```text
/var/log/sentinelops
owner: root
group: emir
mode: 750
```

and:

```text
/var/log/sentinelops/health-check.log
owner: emir
group: emir
mode: 640
```

This separates directory control from file append ownership.

---

## 12. Directory Security Model

The directory mode:

```text
750
```

means:

```text
owner root:
    read
    write
    execute

group emir:
    read
    execute

others:
    no access
```

The directory is therefore not world-writable.

The normal monitoring user can access the directory but cannot arbitrarily restructure ownership or permissions as root.

---

## 13. Log File Security Model

The health-check log mode:

```text
640
```

means:

```text
owner emir:
    read
    write

group emir:
    read

others:
    no access
```

This allows the normal monitoring script to append records without requiring root privileges.

Other users receive no access through the Unix permission model.

---

## 14. Monitoring Directory Creation

The directory was created using:

```bash
sudo install -d -o root -g emir -m 0750 /var/log/sentinelops
```

This creates the directory with ownership and permissions atomically.

The resulting state was verified using:

```bash
ls -ld /var/log/sentinelops
```

Result:

```text
drwxr-x--- root emir /var/log/sentinelops
```

---

## 15. Monitoring Log Creation

The log file was created using:

```bash
sudo install -o emir -g emir -m 0640 /dev/null /var/log/sentinelops/health-check.log
```

The resulting file state was verified using:

```bash
ls -l /var/log/sentinelops/health-check.log
```

Result:

```text
-rw-r----- emir emir /var/log/sentinelops/health-check.log
```

---

## 16. Write Permission Verification

Normal-user write access was explicitly tested using:

```bash
test -w /var/log/sentinelops/health-check.log && echo "emir can write to monitoring log"
```

Result:

```text
emir can write to monitoring log
```

This proved that the script could persist monitoring entries without using root privileges for logging.

---

## 17. Structured Monitoring Design

SEN-016 introduces a line-oriented structured monitoring format.

Each entry follows the model:

```text
timestamp=<UTC timestamp> check=<check-name> status=<PASS|FAIL> severity=<INFO|WARNING|CRITICAL> message="<human-readable message>"
```

Example:

```text
timestamp=2026-08-30T11:28:13Z check=application_health status=PASS severity=INFO message="Application health endpoint returned HTTP 200"
```

This format is intentionally simple and readable by both humans and future automation.

---

## 18. Structured Fields

Each persisted result contains:

```text
timestamp
check
status
severity
message
```

These fields satisfy the requirement that monitoring results identify:

- when the event occurred;
- which check produced the result;
- whether the result passed or failed;
- operational severity;
- useful context.

---

## 19. Timestamp Standard

Structured monitoring uses UTC timestamps.

The timestamp command is:

```bash
date -u +%Y-%m-%dT%H:%M:%SZ
```

Example:

```text
2026-08-30T11:28:13Z
```

This avoids ambiguity between local time zones and provides a consistent log format.

---

## 20. Log File Variable

The script now defines:

```bash
LOG_FILE="/var/log/sentinelops/health-check.log"
```

All structured monitoring results are appended to this file.

---

## 21. Disk Threshold Policy

SEN-016 establishes explicit root filesystem thresholds.

The selected values are:

```text
warning threshold: 80%
critical threshold: 90%
```

This creates three operating states.

---

## 22. Normal Disk State

When root filesystem usage is:

```text
below 80%
```

the result is:

```text
status=PASS
severity=INFO
```

Example:

```text
48% -> PASS / INFO
```

---

## 23. Warning Disk State

When root filesystem usage is:

```text
80% to 89%
```

the result is:

```text
status=PASS
severity=WARNING
```

This indicates that the host remains operational but requires attention.

Example:

```text
85% -> PASS / WARNING
```

---

## 24. Critical Disk State

When root filesystem usage is:

```text
90% or greater
```

the result is:

```text
status=FAIL
severity=CRITICAL
```

Example:

```text
92% -> FAIL / CRITICAL
```

This provides a clear operational failure state before complete disk exhaustion.

---

## 25. Threshold Variables

The monitoring script defines:

```bash
DISK_WARNING_THRESHOLD=80
DISK_CRITICAL_THRESHOLD=90
```

These values are centralized near the beginning of the script.

---

## 26. Root Filesystem Usage Collection

Root filesystem usage is collected using:

```bash
df -P /
```

and parsed using:

```bash
awk 'NR==2 {gsub(/%/, "", $5); print $5}'
```

The resulting value contains only the numeric filesystem usage percentage.

For example:

```text
48
```

rather than:

```text
48%
```

This allows numeric threshold comparison.

---

## 27. Disk Evaluation Logic

The threshold order is:

```text
critical first
warning second
normal otherwise
```

This prevents a critical value from being incorrectly classified as merely warning.

Conceptually:

```bash
if usage >= 90
    critical
elif usage >= 80
    warning
else
    normal
```

---

## 28. Structured Logging Function

The monitoring script introduces:

```bash
log_result()
```

The function accepts:

```text
check_name
status
severity
message
```

It generates its own UTC timestamp and appends the result to the log file.

---

## 29. Logging Function Implementation

The structured logging function is:

```bash
log_result() {
    local check_name="$1"
    local status="$2"
    local severity="$3"
    local message="$4"
    local timestamp

    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    printf 'timestamp=%s check=%s status=%s severity=%s message="%s"\n' \
        "$timestamp" \
        "$check_name" \
        "$status" \
        "$severity" \
        "$message" \
        >> "$LOG_FILE"
}
```

The `>>` operator is important.

It appends rather than overwrites.

---

## 30. Existing Interactive Output Preserved

SEN-016 does not replace the existing terminal-oriented monitoring workflow.

The script still prints:

- host metrics;
- service state;
- Compose state;
- container metrics;
- application health;
- host Nginx health;
- ports;
- firewall state.

Structured logging is added alongside the existing interactive output.

---

## 31. Service Monitoring Improvement

Docker, Nginx, and SSH checks now produce structured results.

Docker success example:

```text
check=docker_service status=PASS severity=INFO message="Docker service is active"
```

Nginx success example:

```text
check=nginx_service status=PASS severity=INFO message="Nginx service is active"
```

SSH success example:

```text
check=ssh_service status=PASS severity=INFO message="SSH socket is active"
```

---

## 32. Service Failure Model

If one of the monitored services is inactive, the script records:

```text
status=FAIL
severity=CRITICAL
```

This gives future failure simulation work a clear structured failure signal.

---

## 33. Compose Application Logging

The Compose service state is evaluated using:

```bash
docker compose ps --status running --services
```

The script checks for:

```text
app
```

If present, the structured result is:

```text
check=compose_application status=PASS severity=INFO
```

Otherwise:

```text
check=compose_application status=FAIL severity=CRITICAL
```

---

## 34. Application Health Logging

SEN-015 previously introduced the dedicated application endpoint:

```text
/health
```

SEN-016 now persists its monitoring result.

The script obtains the HTTP status code from:

```text
http://127.0.0.1:8000/health
```

A healthy response produces:

```text
check=application_health status=PASS severity=INFO
```

with:

```text
Application health endpoint returned HTTP 200
```

---

## 35. Application Failure Model

Any response other than:

```text
HTTP 200
```

produces:

```text
status=FAIL
severity=CRITICAL
```

The returned or fallback HTTP code is included in the message.

---

## 36. Host Nginx Logging

Host Nginx is independently checked through:

```text
http://127.0.0.1
```

Healthy state produces:

```text
check=host_nginx_health status=PASS severity=INFO
```

This preserves the separation between:

```text
application health
```

and:

```text
reverse proxy health
```

---

## 37. Final Structured Check Set

The initial SEN-016 structured log records seven checks per healthy run:

```text
disk_usage
docker_service
nginx_service
ssh_service
compose_application
application_health
host_nginx_health
```

Other interactive information remains available in terminal output but is not yet represented as dedicated structured entries.

---

## 38. Final Monitoring Script

The final live monitoring script is:

```bash
#!/usr/bin/env bash

LOG_FILE="/var/log/sentinelops/health-check.log"
DISK_WARNING_THRESHOLD=80
DISK_CRITICAL_THRESHOLD=90

log_result() {
    local check_name="$1"
    local status="$2"
    local severity="$3"
    local message="$4"
    local timestamp

    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    printf 'timestamp=%s check=%s status=%s severity=%s message="%s"\n' \
        "$timestamp" \
        "$check_name" \
        "$status" \
        "$severity" \
        "$message" \
        >> "$LOG_FILE"
}

echo "========================================"
echo " SentinelOps Health Check"
echo "========================================"
echo

echo "Timestamp:"
date
echo

echo "=== HOST UPTIME / LOAD ==="
uptime
echo

echo "=== MEMORY ==="
free -h
echo

echo "=== FILESYSTEM ==="
df -h /
echo

echo "=== DISK THRESHOLD CHECK ==="

DISK_USAGE="$(df -P / | awk 'NR==2 {gsub(/%/, "", $5); print $5}')"

if (( DISK_USAGE >= DISK_CRITICAL_THRESHOLD )); then
    echo "CRITICAL: Root filesystem usage is ${DISK_USAGE}%"
    log_result \
        "disk_usage" \
        "FAIL" \
        "CRITICAL" \
        "Root filesystem usage is ${DISK_USAGE}%, at or above critical threshold of ${DISK_CRITICAL_THRESHOLD}%"
elif (( DISK_USAGE >= DISK_WARNING_THRESHOLD )); then
    echo "WARNING: Root filesystem usage is ${DISK_USAGE}%"
    log_result \
        "disk_usage" \
        "PASS" \
        "WARNING" \
        "Root filesystem usage is ${DISK_USAGE}%, at or above warning threshold of ${DISK_WARNING_THRESHOLD}%"
else
    echo "OK: Root filesystem usage is ${DISK_USAGE}%"
    log_result \
        "disk_usage" \
        "PASS" \
        "INFO" \
        "Root filesystem usage is ${DISK_USAGE}%, below warning threshold of ${DISK_WARNING_THRESHOLD}%"
fi

echo

echo "=== FAILED SYSTEMD UNITS ==="
systemctl --failed
echo

echo "=== SERVICE HEALTH ==="

printf "Docker: "
if systemctl is-active --quiet docker; then
    echo "active"
    log_result \
        "docker_service" \
        "PASS" \
        "INFO" \
        "Docker service is active"
else
    echo "inactive"
    log_result \
        "docker_service" \
        "FAIL" \
        "CRITICAL" \
        "Docker service is not active"
fi

printf "Nginx:  "
if systemctl is-active --quiet nginx; then
    echo "active"
    log_result \
        "nginx_service" \
        "PASS" \
        "INFO" \
        "Nginx service is active"
else
    echo "inactive"
    log_result \
        "nginx_service" \
        "FAIL" \
        "CRITICAL" \
        "Nginx service is not active"
fi

printf "SSH:    "
if systemctl is-active --quiet ssh.socket; then
    echo "active"
    log_result \
        "ssh_service" \
        "PASS" \
        "INFO" \
        "SSH socket is active"
else
    echo "inactive"
    log_result \
        "ssh_service" \
        "FAIL" \
        "CRITICAL" \
        "SSH socket is not active"
fi

echo

echo "=== COMPOSE APPLICATION ==="
cd /home/emir/sentinelops-app || exit 1
docker compose ps
echo

if docker compose ps --status running --services | grep -qx "app"; then
    log_result \
        "compose_application" \
        "PASS" \
        "INFO" \
        "Compose application service is running"
else
    log_result \
        "compose_application" \
        "FAIL" \
        "CRITICAL" \
        "Compose application service is not running"
fi

echo "=== CONTAINER RESOURCE USAGE ==="
docker stats --no-stream
echo

echo "=== APPLICATION HEALTH ==="

APP_HTTP_CODE="$(curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/health || true)"

if [[ "$APP_HTTP_CODE" == "200" ]]; then
    echo "HTTP 200"
    echo "Application health endpoint reachable"
    log_result \
        "application_health" \
        "PASS" \
        "INFO" \
        "Application health endpoint returned HTTP 200"
else
    echo "HTTP ${APP_HTTP_CODE:-000}"
    echo "Application health check FAILED"
    log_result \
        "application_health" \
        "FAIL" \
        "CRITICAL" \
        "Application health endpoint returned HTTP ${APP_HTTP_CODE:-000}"
fi

echo

echo "=== HOST NGINX HEALTH ==="

NGINX_HTTP_CODE="$(curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1 || true)"

if [[ "$NGINX_HTTP_CODE" == "200" ]]; then
    echo "HTTP 200"
    echo "Nginx reachable"
    log_result \
        "host_nginx_health" \
        "PASS" \
        "INFO" \
        "Host Nginx returned HTTP 200"
else
    echo "HTTP ${NGINX_HTTP_CODE:-000}"
    echo "Nginx health check FAILED"
    log_result \
        "host_nginx_health" \
        "FAIL" \
        "CRITICAL" \
        "Host Nginx returned HTTP ${NGINX_HTTP_CODE:-000}"
fi

echo

echo "=== LISTENING TCP PORTS ==="
ss -tln
echo

echo "=== UFW ==="
sudo ufw status verbose
echo

echo "========================================"
echo " Health Check Complete"
echo "========================================"
```

---

## 39. Shell Syntax Validation

After editing, the script was validated using:

```bash
bash -n ~/sentinelops-monitoring/health-check.sh
```

No output was returned.

This confirms no Bash syntax error was detected.

---

## 40. First Log State

Before the first SEN-016 monitoring run:

```bash
wc -l /var/log/sentinelops/health-check.log
```

returned:

```text
0 /var/log/sentinelops/health-check.log
```

This established a clean initial log state.

---

## 41. First Controlled Monitoring Run

The script was executed using:

```bash
~/sentinelops-monitoring/health-check.sh
```

The run completed successfully.

Current host state included approximately:

```text
root filesystem usage: 48%
```

The threshold output was:

```text
OK: Root filesystem usage is 48%
```

---

## 42. Service State During First Run

The first run reported:

```text
Docker: active
Nginx: active
SSH: active
```

No failed systemd units were reported.

---

## 43. Application State During First Run

The Compose application remained:

```text
sentinelops-app
```

with:

```text
127.0.0.1:8000->80/tcp
```

The container remained in an:

```text
Up
```

state.

---

## 44. Application Health During First Run

The application health section returned:

```text
HTTP 200
Application health endpoint reachable
```

This was persisted as:

```text
check=application_health status=PASS severity=INFO
```

---

## 45. Host Nginx Health During First Run

The host Nginx section returned:

```text
HTTP 200
Nginx reachable
```

This was persisted as:

```text
check=host_nginx_health status=PASS severity=INFO
```

---

## 46. First Structured Log Contents

After the first monitoring run:

```bash
cat /var/log/sentinelops/health-check.log
```

returned:

```text
timestamp=2026-08-30T11:28:11Z check=disk_usage status=PASS severity=INFO message="Root filesystem usage is 48%, below warning threshold of 80%"
timestamp=2026-08-30T11:28:11Z check=docker_service status=PASS severity=INFO message="Docker service is active"
timestamp=2026-08-30T11:28:11Z check=nginx_service status=PASS severity=INFO message="Nginx service is active"
timestamp=2026-08-30T11:28:11Z check=ssh_service status=PASS severity=INFO message="SSH socket is active"
timestamp=2026-08-30T11:28:12Z check=compose_application status=PASS severity=INFO message="Compose application service is running"
timestamp=2026-08-30T11:28:13Z check=application_health status=PASS severity=INFO message="Application health endpoint returned HTTP 200"
timestamp=2026-08-30T11:28:13Z check=host_nginx_health status=PASS severity=INFO message="Host Nginx returned HTTP 200"
```

---

## 47. First Log Line Count

After the first run:

```bash
wc -l /var/log/sentinelops/health-check.log
```

returned:

```text
7 /var/log/sentinelops/health-check.log
```

This matches the seven structured checks implemented in SEN-016.

---

## 48. First Log Permissions Verification

The log file remained:

```text
-rw-r----- emir emir
```

after the script appended entries.

This proves normal logging activity did not alter the intended permissions.

---

## 49. Second Controlled Monitoring Run

The monitoring script was executed a second time.

The second run again reported healthy infrastructure state.

The root filesystem remained:

```text
48%
```

and therefore remained:

```text
PASS / INFO
```

---

## 50. Append Behaviour Verification

After the second run:

```bash
wc -l /var/log/sentinelops/health-check.log
```

returned:

```text
14 /var/log/sentinelops/health-check.log
```

This proves the second run appended seven new entries rather than overwriting the original seven.

---

## 51. Second-Run Structured Entries

The newest seven entries were inspected using:

```bash
tail -n 7 /var/log/sentinelops/health-check.log
```

The entries had later UTC timestamps:

```text
2026-08-30T11:29:33Z
2026-08-30T11:29:34Z
2026-08-30T11:29:35Z
```

This proves the log contains results from multiple independent monitoring runs.

---

## 52. Log Growth Verification

The log file grew from approximately:

```text
865 bytes
```

after the first run to approximately:

```text
1730 bytes
```

after the second run.

This is consistent with append-only behaviour during these tests.

---

## 53. Permission Persistence

After repeated runs:

```text
/var/log/sentinelops
```

remained:

```text
root:emir
750
```

and:

```text
/var/log/sentinelops/health-check.log
```

remained:

```text
emir:emir
640
```

No permissions drift occurred.

---

## 54. Threshold Configuration Verification

Threshold values were directly inspected using:

```bash
grep -nE 'DISK_WARNING_THRESHOLD|DISK_CRITICAL_THRESHOLD' ~/sentinelops-monitoring/health-check.sh
```

The script confirmed:

```text
DISK_WARNING_THRESHOLD=80
DISK_CRITICAL_THRESHOLD=90
```

The expected comparison branches were also present.

---

## 55. Safe Threshold Branch Testing

The warning and critical branches were tested without filling the actual filesystem.

A standalone arithmetic test used:

```text
48
85
92
```

as representative usage values.

This avoided any destructive disk-fill simulation.

---

## 56. Threshold Branch Results

The safe test produced:

```text
48% -> status=PASS severity=INFO
85% -> status=PASS severity=WARNING
92% -> status=FAIL severity=CRITICAL
```

This confirms that all three threshold states behave as designed.

---

## 57. Why Disk Filling Was Not Used

It was unnecessary and unsafe to intentionally consume enough disk space to reach:

```text
80%
```

or:

```text
90%
```

on the live SentinelOps VM merely to prove arithmetic branch logic.

The implementation therefore validated:

- real current usage;
- configured thresholds;
- real normal-state path;
- standalone warning branch;
- standalone critical branch.

Controlled infrastructure failure simulation belongs to later SentinelOps work.

---

## 58. Runtime Security Regression

After the monitoring changes, application health was rechecked.

Private backend:

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

## 59. Host Nginx Regression

The health endpoint through host Nginx:

```bash
curl -i http://127.0.0.1/health
```

returned:

```text
HTTP/1.1 200 OK
```

with:

```json
{"status":"healthy","version":"0.1.0"}
```

SEN-016 therefore did not disrupt the application-health baseline.

---

## 60. Compose Regression

The Compose application was checked using:

```bash
docker compose -f ~/sentinelops-app/compose.yaml ps
```

The container remained:

```text
sentinelops-app
```

and remained:

```text
Up
```

with the port mapping:

```text
127.0.0.1:8000->80/tcp
```

---

## 61. UFW Regression

UFW remained:

```text
Status: active
```

with:

```text
Default: deny (incoming)
```

Allowed inbound services remained:

```text
22/tcp
80/tcp
```

No TCP `8000` allow rule was introduced.

---

## 62. Listener Regression

The following listener inspection was performed:

```bash
ss -tulpn | grep -E ':22|:80|:8000'
```

Relevant results remained:

```text
127.0.0.1:8000
0.0.0.0:80
0.0.0.0:22
[::]:80
[::]:22
```

This confirms no monitoring service or new public listener was introduced.

---

## 63. Monitoring Network Impact

SEN-016 adds no network daemon.

It creates:

```text
directory
log file
script logic
```

only.

There is no new:

- TCP listener;
- UDP listener;
- firewall rule;
- public endpoint;
- external agent;
- monitoring server.

---

## 64. Application Version Preservation

The application remained at:

```text
0.1.0
```

SEN-016 did not modify the application version or application image.

---

## 65. Final Monitoring Architecture

After SEN-016:

```text
                          Ubuntu Server
                               |
                               v
                  health-check.sh
                               |
            +------------------+------------------+
            |                  |                  |
            v                  v                  v
       host checks        service checks    app checks
            |                  |                  |
            +------------------+------------------+
                               |
                               v
                    structured result
                               |
                               v
              /var/log/sentinelops/
                               |
                               v
                  health-check.log
```

The existing interactive terminal output remains available in parallel.

---

## 66. Structured Monitoring Flow

A typical application-health result now follows:

```text
health-check.sh
      |
      v
curl 127.0.0.1:8000/health
      |
      v
HTTP 200
      |
      v
PASS / INFO
      |
      v
UTC timestamp
      |
      v
/var/log/sentinelops/health-check.log
```

---

## 67. Disk Monitoring Flow

Root disk monitoring now follows:

```text
df -P /
   |
   v
extract numeric use%
   |
   v
compare against 80 / 90
   |
   +---- <80 -> PASS / INFO
   |
   +---- 80-89 -> PASS / WARNING
   |
   +---- >=90 -> FAIL / CRITICAL
   |
   v
structured log entry
```

---

## 68. Security State After SEN-016

Final security state remains:

```text
SSH:
    public-key authentication retained
    password authentication disabled
    direct root login disabled

UFW:
    active
    default incoming deny
    22/tcp allowed
    80/tcp allowed
    no 8000/tcp allow rule

Application:
    127.0.0.1:8000 backend
    host Nginx public entry point
    /health HTTP 200
    version 0.1.0

Monitoring:
    no network daemon
    /var/log/sentinelops root-controlled
    log file not world-readable
    log file not world-writable
```

---

## 69. Logging Security Review

The structured log currently records:

- disk usage percentage;
- service health state;
- Compose application state;
- HTTP status codes;
- simple operational messages.

It does not intentionally record:

- passwords;
- SSH keys;
- API keys;
- secrets;
- tokens;
- environment variables;
- application credentials.

---

## 70. Current Healthy Structured Example

A representative healthy run produces:

```text
timestamp=<UTC> check=disk_usage status=PASS severity=INFO message="Root filesystem usage is 48%, below warning threshold of 80%"
timestamp=<UTC> check=docker_service status=PASS severity=INFO message="Docker service is active"
timestamp=<UTC> check=nginx_service status=PASS severity=INFO message="Nginx service is active"
timestamp=<UTC> check=ssh_service status=PASS severity=INFO message="SSH socket is active"
timestamp=<UTC> check=compose_application status=PASS severity=INFO message="Compose application service is running"
timestamp=<UTC> check=application_health status=PASS severity=INFO message="Application health endpoint returned HTTP 200"
timestamp=<UTC> check=host_nginx_health status=PASS severity=INFO message="Host Nginx returned HTTP 200"
```

---

## 71. Acceptance Criteria Verification

### Dedicated monitoring directory exists

Verified:

```text
/var/log/sentinelops
```

### Dedicated monitoring log exists

Verified:

```text
/var/log/sentinelops/health-check.log
```

### Directory ownership controlled

Verified:

```text
root:emir
```

### Directory mode

Verified:

```text
750
```

### Log ownership

Verified:

```text
emir:emir
```

### Log mode

Verified:

```text
640
```

### Normal monitoring user can write

Verified.

### Structured timestamp present

Verified.

### Structured check name present

Verified.

### Structured status present

Verified.

### Structured severity present

Verified.

### Structured message present

Verified.

### UTC timestamps

Verified.

### Root filesystem evaluated

Verified.

### Warning threshold

Verified:

```text
80%
```

### Critical threshold

Verified:

```text
90%
```

### Current root disk state

Verified:

```text
48% -> PASS / INFO
```

### Warning branch

Verified safely:

```text
85% -> PASS / WARNING
```

### Critical branch

Verified safely:

```text
92% -> FAIL / CRITICAL
```

### Application health monitoring

Verified:

```text
HTTP 200
```

### Host Nginx health monitoring

Verified:

```text
HTTP 200
```

### Docker service monitoring

Verified.

### Nginx service monitoring

Verified.

### SSH monitoring

Verified.

### Compose application monitoring

Verified.

### First structured run

Verified:

```text
7 lines
```

### Second structured run

Verified:

```text
14 lines
```

### Append behaviour

Verified.

### Script syntax

Verified with:

```bash
bash -n
```

### Application version unchanged

Verified:

```text
0.1.0
```

### Backend isolation unchanged

Verified:

```text
127.0.0.1:8000
```

### UFW unchanged

Verified.

### No new listener

Verified.

---

## 72. Limitations

The SEN-016 monitoring system remains intentionally lightweight.

It does not currently include:

- automatic scheduling of the health-check script;
- monitoring log rotation;
- remote log shipping;
- centralized log aggregation;
- external alert delivery;
- metrics storage;
- dashboards;
- historical visualization.

These are not required for this issue.

---

## 73. Log Rotation Limitation

The file:

```text
/var/log/sentinelops/health-check.log
```

currently grows through repeated appends.

No `logrotate` policy is added in SEN-016.

Log rotation was explicitly left out of scope and should be handled as separate work if required.

---

## 74. Scheduling Limitation

SEN-016 verifies the monitoring script manually.

It does not add a new systemd timer or cron schedule for health monitoring.

The focus of this issue is structured persistent logging and threshold evaluation.

Scheduling may be considered independently.

---

## 75. Backup Freshness Limitation

The monitoring script does not yet verify whether SentinelOps backups are recent enough.

Backup freshness is an existing separate requirement and remains future work.

It is intentionally not bundled into SEN-016.

---

## 76. Backup Integrity Limitation

SEN-016 does not add:

- backup manifests;
- checksums;
- corruption detection.

Those belong to backup integrity work rather than structured monitoring logging.

---

## 77. Failure Simulation Limitation

Although the script now has clear structured failure states, SEN-016 does not intentionally stop:

- Docker;
- Nginx;
- SSH;
- the Compose application.

Controlled failure simulations will be implemented separately with proper detection, diagnosis, recovery, and prevention evidence.

---

## 78. Future Operational Value

The structured log provides a foundation for later work including:

- incident investigation;
- failure simulations;
- monitoring automation;
- alerts;
- log parsing;
- dashboards;
- CI validation;
- post-failure evidence.

Because the format is line-oriented and explicit, later tooling can process it without replacing the current monitoring workflow.

---

## 79. Files Changed on the Ubuntu VM

SEN-016 modified:

```text
/home/emir/sentinelops-monitoring/health-check.sh
```

SEN-016 created:

```text
/var/log/sentinelops/
```

and:

```text
/var/log/sentinelops/health-check.log
```

No application file was changed.

No Compose file was changed.

No Nginx file was changed.

No UFW configuration was changed.

No SSH configuration was changed.

No backup configuration was changed.

---

## 80. Repository Documentation

The repository records SEN-016 in:

```text
docs/phase-2/structured-monitoring-baseline.md
```

The live monitoring implementation remains deployed on the Ubuntu VM.

The repository continues to act as the durable implementation and verification record.

---

## 81. Out of Scope

SEN-016 does not implement:

- backup freshness monitoring;
- backup manifests;
- cryptographic backup checksums;
- backup corruption detection;
- backup encryption;
- off-host backups;
- log rotation;
- centralized logging;
- remote log forwarding;
- syslog forwarding;
- journald forwarding;
- external monitoring agents;
- email alerts;
- Slack alerts;
- Prometheus;
- Grafana;
- Loki;
- Elasticsearch;
- Splunk;
- controlled failure simulations;
- incident runbooks;
- GitHub Actions;
- ShellCheck CI;
- automated container CI;
- provisioning automation;
- idempotent provisioning;
- Ansible;
- Terraform;
- cloud deployment;
- HTTPS;
- public DNS.

These remain separate future SentinelOps issues.

---

## 82. Commands Used During SEN-016

Requirements inspection:

```bash
grep -nE 'FR-19|FR-22|FR-23|FR-24|FR-25' docs/phase-0/requirements.md
sed -n '95,140p' docs/phase-0/requirements.md
```

Live monitoring inspection:

```bash
cat ~/sentinelops-monitoring/health-check.sh
```

Existing log state:

```bash
ls -ld /var/log/sentinelops 2>/dev/null || echo "/var/log/sentinelops does not exist"
find /var/log/sentinelops -maxdepth 1 -type f -ls 2>/dev/null
```

User and group inspection:

```bash
id emir
groups emir
whoami
```

Monitoring file ownership inspection:

```bash
ls -ld ~/sentinelops-monitoring
ls -l ~/sentinelops-monitoring/health-check.sh
ls -ld /var/log
```

Log directory creation:

```bash
sudo install -d -o root -g emir -m 0750 /var/log/sentinelops
```

Log file creation:

```bash
sudo install -o emir -g emir -m 0640 /dev/null /var/log/sentinelops/health-check.log
```

Permission verification:

```bash
ls -ld /var/log/sentinelops
ls -l /var/log/sentinelops/health-check.log
test -w /var/log/sentinelops/health-check.log && echo "emir can write to monitoring log"
```

Monitoring script editing:

```bash
nano ~/sentinelops-monitoring/health-check.sh
```

Shell syntax validation:

```bash
bash -n ~/sentinelops-monitoring/health-check.sh
```

Script inspection:

```bash
head -35 ~/sentinelops-monitoring/health-check.sh
tail -35 ~/sentinelops-monitoring/health-check.sh
```

Initial log count:

```bash
wc -l /var/log/sentinelops/health-check.log
```

Monitoring execution:

```bash
~/sentinelops-monitoring/health-check.sh
```

Structured log inspection:

```bash
cat /var/log/sentinelops/health-check.log
tail -n 7 /var/log/sentinelops/health-check.log
```

Threshold configuration inspection:

```bash
grep -nE 'DISK_WARNING_THRESHOLD|DISK_CRITICAL_THRESHOLD' ~/sentinelops-monitoring/health-check.sh
```

Threshold branch test:

```bash
for TEST_USAGE in 48 85 92; do
    if (( TEST_USAGE >= 90 )); then
        echo "${TEST_USAGE}% -> status=FAIL severity=CRITICAL"
    elif (( TEST_USAGE >= 80 )); then
        echo "${TEST_USAGE}% -> status=PASS severity=WARNING"
    else
        echo "${TEST_USAGE}% -> status=PASS severity=INFO"
    fi
done
```

Application verification:

```bash
curl -i http://127.0.0.1:8000/health
curl -i http://127.0.0.1/health
```

Compose verification:

```bash
docker compose -f ~/sentinelops-app/compose.yaml ps
```

Firewall verification:

```bash
sudo ufw status verbose
```

Listener verification:

```bash
ss -tulpn | grep -E ':22|:80|:8000'
```

Git branch verification:

```bash
git branch --show-current
git status
```

---

## 83. SEN-016 Completion State

Before SEN-016:

```text
monitoring output -> terminal only
/var/log/sentinelops -> absent
structured monitoring history -> absent
disk thresholds -> absent
disk usage -> display only
```

After SEN-016:

```text
monitoring output -> terminal + persistent structured log
/var/log/sentinelops -> present
health-check.log -> present
timestamp -> present
check -> present
status -> present
severity -> present
message -> present
warning threshold -> 80%
critical threshold -> 90%
append behaviour -> verified
```

The monitoring system now provides persistent operational evidence while retaining the existing lightweight SentinelOps architecture.

No additional network service was introduced.

No public port was added.

No firewall rule was added.

No application configuration was changed.

No backup configuration was changed.

The application remains healthy at version:

```text
0.1.0
```

The backend remains private on:

```text
127.0.0.1:8000
```

SEN-016 is ready for repository validation, commit, pull request, review, merge, and issue closure.