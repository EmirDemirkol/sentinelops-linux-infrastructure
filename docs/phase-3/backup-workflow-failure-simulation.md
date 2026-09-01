# SEN-023: Backup Workflow Failure Simulation

## Summary

SEN-023 completes the third controlled SentinelOps failure simulation by intentionally causing the automated backup workflow to fail and documenting the complete incident lifecycle.

The simulation demonstrates:

- healthy pre-failure backup state;
- safe controlled backup failure;
- preservation of existing valid backup artifacts;
- systemd failure detection;
- journal-based diagnosis;
- fault isolation;
- recovery;
- successful post-recovery backup execution;
- archive verification;
- SHA-256 checksum verification;
- manifest verification;
- backup freshness verification;
- timer persistence;
- application and infrastructure regression checks;
- resilience and monitoring improvement considerations.

The controlled failure was introduced by temporarily renaming one required backup source file:

```text
/home/emir/sentinelops-app/Dockerfile
```

to:

```text
/home/emir/sentinelops-app/Dockerfile.sen-023-test
```

The backup script then failed when attempting to copy the expected `Dockerfile`.

Because the backup script uses:

```bash
set -euo pipefail
```

the failed `cp` command caused the script to exit immediately with a non-zero exit status.

The service entered the systemd failed state.

Existing valid backup archives were not modified or deleted.

After diagnosis, the Dockerfile was restored, the failed unit state was reset, and the backup service was executed again successfully.

A new backup triplet was created:

```text
sentinelops-backup-20260901T100712Z.tar.gz
sentinelops-backup-20260901T100712Z.tar.gz.sha256
sentinelops-backup-20260901T100712Z.tar.gz.manifest
```

The new archive passed SHA-256 verification.

The new manifest matched the archive listing exactly.

The backup timer remained enabled and active.

The SentinelOps environment was fully restored to its verified healthy state before completion.

---

# Purpose

The purpose of SEN-023 is to prove that SentinelOps can safely detect, diagnose, and recover from a failure in the automated backup workflow.

This scenario focuses on backup execution rather than application availability.

SEN-021 tested:

```text
application container failure
```

SEN-022 tested:

```text
host Nginx failure
```

SEN-023 tests:

```text
backup workflow failure
```

Together these scenarios cover three different operational failure domains:

```text
application layer
reverse-proxy layer
backup and recoverability layer
```

The objective is not only to make the backup job fail.

The objective is to prove that the failure can be:

```text
detected
diagnosed
isolated
recovered
verified
documented
```

without damaging the existing backup set.

---

# Requirements Mapping

SEN-023 contributes directly to the SentinelOps controlled failure simulation requirements.

## FR-35

> Perform at least three controlled infrastructure or application failure simulations.

SEN-023 represents the third controlled simulation.

The three completed scenarios are:

```text
SEN-021
Application container failure

SEN-022
Host Nginx failure

SEN-023
Backup workflow failure
```

The SEN-023 failure was introduced deliberately and safely.

---

## FR-36

> Demonstrate failure detection.

The failed backup execution was detected through systemd.

The service reported:

```text
sentinelops-backup.service
failed
```

The journal recorded:

```text
cp: cannot stat '/home/emir/sentinelops-app/Dockerfile': No such file or directory
```

and:

```text
sentinelops-backup.service: Main process exited, code=exited, status=1/FAILURE
```

The failed unit was also visible through:

```bash
systemctl --failed
```

---

## FR-37

> Document diagnosis evidence.

Diagnosis used:

- service status;
- systemd failed-unit state;
- backup journal;
- backup script inspection;
- backup source-file inspection;
- archive counts;
- newest archive verification;
- timer state;
- unrelated service state;
- application health;
- UFW state.

---

## FR-38

> Document recovery steps.

Recovery consisted of:

1. restoring the temporarily renamed Dockerfile;
2. resetting the failed systemd state;
3. executing the backup service again;
4. verifying successful completion;
5. verifying the newly created archive;
6. verifying checksum integrity;
7. verifying manifest accuracy;
8. confirming backup freshness;
9. confirming the timer remained operational;
10. confirming unrelated infrastructure remained healthy.

---

## FR-39

> Verify restoration of normal service.

Normal backup operation was restored.

The recovered backup service completed successfully with:

```text
status=0/SUCCESS
```

A new archive was created.

A new checksum file was created.

A new manifest file was created.

The checksum verification returned:

```text
OK
```

Manifest verification returned no differences.

Backup freshness returned:

```text
Backup age: 0 hour(s)
Backup freshness: OK
```

---

## FR-40

> Document prevention or improvement controls.

Existing controls and future improvements are documented later in this report.

A particularly important finding was that backup freshness monitoring alone did not immediately detect the failed execution because a recent valid backup still existed.

This identifies a legitimate observability improvement opportunity.

---

# Scope

SEN-023 covers:

```text
failure of sentinelops-backup.service
```

The test intentionally targets the backup execution path.

The following components were not intentionally failed:

- Docker;
- the application container;
- host Nginx;
- SSH;
- UFW;
- the VM;
- filesystem capacity;
- networking;
- existing backup archives;
- existing checksums;
- existing manifests.

---

# Backup Architecture

The deployed backup architecture is:

```text
sentinelops-backup.timer
        |
        v
sentinelops-backup.service
        |
        v
/home/emir/backups/sentinelops/backup-sentinelops.sh
        |
        v
temporary staging directory
        |
        v
archive generation
        |
        +--> manifest generation
        |
        +--> manifest verification
        |
        +--> SHA-256 generation
        |
        +--> SHA-256 verification
        |
        v
retention processing
```

The timer invokes:

```text
sentinelops-backup.service
```

The service executes:

```text
/home/emir/backups/sentinelops/backup-sentinelops.sh
```

The resulting backup artifacts are stored under:

```text
/home/emir/backups/sentinelops
```

---

# systemd Service Definition

The service definition was inspected with:

```bash
sudo systemctl cat sentinelops-backup.service
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
Type
oneshot

User
root

ExecStart
/home/emir/backups/sentinelops/backup-sentinelops.sh
```

The service performs one backup execution and then exits.

Therefore a successful execution normally ends with:

```text
inactive (dead)
```

combined with:

```text
status=0/SUCCESS
```

This is expected behavior for the oneshot service.

---

# systemd Timer Definition

The timer was inspected with:

```bash
sudo systemctl cat sentinelops-backup.timer
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

Important controls:

```text
OnCalendar=daily
```

The backup runs daily.

```text
Persistent=true
```

Missed timer executions can be triggered after the machine becomes available again.

---

# Healthy Pre-Failure Baseline

Before the controlled failure was introduced, the existing backup workflow was inspected and verified.

---

## Timer State

The timer status showed:

```text
Loaded: loaded
enabled

Active: active (waiting)
```

The next trigger was scheduled for:

```text
Wed 2026-09-02 00:00:00 UTC
```

The timer was therefore operating normally before the simulation.

---

## Timer Enabled State

The command:

```bash
systemctl is-enabled sentinelops-backup.timer
```

returned:

```text
enabled
```

---

## Timer Active State

The command:

```bash
systemctl is-active sentinelops-backup.timer
```

returned:

```text
active
```

---

# Previous Backup Service State

Before the simulation, the service status showed its most recent automatic run completed successfully.

Relevant evidence:

```text
Active: inactive (dead)
```

and:

```text
Process:
code=exited
status=0/SUCCESS
```

The previous execution completed at:

```text
2026-09-01 00:00:13 UTC
```

The service journal contained:

```text
Backup manifest verification complete.
```

```text
SHA-256 checksum created.
```

```text
Verifying backup integrity.
```

```text
sentinelops-backup-20260901T000013Z.tar.gz: OK
```

```text
Backup integrity verification complete.
```

```text
Backup retention complete.
```

```text
Finished sentinelops-backup.service - SentinelOps local backup.
```

This established a known-good baseline.

---

# Backup Script Inspection

The deployed script was inspected using:

```bash
sudo sed -n '1,260p' /home/emir/backups/sentinelops/backup-sentinelops.sh
```

The script begins with:

```bash
#!/usr/bin/env bash

set -euo pipefail
```

This is significant.

---

## Strict Error Handling

The script uses:

```bash
set -euo pipefail
```

This means:

```text
-e
exit when an unhandled command fails

-u
treat unset variables as errors

pipefail
propagate pipeline failures
```

This strict behavior made it possible to create a controlled failure at an early backup stage.

---

# Backup Directory

The script defines:

```bash
BACKUP_DIR="/home/emir/backups/sentinelops"
```

Retention is defined as:

```bash
RETENTION_MINUTES=10080
```

which corresponds to:

```text
7 days
```

---

# Temporary Staging Directory

The script creates a temporary directory using:

```bash
STAGING_DIR="$(mktemp -d)"
```

and registers:

```bash
trap cleanup EXIT
```

with:

```bash
cleanup() {
    rm -rf "$STAGING_DIR"
}
```

This means temporary staging content is cleaned when the script exits.

That behavior is useful during a failed backup execution because temporary data should not remain indefinitely.

---

# Backup Source Files

The script copies the following application files:

```text
/home/emir/sentinelops-app/index.html
/home/emir/sentinelops-app/Dockerfile
/home/emir/sentinelops-app/compose.yaml
```

It also copies:

```text
/home/emir/sentinelops-monitoring/health-check.sh
```

and:

```text
/etc/nginx/sites-available/sentinelops
```

---

# Archive Generation

The archive is created using:

```bash
tar -czf "$ARCHIVE" -C "$STAGING_DIR" .
```

The archive is then assigned:

```text
owner
emir:emir
```

and:

```text
permissions
600
```

---

# Manifest Generation

The manifest is generated using:

```bash
tar -tzf "$ARCHIVE" > "$MANIFEST_FILE"
```

It is then verified using:

```bash
diff -u "$MANIFEST_FILE" <(tar -tzf "$ARCHIVE")
```

A successful manifest verification produces no differences.

---

# SHA-256 Generation

The checksum is generated with:

```bash
sha256sum "$(basename "$ARCHIVE")" > "$(basename "$CHECKSUM_FILE")"
```

and verified with:

```bash
sha256sum --check "$(basename "$CHECKSUM_FILE")"
```

---

# Retention

The script identifies old archives using:

```bash
find "$BACKUP_DIR" \
    -maxdepth 1 \
    -type f \
    -name 'sentinelops-backup-*.tar.gz' \
    -mmin +"$RETENTION_MINUTES"
```

When an old archive is removed, the matching checksum and manifest are also removed where present.

This preserves paired artifact behavior.

---

# Healthy Backup Set

The backup directory was inspected with:

```bash
ls -lah /home/emir/backups/sentinelops
```

Multiple historical archives were present.

The newest valid pre-failure archive was:

```text
sentinelops-backup-20260901T000013Z.tar.gz
```

Its associated metadata files were:

```text
sentinelops-backup-20260901T000013Z.tar.gz.sha256
sentinelops-backup-20260901T000013Z.tar.gz.manifest
```

---

# Pre-Failure Artifact Metadata

The newest triplet showed:

```text
archive
3140 bytes

manifest
167 bytes

checksum
109 bytes
```

Ownership:

```text
emir:emir
```

Permissions:

```text
600
```

represented by:

```text
-rw-------
```

---

# Pre-Failure SHA-256 Verification

Checksum verification was executed using:

```bash
sha256sum --check "$(basename "$NEWEST_ARCHIVE").sha256"
```

Result:

```text
sentinelops-backup-20260901T000013Z.tar.gz: OK
```

This confirmed that the newest existing backup archive matched its stored checksum before failure injection.

---

# Pre-Failure Manifest Verification

The manifest was compared with the actual archive listing using:

```bash
diff -u \
    "$(basename "$NEWEST_ARCHIVE").manifest" \
    <(tar -tzf "$(basename "$NEWEST_ARCHIVE")")
```

Result:

```text
no output
```

No output from `diff` indicates the manifest matched the archive contents.

---

# Backup Freshness Baseline

The SentinelOps health check reported:

```text
Newest backup:
sentinelops-backup-20260901T000013Z.tar.gz
```

and:

```text
Backup age:
9 hour(s)
```

with:

```text
Backup freshness:
OK
```

The existing valid backup was therefore comfortably within the configured freshness threshold.

---

# Infrastructure Baseline

Before failure:

```text
Docker
active

Nginx
active

SSH
active
```

Application health returned:

```text
HTTP 200
```

with:

```json
{"status":"healthy","version":"0.1.0"}
```

---

# Firewall Baseline

UFW reported:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
```

Inbound rules remained:

```text
22/tcp
80/tcp
```

No external TCP 8000 rule existed.

---

# Failed Unit Baseline

Before failure:

```bash
systemctl --failed
```

returned:

```text
0 loaded units listed.
```

The host therefore began SEN-023 without existing failed systemd units.

---

# Archive Count Baseline

Before failure injection, the number of backup archives was counted.

Command:

```bash
printf 'Archive count before failure: '

find /home/emir/backups/sentinelops \
    -maxdepth 1 \
    -type f \
    -name 'sentinelops-backup-*.tar.gz' \
    | wc -l
```

Result:

```text
Archive count before failure: 11
```

The value:

```text
11
```

became the reference for detecting whether the failed run incorrectly created a new archive.

---

# Newest Archive Baseline

Before failure:

```bash
ls -1t /home/emir/backups/sentinelops/sentinelops-backup-*.tar.gz | head -1
```

returned:

```text
/home/emir/backups/sentinelops/sentinelops-backup-20260901T000013Z.tar.gz
```

This established the precise newest valid backup before the simulated failure.

---

# Failure Design

The controlled failure needed to satisfy several conditions.

It had to:

- force the real systemd backup service to fail;
- produce a non-zero exit status;
- generate useful operational evidence;
- avoid corruption of existing valid backups;
- avoid deleting backup artifacts;
- avoid stopping the live application;
- avoid changing Docker;
- avoid changing Nginx;
- avoid changing UFW;
- be completely reversible.

---

# Selected Failure Mechanism

The selected failure mechanism was to temporarily rename:

```text
/home/emir/sentinelops-app/Dockerfile
```

to:

```text
/home/emir/sentinelops-app/Dockerfile.sen-023-test
```

Command:

```bash
mv /home/emir/sentinelops-app/Dockerfile \
   /home/emir/sentinelops-app/Dockerfile.sen-023-test
```

---

# Why the Dockerfile Was Selected

The Dockerfile is required by the backup script.

The script executes:

```bash
cp /home/emir/sentinelops-app/Dockerfile \
   "$STAGING_DIR/application/"
```

However, the currently running application container does not require the host Dockerfile to remain present after the container image has already been built and started.

Therefore the temporary rename:

```text
affects the backup source
```

without intentionally causing:

```text
application runtime failure
```

This made it suitable for a controlled backup-only simulation.

---

# Failure Injection

After temporarily renaming the Dockerfile, the real backup systemd service was manually executed:

```bash
sudo systemctl start sentinelops-backup.service
```

systemd returned:

```text
Job for sentinelops-backup.service failed because the control process exited with error code.
```

This confirmed the intended failure was triggered.

---

# Failed-State Journal Evidence

The backup service journal was queried:

```bash
sudo journalctl -u sentinelops-backup.service \
    --since "2026-09-01 09:50:00" \
    --no-pager
```

The critical lines were:

```text
Sep 01 10:03:41 sentinelops-ubuntu systemd[1]:
Starting sentinelops-backup.service - SentinelOps local backup...
```

```text
Sep 01 10:03:41 sentinelops-ubuntu backup-sentinelops.sh[10877]:
cp: cannot stat '/home/emir/sentinelops-app/Dockerfile': No such file or directory
```

```text
Sep 01 10:03:41 sentinelops-ubuntu systemd[1]:
sentinelops-backup.service: Main process exited, code=exited, status=1/FAILURE
```

```text
Sep 01 10:03:41 sentinelops-ubuntu systemd[1]:
sentinelops-backup.service: Failed with result 'exit-code'.
```

```text
Sep 01 10:03:41 sentinelops-ubuntu systemd[1]:
Failed to start sentinelops-backup.service - SentinelOps local backup.
```

This provides a complete failure chain.

---

# Failed Backup Stage

The backup failed during the staging-copy phase.

Specifically:

```text
copy application Dockerfile
```

failed.

The command in the script was:

```bash
cp /home/emir/sentinelops-app/Dockerfile \
   "$STAGING_DIR/application/"
```

Because the expected source path was temporarily absent, `cp` returned an error.

---

# Strict Bash Failure Propagation

The script contains:

```bash
set -euo pipefail
```

The failed `cp` therefore caused the backup script to stop immediately.

The final process state was:

```text
status=1/FAILURE
```

This demonstrates that strict Bash error handling prevented the script from continuing as though the staging operation had succeeded.

---

# Failed systemd State

The command:

```bash
systemctl --failed
```

returned:

```text
UNIT                         LOAD   ACTIVE SUB    DESCRIPTION
sentinelops-backup.service   loaded failed failed SentinelOps local backup
```

The summary showed:

```text
1 loaded units listed.
```

This was a clear system-level failure signal.

---

# Preservation of Existing Archives

The archive count was checked immediately after the failed execution.

Result:

```text
Archive count after failed run: 11
```

The pre-failure count was also:

```text
11
```

Therefore:

```text
before
11

after failed run
11
```

No false successful archive was created.

---

# Newest Existing Archive After Failure

After the failed run:

```bash
ls -1t /home/emir/backups/sentinelops/sentinelops-backup-*.tar.gz | head -1
```

still returned:

```text
/home/emir/backups/sentinelops/sentinelops-backup-20260901T000013Z.tar.gz
```

This was the same archive that existed before failure injection.

The failed run did not replace the newest valid backup.

---

# Existing Backup Preservation

The existing valid backup set remained intact.

No intentional operation was performed against:

```text
sentinelops-backup-20260901T000013Z.tar.gz
```

or its:

```text
.sha256
```

and:

```text
.manifest
```

files.

This was a key safety requirement for SEN-023.

---

# Timer State During Failure

The timer was checked while the backup service itself was failed.

`systemctl is-enabled` returned:

```text
enabled
```

`systemctl is-active` returned:

```text
active
```

Detailed timer status showed:

```text
Active: active (waiting)
```

The next trigger remained scheduled.

Therefore:

```text
backup execution failed
```

but:

```text
timer configuration survived
```

---

# Application Isolation During Failure

The following services remained active:

```text
Docker
active

Nginx
active

SSH
active
```

The application health endpoint still returned:

```text
HTTP/1.1 200 OK
```

Body:

```json
{"status":"healthy","version":"0.1.0"}
```

This confirmed that the temporary Dockerfile rename did not break the running application.

---

# Firewall Isolation During Failure

UFW remained:

```text
active
```

with:

```text
Default: deny (incoming)
```

Existing inbound rules remained:

```text
22/tcp
80/tcp
```

No firewall rule was changed as part of the backup failure simulation.

---

# Failure-Domain Isolation

The incident state was therefore:

```text
backup service
FAILED

backup timer
HEALTHY

Docker
HEALTHY

Nginx
HEALTHY

SSH
HEALTHY

application
HEALTHY

UFW
UNCHANGED
```

The fault was isolated to:

```text
backup workflow execution
```

---

# Formal Diagnosis

The diagnostic evidence supported the following root cause:

```text
Required backup source file temporarily unavailable
```

Specifically:

```text
/home/emir/sentinelops-app/Dockerfile
```

was not present at the path expected by the backup script.

---

# Root Cause Chain

The complete causal chain was:

```text
Dockerfile temporarily renamed
        |
        v
backup service started
        |
        v
backup script creates staging directory
        |
        v
script attempts Dockerfile copy
        |
        v
cp cannot stat expected source path
        |
        v
cp exits non-zero
        |
        v
set -e terminates backup script
        |
        v
systemd receives exit status 1
        |
        v
sentinelops-backup.service enters failed state
```

---

# What Did Not Fail

During the same event:

```text
existing backups
remained valid

backup timer
remained enabled and active

application
remained healthy

Docker
remained active

host Nginx
remained active

SSH
remained active

UFW
remained unchanged
```

---

# Monitoring Observation

The existing monitoring script includes:

```text
backup freshness
```

The freshness check evaluates the age of the newest successful backup archive.

At the time of SEN-023, the previous valid archive was only approximately:

```text
9 to 10 hours old
```

The configured freshness threshold is:

```text
36 hours
```

Therefore the previous valid backup remained within policy even though a new manual backup execution had just failed.

---

# Important Monitoring Limitation

This revealed an important distinction.

The current backup freshness check answers:

```text
Do we have a sufficiently recent backup?
```

It does not necessarily answer:

```text
Did the most recent backup job execution fail?
```

Immediately after SEN-023 failed:

```text
systemd
knew the service failed
```

and:

```text
journal
contained the failure
```

but:

```text
backup freshness
could still remain PASS
```

because the previous valid archive was still fresh.

---

# Operational Significance

A freshness check is valuable because it detects:

```text
missing recent backups
```

However, it can have a detection delay.

For example:

```text
backup job fails at 10 hours since last successful backup
```

while threshold is:

```text
36 hours
```

The freshness monitor could remain healthy for many additional hours.

Therefore a mature monitoring design should ideally include both:

```text
backup freshness monitoring
```

and:

```text
backup execution failure monitoring
```

These detect different conditions.

---

# Recovery

The recovery objective was to reverse only the controlled test condition.

The Dockerfile was restored to its expected path:

```text
/home/emir/sentinelops-app/Dockerfile
```

The failed systemd unit state was reset.

The backup service was then manually executed again.

No Docker restart was required.

No application restart was required.

No Nginx restart was required.

No VM reboot was required.

No firewall modification was required.

---

# Failed Unit Reset

The failed unit state was cleared using:

```bash
sudo systemctl reset-failed sentinelops-backup.service
```

After recovery, `systemctl --failed` returned:

```text
0 loaded units listed.
```

---

# Post-Recovery Backup Execution

The backup service was executed again:

```bash
sudo systemctl start sentinelops-backup.service
```

This execution completed successfully.

---

# Recovered Service State

The service status after successful execution showed:

```text
Active: inactive (dead)
```

with:

```text
Process:
code=exited
status=0/SUCCESS
```

This was correct because:

```text
Type=oneshot
```

services normally return to inactive after successful completion.

---

# New Backup Creation

The successful recovery run created:

```text
/home/emir/backups/sentinelops/sentinelops-backup-20260901T100712Z.tar.gz
```

The service journal recorded:

```text
Backup created:
```

followed by:

```text
/home/emir/backups/sentinelops/sentinelops-backup-20260901T100712Z.tar.gz
```

---

# New Manifest Creation

The recovery run created:

```text
sentinelops-backup-20260901T100712Z.tar.gz.manifest
```

The journal recorded:

```text
Backup manifest created:
```

and:

```text
Backup manifest verification complete.
```

---

# New Checksum Creation

The recovery run created:

```text
sentinelops-backup-20260901T100712Z.tar.gz.sha256
```

The journal recorded:

```text
SHA-256 checksum created:
```

---

# New Integrity Verification

The journal then recorded:

```text
Verifying backup integrity:
```

followed by:

```text
sentinelops-backup-20260901T100712Z.tar.gz: OK
```

and:

```text
Backup integrity verification complete.
```

---

# Retention Completion

The successful recovery run also reached:

```text
Removing backup archives older than 7 days:
```

and completed with:

```text
Backup retention complete.
```

This proves the script proceeded beyond backup creation and verification into retention processing.

---

# Newest Backup Verification

The newest three archives after recovery were:

```text
/home/emir/backups/sentinelops/sentinelops-backup-20260901T100712Z.tar.gz

/home/emir/backups/sentinelops/sentinelops-backup-20260901T000013Z.tar.gz

/home/emir/backups/sentinelops/sentinelops-backup-20260831T103229Z.tar.gz
```

The recovered archive became the newest valid backup.

---

# Archive Count After Recovery

After successful recovery:

```text
Archive count after recovery: 12
```

The progression was:

```text
before failure
11

after failed run
11

after successful recovery
12
```

This provides simple but useful evidence.

The failed run did not create an archive.

The successful run did.

---

# New Backup Triplet

The recovered archive triplet was:

```text
sentinelops-backup-20260901T100712Z.tar.gz
sentinelops-backup-20260901T100712Z.tar.gz.sha256
sentinelops-backup-20260901T100712Z.tar.gz.manifest
```

---

# Recovered Artifact Metadata

The archive showed:

```text
-rw-------
owner emir
group emir
size 3139 bytes
```

The manifest showed:

```text
-rw-------
owner emir
group emir
size 167 bytes
```

The checksum showed:

```text
-rw-------
owner emir
group emir
size 109 bytes
```

All three therefore had:

```text
owner
emir:emir

permissions
600
```

---

# SHA-256 Recovery Verification

The new checksum was verified manually:

```bash
sha256sum --check "$(basename "$NEWEST_ARCHIVE").sha256"
```

Result:

```text
sentinelops-backup-20260901T100712Z.tar.gz: OK
```

This independently confirmed that the recovered archive matched its stored SHA-256 checksum.

---

# Manifest Recovery Verification

The new manifest was compared with the archive listing:

```bash
diff -u \
    "$(basename "$NEWEST_ARCHIVE").manifest" \
    <(tar -tzf "$(basename "$NEWEST_ARCHIVE")")
```

Result:

```text
no output
```

This confirmed the manifest matched the archive listing exactly.

---

# Backup Freshness After Recovery

The SentinelOps monitoring script reported:

```text
Newest backup:
sentinelops-backup-20260901T100712Z.tar.gz
```

and:

```text
Backup age:
0 hour(s)
```

with:

```text
Backup freshness:
OK
```

This confirmed that the newest recovered backup had become the archive evaluated by the freshness check.

---

# Infrastructure Recovery Verification

After recovery:

```text
Docker
active

Nginx
active

SSH
active
```

The application remained:

```text
HTTP 200
```

with:

```json
{"status":"healthy","version":"0.1.0"}
```

---

# Listening Ports After Recovery

Monitoring showed:

```text
127.0.0.1:8000
```

still listening.

Host HTTP remained on:

```text
TCP 80
```

SSH remained on:

```text
TCP 22
```

The backup recovery introduced no new network listener.

---

# Firewall After Recovery

UFW remained:

```text
Status: active
```

with:

```text
Default: deny (incoming)
```

Inbound access remained:

```text
22/tcp
80/tcp
```

No external application port was introduced.

---

# Failed Units After Recovery

After the failed state was reset and the backup rerun successfully:

```bash
systemctl --failed
```

returned:

```text
0 loaded units listed.
```

The host therefore returned to a clean systemd state.

---

# Timer Verification After Recovery

The timer remained:

```text
enabled
```

and:

```text
active
```

The failure simulation did not alter the backup schedule.

---

# Journal Failure and Recovery Timeline

The backup journal captured both phases.

## Failure

```text
Sep 01 10:03:41
Starting sentinelops-backup.service
```

```text
Sep 01 10:03:41
cp: cannot stat '/home/emir/sentinelops-app/Dockerfile'
```

```text
Sep 01 10:03:41
Main process exited, code=exited, status=1/FAILURE
```

```text
Sep 01 10:03:41
Failed with result 'exit-code'
```

```text
Sep 01 10:03:41
Failed to start sentinelops-backup.service
```

---

## Recovery

```text
Sep 01 10:07:12
Starting sentinelops-backup.service
```

```text
Sep 01 10:07:12
Backup created
```

```text
Sep 01 10:07:12
Backup manifest created
```

```text
Sep 01 10:07:12
Backup manifest verification complete
```

```text
Sep 01 10:07:12
SHA-256 checksum created
```

```text
Sep 01 10:07:12
Verifying backup integrity
```

```text
Sep 01 10:07:12
sentinelops-backup-20260901T100712Z.tar.gz: OK
```

```text
Sep 01 10:07:13
Backup integrity verification complete
```

```text
Sep 01 10:07:13
Backup retention complete
```

```text
Sep 01 10:07:13
sentinelops-backup.service: Deactivated successfully
```

```text
Sep 01 10:07:13
Finished sentinelops-backup.service
```

---

# Incident Timeline

The SEN-023 timeline can therefore be summarized as:

```text
2026-09-01 09:55 UTC
Healthy backup baseline verified.

2026-09-01 09:55 UTC
Newest archive confirmed as 20260901T000013Z.

2026-09-01 09:55 UTC
Checksum verification successful.

2026-09-01 09:55 UTC
Manifest verification successful.

2026-09-01 09:55 UTC
Backup freshness approximately 9 hours and healthy.

2026-09-01 10:03 UTC
Dockerfile temporarily moved for controlled simulation.

2026-09-01 10:03:41 UTC
Backup service manually started.

2026-09-01 10:03:41 UTC
Dockerfile copy fails.

2026-09-01 10:03:41 UTC
Script exits status 1.

2026-09-01 10:03:41 UTC
systemd marks service failed.

2026-09-01 10:03 UTC
Archive count remains 11.

2026-09-01 10:03 UTC
Backup timer remains enabled and active.

2026-09-01 10:05 UTC
Docker, Nginx, SSH, application, and UFW verified healthy.

2026-09-01 10:07 UTC
Controlled condition removed.

2026-09-01 10:07:12 UTC
Backup service executed again.

2026-09-01 10:07:12 UTC
New archive created.

2026-09-01 10:07:12 UTC
Manifest created and verified.

2026-09-01 10:07:12 UTC
Checksum created and verified.

2026-09-01 10:07:13 UTC
Retention completes.

2026-09-01 10:07:13 UTC
Backup service finishes successfully.

2026-09-01 10:07 UTC
Archive count increases to 12.

2026-09-01 10:07 UTC
New backup freshness becomes 0 hours.

2026-09-01 10:07 UTC
No failed systemd units remain.
```

---

# Comparison with SEN-021

SEN-021 tested failure of:

```text
sentinelops-app
```

The application backend disappeared.

Host Nginx remained running.

The result was:

```text
HTTP 502
```

Monitoring showed:

```text
compose_application
FAIL

application_health
FAIL

host_nginx_health
FAIL
```

---

# Comparison with SEN-022

SEN-022 tested failure of:

```text
host nginx.service
```

The backend remained healthy.

TCP 80 disappeared.

The result was:

```text
connection failure
HTTP 000
```

Monitoring showed:

```text
nginx_service
FAIL

host_nginx_health
FAIL
```

while:

```text
application_health
PASS
```

---

# SEN-023 Failure Pattern

SEN-023 tested:

```text
sentinelops-backup.service
```

The online application path remained healthy.

The backup service entered:

```text
failed
```

systemd recorded:

```text
status=1/FAILURE
```

while:

```text
Docker
PASS

Nginx
PASS

SSH
PASS

application
HTTP 200
```

---

# Three Failure Domains

The three scenarios demonstrate:

```text
SEN-021
application availability failure

SEN-022
reverse-proxy availability failure

SEN-023
backup execution failure
```

This provides broader operational coverage than repeating the same type of outage multiple times.

---

# Safety Analysis

The SEN-023 simulation avoided destructive backup manipulation.

No existing archive was corrupted.

No checksum was intentionally changed.

No manifest was intentionally changed.

No archive was intentionally deleted.

The failure occurred before archive generation.

This significantly reduced the risk of damaging recovery data.

---

# Temporary Source Rename Safety

The temporary rename affected only:

```text
backup source collection
```

It did not modify the file contents.

The original Dockerfile remained on disk under:

```text
Dockerfile.sen-023-test
```

until recovery.

This made the change reversible.

---

# Cleanup Behavior

The backup script defines:

```bash
trap cleanup EXIT
```

with:

```bash
rm -rf "$STAGING_DIR"
```

Therefore the staging directory cleanup runs even when the script exits early.

This is a useful resilience property.

---

# Existing Controls

## Strict Shell Behavior

```bash
set -euo pipefail
```

prevents many silent script errors.

---

## systemd Exit Status

systemd captures the backup process exit code.

A failure is therefore visible as:

```text
status=1/FAILURE
```

---

## systemd Failed Unit State

Failed backup execution is surfaced through:

```bash
systemctl --failed
```

---

## Journal Logging

The journal records:

```text
which command failed
why it failed
when it failed
service exit code
service result
```

---

## Backup Timer

The daily timer remains separately managed and independently inspectable.

---

## Backup Freshness Monitoring

Freshness monitoring detects when valid backups become too old.

---

## SHA-256 Verification

Backups are verified against generated SHA-256 checksums.

---

## Manifest Verification

Archive contents are recorded and verified against generated manifests.

---

## Retention

Archives older than the configured seven-day threshold are removed together with associated checksum and manifest files.

---

# Prevention and Improvement

## Existing Prevention Controls

The current workflow already includes several useful controls:

```text
strict shell error handling
systemd service supervision
systemd journaling
scheduled execution
Persistent=true
backup freshness monitoring
SHA-256 generation
SHA-256 verification
manifest generation
manifest verification
retention
```

---

# Improvement Opportunity: Explicit Job Failure Monitoring

The most significant finding from SEN-023 is that freshness monitoring and execution monitoring are different.

The current health check can report:

```text
Backup freshness: OK
```

while a new backup job has just failed.

This is possible when the previous successful backup remains within the freshness threshold.

---

## Recommended Future Check

A future monitoring enhancement could inspect:

```text
sentinelops-backup.service
```

for recent failed executions.

Possible signals include:

```text
systemctl is-failed sentinelops-backup.service
```

or structured inspection of the unit result.

Such a check could produce:

```text
check=backup_service
status=FAIL
severity=CRITICAL
```

immediately following a failed backup run.

---

# Improvement Opportunity: Completion State

A future design could record an explicit successful completion marker containing:

```text
timestamp
archive filename
checksum status
manifest status
```

This could make it easier to distinguish:

```text
latest artifact exists
```

from:

```text
latest scheduled job completed successfully
```

---

# Improvement Opportunity: Alerting

Future external alerting could surface backup-job failure without requiring an operator to manually inspect:

```bash
systemctl --failed
```

or:

```bash
journalctl
```

---

# Improvement Opportunity: Off-Host Backups

The existing backup storage is local.

A future resilience improvement could replicate verified backups to a separate host or remote storage destination.

This would protect against:

```text
VM loss
disk loss
host-level filesystem corruption
```

This is outside SEN-023.

---

# Improvement Opportunity: Restoration Drills

Backup creation and cryptographic verification do not by themselves prove complete recoverability.

Periodic restoration drills could verify that the archives can reconstruct the intended configuration and application state.

---

# Operational Runbook

If the SentinelOps backup workflow fails in future, the following diagnostic process can be used.

---

## Step 1: Check the Timer

```bash
systemctl status sentinelops-backup.timer --no-pager
systemctl is-enabled sentinelops-backup.timer
systemctl is-active sentinelops-backup.timer
```

---

## Step 2: Check the Backup Service

```bash
systemctl status sentinelops-backup.service --no-pager
```

---

## Step 3: Check Failed Units

```bash
systemctl --failed
```

---

## Step 4: Inspect the Journal

```bash
sudo journalctl -u sentinelops-backup.service --no-pager
```

---

## Step 5: Inspect Backup Sources

Verify required files still exist.

For example:

```bash
ls -l /home/emir/sentinelops-app/index.html
ls -l /home/emir/sentinelops-app/Dockerfile
ls -l /home/emir/sentinelops-app/compose.yaml
ls -l /home/emir/sentinelops-monitoring/health-check.sh
ls -l /etc/nginx/sites-available/sentinelops
```

---

## Step 6: Inspect Existing Backups

```bash
ls -lah /home/emir/backups/sentinelops
```

---

## Step 7: Identify the Newest Archive

```bash
ls -1t /home/emir/backups/sentinelops/sentinelops-backup-*.tar.gz | head -1
```

---

## Step 8: Verify Existing Backup Integrity

```bash
cd /home/emir/backups/sentinelops

sha256sum --check <archive>.sha256
```

---

## Step 9: Verify Manifest

```bash
diff -u \
    <archive>.manifest \
    <(tar -tzf <archive>)
```

---

## Step 10: Correct the Root Cause

Correct only the identified failure condition.

Do not make unrelated changes.

---

## Step 11: Clear Failed State If Appropriate

```bash
sudo systemctl reset-failed sentinelops-backup.service
```

---

## Step 12: Rerun the Backup

```bash
sudo systemctl start sentinelops-backup.service
```

---

## Step 13: Confirm Successful Result

```bash
systemctl status sentinelops-backup.service --no-pager
```

Expected:

```text
inactive (dead)
status=0/SUCCESS
```

---

## Step 14: Verify New Artifacts

Confirm the new:

```text
.tar.gz
.sha256
.manifest
```

triplet exists.

---

## Step 15: Verify New Integrity

```bash
sha256sum --check <new-archive>.sha256
```

---

## Step 16: Verify New Manifest

```bash
diff -u \
    <new-archive>.manifest \
    <(tar -tzf <new-archive>)
```

---

## Step 17: Run Monitoring

```bash
~/sentinelops-monitoring/health-check.sh
```

---

## Step 18: Verify Failed Units

```bash
systemctl --failed
```

---

## Step 19: Verify Timer

```bash
systemctl is-enabled sentinelops-backup.timer
systemctl is-active sentinelops-backup.timer
```

---

## Step 20: Verify Unrelated Infrastructure

```bash
systemctl is-active docker
systemctl is-active nginx
systemctl is-active ssh.socket
curl -i http://127.0.0.1/health
sudo ufw status verbose
```

---

# What Not to Do

A backup service failure does not automatically justify:

```bash
sudo reboot
```

It does not automatically require:

```text
Docker restart
Nginx restart
application rebuild
firewall changes
```

It should not result in deletion of the existing known-good backup set.

It should not result in opening additional network ports.

Diagnosis should identify the failing backup stage first.

---

# Lessons Learned

## Backup Freshness Is Not Backup Execution Status

A recent valid backup can remain fresh even when the newest scheduled or manually invoked backup fails.

Therefore these are different questions:

```text
Do we have a recent valid backup?
```

and:

```text
Did the latest backup job succeed?
```

Both are operationally useful.

---

## Strict Error Handling Is Valuable

The script's:

```bash
set -euo pipefail
```

behavior prevented it from silently skipping the missing Dockerfile.

The job failed visibly instead.

This is preferable to producing an incomplete archive that appears successful.

---

## Existing Backups Must Be Protected During Testing

The test was intentionally designed to fail before archive creation.

This avoided corruption of existing recovery artifacts.

---

## systemd Provides Strong Failure Evidence

The backup failure was visible through:

```text
service status
failed-unit state
exit code
journal
```

This made diagnosis straightforward.

---

## Timer Health Is Separate From Job Health

The backup timer remained:

```text
enabled
active
```

even though:

```text
sentinelops-backup.service
failed
```

Therefore monitoring only the timer would not be sufficient.

---

## Successful Recovery Requires Verification

Starting the service successfully was not treated as enough.

Recovery verification also included:

```text
new archive exists
checksum exists
manifest exists
checksum verifies
manifest matches
freshness healthy
timer active
failed units clear
application healthy
UFW unchanged
```

---

# Acceptance Criteria Verification

- [x] FR-35 through FR-40 mapped to the scenario.
- [x] Healthy backup workflow documented before failure.
- [x] Backup timer enabled before failure.
- [x] Backup timer active before failure.
- [x] Existing valid backup preserved.
- [x] Existing archive/checksum/manifest triplet verified.
- [x] Controlled backup failure introduced safely.
- [x] No production backup archive intentionally corrupted.
- [x] No valid backup artifact intentionally deleted.
- [x] Backup service failure captured.
- [x] systemd service evidence captured.
- [x] Journal failure evidence captured.
- [x] Root cause identified.
- [x] Failed backup stage identified.
- [x] Previous valid backups remained intact.
- [x] Archive count remained 11 during failure.
- [x] New false-success archive was not created.
- [x] Timer remained enabled.
- [x] Timer remained active.
- [x] Docker remained active.
- [x] Nginx remained active.
- [x] SSH remained active.
- [x] Application remained HTTP 200.
- [x] Application version remained `0.1.0`.
- [x] UFW remained unchanged.
- [x] Controlled failure condition reversed.
- [x] Failed systemd state reset.
- [x] Backup service executed successfully after recovery.
- [x] New archive created.
- [x] New checksum created.
- [x] New manifest created.
- [x] New archive ownership verified.
- [x] New checksum ownership verified.
- [x] New manifest ownership verified.
- [x] New archive permissions verified.
- [x] New checksum permissions verified.
- [x] New manifest permissions verified.
- [x] SHA-256 verification succeeded.
- [x] Manifest verification succeeded.
- [x] Backup freshness returned healthy.
- [x] Archive count increased to 12 after recovery.
- [x] Timer remained enabled after recovery.
- [x] Timer remained active after recovery.
- [x] Retention stage completed successfully.
- [x] No unexpected failed systemd units remained.
- [x] Monitoring limitation documented.
- [x] Prevention and improvement controls documented.
- [x] Recovery steps documented.
- [x] No secrets documented.

Git diff verification is completed during repository review before commit.

---

# Final Verified State

At completion of SEN-023:

```text
sentinelops-backup.timer
enabled

sentinelops-backup.timer
active

sentinelops-backup.service
last execution successful

latest backup
sentinelops-backup-20260901T100712Z.tar.gz

archive ownership
emir:emir

archive permissions
600

checksum
present

checksum verification
OK

manifest
present

manifest verification
matched

backup freshness
0 hours

backup freshness state
OK

archive count
12

Docker
active

Nginx
active

SSH
active

application health
HTTP 200

application version
0.1.0

UFW
active

default incoming
deny

TCP 22
allowed

TCP 80
allowed

external TCP 8000
not allowed

failed systemd units
0
```

The environment was therefore restored to its normal healthy and secure state.

---

# Commands Used

## Service and Timer Inspection

```bash
sudo systemctl cat sentinelops-backup.service
sudo systemctl cat sentinelops-backup.timer

systemctl status sentinelops-backup.timer --no-pager
systemctl status sentinelops-backup.service --no-pager

systemctl is-enabled sentinelops-backup.timer
systemctl is-active sentinelops-backup.timer
```

---

## Backup Script Inspection

```bash
sudo sed -n '1,260p' /home/emir/backups/sentinelops/backup-sentinelops.sh

ls -l /home/emir/backups/sentinelops/backup-sentinelops.sh

grep -nE 'set -|set -e|set -u|pipefail|BACKUP_DIR|ARCHIVE|MANIFEST|sha256|tar|find' \
    /home/emir/backups/sentinelops/backup-sentinelops.sh
```

---

## Backup Directory Inspection

```bash
ls -lah /home/emir/backups/sentinelops
```

---

## Newest Archive Selection

```bash
NEWEST_ARCHIVE=$(find /home/emir/backups/sentinelops \
    -maxdepth 1 \
    -type f \
    -name 'sentinelops-backup-*.tar.gz' \
    -printf '%T@ %p\n' \
    | sort -nr \
    | head -1 \
    | cut -d' ' -f2-)

printf 'Newest archive: %s\n' "$NEWEST_ARCHIVE"
```

---

## Pre-Failure Artifact Verification

```bash
ls -l \
    "$NEWEST_ARCHIVE" \
    "$NEWEST_ARCHIVE.sha256" \
    "$NEWEST_ARCHIVE.manifest"
```

```bash
cd /home/emir/backups/sentinelops

sha256sum --check "$(basename "$NEWEST_ARCHIVE").sha256"

diff -u \
    "$(basename "$NEWEST_ARCHIVE").manifest" \
    <(tar -tzf "$(basename "$NEWEST_ARCHIVE")")
```

---

## Baseline Monitoring

```bash
~/sentinelops-monitoring/health-check.sh
```

---

## Baseline Infrastructure Verification

```bash
systemctl is-active docker
systemctl is-active nginx
systemctl is-active ssh.socket

curl -i http://127.0.0.1/health

sudo ufw status verbose

systemctl --failed
```

---

## Pre-Failure Archive Count

```bash
printf 'Archive count before failure: '

find /home/emir/backups/sentinelops \
    -maxdepth 1 \
    -type f \
    -name 'sentinelops-backup-*.tar.gz' \
    | wc -l
```

---

## Pre-Failure Newest Archive

```bash
ls -1t /home/emir/backups/sentinelops/sentinelops-backup-*.tar.gz | head -1
```

---

## Failure Injection

```bash
mv /home/emir/sentinelops-app/Dockerfile \
   /home/emir/sentinelops-app/Dockerfile.sen-023-test
```

---

## Controlled Backup Execution

```bash
sudo systemctl start sentinelops-backup.service
```

---

## Failed-State Verification

```bash
systemctl is-active sentinelops-backup.service
systemctl status sentinelops-backup.service --no-pager
```

```bash
sudo journalctl -u sentinelops-backup.service \
    --since "2026-09-01 09:50:00" \
    --no-pager
```

```bash
systemctl --failed
```

---

## Post-Failure Archive Count

```bash
printf 'Archive count after failed run: '

find /home/emir/backups/sentinelops \
    -maxdepth 1 \
    -type f \
    -name 'sentinelops-backup-*.tar.gz' \
    | wc -l
```

---

## Post-Failure Newest Archive

```bash
ls -1t /home/emir/backups/sentinelops/sentinelops-backup-*.tar.gz | head -1
```

---

## Timer Verification During Failure

```bash
systemctl is-enabled sentinelops-backup.timer
systemctl is-active sentinelops-backup.timer
systemctl status sentinelops-backup.timer --no-pager
```

---

## Infrastructure Verification During Failure

```bash
systemctl is-active docker
systemctl is-active nginx
systemctl is-active ssh.socket

curl -i http://127.0.0.1/health

sudo ufw status verbose
```

---

## Recovery

```bash
mv /home/emir/sentinelops-app/Dockerfile.sen-023-test \
   /home/emir/sentinelops-app/Dockerfile
```

```bash
sudo systemctl reset-failed sentinelops-backup.service
```

```bash
sudo systemctl start sentinelops-backup.service
```

---

## Recovered Service Verification

```bash
systemctl status sentinelops-backup.service --no-pager
```

---

## Recovered Archive Listing

```bash
ls -1t /home/emir/backups/sentinelops/sentinelops-backup-*.tar.gz | head -3
```

---

## Recovered Archive Count

```bash
printf 'Archive count after recovery: '

find /home/emir/backups/sentinelops \
    -maxdepth 1 \
    -type f \
    -name 'sentinelops-backup-*.tar.gz' \
    | wc -l
```

---

## Recovered Newest Archive

```bash
NEWEST_ARCHIVE=$(ls -1t /home/emir/backups/sentinelops/sentinelops-backup-*.tar.gz | head -1)

printf 'Newest archive after recovery: %s\n' "$NEWEST_ARCHIVE"
```

---

## Recovered Triplet Verification

```bash
ls -l \
    "$NEWEST_ARCHIVE" \
    "$NEWEST_ARCHIVE.sha256" \
    "$NEWEST_ARCHIVE.manifest"
```

---

## Recovered Checksum Verification

```bash
cd /home/emir/backups/sentinelops

sha256sum --check "$(basename "$NEWEST_ARCHIVE").sha256"
```

---

## Recovered Manifest Verification

```bash
diff -u \
    "$(basename "$NEWEST_ARCHIVE").manifest" \
    <(tar -tzf "$(basename "$NEWEST_ARCHIVE")")
```

---

## Recovered Monitoring

```bash
~/sentinelops-monitoring/health-check.sh
```

---

## Final Timer and Infrastructure Verification

```bash
systemctl is-enabled sentinelops-backup.timer
systemctl is-active sentinelops-backup.timer

systemctl --failed

systemctl is-active docker
systemctl is-active nginx
systemctl is-active ssh.socket

curl -i http://127.0.0.1/health

sudo ufw status verbose
```

---

## Final Backup Journal

```bash
sudo journalctl -u sentinelops-backup.service \
    --since "2026-09-01 09:50:00" \
    --no-pager
```

---

# Conclusion

SEN-023 successfully demonstrated a controlled failure of the SentinelOps backup workflow.

The simulation intentionally made the required application Dockerfile unavailable to the backup script.

The backup service then failed during staging with:

```text
cp: cannot stat '/home/emir/sentinelops-app/Dockerfile'
```

systemd correctly recorded:

```text
status=1/FAILURE
```

and:

```text
Failed with result 'exit-code'
```

The service appeared in:

```bash
systemctl --failed
```

as a failed unit.

The existing backup set remained intact.

Archive count remained:

```text
11
```

before and after the failed run.

The newest valid archive remained:

```text
sentinelops-backup-20260901T000013Z.tar.gz
```

The timer remained:

```text
enabled
active
```

Unrelated infrastructure remained healthy:

```text
Docker
active

Nginx
active

SSH
active

application
HTTP 200

UFW
unchanged
```

Recovery restored the Dockerfile and reran the backup service.

The service then completed with:

```text
status=0/SUCCESS
```

A new archive was created:

```text
sentinelops-backup-20260901T100712Z.tar.gz
```

with matching:

```text
.sha256
```

and:

```text
.manifest
```

files.

SHA-256 verification returned:

```text
OK
```

Manifest verification returned no differences.

Archive count increased to:

```text
12
```

Backup freshness returned:

```text
0 hour(s)
OK
```

The system returned to:

```text
0 failed systemd units
```

One important operational finding was identified:

```text
backup freshness monitoring
```

does not immediately guarantee detection of:

```text
the latest backup execution failing
```

when a previous valid backup remains sufficiently recent.

Future explicit monitoring of backup-service execution status would therefore complement the existing freshness check.

SEN-023 completes the third required controlled SentinelOps failure scenario and demonstrates detection, diagnosis, recovery, verification, and resilience analysis for the backup subsystem.