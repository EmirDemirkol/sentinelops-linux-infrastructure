# SentinelOps Automated Backup Baseline

## Purpose

This document records the implementation and verification of the SentinelOps automated local backup baseline.

The automated backup baseline builds directly on SEN-012, where a manual backup process was created, archive integrity was verified, and an isolated restore test was completed successfully.

The objective of SEN-013 is to automate that validated backup process using systemd, verify unattended execution, confirm timer persistence across reboot, and preserve the existing SentinelOps security architecture.

---

## Initial State

Before SEN-013:

- Ubuntu Server 24.04.4 LTS was running in UTM;
- the VM used IPv4 address `192.168.64.2`;
- SSH public-key administration was operational;
- UFW was active;
- TCP port 22 was allowed for SSH;
- TCP port 80 was allowed for Nginx HTTP;
- TCP port 443 remained blocked;
- Docker Engine was installed and active;
- Docker Compose was available;
- the Compose-managed `sentinelops-app` container was running;
- the application backend was bound only to `127.0.0.1:8000`;
- host Nginx reverse proxied requests to the private backend;
- the monitoring baseline from SEN-011 was available;
- `/home/emir/backups/sentinelops/backup-sentinelops.sh` existed;
- the backup script successfully generated timestamped `.tar.gz` archives;
- backup archive integrity had been verified;
- isolated restoration had been tested successfully;
- restored files matched the live originals;
- no systemd backup service existed;
- no systemd backup timer existed;
- no automated backup schedule existed;
- no off-host backup destination was configured.

---

## Existing Backup Directory

The existing backup directory was reviewed using:

```bash
ls -lh ~/backups/sentinelops/
```

Observed contents included:

```text
backup-sentinelops.sh
sentinelops-backup-20260827T155515Z.tar.gz
```

This confirmed that the SEN-012 backup script and at least one previously generated archive were present.

## Existing Backup Script Permissions

The backup script was reviewed using:

```bash
ls -l ~/backups/sentinelops/backup-sentinelops.sh
```

Observed result:

```text
-rwxrwxr-x 1 emir emir 960 Aug 27 15:55 /home/emir/backups/sentinelops/backup-sentinelops.sh
```

The script was executable and owned by `emir`.

## Initial Systemd State

Before implementation, the service was checked using:

```bash
systemctl status sentinelops-backup.service
```

Result:

```text
Unit sentinelops-backup.service could not be found.
```

The timer was checked using:

```bash
systemctl status sentinelops-backup.timer
```

Result:

```text
Unit sentinelops-backup.timer could not be found.
```

The timer list was also reviewed:

```bash
systemctl list-timers --all | grep sentinelops
```

No matching timer was present.

This confirmed that backup automation had not yet been configured.

## Systemd Backup Service

A dedicated systemd service unit was created at:

```text
/etc/systemd/system/sentinelops-backup.service
```

The service was created using:

```bash
sudo nano /etc/systemd/system/sentinelops-backup.service
```

The initial unit definition was:

```ini
[Unit]
Description=SentinelOps local backup
After=network.target

[Service]
Type=oneshot
User=emir
ExecStart=/home/emir/backups/sentinelops/backup-sentinelops.sh
```

The service used:

```ini
Type=oneshot
```

This means the service runs only for the duration of one backup execution and then exits.

It does not remain running as a persistent daemon.

## Systemd Backup Timer

A dedicated timer unit was created at:

```text
/etc/systemd/system/sentinelops-backup.timer
```

The timer was created using:

```bash
sudo nano /etc/systemd/system/sentinelops-backup.timer
```

The production timer definition was:

```ini
[Unit]
Description=Run SentinelOps backup daily

[Timer]
OnCalendar=daily
Persistent=true
Unit=sentinelops-backup.service

[Install]
WantedBy=timers.target
```

This configured a daily recurring backup schedule.

## Persistent Scheduling

The timer uses:

```ini
Persistent=true
```

This instructs systemd to account for missed scheduled runs when the system was unavailable.

This is useful for a VM that may not remain powered on continuously.

## Initial Systemd Reload

After creating the service and timer, systemd configuration was reloaded using:

```bash
sudo systemctl daemon-reload
```

The service was then inspected:

```bash
systemctl status sentinelops-backup.service
```

Observed state:

```text
Loaded: loaded
Active: inactive (dead)
```

This was expected because a oneshot service does not remain active while idle.

The timer was inspected:

```bash
systemctl status sentinelops-backup.timer
```

Observed state:

```text
Loaded: loaded
disabled
Active: inactive (dead)
```

This was also expected because the timer had not yet been enabled.

## Initial Manual Service Test

Before enabling the timer, the backup service was manually triggered using:

```bash
sudo systemctl start sentinelops-backup.service
```

The first automated execution failed.

Systemd reported:

```text
Job for sentinelops-backup.service failed because the control process exited with error code.
```

The service status showed:

```text
Active: failed
Result: exit-code
status=1/FAILURE
```

## Failure Investigation

The system journal showed:

```text
sudo: a terminal is required to read the password
sudo: a password is required
pam_unix(sudo:auth): conversation failed
pam_unix(sudo:auth): auth could not identify password for [emir]
```

This identified the root cause.

The SEN-012 backup script contained `sudo` commands.

When executed interactively, `sudo` could prompt for the administrator password.

When executed through systemd, no interactive terminal existed to supply the password.

The backup process therefore could not run unattended in its original form.

## Privilege Model Correction

The service execution model was corrected rather than weakening sudo policy.

The systemd service was changed to run explicitly as root:

```ini
[Unit]
Description=SentinelOps local backup
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=/home/emir/backups/sentinelops/backup-sentinelops.sh
```

This allowed the backup process to read the root-owned Nginx configuration without requiring interactive sudo authentication.

## Backup Script Automation Correction

The backup script was updated to remove embedded `sudo` commands.

The revised script was:

```bash
#!/usr/bin/env bash

set -euo pipefail

BACKUP_DIR="/home/emir/backups/sentinelops"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
STAGING_DIR="$(mktemp -d)"
ARCHIVE="${BACKUP_DIR}/sentinelops-backup-${TIMESTAMP}.tar.gz"

cleanup() {
    rm -rf "$STAGING_DIR"
}

trap cleanup EXIT

mkdir -p "$STAGING_DIR/application"
mkdir -p "$STAGING_DIR/monitoring"
mkdir -p "$STAGING_DIR/nginx"

cp /home/emir/sentinelops-app/index.html \
   "$STAGING_DIR/application/"

cp /home/emir/sentinelops-app/Dockerfile \
   "$STAGING_DIR/application/"

cp /home/emir/sentinelops-app/compose.yaml \
   "$STAGING_DIR/application/"

cp /home/emir/sentinelops-monitoring/health-check.sh \
   "$STAGING_DIR/monitoring/"

cp /etc/nginx/sites-available/sentinelops \
   "$STAGING_DIR/nginx/sentinelops"

tar -czf "$ARCHIVE" -C "$STAGING_DIR" .

chown emir:emir "$ARCHIVE"
chmod 600 "$ARCHIVE"

echo "Backup created:"
echo "$ARCHIVE"
echo
echo "Archive size:"
du -h "$ARCHIVE"
```

## Automation Security Improvement

Removing `sudo` from inside the script improved unattended execution.

The privilege model became:

```text
systemd
   |
   | executes as root
   v
backup-sentinelops.sh
   |
   +-- reads root-owned Nginx configuration
   +-- creates archive
   +-- changes archive ownership to emir
   +-- applies mode 600
```

This is more appropriate than attempting to provide an interactive sudo password to an automated service.

## Systemd Configuration Reload After Fix

After modifying the service and backup script, systemd was reloaded:

```bash
sudo systemctl daemon-reload
```

The previous failed service state was cleared using:

```bash
sudo systemctl reset-failed sentinelops-backup.service
```

## Successful Manual Systemd Backup

The corrected service was manually triggered again:

```bash
sudo systemctl start sentinelops-backup.service
```

The service completed successfully.

Service output included:

```text
Backup created:
/home/emir/backups/sentinelops/sentinelops-backup-20260828T185351Z.tar.gz

Archive size:
4.0K
```

Systemd reported:

```text
sentinelops-backup.service: Deactivated successfully.
Finished sentinelops-backup.service - SentinelOps local backup.
```

## Successful Oneshot Service State

After successful execution:

```bash
systemctl status sentinelops-backup.service
```

reported the service as:

```text
inactive (dead)
```

This is the expected successful idle state for a completed oneshot service.

The journal recorded successful completion rather than a failed result.

## New Backup Archive

The backup directory was reviewed using:

```bash
ls -lh ~/backups/sentinelops/
```

Observed state:

```text
backup-sentinelops.sh
sentinelops-backup-20260827T155515Z.tar.gz
sentinelops-backup-20260828T185351Z.tar.gz
```

The new archive confirmed that systemd successfully executed the backup script.

## Archive Permissions After Automation

The new archive permissions were:

```text
-rw-------
```

The file remained owned by:

```text
emir:emir
```

This confirmed that the automated backup preserved the restrictive archive permissions established in SEN-012.

## Backup Service Journal

The backup service journal was reviewed using:

```bash
journalctl -u sentinelops-backup.service -n 30 --no-pager
```

The journal preserved both the initial failed test and the later successful execution.

The successful execution contained:

```text
Starting sentinelops-backup.service - SentinelOps local backup...
Backup created:
/home/emir/backups/sentinelops/sentinelops-backup-20260828T185351Z.tar.gz
Archive size:
4.0K
sentinelops-backup.service: Deactivated successfully.
Finished sentinelops-backup.service - SentinelOps local backup.
```

This provides a clear audit trail for automated backup executions.

## Timer Enablement

The production timer was enabled and started using:

```bash
sudo systemctl enable --now sentinelops-backup.timer
```

Systemd created:

```text
/etc/systemd/system/timers.target.wants/sentinelops-backup.timer
```

as a symbolic link to the timer unit.

This configured the timer to start automatically during system boot.

## Timer State

Timer status was checked using:

```bash
systemctl status sentinelops-backup.timer
```

Observed result:

```text
Loaded: loaded
enabled
Active: active (waiting)
Trigger: Sat 2026-08-29 00:00:00 UTC
```

This confirmed that the timer was enabled and actively waiting for the next scheduled run.

## Timer Enablement Verification

Enablement was explicitly checked using:

```bash
systemctl is-enabled sentinelops-backup.timer
```

Result:

```text
enabled
```

## Scheduled Execution Visibility

The timer schedule was reviewed using:

```bash
systemctl list-timers --all | grep sentinelops
```

The output showed:

```text
sentinelops-backup.timer
sentinelops-backup.service
```

with the next trigger scheduled for:

```text
Sat 2026-08-29 00:00:00 UTC
```

This confirmed that the production timer was registered with systemd.

## Controlled Timer Trigger Test

Waiting until midnight was unnecessary for functional verification.

The timer was temporarily changed to a short test interval.

The `[Timer]` section was changed to:

```ini
[Timer]
OnBootSec=1min
OnUnitActiveSec=2min
Persistent=true
Unit=sentinelops-backup.service
```

The `[Unit]` and `[Install]` sections remained unchanged.

## Timer Reload for Test

After modifying the timer:

```bash
sudo systemctl daemon-reload
```

was executed.

The timer was then restarted:

```bash
sudo systemctl restart sentinelops-backup.timer
```

## Test Timer State

The short-interval timer reported:

```text
Active: active (waiting)
```

with an upcoming trigger approximately two minutes later.

The timer list confirmed the scheduled automatic execution.

## Timer-Triggered Backup

During the controlled test, systemd triggered the backup service automatically.

A new archive appeared:

```text
sentinelops-backup-20260828T185854Z.tar.gz
```

This was the third archive in the backup directory.

## Timer Trigger Journal Evidence

The backup service journal showed:

```text
Aug 28 18:58:54 sentinelops-ubuntu systemd[1]: Starting sentinelops-backup.service - SentinelOps local backup...
Aug 28 18:58:54 sentinelops-ubuntu backup-sentinelops.sh: Backup created:
Aug 28 18:58:54 sentinelops-ubuntu backup-sentinelops.sh: /home/emir/backups/sentinelops/sentinelops-backup-20260828T185854Z.tar.gz
Aug 28 18:58:54 sentinelops-ubuntu backup-sentinelops.sh: Archive size:
Aug 28 18:58:54 sentinelops-ubuntu systemd[1]: sentinelops-backup.service: Deactivated successfully.
Aug 28 18:58:54 sentinelops-ubuntu systemd[1]: Finished sentinelops-backup.service - SentinelOps local backup.
```

This proved that the timer itself could trigger a complete backup without operator interaction.

## Timer Test Result

The controlled timer test confirmed:

- systemd timer activation works;
- systemd can invoke the backup service;
- the service can run unattended;
- the backup script completes without interactive authentication;
- a new timestamped archive is created;
- archive permissions remain restrictive;
- journal entries record the execution.

## Production Schedule Restoration

After the controlled test, the timer was restored immediately to the intended production configuration:

```ini
[Unit]
Description=Run SentinelOps backup daily

[Timer]
OnCalendar=daily
Persistent=true
Unit=sentinelops-backup.service

[Install]
WantedBy=timers.target
```

## Production Timer Reload

The restored timer configuration was applied using:

```bash
sudo systemctl daemon-reload
```

The timer was restarted using:

```bash
sudo systemctl restart sentinelops-backup.timer
```

## Restored Daily Schedule Verification

Timer status reported:

```text
Loaded: loaded
enabled
Active: active (waiting)
Trigger: Sat 2026-08-29 00:00:00 UTC
```

The timer list also showed the next trigger at:

```text
Sat 2026-08-29 00:00:00 UTC
```

This confirmed that the temporary short-interval test configuration had been removed.

## Final Production Schedule

The resulting automated backup schedule is:

- **Frequency:** daily
- **Time:** `00:00 UTC`
- **Persistence:** enabled

The timer targets:

```text
sentinelops-backup.service
```

## Reboot Persistence Test

The Ubuntu VM was rebooted to verify that backup automation survived a system restart.

The reboot was initiated using:

```bash
sudo reboot
```

The SSH session closed as expected.

After the VM completed startup, SSH connectivity was restored from the Mac.

## Timer State After Reboot

After reboot, the timer remained active.

The timer status showed:

```text
Started sentinelops-backup.timer - Run SentinelOps backup daily.
```

It remained:

```text
enabled
```

and continued waiting for the next scheduled execution.

## Timer Enablement After Reboot

The command:

```bash
systemctl is-enabled sentinelops-backup.timer
```

returned:

```text
enabled
```

This confirmed persistence across reboot.

## Timer Schedule After Reboot

The timer list was checked using:

```bash
systemctl list-timers --all | grep sentinelops
```

Observed schedule:

```text
Sat 2026-08-29 00:00:00 UTC
```

The daily production schedule therefore remained intact after reboot.

## Docker State After Reboot

Docker was checked using:

```bash
systemctl status docker
```

The service reported:

```text
Loaded: loaded
enabled
Active: active (running)
```

Docker successfully returned after reboot.

## Nginx State After Reboot

Nginx was checked using:

```bash
systemctl status nginx
```

The service reported:

```text
Loaded: loaded
enabled
Active: active (running)
```

The reverse proxy remained operational.

## Compose Application State After Reboot

The application state was reviewed using:

```bash
docker compose -f ~/sentinelops-app/compose.yaml ps
```

Observed result included:

```text
sentinelops-app
Up
127.0.0.1:8000->80/tcp
```

This confirmed that the application returned successfully after reboot.

## Firewall State After Reboot

UFW was reviewed using:

```bash
sudo ufw status verbose
```

Observed state:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
```

The inbound rules remained:

```text
22/tcp                     ALLOW IN    Anywhere
80/tcp (Nginx HTTP)        ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
80/tcp (Nginx HTTP (v6))   ALLOW IN    Anywhere (v6)
```

No backup-related firewall rule was introduced.

## Listening Socket Verification

Relevant listening sockets were reviewed using:

```bash
ss -tulpn | grep -E ':22|:80|:8000'
```

Observed state:

```text
127.0.0.1:8000
0.0.0.0:80
0.0.0.0:22
[::]:80
[::]:22
```

This confirmed that:

- SSH remained externally available on TCP port 22;
- Nginx remained externally available on TCP port 80;
- the application backend remained bound only to loopback on TCP port 8000;
- no backup automation service introduced a listening port.

## External HTTP Verification

After exiting the Ubuntu SSH session, external application availability was checked from the Mac:

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

This confirmed that automated backup implementation did not disrupt the existing reverse-proxy path.

## Direct Backend Isolation Check

The Mac tested TCP port 8000 directly:

```bash
nc -vz -w 2 192.168.64.2 8000
```

No successful connection was established.

The command remained pending and was manually interrupted with:

```text
Ctrl+C
```

This still confirmed that the backend was not directly reachable from the Mac.

## Final Automation Architecture

The completed automated backup flow is:

```text
systemd timer
      |
      | daily at 00:00 UTC
      v
sentinelops-backup.service
      |
      | Type=oneshot
      | User=root
      v
backup-sentinelops.sh
      |
      +-- application files
      +-- Docker Compose configuration
      +-- monitoring script
      +-- Nginx configuration
      |
      v
Timestamped .tar.gz archive
      |
      v
chown emir:emir
chmod 600
      |
      v
/home/emir/backups/sentinelops/
```

## Service Responsibility

The systemd service is responsible for:

- execution context;
- privilege context;
- running the backup script;
- reporting execution success or failure;
- exposing status through systemd;
- exposing logs through `journalctl`.

## Timer Responsibility

The systemd timer is responsible for:

- recurring scheduling;
- daily execution;
- persistent scheduling behaviour;
- boot persistence;
- triggering the backup service.

## Script Responsibility

The existing backup script remains responsible for:

- creating the staging directory;
- collecting application files;
- collecting monitoring files;
- collecting Nginx configuration;
- creating the archive;
- applying final archive ownership;
- applying restrictive archive permissions;
- removing temporary staging data.

## Security Model

The automation preserves the existing SentinelOps security architecture.

- No new network service was introduced.
- No new inbound firewall rule was created.
- No monitoring or backup port was opened.
- No remote backup daemon was installed.
- No interactive password was stored.
- No sudo password was embedded in configuration.
- No SSH private key was added to the backup.
- The application backend remains private.

## Root Service Execution

The backup systemd service runs as root because one backup source is:

```text
/etc/nginx/sites-available/sentinelops
```

which is root-owned.

The resulting archive is explicitly transferred back to:

```text
emir:emir
```

and restricted to:

```text
600
```

This allows privileged file collection while preserving restrictive archive access.

## Failure Visibility

The initial failed execution demonstrated that backup failures are visible through:

```bash
systemctl status sentinelops-backup.service
```

and:

```bash
journalctl -u sentinelops-backup.service
```

This is valuable operational behaviour.

A failed automated backup does not silently appear successful.

## Successful Execution Visibility

Successful executions are also recorded in the journal.

Expected successful messages include:

```text
Backup created:
Archive size:
Deactivated successfully.
Finished sentinelops-backup.service - SentinelOps local backup.
```

This provides an audit trail for backup operations.

## Automated Backup Result

At completion of SEN-013:

- the existing SEN-012 backup script remains the backup implementation;
- the script has been adapted for unattended execution;
- embedded `sudo` usage has been removed;
- a dedicated systemd oneshot backup service exists;
- the service runs explicitly as root;
- a dedicated systemd timer exists;
- the timer is enabled;
- the timer is active;
- the production schedule is daily at `00:00 UTC`;
- persistent timer behaviour is enabled;
- manual service execution has been validated;
- unattended timer execution has been validated;
- systemd journal logging has been validated;
- backup failures are visible;
- backup successes are visible;
- new timestamped archives are generated automatically;
- archive permissions remain `600`;
- archive ownership remains `emir:emir`;
- timer persistence across reboot has been validated;
- Docker remains active;
- Nginx remains active;
- the Compose application remains active;
- UFW remains active;
- TCP port 8000 remains private;
- external HTTP remains operational;
- no backup network port has been introduced.

## Verification Summary

The following checks were successfully completed:

- reviewed the existing backup directory;
- verified the existing backup script;
- confirmed no backup service existed initially;
- confirmed no backup timer existed initially;
- created `sentinelops-backup.service`;
- configured `Type=oneshot`;
- created `sentinelops-backup.timer`;
- configured daily scheduling;
- configured `Persistent=true`;
- reloaded systemd configuration;
- verified the service unit was loaded;
- verified the timer unit was loaded;
- performed an initial manual service test;
- observed the unattended sudo failure;
- investigated the failure using service status;
- investigated the failure using `journalctl`;
- identified interactive sudo as the cause;
- changed the service execution user to root;
- removed sudo commands from the backup script;
- retained archive ownership as `emir:emir`;
- retained archive mode `600`;
- reloaded systemd;
- cleared the previous failed service state;
- manually executed the corrected service;
- confirmed successful oneshot execution;
- created `sentinelops-backup-20260828T185351Z.tar.gz`;
- verified the new archive existed;
- verified restrictive archive permissions;
- reviewed successful service journal output;
- enabled and started the backup timer;
- confirmed the timer was enabled;
- confirmed the timer was active (`waiting`);
- confirmed the daily schedule was visible;
- temporarily configured a short timer interval;
- reloaded and restarted the timer;
- observed automatic timer execution;
- created `sentinelops-backup-20260828T185854Z.tar.gz`;
- confirmed the timer-triggered backup through journal output;
- restored the production daily timer configuration;
- reloaded systemd again;
- confirmed the next production run was `00:00 UTC`;
- rebooted the Ubuntu VM;
- restored SSH connectivity;
- confirmed the timer remained enabled after reboot;
- confirmed the timer remained active after reboot;
- confirmed the next scheduled run remained visible;
- verified Docker remained active;
- verified Nginx remained active;
- verified the Compose application remained running;
- verified UFW remained active;
- verified only TCP ports 22 and 80 remained externally allowed;
- verified TCP port 8000 remained loopback-only;
- verified no new listening backup service existed;
- verified external HTTP returned `HTTP/1.1 200 OK`;
- verified direct backend access from the Mac did not succeed.

## Out of Scope

SEN-013 did not introduce:

- off-host backup replication;
- cloud backup storage;
- remote backup transfer;
- automated retention;
- archive deletion;
- backup encryption;
- backup alerting;
- email notifications;
- Slack notifications;
- PagerDuty;
- PostgreSQL backups;
- Docker volume backups;
- full VM snapshots;
- full filesystem backups;
- remote disaster recovery;
- object storage;
- CI/CD backup integration;
- external backup monitoring.

These capabilities remain reserved for later SentinelOps issues.

## Completion State

The SentinelOps local backup process is now automated through systemd.

A dedicated oneshot service executes the validated SEN-012 backup script, while a persistent systemd timer triggers that service every day at `00:00 UTC`.

The automation was tested manually, tested through an actual timer trigger, and verified across a full Ubuntu VM reboot.

An initial unattended execution failure caused by interactive sudo requirements was identified through systemd and journal logging and corrected using an explicit root service execution model.

The resulting backup archives continue to be owned by `emir`, remain protected with mode `600`, and require no interactive password entry.

Docker, Nginx, UFW, SSH, the Compose-managed application, and backend isolation remain operational and unchanged.

No new network port or remotely accessible backup service was introduced.

This establishes the automated local backup foundation required for later SentinelOps off-host replication, retention, alerting, and disaster-recovery work.