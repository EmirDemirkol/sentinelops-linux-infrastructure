# SEN-031 Clean Rebuild Validation Baseline

## Purpose

SEN-031 validates that the combined SentinelOps implementation through SEN-030 can be reproduced on a fresh supported Ubuntu Server VM.

The test covers clean provisioning, secure access, application deployment, network isolation, scheduled monitoring, local backups, restoration, repeated provisioning, reboot persistence and controlled failure detection.

Runtime validation was performed on 11 September 2026.

This document records runtime evidence. It does not declare final MVP release or completion of every project success criterion.

## Source Revision

Repository:

https://github.com/EmirDemirkol/sentinelops-linux-infrastructure

Validated commit:

```text
cc6e8206d1c2ee1afa6b60b995f14b2097013e96
```

This is the SEN-030 merge revision from PR #47.

The VM used a detached checkout of this exact commit. Source validation reported a clean working tree.

Documentation is prepared on:

```text
sen-031-clean-rebuild-validation
```

No provisioner implementation correction was required during the recorded rebuild.

## Fresh Environment

A new Ubuntu installation was created from the installer ISO. It was not cloned from an existing provisioned SentinelOps VM.

| Property | Recorded value |
|---|---|
| UTM VM name | SentinelOps-Rebuild |
| Hostname | sentinelops-rebuild |
| Operating system | Ubuntu Server 24.04.4 LTS |
| Architecture | arm64 |
| Kernel | 6.8.0-139-generic |
| Virtualisation | QEMU through UTM |
| CPU allocation | 2 cores |
| Memory allocation | 3072 MiB |
| Reported memory | 2.9 GiB |
| Virtual disk | 20 GiB configured in UTM |
| Root filesystem | ext4, approximately 19 GiB |
| Initial root free space | Approximately 12 GiB |
| Swap | Approximately 2.9 GiB |
| Network | UTM shared network |
| Interface | enp0s1 |
| Recorded IPv4 address | 192.168.64.4/24 |
| Administrator | emir |
| Home directory | /home/emir |

Installer media:

```text
ubuntu-24.04.4-live-server-arm64.iso
```

The standard Ubuntu Server installation was selected. OpenSSH server was installed. Ubuntu Pro and featured server snaps were not selected.

The installer ISO was detached after the VM initially booted back into the installer following reboot. The installed operating system then booted successfully.

Existing SentinelOps VMs were not repurposed for this rebuild.

## Administrator and SSH Bootstrap

The installer created the named administrator account:

```text
user: emir
group: emir
home: /home/emir
```

Administrative access was confirmed with:

```bash
sudo -v
```

UTM console access remained available during SSH and firewall configuration.

The administrator's existing Mac public key was installed into:

```text
/home/emir/.ssh/authorized_keys
```

From the Mac:

```bash
cat "$HOME/.ssh/id_rsa.pub" | ssh emir@192.168.64.4 'umask 077; mkdir -p /home/emir/.ssh; cat >> /home/emir/.ssh/authorized_keys; chmod 700 /home/emir/.ssh; chmod 600 /home/emir/.ssh/authorized_keys'
```

Public-key access was verified before provisioning applied SSH hardening:

```bash
ssh -i "$HOME/.ssh/id_rsa" \
  -o IdentitiesOnly=yes \
  -o PreferredAuthentications=publickey \
  emir@192.168.64.4 'hostname; whoami'
```

Result:

```text
sentinelops-rebuild
emir
```

The private key remained on the Mac.

Several initial commands were accidentally executed inside the VM instead of on the Mac. Those attempts failed because the Mac private key was unavailable inside Ubuntu. They were corrected by running the commands from the Mac prompt.

Password-entry mistakes were corrected interactively. These were operator setup errors, not provisioning defects.

## Repository Preparation

Git was already available at:

```text
/usr/bin/git
```

Inside Rebuild:

```bash
git clone https://github.com/EmirDemirkol/sentinelops-linux-infrastructure.git /home/emir/sentinelops-linux-infrastructure
cd /home/emir/sentinelops-linux-infrastructure
git checkout --detach cc6e8206d1c2ee1afa6b60b995f14b2097013e96
git rev-parse HEAD
git status --short --branch
```

Source validation:

```bash
bash -n provision/scripts/provision.sh &&
bash -n provision/monitoring/health-check.sh &&
bash -n provision/backup/backup-sentinelops.sh &&
git diff --check &&
echo "All source checks passed"
```

Result:

```text
All source checks passed
```

## First Provisioning Execution

The documented entry point was executed from the repository root:

```bash
sudo -v
set -o pipefail
sudo bash provision/scripts/provision.sh 2>&1 | tee /home/emir/sen031-first-provision.log
provision_status=${PIPESTATUS[0]}
printf 'Provisioner exit code: %s\n' "$provision_status" | tee -a /home/emir/sen031-first-provision.log
```

Result:

```text
[SEN-025] Provisioning preflight completed successfully
[SEN-025] SentinelOps provisioning completed successfully
Provisioner exit code: 0
```

Preflight verified the supported OS, administrator, source assets, shell syntax, public-key readiness, disk capacity, repository name resolution, managed paths and port assumptions.

Provisioning installed or configured Docker, Compose, Nginx, SSH, UFW, application assets, monitoring and backup units.

The provisioner created the initial backup and validated its checksum and manifest.

No undocumented manual package or service configuration was needed to make provisioning succeed.

## Application and Network Verification

Provisioner validation reported:

```text
Backend health HTTP status: 200
Host Nginx health HTTP status: 200
```

Expected response:

```json
{"status":"healthy","version":"0.1.0"}
```

The running container published:

```text
127.0.0.1:8000->80/tcp
```

Relevant listeners were:

```text
0.0.0.0:22
[::]:22
0.0.0.0:80
[::]:80
127.0.0.1:8000
```

Nginx configuration validation passed.

From the Mac:

```bash
curl --fail --show-error --max-time 10 http://192.168.64.4/health
nc -vz -G 5 192.168.64.4 8000
```

The HTTP request returned the expected healthy JSON. Direct access to TCP 8000 timed out.

The external connection result and the verified loopback publication together establish the tested backend isolation boundary.

## SSH and Firewall Verification

A new public-key connection from the Mac succeeded after hardening.

The named account's new session included the Docker group.

Effective SSH settings reported:

```text
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
kbdinteractiveauthentication no
```

A root login attempt from the Mac was rejected:

```bash
ssh -i "$HOME/.ssh/id_rsa" \
  -o IdentitiesOnly=yes \
  -o BatchMode=yes \
  -o PreferredAuthentications=publickey \
  root@192.168.64.4 'whoami'
```

Result:

```text
root@192.168.64.4: Permission denied (publickey).
```

UFW was active with:

```text
deny incoming
allow outgoing
deny routed
```

The permitted inbound services were SSH on TCP 22 and Nginx HTTP on TCP 80, for IPv4 and IPv6.

UFW remained active after reboot.

## Ownership and Permissions

Observed metadata:

| Path or artifact | Owner | Mode |
|---|---|---|
| /usr/local/lib/sentinelops | root:root | 0755 |
| /usr/local/lib/sentinelops/health-check.sh | root:root | 0755 |
| /var/log/sentinelops | root:emir | 0750 |
| /var/log/sentinelops/health-check.log | emir:emir | 0640 |
| Initial backup archive | emir:emir | 0600 |
| Initial checksum | emir:emir | 0600 |
| Initial manifest | emir:emir | 0600 |

Checks executed as `emir` without sudo confirmed these paths were not writable:

```text
/usr/local/lib/sentinelops
/usr/local/lib/sentinelops/health-check.sh
/etc/nginx/sites-available/sentinelops
/etc/ssh/sshd_config.d/00-sentinelops.conf
```

This verifies direct filesystem access restrictions for the named account without privilege escalation.

The account has sudo and Docker privileges. It is not claimed to be isolated from root-equivalent administrative capabilities.

## Scheduled Monitoring

Multiple scheduled executions produced structured records for:

- system load;
- memory;
- disk usage;
- backup freshness;
- Docker;
- Nginx;
- SSH;
- Compose application state;
- backend health;
- host Nginx health.

Healthy runs contained PASS records for all these checks.

Memory and load PASS records indicate successful collection. They do not establish usage-threshold evaluation.

Individual records were inspected separately from the monitoring service exit status.

## Repeated Provisioning

The same provisioner was executed again, with output captured in:

```text
/home/emir/sen031-repeat-provision.log
```

Result:

```text
Provisioner exit code: 0
```

Observed behaviour:

- existing Docker group membership was recognised;
- existing UFW rules were skipped;
- the application remained running;
- initial backup creation was skipped because an archive existed;
- before-and-after backup archive lists matched;
- health validation passed;
- no failed systemd units were reported;
- scheduled monitoring was re-enabled and resumed.

No implementation change was made between the two provisioning runs.

## Reboot Persistence

The VM was rebooted and a new SSH connection succeeded.

Recorded post-reboot boot ID:

```text
73052839-6916-4623-8463-199e880e63f6
```

After reboot:

- Docker was active;
- Nginx was active;
- ssh.socket was active;
- the application container restarted;
- port 8000 remained bound to loopback;
- HTTP health returned the expected JSON;
- both permanent timers remained enabled and active;
- no failed systemd units were reported.

The first inspected monitoring journal was empty because its initial scheduled execution had not occurred yet.

Scheduled monitoring then recorded PASS checks at:

```text
2026-09-11T13:07:17Z
```

The service completed at:

```text
2026-09-11T13:07:19Z
```

This confirms execution after reboot rather than relying only on timer configuration.

## Initial Backup and Isolated Extraction

Initial archive:

```text
sentinelops-backup-20260911T125921Z.tar.gz
```

Verification covered:

- SHA-256 checksum;
- gzip stream integrity;
- manifest comparison;
- extraction into an isolated directory;
- comparison of all five backed-up files with live originals.

All comparisons passed.

The extraction directory was:

```text
/home/emir/sen031-restore-test.um2mn0
```

It was removed after verification. Application health remained successful.

This extraction test was supplemented by the synthetic-data recovery exercise below.

## Synthetic-Data Loss and Recovery

A unique marker was appended to the disposable VM's application source page:

```text
SEN031-RECOVERY-20260911T133516Z
```

The original page was preserved in a temporary directory before modification.

The deployed backup service created:

```text
sentinelops-backup-20260911T133516Z.tar.gz
```

Its checksum passed.

The live source page was then replaced with the preserved original, removing the marker. A check confirmed that the synthetic data was missing.

The archive was extracted into a separate temporary directory. Its application page was copied back to the source location.

Verification confirmed:

- exact content equality with the expected marked page;
- restored owner `emir:emir`;
- restored mode `0664`;
- successful application health.

Recorded recovery timestamps:

| Event | UTC |
|---|---|
| Recovery started | 2026-09-11T13:35:16Z |
| Recovery verified | 2026-09-11T13:35:16Z |

Both events occurred within the same recorded second. The evidence does not claim a precise subsecond duration.

The original unmarked page was reinstated and compared successfully. Temporary recovery files were removed through the cleanup trap.

The synthetic backup remains identifiable as test evidence.

The running container used its image's existing page. This exercise proves application source-file recovery, ownership and permission handling. It does not prove rebuilding a container image or restoring a complete host from backup.

## Deliberately Modified Backup

The synthetic recovery archive and its checksum were copied into a disposable directory.

The copied archive initially passed verification.

Test bytes were appended to that copy, after which verification reported:

```text
FAILED
sha256sum: WARNING: 1 computed checksum did NOT match
PASS: modified backup rejected
```

The original archive was verified again:

```text
OK
PASS: original backup remains intact
```

The disposable corrupted copy was removed automatically.

## Timer-Triggered Backup Execution

The permanent backup timer remained configured for daily execution.

To observe scheduled execution during the validation session, a separate transient timer was created:

```bash
sudo systemd-run --unit=sen031-backup-trigger --on-active=30s /usr/bin/systemctl start sentinelops-backup.service
```

Observed events:

| Event | UTC |
|---|---|
| Temporary timer created | 2026-09-11T13:37:46Z |
| Trigger service started | 2026-09-11T13:38:26Z |
| Backup completed | 2026-09-11T13:38:27Z |

Created archive:

```text
sentinelops-backup-20260911T133827Z.tar.gz
```

The journal recorded successful checksum and manifest verification.

Service result:

```text
Result=success
ExecMainStatus=0
```

The transient timer was subsequently unloaded. A cleanup stop request reported that the unit was no longer loaded.

Both permanent timers remained enabled and active.

This demonstrates timer-triggered execution of the deployed backup workflow. It does not claim that the normal midnight calendar trigger or a missed daily execution was observed during SEN-031.

## Controlled Nginx Failure

Nginx was deliberately stopped on Rebuild.

The test watched new monitoring records without manually starting the monitoring service. Nginx was restored after detection, with a bounded fallback and cleanup trap.

| Event | UTC |
|---|---|
| Failure test started | 2026-09-11T13:15:20Z |
| Scheduled Nginx FAIL | 2026-09-11T13:15:25Z |
| Nginx restored | 2026-09-11T13:15:26Z |
| Scheduled recovery PASS | 2026-09-11T13:16:26Z |

Failure record:

```text
timestamp=2026-09-11T13:15:25Z check=nginx_service status=FAIL severity=CRITICAL message="Nginx service is not active"
```

Recovery record:

```text
timestamp=2026-09-11T13:16:26Z check=nginx_service status=PASS severity=INFO message="Nginx service is active"
```

Observed detection time was five seconds, within the 120-second educational target.

Timing used whole-second UTC timestamps. This result is specific to the selected test and does not guarantee five-second detection for every failure.

Application health passed after restoration. No failed systemd units remained.

## Success-Criteria Mapping

Definitions are taken from `docs/phase-0/success-criteria.md`.

| Criterion | SEN-031 evidence and boundary |
|---|---|
| SC-03 | Loopback publication and unsuccessful Mac access to TCP 8000 |
| SC-04 | UFW policy, allowed services and post-reboot firewall evidence |
| SC-05 | Key authentication before hardening and new access after hardening |
| SC-06 | Effective root restriction and rejected root SSH attempt |
| SC-07 | Ownership, modes and direct non-writability checks on selected protected paths |
| SC-15 | Scheduled Nginx failure detected in five seconds |
| SC-18 | Timestamped backup and successful execution through a transient timer; normal midnight trigger not observed |
| SC-19 | Generated manifests verified against archive listings |
| SC-20 | Valid checksum accepted, deliberately modified copy rejected |
| SC-22 | Identifiable synthetic source content removed and recovered from backup |
| SC-23 | Recovered content, owner, mode and continuing application health verified within source-file test scope |
| SC-33 | Fresh installation provisioned successfully from the recorded revision |
| SC-34 | Second provisioning run reused rules and membership and preserved healthy state |
| SC-35 | Successful source and preflight validation recorded; negative preflight cases remain historical evidence |
| SC-45 | Fresh supported arm64 rebuild completed without an implementation repair |

The source-file recovery timing also supports the selected exercise's SC-24 educational target. It is not a general recovery-time guarantee.

Historical negative preflight evidence is documented in:

```text
docs/phase-4/provisioning-idempotency-validation-baseline.md
provision/README.md
```

Historical tests are not represented as newly executed during SEN-031.

## Limitations

- Runtime validation covers Ubuntu 24.04 arm64 only.
- The exact repository commit is recorded, but external package versions and image tags are not fully pinned.
- The selected restore test covers source files, not complete VM recovery or container rebuilding from backup.
- Backups remain local to the VM.
- The normal midnight backup trigger was not observed in this session.
- Missed daily backup catch-up was not tested in this session.
- Retention failure simulations and negative preflight cases were not repeated during this issue.
- Memory and load collection do not implement usage thresholds.
- Monitoring service success does not aggregate every individual check outcome.
- External alerting and automatic remediation remain outside scope.
- SEN-032 retains the final criterion-by-criterion release audit and demonstration evidence.

## Repository Completion Gates

At document preparation:

- runtime evidence has been collected;
- documentation review and Git validation remain pending;
- SEN-031 pull-request CI remains pending;
- merge verification remains pending;
- post-merge main CI remains pending;
- local and remote branch cleanup remain pending;
- the closing issue evidence comment remains pending.

Actual PR, CI, merge and cleanup results must be recorded in the SEN-031 PR and closing issue comment.

No future CI result or merge outcome is claimed by this runtime baseline.

## Final Runtime State

At the end of the recorded tests:

- named administrator SSH access worked;
- root SSH access was rejected;
- Nginx and Docker were operational;
- the application returned the expected healthy response;
- TCP 8000 remained private;
- permanent backup and monitoring timers were enabled and active;
- protected file-access checks passed;
- restoration and corruption-test temporary directories were cleaned up;
- the original application source was reinstated;
- the temporary backup trigger was unloaded;
- no failed systemd units were reported.

The clean rebuild and selected verification exercises succeeded within the boundaries recorded above.