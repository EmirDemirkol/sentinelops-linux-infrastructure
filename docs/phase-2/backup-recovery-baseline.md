# SentinelOps Backup and Recovery Baseline

## Purpose

This document records the implementation and verification of the SentinelOps local backup and recovery baseline.

The backup and recovery baseline builds on:

- SEN-007 host-level Nginx deployment
- SEN-008 Docker Engine installation
- SEN-009 private application deployment
- SEN-010 Docker Compose application deployment
- SEN-011 local monitoring and operational visibility

The objective is to create a repeatable local backup process for the current SentinelOps application and supporting configuration, verify archive integrity, perform a real isolated restore test, compare restored files with the live originals, and confirm that backup activity does not disrupt the running system.

The SEN-012 implementation remains intentionally local to the Ubuntu VM.

---

## Initial State

Before SEN-012:

- Ubuntu Server 24.04.4 LTS was running in UTM
- the VM used IPv4 address `192.168.64.2`
- SSH public-key administration was operational
- UFW was active
- TCP port 22 was allowed for SSH
- TCP port 80 was allowed for Nginx HTTP
- TCP port 443 remained blocked
- Docker Engine was installed and active
- Docker Compose was available
- the Compose-managed `sentinelops-app` container was running
- the application backend was bound only to `127.0.0.1:8000`
- host Nginx reverse proxied requests to the private backend
- the application project existed under `/home/emir/sentinelops-app`
- the monitoring script existed under `/home/emir/sentinelops-monitoring`
- the SentinelOps Nginx configuration existed at `/etc/nginx/sites-available/sentinelops`
- no reusable SentinelOps backup script existed
- no local SentinelOps archive directory existed
- no off-host backup destination was configured
- UTM console access remained available as a recovery path

---

## Filesystem Capacity Baseline

Filesystem capacity was reviewed using:

```bash
df -h /
```

Observed result:

```text
Filesystem                         Size  Used Avail Use% Mounted on
/dev/mapper/ubuntu--vg-ubuntu--lv   14G  5.9G  6.6G  48% /
```

This confirmed:

- root filesystem size was approximately `14 GB`
- approximately `5.9 GB` was used
- approximately `6.6 GB` remained available
- filesystem usage was approximately `48%`

The host had sufficient capacity for the small local configuration backups required by SEN-012.

---

## Application Source Size

The SentinelOps application directory size was reviewed using:

```bash
du -sh ~/sentinelops-app
```

Observed result:

```text
16K    /home/emir/sentinelops-app
```

The application source footprint was therefore very small.

---

## Monitoring Source Size

The monitoring directory size was reviewed using:

```bash
du -sh ~/sentinelops-monitoring
```

Observed result:

```text
8.0K    /home/emir/sentinelops-monitoring
```

The monitoring configuration also had a minimal storage footprint.

---

## Nginx Configuration Baseline

The SentinelOps Nginx site was verified using:

```bash
ls -l /etc/nginx/sites-available/sentinelops
```

Observed result:

```text
-rw-r--r-- 1 root root 372 Aug 26 18:41 /etc/nginx/sites-available/sentinelops
```

This confirmed that the active reverse-proxy configuration existed and was owned by `root`.

---

## Application Runtime Baseline

The Compose-managed application state was verified using:

```bash
docker compose -f ~/sentinelops-app/compose.yaml ps
```

The application was reported as:

```text
sentinelops-app   sentinelops-app-app   app   Up 20 hours   127.0.0.1:8000->80/tcp
```

This confirmed:

- the application was running
- Docker Compose was managing the service
- the backend remained bound only to `127.0.0.1:8000`

---

## Firewall Baseline

UFW was reviewed using:

```bash
sudo ufw status verbose
```

Observed result:

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

No backup-related firewall rule existed.

No rule existed for TCP port 8000.

---

## Backup Scope

The backup baseline includes only the minimum files required to recreate the current SentinelOps application and supporting local configuration.

Included application files:

```text
/home/emir/sentinelops-app/
├── index.html
├── Dockerfile
└── compose.yaml
```

Included monitoring file:

```text
/home/emir/sentinelops-monitoring/
└── health-check.sh
```

Included Nginx file:

```text
/etc/nginx/sites-available/
└── sentinelops
```

---

## Excluded Data

The backup deliberately excludes:

- SSH private keys
- SSH host keys
- credentials
- API tokens
- passwords
- Docker images
- Docker container writable layers
- operating-system packages
- system logs
- package caches
- temporary files
- the complete Ubuntu filesystem

This keeps the archive minimal and avoids backing up unnecessary or sensitive runtime data.

---

## Backup Directory

A dedicated local backup directory was created using:

```bash
mkdir -p ~/backups/sentinelops
```

The resulting directory was:

```text
/home/emir/backups/sentinelops
```

This became the local backup destination for the SEN-012 baseline.

---

## Backup Script

A reusable backup script was created at:

```text
/home/emir/backups/sentinelops/backup-sentinelops.sh
```

The script was created using:

```bash
nano ~/backups/sentinelops/backup-sentinelops.sh
```

The script contains:

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

sudo cp /etc/nginx/sites-available/sentinelops \
   "$STAGING_DIR/nginx/sentinelops"

sudo chown -R emir:emir "$STAGING_DIR"

tar -czf "$ARCHIVE" -C "$STAGING_DIR" .

chmod 600 "$ARCHIVE"

echo "Backup created:"
echo "$ARCHIVE"
echo
echo "Archive size:"
du -h "$ARCHIVE"
```

---

## Backup Script Behaviour

The script performs the following sequence:

1. enables strict shell behaviour
2. creates a UTC timestamp
3. creates a temporary staging directory
4. creates application, monitoring, and Nginx subdirectories
5. copies the required application files
6. copies the monitoring script
7. copies the root-owned Nginx configuration
8. transfers ownership of staging content to `emir`
9. creates a compressed `.tar.gz` archive
10. sets archive permissions to `600`
11. removes temporary staging data automatically when complete

---

## Strict Shell Options

The script uses:

```bash
set -euo pipefail
```

This improves reliability by causing the script to stop when:

- a command fails
- an undefined variable is referenced
- a command in a pipeline fails

This reduces the risk of silently producing an incomplete backup.

---

## Temporary Staging Directory

The script creates a temporary staging directory using:

```bash
mktemp -d
```

The staging directory is automatically removed through:

```bash
trap cleanup EXIT
```

This prevents temporary backup material from being left behind after script completion.

---

## Timestamped Archive Naming

Backup filenames use UTC timestamps.

The naming pattern is:

```text
sentinelops-backup-YYYYMMDDTHHMMSSZ.tar.gz
```

The successful SEN-012 archive was:

```text
sentinelops-backup-20260827T155515Z.tar.gz
```

This provides clear chronological identification of backup generations.

---

## Script Permissions

The backup script was made executable using:

```bash
chmod +x ~/backups/sentinelops/backup-sentinelops.sh
```

The script could then be executed directly.

---

## Backup Execution

The backup was generated using:

```bash
~/backups/sentinelops/backup-sentinelops.sh
```

Observed output:

```text
Backup created:
/home/emir/backups/sentinelops/sentinelops-backup-20260827T155515Z.tar.gz

Archive size:
4.0K    /home/emir/backups/sentinelops/sentinelops-backup-20260827T155515Z.tar.gz
```

The backup completed successfully.

---

## Backup Directory Inspection

The backup directory was inspected using:

```bash
ls -lh ~/backups/sentinelops/
```

Observed result:

```text
total 8.0K
-rwxrwxr-x 1 emir emir  960 Aug 27 15:55 backup-sentinelops.sh
-rw------- 1 emir emir 1.9K Aug 27 15:55 sentinelops-backup-20260827T155515Z.tar.gz
```

This confirmed that both the reusable backup script and generated archive were present.

---

## Archive Permissions

The generated archive permissions were:

```text
-rw-------
```

This corresponds to mode:

```text
600
```

Only the owning user can read or write the archive.

This is appropriate for locally stored configuration backups.

---

## Archive Size

The compressed archive occupied approximately:

```text
1.9K
```

on disk and was reported as:

```text
4.0K
```

by `du`.

This small size is expected because the current SentinelOps application and configuration files are minimal.

---

## Archive Content Verification

Archive contents were listed using:

```bash
tar -tzf ~/backups/sentinelops/sentinelops-backup-20260827T155515Z.tar.gz
```

Observed contents:

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

This confirmed that every intended file was included.

---

## Application Files in Archive

The archive contained:

```text
./application/compose.yaml
./application/Dockerfile
./application/index.html
```

These files are sufficient to recreate the current Compose-managed application definition and custom application page.

---

## Monitoring File in Archive

The archive contained:

```text
./monitoring/health-check.sh
```

This preserves the SEN-011 operational health-check tooling.

---

## Nginx Configuration in Archive

The archive contained:

```text
./nginx/sentinelops
```

This preserves the reverse-proxy configuration required to connect host Nginx to the private application backend.

---

## Archive Integrity Verification

Compressed archive integrity was checked using:

```bash
gzip -t ~/backups/sentinelops/sentinelops-backup-20260827T155515Z.tar.gz && echo "Archive integrity OK"
```

Observed result:

```text
Archive integrity OK
```

This confirmed that the gzip stream was valid and readable.

---

## Restore Test Directory

A dedicated isolated restore directory was created using:

```bash
mkdir -p ~/sentinelops-restore-test
```

The restore test path was:

```text
/home/emir/sentinelops-restore-test
```

This location was deliberately separate from all live application and configuration paths.

---

## Isolated Restore

The archive was extracted using:

```bash
tar -xzf ~/backups/sentinelops/sentinelops-backup-20260827T155515Z.tar.gz -C ~/sentinelops-restore-test
```

The extraction completed successfully.

No live application file was overwritten.

---

## Restored File Inspection

Restored files were inspected using:

```bash
find ~/sentinelops-restore-test -maxdepth 3 -type f -print
```

Observed result:

```text
/home/emir/sentinelops-restore-test/nginx/sentinelops
/home/emir/sentinelops-restore-test/monitoring/health-check.sh
/home/emir/sentinelops-restore-test/application/compose.yaml
/home/emir/sentinelops-restore-test/application/Dockerfile
/home/emir/sentinelops-restore-test/application/index.html
```

This confirmed successful extraction of every expected file.

---

## Initial Find Warning

An earlier command used:

```bash
find ~/sentinelops-restore-test -type f -maxdepth 3 -print
```

This produced a warning because `-maxdepth` is a global `find` option and should be specified before the expression.

The corrected command was:

```bash
find ~/sentinelops-restore-test -maxdepth 3 -type f -print
```

The warning did not affect restoration and all files were present.

---

## Restored Application Comparison

The restored application page was compared with the live file:

```bash
diff ~/sentinelops-app/index.html \
~/sentinelops-restore-test/application/index.html
```

No output was returned.

This confirmed that the restored `index.html` was identical to the live original.

---

## Restored Dockerfile Comparison

The restored Dockerfile was compared with:

```bash
diff ~/sentinelops-app/Dockerfile \
~/sentinelops-restore-test/application/Dockerfile
```

No output was returned.

This confirmed that the restored Dockerfile was identical to the live original.

---

## Restored Compose Configuration Comparison

The restored Compose definition was compared using:

```bash
diff ~/sentinelops-app/compose.yaml \
~/sentinelops-restore-test/application/compose.yaml
```

No output was returned.

This confirmed that the restored `compose.yaml` was identical to the live original.

---

## Restored Monitoring Script Comparison

The restored health-check script was compared using:

```bash
diff ~/sentinelops-monitoring/health-check.sh \
~/sentinelops-restore-test/monitoring/health-check.sh
```

No output was returned.

This confirmed that the restored monitoring script was identical to the live original.

---

## Restored Nginx Configuration Comparison

The root-owned live Nginx configuration was compared using:

```bash
sudo diff /etc/nginx/sites-available/sentinelops \
~/sentinelops-restore-test/nginx/sentinelops
```

No output was returned.

This confirmed that the restored Nginx configuration was identical to the live original.

---

## Restore Accuracy Result

All five `diff` comparisons returned no output.

This means the restored files matched the corresponding live source files byte-for-byte for the purposes of the standard `diff` comparison.

The verified files were:

```text
index.html
Dockerfile
compose.yaml
health-check.sh
sentinelops Nginx configuration
```

This provides direct evidence that the backup can restore the current SentinelOps configuration accurately.

---

## Application State After Backup and Restore Testing

The live application was checked using:

```bash
docker compose -f ~/sentinelops-app/compose.yaml ps
```

Observed result:

```text
sentinelops-app   sentinelops-app-app   app   Up 20 hours   127.0.0.1:8000->80/tcp
```

This confirmed that backup and restore testing did not stop or recreate the live application.

---

## Nginx State After Backup Testing

Nginx was checked using:

```bash
systemctl status nginx
```

The service remained:

```text
Loaded: loaded
enabled
Active: active (running)
```

This confirmed that backup operations did not interrupt the host reverse proxy.

---

## Local HTTP Verification

The local host HTTP endpoint was checked using:

```bash
curl -I http://127.0.0.1
```

Result:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Content-Type: text/html
Content-Length: 1923
Connection: keep-alive
```

This confirmed that the application remained available locally after backup and restore testing.

---

## Firewall State After Backup Testing

UFW was reviewed again using:

```bash
sudo ufw status verbose
```

Observed result:

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

No backup-related rule was introduced.

No TCP port 8000 rule appeared.

---

## Listening Socket Verification

Relevant listeners were reviewed using:

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

- SSH remained externally available on TCP port 22
- Nginx remained externally available on TCP port 80
- the application backend remained loopback-only on TCP port 8000

No backup service introduced an additional listener.

---

## External HTTP Verification

After exiting the SSH session, the Mac tested the application using:

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

This confirmed that the external reverse-proxy path remained healthy after backup creation and restore testing.

---

## External Backend Isolation Verification

The Mac tested the backend directly using:

```bash
nc -vz -w 2 192.168.64.2 8000
```

The connection did not succeed.

The expected result was a timeout or no successful connection.

This confirmed that backup implementation did not weaken backend isolation.

---

## Backup Architecture

The implemented local backup path is:

```text
Application files
       +
Monitoring script
       +
Nginx configuration
       |
       v
Temporary staging directory
       |
       v
tar + gzip
       |
       v
Timestamped .tar.gz archive
       |
       v
/home/emir/backups/sentinelops/
```

---

## Restore Architecture

The validated restore path is:

```text
Backup archive
      |
      v
/home/emir/sentinelops-restore-test
      |
      v
Extract files
      |
      v
Inspect structure
      |
      v
diff restored files against live files
```

No live configuration is overwritten during verification.

---

## Recovery Procedure

A safe recovery workflow for the current SentinelOps configuration is:

1. identify the required backup archive
2. verify archive integrity with `gzip -t`
3. inspect archive contents with `tar -tzf`
4. extract the archive into an isolated temporary directory
5. review restored file structure
6. compare restored files against any surviving live files
7. reinstall required platform components if rebuilding a host
8. restore application files into the application directory
9. restore the monitoring script
10. restore the SentinelOps Nginx site as root
11. validate Docker Compose configuration
12. validate Nginx configuration
13. start the application stack
14. verify backend loopback binding
15. verify UFW state
16. verify external HTTP
17. verify direct backend isolation

SEN-012 validated the archive, extraction, and file-accuracy stages of this workflow.

---

## Backup Security Model

The backup process preserves the existing security architecture.

The archive does not intentionally contain:

- SSH private keys
- credentials
- tokens
- passwords
- private application secrets

The backup archive is stored with:

```text
600
```

permissions.

No backup daemon or remote backup service is introduced.

No network port is opened.

---

## Local Backup Limitation

The backup is stored on the same Ubuntu VM as the source files.

This provides protection against:

- accidental deletion of live application files
- accidental configuration modification
- operator error affecting the live deployment
- corruption of individual configuration files

It does not provide protection against:

- complete VM deletion
- virtual disk loss
- corruption of the entire virtual disk
- Mac host storage failure
- loss of the UTM VM bundle
- simultaneous destruction of both source and backup data

This limitation is intentional for the current MVP architecture.

---

## Future Backup Improvement

A later SentinelOps phase should replicate backups outside the VM.

Possible future targets include:

- the Mac host
- encrypted external storage
- a remote server
- object storage
- another trusted backup destination

Off-host replication should retain:

- encryption
- least privilege
- integrity checking
- retention control
- restore testing

This remains outside SEN-012.

---

## Retention Consideration

The current backup script creates timestamped archives and does not automatically remove older backups.

This is appropriate for the initial baseline because it avoids accidental deletion.

However, long-term operation will require a retention policy to prevent indefinite archive growth.

A future retention policy may keep a defined number of:

- daily backups
- weekly backups
- monthly backups

No automatic deletion policy was introduced during SEN-012.

---

## Backup Result

At completion of SEN-012:

- backup source paths are identified
- the backup footprint is small
- a dedicated local backup directory exists
- a reusable backup script exists
- the script is executable
- the script uses UTC timestamped archive names
- the application files are backed up
- the Docker Compose definition is backed up
- the monitoring script is backed up
- the SentinelOps Nginx configuration is backed up
- SSH private keys are excluded
- a compressed archive was created successfully
- archive permissions are restricted to `600`
- archive contents were verified
- gzip integrity validation passed
- an isolated restore directory was created
- the archive extracted successfully
- all expected restored files were present
- restored files were compared with live originals
- all file comparisons matched
- the live application remained running
- Nginx remained active
- UFW remained active
- external HTTP remained operational
- TCP port 8000 remained private
- no additional network service was introduced

---

## Verification Summary

The following checks were successfully completed:

- reviewed root filesystem capacity
- confirmed approximately `6.6 GB` free space
- reviewed application directory size
- reviewed monitoring directory size
- verified the SentinelOps Nginx configuration
- verified the Compose application was running
- reviewed UFW state
- created `/home/emir/backups/sentinelops`
- created `backup-sentinelops.sh`
- enabled strict shell error handling
- configured temporary staging
- configured automatic staging cleanup
- copied application files
- copied the monitoring script
- copied the root-owned Nginx configuration
- created timestamped compressed archives
- configured archive permissions to `600`
- executed the backup successfully
- created `sentinelops-backup-20260827T155515Z.tar.gz`
- reviewed backup directory contents
- verified archive permissions
- listed archive contents
- confirmed all expected files were included
- verified gzip integrity
- created `~/sentinelops-restore-test`
- extracted the archive safely
- reviewed restored file structure
- corrected the `find -maxdepth` argument order
- compared restored `index.html` with the live file
- compared restored `Dockerfile` with the live file
- compared restored `compose.yaml` with the live file
- compared restored `health-check.sh` with the live file
- compared restored Nginx configuration with the live file
- confirmed all `diff` checks returned no differences
- verified the application remained running
- verified Nginx remained active
- verified local HTTP returned `HTTP/1.1 200 OK`
- verified UFW remained active
- verified only TCP ports 22 and 80 remained externally allowed
- verified backend TCP port 8000 remained bound only to loopback
- verified external HTTP remained operational
- verified direct external backend access did not succeed
- confirmed no backup-related network service was exposed

---

## Out of Scope

SEN-012 did not introduce:

- off-host backup replication
- cloud backup storage
- encrypted remote backup transfer
- automated backup scheduling
- cron-based backup scheduling
- systemd timers
- backup alerting
- automated retention
- PostgreSQL backups
- database dumps
- Docker image backups
- Docker volume backups
- full VM snapshots
- full filesystem backups
- disaster recovery to a replacement VM
- production secret backup
- remote object storage
- backup monitoring dashboards

These capabilities remain reserved for later SentinelOps issues.

---

## Completion State

The SentinelOps Ubuntu Server VM now has a repeatable local backup and recovery baseline.

The current application source, Docker Compose definition, monitoring script, and Nginx reverse-proxy configuration can be collected into a timestamped compressed archive using a reusable backup script.

The generated archive is protected with restrictive file permissions, its contents can be inspected, and its compressed integrity can be validated.

A real isolated restore test successfully recovered every expected file, and all restored files matched their live originals.

The backup and restore process did not interrupt Docker, Nginx, UFW, SSH, the application, or the existing reverse-proxy architecture.

The backend remains private on `127.0.0.1:8000`, external HTTP remains available through Nginx, and no new network service was introduced.

This establishes the local backup and recovery foundation required before later SentinelOps scheduling, off-host replication, retention, and broader disaster-recovery work.s