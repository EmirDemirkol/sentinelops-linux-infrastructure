# SentinelOps Backup Integrity Baseline

## 1. Overview

SEN-018 adds cryptographic integrity verification to the SentinelOps backup workflow.

Before this issue, SentinelOps already provided:

- timestamped local backup archives;
- automated backup execution through systemd;
- persistent daily backup scheduling;
- seven-day backup retention;
- documented restoration;
- structured monitoring;
- application health monitoring;
- backup freshness monitoring.

However, the backup workflow did not generate cryptographic integrity checksums for backup archives.

This meant that SentinelOps could determine whether a backup existed and whether it was sufficiently recent, but it could not independently detect whether a backup archive had been modified or corrupted after creation.

SEN-018 closes this gap by adding SHA-256 checksum generation and verification to the existing backup workflow.

---

## 2. Issue

GitHub issue:

```text
SEN-018: Implement backup integrity verification
```

GitHub issue number:

```text
#22
```

Feature branch:

```text
sen-018-backup-integrity
```

---

## 3. Objective

The objective of SEN-018 is to provide cryptographic evidence that a backup archive remains unchanged after creation.

The backup workflow must be able to distinguish:

```text
valid unchanged archive
modified or corrupted archive
missing checksum record
```

The implementation must preserve the existing:

- backup process;
- systemd scheduling;
- seven-day retention;
- backup freshness monitoring;
- application architecture;
- Docker architecture;
- Nginx architecture;
- SSH configuration;
- UFW policy;
- backend isolation.

---

## 4. Requirement Addressed

SEN-018 directly addresses:

```text
FR-28: Backup Integrity
```

The SentinelOps requirements specify that the system shall generate an integrity checksum for backup archives.

SEN-018 implements that requirement using:

```text
SHA-256
```

---

## 5. Related Requirement

The requirements separately define:

```text
FR-27: Backup Manifest
```

Backup manifests describe what a backup contains.

SEN-018 does not implement FR-27.

Checksum integrity and backup manifests remain separate controls.

---

## 6. Freshness vs Integrity

SEN-017 answers:

```text
Is there a sufficiently recent backup?
```

SEN-018 answers:

```text
Has the backup archive changed since its checksum was generated?
```

These are different operational questions.

A backup can be:

```text
fresh but corrupted
```

or:

```text
old but cryptographically unchanged
```

Freshness does not imply integrity.

Integrity does not imply freshness.

---

## 7. Integrity vs Restoration

A checksum match does not prove that the archive can successfully restore the system.

SEN-018 proves only that:

```text
the current archive bytes match the bytes that existed when the checksum was generated
```

Restoration testing remains a separate operational control.

---

## 8. Initial Backup Architecture

Before SEN-018:

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
sentinelops-backup-<timestamp>.tar.gz
```

No checksum record was generated.

---

## 9. Final Backup Architecture

After SEN-018:

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
create archive
     |
     v
set archive ownership and permissions
     |
     v
generate SHA-256 checksum
     |
     v
set checksum ownership and permissions
     |
     v
verify archive against checksum
     |
     +-------------------------------+
     |                               |
     v                               v
archive                         checksum
.tar.gz                         .sha256
```

---

## 10. Integrity Verification Architecture

Verification now follows:

```text
archive
  +
checksum
   |
   v
sha256sum --check
   |
   +----------------+
   |                |
   v                v
match            mismatch
   |                |
   v                v
  OK             FAILED
```

---

## 11. Initial Archive Inventory

Before SEN-018, the backup directory contained:

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

---

## 12. Initial Checksum State

Before implementation, the following inspection was performed:

```bash
find /home/emir/backups/sentinelops \
    -maxdepth 1 \
    -type f \
    -name '*.sha256' \
    -print
```

No output was returned.

Therefore:

```text
existing checksum files = 0
```

This confirmed that SEN-018 started from a genuine no-integrity-checksum baseline.

---

## 13. Existing Archive Ownership

Existing backup archives were owned by:

```text
emir:emir
```

---

## 14. Existing Archive Permissions

Existing archives used:

```text
600
```

Example:

```text
-rw------- emir emir sentinelops-backup-20260830T021748Z.tar.gz
```

SEN-018 preserves this security property.

---

## 15. Existing Backup Script

The backup script remained located at:

```text
/home/emir/backups/sentinelops/backup-sentinelops.sh
```

Before SEN-018 it:

- created a temporary staging directory;
- copied application files;
- copied monitoring files;
- copied Nginx configuration;
- created a compressed archive;
- set archive ownership;
- set archive mode;
- reported archive size;
- removed archives older than seven days.

---

## 16. Existing Safety Configuration

The script already used:

```bash
set -euo pipefail
```

This was preserved.

---

## 17. Meaning of `set -euo pipefail`

The existing Bash safety configuration provides stricter failure behaviour.

Conceptually:

```text
-e
exit when an unhandled command fails

-u
treat unset variables as errors

pipefail
propagate pipeline failures
```

This is important for backup integrity because checksum generation must not silently fail while the script continues as if the backup were complete.

---

## 18. Existing Temporary Staging Cleanup

The script already used:

```bash
trap cleanup EXIT
```

and:

```bash
cleanup() {
    rm -rf "$STAGING_DIR"
}
```

This behaviour was preserved.

---

## 19. Initial systemd Timer State

Before SEN-018, the backup timer reported:

```text
enabled
active (waiting)
```

The timer remained scheduled daily.

---

## 20. Existing Persistent Timer Behaviour

The timer configuration remained:

```ini
[Timer]
OnCalendar=daily
Persistent=true
Unit=sentinelops-backup.service
```

SEN-018 does not modify systemd scheduling.

---

## 21. Initial Backup Service State

The existing backup service remained:

```ini
[Service]
Type=oneshot
User=root
ExecStart=/home/emir/backups/sentinelops/backup-sentinelops.sh
```

The previous automated run had completed successfully with:

```text
status=0/SUCCESS
```

---

## 22. Existing Retention Policy

The script continued to define:

```bash
RETENTION_MINUTES=10080
```

This represents:

```text
7 days
```

---

## 23. SHA-256 Availability

Before implementation, SHA-256 tooling was verified using:

```bash
command -v sha256sum
```

Result:

```text
/usr/bin/sha256sum
```

---

## 24. SHA-256 Version

The installed implementation was:

```text
sha256sum (GNU coreutils) 9.4
```

No additional package installation was required.

---

## 25. Checksum Algorithm Decision

SEN-018 uses:

```text
SHA-256
```

Reasons include:

- widely supported Linux tooling;
- strong collision resistance for this operational use;
- deterministic output;
- easy automation;
- no additional dependency;
- straightforward verification using `sha256sum --check`.

---

## 26. Why MD5 Was Not Used

MD5 is not appropriate as the integrity baseline because stronger cryptographic hash functions are readily available.

SHA-256 provides a more defensible integrity mechanism without adding operational complexity.

---

## 27. Why SHA-1 Was Not Used

SHA-1 is also no longer considered an appropriate modern integrity baseline when SHA-256 is readily available.

SEN-018 therefore standardizes on SHA-256.

---

## 28. Checksum Filename Policy

Each new archive receives a corresponding checksum file.

Pattern:

```text
sentinelops-backup-<timestamp>.tar.gz
sentinelops-backup-<timestamp>.tar.gz.sha256
```

---

## 29. Checksum Variable

SEN-018 adds:

```bash
CHECKSUM_FILE="${ARCHIVE}.sha256"
```

This ensures the checksum filename is directly derived from the archive path.

---

## 30. Unambiguous Archive Association

Because the checksum path is:

```text
<archive>.sha256
```

the relationship between archive and checksum is explicit.

Example:

```text
sentinelops-backup-20260830T185122Z.tar.gz
sentinelops-backup-20260830T185122Z.tar.gz.sha256
```

---

## 31. Archive Creation Remains First

The archive is created using:

```bash
tar -czf "$ARCHIVE" -C "$STAGING_DIR" .
```

Checksum generation occurs only after this command.

---

## 32. Why Checksum Generation Occurs After Archive Creation

A checksum cannot represent the final archive until archive creation has completed.

Therefore the correct order is:

```text
create archive
-> generate checksum
```

not:

```text
generate checksum
-> continue modifying archive
```

---

## 33. Archive Ownership

After creation:

```bash
chown emir:emir "$ARCHIVE"
```

remains configured.

---

## 34. Archive Permissions

After creation:

```bash
chmod 600 "$ARCHIVE"
```

remains configured.

---

## 35. Checksum Generation

SEN-018 generates the checksum using:

```bash
sha256sum "$(basename "$ARCHIVE")" > "$(basename "$CHECKSUM_FILE")"
```

---

## 36. Backup Directory Context

Checksum generation is performed inside:

```bash
(
    cd "$BACKUP_DIR"
    ...
)
```

This produces a checksum record containing the archive basename rather than an unnecessary absolute path.

---

## 37. Checksum Record Format

The generated checksum record contained:

```text
38b46f8a6d2816ff1f0e494af9da7a175be9806a5fd3b894807aa2c292f9250d  sentinelops-backup-20260830T185122Z.tar.gz
```

The first field is the SHA-256 digest.

The second field identifies the archive.

---

## 38. Checksum Ownership

After generation:

```bash
chown emir:emir "$CHECKSUM_FILE"
```

is applied.

---

## 39. Checksum Permissions

The checksum file uses:

```bash
chmod 600 "$CHECKSUM_FILE"
```

This matches the archive security model.

---

## 40. Why Checksum Files Use Mode 600

The checksum itself is not equivalent to secret data.

However, keeping backup metadata aligned with archive permissions:

- reduces unnecessary exposure;
- preserves a simple security model;
- ensures only the backup owner and privileged administrators can access the files.

---

## 41. Automatic Integrity Verification

The backup script does not merely generate a checksum.

It also immediately verifies it using:

```bash
sha256sum --check "$(basename "$CHECKSUM_FILE")"
```

---

## 42. Why Immediate Verification Is Useful

Immediate verification confirms that:

- the checksum file was created correctly;
- the checksum refers to the intended archive;
- the archive can be read;
- the generated pair is internally consistent before the backup run completes.

---

## 43. Failure Behaviour

Because the script uses:

```bash
set -euo pipefail
```

a failed integrity verification causes the backup script to exit with failure rather than continuing as though the backup completed normally.

---

## 44. Backup Completion Contract

The updated workflow now effectively means:

```text
archive creation success
+
checksum generation success
+
checksum verification success
=
successful backup workflow
```

---

## 45. New Backup Execution

A controlled backup was triggered through systemd after the script change.

The new archive was:

```text
sentinelops-backup-20260830T185122Z.tar.gz
```

---

## 46. New Checksum File

The corresponding checksum file was:

```text
sentinelops-backup-20260830T185122Z.tar.gz.sha256
```

---

## 47. New Backup Service Result

The systemd service completed with:

```text
code=exited
status=0/SUCCESS
```

---

## 48. Service Journal Integrity Evidence

The backup service recorded:

```text
SHA-256 checksum created:
```

followed by:

```text
/home/emir/backups/sentinelops/sentinelops-backup-20260830T185122Z.tar.gz.sha256
```

---

## 49. Service Verification Evidence

The service then recorded:

```text
Verifying backup integrity:
```

followed by:

```text
sentinelops-backup-20260830T185122Z.tar.gz: OK
```

---

## 50. Integrity Completion Evidence

The service output included:

```text
Backup integrity verification complete.
```

---

## 51. Service Completion

The systemd unit then completed with:

```text
Deactivated successfully
Finished sentinelops-backup.service
```

This is the expected state for a successful `Type=oneshot` service.

---

## 52. Real Archive Size

The new archive size was:

```text
3141 bytes
```

during the direct `stat` verification.

---

## 53. Real Checksum Size

The corresponding checksum file size was:

```text
109 bytes
```

---

## 54. Real Archive Ownership Verification

The new archive reported:

```text
owner=emir:emir
```

---

## 55. Real Archive Permission Verification

The new archive reported:

```text
mode=600
```

---

## 56. Real Checksum Ownership Verification

The checksum reported:

```text
owner=emir:emir
```

---

## 57. Real Checksum Permission Verification

The checksum reported:

```text
mode=600
```

---

## 58. Independent Integrity Verification

After the systemd backup completed, verification was run independently:

```bash
sha256sum --check "$(basename "${NEWEST_ARCHIVE}.sha256")"
```

Result:

```text
sentinelops-backup-20260830T185122Z.tar.gz: OK
```

---

## 59. Meaning of `OK`

The result:

```text
OK
```

means the SHA-256 digest calculated from the current archive matched the digest stored in the checksum record.

---

## 60. Safe Corruption Test Strategy

SEN-018 required proof that changed data is detected.

The real archive was not modified.

Instead, an isolated temporary directory was created using:

```bash
mktemp -d
```

---

## 61. Temporary Integrity Test Directory

The temporary directory existed under:

```text
/tmp
```

This isolated destructive test activity from production backup files.

---

## 62. Archive Copy

The real archive was copied into the temporary directory.

---

## 63. Checksum Copy

The real checksum file was also copied into the temporary directory.

---

## 64. Pre-Corruption Verification

Before modifying the temporary archive, the copied pair was checked.

Result:

```text
sentinelops-backup-20260830T185122Z.tar.gz: OK
```

This established that the copied test pair started in a valid state.

---

## 65. Synthetic Corruption

Only the temporary copy was modified using:

```bash
printf 'SEN-018 synthetic corruption test\n' >> "$(basename "$NEWEST_ARCHIVE")"
```

---

## 66. Why Appending Data Is Sufficient

Changing even a small portion of the archive changes its SHA-256 digest.

Appending a controlled test string therefore creates a deterministic integrity mismatch.

---

## 67. Corruption Detection Result

After synthetic modification:

```bash
sha256sum --check ...
```

returned:

```text
sentinelops-backup-20260830T185122Z.tar.gz: FAILED
```

---

## 68. Checksum Warning

The command also returned:

```text
sha256sum: WARNING: 1 computed checksum did NOT match
```

This proves SEN-018 detects altered archive data.

---

## 69. Real Archive Safety

The corruption occurred only inside the temporary directory.

The real production archive was never modified.

---

## 70. Missing Checksum Test

The temporary checksum copy was then removed.

The test checked whether the expected checksum file still existed.

---

## 71. Missing Checksum Result

The missing-checksum test produced:

```text
MISSING CHECKSUM TEST -> status=FAIL checksum file missing
```

This demonstrates the required failure condition when an archive has no corresponding checksum record.

---

## 72. Temporary Test Cleanup

After mismatch and missing-checksum testing:

```bash
rm -rf "$INTEGRITY_TEST_DIR"
```

removed the isolated test directory.

---

## 73. Production Pair Verification After Testing

The real archive/checksum pair was then verified again.

Result:

```text
sentinelops-backup-20260830T185122Z.tar.gz: OK
```

---

## 74. Production Archive Preservation

After testing, the real archive remained:

```text
owner=emir:emir
mode=600
size=3141
```

---

## 75. Production Checksum Preservation

After testing, the real checksum remained:

```text
owner=emir:emir
mode=600
size=109
```

---

## 76. Retention Problem Introduced by Checksums

Before SEN-018, retention needed to remove only:

```text
.tar.gz
```

archives.

After SEN-018, deleting only the archive would leave:

```text
orphaned .sha256 files
```

Therefore retention required paired cleanup.

---

## 77. Updated Retention Model

The retention process now becomes:

```text
find expired archive
       |
       v
derive matching checksum path
       |
       +-- checksum exists -> remove checksum
       |
       v
remove archive
```

---

## 78. Retention Iteration

The updated script uses:

```bash
while IFS= read -r OLD_ARCHIVE; do
```

for expired archive processing.

---

## 79. Matching Checksum Calculation

For each old archive:

```bash
OLD_CHECKSUM="${OLD_ARCHIVE}.sha256"
```

determines the associated checksum path.

---

## 80. Optional Checksum Removal

The script checks:

```bash
if [[ -f "$OLD_CHECKSUM" ]]; then
```

before attempting checksum removal.

---

## 81. Why the Existence Check Matters

Older archives created before SEN-018 do not have checksum files.

The existence check allows retention to continue handling those historical archives safely.

---

## 82. Archive Removal

After checksum handling:

```bash
rm -f "$OLD_ARCHIVE"
```

removes the expired archive.

---

## 83. Retention Threshold Preserved

The archive selector still uses:

```bash
-mmin +"$RETENTION_MINUTES"
```

with:

```bash
RETENTION_MINUTES=10080
```

The retention period remains seven days.

---

## 84. Safe Retention Test Strategy

Retention pairing was tested without aging or deleting a real backup.

A temporary directory was created.

---

## 85. Synthetic Retention Archive

A synthetic archive was created:

```text
sentinelops-backup-RETENTION-OLD.tar.gz
```

---

## 86. Synthetic Retention Checksum

A matching checksum file was created:

```text
sentinelops-backup-RETENTION-OLD.tar.gz.sha256
```

---

## 87. Synthetic Pair Initial State

Before retention testing, the directory contained both files.

---

## 88. Synthetic Pair Age

Both synthetic files were aged using:

```bash
touch -d '8 days ago'
```

This made the archive older than the seven-day retention threshold.

---

## 89. Isolated Retention Threshold

The test used:

```bash
TEST_RETENTION_MINUTES=10080
```

matching the production value.

---

## 90. Retention Test Result

The test printed:

```text
Removing archive: /tmp/.../sentinelops-backup-RETENTION-OLD.tar.gz
Removing checksum: /tmp/.../sentinelops-backup-RETENTION-OLD.tar.gz.sha256
```

---

## 91. Empty Directory Verification

After retention processing:

```bash
ls -la "$RETENTION_TEST_DIR"
```

showed only:

```text
.
..
```

Both the archive and checksum had been removed.

---

## 92. Retention Test Cleanup

The temporary directory was then removed.

No real archive was aged or deleted.

---

## 93. Retention Compatibility With Historical Backups

Archives created before SEN-018 do not currently have matching checksum files.

The updated retention logic handles them because checksum deletion is conditional.

Therefore:

```text
old pre-SEN-018 archive
-> no checksum exists
-> archive can still be removed normally
```

---

## 94. SEN-017 Freshness Regression

After creating the first checksummed backup, the existing monitoring workflow was run.

It selected:

```text
sentinelops-backup-20260830T185122Z.tar.gz
```

---

## 95. Freshness Age

The newest archive was:

```text
0 hour(s)
```

old during the regression test.

---

## 96. Freshness Result

The result remained:

```text
PASS / INFO
```

---

## 97. Structured Freshness Entry

The monitoring log contained:

```text
timestamp=2026-08-30T18:52:26Z check=backup_freshness status=PASS severity=INFO message="Newest backup sentinelops-backup-20260830T185122Z.tar.gz is 0 hour(s) old, within freshness threshold of 36 hours"
```

---

## 98. Why Freshness Monitoring Was Not Broken

The SEN-017 selector searches only:

```text
sentinelops-backup-*.tar.gz
```

The new checksum files end with:

```text
.tar.gz.sha256
```

Therefore they are not incorrectly selected as backup archives.

---

## 99. Monitoring Regression

The existing health-check continued to report:

```text
Docker: active
Nginx: active
SSH: active
```

---

## 100. Compose Regression

The Compose application remained running.

The backend mapping remained:

```text
127.0.0.1:8000->80/tcp
```

---

## 101. Application Health Regression

The application health endpoint continued to return:

```text
HTTP 200
```

---

## 102. Host Nginx Regression

Host Nginx continued to return:

```text
HTTP 200
```

---

## 103. Backup Timer Regression

After SEN-018, the timer remained:

```text
enabled
active (waiting)
```

---

## 104. Next Timer Run

The timer continued to target the next daily scheduled execution.

No scheduling change was introduced.

---

## 105. Persistent Timer Regression

The systemd timer configuration remains:

```text
Persistent=true
```

---

## 106. Backup Service Regression

The service still uses:

```text
Type=oneshot
User=root
ExecStart=/home/emir/backups/sentinelops/backup-sentinelops.sh
```

---

## 107. Backup Script Syntax Validation

After modification:

```bash
bash -n /home/emir/backups/sentinelops/backup-sentinelops.sh
```

returned no output.

No Bash syntax error was detected.

---

## 108. UFW Regression

UFW remained:

```text
Status: active
```

---

## 109. Default Firewall Policy

The firewall continued to report:

```text
Default: deny (incoming)
```

---

## 110. Allowed TCP Ports

The allowed inbound services remained:

```text
22/tcp
80/tcp
```

---

## 111. Port 8000 Firewall State

No UFW rule was added for:

```text
8000/tcp
```

---

## 112. Listener Regression

The listener check showed:

```text
127.0.0.1:8000
0.0.0.0:80
0.0.0.0:22
[::]:80
[::]:22
```

---

## 113. Backend Isolation

The application backend remains:

```text
127.0.0.1:8000
```

It is not listening on:

```text
0.0.0.0:8000
```

---

## 114. Network Impact

SEN-018 introduces:

```text
no new port
no new daemon
no new listener
no new firewall rule
```

The feature operates entirely through local filesystem integrity checks.

---

## 115. Security Boundary

SHA-256 integrity verification is a local host control.

It does not change the system's network trust boundary.

---

## 116. Checksum Security Limitation

The archive and checksum currently exist on the same host and filesystem.

If an attacker gains sufficient access to modify both:

```text
archive
and
checksum
```

they could potentially replace both consistently.

Therefore this control primarily detects:

- accidental corruption;
- unintended archive modification;
- incomplete or unexpected changes where the checksum is not also regenerated.

---

## 117. Off-Host Integrity Limitation

SEN-018 does not store checksum records off-host.

A stronger future design could preserve checksum metadata separately from the backup host.

That is outside the current MVP scope.

---

## 118. Cryptographic Signature Limitation

SHA-256 provides hashing, not authentication.

The checksum file is not cryptographically signed.

Therefore SEN-018 does not prove who created the checksum.

---

## 119. Archive Completeness Limitation

A valid checksum does not prove that all intended files were included in the archive.

That gap relates to:

```text
FR-27: Backup Manifest
```

---

## 120. Restoration Limitation

A valid checksum does not prove that restoration succeeds.

Archive integrity and restoration validity remain separate controls.

---

## 121. Existing Historical Backup Limitation

Backups created before SEN-018 currently do not have checksum files.

SEN-018 guarantees checksum generation for new backups created after the implementation.

Historical archives were not retroactively assigned checksums.

---

## 122. Why Historical Checksums Were Not Backfilled

Generating checksums for old archives now would prove only their current state.

It would not prove whether those archives had already changed between their original creation and the later checksum generation.

Therefore SEN-018 does not falsely claim historical integrity assurance.

---

## 123. Checksum Verification Scope

The checksum verifies the compressed archive bytes.

It does not individually checksum every file inside the archive.

---

## 124. Why Archive-Level Hashing Is Appropriate

The requirement is specifically for an integrity checksum for backup archives.

Hashing the completed `.tar.gz` provides direct validation of the recovery artifact itself.

---

## 125. Final Backup Pair

The first production backup created under SEN-018 is:

```text
sentinelops-backup-20260830T185122Z.tar.gz
```

with:

```text
sentinelops-backup-20260830T185122Z.tar.gz.sha256
```

---

## 126. Final Verified Checksum

The checksum stored for the archive was:

```text
38b46f8a6d2816ff1f0e494af9da7a175be9806a5fd3b894807aa2c292f9250d
```

---

## 127. Final Production Verification

The production archive verifies as:

```text
sentinelops-backup-20260830T185122Z.tar.gz: OK
```

---

## 128. Final Integrity Contract

The implemented behaviour is:

```text
archive created
    |
    v
checksum generated
    |
    v
checksum verified
    |
    +-- match -> backup workflow succeeds
    |
    +-- mismatch -> backup workflow fails
```

---

## 129. Missing Checksum Contract

Operationally:

```text
archive exists
checksum absent
```

must be treated as:

```text
integrity verification unavailable
FAIL
```

---

## 130. Corruption Contract

Operationally:

```text
computed SHA-256 != recorded SHA-256
```

means:

```text
integrity verification failed
```

---

## 131. Paired Retention Contract

When a checksummed archive exceeds retention:

```text
archive
+
matching checksum
```

must both be removed.

---

## 132. Final Backup Workflow

The complete backup sequence is now:

```text
create temporary staging directory
        |
        v
copy application files
        |
        v
copy monitoring configuration
        |
        v
copy Nginx configuration
        |
        v
create .tar.gz archive
        |
        v
chown emir:emir
        |
        v
chmod 600
        |
        v
generate SHA-256 checksum
        |
        v
checksum chown emir:emir
        |
        v
checksum chmod 600
        |
        v
verify checksum
        |
        v
apply paired seven-day retention
        |
        v
cleanup staging directory
```

---

## 133. Final Relationship Between Backup Controls

After SEN-018:

```text
backup creation
      |
      +-- scheduling
      |
      +-- persistence
      |
      +-- retention
      |
      +-- restoration documentation
      |
      +-- freshness
      |
      +-- integrity
```

---

## 134. Current Implemented Backup Controls

The SentinelOps backup subsystem now provides:

```text
manual backup capability
automated backup execution
daily systemd scheduling
Persistent=true
seven-day retention
documented restoration
backup freshness monitoring
SHA-256 archive integrity verification
paired archive/checksum retention
```

---

## 135. Controls Still Remaining

Separate future work includes:

```text
backup manifest
off-host backup
encryption at rest
automated restoration verification
external alerting
```

---

## 136. Files Changed on Ubuntu

SEN-018 modified:

```text
/home/emir/backups/sentinelops/backup-sentinelops.sh
```

---

## 137. Files Not Changed

SEN-018 did not modify:

```text
/etc/systemd/system/sentinelops-backup.service
/etc/systemd/system/sentinelops-backup.timer
/home/emir/sentinelops-monitoring/health-check.sh
/home/emir/sentinelops-app/*
Nginx configuration
SSH configuration
UFW configuration
```

---

## 138. Runtime Artifacts Created

SEN-018 created:

```text
/home/emir/backups/sentinelops/sentinelops-backup-20260830T185122Z.tar.gz
/home/emir/backups/sentinelops/sentinelops-backup-20260830T185122Z.tar.gz.sha256
```

---

## 139. Temporary Test Artifacts

Temporary testing used directories under:

```text
/tmp
```

These included:

- copied archive;
- copied checksum;
- corrupted synthetic archive;
- synthetic retention archive;
- synthetic retention checksum.

All temporary test directories were removed after validation.

---

## 140. Production Safety During Testing

No real production backup was:

- corrupted;
- appended to;
- renamed;
- deleted;
- deliberately aged;
- permission-modified.

---

## 141. Acceptance Criteria Verification

### SHA-256 documented

Verified.

### New archives generate checksum file

Verified.

### Checksum generated after archive creation

Verified.

### Unambiguous checksum/archive relationship

Verified.

### Valid archive passes verification

Verified:

```text
OK
```

### Standard Linux tooling used

Verified:

```text
sha256sum
sha256sum --check
```

### Synthetic changed archive fails

Verified:

```text
FAILED
```

### Computed mismatch warning generated

Verified.

### Missing checksum condition detected

Verified.

### Real archive untouched during corruption testing

Verified.

### Existing archive remains readable

Verified.

### Archive ownership remains `emir:emir`

Verified.

### Archive mode remains `600`

Verified.

### Checksum ownership documented

Verified:

```text
emir:emir
```

### Checksum mode documented

Verified:

```text
600
```

### Seven-day retention preserved

Verified:

```text
RETENTION_MINUTES=10080
```

### Checksum retention defined

Verified.

### Paired retention tested

Verified.

### Backup timer enabled

Verified.

### Backup timer active

Verified.

### `Persistent=true` preserved

Verified.

### Backup service configuration preserved

Verified.

### Backup freshness remains operational

Verified:

```text
PASS / INFO
```

### Application health remains operational

Verified.

### Host Nginx remains operational

Verified.

### UFW remains active

Verified.

### Default incoming deny preserved

Verified.

### TCP 22 remains allowed

Verified.

### TCP 80 remains allowed

Verified.

### TCP 8000 remains not externally allowed

Verified.

### Backend remains loopback-only

Verified:

```text
127.0.0.1:8000
```

### No new listener introduced

Verified.

### Backup script syntax validation passes

Verified.

---

## 142. Failures Encountered

No production failure occurred during SEN-018.

The intentionally generated integrity failure occurred only against a copied test archive.

Expected output:

```text
FAILED
```

and:

```text
1 computed checksum did NOT match
```

This was expected evidence rather than an implementation defect.

---

## 143. Security Preservation

SEN-018 preserves the established security architecture:

```text
SSH public-key administration
password SSH disabled
direct root SSH disabled
UFW active
default deny incoming
22/tcp allowed
80/tcp allowed
no external 8000/tcp
backend loopback-only
Docker Compose application
host Nginx reverse proxy
```

---

## 144. Operational Benefit

Before SEN-018:

```text
backup file exists
```

was the strongest integrity evidence available.

After SEN-018:

```text
archive exists
+
cryptographic checksum exists
+
checksum verifies
```

provides a materially stronger operational assurance.

---

## 145. Incident Diagnosis Benefit

If a future backup fails verification, an operator can distinguish:

```text
backup is recent
```

from:

```text
backup is intact
```

This improves incident diagnosis.

---

## 146. Monitoring Integration Limitation

SEN-018 currently verifies integrity during the backup workflow.

The structured health-check script does not yet independently log a recurring:

```text
backup_integrity
```

monitoring result.

If desired, that can be implemented as a separate future monitoring enhancement.

---

## 147. Why Integrity Was Added to the Backup Script

Generating and immediately validating the checksum directly after archive creation ensures the integrity record is created as part of the same controlled backup workflow.

This prevents integrity generation from depending on a separate manual process.

---

## 148. Why `sha256sum --check` Is Used

`sha256sum --check` reads the stored digest and archive filename, recomputes the digest from the current archive, and compares them.

This provides a simple deterministic integrity verification mechanism.

---

## 149. Why Checksum Files Are Separate

A separate checksum file allows:

- independent verification;
- normal Linux tooling;
- easy retention pairing;
- human inspection;
- future monitoring integration.

---

## 150. Final Security State

After SEN-018:

```text
SSH:
    key authentication retained
    password authentication disabled
    root SSH disabled

UFW:
    active
    incoming default deny
    22/tcp allowed
    80/tcp allowed
    no 8000/tcp allow rule

Application:
    Docker Compose
    backend 127.0.0.1:8000
    host Nginx reverse proxy
    /health operational
    version 0.1.0

Backups:
    systemd automation
    daily schedule
    Persistent=true
    seven-day retention
    backup freshness monitoring
    SHA-256 checksum generation
    immediate checksum verification
    archive mode 600
    checksum mode 600
    paired archive/checksum retention
```

---

## 151. Out of Scope

SEN-018 does not implement:

- backup manifests;
- file-by-file archive inventories;
- cryptographic signatures;
- HMAC verification;
- off-host checksum storage;
- backup encryption;
- off-host backups;
- automatic restoration;
- new restoration tests;
- new backup schedule;
- retention-period changes;
- structured recurring integrity monitoring;
- external alerts;
- email alerts;
- Slack alerts;
- Prometheus;
- Grafana;
- log rotation;
- controlled infrastructure failure simulations;
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

---

## 152. Commands Used During SEN-018

Initial backup script inspection:

```bash
sed -n '1,220p' /home/emir/backups/sentinelops/backup-sentinelops.sh
```

Backup inventory:

```bash
ls -lh /home/emir/backups/sentinelops/
```

SHA-256 availability:

```bash
command -v sha256sum
```

SHA-256 version:

```bash
sha256sum --version | head -1
```

Timer inspection:

```bash
systemctl status sentinelops-backup.timer --no-pager
```

Backup service inspection:

```bash
systemctl status sentinelops-backup.service --no-pager
```

Initial checksum search:

```bash
find /home/emir/backups/sentinelops \
    -maxdepth 1 \
    -type f \
    -name '*.sha256' \
    -print
```

Backup script editing:

```bash
nano /home/emir/backups/sentinelops/backup-sentinelops.sh
```

Syntax validation:

```bash
bash -n /home/emir/backups/sentinelops/backup-sentinelops.sh
```

Integrity implementation inspection:

```bash
grep -nE 'CHECKSUM_FILE|sha256sum|OLD_ARCHIVE|OLD_CHECKSUM|RETENTION_MINUTES' \
    /home/emir/backups/sentinelops/backup-sentinelops.sh
```

Controlled systemd backup:

```bash
sudo systemctl start sentinelops-backup.service
```

Backup service validation:

```bash
systemctl status sentinelops-backup.service --no-pager
```

Newest archive selection:

```bash
NEWEST_ARCHIVE="$(
    find /home/emir/backups/sentinelops \
        -maxdepth 1 \
        -type f \
        -name 'sentinelops-backup-*.tar.gz' \
        -printf '%T@ %p\n' \
        | sort -nr \
        | head -1 \
        | cut -d' ' -f2-
)"
```

Archive/checksum permissions:

```bash
stat -c '%n | owner=%U:%G | mode=%a | size=%s' \
    "$NEWEST_ARCHIVE" \
    "${NEWEST_ARCHIVE}.sha256"
```

Checksum inspection:

```bash
cat "${NEWEST_ARCHIVE}.sha256"
```

Checksum verification:

```bash
cd /home/emir/backups/sentinelops
sha256sum --check "$(basename "${NEWEST_ARCHIVE}.sha256")"
```

Freshness regression:

```bash
~/sentinelops-monitoring/health-check.sh
```

Structured freshness inspection:

```bash
grep 'check=backup_freshness' \
    /var/log/sentinelops/health-check.log | tail -1
```

Temporary integrity directory:

```bash
INTEGRITY_TEST_DIR="$(mktemp -d)"
```

Copy production archive for safe test:

```bash
cp "$NEWEST_ARCHIVE" "$INTEGRITY_TEST_DIR/"
```

Copy checksum:

```bash
cp "${NEWEST_ARCHIVE}.sha256" "$INTEGRITY_TEST_DIR/"
```

Synthetic corruption:

```bash
printf 'SEN-018 synthetic corruption test\n' >> "$(basename "$NEWEST_ARCHIVE")"
```

Missing checksum simulation:

```bash
rm "$(basename "${NEWEST_ARCHIVE}.sha256")"
```

Temporary integrity cleanup:

```bash
rm -rf "$INTEGRITY_TEST_DIR"
```

Temporary retention directory:

```bash
RETENTION_TEST_DIR="$(mktemp -d)"
```

Synthetic retention archive:

```bash
printf 'SEN-018 retention test archive\n' \
    > "$RETENTION_TEST_DIR/sentinelops-backup-RETENTION-OLD.tar.gz"
```

Synthetic checksum generation:

```bash
(
    cd "$RETENTION_TEST_DIR"
    sha256sum sentinelops-backup-RETENTION-OLD.tar.gz \
        > sentinelops-backup-RETENTION-OLD.tar.gz.sha256
)
```

Synthetic ageing:

```bash
touch -d '8 days ago' \
    "$RETENTION_TEST_DIR/sentinelops-backup-RETENTION-OLD.tar.gz" \
    "$RETENTION_TEST_DIR/sentinelops-backup-RETENTION-OLD.tar.gz.sha256"
```

Retention test inspection:

```bash
ls -lh "$RETENTION_TEST_DIR"
```

Retention cleanup verification:

```bash
ls -la "$RETENTION_TEST_DIR"
```

Temporary retention cleanup:

```bash
rm -rf "$RETENTION_TEST_DIR"
```

Firewall regression:

```bash
sudo ufw status verbose
```

Listener regression:

```bash
ss -tulpn | grep -E ':22|:80|:8000'
```

Git branch inspection:

```bash
git branch --show-current
git status
```

---

## 153. SEN-018 Completion State

Before SEN-018:

```text
backup creation -> implemented
backup scheduling -> implemented
backup persistence -> implemented
backup retention -> implemented
backup restoration documentation -> implemented
backup freshness -> implemented
backup integrity checksum -> not implemented
```

After SEN-018:

```text
backup creation -> implemented
backup scheduling -> implemented
backup persistence -> implemented
backup retention -> implemented
backup restoration documentation -> implemented
backup freshness -> implemented
backup integrity checksum -> implemented
```

The first new production archive under the integrity-enabled workflow is:

```text
sentinelops-backup-20260830T185122Z.tar.gz
```

with:

```text
sentinelops-backup-20260830T185122Z.tar.gz.sha256
```

The production pair verifies as:

```text
OK
```

A safely copied and deliberately modified archive verifies as:

```text
FAILED
```

A missing checksum condition was detected.

Paired retention successfully removed both an expired synthetic archive and its matching checksum.

The real production backup remained intact throughout testing.

The backup timer remains enabled and active.

The seven-day retention policy remains unchanged.

Backup freshness monitoring remains operational.

The application remains healthy.

The backend remains private at:

```text
127.0.0.1:8000
```

UFW remains active with default deny incoming.

No new network service, firewall rule, or externally exposed port was introduced.

SEN-018 is ready for repository validation, commit, pull request, review, merge, and issue closure.