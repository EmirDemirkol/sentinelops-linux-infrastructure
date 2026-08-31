# SentinelOps Application Container Failure Simulation

## 1. Overview

SEN-021 performs the first controlled SentinelOps failure simulation.

The scenario intentionally stops the `sentinelops-app` Docker Compose service and documents the complete incident lifecycle:

- healthy baseline;
- controlled failure injection;
- failure detection;
- diagnosis;
- recovery;
- recovery verification;
- prevention and resilience considerations.

The simulation validates that the existing SentinelOps monitoring and operational logging architecture can distinguish an application-container failure from failures in Docker, host Nginx, SSH, or the firewall.

---

## 2. Issue

GitHub issue:

```text
SEN-021: Simulate application container failure
```

GitHub issue number:

```text
#28
```

Feature branch:

```text
sen-021-application-container-failure
```

---

## 3. Requirements Addressed

SEN-021 contributes to the controlled failure requirements:

```text
FR-35
At least three controlled infrastructure or application failure simulations shall be performed.

FR-36
Failure detection shall be demonstrated.

FR-37
Diagnosis evidence shall be documented.

FR-38
Recovery steps shall be documented.

FR-39
Restoration of normal service shall be verified.

FR-40
At least one prevention or improvement control shall be documented.
```

SEN-021 is the application-container failure scenario.

---

## 4. Scenario

Normal request path:

```text
Client
  |
  v
Host Nginx :80
  |
  v
127.0.0.1:8000
  |
  v
sentinelops-app
  |
  v
container Nginx :80
```

Controlled failure:

```text
sentinelops-app
-> intentionally stopped
```

Expected result:

```text
Docker daemon
-> remains active

host Nginx
-> remains active

SSH
-> remains active

application container
-> stopped

127.0.0.1:8000
-> unavailable

direct application health
-> unavailable

proxied application request
-> HTTP 502

UFW
-> unchanged
```

---

## 5. Safety Constraints

The simulation was designed to be reversible and non-destructive.

The test did not:

- delete the container;
- delete the Docker image;
- modify `compose.yaml`;
- modify the Dockerfile;
- modify application content;
- modify Nginx configuration;
- modify SSH configuration;
- modify UFW;
- delete backup artifacts;
- alter backup retention;
- alter backup integrity data;
- expose any new port.

The application was stopped using the existing Docker Compose workflow.

---

## 6. Healthy Pre-Failure Baseline

Before failure injection:

```bash
cd /home/emir/sentinelops-app
docker compose ps
```

reported:

```text
sentinelops-app
status: Up
ports: 127.0.0.1:8000->80/tcp
```

---

## 7. Core Service Baseline

The following checks were executed:

```bash
systemctl is-active docker
systemctl is-active nginx
systemctl is-active ssh.socket
systemctl --failed
```

Results:

```text
Docker
active

Nginx
active

SSH
active

failed systemd units
0
```

---

## 8. Backend Health Baseline

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

## 9. Reverse Proxy Health Baseline

Host Nginx health:

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

---

## 10. Application Version Baseline

The application version before failure was:

```text
0.1.0
```

---

## 11. Listener Baseline

The listener check:

```bash
ss -tulpn | grep -E ':22|:80|:8000'
```

showed:

```text
127.0.0.1:8000
0.0.0.0:80
0.0.0.0:22
[::]:80
[::]:22
```

This confirmed:

```text
backend
-> loopback only

HTTP
-> externally reachable through host Nginx

SSH
-> reachable
```

---

## 12. Firewall Baseline

UFW reported:

```text
Status: active
```

Default policy:

```text
deny incoming
```

Allowed inbound services:

```text
22/tcp
80/tcp
```

No rule existed for:

```text
8000/tcp
```

---

## 13. Monitoring Baseline

The SentinelOps health-check script was executed before failure.

Relevant structured entries were:

```text
compose_application status=PASS severity=INFO
application_health status=PASS severity=INFO
host_nginx_health status=PASS severity=INFO
```

---

## 14. Backup Freshness Baseline

Monitoring also reported:

```text
backup_freshness status=PASS severity=INFO
```

The newest backup was within the 36-hour freshness threshold.

---

## 15. Failure Injection

The controlled failure was introduced using:

```bash
docker compose stop app
```

Docker reported:

```text
Container sentinelops-app Stopped
```

---

## 16. Why `docker compose stop` Was Used

`docker compose stop app` was selected because it:

- targets only the application service;
- preserves the container;
- preserves the image;
- preserves configuration;
- does not remove data;
- is immediately reversible.

This makes it suitable for a controlled failure simulation.

---

## 17. Failed Compose State

After the stop:

```bash
docker compose ps -a
```

reported:

```text
sentinelops-app
Exited (0)
```

The exit code was:

```text
0
```

This was expected because the container was intentionally stopped rather than crashing unexpectedly.

---

## 18. Backend Listener Failure

After the container stopped:

```bash
ss -tulpn | grep -E ':22|:80|:8000'
```

showed:

```text
0.0.0.0:80
0.0.0.0:22
[::]:80
[::]:22
```

The listener:

```text
127.0.0.1:8000
```

was absent.

---

## 19. Direct Backend Failure

The direct request:

```bash
curl -i --max-time 5 http://127.0.0.1:8000/health
```

failed with:

```text
curl: (7) Failed to connect to 127.0.0.1 port 8000
```

This confirmed the backend application service was unavailable.

---

## 20. Reverse Proxy Failure

The host request:

```bash
curl -i --max-time 5 http://127.0.0.1/health
```

returned:

```text
HTTP/1.1 502 Bad Gateway
```

The response was generated by:

```text
nginx/1.24.0 (Ubuntu)
```

---

## 21. Meaning of HTTP 502

The HTTP `502 Bad Gateway` response demonstrated that:

```text
host Nginx
-> still running
```

but:

```text
its upstream application
-> unavailable
```

This provided immediate evidence that the problem was downstream of the reverse proxy.

---

## 22. Infrastructure Services During Failure

During the failed application state:

```text
Docker
active

host Nginx
active

SSH
active

failed systemd units
0
```

This ruled out:

- Docker daemon failure;
- host Nginx service failure;
- SSH failure;
- general systemd service failure.

---

## 23. Docker Logs During Failure

The Docker logs showed graceful shutdown activity including:

```text
signal 3 (SIGQUIT) received, shutting down
```

and worker shutdown messages.

This was consistent with an intentional administrative stop.

---

## 24. Monitoring During Failure

The SentinelOps health-check script was executed while the application remained stopped.

The monitor reported:

```text
Docker: active
Nginx: active
SSH: active
```

but the Compose application section showed no running application service.

---

## 25. Application Health Detection

The monitor reported:

```text
HTTP 000
Application health check FAILED
```

because the backend listener was absent.

---

## 26. Host Nginx End-to-End Detection

The monitor reported:

```text
HTTP 502
Nginx health check FAILED
```

This check represents end-to-end HTTP health through host Nginx.

---

## 27. Structured Failure Evidence

Structured monitoring recorded:

```text
check=docker_service
status=PASS
severity=INFO
```

```text
check=nginx_service
status=PASS
severity=INFO
```

```text
check=ssh_service
status=PASS
severity=INFO
```

```text
check=compose_application
status=FAIL
severity=CRITICAL
```

```text
check=application_health
status=FAIL
severity=CRITICAL
```

```text
check=host_nginx_health
status=FAIL
severity=CRITICAL
```

---

## 28. Detection Interpretation

The combination:

```text
docker_service = PASS
nginx_service = PASS
ssh_service = PASS
compose_application = FAIL
application_health = FAIL
host_nginx_health = FAIL
```

provided strong evidence that:

```text
host infrastructure was healthy
```

while:

```text
the application layer was unavailable
```

---

## 29. Service Health vs End-to-End Health

An important distinction was demonstrated:

```text
nginx_service = PASS
```

while:

```text
host_nginx_health = FAIL
```

This is not contradictory.

`nginx_service` answers:

```text
Is the host Nginx process running?
```

`host_nginx_health` answers:

```text
Can a request successfully pass through host Nginx to the application?
```

The service was running, but its upstream dependency was unavailable.

---

## 30. Formal Container Diagnosis

The following command was executed:

```bash
docker inspect sentinelops-app \
    --format 'status={{.State.Status}} exit_code={{.State.ExitCode}} restart_policy={{.HostConfig.RestartPolicy.Name}}'
```

Result:

```text
status=exited
exit_code=0
restart_policy=unless-stopped
```

---

## 31. Container Diagnosis Interpretation

The result established three facts:

```text
status=exited
```

The application container was not running.

```text
exit_code=0
```

The stop was graceful rather than an application crash.

```text
restart_policy=unless-stopped
```

A resilience policy exists for non-administrative container termination.

---

## 32. Docker Daemon Diagnosis

`systemctl status docker` reported:

```text
active (running)
```

The Docker daemon was therefore not the root cause.

---

## 33. Host Nginx Diagnosis

`systemctl status nginx` reported:

```text
active (running)
```

The host reverse-proxy process itself was therefore not the root cause.

---

## 34. Nginx Upstream Error Evidence

The host Nginx error log contained:

```text
connect() failed (111: Connection refused) while connecting to upstream
```

for:

```text
http://127.0.0.1:8000/health
```

and:

```text
http://127.0.0.1:8000/
```

---

## 35. Root Cause

The failure was diagnosed as:

```text
application container intentionally stopped
```

which caused:

```text
127.0.0.1:8000 listener
-> removed
```

which caused:

```text
host Nginx upstream connection
-> refused
```

which caused:

```text
proxied application requests
-> HTTP 502
```

---

## 36. Root Cause Chain

```text
docker compose stop app
        |
        v
sentinelops-app exits
        |
        v
127.0.0.1:8000 disappears
        |
        v
direct /health fails
        |
        v
host Nginx cannot reach upstream
        |
        v
HTTP 502
        |
        v
monitoring records CRITICAL failures
```

---

## 37. Firewall During Failure

UFW remained:

```text
active
```

with:

```text
default deny incoming
```

and only:

```text
22/tcp
80/tcp
```

allowed.

No firewall change caused the incident.

---

## 38. Failure Isolation

The incident was therefore isolated away from:

- Docker daemon;
- host Nginx service;
- SSH;
- UFW;
- backup system;
- systemd host health.

The failed component was:

```text
sentinelops-app
```

---

## 39. Recovery Decision

Because:

- the container still existed;
- the image still existed;
- Compose configuration was unchanged;
- the failure was an intentional stop;

the smallest appropriate recovery action was:

```bash
docker compose start app
```

A rebuild or recreation was unnecessary.

---

## 40. Recovery

The recovery command was:

```bash
cd /home/emir/sentinelops-app
docker compose start app
```

Docker reported:

```text
Container sentinelops-app Started
```

---

## 41. Recovered Compose State

After recovery:

```bash
docker compose ps
```

reported:

```text
sentinelops-app
Up
127.0.0.1:8000->80/tcp
```

---

## 42. Recovered Listener State

The listener check again showed:

```text
127.0.0.1:8000
0.0.0.0:80
0.0.0.0:22
[::]:80
[::]:22
```

The backend listener returned exactly on loopback.

---

## 43. Direct Backend Recovery

After recovery:

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

## 44. Reverse Proxy Recovery

After recovery:

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

---

## 45. Application Version After Recovery

The application version remained:

```text
0.1.0
```

This confirmed that recovery restored the same application state rather than introducing an unintended version change.

---

## 46. Monitoring Recovery

The SentinelOps monitoring script was executed after restoration.

It reported:

```text
Docker: active
Nginx: active
SSH: active
```

and the application was again shown as running.

---

## 47. Structured Recovery Evidence

The recovered structured entries were:

```text
docker_service status=PASS severity=INFO
nginx_service status=PASS severity=INFO
ssh_service status=PASS severity=INFO
compose_application status=PASS severity=INFO
application_health status=PASS severity=INFO
host_nginx_health status=PASS severity=INFO
```

---

## 48. Monitoring State Transition

The simulation therefore demonstrated:

```text
HEALTHY
   |
   v
FAILURE
   |
   v
DETECTED
   |
   v
DIAGNOSED
   |
   v
RECOVERED
   |
   v
HEALTHY
```

---

## 49. Structured Monitoring Transition

Before failure:

```text
compose_application PASS
application_health PASS
host_nginx_health PASS
```

During failure:

```text
compose_application FAIL
application_health FAIL
host_nginx_health FAIL
```

After recovery:

```text
compose_application PASS
application_health PASS
host_nginx_health PASS
```

---

## 50. Failed Unit Regression

After recovery:

```bash
systemctl --failed
```

returned:

```text
0 loaded units listed
```

---

## 51. Firewall Recovery Verification

After recovery, UFW remained:

```text
Status: active
```

with:

```text
Default: deny incoming
```

and only:

```text
22/tcp
80/tcp
```

allowed.

---

## 52. No New Port Exposure

The recovery process did not expose:

```text
8000/tcp
```

externally.

The backend returned only on:

```text
127.0.0.1:8000
```

---

## 53. Existing Restart Policy

The application Compose configuration uses:

```yaml
restart: unless-stopped
```

This is an existing resilience control.

---

## 54. Restart Policy Interpretation

The simulation demonstrated an important Docker behavior.

An explicit:

```bash
docker compose stop app
```

is an intentional administrative stop.

The `unless-stopped` policy does not immediately override that administrator decision.

---

## 55. Unexpected Failure vs Administrative Stop

The restart policy is designed to improve resilience against unexpected termination or daemon/host restart scenarios.

It is not intended to fight an explicit operator stop command.

Therefore:

```text
container remained stopped
```

was expected behavior during this controlled simulation.

---

## 56. Prevention / Improvement Control

Existing resilience control:

```text
restart: unless-stopped
```

helps reduce downtime following unexpected container termination.

Existing detection controls:

```text
compose_application monitoring
application_health monitoring
host_nginx_health monitoring
```

help identify failure quickly.

---

## 57. Future Improvement Options

Potential future improvements include:

- scheduled automatic execution of monitoring;
- external alert delivery;
- container-native health checks;
- Docker health status integration;
- orchestrator-level automatic remediation;
- centralized incident alerting.

These are outside SEN-021 scope.

---

## 58. Detection Strength

The monitoring system did not merely report:

```text
application broken
```

It provided multiple correlated signals:

```text
Docker host healthy
Nginx host service healthy
SSH healthy
Compose application failed
backend health failed
end-to-end proxy health failed
```

This substantially narrows diagnosis.

---

## 59. Operational Logging Strength

The Nginx error log independently corroborated the monitoring result:

```text
Connection refused to 127.0.0.1:8000
```

This provides a second evidence source beyond the monitoring log.

---

## 60. Recovery Strength

Recovery required only:

```bash
docker compose start app
```

No:

- rebuild;
- redeployment;
- configuration repair;
- firewall repair;
- Nginx restart;
- Docker restart;

was required.

---

## 61. Incident Summary

### Symptom

```text
Application unavailable
```

### User-facing result

```text
HTTP 502 Bad Gateway
```

### Direct backend result

```text
connection refused
```

### Failed component

```text
sentinelops-app
```

### Healthy dependencies

```text
Docker
host Nginx
SSH
UFW
```

### Recovery

```text
docker compose start app
```

### Final result

```text
HTTP 200
monitoring PASS
security controls unchanged
```

---

## 62. FR-35 Contribution

SEN-021 provides one controlled failure scenario toward the minimum requirement of three.

Scenario:

```text
application container failure
```

---

## 63. FR-36 Detection

Failure detection was demonstrated through:

- `docker compose ps -a`;
- disappearance of port `8000`;
- direct health failure;
- proxied HTTP 502;
- SentinelOps monitoring;
- structured CRITICAL entries.

FR-36 is satisfied for this scenario.

---

## 64. FR-37 Diagnosis

Diagnosis evidence included:

- `docker inspect`;
- Docker service state;
- host Nginx service state;
- SSH state;
- listener state;
- Nginx upstream errors;
- monitoring results;
- Compose state.

FR-37 is satisfied for this scenario.

---

## 65. FR-38 Recovery

Recovery was documented and performed using:

```bash
docker compose start app
```

FR-38 is satisfied for this scenario.

---

## 66. FR-39 Recovery Verification

Recovery was verified through:

- running Compose service;
- restored loopback listener;
- direct HTTP 200;
- proxied HTTP 200;
- version `0.1.0`;
- restored monitoring PASS state;
- zero failed systemd units;
- unchanged firewall state.

FR-39 is satisfied for this scenario.

---

## 67. FR-40 Prevention / Improvement

Existing resilience and detection controls were documented:

```text
restart: unless-stopped
structured monitoring
health endpoint
operational logging
```

Future improvement options were also identified.

FR-40 is satisfied for this scenario.

---

## 68. Acceptance Criteria Verification

### FR-35 through FR-40 mapped

Verified.

### Healthy application state documented

Verified.

### Application intentionally stopped

Verified.

### No destructive Docker operation used

Verified.

### Compose shows application not running

Verified.

### Backend `/health` unavailable

Verified.

### Host proxy failure observed

Verified:

```text
HTTP 502
```

### Port 8000 listener disappeared

Verified.

### Monitoring detected failure

Verified.

### `compose_application` failure recorded

Verified:

```text
FAIL / CRITICAL
```

### `application_health` failure recorded

Verified:

```text
FAIL / CRITICAL
```

### `host_nginx_health` failure recorded

Verified:

```text
FAIL / CRITICAL
```

### Docker remained active

Verified.

### Host Nginx remained active

Verified.

### SSH remained active

Verified.

### UFW remained active

Verified.

### Failure correctly diagnosed

Verified.

### Application recovered with Docker Compose

Verified.

### Compose returned to running

Verified.

### Port 8000 restored loopback-only

Verified.

### Direct `/health` restored

Verified:

```text
HTTP 200
```

### Host `/health` restored

Verified:

```text
HTTP 200
```

### Application version preserved

Verified:

```text
0.1.0
```

### Monitoring returned to PASS

Verified.

### Structured recovery entries recorded

Verified.

### Failed systemd units

Verified:

```text
0
```

### UFW configuration unchanged

Verified.

### TCP 22 preserved

Verified.

### TCP 80 preserved

Verified.

### No external 8000 rule introduced

Verified.

### Restart policy documented

Verified.

### Administrative stop behavior documented

Verified.

### Recovery documented

Verified.

### Prevention/improvement documented

Verified.

---

## 69. Commands Used During SEN-021

Repository branch:

```bash
git switch -c sen-021-application-container-failure
git status
git branch --show-current
```

SSH:

```bash
ssh emir@192.168.64.2
```

Compose baseline:

```bash
cd /home/emir/sentinelops-app
docker compose ps
```

Service baseline:

```bash
systemctl is-active docker
systemctl is-active nginx
systemctl is-active ssh.socket
systemctl --failed
```

Health baseline:

```bash
curl -i http://127.0.0.1:8000/health
curl -i http://127.0.0.1/health
```

Listener baseline:

```bash
ss -tulpn | grep -E ':22|:80|:8000'
```

Firewall baseline:

```bash
sudo ufw status verbose
```

Monitoring baseline:

```bash
~/sentinelops-monitoring/health-check.sh
```

Structured baseline:

```bash
grep -E 'check=(compose_application|application_health|host_nginx_health)' \
    /var/log/sentinelops/health-check.log | tail -3
```

Failure injection:

```bash
docker compose stop app
```

Failed Compose state:

```bash
docker compose ps -a
```

Failed listener state:

```bash
ss -tulpn | grep -E ':22|:80|:8000'
```

Direct failed health:

```bash
curl -i --max-time 5 http://127.0.0.1:8000/health
```

Failed proxy health:

```bash
curl -i --max-time 5 http://127.0.0.1/health
```

Infrastructure diagnosis:

```bash
systemctl is-active docker
systemctl is-active nginx
systemctl is-active ssh.socket
systemctl --failed
```

Container logs:

```bash
docker compose logs --tail=30
```

Failed monitoring:

```bash
~/sentinelops-monitoring/health-check.sh
```

Structured failure evidence:

```bash
grep -E 'check=(compose_application|application_health|host_nginx_health|docker_service|nginx_service|ssh_service)' \
    /var/log/sentinelops/health-check.log | tail -6
```

Container diagnosis:

```bash
docker inspect sentinelops-app \
    --format 'status={{.State.Status}} exit_code={{.State.ExitCode}} restart_policy={{.HostConfig.RestartPolicy.Name}}'
```

Docker service diagnosis:

```bash
systemctl status docker --no-pager
```

Nginx service diagnosis:

```bash
systemctl status nginx --no-pager
```

Nginx error diagnosis:

```bash
sudo tail -20 /var/log/nginx/error.log
```

Firewall diagnosis:

```bash
sudo ufw status verbose
```

Recovery:

```bash
cd /home/emir/sentinelops-app
docker compose start app
```

Recovery state:

```bash
docker compose ps
```

Recovery listeners:

```bash
ss -tulpn | grep -E ':22|:80|:8000'
```

Recovery health:

```bash
curl -i http://127.0.0.1:8000/health
curl -i http://127.0.0.1/health
```

Recovery monitoring:

```bash
~/sentinelops-monitoring/health-check.sh
```

Structured recovery evidence:

```bash
grep -E 'check=(compose_application|application_health|host_nginx_health|docker_service|nginx_service|ssh_service)' \
    /var/log/sentinelops/health-check.log | tail -6
```

Final failed-unit check:

```bash
systemctl --failed
```

Final firewall check:

```bash
sudo ufw status verbose
```

---

## 70. Lessons Learned

### Layered monitoring improves diagnosis

A single HTTP failure does not identify the failed component.

Correlating:

```text
service state
container state
port state
HTTP state
structured monitoring
web-server logs
```

provided a much clearer diagnosis.

### Service availability and dependency availability differ

Host Nginx can be:

```text
active
```

while returning:

```text
502 Bad Gateway
```

because the reverse proxy depends on the backend application.

### Exit code 0 does not mean the service is available

The stopped container reported:

```text
exit_code=0
```

because the shutdown was graceful.

Operational state must therefore be checked separately from process exit semantics.

### Restart policy behavior matters

`unless-stopped` improves resilience, but an explicit administrative stop intentionally suppresses automatic restart.

### Recovery should be minimal

Because the configuration and image were healthy, restarting only the stopped Compose service was preferable to rebuilding or restarting unrelated infrastructure.

---

## 71. Final State

At completion:

```text
sentinelops-app
running
```

```text
Docker
active
```

```text
host Nginx
active
```

```text
SSH
active
```

```text
127.0.0.1:8000
listening
```

```text
direct /health
HTTP 200
```

```text
host /health
HTTP 200
```

```text
application version
0.1.0
```

```text
compose_application
PASS / INFO
```

```text
application_health
PASS / INFO
```

```text
host_nginx_health
PASS / INFO
```

```text
failed systemd units
0
```

```text
UFW
active
```

```text
default incoming
deny
```

No new listener or firewall rule was introduced.

The environment returned to its verified healthy state.

SEN-021 successfully demonstrates the first controlled SentinelOps failure lifecycle and is ready for repository validation, commit, pull request, review, merge, and issue closure.