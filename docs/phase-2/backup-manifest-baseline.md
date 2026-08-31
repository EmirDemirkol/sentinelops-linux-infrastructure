# SentinelOps Backup Manifest Baseline

## 1. Overview

SEN-019 adds automatic backup manifest generation to the SentinelOps backup workflow.

Before this issue, SentinelOps already provided:

- timestamped local backup archives;
- automated backup execution through systemd;
- persistent daily scheduling;
- seven-day retention;
- documented restoration;
- structured monitoring;
- backup freshness monitoring;
- SHA-256 archive integrity verification;
- paired archive and checksum retention.

However, the backup workflow did not yet produce a documented record of what each backup archive actually contained.

SEN-019 closes that gap by generating a human-readable manifest from every newly created archive.

The manifest is derived directly from the completed `.tar.gz` artifact rather than only from the temporary staging directory.

This means SentinelOps can now answer three distinct backup questions:

```text
Freshness:
Is the backup sufficiently recent?

Integrity:
Has the archive changed since checksum generation?

Manifest:
What files are actually stored inside the archive?
```

---

## 2. Issue

GitHub issue:

```text
SEN-019: Implement backup manifest generation
```

GitHub issue number:

```text
#24
```

Feature branch:

```text
sen-019-backup-manifest
```

---

## 3. Requirement Addressed

SEN-019 directly addresses:

```text
FR-27: Backup Manifest
```

The project requirement states that each backup shall have a documented record of the files or data it contains.

SEN-019 implements that requirement by generating a manifest from the completed archive using `tar -tzf`.

---

## 4. Objective

The objective of SEN-019 is to ensure that every new SentinelOps backup includes an independently inspectable inventory of the files stored inside the backup archive.

The implementation must:

- generate one manifest per new backup;
- derive the manifest from the completed archive;
- associate the manifest deterministically with its archive;
- make the manifest human-readable;
- preserve SHA-256 integrity verification;
- preserve backup freshness monitoring;
- preserve seven-day retention;
- remove expired manifests with their associated backup set;
- preserve existing security and network controls.

---

## 5. Existing Backup Architecture

Before SEN-019, a new integrity-enabled backup produced:

```text
sentinelops-backup-<timestamp>.tar.gz
sentinelops-backup-<timestamp>.tar.gz.sha256
```

The archive contained the actual backup data.

The `.sha256` file provided cryptographic integrity verification.

---

## 6. Final Backup Artifact Set

After SEN-019, every new backup produces:

```text
sentinelops-backup-<timestamp>.tar.gz
sentinelops-backup-<timestamp>.tar.gz.sha256
sentinelops-backup-<timestamp>.tar.gz.manifest
```

All three files share the same archive basename.

This creates one logical backup set.

---

## 7. Final Backup Architecture

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
create staging directory
     |
     v
copy application / monitoring / Nginx files
     |
     v
create .tar.gz archive
     |
     +--> generate manifest from completed archive
     |
     +--> verify manifest against archive
     |
     +--> generate SHA-256 checksum
     |
     +--> verify SHA-256 checksum
     |
     v
apply paired retention
```

---

## 8. Initial State

Before SEN-019:

- Ubuntu Server 24.04.4 LTS was operational;
- SSH public-key administration was working;
- SSH password authentication was disabled;
- direct root SSH login was disabled;
- UFW was active;
- default incoming traffic was denied;
- TCP port `22` was allowed;
- TCP port `80` was allowed;
- TCP port `8000` was not externally allowed;
- host Nginx was active;
- Docker was active;
- the Compose application was running;
- the backend remained bound to `127.0.0.1:8000`;
- `/health` monitoring was operational;
- backup freshness monitoring was operational;
- automated backups were operational;
- SHA-256 backup integrity verification was operational;
- archive/checksum paired retention was operational;
- no `.manifest` files existed.

---

## 9. Initial Manifest Check

Before implementation:

```bash
find /home/emir/backups/sentinelops \
    -maxdepth 1 \
    -type f \
    -name '*.manifest' \
    -print
```

returned no output.

Therefore:

```text
existing manifest files = 0
```

---

## 10. Existing Integrity-Enabled Backup

The newest backup before SEN-019 was:

```text
sentinelops-backup-20260831T001724Z.tar.gz
```

with checksum:

```text
sentinelops-backup-20260831T001724Z.tar.gz.sha256
```

---

## 11. Automated SEN-018 Regression Evidence

The backup created automatically on 31 August 2026 completed successfully.

The systemd service reported:

```text
status=0/SUCCESS
```

The service output included:

```text
SHA-256 checksum created
Verifying backup integrity
sentinelops-backup-20260831T001724Z.tar.gz: OK
Backup integrity verification complete
Backup retention complete
```

This demonstrated that SEN-018 continued operating automatically through the daily systemd timer.

---

## 12. Initial Archive Inspection

The newest pre-SEN-019 archive was inspected using:

```bash
tar -tzf "$NEWEST_ARCHIVE"
```

Its contents were:

```text
./
./nginx/
./nginx/sentinelops
./monitoring/
./monitoring/health-check.sh
./application/
./application/compose.yaml
./application/Dockerfile
./application/index.html
```

This real archive inventory was used to define and verify SEN-019.

---

## 13. Manifest Design Decision

The manifest is generated from the completed archive using:

```bash
tar -tzf "$ARCHIVE"
```

rather than from the staging directory.

This ensures the manifest records what is actually inside the backup artifact.

---

## 14. Why Archive-Derived Generation Matters

A staging-directory inventory would describe what the script attempted to include.

An archive-derived manifest describes what was actually written into the `.tar.gz`.

Therefore the final archive is the authoritative source.

---

## 15. Manifest Naming Convention

SEN-019 adds:

```bash
MANIFEST_FILE="${ARCHIVE}.manifest"
```

Example:

```text
sentinelops-backup-20260831T103229Z.tar.gz
sentinelops-backup-20260831T103229Z.tar.gz.sha256
sentinelops-backup-20260831T103229Z.tar.gz.manifest
```

---

## 16. Deterministic Association

The manifest filename is derived directly from the archive filename.

This provides an unambiguous relationship:

```text
archive
-> archive.manifest
```

---

## 17. Manifest Generation

After archive creation:

```bash
tar -tzf "$ARCHIVE" > "$MANIFEST_FILE"
```

generates the manifest.

---

## 18. Human-Readable Format

The manifest is plain text.

Each archive entry appears on its own line.

Example:

```text
./application/compose.yaml
./application/Dockerfile
./application/index.html
```

No specialized parser is required to inspect it.

---

## 19. Manifest Ownership

SEN-019 applies:

```bash
chown emir:emir "$MANIFEST_FILE"
```

---

## 20. Manifest Permissions

SEN-019 applies:

```bash
chmod 600 "$MANIFEST_FILE"
```

The manifest therefore follows the same permission model as the archive and checksum.

---

## 21. Why Mode 600 Is Used

Mode `600` means:

```text
owner: read + write
group: no access
others: no access
```

This keeps backup metadata restricted to the backup owner and privileged administration.

---

## 22. Manifest Verification

The backup script immediately verifies the generated manifest using:

```bash
diff -u "$MANIFEST_FILE" <(tar -tzf "$ARCHIVE")
```

---

## 23. Manifest Verification Contract

If the stored manifest and a fresh archive listing match:

```text
diff exit code = 0
```

and the backup workflow continues.

If they differ:

```text
diff exit code != 0
```

and because the script uses:

```bash
set -euo pipefail
```

the workflow fails rather than silently accepting inconsistent metadata.

---

## 24. Backup Script Safety

The existing script continues to use:

```bash
set -euo pipefail
```

This remains important because:

- manifest generation failure must stop the workflow;
- manifest verification failure must stop the workflow;
- checksum generation failure must stop the workflow;
- checksum verification failure must stop the workflow.

---

## 25. Manifest Position in Workflow

The implemented sequence is:

```text
archive creation
-> archive ownership / permissions
-> manifest generation
-> manifest ownership / permissions
-> manifest verification
-> SHA-256 checksum generation
-> checksum verification
-> retention
```

---

## 26. First Manifest-Enabled Backup

A controlled systemd backup produced:

```text
sentinelops-backup-20260831T103229Z.tar.gz
```

---

## 27. First Manifest File

The corresponding manifest was:

```text
sentinelops-backup-20260831T103229Z.tar.gz.manifest
```

---

## 28. Corresponding Checksum

The same backup set also contained:

```text
sentinelops-backup-20260831T103229Z.tar.gz.sha256
```

---

## 29. Backup Service Result

The backup service completed with:

```text
code=exited
status=0/SUCCESS
```

---

## 30. Manifest Verification Service Evidence

The service output included:

```text
Backup manifest verification complete.
```

This confirms the manifest comparison passed during the backup workflow.

---

## 31. SHA-256 Regression Evidence

The service also reported:

```text
sentinelops-backup-20260831T103229Z.tar.gz: OK
```

Therefore SEN-018 integrity verification remained operational after adding manifest generation.

---

## 32. Artifact Ownership Verification

The archive, checksum, and manifest were inspected using:

```bash
stat -c '%n | owner=%U:%G | mode=%a | size=%s'
```

All three reported:

```text
owner=emir:emir
mode=600
```

---

## 33. Archive Size

The first SEN-019 archive was:

```text
3140 bytes
```

---

## 34. Checksum Size

The checksum file was:

```text
109 bytes
```

---

## 35. Manifest Size

The manifest file was:

```text
167 bytes
```

---

## 36. Real Manifest Contents

The generated manifest contained:

```text
./
./nginx/
./nginx/sentinelops
./monitoring/
./monitoring/health-check.sh
./application/
./application/compose.yaml
./application/Dockerfile
./application/index.html
```

---

## 37. Expected Application Files

The manifest confirms inclusion of:

```text
./application/compose.yaml
./application/Dockerfile
./application/index.html
```

---

## 38. Expected Monitoring File

The manifest confirms inclusion of:

```text
./monitoring/health-check.sh
```

---

## 39. Expected Nginx Configuration

The manifest confirms inclusion of:

```text
./nginx/sentinelops
```

---

## 40. Direct Archive Verification

The archive was independently inspected:

```bash
tar -tzf "$NEWEST_ARCHIVE"
```

It returned the same entries as the manifest.

---

## 41. Exact Manifest Comparison

The following was executed:

```bash
diff -u \
    "${NEWEST_ARCHIVE}.manifest" \
    <(tar -tzf "$NEWEST_ARCHIVE")
```

No output was returned.

---

## 42. Meaning of No Diff Output

No `diff` output means:

```text
manifest contents == current archive listing
```

The generated manifest therefore accurately represented the backup.

---

## 43. SHA-256 Independent Verification

The archive was independently verified using:

```bash
sha256sum --check "$(basename "${NEWEST_ARCHIVE}.sha256")"
```

Result:

```text
sentinelops-backup-20260831T103229Z.tar.gz: OK
```

---

## 44. Manifest and Integrity Relationship

Manifest verification proves:

```text
the inventory matches the archive listing
```

Checksum verification proves:

```text
the archive bytes match the recorded SHA-256 digest
```

These are separate controls.

---

## 45. Freshness Relationship

Backup freshness proves:

```text
the newest backup is recent enough
```

It does not prove archive content or cryptographic integrity.

---

## 46. Three-Part Backup Assurance

SentinelOps now provides:

```text
Freshness
-> Is it recent?

Integrity
-> Has it changed?

Manifest
-> What does it contain?
```

---

## 47. Retention Change Required by Manifests

Before SEN-019, paired retention removed:

```text
archive
checksum
```

After SEN-019, retention must remove:

```text
archive
checksum
manifest
```

---

## 48. Updated Retention Variables

The retention loop now derives:

```bash
OLD_CHECKSUM="${OLD_ARCHIVE}.sha256"
OLD_MANIFEST="${OLD_ARCHIVE}.manifest"
```

---

## 49. Manifest Removal Condition

The script checks:

```bash
if [[ -f "$OLD_MANIFEST" ]]; then
```

before deleting it.

---

## 50. Historical Backup Compatibility

Historical backups created before SEN-019 do not have manifest files.

Conditional deletion ensures those backups can still expire normally.

---

## 51. Historical Integrity Compatibility

Even older backups may also lack `.sha256` files.

The retention code therefore independently checks whether:

```text
checksum exists
manifest exists
```

before removing associated metadata.

---

## 52. Final Retention Model

```text
find expired .tar.gz archive
          |
          v
derive .sha256 path
          |
          v
remove checksum if present
          |
          v
derive .manifest path
          |
          v
remove manifest if present
          |
          v
remove archive
```

---

## 53. Retention Threshold

The retention threshold remains:

```bash
RETENTION_MINUTES=10080
```

Equivalent to:

```text
7 days
```

---

## 54. No Retention Period Change

SEN-019 changes only associated artifact cleanup.

The retention period itself remains unchanged.

---

## 55. Safe Three-File Retention Test

A synthetic test directory was created using:

```bash
mktemp -d
```

No production backup was deliberately aged or removed.

---

## 56. Synthetic Test Archive

The test created:

```text
sentinelops-backup-RETENTION-OLD.tar.gz
```

---

## 57. Synthetic Test Checksum

The test generated:

```text
sentinelops-backup-RETENTION-OLD.tar.gz.sha256
```

---

## 58. Synthetic Test Manifest

The test generated:

```text
sentinelops-backup-RETENTION-OLD.tar.gz.manifest
```

---

## 59. Synthetic Manifest Contents

The test manifest contained:

```text
./application/test-file
```

---

## 60. Synthetic Age

All three synthetic artifacts were aged using:

```bash
touch -d '8 days ago'
```

This placed them beyond the seven-day retention threshold.

---

## 61. Pre-Retention Test State

Before cleanup, the directory contained:

```text
archive
checksum
manifest
```

---

## 62. Retention Test Result

The test reported:

```text
Removing archive: ...sentinelops-backup-RETENTION-OLD.tar.gz
Removing checksum: ...sentinelops-backup-RETENTION-OLD.tar.gz.sha256
Removing manifest: ...sentinelops-backup-RETENTION-OLD.tar.gz.manifest
```

---

## 63. Empty Directory Proof

After retention processing:

```bash
ls -la "$MANIFEST_RETENTION_TEST_DIR"
```

showed only:

```text
.
..
```

---

## 64. Retention Test Cleanup

The temporary directory was removed using:

```bash
rm -rf "$MANIFEST_RETENTION_TEST_DIR"
```

---

## 65. Production Backup Safety

No real production backup was:

- aged;
- deleted;
- renamed;
- corrupted;
- modified for retention testing.

---

## 66. Production Integrity Regression

After retention testing:

```bash
sha256sum --check ...
```

still returned:

```text
sentinelops-backup-20260831T103229Z.tar.gz: OK
```

---

## 67. Production Manifest Regression

After retention testing:

```bash
diff -u manifest <(tar -tzf archive)
```

returned no output.

The production manifest remained valid.

---

## 68. Freshness Regression

The monitoring script was executed after SEN-019.

The newest backup was:

```text
sentinelops-backup-20260831T103229Z.tar.gz
```

---

## 69. Backup Age

The newest archive was:

```text
0 hour(s)
```

old.

---

## 70. Freshness Result

The monitoring script reported:

```text
Backup freshness: OK
```

---

## 71. Structured Freshness Result

The monitoring log contained:

```text
timestamp=2026-08-31T10:34:42Z check=backup_freshness status=PASS severity=INFO message="Newest backup sentinelops-backup-20260831T103229Z.tar.gz is 0 hour(s) old, within freshness threshold of 36 hours"
```

---

## 72. Why Manifest Files Do Not Break Freshness

The freshness selector matches only:

```text
sentinelops-backup-*.tar.gz
```

Manifest files end with:

```text
.tar.gz.manifest
```

and therefore are not selected as backup archives.

---

## 73. Checksum Files Also Remain Excluded

Checksum files end with:

```text
.tar.gz.sha256
```

They are also excluded from freshness archive selection.

---

## 74. Docker Regression

Monitoring continued to report:

```text
Docker: active
```

---

## 75. Nginx Regression

Monitoring continued to report:

```text
Nginx: active
```

---

## 76. SSH Regression

Monitoring continued to report:

```text
SSH: active
```

---

## 77. Compose Regression

The application remained:

```text
running
```

with:

```text
127.0.0.1:8000->80/tcp
```

---

## 78. Application Health Regression

The application health check returned:

```text
HTTP 200
```

---

## 79. Host Nginx Health Regression

Host Nginx returned:

```text
HTTP 200
```

---

## 80. Backup Timer Regression

The systemd timer remained:

```text
enabled
active (waiting)
```

---

## 81. Next Scheduled Run

The timer continued to target:

```text
Tue 2026-09-01 00:00:00 UTC
```

---

## 82. Persistent Scheduling

The timer remains configured with:

```text
Persistent=true
```

---

## 83. Backup Service Configuration

The existing systemd service remains unchanged:

```text
Type=oneshot
User=root
ExecStart=/home/emir/backups/sentinelops/backup-sentinelops.sh
```

---

## 84. Bash Syntax Regression

The final backup script passed:

```bash
bash -n /home/emir/backups/sentinelops/backup-sentinelops.sh
```

No output was returned.

---

## 85. UFW Regression

UFW remained:

```text
Status: active
```

---

## 86. Default Firewall Policy

The default remained:

```text
deny (incoming)
```

---

## 87. Allowed Services

Inbound rules remained:

```text
22/tcp
80/tcp
```

---

## 88. No Backend Firewall Exposure

No UFW rule exists for:

```text
8000/tcp
```

---

## 89. Listener Regression

Listeners remained:

```text
127.0.0.1:8000
0.0.0.0:80
0.0.0.0:22
[::]:80
[::]:22
```

---

## 90. Backend Isolation

The application backend remains bound to:

```text
127.0.0.1:8000
```

rather than:

```text
0.0.0.0:8000
```

---

## 91. Network Impact

SEN-019 introduces:

```text
no new daemon
no new port
no new listener
no new firewall rule
```

---

## 92. Files Changed on Ubuntu

SEN-019 modified:

```text
/home/emir/backups/sentinelops/backup-sentinelops.sh
```

---

## 93. Files Not Changed

SEN-019 did not modify:

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

## 94. Runtime Artifacts Created

SEN-019 created:

```text
sentinelops-backup-20260831T103229Z.tar.gz
sentinelops-backup-20260831T103229Z.tar.gz.sha256
sentinelops-backup-20260831T103229Z.tar.gz.manifest
```

---

## 95. Manifest Limitation

The manifest lists archive paths.

It does not provide:

- per-file SHA-256 hashes;
- file ownership metadata;
- file permission metadata;
- file modification timestamps;
- cryptographic signatures.

---

## 96. Archive-Level Integrity Remains Separate

The existing SHA-256 file hashes the completed archive as one object.

The manifest itself is not independently signed.

---

## 97. Same-Host Metadata Limitation

The archive, checksum, and manifest are stored on the same host.

An attacker with sufficient access could potentially modify multiple artifacts.

This remains an accepted local-MVP limitation.

---

## 98. Off-Host Limitation

SEN-019 does not replicate:

```text
archive
checksum
manifest
```

to off-host storage.

---

## 99. Restoration Limitation

A correct manifest does not prove restoration succeeds.

It proves only that the manifest matches the archive listing.

---

## 100. Historical Manifest Limitation

Backups created before SEN-019 remain without manifests.

SEN-019 does not retroactively generate them.

---

## 101. Why Historical Manifests Were Not Backfilled

A newly generated manifest for an old archive would describe its current contents.

It would not prove what the archive contained at the moment of original creation.

Therefore historical archives are not falsely represented as originally manifested backups.

---

## 102. Final Backup Assurance Model

After SEN-019:

```text
Backup exists
     |
     +--> Freshness
     |       Is it recent?
     |
     +--> Integrity
     |       Has the archive changed?
     |
     +--> Manifest
             What is inside it?
```

---

## 103. Final Backup Artifact Contract

Every new backup should now produce:

```text
1 x .tar.gz
1 x .tar.gz.sha256
1 x .tar.gz.manifest
```

---

## 104. Final Retention Contract

Expired backup sets remove:

```text
archive
checksum if present
manifest if present
```

---

## 105. Acceptance Criteria Verification

### FR-27 documented

Verified.

### Manifest format defined

Verified.

### New backup generates manifest

Verified.

### Manifest generated after archive creation

Verified.

### Deterministic archive/manifest association

Verified.

### Manifest generated from completed archive

Verified.

### Manifest human-readable

Verified.

### Application files present

Verified.

### Monitoring script present

Verified.

### Nginx configuration present

Verified.

### Manifest matches direct archive listing

Verified.

### Manifest ownership

Verified:

```text
emir:emir
```

### Manifest permissions

Verified:

```text
600
```

### SHA-256 generation preserved

Verified.

### SHA-256 verification preserved

Verified:

```text
OK
```

### Backup freshness preserved

Verified:

```text
PASS / INFO
```

### Seven-day retention preserved

Verified.

### Manifest retention implemented

Verified.

### Three-file synthetic retention

Verified.

### Historical backup compatibility

Verified.

### Real backups preserved during testing

Verified.

### Timer enabled

Verified.

### Timer active

Verified.

### Persistent timer preserved

Verified.

### Backup service configuration valid

Verified.

### Application health operational

Verified.

### Host Nginx operational

Verified.

### UFW active

Verified.

### Default incoming deny

Verified.

### TCP 22 allowed

Verified.

### TCP 80 allowed

Verified.

### No TCP 8000 UFW allow rule

Verified.

### Backend loopback-only

Verified.

### No new network listener

Verified.

### Backup script syntax validation

Verified.

---

## 106. Commands Used During SEN-019

Git branch cleanup:

```bash
git branch -d sen-019-backup-manifset
git branch
```

SSH:

```bash
ssh emir@192.168.64.2
```

Backup script inspection:

```bash
sed -n '1,240p' /home/emir/backups/sentinelops/backup-sentinelops.sh
```

Backup inventory:

```bash
ls -lh /home/emir/backups/sentinelops/
```

Initial manifest search:

```bash
find /home/emir/backups/sentinelops \
    -maxdepth 1 \
    -type f \
    -name '*.manifest' \
    -print
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

Archive listing:

```bash
tar -tzf "$NEWEST_ARCHIVE"
```

Timer inspection:

```bash
systemctl status sentinelops-backup.timer --no-pager
```

Service inspection:

```bash
systemctl status sentinelops-backup.service --no-pager
```

Backup script editing:

```bash
nano /home/emir/backups/sentinelops/backup-sentinelops.sh
```

Syntax validation:

```bash
bash -n /home/emir/backups/sentinelops/backup-sentinelops.sh
```

Manifest implementation inspection:

```bash
grep -nE 'MANIFEST_FILE|tar -tzf|diff -u|OLD_MANIFEST|CHECKSUM_FILE|RETENTION_MINUTES' \
    /home/emir/backups/sentinelops/backup-sentinelops.sh
```

Controlled backup run:

```bash
sudo systemctl start sentinelops-backup.service
```

Artifact inspection:

```bash
stat -c '%n | owner=%U:%G | mode=%a | size=%s' \
    "$NEWEST_ARCHIVE" \
    "${NEWEST_ARCHIVE}.sha256" \
    "${NEWEST_ARCHIVE}.manifest"
```

Manifest inspection:

```bash
cat "${NEWEST_ARCHIVE}.manifest"
```

Manifest comparison:

```bash
diff -u \
    "${NEWEST_ARCHIVE}.manifest" \
    <(tar -tzf "$NEWEST_ARCHIVE")
```

Checksum verification:

```bash
sha256sum --check "$(basename "${NEWEST_ARCHIVE}.sha256")"
```

Temporary retention directory:

```bash
MANIFEST_RETENTION_TEST_DIR="$(mktemp -d)"
```

Synthetic archive creation:

```bash
printf 'SEN-019 manifest retention test\n' \
    > "$MANIFEST_RETENTION_TEST_DIR/sentinelops-backup-RETENTION-OLD.tar.gz"
```

Synthetic checksum generation:

```bash
(
    cd "$MANIFEST_RETENTION_TEST_DIR"
    sha256sum sentinelops-backup-RETENTION-OLD.tar.gz \
        > sentinelops-backup-RETENTION-OLD.tar.gz.sha256
)
```

Synthetic manifest creation:

```bash
printf './application/test-file\n' \
    > "$MANIFEST_RETENTION_TEST_DIR/sentinelops-backup-RETENTION-OLD.tar.gz.manifest"
```

Synthetic ageing:

```bash
touch -d '8 days ago' \
    "$MANIFEST_RETENTION_TEST_DIR/sentinelops-backup-RETENTION-OLD.tar.gz" \
    "$MANIFEST_RETENTION_TEST_DIR/sentinelops-backup-RETENTION-OLD.tar.gz.sha256" \
    "$MANIFEST_RETENTION_TEST_DIR/sentinelops-backup-RETENTION-OLD.tar.gz.manifest"
```

Retention inspection:

```bash
ls -lh "$MANIFEST_RETENTION_TEST_DIR"
```

Empty-directory verification:

```bash
ls -la "$MANIFEST_RETENTION_TEST_DIR"
```

Temporary cleanup:

```bash
rm -rf "$MANIFEST_RETENTION_TEST_DIR"
```

Monitoring regression:

```bash
~/sentinelops-monitoring/health-check.sh
```

Freshness log inspection:

```bash
grep 'check=backup_freshness' \
    /var/log/sentinelops/health-check.log | tail -1
```

Firewall regression:

```bash
sudo ufw status verbose
```

Listener regression:

```bash
ss -tulpn | grep -E ':22|:80|:8000'
```

---

## 107. SEN-019 Completion State

Before SEN-019:

```text
backup creation -> implemented
backup automation -> implemented
backup scheduling -> implemented
backup persistence -> implemented
backup retention -> implemented
backup restoration documentation -> implemented
backup freshness -> implemented
backup integrity -> implemented
backup manifest -> not implemented
```

After SEN-019:

```text
backup creation -> implemented
backup automation -> implemented
backup scheduling -> implemented
backup persistence -> implemented
backup retention -> implemented
backup restoration documentation -> implemented
backup freshness -> implemented
backup integrity -> implemented
backup manifest -> implemented
```

The first manifest-enabled production backup is:

```text
sentinelops-backup-20260831T103229Z.tar.gz
```

with:

```text
sentinelops-backup-20260831T103229Z.tar.gz.sha256
sentinelops-backup-20260831T103229Z.tar.gz.manifest
```

The manifest matches the completed archive exactly.

The checksum verifies as:

```text
OK
```

The newest backup freshness result remains:

```text
PASS / INFO
```

Three-file retention successfully removes:

```text
archive
checksum
manifest
```

from an expired synthetic backup set.

The timer remains enabled and active.

The seven-day retention threshold remains unchanged.

The application remains healthy.

UFW remains active with default deny incoming.

The backend remains private at:

```text
127.0.0.1:8000
```

No new network service, listener, or firewall rule was introduced.

SEN-019 is ready for repository validation, commit, pull request, review, merge, and issue closure.