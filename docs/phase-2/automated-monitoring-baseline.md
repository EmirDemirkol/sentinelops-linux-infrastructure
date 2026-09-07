# SEN-029 Automated Monitoring Baseline

## Purpose

SEN-029 introduces scheduled execution of the existing SentinelOps monitoring workflow using systemd.

The implementation addresses SC-15 by measuring automatic detection of a controlled service failure within two monitoring intervals.

This document records implementation and validation on the disposable SentinelOps test VM.

## Issue

- Issue: #44
- Title: SEN-029: Automate monitoring and verify failure detection time
- Branch: `sen-029-automated-monitoring`
- Starting main commit: `b353f1e`

## Requirements

### Primary Success Criterion

SC-15 requires a selected service failure to be detected within two monitoring intervals.

With a one-minute interval, the educational detection target is 120 seconds.

### Supporting Requirements

The implementation preserves existing capabilities associated with:

- FR-16: Nginx service monitoring.
- FR-17: Application container monitoring.
- FR-18: Application endpoint monitoring.
- FR-23: Dedicated monitoring logs.
- FR-24: Structured monitoring records.
- FR-42: Repeatable provisioning.
- FR-43: Idempotent provisioning.
- FR-44: Prerequisite validation.
- FR-45: Useful failure reporting.

SEN-029 adds scheduling and detection-time evidence to these existing capabilities.

## Initial State

SEN-028 had completed structured memory and system-load collection.

The repository contained backup service and timer assets, but no monitoring service or timer assets.

The existing monitoring script was deployed to:

```text
/home/emir/sentinelops-monitoring/health-check.sh
```

The complete script included Docker inspection and a privileged UFW status command.

Scheduled execution therefore required an explicit permission model that did not depend on interactive authentication.

## Validation Environment

| Property | Value |
|---|---|
| Hostname | `sentinelops-test` |
| Address | `192.168.64.3` |
| Operating system | Ubuntu Server 24.04.4 LTS |
| Architecture | arm64 |
| Kernel reported | `6.8.0-139-generic` |
| Validation date | 2026-09-07 |
| Source staging directory | `/home/emir/sen029-validation` |

The recorded deployment, reboot and controlled failure tests were performed on the test VM.

This evidence does not establish deployment of SEN-029 to the primary VM.

## Repository Changes

Added:

```text
provision/systemd/sentinelops-monitoring.service
provision/systemd/sentinelops-monitoring.timer
docs/phase-2/automated-monitoring-baseline.md
```

Updated:

```text
provision/scripts/provision.sh
provision/README.md
```

The existing health-check script remains the source for both deployed monitoring copies.

## Monitoring Service

```ini
[Unit]
Description=SentinelOps scheduled host and application monitoring
After=network.target docker.service nginx.service

[Service]
Type=oneshot
User=root
Group=root
WorkingDirectory=/usr/local/lib/sentinelops
ExecStart=/usr/bin/bash /usr/local/lib/sentinelops/health-check.sh
TimeoutStartSec=45s
UMask=0027
StandardOutput=journal
StandardError=journal
```

The service executes the complete health check as root.

This permits privileged host inspection without introducing a passwordless sudo rule or requiring an interactive password prompt.

The 45-second timeout bounds service startup execution.

The oneshot service returns to an inactive state after execution. This is expected between scheduled runs.

Its execution status is separate from individual monitoring health results.

## Monitoring Timer

```ini
[Unit]
Description=Run SentinelOps monitoring every minute

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
AccuracySec=1s
RandomizedDelaySec=0
Unit=sentinelops-monitoring.service

[Install]
WantedBy=timers.target
```

The timer requests its first boot-relative run after one minute and subsequent runs relative to the service's last activation.

Actual execution times can vary slightly.

Systemd does not start a second instance of the same service while it is already active.

The timer does not implement replay of every monitoring interval missed while the VM was powered off.

## Protected Script Deployment

Provisioning retains the existing manual script and installs a separate scheduled copy:

| Purpose | Path | Owner | Mode |
|---|---|---|---|
| Manual script | `/home/emir/sentinelops-monitoring/health-check.sh` | `emir:emir` | `0775` |
| Scheduled directory | `/usr/local/lib/sentinelops` | `root:root` | `0755` |
| Scheduled script | `/usr/local/lib/sentinelops/health-check.sh` | `root:root` | `0755` |

The scheduled service executes the protected copy.

Preflight checks `/usr`, `/usr/local`, `/usr/local/lib` and the scheduled directory. Existing directories must be root-owned, must not be symbolic links and must not be group- or world-writable.

Preflight also rejects a scheduled script path that is a symbolic link or an unexpected non-regular file.

Provisioning checks the scheduled script and directory ownership and modes after installation.

This protects the scheduled script path. It is not a claim that the existing Docker administration model constitutes a sandbox for the administrator.

## Provisioning Integration

The updated provisioner:

1. Requires both monitoring unit source files.
2. Validates the protected monitoring path.
3. Completes preflight before pausing monitoring.
4. Stops an existing monitoring timer and service.
5. Deploys the monitoring scripts.
6. Installs both monitoring units.
7. Runs `systemd-analyze verify` against the installed monitoring units.
8. Reloads systemd.
9. Preserves backup timer activation.
10. Completes application setup and initial backup handling.
11. Runs existing service, SSH, application, network and backup validations.
12. Starts the monitoring service and checks execution success.
13. Checks for failed systemd units.
14. Enables and starts the monitoring timer.
15. Checks timer enablement, activity and monitoring log permissions.

The scheduled timer is activated after the operational validation sequence.

### Interrupted Provisioning

A preflight failure occurs before monitoring is paused.

If provisioning fails after the pause, monitoring remains stopped. The operator must correct the failure and complete provisioning to resume the schedule.

There is no automatic rollback of all provisioning changes.

## Local Validation

The updated provisioner passed:

```bash
bash -n provision/scripts/provision.sh
git diff --check
```

The first attempted local editing helper stopped because an expected text fragment occurred twice. It exited before saving.

The corrected helper applied the changes and validated Bash syntax before writing the provisioner.

That local editing error did not deploy a partial provisioner.

## First Test-VM Deployment

The current provisioning tree was copied to:

```text
/home/emir/sen029-validation/provision
```

The provisioner completed successfully on `sentinelops-test`.

Observed results included:

- required monitoring source assets found;
- protected path preflight passed;
- monitoring script deployment passed;
- monitoring unit validation passed;
- monitoring service execution completed;
- monitoring timer enabled and active;
- no failed systemd units;
- backend health HTTP 200;
- host Nginx health HTTP 200;
- backup checksum and manifest validation passed.

## Automatic Execution Evidence

Structured resource records showed executions at:

```text
2026-09-07T20:58:11Z
2026-09-07T20:58:13Z
2026-09-07T20:59:13Z
```

The first execution was requested by provisioning.

The timer then triggered execution, followed by the next scheduled run 60 seconds later.

The journal recorded successful completion of the scheduled service.

Later healthy Nginx records included:

```text
2026-09-07T21:02:06Z
2026-09-07T21:03:07Z
2026-09-07T21:04:08Z
```

These observations demonstrate automatic recurrence with slight variation in actual start times.

## Installed Permissions

Observed:

```text
root:root 755 /usr/local/lib/sentinelops
root:root 755 /usr/local/lib/sentinelops/health-check.sh
root:root 644 /etc/systemd/system/sentinelops-monitoring.service
root:root 644 /etc/systemd/system/sentinelops-monitoring.timer
root:emir 750 /var/log/sentinelops
emir:emir 640 /var/log/sentinelops/health-check.log
```

Existing structured log ownership and permissions were preserved.

## Reboot Persistence

The test VM was rebooted at approximately:

```text
2026-09-07T21:00:55Z
```

After reboot:

- the monitoring timer was enabled;
- the monitoring timer was active;
- its first scheduled execution was pending.

Initial journal inspection returned no entries because the first run had not yet occurred.

Subsequent evidence showed:

| Event | UTC timestamp |
|---|---|
| Timer started automatically | `2026-09-07T21:01:09Z` |
| Monitoring service started automatically | `2026-09-07T21:02:06Z` |
| Monitoring service completed | `2026-09-07T21:02:08Z` |

The service reported:

```text
code=exited, status=0/SUCCESS
```

Both application and host Nginx HTTP checks returned 200.

This verifies automatic monitoring execution after reboot.

## Controlled Failure Test

### Healthy Baseline

Before introducing the failure:

- hostname was confirmed as `sentinelops-test`;
- Nginx was active;
- the monitoring timer was active;
- recent scheduled Nginx records showed PASS.

### Method

The test:

1. Recorded the existing monitoring log line count.
2. Recorded UTC time immediately before requesting the Nginx stop.
3. Stopped Nginx.
4. Verified its inactive state.
5. Polled only new structured log records.
6. Waited for a scheduled `nginx_service` FAIL record.
7. Calculated elapsed time from the recorded start time.
8. Restored Nginx.
9. Waited for a subsequent scheduled PASS record.
10. Requested the application health endpoint through host Nginx.

The test did not manually invoke monitoring during the detection or recovery measurement windows.

An exit trap attempted to restore Nginx if the test exited early.

### Recorded Results

| Event | UTC timestamp |
|---|---|
| Failure test started | `2026-09-07T21:08:10Z` |
| Scheduled failure record | `2026-09-07T21:08:12Z` |
| Nginx restored | `2026-09-07T21:08:12Z` |
| Scheduled recovery record | `2026-09-07T21:09:13Z` |

Failure record:

```text
timestamp=2026-09-07T21:08:12Z check=nginx_service status=FAIL severity=CRITICAL message="Nginx service is not active"
```

Measured detection:

```text
Detection elapsed: 2 seconds
```

Recovery record:

```text
timestamp=2026-09-07T21:09:13Z check=nginx_service status=PASS severity=INFO message="Nginx service is active"
```

Health response after recovery:

```json
{"status":"healthy","version":"0.1.0"}
```

The complete test reported:

```text
PASS: SC-15 detection target met, and scheduled recovery verified.
```

### Interpretation

The observed two-second detection met the 120-second target.

The measurement used whole-second UTC timestamps and began immediately before the stop command. It includes the time required to stop Nginx.

The failure occurred shortly before a scheduled check. This is one observed timing result, not a guarantee of two-second detection for every failure.

### Subsequent Terminal Errors

After the complete test had passed, part of its body was pasted again outside the original Bash process.

This produced `command not found` errors because the helper function was no longer defined.

The repeated fragment's printed PASS is not additional evidence. The valid evidence is the complete original test and its structured records.

## Repeated Provisioning

The updated provisioner was run again on the already-configured test VM.

It completed successfully.

Observed results:

- existing monitoring was paused for provisioning;
- deployment and validation completed;
- the existing backup archive was retained;
- initial backup creation was skipped appropriately;
- backup verification passed;
- backend and proxy HTTP checks returned 200;
- SSH security validation passed;
- backend port 8000 remained loopback-only;
- no failed systemd units were reported;
- monitoring timer returned to enabled and active state.

The timer reported its next execution at:

```text
2026-09-07T21:11:19Z
```

This supports repeated provisioning of the monitoring configuration.

## Missing-Asset Preflight Test

The monitoring timer source was temporarily renamed in the test VM's staging directory.

The installed systemd timer was not removed or renamed.

Provisioning reported:

```text
[SEN-025] ERROR: Required provisioning asset missing: /home/emir/sen029-validation/provision/systemd/sentinelops-monitoring.timer
```

Observed exit code:

```text
1
```

The test verified that preflight did not complete.

The source file was restored, and the installed monitoring timer remained active.

Final result:

```text
PASS: Missing asset rejected during preflight; source restored; installed timer remains active.
```

This demonstrates useful failure reporting before the monitoring pause and deployment stages.

## Operational Regression Evidence

The recorded provisioning runs verified:

| Check | Observed result |
|---|---|
| Docker service | Active |
| Nginx service | Active |
| SSH socket | Active |
| Backup timer | Enabled and active |
| Backend health | HTTP 200 |
| Host Nginx health | HTTP 200 |
| Backend publication | `127.0.0.1:8000` |
| UFW | Active |
| Incoming policy | Deny |
| Allowed inbound services | TCP 22 and TCP 80 |
| Root SSH login | Disabled |
| SSH password authentication | Disabled |
| SSH public-key authentication | Enabled |
| Backup checksum | Passed |
| Backup manifest | Passed |
| Failed systemd units | None reported |

The controlled failure was recovered before this repeated validation.

## Acceptance Status

- [x] Monitoring service and timer assets added.
- [x] Monitoring source assets included in preflight.
- [x] Scheduled execution requires no interactive authentication.
- [x] Protected scheduled script and directory permissions verified.
- [x] Service execution timeout configured.
- [x] One-minute timer interval configured.
- [x] Repeated automatic execution observed.
- [x] Timer enablement and activity verified.
- [x] Automatic execution after reboot verified.
- [x] Structured records produced by scheduled runs.
- [x] Existing log permissions preserved.
- [x] Controlled Nginx failure detected automatically.
- [x] Observed detection met the SC-15 target.
- [x] Scheduled recovery record verified.
- [x] Repeated provisioning completed successfully.
- [x] Missing source asset rejected during preflight.
- [x] Existing operational checks passed.
- [ ] Pull-request CI verified.
- [ ] Merge verified.
- [ ] Default-branch CI verified.

## CI and Completion Status

The runtime and controlled tests in this document were executed manually on the test VM.

This issue does not add those runtime tests to the GitHub Actions workflow.

Pull-request CI, merge verification and default-branch CI remain separate completion steps at the time of this evidence draft.

## Known Limitations

- SC-15 evidence covers one selected Nginx failure on the test VM.
- Timer accuracy and system workload can affect observed timing.
- A suspended or powered-off VM cannot perform live monitoring.
- The 45-second service timeout can terminate an incomplete run.
- Service execution success does not imply all health conditions passed.
- Failed provisioning after the monitoring pause leaves scheduling stopped.
- The monitoring log remains writable by the existing administrator account and is not tamper-proof.
- Log rotation is not introduced by this issue.
- Automatic recovery of failed services is not implemented.
- Primary-VM deployment is not established by these test-VM results.

## Out of Scope

SEN-029 does not introduce:

- memory or load thresholds;
- external alerts;
- automatic remediation;
- log rotation;
- overall health-check exit-status redesign;
- new backup scheduling or retention;
- Prometheus or Grafana;
- cloud infrastructure;
- multi-server monitoring;
- public DNS or HTTPS;
- application architecture changes.

## Evidence Conclusion

Scheduled monitoring, reboot persistence, protected script deployment and repeated provisioning were demonstrated on the test VM.

A controlled Nginx failure was detected automatically in two seconds, and the next scheduled check recorded recovery.

These results support SC-15 for the observed lab test. Repository completion remains subject to CI and merge verification.