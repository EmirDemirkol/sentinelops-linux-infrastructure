# SEN-014: Automated Backup Retention and Rotation Baseline

## Purpose

This document records the implementation and verification of automated local backup retention and rotation for SentinelOps.

SEN-014 builds directly on the backup and recovery baseline established in SEN-012 and the persistent systemd backup automation established in SEN-013.

Before this issue, SentinelOps automatically created timestamped local backup archives through a systemd timer, but no automatic retention policy existed.

As a result, valid archives would continue accumulating indefinitely in:

```text
/home/emir/backups/sentinelops/
```

The goal of SEN-014 was to introduce a controlled seven-day local retention policy while preserving the existing backup workflow, archive security properties, systemd scheduling, application availability and network security architecture.

The implementation was deliberately tested using disposable backup artefacts before any cleanup logic was integrated into the production backup script.

No genuine verified backup archive was modified, artificially aged or deleted during retention testing.

---

# 1. Issue

GitHub issue:

```text
SEN-014: Implement automated backup retention and rotation
```

Status at implementation start:

```text
created
open
implementation not started
```

SEN-013 was already fully completed and closed.

Latest known completed baseline commit before SEN-014:

```text
fb98e95 docs: complete SEN-013 automated backup baseline
```

---

# 2. Objective

The objective of SEN-014 was to implement and verify:

- a defined seven-day local backup retention policy;
- automatic deletion of backup archives older than the retention threshold;
- safe matching of backup archive filenames;
- preservation of the backup script;
- preservation of recent genuine backup archives;
- controlled testing with disposable backup files;
- integration with the existing backup script;
- execution through the existing systemd service;
- retention activity visible through systemd logs;
- preservation of archive ownership;
- preservation of restrictive archive permissions;
- preservation of the daily systemd timer;
- preservation of the existing firewall state;
- preservation of private backend isolation;
- preservation of external HTTP availability.

---

# 3. Scope

SEN-014 modified only the local backup lifecycle.

The primary live implementation file was:

```text
/home/emir/backups/sentinelops/backup-sentinelops.sh
```

The existing systemd service remained:

```text
/etc/systemd/system/sentinelops-backup.service
```

The existing timer remained:

```text
/etc/systemd/system/sentinelops-backup.timer
```

No change to the systemd unit files was required.

The retention process operates only inside:

```text
/home/emir/backups/sentinelops/
```

and only against regular files matching:

```text
sentinelops-backup-*.tar.gz
```

---

# 4. Initial Architecture

Before SEN-014, the automated backup architecture was:

```text
systemd timer
    |
    v
sentinelops-backup.service
    |
    | User=root
    v
backup-sentinelops.sh
    |
    +-- collect application files
    +-- collect monitoring script
    +-- collect Nginx configuration
    +-- create timestamped tar.gz archive
    +-- chown archive to emir:emir
    +-- chmod archive to 600
```

Archives accumulated indefinitely.

There was no automated cleanup stage.

---

# 5. Initial Git State

Development began from the existing SentinelOps repository on the Mac:

```text
~/Desktop/sentinelops-linux-infrastructure
```

The starting branch was:

```text
main
```

The repository was verified as clean and synchronised.

Observed state:

```text
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

The latest commit was:

```text
fb98e95 docs: complete SEN-013 automated backup baseline
```

A dedicated feature branch was then created for SEN-014:

```bash
git switch -c sen-014-backup-retention
```

Branch:

```text
sen-014-backup-retention
```

This marks the transition from the historical direct-to-main workflow used for most earlier SentinelOps issues to the newer feature-branch workflow.

---

# 6. Initial Ubuntu Inspection

The live Ubuntu VM remained the authoritative infrastructure source.

Connection from the Mac:

```bash
ssh emir@192.168.64.2
```

The Ubuntu prompt was:

```text
emir@sentinelops-ubuntu:~$
```

The backup directory was inspected before making any changes:

```bash
ls -lh ~/backups/sentinelops/
```

The directory contained:

```text
backup-sentinelops.sh
```

and five genuine backup archives.

Observed genuine archive inventory before implementation:

```text
sentinelops-backup-20260827T155515Z.tar.gz
sentinelops-backup-20260828T185351Z.tar.gz
sentinelops-backup-20260828T185854Z.tar.gz
sentinelops-backup-20260828T190100Z.tar.gz
sentinelops-backup-20260829T053444Z.tar.gz
```

The archive inventory was newer than the previous SEN-013 handoff because the persistent timer had continued operating.

This confirmed why the live VM must be inspected before relying on historical documentation.

---

# 7. Initial Filesystem State

Root filesystem state was checked with:

```bash
df -h /
```

Observed approximate state:

```text
Filesystem size: 14G
Available:       6.6G
Usage:           48%
```

The filesystem was healthy, but the relatively small root logical volume reinforced the value of introducing bounded local backup retention.

---

# 8. Existing Timer State

The systemd timer was inspected before modification:

```bash
systemctl status sentinelops-backup.timer
systemctl is-enabled sentinelops-backup.timer
```

Observed state:

```text
enabled
active (waiting)
```

The next scheduled run shown during inspection was:

```text
Sun 2026-08-30 00:00:00 UTC
```

The production timer remained configured for daily execution.

---

# 9. Existing Backup Script Inspection

The current backup script was inspected directly:

```bash
cat ~/backups/sentinelops/backup-sentinelops.sh
```

This confirmed the authoritative SEN-013 privilege architecture.

The script contained:

```text
no sudo
```

The script already:

- created a temporary staging directory;
- copied the required files;
- generated a compressed archive;
- assigned final ownership to `emir:emir`;
- assigned mode `600`;
- used a cleanup trap for the staging directory.

This current live script superseded the older SEN-012 version that had contained internal `sudo`.

---

# 10. Existing Systemd Service Inspection

The systemd service was inspected:

```bash
sudo cat /etc/systemd/system/sentinelops-backup.service
```

Observed configuration:

```ini
[Unit]
Description=SentinelOps local backup
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=/home/emir/backups/sentinelops/backup-sentinelops.sh
```

Important properties:

```text
Type=oneshot
User=root
```

The service runs with sufficient privileges to read the root-owned Nginx configuration.

The backup script therefore does not require interactive `sudo`.

---

# 11. Existing Systemd Timer Inspection

The timer was inspected:

```bash
sudo cat /etc/systemd/system/sentinelops-backup.timer
```

Observed configuration:

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

The production schedule remained:

```text
daily at 00:00 UTC
```

Persistence remained:

```text
Persistent=true
```

No SEN-014 change to the timer was required.

---

# 12. Retention Design

The approved retention policy was:

```text
7 days
```

The intended archive match was:

```text
sentinelops-backup-*.tar.gz
```

The target directory was:

```text
/home/emir/backups/sentinelops/
```

A critical safety condition was:

```text
backup-sentinelops.sh must never be eligible for deletion
```

The cleanup logic therefore needed to combine:

- a fixed backup directory;
- regular-file filtering;
- a specific archive filename pattern;
- an age threshold.

---

# 13. Disposable Test Artefacts

Retention deletion was not tested against genuine backups.

Two disposable files were created:

```bash
touch ~/backups/sentinelops/sentinelops-backup-TEST-OLD.tar.gz
touch ~/backups/sentinelops/sentinelops-backup-TEST-RECENT.tar.gz
```

The test files deliberately matched the archive filename pattern while containing no production data.

Their purpose was to prove:

- old matching files are selected;
- recent matching files are preserved;
- the backup script is not selected;
- genuine recent backups are preserved.

---

# 14. First Age Test

The OLD disposable file was initially aged by eight days:

```bash
touch -d '8 days ago' \
~/backups/sentinelops/sentinelops-backup-TEST-OLD.tar.gz
```

The timestamps were inspected:

```bash
ls -lh --time-style=long-iso \
~/backups/sentinelops/sentinelops-backup-TEST-*.tar.gz
```

Observed:

```text
sentinelops-backup-TEST-OLD.tar.gz
2026-08-21 15:07

sentinelops-backup-TEST-RECENT.tar.gz
2026-08-29 15:07
```

This established a clear expired and recent test pair.

---

# 15. Initial Selector Test

The first retention selector used:

```bash
find ~/backups/sentinelops/ \
  -maxdepth 1 \
  -type f \
  -name 'sentinelops-backup-*.tar.gz' \
  -mtime +7 \
  -print
```

Observed output:

```text
/home/emir/backups/sentinelops/sentinelops-backup-TEST-OLD.tar.gz
```

No other file was returned.

In particular:

```text
sentinelops-backup-TEST-RECENT.tar.gz
```

was not selected.

The genuine recent backup archives were not selected.

The script:

```text
backup-sentinelops.sh
```

was not selected.

---

# 16. First Controlled Deletion Test

After selection behaviour was verified with `-print`, the matching expired disposable file was deleted:

```bash
find ~/backups/sentinelops/ \
  -maxdepth 1 \
  -type f \
  -name 'sentinelops-backup-*.tar.gz' \
  -mtime +7 \
  -delete
```

The directory was then inspected:

```bash
ls -lh --time-style=long-iso ~/backups/sentinelops/
```

Observed state:

```text
sentinelops-backup-TEST-OLD.tar.gz
deleted

sentinelops-backup-TEST-RECENT.tar.gz
preserved

backup-sentinelops.sh
preserved

all genuine recent backups
preserved
```

This proved the fundamental filename and age safety model.

---

# 17. Retention Precision Review

Before production integration, the retention expression was reviewed more carefully.

The initial expression:

```text
-mtime +7
```

uses whole 24-hour age buckets.

For an exact seven-day policy, a minute-based threshold was preferred.

Seven days equals:

```text
7 × 24 × 60
```

which equals:

```text
10080 minutes
```

The planned production threshold therefore became:

```text
-mmin +10080
```

This expresses the retention rule directly in minutes.

---

# 18. Boundary-Test Mistake

An attempt was made to construct a file just over the seven-day threshold using:

```bash
touch -d '7 days 1 minute ago' \
~/backups/sentinelops/sentinelops-backup-TEST-OLD.tar.gz
```

The subsequent selector unexpectedly returned no output.

Rather than assuming the `find` expression was broken, the actual file timestamp was inspected:

```bash
stat ~/backups/sentinelops/sentinelops-backup-TEST-OLD.tar.gz
```

and the system time was checked:

```bash
date
```

The file unexpectedly showed a modification time around:

```text
2026-09-05 15:08:32 +0000
```

while current server time was approximately:

```text
Sat Aug 29 15:11:39 UTC 2026
```

The test artefact had therefore been placed into the future.

The absence of a retention match was correct.

This was a test-data construction problem, not a failure of the retention selector.

No production file was affected.

---

# 19. Boundary-Test Correction

The disposable OLD file was reset unambiguously:

```bash
touch -d '8 days ago' \
~/backups/sentinelops/sentinelops-backup-TEST-OLD.tar.gz
```

The timestamp was verified with:

```bash
stat ~/backups/sentinelops/sentinelops-backup-TEST-OLD.tar.gz
```

Observed modification time:

```text
2026-08-21 15:12:44 +0000
```

The production candidate selector was then tested:

```bash
find ~/backups/sentinelops/ \
  -maxdepth 1 \
  -type f \
  -name 'sentinelops-backup-*.tar.gz' \
  -mmin +10080 \
  -print
```

Observed output:

```text
/home/emir/backups/sentinelops/sentinelops-backup-TEST-OLD.tar.gz
```

Only the expired disposable file matched.

This confirmed the production candidate expression.

---

# 20. Final Retention Expression

The final production selection model became:

```bash
find "$BACKUP_DIR" \
    -maxdepth 1 \
    -type f \
    -name 'sentinelops-backup-*.tar.gz' \
    -mmin +"$RETENTION_MINUTES" \
    -print \
    -delete
```

with:

```bash
RETENTION_MINUTES=10080
```

The selector is constrained by:

```text
directory:
$BACKUP_DIR

depth:
-maxdepth 1

type:
-type f

name:
sentinelops-backup-*.tar.gz

age:
older than 10080 minutes
```

This prevents recursive deletion and avoids matching unrelated files.

---

# 21. Production Script Modification

The production backup script was opened:

```bash
nano ~/backups/sentinelops/backup-sentinelops.sh
```

The full file was replaced with:

```bash
#!/usr/bin/env bash

set -euo pipefail

BACKUP_DIR="/home/emir/backups/sentinelops"
RETENTION_MINUTES=10080
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
echo

echo "Removing backup archives older than 7 days:"
find "$BACKUP_DIR" \
    -maxdepth 1 \
    -type f \
    -name 'sentinelops-backup-*.tar.gz' \
    -mmin +"$RETENTION_MINUTES" \
    -print \
    -delete

echo
echo "Backup retention complete."
```

The Nano save sequence was:

```text
Ctrl+O
Enter
Ctrl+X
```

---

# 22. Script Syntax Validation

Before executing the modified backup script, Bash syntax was validated:

```bash
bash -n ~/backups/sentinelops/backup-sentinelops.sh
```

Observed result:

```text
no output
```

This confirmed that Bash detected no syntax errors.

The complete file was then inspected:

```bash
cat ~/backups/sentinelops/backup-sentinelops.sh
```

The retention logic was present in the expected location after successful archive creation and permission enforcement.

---

# 23. Why Retention Runs After Backup Creation

Retention was deliberately placed after:

```bash
tar -czf "$ARCHIVE" ...
chown emir:emir "$ARCHIVE"
chmod 600 "$ARCHIVE"
```

This preserves the existing backup-first workflow.

The sequence is now:

```text
collect files
    |
    v
create archive
    |
    v
set ownership
    |
    v
set permissions
    |
    v
remove expired matching archives
```

This means each service execution first creates the current backup before performing retention cleanup.

---

# 24. Systemd Integration Test

The modified workflow was tested through the real systemd service:

```bash
sudo systemctl start sentinelops-backup.service
```

This was intentionally preferred over running the script manually because the production automation path is:

```text
systemd -> backup script
```

The service completed successfully.

---

# 25. Systemd Service Result

Service status was inspected:

```bash
systemctl status sentinelops-backup.service
```

Observed state:

```text
Active: inactive (dead)
```

This was expected because:

```text
Type=oneshot
```

The important execution result was:

```text
code=exited
status=0/SUCCESS
```

Observed runtime timestamp:

```text
Sat 2026-08-29 15:17:06 UTC
```

Systemd reported:

```text
sentinelops-backup.service: Deactivated successfully.
Finished sentinelops-backup.service - SentinelOps local backup.
```

This confirmed successful completion.

---

# 26. New Archive Creation

The systemd service created:

```text
/home/emir/backups/sentinelops/sentinelops-backup-20260829T151706Z.tar.gz
```

This demonstrated that introducing retention did not break backup generation.

The archive filename retained the established UTC timestamp format:

```text
sentinelops-backup-YYYYMMDDTHHMMSSZ.tar.gz
```

---

# 27. Retention Logging

The service output showed:

```text
Removing backup archives older than 7 days:
```

followed by:

```text
/home/emir/backups/sentinelops/sentinelops-backup-TEST-OLD.tar.gz
```

and then:

```text
Backup retention complete.
```

This proved that the expired disposable archive was removed through the actual production execution path.

---

# 28. Journal Verification

The systemd journal was inspected:

```bash
sudo journalctl -u sentinelops-backup.service -n 30 --no-pager
```

The newest relevant execution showed:

```text
Aug 29 15:17:06 sentinelops-ubuntu systemd[1]:
Starting sentinelops-backup.service - SentinelOps local backup...
```

Then:

```text
Backup created:
```

followed by:

```text
/home/emir/backups/sentinelops/sentinelops-backup-20260829T151706Z.tar.gz
```

The archive size was reported.

Retention then logged:

```text
Removing backup archives older than 7 days:
```

and:

```text
/home/emir/backups/sentinelops/sentinelops-backup-TEST-OLD.tar.gz
```

The run ended with:

```text
Backup retention complete.
```

and:

```text
sentinelops-backup.service: Deactivated successfully.
Finished sentinelops-backup.service - SentinelOps local backup.
```

This provides systemd-level evidence that backup creation and retention were both completed successfully.

---

# 29. Historical Journal Context

The journal also contained older successful backup executions from SEN-013.

Examples included:

```text
2026-08-28 18:58:54 UTC
2026-08-28 19:01:01 UTC
2026-08-29 05:34:44 UTC
```

The newest SEN-014 execution occurred at:

```text
2026-08-29 15:17:06 UTC
```

The newest timestamp was treated as authoritative for the current implementation test.

Historical journal entries were not mistaken for current failures.

---

# 30. Post-Service Archive Inventory

The backup directory was inspected:

```bash
ls -lh --time-style=long-iso ~/backups/sentinelops/
```

Observed production archives:

```text
sentinelops-backup-20260827T155515Z.tar.gz
sentinelops-backup-20260828T185351Z.tar.gz
sentinelops-backup-20260828T185854Z.tar.gz
sentinelops-backup-20260828T190100Z.tar.gz
sentinelops-backup-20260829T053444Z.tar.gz
sentinelops-backup-20260829T151706Z.tar.gz
```

Observed test state:

```text
sentinelops-backup-TEST-OLD.tar.gz
deleted

sentinelops-backup-TEST-RECENT.tar.gz
preserved
```

Observed script state:

```text
backup-sentinelops.sh
preserved
```

---

# 31. Archive Ownership Verification

The newly generated archive appeared as:

```text
-rw------- 1 emir emir ...
sentinelops-backup-20260829T151706Z.tar.gz
```

Owner:

```text
emir
```

Group:

```text
emir
```

Therefore archive ownership remained:

```text
emir:emir
```

This preserved the SEN-013 privilege handoff model.

---

# 32. Archive Permission Verification

The newly generated archive appeared as:

```text
-rw-------
```

Equivalent mode:

```text
600
```

This confirmed that retention integration did not weaken archive permissions.

---

# 33. Disposable Test Cleanup

After retention behaviour was fully verified, the remaining recent disposable test file was removed manually:

```bash
rm ~/backups/sentinelops/sentinelops-backup-TEST-RECENT.tar.gz
```

The backup directory was then inspected:

```bash
ls -lh ~/backups/sentinelops/
```

No disposable test artefacts remained.

The final observed directory contained:

```text
backup-sentinelops.sh

sentinelops-backup-20260827T155515Z.tar.gz
sentinelops-backup-20260828T185351Z.tar.gz
sentinelops-backup-20260828T185854Z.tar.gz
sentinelops-backup-20260828T190100Z.tar.gz
sentinelops-backup-20260829T053444Z.tar.gz
sentinelops-backup-20260829T151706Z.tar.gz
```

---

# 34. Timer Regression Verification

The timer was checked again after implementation:

```bash
systemctl status sentinelops-backup.timer
```

Observed:

```text
Loaded: loaded
enabled
Active: active (waiting)
```

Next trigger:

```text
Sun 2026-08-30 00:00:00 UTC
```

The timer remained attached to:

```text
sentinelops-backup.service
```

---

# 35. Timer Enablement Verification

Enablement was checked separately:

```bash
systemctl is-enabled sentinelops-backup.timer
```

Observed:

```text
enabled
```

This confirmed that SEN-014 did not disable or replace the persistent backup schedule.

---

# 36. Timer Configuration Remained Unchanged

The production timer continues to use:

```ini
OnCalendar=daily
Persistent=true
```

No temporary short-interval timer was introduced during SEN-014.

The production schedule remains:

```text
00:00 UTC daily
```

---

# 37. UFW Regression Verification

Firewall state was checked:

```bash
sudo ufw status verbose
```

Observed:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
```

Allowed inbound rules remained:

```text
22/tcp
80/tcp (Nginx HTTP)
```

IPv6 equivalents also remained.

There was no allow rule for:

```text
8000/tcp
```

Retention implementation therefore introduced no firewall exposure.

---

# 38. Listening Port Regression Verification

Listening TCP ports were inspected:

```bash
ss -tulpn | grep -E ':22|:80|:8000'
```

Observed:

```text
127.0.0.1:8000
0.0.0.0:80
0.0.0.0:22
[::]:80
[::]:22
```

This preserved the intended network model.

Port:

```text
8000
```

remained bound only to:

```text
127.0.0.1
```

---

# 39. Docker Compose Regression Verification

The application stack was inspected:

```bash
docker compose -f ~/sentinelops-app/compose.yaml ps
```

Observed container:

```text
sentinelops-app
```

Observed state:

```text
Up
```

Observed mapping:

```text
127.0.0.1:8000->80/tcp
```

The Compose application remained operational.

---

# 40. External HTTP Regression Test

The Ubuntu SSH session was exited:

```bash
exit
```

From the Mac, external HTTP was tested:

```bash
curl -I http://192.168.64.2
```

Observed:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Content-Type: text/html
Content-Length: 1923
```

This confirmed that the public application path remained available through host Nginx.

---

# 41. Direct Backend Isolation Test

From the Mac:

```bash
nc -vz -w 2 192.168.64.2 8000
```

No successful TCP connection was established.

The command remained pending until manually interrupted with:

```text
Ctrl+C
```

This is valid evidence of the intended backend isolation.

The success criterion is not a particular timeout string.

The success criterion is:

```text
no TCP connection to 192.168.64.2:8000 is established from the Mac
```

That criterion remained satisfied.

---

# 42. Final Network Architecture

After SEN-014, application networking remains:

```text
Mac
 |
 | HTTP :80
 v
192.168.64.2
 |
 v
host Nginx
 |
 v
127.0.0.1:8000
 |
 v
Docker Compose application
 |
 v
container Nginx :80
```

SEN-014 introduced no new listener, firewall rule or network service.

---

# 43. Final Backup Architecture

The backup workflow is now:

```text
sentinelops-backup.timer
        |
        | daily
        | Persistent=true
        v
sentinelops-backup.service
        |
        | Type=oneshot
        | User=root
        v
backup-sentinelops.sh
        |
        +-- create staging directory
        |
        +-- copy application files
        |
        +-- copy monitoring script
        |
        +-- copy Nginx configuration
        |
        +-- create timestamped tar.gz archive
        |
        +-- chown archive emir:emir
        |
        +-- chmod archive 600
        |
        +-- locate matching archives older than 10080 minutes
        |
        +-- log matching archive paths
        |
        +-- delete expired matching archives
        |
        +-- clean temporary staging directory
```

---

# 44. Retention Safety Model

The cleanup command is constrained to:

```text
/home/emir/backups/sentinelops/
```

It uses:

```text
-maxdepth 1
```

so it does not recursively traverse unrelated directories.

It uses:

```text
-type f
```

so only regular files are considered.

It uses:

```text
-name 'sentinelops-backup-*.tar.gz'
```

so unrelated filenames are excluded.

It uses:

```text
-mmin +10080
```

so recent matching backups are preserved.

The backup script filename:

```text
backup-sentinelops.sh
```

does not match the archive pattern.

It is therefore not eligible for deletion.

---

# 45. Retention Policy Semantics

The production threshold is defined as:

```text
10080 minutes
```

which represents:

```text
7 days
```

Cleanup is based on filesystem modification age.

It does not parse the timestamp embedded in the archive filename.

This avoids relying on filename parsing for retention eligibility.

---

# 46. Current Backup Script

The authoritative script after SEN-014 is:

```bash
#!/usr/bin/env bash

set -euo pipefail

BACKUP_DIR="/home/emir/backups/sentinelops"
RETENTION_MINUTES=10080
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
echo

echo "Removing backup archives older than 7 days:"
find "$BACKUP_DIR" \
    -maxdepth 1 \
    -type f \
    -name 'sentinelops-backup-*.tar.gz' \
    -mmin +"$RETENTION_MINUTES" \
    -print \
    -delete

echo
echo "Backup retention complete."
```

---

# 47. Security State

The following security properties remained unchanged after SEN-014:

```text
SSH public-key authentication:
enabled

SSH password authentication:
disabled

direct root SSH:
disabled

UFW:
active

default incoming policy:
deny

22/tcp:
allowed

80/tcp:
allowed

8000/tcp:
not externally allowed

application backend:
127.0.0.1:8000

host Nginx:
public HTTP entry point

Docker daemon:
not remotely exposed
```

---

# 48. Backup Security State

Archive security properties remain:

```text
owner:
emir:emir

mode:
600
```

The backup service continues to execute as:

```text
root
```

The backup script continues to contain:

```text
no sudo
```

This preserves the corrected SEN-013 unattended execution model.

---

# 49. Verification Summary

The following checks succeeded.

## Repository baseline

```text
clean main baseline verified
latest commit fb98e95 verified
feature branch created
```

## Live backup baseline

```text
backup directory inspected
current archive inventory recorded
disk state inspected
```

## Existing automation

```text
service configuration inspected
timer configuration inspected
timer enabled
timer active
```

## Retention safety

```text
disposable old archive created
disposable recent archive created
old archive timestamped into the past
selector tested before deletion
only expired disposable archive selected
recent disposable preserved
backup script preserved
real backups preserved
```

## Retention precision

```text
10080-minute threshold selected
candidate selector tested
expired disposable archive correctly matched
```

## Production integration

```text
backup script modified
bash syntax valid
systemd service execution successful
new backup archive created
expired disposable archive deleted
recent disposable archive preserved
```

## Logging

```text
new backup path logged
retention phase logged
deleted expired path logged
retention completion logged
service completion logged
```

## Archive security

```text
owner emir:emir preserved
mode 600 preserved
```

## Timer

```text
enabled
active (waiting)
daily schedule preserved
Persistent=true preserved
```

## Security regression

```text
UFW active
default incoming deny
22 allowed
80 allowed
8000 not allowed
8000 loopback-only
Compose app running
HTTP 200 through Nginx
direct Mac connection to 8000 unavailable
```

---

# 50. Failure Encountered

One test-data error occurred during exact threshold testing.

The command:

```bash
touch -d '7 days 1 minute ago' \
~/backups/sentinelops/sentinelops-backup-TEST-OLD.tar.gz
```

produced an unexpected future timestamp.

The retention selector therefore returned no output.

This was correctly investigated with:

```bash
stat
date
```

The problem was identified as an incorrectly constructed test timestamp.

The production selector itself was not changed in response to the incorrect test artefact.

The file was reset using:

```bash
touch -d '8 days ago' ...
```

and the selector was retested successfully.

This troubleshooting event is intentionally documented rather than hidden.

---

# 51. Why Genuine Archives Were Not Used for Deletion Testing

The existing archives had already been verified by previous backup and recovery work.

Artificially aging or deleting them would introduce unnecessary risk.

Disposable zero-byte files were sufficient to verify:

- filename matching;
- age selection;
- deletion behaviour;
- preservation behaviour.

This isolated the destructive test from genuine recovery assets.

---

# 52. Why No Systemd Change Was Required

The existing service already runs:

```text
User=root
```

and executes:

```text
/home/emir/backups/sentinelops/backup-sentinelops.sh
```

The timer already executes the service daily.

By integrating retention directly into the backup script, every scheduled backup automatically receives the same retention behaviour.

No additional service or timer was required.

This kept SEN-014 within the smallest required infrastructure change.

---

# 53. Why No New Package Was Installed

Retention uses the existing GNU `find` utility already available on Ubuntu.

No additional package, daemon or external dependency was required.

This reduces configuration complexity and avoids unnecessary operational scope.

---

# 54. Why `backup-sentinelops.sh` Is Safe

The production cleanup selector requires filenames matching:

```text
sentinelops-backup-*.tar.gz
```

The script is named:

```text
backup-sentinelops.sh
```

It therefore cannot match the retention expression.

The successful disposable deletion tests and subsequent production service execution both confirmed that the script remained present.

---

# 55. Limitations

The retention baseline intentionally has several limitations.

## Local storage only

Archives remain on the same Ubuntu VM as the source configuration.

This does not protect against:

- VM loss;
- virtual disk failure;
- host storage failure;
- deletion of the UTM VM bundle.

## No off-host replication

No backup is currently copied to:

- another machine;
- external storage;
- object storage;
- cloud backup storage.

## No encryption layer

The archive is protected by Unix file permissions but is not separately encrypted.

## No backup alerting

No email, Slack or other notification occurs when:

- backup creation fails;
- retention fails;
- disk space becomes low.

## No capacity-based retention

Retention is time-based only.

It does not currently enforce:

- maximum archive count;
- maximum directory size;
- free-space threshold.

## No full VM backup

The system backs up selected SentinelOps application and configuration files only.

It is not a full operating-system or VM snapshot.

---

# 56. Out of Scope

The following were deliberately not implemented in SEN-014:

```text
off-host backup replication
cloud backup storage
remote backup transfer
backup encryption
object storage
full VM snapshots
database backups
backup email alerts
Slack alerts
PagerDuty integration
Prometheus
Grafana
HTTPS
Ansible
Terraform
disaster recovery to another host
Docker image backups
full filesystem backups
```

Any of these would require a separate SentinelOps issue.

---

# 57. No Database Workflow

SentinelOps currently has no relational application database.

Therefore SEN-014 did not involve:

```text
database migrations
database dumps
ORM models
synthetic database records
database restore testing
```

Disposable backup files were the correct synthetic test artefacts for this infrastructure issue.

---

# 58. No Application Behaviour Change

SEN-014 did not change:

```text
index.html
Dockerfile
compose.yaml
Nginx routing
application HTTP behaviour
```

Established HTTP behaviour remained:

```text
GET / -> HTTP 200
HEAD / -> HTTP 200
```

---

# 59. No Network Scope Expansion

SEN-014 added:

```text
no firewall rule
no new listener
no new service port
no public container port
```

The backend remained private.

---

# 60. Final Architecture

The final SentinelOps infrastructure relevant to this issue is:

```text
Mac host
   |
   | SSH :22
   | HTTP :80
   v
Ubuntu Server VM
   |
   +-- UFW
   |     |
   |     +-- 22/tcp allowed
   |     +-- 80/tcp allowed
   |     +-- 8000/tcp not externally allowed
   |
   +-- host Nginx :80
   |       |
   |       v
   |   127.0.0.1:8000
   |       |
   |       v
   |   Docker Compose application
   |
   +-- sentinelops-monitoring
   |
   +-- local backup system
           |
           +-- sentinelops-backup.timer
           |      |
           |      +-- daily
           |      +-- Persistent=true
           |
           +-- sentinelops-backup.service
           |      |
           |      +-- Type=oneshot
           |      +-- User=root
           |
           +-- backup-sentinelops.sh
                  |
                  +-- create archive
                  +-- owner emir:emir
                  +-- mode 600
                  +-- retain <= 7 days
                  +-- remove matching archives > 7 days
                  +-- log retention action
```

---

# 61. Final Operational State

At the end of technical verification:

```text
Ubuntu:
operational

SSH:
operational

UFW:
active

Nginx:
operational

Docker:
operational

Compose application:
Up

external HTTP:
HTTP 200

backend port 8000:
loopback-only
not directly reachable from Mac

backup creation:
operational

retention:
operational

retention threshold:
10080 minutes

expired disposable archive:
successfully removed

recent disposable archive:
correctly preserved during test
then manually removed

genuine backups:
preserved

backup script:
preserved

new archive ownership:
emir:emir

new archive permissions:
600

systemd backup service:
successful

systemd timer:
enabled
active (waiting)

production timer schedule:
daily at 00:00 UTC

Persistent:
true
```

---

# 62. Completion State

SEN-014 technical implementation and runtime verification are complete.

The implementation now provides controlled seven-day local backup retention without changing the established SentinelOps security or application architecture.

The system:

```text
creates a new backup
secures the archive
removes only expired matching backup archives
preserves recent backups
preserves the backup script
logs retention through systemd
continues operating through the existing daily timer
```

The remaining project workflow after this documentation is:

```text
documentation validation
-> Git review
-> stage explicit documentation file
-> staged diff validation
-> commit
-> push feature branch
-> create PR
-> manual PR review
-> merge
-> completion comment
-> close SEN-014
-> switch to main
-> pull merged main
-> delete feature branch
-> verify clean working tree
```