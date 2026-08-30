# SentinelOps Backup Freshness Monitoring Baseline

## 1. Overview

SEN-017 extends the SentinelOps monitoring workflow with backup freshness monitoring.

Before this issue, SentinelOps already had:

- manual backup and restoration capability;
- automated backup creation;
- a systemd backup service;
- a systemd backup timer;
- daily backup scheduling;
- persistent timer behaviour;
- seven-day backup retention;
- structured monitoring logs;
- disk threshold monitoring;
- application health monitoring.

However, the monitoring system did not yet determine whether a sufficiently recent backup existed.

The original SentinelOps requirements explicitly require:

```text
FR-22: Backup Freshness Monitoring
```

The monitoring system must be able to determine whether a sufficiently recent backup exists. :contentReference[oaicite:0]{index=0}

SEN-017 closes that gap by:

- defining a backup freshness policy;
- identifying the newest valid SentinelOps backup archive;
- calculating its age;
- classifying the newest backup as fresh or stale;
- detecting when no valid backup archive exists;
- persisting backup freshness results using the structured monitoring format introduced in SEN-016;
- preserving the existing backup, retention, timer, security, and application architecture.

---

## 2. Issue

GitHub issue:

```text
SEN-017: Implement backup freshness monitoring
```

GitHub issue number:

```text
#20
```

Feature branch:

```text
sen-017-backup-freshness
```

---

## 3. Objective

The objective of SEN-017 is to provide operational evidence that a sufficiently recent SentinelOps backup exists.

The monitoring workflow must be able to distinguish:

```text
fresh backup
stale backup
missing backup
```

The implementation must remain read-only with respect to real backup archives.

It must not:

- delete archives;
- rename archives;
- modify timestamps;
- change archive permissions;
- alter retention;
- alter backup scheduling;
- create new backup archives merely for freshness testing.

---

## 4. Requirement Addressed

SEN-017 directly addresses:

```text
FR-22: Backup Freshness Monitoring
```

The requirement states that the monitoring system shall be able to determine whether a sufficiently recent backup exists. :contentReference[oaicite:1]{index=1}

The requirement deliberately does not prescribe an exact number of hours.

Therefore SEN-017 establishes and documents a deliberate freshness policy based on the existing daily backup schedule.

---

## 5. Existing Backup Architecture

Before SEN-017, the backup architecture was:

```text
systemd timer
     |
     v
sentinelops-backup.service
     |
     v
backup-sentinelops.sh
     |
     v
/home/emir/backups/sentinelops/
     |
     +-- timestamped .tar.gz archives
```

The timer runs daily.

The service runs the backup script as root.

The backup script creates the archive, sets ownership and permissions, and removes archives older than the configured retention threshold.

---

## 6. Existing Monitoring Architecture

Before SEN-017, monitoring was performed using:

```text
/home/emir/sentinelops-monitoring/health-check.sh
```

Structured results were written to:

```text
/var/log/sentinelops/health-check.log
```

Each structured result followed:

```text
timestamp=<UTC> check=<check> status=<PASS|FAIL> severity=<INFO|WARNING|CRITICAL> message="<message>"
```

SEN-017 reuses this format.

---

## 7. Initial Backup Inventory

Before implementing freshness monitoring, the backup directory contained:

```text
/home/emir/backups/sentinelops/
```

with:

```text
backup-sentinelops.sh
sentinelops-backup-20260827T155515Z.tar.gz
sentinelops-backup-20260828T185351Z.tar.gz
sentinelops-backup-20260828T185854Z.tar.gz
sentinelops-backup-20260828T190100Z.tar.gz
sentinelops-backup-20260829T053444Z.tar.gz
sentinelops-backup-20260829T151706Z.tar.gz
sentinelops-backup-20260830T021748Z.tar.gz
```

The newest real archive was:

```text
sentinelops-backup-20260830T021748Z.tar.gz
```

---

## 8. Backup Archive Permissions

The existing backup archives remained:

```text
owner: emir
group: emir
mode: 600
```

Example:

```text
-rw------- emir emir sentinelops-backup-20260830T021748Z.tar.gz
```

SEN-017 does not change these permissions.

---

## 9. Backup Script State

The backup script remained:

```text
/home/emir/backups/sentinelops/backup-sentinelops.sh
```

It was not modified by SEN-017.

The existing retention logic remained active.

---

## 10. Retention Policy

The backup script continued to define:

```bash
RETENTION_MINUTES=10080
```

This represents:

```text
7 days
```

The cleanup selector continued to use:

```bash
-mmin +"$RETENTION_MINUTES"
```

SEN-017 does not alter backup retention.

---

## 11. Systemd Backup Service

The existing service remained:

```ini
[Unit]
Description=SentinelOps local backup
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=/home/emir/backups/sentinelops/backup-sentinelops.sh
```

The service remains intentionally `Type=oneshot`.

An inactive state after successful completion is expected.

---

## 12. Systemd Backup Timer

The timer remained:

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

Important properties are:

```text
daily schedule
Persistent=true
enabled
active waiting state
```

---

## 13. Initial Timer Verification

The timer was checked before implementing SEN-017.

It reported:

```text
Loaded: loaded
enabled
Active: active (waiting)
```

The next scheduled run was:

```text
Mon 2026-08-31 00:00:00 UTC
```

The last recorded execution was:

```text
Sun 2026-08-30 02:17:48 UTC
```

---

## 14. Successful Automated Backup Evidence

The service state showed the previous backup completed successfully.

Relevant evidence:

```text
ExecStart=/home/emir/backups/sentinelops/backup-sentinelops.sh
code=exited
status=0/SUCCESS
```

The service journal recorded:

```text
Backup created:
```

followed by:

```text
/home/emir/backups/sentinelops/sentinelops-backup-20260830T021748Z.tar.gz
```

---

## 15. Successful Retention Evidence

The same automated run also recorded:

```text
Removing backup archives older than 7 days:
```

and:

```text
Backup retention complete.
```

The service then completed with:

```text
Deactivated successfully
Finished sentinelops-backup.service
```

This established that the newest archive was the product of a legitimate successful automated backup run.

---

## 16. Freshness Policy Decision

SentinelOps backups are scheduled daily.

The expected interval is therefore approximately:

```text
24 hours
```

SEN-017 establishes a freshness threshold of:

```text
36 hours
```

---

## 17. Freshness Threshold Rationale

A strict 24-hour threshold could create unnecessary failures due to:

- VM shutdown;
- delayed boot;
- systemd scheduling delay;
- timer catch-up behaviour;
- short operational interruption.

Because the timer uses:

```text
Persistent=true
```

a backup may legitimately execute after the machine becomes available again.

A 36-hour threshold therefore provides:

```text
24-hour expected interval
+
12-hour operational grace period
```

while still identifying genuinely missed or stale backups.

---

## 18. Fresh Backup Definition

A backup is classified as fresh when:

```text
age <= 36 hours
```

Structured result:

```text
status=PASS
severity=INFO
```

---

## 19. Stale Backup Definition

A backup is classified as stale when:

```text
age > 36 hours
```

Structured result:

```text
status=FAIL
severity=CRITICAL
```

---

## 20. Missing Backup Definition

If no regular file matching the approved archive pattern exists, the result is:

```text
status=FAIL
severity=CRITICAL
```

This ensures that an empty backup directory is not mistaken for a healthy backup state.

---

## 21. Backup Directory Variable

SEN-017 adds:

```bash
BACKUP_DIR="/home/emir/backups/sentinelops"
```

This centralizes the approved backup location inside the monitoring script.

---

## 22. Freshness Threshold Variable

The monitoring script defines:

```bash
BACKUP_FRESHNESS_THRESHOLD_HOURS=36
```

This makes the policy explicit and easy to identify.

---

## 23. Seconds Conversion

The hour threshold is converted to seconds:

```bash
BACKUP_FRESHNESS_THRESHOLD_SECONDS=$((BACKUP_FRESHNESS_THRESHOLD_HOURS * 3600))
```

This allows direct comparison with Unix epoch timestamps.

---

## 24. Backup Selection Rule

Only files inside:

```text
/home/emir/backups/sentinelops
```

are considered.

Selection is restricted to:

```text
-maxdepth 1
-type f
-name 'sentinelops-backup-*.tar.gz'
```

---

## 25. Why `-maxdepth 1` Is Used

`-maxdepth 1` prevents the monitoring check from searching recursively into unrelated subdirectories.

This keeps selection limited to the known backup storage location.

---

## 26. Why `-type f` Is Used

`-type f` ensures only regular files are considered.

This prevents directories or other filesystem objects with a matching name from being treated as valid backups.

---

## 27. Filename Pattern

The approved pattern is:

```text
sentinelops-backup-*.tar.gz
```

This matches the established backup naming convention.

It excludes:

```text
backup-sentinelops.sh
```

and unrelated files.

---

## 28. Newest Backup Selection

The monitoring workflow finds matching archives using:

```bash
find "$BACKUP_DIR" \
    -maxdepth 1 \
    -type f \
    -name 'sentinelops-backup-*.tar.gz' \
    -printf '%T@ %p\n'
```

The output contains:

```text
modification epoch path
```

---

## 29. Sorting by Modification Time

Results are sorted using:

```bash
sort -nr
```

This places the newest modification timestamp first.

---

## 30. Selecting One Archive

The first result is selected using:

```bash
head -1
```

Only the newest matching backup is evaluated.

---

## 31. Extracting the Path

The path is extracted using:

```bash
cut -d' ' -f2-
```

The resulting variable is stored as:

```bash
NEWEST_BACKUP
```

---

## 32. Missing-Backup Detection

The script checks:

```bash
if [[ -z "$NEWEST_BACKUP" ]]; then
```

An empty value means no matching regular backup archive was found.

---

## 33. Missing-Backup Terminal Result

When no archive exists, the script prints:

```text
CRITICAL: No matching SentinelOps backup archive found
```

---

## 34. Missing-Backup Structured Result

The monitoring log receives:

```text
check=backup_freshness
status=FAIL
severity=CRITICAL
```

with:

```text
No matching SentinelOps backup archive was found
```

---

## 35. Backup Modification Timestamp

When a backup exists, its modification time is retrieved using:

```bash
stat -c %Y "$NEWEST_BACKUP"
```

The result is a Unix epoch timestamp.

---

## 36. Current Epoch Time

The current UTC epoch time is obtained using:

```bash
date -u +%s
```

This is stored as:

```bash
NOW_EPOCH
```

---

## 37. Backup Age Calculation

Age is calculated using:

```bash
BACKUP_AGE_SECONDS=$((NOW_EPOCH - BACKUP_MTIME))
```

The result represents the backup age in seconds.

---

## 38. Future Timestamp Protection

The script includes:

```bash
if (( BACKUP_AGE_SECONDS < 0 )); then
```

This protects against a backup file whose modification timestamp is unexpectedly in the future.

---

## 39. Future Timestamp Classification

A future modification timestamp produces:

```text
status=FAIL
severity=CRITICAL
```

This is treated as an invalid freshness condition rather than silently considering the backup extremely fresh.

---

## 40. Backup Age in Hours

For human-readable output:

```bash
BACKUP_AGE_HOURS=$((BACKUP_AGE_SECONDS / 3600))
```

This uses integer hours.

---

## 41. Backup Basename

The archive filename is extracted using:

```bash
basename "$NEWEST_BACKUP"
```

This prevents the structured monitoring message from unnecessarily repeating the complete path.

---

## 42. Freshness Comparison

The core comparison is:

```bash
if (( BACKUP_AGE_SECONDS <= BACKUP_FRESHNESS_THRESHOLD_SECONDS )); then
```

This means exactly 36 hours remains within the accepted freshness window.

---

## 43. Fresh Terminal Output

A valid fresh backup produces:

```text
Newest backup: <filename>
Backup age: <hours> hour(s)
Backup freshness: OK
```

---

## 44. Fresh Structured Output

A healthy result is logged using:

```text
check=backup_freshness
status=PASS
severity=INFO
```

The message includes:

- filename;
- calculated age;
- configured threshold.

---

## 45. Stale Terminal Output

A stale backup produces:

```text
Backup freshness: CRITICAL
```

---

## 46. Stale Structured Output

A stale result uses:

```text
check=backup_freshness
status=FAIL
severity=CRITICAL
```

The message states that the backup age exceeds the 36-hour threshold.

---

## 47. Monitoring Integration

The backup freshness section was inserted into the existing health-check workflow after disk threshold evaluation.

The monitoring flow now includes:

```text
host resource information
disk threshold
backup freshness
systemd state
service health
Compose application
container resources
application health
host Nginx health
network listeners
UFW
```

---

## 48. Existing Structured Format Preserved

SEN-017 reuses the SEN-016 logging function:

```bash
log_result
```

No second logging format was introduced.

The same fields remain:

```text
timestamp
check
status
severity
message
```

---

## 49. Final Backup Freshness Check Name

The structured check name is:

```text
backup_freshness
```

This provides a stable identifier for future log parsing or alerting.

---

## 50. Monitoring Script Syntax Validation

After the SEN-017 changes, syntax was validated using:

```bash
bash -n ~/sentinelops-monitoring/health-check.sh
```

No output was returned.

This indicates no Bash syntax error was detected.

---

## 51. Configuration Verification

The following values were inspected directly:

```text
BACKUP_DIR="/home/emir/backups/sentinelops"
BACKUP_FRESHNESS_THRESHOLD_HOURS=36
```

The selection and age-calculation variables were also verified in the script.

---

## 52. Real Backup Preservation Before Test

The real backup directory was listed again before the first monitoring run.

All existing archives remained present.

No archive was modified during script editing.

---

## 53. Structured Log State Before SEN-017 Run

Before the first SEN-017-enabled monitoring execution:

```bash
wc -l /var/log/sentinelops/health-check.log
```

returned:

```text
14
```

This represented two previous SEN-016 runs with seven structured results each.

---

## 54. First Real SEN-017 Monitoring Run

The monitoring script was executed using:

```bash
~/sentinelops-monitoring/health-check.sh
```

The run completed successfully.

---

## 55. Current Root Disk Result

The root filesystem remained:

```text
48%
```

The existing disk check therefore returned:

```text
PASS / INFO
```

This confirmed SEN-017 did not break the SEN-016 disk threshold logic.

---

## 56. Newest Backup Selected

The backup freshness section selected:

```text
sentinelops-backup-20260830T021748Z.tar.gz
```

This matched the independently inspected newest archive.

---

## 57. Real Backup Age

During the real monitoring run, the calculated age was:

```text
15 hours
```

---

## 58. Real Backup Freshness Result

Because:

```text
15 <= 36
```

the backup was classified as:

```text
PASS
INFO
```

Terminal result:

```text
Backup freshness: OK
```

---

## 59. Real Structured Freshness Entry

The monitoring log contained:

```text
timestamp=2026-08-30T17:58:51Z check=backup_freshness status=PASS severity=INFO message="Newest backup sentinelops-backup-20260830T021748Z.tar.gz is 15 hour(s) old, within freshness threshold of 36 hours"
```

This proves the live production path works.

---

## 60. Structured Result Verification

The result was isolated using:

```bash
grep 'check=backup_freshness' /var/log/sentinelops/health-check.log | tail -1
```

The expected PASS/INFO result was returned.

---

## 61. Independent Newest Backup Verification

The newest archive was independently checked using:

```bash
find /home/emir/backups/sentinelops \
    -maxdepth 1 \
    -type f \
    -name 'sentinelops-backup-*.tar.gz' \
    -printf '%T@ %p\n' \
    | sort -nr \
    | head -1
```

The result identified:

```text
sentinelops-backup-20260830T021748Z.tar.gz
```

This agreed with the monitoring script.

---

## 62. Structured Log Growth

After the first SEN-017 run:

```bash
wc -l /var/log/sentinelops/health-check.log
```

returned:

```text
22
```

Before the run:

```text
14
```

After the run:

```text
22
```

---

## 63. Why the Log Increased by Eight

SEN-016 produced seven structured entries per healthy run.

SEN-017 adds:

```text
backup_freshness
```

Therefore each healthy run now produces eight structured entries.

The growth:

```text
14 -> 22
```

matches the expected behaviour.

---

## 64. Append Behaviour Preserved

The existing log was not overwritten.

Previous monitoring entries remained present.

SEN-017 therefore preserves the append behaviour established in SEN-016.

---

## 65. Safe Stale-Backup Testing Strategy

The real backup archives were not altered to test a stale condition.

Instead, an isolated temporary directory was created using:

```bash
mktemp -d
```

This prevented SEN-017 testing from modifying valid backup evidence.

---

## 66. Synthetic Stale Backup

A synthetic file was created in the temporary directory:

```text
sentinelops-backup-TEST-STALE.tar.gz
```

The file contained no real backup data.

It existed only to test timestamp comparison logic.

---

## 67. Synthetic Stale Timestamp

The synthetic file was aged using:

```bash
touch -d '40 hours ago'
```

Its modification timestamp was verified with:

```bash
stat
```

---

## 68. Stale Test Isolation

The stale test used:

```text
/tmp/<temporary-directory>
```

rather than:

```text
/home/emir/backups/sentinelops
```

The real backup directory therefore remained untouched.

---

## 69. Stale Selection Logic

The same selection pattern used by the live script was applied to the temporary stale directory.

This included:

```text
-maxdepth 1
-type f
-name sentinelops-backup-*.tar.gz
sort newest first
```

---

## 70. Stale Age Calculation

The synthetic file age was calculated using the same epoch model.

Result:

```text
40 hours
```

---

## 71. Stale Test Result

The safe stale test produced:

```text
STALE TEST -> status=FAIL severity=CRITICAL age=40h
```

Because:

```text
40 > 36
```

the stale branch behaved correctly.

---

## 72. Safe Missing-Backup Testing Strategy

A second isolated empty temporary directory was created.

No files were added.

This allowed missing-backup behaviour to be tested without removing or hiding the real backups.

---

## 73. Missing Selection Result

The normal backup selector was executed against the empty temporary directory.

It returned no matching backup path.

---

## 74. Missing Test Result

The safe missing test produced:

```text
MISSING TEST -> status=FAIL severity=CRITICAL
```

This confirms that an empty approved location results in a critical freshness failure.

---

## 75. Temporary Test Cleanup

After stale and missing tests, only the temporary directories were removed:

```bash
rm -rf "$STALE_TEST_DIR" "$MISSING_TEST_DIR"
```

No path under the real backup directory was removed.

---

## 76. Real Archive Inventory After Testing

The real backup inventory was listed after the temporary tests.

It still contained:

```text
sentinelops-backup-20260827T155515Z.tar.gz
sentinelops-backup-20260828T185351Z.tar.gz
sentinelops-backup-20260828T185854Z.tar.gz
sentinelops-backup-20260828T190100Z.tar.gz
sentinelops-backup-20260829T053444Z.tar.gz
sentinelops-backup-20260829T151706Z.tar.gz
sentinelops-backup-20260830T021748Z.tar.gz
```

No real archive had been removed.

---

## 77. Archive Ownership Preservation

The real archives remained owned by:

```text
emir:emir
```

---

## 78. Archive Permission Preservation

The real archives remained:

```text
600
```

SEN-017 did not modify backup permissions.

---

## 79. Timer Regression Verification

After the freshness implementation, the backup timer was rechecked.

It remained:

```text
enabled
active (waiting)
```

---

## 80. Timer Schedule Preservation

The timer continued to show:

```text
NEXT:
Mon 2026-08-31 00:00:00 UTC
```

The daily schedule therefore remained unchanged.

---

## 81. Timer Persistence Preservation

The timer configuration continued to contain:

```text
Persistent=true
```

No systemd timer edit was made by SEN-017.

---

## 82. Backup Service Regression

The backup service definition remained unchanged:

```ini
[Service]
Type=oneshot
User=root
ExecStart=/home/emir/backups/sentinelops/backup-sentinelops.sh
```

---

## 83. Retention Regression

The backup script continued to contain:

```bash
RETENTION_MINUTES=10080
```

and:

```bash
-mmin +"$RETENTION_MINUTES"
```

Therefore the seven-day retention policy remained intact.

---

## 84. Application Regression

The private backend health endpoint was rechecked:

```bash
curl -i http://127.0.0.1:8000/health
```

Result:

```text
HTTP/1.1 200 OK
```

Body:

```json
{"status":"healthy","version":"0.1.0"}
```

---

## 85. Host Nginx Regression

The health endpoint through host Nginx was rechecked:

```bash
curl -i http://127.0.0.1/health
```

Result:

```text
HTTP/1.1 200 OK
```

Body:

```json
{"status":"healthy","version":"0.1.0"}
```

---

## 86. Application Version Preservation

The application remains:

```text
0.1.0
```

SEN-017 does not modify application versioning.

---

## 87. UFW Regression

UFW remained:

```text
Status: active
```

with:

```text
Default: deny (incoming)
```

Allowed inbound rules remained:

```text
22/tcp
80/tcp
```

---

## 88. No Port 8000 Firewall Rule

No UFW allow rule was added for:

```text
8000/tcp
```

The backend remains intentionally private.

---

## 89. Listener Regression

Listener inspection showed:

```text
127.0.0.1:8000
0.0.0.0:80
0.0.0.0:22
[::]:80
[::]:22
```

No new listener was introduced.

---

## 90. Backend Isolation Preservation

The application backend remains:

```text
127.0.0.1:8000
```

It is not exposed as:

```text
0.0.0.0:8000
```

---

## 91. Monitoring Security Impact

SEN-017 introduces no new network service.

The change consists only of:

```text
read-only filesystem inspection
timestamp arithmetic
structured monitoring output
```

No new daemon is required.

---

## 92. Backup Read-Only Behaviour

The freshness check performs only read operations against real archives.

The commands used for real archive evaluation include:

```text
find
stat
basename
date
sort
head
cut
```

No real backup modification command is used by the production freshness path.

---

## 93. Why Modification Time Is Used

The current backup workflow creates a new archive when a backup completes.

The archive modification time therefore provides a practical local freshness signal for the current SentinelOps MVP.

The check does not rely solely on the filename timestamp.

---

## 94. Filename Timestamp vs Filesystem Timestamp

The filename includes:

```text
YYYYMMDDTHHMMSSZ
```

but SEN-017 calculates age from:

```text
filesystem modification timestamp
```

This avoids requiring custom parsing of the archive filename.

---

## 95. Backup Validity Limitation

Freshness does not prove backup integrity.

A backup could be:

```text
recent
```

but still be:

```text
corrupted
incomplete
invalid
```

SEN-017 addresses only freshness.

---

## 96. Relationship to Backup Integrity

The original requirements separately define:

```text
FR-28: Backup Integrity
```

and:

```text
NFR-19: Backup Integrity
```

Integrity must therefore be implemented separately from freshness. :contentReference[oaicite:2]{index=2}

SEN-017 intentionally does not claim that a fresh archive is valid solely because it exists.

---

## 97. Relationship to Backup Manifest

The original requirements separately define:

```text
FR-27: Backup Manifest
```

SEN-017 does not add archive manifests. :contentReference[oaicite:3]{index=3}

---

## 98. Structured Log Security

Backup freshness entries contain only:

- archive filename;
- calculated age;
- threshold;
- status;
- severity.

They do not record:

- archive contents;
- credentials;
- SSH keys;
- secrets;
- environment variables.

---

## 99. Final Monitoring Check Set

After SEN-017, one normal monitoring run records:

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

This is eight structured checks.

---

## 100. Final Monitoring Architecture

After SEN-017:

```text
                    health-check.sh
                          |
          +---------------+---------------+
          |               |               |
          v               v               v
       disk           backups         services
          |               |               |
          |               v               |
          |       newest archive           |
          |               |               |
          |          calculate age         |
          |               |               |
          |        compare to 36h          |
          |               |               |
          +---------------+---------------+
                          |
                          v
                  structured result
                          |
                          v
        /var/log/sentinelops/health-check.log
```

---

## 101. Backup Freshness Flow

The freshness workflow is:

```text
/home/emir/backups/sentinelops
             |
             v
find matching regular archives
             |
             v
sort newest first
             |
             v
select newest
             |
      +------+------+
      |             |
      | none        | exists
      v             v
FAIL/CRITICAL   read mtime
                    |
                    v
              calculate age
                    |
             +------+------+
             |             |
          <=36h          >36h
             |             |
             v             v
        PASS/INFO     FAIL/CRITICAL
```

---

## 102. Final Freshness Contract

Current policy:

```text
Fresh:
    <= 36 hours
    PASS
    INFO

Stale:
    > 36 hours
    FAIL
    CRITICAL

Missing:
    no matching archive
    FAIL
    CRITICAL

Future timestamp:
    negative calculated age
    FAIL
    CRITICAL
```

---

## 103. Final Security State

After SEN-017:

```text
SSH:
    public-key authentication retained
    password authentication disabled
    direct root SSH login disabled

UFW:
    active
    default incoming deny
    22/tcp allowed
    80/tcp allowed
    no 8000/tcp allow rule

Application:
    backend 127.0.0.1:8000
    host Nginx entry point
    /health HTTP 200
    version 0.1.0

Backup:
    systemd timer enabled
    timer active waiting
    daily schedule
    Persistent=true
    seven-day retention
    archive permissions 600

Monitoring:
    structured logging retained
    backup freshness added
    no new network listener
```

---

## 104. Acceptance Criteria Verification

### Freshness threshold documented

Verified:

```text
36 hours
```

### Newest valid archive identified

Verified.

### Approved backup directory

Verified:

```text
/home/emir/backups/sentinelops
```

### Regular-file restriction

Verified:

```text
-type f
```

### Filename restriction

Verified:

```text
sentinelops-backup-*.tar.gz
```

### Real backup selected correctly

Verified:

```text
sentinelops-backup-20260830T021748Z.tar.gz
```

### Real age calculation

Verified:

```text
15 hours
```

### Fresh classification

Verified:

```text
PASS / INFO
```

### Stale classification

Verified safely:

```text
40h -> FAIL / CRITICAL
```

### Missing classification

Verified safely:

```text
FAIL / CRITICAL
```

### Structured check name

Verified:

```text
backup_freshness
```

### Structured timestamp

Verified.

### Structured status

Verified.

### Structured severity

Verified.

### Structured useful message

Verified.

### Log append behaviour

Verified:

```text
14 -> 22 lines
```

### Disk monitoring preserved

Verified.

### Docker monitoring preserved

Verified.

### Nginx monitoring preserved

Verified.

### SSH monitoring preserved

Verified.

### Compose monitoring preserved

Verified.

### Application health preserved

Verified:

```text
HTTP 200
```

### Host Nginx health preserved

Verified:

```text
HTTP 200
```

### Application version preserved

Verified:

```text
0.1.0
```

### Backup timer enabled

Verified.

### Backup timer active

Verified.

### Daily schedule preserved

Verified.

### Persistent timer preserved

Verified.

### Backup service unchanged

Verified.

### Seven-day retention preserved

Verified.

### Real backup archives untouched

Verified.

### UFW active

Verified.

### Default incoming deny

Verified.

### TCP 22 allowed

Verified.

### TCP 80 allowed

Verified.

### TCP 8000 not externally allowed

Verified.

### Backend remains loopback-only

Verified.

### No new listener

Verified.

### Bash syntax validation

Verified.

---

## 105. Limitations

SEN-017 checks only freshness.

It does not prove that the newest archive:

- can be extracted;
- has the expected files;
- has not been corrupted;
- matches a checksum;
- contains a manifest;
- can successfully restore the application.

These remain separate requirements.

---

## 106. Freshness Precision Limitation

Human-readable output uses integer hours.

For example:

```text
15 hour(s)
```

The actual pass/fail comparison uses seconds.

Therefore threshold accuracy is not limited by the displayed integer hour value.

---

## 107. Local Backup Limitation

Freshness monitoring checks only:

```text
/home/emir/backups/sentinelops
```

It does not check an off-host backup location.

Off-host backup replication is outside the current MVP implementation scope.

---

## 108. Alerting Limitation

A stale or missing backup currently produces:

```text
FAIL / CRITICAL
```

in the structured monitoring log and terminal output.

It does not automatically send:

- email;
- Slack;
- SMS;
- push notifications.

External alerting is separate future work.

---

## 109. Scheduling Limitation

The general health-check script is still executed manually during the current baseline.

SEN-017 does not introduce a new monitoring timer.

The backup timer itself remains automated.

---

## 110. Integrity Limitation

A recent zero-byte file with the correct naming pattern could theoretically pass the freshness selector if placed in the approved directory.

SEN-017 intentionally does not perform integrity validation.

That gap is expected to be addressed by later backup manifest and checksum work.

---

## 111. Why Freshness and Integrity Are Separate

Freshness asks:

```text
Was a sufficiently recent backup created?
```

Integrity asks:

```text
Is that backup valid and unchanged?
```

These are distinct operational controls.

Combining them prematurely would make the issue less focused.

---

## 112. Future Operational Value

The freshness result provides a stable signal for future:

- automated monitoring schedules;
- external alerts;
- incident simulations;
- dashboarding;
- CI validation;
- backup reliability analysis.

---

## 113. Files Changed on the Ubuntu VM

SEN-017 modified:

```text
/home/emir/sentinelops-monitoring/health-check.sh
```

No backup script was modified.

No systemd service was modified.

No systemd timer was modified.

No application file was modified.

No Nginx file was modified.

No UFW configuration was modified.

No SSH configuration was modified.

---

## 114. Temporary Test Files

Synthetic stale and missing-backup testing used temporary directories under:

```text
/tmp
```

The temporary test data was removed after verification.

No test archive was placed into the production backup directory.

---

## 115. Repository Documentation

The repository records SEN-017 in:

```text
docs/phase-2/backup-freshness-monitoring-baseline.md
```

The live implementation remains deployed on the Ubuntu VM.

---

## 116. Out of Scope

SEN-017 does not implement:

- backup manifests;
- backup checksums;
- archive integrity verification;
- corruption detection;
- automatic restoration;
- additional restoration testing;
- retention changes;
- new backup scheduling;
- off-host backup replication;
- backup encryption;
- monitoring scheduling;
- log rotation;
- external alerting;
- Prometheus;
- Grafana;
- controlled failure simulations;
- incident runbooks;
- GitHub Actions;
- ShellCheck CI;
- provisioning automation;
- idempotent provisioning;
- Ansible;
- Terraform;
- cloud deployment;
- HTTPS;
- public DNS.

These remain separate future SentinelOps issues.

---

## 117. Commands Used During SEN-017

Requirement inspection:

```bash
sed -n '108,120p' docs/phase-0/requirements.md
```

Backup inventory:

```bash
ls -lh /home/emir/backups/sentinelops/
```

Archive timestamp inspection:

```bash
find /home/emir/backups/sentinelops \
    -maxdepth 1 \
    -type f \
    -name 'sentinelops-backup-*.tar.gz' \
    -printf '%TY-%Tm-%Td %TH:%TM:%TS %f\n' \
    | sort
```

Timer inspection:

```bash
systemctl status sentinelops-backup.timer --no-pager
systemctl list-timers sentinelops-backup.timer --no-pager
```

UTC time:

```bash
date -u
```

Backup service inspection:

```bash
systemctl status sentinelops-backup.service --no-pager
```

Backup journal:

```bash
journalctl -u sentinelops-backup.service --since "2026-08-30 00:00:00" --no-pager
```

Monitoring inspection:

```bash
grep -nE 'LOG_FILE|DISK_|APPLICATION HEALTH|HOST NGINX HEALTH|log_result' \
    ~/sentinelops-monitoring/health-check.sh
```

Full monitoring script inspection:

```bash
sed -n '1,230p' ~/sentinelops-monitoring/health-check.sh
```

Monitoring script editing:

```bash
nano ~/sentinelops-monitoring/health-check.sh
```

Syntax validation:

```bash
bash -n ~/sentinelops-monitoring/health-check.sh
```

SEN-017 variable inspection:

```bash
grep -nE 'BACKUP_DIR|BACKUP_FRESHNESS|NEWEST_BACKUP|BACKUP_MTIME|BACKUP_AGE' \
    ~/sentinelops-monitoring/health-check.sh
```

Structured log count:

```bash
wc -l /var/log/sentinelops/health-check.log
```

Monitoring execution:

```bash
~/sentinelops-monitoring/health-check.sh
```

Structured monitoring inspection:

```bash
tail -n 10 /var/log/sentinelops/health-check.log
```

Freshness entry inspection:

```bash
grep 'check=backup_freshness' \
    /var/log/sentinelops/health-check.log | tail -1
```

Newest backup verification:

```bash
find /home/emir/backups/sentinelops \
    -maxdepth 1 \
    -type f \
    -name 'sentinelops-backup-*.tar.gz' \
    -printf '%T@ %p\n' \
    | sort -nr \
    | head -1
```

Temporary stale directory:

```bash
STALE_TEST_DIR="$(mktemp -d)"
```

Synthetic stale backup:

```bash
touch "$STALE_TEST_DIR/sentinelops-backup-TEST-STALE.tar.gz"
touch -d '40 hours ago' "$STALE_TEST_DIR/sentinelops-backup-TEST-STALE.tar.gz"
```

Synthetic timestamp inspection:

```bash
stat "$STALE_TEST_DIR/sentinelops-backup-TEST-STALE.tar.gz"
```

Temporary missing directory:

```bash
MISSING_TEST_DIR="$(mktemp -d)"
```

Temporary test cleanup:

```bash
rm -rf "$STALE_TEST_DIR" "$MISSING_TEST_DIR"
```

Service definition verification:

```bash
cat /etc/systemd/system/sentinelops-backup.service
```

Timer definition verification:

```bash
cat /etc/systemd/system/sentinelops-backup.timer
```

Retention verification:

```bash
grep -nE 'RETENTION_MINUTES|find|mmin' \
    /home/emir/backups/sentinelops/backup-sentinelops.sh
```

Application health verification:

```bash
curl -i http://127.0.0.1:8000/health
curl -i http://127.0.0.1/health
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

## 118. SEN-017 Completion State

Before SEN-017:

```text
backup creation -> implemented
backup scheduling -> implemented
backup retention -> implemented
backup restoration -> implemented
structured monitoring -> implemented
backup freshness -> not monitored
```

After SEN-017:

```text
backup creation -> implemented
backup scheduling -> implemented
backup retention -> implemented
backup restoration -> implemented
structured monitoring -> implemented
backup freshness -> implemented
```

The monitoring workflow can now determine whether:

```text
a recent backup exists
a backup is stale
no matching backup exists
```

The current real backup was:

```text
15 hours old
```

and correctly classified as:

```text
PASS / INFO
```

A synthetic:

```text
40-hour-old
```

backup correctly produced:

```text
FAIL / CRITICAL
```

An empty synthetic backup location correctly produced:

```text
FAIL / CRITICAL
```

The production backup archives were not modified during testing.

The daily timer remains enabled and active.

The seven-day retention policy remains unchanged.

The application remains healthy at:

```text
0.1.0
```

The application backend remains private at:

```text
127.0.0.1:8000
```

UFW remains active with default deny incoming.

No new network service or firewall rule was introduced.

SEN-017 is ready for repository validation, commit, pull request, review, merge, and issue closure.