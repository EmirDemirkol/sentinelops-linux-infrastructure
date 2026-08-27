# SentinelOps Monitoring Baseline

## Purpose

This document records the implementation and verification of the SentinelOps local monitoring and operational visibility baseline.

The monitoring baseline builds on:

- SEN-005 secure SSH administration
- SEN-006 UFW firewall configuration
- SEN-007 host-level Nginx deployment
- SEN-008 Docker Engine installation
- SEN-009 private application deployment
- SEN-010 Docker Compose application deployment

The objective is to provide lightweight operational visibility into the Ubuntu host, system services, Docker runtime, application container, reverse proxy, network exposure, and logs without introducing a dedicated external monitoring platform.

The monitoring approach remains local-first and does not expose any additional network service.

---

## Initial State

Before SEN-011:

- Ubuntu Server 24.04.4 LTS was running in UTM
- the VM used IPv4 address `192.168.64.2`
- secure SSH administration was operational
- UFW was active
- TCP port 22 was allowed for SSH
- TCP port 80 was allowed for Nginx HTTP
- TCP port 443 remained blocked
- Docker Engine was installed and active
- Docker Compose was available
- the Compose-managed `sentinelops-app` container was running
- the backend was bound only to `127.0.0.1:8000`
- host Nginx reverse proxied requests to the private backend
- external HTTP access through Nginx returned `200 OK`
- TCP port 8000 was not directly reachable from the Mac
- no dedicated monitoring service was installed
- no monitoring port was exposed
- UTM console access remained available as a recovery path

---

## Monitoring Philosophy

SEN-011 introduces a lightweight operational monitoring baseline.

The purpose is to answer practical operational questions such as:

- Is the host online?
- What is the current system load?
- How much memory is available?
- How much disk space remains?
- Are any systemd units failed?
- Is Docker active?
- Is Nginx active?
- Is SSH active?
- Is the application container running?
- How much CPU and memory is the container using?
- Is the backend responding locally?
- Is Nginx responding locally?
- Is the application responding externally?
- Are there recent application or proxy errors?
- Which TCP ports are listening?
- Is UFW still enforcing the intended rules?
- Is the backend still isolated from external clients?

The monitoring baseline intentionally avoids deploying Prometheus, Grafana, Loki, ELK, or another dedicated monitoring platform.

---

## Host Uptime and Load

Host uptime and load were reviewed using:

```bash
uptime
```

Observed result:

```text
15:10:16 up 1:36, 1 user, load average: 0.06, 0.01, 0.00
```

This showed that the host was operating with very low system load at the time of the baseline.

The values indicate no immediate CPU saturation or load-related concern.

---

## Memory Baseline

Memory usage was reviewed using:

```bash
free -h
```

Observed state:

```text
               total        used        free      shared  buff/cache   available
Mem:           2.9Gi       302Mi       2.1Gi       5.3Mi       537Mi       2.6Gi
Swap:          2.7Gi          0B       2.7Gi
```

This confirmed:

- total memory was approximately `2.9 GiB`
- used memory was approximately `302 MiB`
- available memory was approximately `2.6 GiB`
- swap usage was `0`

The host therefore had substantial memory headroom.

---

## Filesystem Baseline

Filesystem usage was reviewed using:

```bash
df -h
```

The root filesystem reported:

```text
Filesystem                         Size  Used Avail Use% Mounted on
/dev/mapper/ubuntu--vg-ubuntu--lv   14G  5.9G  6.6G  48% /
```

This confirmed:

- root filesystem size was approximately `14 GB`
- approximately `5.9 GB` was used
- approximately `6.6 GB` remained available
- filesystem usage was approximately `48%`

No immediate disk-capacity issue was present.

---

## Failed Systemd Unit Check

Failed systemd units were reviewed using:

```bash
systemctl --failed
```

Result:

```text
0 loaded units listed.
```

This confirmed there were no failed systemd services at the time of the SEN-011 baseline.

---

## Docker Service Health

Docker service health was reviewed using:

```bash
systemctl status docker
```

The Docker service reported:

```text
Loaded: loaded
enabled
Active: active (running)
```

This confirmed the Docker daemon remained available and operational.

---

## Nginx Service Health

Nginx service health was reviewed using:

```bash
systemctl status nginx
```

The Nginx service reported:

```text
Loaded: loaded
enabled
Active: active (running)
```

This confirmed the host-level reverse proxy remained available and operational.

---

## Compose Application Health

The Compose-managed application was reviewed using:

```bash
cd ~/sentinelops-app && docker compose ps
```

The service reported:

```text
sentinelops-app   sentinelops-app-app   app   Up 19 hours   127.0.0.1:8000->80/tcp
```

This confirmed:

- the application container was running
- the container had remained up for approximately 19 hours
- the backend remained bound only to `127.0.0.1:8000`
- Docker Compose continued to manage the application successfully

---

## Monitoring Script Directory

A dedicated local monitoring directory was created:

```bash
mkdir -p ~/sentinelops-monitoring
```

The directory path was:

```text
/home/emir/sentinelops-monitoring
```

This directory stores reusable local monitoring tooling.

---

## Health-Check Script

A reusable health-check script was created at:

```text
/home/emir/sentinelops-monitoring/health-check.sh
```

The script was created using:

```bash
nano ~/sentinelops-monitoring/health-check.sh
```

The script contains:

```bash
#!/usr/bin/env bash

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

echo "=== FAILED SYSTEMD UNITS ==="
systemctl --failed
echo

echo "=== SERVICE HEALTH ==="
printf "Docker: "
systemctl is-active docker

printf "Nginx:  "
systemctl is-active nginx

printf "SSH:    "
systemctl is-active ssh.socket
echo

echo "=== COMPOSE APPLICATION ==="
cd /home/emir/sentinelops-app || exit 1
docker compose ps
echo

echo "=== CONTAINER RESOURCE USAGE ==="
docker stats --no-stream
echo

echo "=== LOCAL BACKEND HEALTH ==="
if curl -fsS -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8000; then
    echo "Backend reachable"
else
    echo "Backend health check FAILED"
fi
echo

echo "=== HOST NGINX HEALTH ==="
if curl -fsS -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1; then
    echo "Nginx reachable"
else
    echo "Nginx health check FAILED"
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

## Script Permissions

The script was made executable using:

```bash
chmod +x ~/sentinelops-monitoring/health-check.sh
```

This allowed the script to be run directly by the administrator.

---

## Health-Check Execution

The script was executed using:

```bash
~/sentinelops-monitoring/health-check.sh
```

The script completed successfully.

It produced a consolidated operational view covering:

- timestamp
- uptime
- load
- memory
- filesystem usage
- failed systemd units
- Docker state
- Nginx state
- SSH state
- Compose application state
- container resource consumption
- local backend HTTP health
- local Nginx HTTP health
- listening TCP sockets
- UFW status

---

## Script Timestamp

The script recorded:

```text
Thu Aug 27 03:12:49 PM UTC 2026
```

This provides clear execution context for the monitoring output.

---

## Script Host Load Result

The script reported:

```text
15:12:49 up 1:39, 1 user, load average: 0.02, 0.02, 0.00
```

This confirmed the server remained under very low load.

---

## Script Memory Result

The script reported approximately:

```text
Mem: 2.9Gi total
289Mi used
2.2Gi free
2.6Gi available
```

Swap usage remained:

```text
0B
```

This confirmed that the host continued to have substantial memory headroom.

---

## Script Filesystem Result

The root filesystem check reported:

```text
/dev/mapper/ubuntu--vg-ubuntu--lv   14G   5.9G   6.6G   48%   /
```

This matched the earlier filesystem baseline.

---

## Script Failed-Unit Result

The script reported:

```text
0 loaded units listed.
```

This confirmed that no failed systemd units appeared between the initial check and scripted execution.

---

## Script Service Health

The script reported:

```text
Docker: active
Nginx:  active
SSH:    active
```

This provided a concise service-health summary.

---

## Script Application State

The script reported the `sentinelops-app` Compose service as:

```text
Up 19 hours
127.0.0.1:8000->80/tcp
```

This confirmed that the application was running and remained privately bound.

---

## Container Resource Usage

The health script included:

```bash
docker stats --no-stream
```

Observed container resource usage included approximately:

```text
CPU: 0.00%
Memory: 10.15 MiB / 2.887 GiB
Memory percentage: 0.34%
PIDs: 3
```

A dedicated check later reported:

```text
CPU: 0.00%
Memory: 10.18 MiB / 2.887 GiB
Memory percentage: 0.34%
```

This confirmed that the lightweight application container consumed very little CPU or memory.

---

## Local Backend Health

The script tested:

```text
http://127.0.0.1:8000
```

Result:

```text
HTTP 200
Backend reachable
```

This confirmed that the private backend was healthy and reachable from the Ubuntu host.

---

## Host Nginx Health

The script tested:

```text
http://127.0.0.1
```

Result:

```text
HTTP 200
Nginx reachable
```

This confirmed that host-level Nginx was responding successfully.

---

## Listening TCP Ports

The script reviewed listening TCP sockets using:

```bash
ss -tln
```

Relevant entries included:

```text
127.0.0.1:8000
0.0.0.0:80
0.0.0.0:22
[::]:80
[::]:22
```

This confirmed the intended network architecture:

```text
SSH       -> externally bound on TCP 22
Nginx     -> externally bound on TCP 80
Backend   -> bound only to 127.0.0.1:8000
```

No monitoring-specific network listener was introduced.

---

## Firewall Health

The health script reviewed UFW using:

```bash
sudo ufw status verbose
```

Result:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
```

The explicit inbound rules remained:

```text
22/tcp                     ALLOW IN    Anywhere
80/tcp (Nginx HTTP)        ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
80/tcp (Nginx HTTP (v6))   ALLOW IN    Anywhere (v6)
```

No monitoring port was added.

No TCP port 8000 rule was added.

---

## Read-Only Monitoring Behaviour

The health-check script was designed to inspect state rather than modify it.

The script does not:

- restart services
- stop containers
- create containers
- modify firewall rules
- reload Nginx
- modify system configuration
- change permissions
- install packages
- alter network exposure

The only privileged command used by the script is:

```bash
sudo ufw status verbose
```

which reads firewall state.

---

## Nginx Access Log Inspection

Nginx access logs were inspected using:

```bash
sudo tail -n 20 /var/log/nginx/access.log
```

Observed entry:

```text
127.0.0.1 - - [27/Aug/2026:15:12:51 +0000] "GET / HTTP/1.1" 200 1923 "-" "curl/8.5.0"
```

This confirmed that the local Nginx health check generated a successful HTTP `200` request and that Nginx logging remained operational.

---

## Nginx Error Log Inspection

Nginx error logs were inspected using:

```bash
sudo tail -n 20 /var/log/nginx/error.log
```

No output was returned.

This indicates that there were no recent Nginx error entries within the requested log range.

---

## Application Container Log Inspection

Application logs were inspected using:

```bash
docker logs --tail 20 sentinelops-app
```

The logs showed normal Nginx Alpine startup behaviour, including:

```text
Configuration complete; ready for start up
using the "epoll" event method
nginx/1.31.4
start worker processes
```

No application startup failure was observed.

---

## Container HTTP Log Entries

The container logs also showed successful HTTP requests.

Examples included:

```text
172.18.0.1 - - [26/Aug/2026:20:15:12 +0000] "HEAD / HTTP/1.0" 200
```

and:

```text
172.18.0.1 - - [27/Aug/2026:15:12:51 +0000] "GET / HTTP/1.1" 200 1923
```

This confirmed that requests were reaching the backend container successfully.

---

## System Journal Inspection

The system journal was reviewed using:

```bash
sudo journalctl -p warning -n 30 --no-pager
```

The output included firewall blocks, existing boot warnings, LVM messages, cron warnings, and kernel notices.

No new service failure introduced by SEN-011 was observed.

---

## UFW Block Evidence

The system journal contained repeated entries similar to:

```text
[UFW BLOCK] IN=enp0s1 ... SRC=192.168.64.1 DST=192.168.64.2 ... DPT=8000 ... SYN
```

These entries corresponded to earlier direct connection tests from the Mac to TCP port 8000.

This provides firewall-level evidence that attempted external connections to the backend port were blocked.

---

## Backend Isolation Monitoring Evidence

The UFW log entries provide an additional verification layer for backend isolation.

The observed flow was:

```text
Mac host
   |
   | TCP 8000 attempt
   v
UFW
   |
   X BLOCK
```

This matches the intended SEN-009 and SEN-010 architecture.

---

## Existing Journal Warnings

The warning-level journal output also contained existing messages such as:

```text
device-mapper: core: CONFIG_IMA_DISABLE_HTABLE is disabled.
```

and:

```text
cron.service: Referenced but unset environment variable evaluates to an empty string: EXTRA_OPTS
```

These were existing host-level warnings and were not caused by the SEN-011 monitoring implementation.

They were recorded as part of the monitoring baseline rather than modified during this issue.

---

## Container Resource Check

Container resource usage was explicitly rechecked using:

```bash
docker stats --no-stream sentinelops-app
```

Observed result:

```text
CONTAINER ID   NAME              CPU %   MEM USAGE / LIMIT      MEM %   PIDS
b6da126bd303   sentinelops-app   0.00%   10.18MiB / 2.887GiB   0.34%   3
```

The container showed negligible CPU utilisation and very low memory consumption.

---

## External HTTP Health Check

The SSH session was exited and the application was tested from the Mac using:

```bash
curl -I http://192.168.64.2
```

Result:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Content-Type: text/html
Content-Length: 1923
Connection: keep-alive
```

This confirmed that external application availability remained healthy through host Nginx.

---

## External Application Content Verification

The Mac also verified application content using:

```bash
curl -s http://192.168.64.2 | grep -E 'SentinelOps|Private Docker Compose|Phase 1'
```

Observed content included:

```text
<title>SentinelOps</title>
<h1>SentinelOps</h1>
<p>Private Docker Compose application behind host Nginx.</p>
<p>This page validates the SentinelOps reverse-proxy architecture and secure backend isolation.</p>
<div class="badge">Phase 1 · Compose Deployment</div>
```

This confirmed that the external health check reached the intended Compose-managed application.

---

## External Backend Isolation Check

Direct backend access was tested from the Mac using:

```bash
nc -vz -w 2 192.168.64.2 8000
```

Result:

```text
nc: connectx to 192.168.64.2 port 8000 (tcp) failed: Operation timed out
```

This confirmed that TCP port 8000 remained unavailable externally.

---

## Monitoring Network Exposure

SEN-011 did not introduce any new listening service.

The externally reachable service model remained:

```text
22/tcp     SSH
80/tcp     Nginx HTTP
```

The backend remained:

```text
127.0.0.1:8000
```

No monitoring port was opened.

---

## Final Monitoring Architecture

The operational visibility model is:

```text
Administrator
    |
    | SSH
    v
Ubuntu Host
    |
    +-- uptime
    +-- free
    +-- df
    +-- systemctl
    +-- journalctl
    +-- ss
    +-- UFW status
    |
    +-- Docker
    |    |
    |    +-- docker compose ps
    |    +-- docker stats
    |    +-- docker logs
    |
    +-- Nginx
    |    |
    |    +-- access.log
    |    +-- error.log
    |
    +-- health-check.sh
         |
         +-- host checks
         +-- service checks
         +-- application checks
         +-- network checks
```

---

## Monitoring Security Model

The monitoring baseline preserves the existing security architecture.

No monitoring component:

- listens on a public port
- accepts remote dashboard connections
- exposes the Docker socket remotely
- modifies UFW
- exposes TCP port 8000
- introduces new credentials
- publishes logs externally
- requires a cloud service

All operational checks are performed locally through the existing secure SSH administration path.

---

## Operational Health Summary

At completion of SEN-011:

- host load is low
- memory usage is low
- swap is unused
- root filesystem usage is below 50%
- no failed systemd units are present
- Docker is active
- Nginx is active
- SSH is active
- the Compose application is running
- the backend is locally healthy
- Nginx is locally healthy
- external HTTP is healthy
- container CPU usage is negligible
- container memory usage is approximately 10 MiB
- Nginx access logging is operational
- Nginx error logs contain no recent entries
- Docker application logs are available
- system journal logs are available
- UFW logging is operational
- UFW confirms blocked TCP port 8000 connection attempts
- TCP port 8000 remains private
- no new monitoring network exposure exists

---

## Verification Summary

The following checks were successfully completed:

- reviewed host uptime
- reviewed system load
- reviewed memory usage
- reviewed swap usage
- reviewed filesystem usage
- confirmed no failed systemd units
- verified Docker service health
- verified Nginx service health
- verified SSH service health
- verified Compose application state
- verified the private backend binding
- created `~/sentinelops-monitoring`
- created `health-check.sh`
- made the script executable
- executed the monitoring script successfully
- verified host resource information through the script
- verified service states through the script
- verified application state through the script
- reviewed container CPU usage
- reviewed container memory usage
- verified local backend HTTP `200`
- verified local Nginx HTTP `200`
- reviewed listening TCP sockets
- verified UFW remained active
- verified only TCP ports 22 and 80 remained allowed inbound
- inspected Nginx access logs
- confirmed successful Nginx requests were logged
- inspected Nginx error logs
- confirmed no recent Nginx error entries
- inspected Docker application logs
- confirmed normal application startup
- confirmed successful backend HTTP requests
- inspected warning-level system journal entries
- reviewed existing boot and cron warnings
- confirmed UFW logged blocked TCP port 8000 attempts
- performed an explicit container resource check
- verified external HTTP returned `HTTP/1.1 200 OK`
- verified external SentinelOps content
- confirmed direct TCP port 8000 access timed out
- confirmed no monitoring port was introduced

---

## Out of Scope

SEN-011 did not introduce:

- Prometheus
- Grafana
- Loki
- Elasticsearch
- OpenSearch
- ELK
- external SaaS monitoring
- cloud monitoring
- SNMP
- monitoring dashboards
- automated alerting
- email alerts
- Slack alerts
- PagerDuty
- automated remediation
- production APM
- monitoring agents
- public metrics endpoints
- backup implementation
- CI/CD monitoring
- Kubernetes monitoring

These capabilities remain reserved for later SentinelOps issues.

---

## Completion State

The SentinelOps Ubuntu Server VM now has a lightweight local monitoring and operational visibility baseline.

Host health, service health, container state, resource usage, application health, listening sockets, firewall state, and relevant logs can be inspected through standard Linux and Docker tooling.

A reusable `health-check.sh` script provides a consolidated read-only operational health view.

The monitoring implementation introduces no public monitoring port, does not weaken UFW, and preserves the private backend architecture.

External HTTP remains available through host Nginx while TCP port 8000 remains inaccessible directly from the Mac.

This establishes the local operational monitoring foundation required for later SentinelOps alerting, observability, and automation work.