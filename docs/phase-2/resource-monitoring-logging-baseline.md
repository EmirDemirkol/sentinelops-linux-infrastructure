# SEN-028 Resource Monitoring Logging Baseline

## Purpose

SEN-028 completes structured logging for host memory and system load samples.

Before this change, the health-check script displayed memory and load information in the terminal through `free -h` and `uptime`, but did not write those samples to the structured monitoring log.

This change addresses the resource-logging gap identified against SC-14.

GitHub issue: #42, SEN-028: Complete structured resource monitoring logs.

Pull request: #43.

## Scope

SEN-028 adds:

- Structured memory collection records.
- Structured system load collection records.
- Validation of collected resource input.
- Explicit collection-failure records.
- Isolated tests using synthetic input files.
- Successful collection after controlled failures.
- Validation against the deployed Ubuntu monitoring script.
- Updated monitoring guidance in `provision/README.md`.

The change does not introduce resource thresholds, monitoring scheduling, log rotation, external alerts or architecture changes.

## Relevant Files

Repository monitoring script:

```text
provision/monitoring/health-check.sh
```

Provisioning guidance:

```text
provision/README.md
```

Deployed monitoring script:

```text
/home/emir/sentinelops-monitoring/health-check.sh
```

Structured runtime log:

```text
/var/log/sentinelops/health-check.log
```

## Memory Collection

The `check_memory_usage` function reads:

```text
/proc/meminfo
```

It collects:

```text
MemTotal
MemAvailable
```

The structured message records:

```text
total_kib
available_kib
```

Both values are expressed in kibibytes.

Input validation requires:

- Exactly one `MemTotal:` field.
- Exactly one `MemAvailable:` field.
- Three fields on each required input line.
- Integer values with the expected `kB` unit.
- Total memory greater than zero.
- Available memory greater than or equal to zero.
- Available memory no greater than total memory.

A valid zero available-memory value is accepted as a collected sample.

No memory usage threshold is evaluated.

## System Load Collection

The `check_system_load` function reads:

```text
/proc/loadavg
```

The structured message records:

```text
load_1m
load_5m
load_15m
```

These are the 1-minute, 5-minute and 15-minute load averages.

They are not CPU percentages.

Input validation requires:

- Exactly one input record.
- Five fields.
- Non-negative numeric values for the three load averages.
- The expected numeric slash-separated fourth field.
- An integer fifth field.

Valid zero load averages are accepted.

No load threshold is evaluated.

## Structured Record Semantics

Both collectors use the existing `log_result` function and record format:

```text
timestamp=<UTC timestamp> check=<check name> status=<status> severity=<severity> message="<message>"
```

Successful memory collection uses:

```text
check=memory_usage status=PASS severity=INFO
```

Successful load collection uses:

```text
check=system_load status=PASS severity=INFO
```

For these checks, `PASS` means collection and input validation succeeded. It does not mean resource usage is below an operational threshold.

Missing, unreadable or invalid input produces:

```text
status=FAIL severity=CRITICAL
```

The affected collector returns exit code `1`.

## Execution Behaviour

The existing host checks are contained within `main()`.

Direct execution runs the normal monitoring workflow.

Sourcing the script defines its functions without executing the host checks. This allows each collector to be tested with a supplied input-file path.

The script must be sourced using Bash for these tests.

The main workflow explicitly supplies the runtime input paths:

```bash
check_system_load /proc/loadavg || true
check_memory_usage /proc/meminfo || true
```

This allows the remaining host checks to run after a resource collection failure has been reported.

The collectors retain their default input paths for isolated calls that omit an argument.

The overall script exit status is not an aggregate health result. Inspect the structured records for individual check outcomes.

## Local Validation

Validation was performed on the Mac using Bash.

The following checks completed without errors:

```bash
bash -n provision/monitoring/health-check.sh
git diff --check
```

Staged changes also passed:

```bash
git diff --cached --check
```

Synthetic resource inputs and test logs were placed in temporary directories.

The isolated tests did not modify the live `/proc` files or use the production monitoring log.

## Successful Synthetic Collection

Memory fixture:

```text
MemTotal: 1000 kB
MemAvailable: 750 kB
```

Load fixture:

```text
0.10 0.20 0.30 1/100 1234
```

Observed records:

```text
timestamp=2026-09-06T17:53:44Z check=memory_usage status=PASS severity=INFO message="Memory sample collected: total_kib=1000 available_kib=750; collection only, no usage threshold evaluated"
timestamp=2026-09-06T17:53:44Z check=system_load status=PASS severity=INFO message="System load sample collected: load_1m=0.10 load_5m=0.20 load_15m=0.30; load averages, not CPU percentages; no load threshold evaluated"
```

The test checked both expected structured messages and reported:

```text
PASS: Both resource samples were collected and logged correctly.
```

## Controlled Collection Failures

The following isolated failure cases were executed:

| Test | Input | Observed result |
| --- | --- | --- |
| Missing memory input | Nonexistent fixture path | Exit `1`, `memory_usage` FAIL/CRITICAL |
| Invalid memory values | Total `1000`, available `1500` | Exit `1`, `memory_usage` FAIL/CRITICAL |
| Missing load input | Nonexistent fixture path | Exit `1`, `system_load` FAIL/CRITICAL |
| Invalid load values | `invalid 0.20 0.30 1/100 1234` | Exit `1`, `system_load` FAIL/CRITICAL |

Observed memory failure message:

```text
Memory sample unavailable: input is unreadable, missing required fields or invalid
```

Observed load failure message:

```text
System load sample unavailable: input is unreadable, missing required fields or invalid
```

Missing-file tests also produced an `awk` diagnostic identifying the unavailable fixture.

These tests demonstrate rejection of the listed inputs. They do not claim exhaustive coverage of every validation branch.

## Successful Collection After Failures

After the failure tests, valid zero-value fixtures were supplied.

Memory fixture:

```text
MemTotal: 1000 kB
MemAvailable: 0 kB
```

Load fixture:

```text
0.00 0.00 0.00 1/100 1234
```

Observed records:

```text
timestamp=2026-09-06T18:00:19Z check=memory_usage status=PASS severity=INFO message="Memory sample collected: total_kib=1000 available_kib=0; collection only, no usage threshold evaluated"
timestamp=2026-09-06T18:00:19Z check=system_load status=PASS severity=INFO message="System load sample collected: load_1m=0.00 load_5m=0.00 load_15m=0.00; load averages, not CPU percentages; no load threshold evaluated"
```

The test checked both expected messages and reported:

```text
PASS: Valid zero-value recovery succeeded.
```

This confirms successful collection with valid input after the controlled failure cases.

## Initial Implementation Commit

The implementation and initial evidence were committed as:

```text
1b5394f feat: complete SEN-028 structured resource monitoring logs
```

## Initial Pull-Request CI Failure

The initial pull-request workflow was:

```text
SentinelOps CI #13
Pull request #43
```

Results:

```text
Shell validation: FAIL
Secret safety: PASS
Container and application validation: PASS
```

Bash syntax validation passed.

The failing step was:

```text
Run ShellCheck
```

ShellCheck reported:

```text
SC2120: Function references arguments, but none are ever passed.
SC2119: Use function "$@" if the function's $1 should mean the script's $1.
```

Both resource collectors accepted an optional input-file argument, but the calls inside `main()` supplied no arguments.

The isolated fixture calls were executed outside the script and therefore did not establish argument usage for this static analysis.

The ShellCheck step exited with code `1`.

This was a real CI finding, separate from the deliberately controlled resource-input failure tests.

## ShellCheck Correction

The runtime calls were changed to explicitly provide the intended Linux input paths:

```bash
check_system_load /proc/loadavg || true
check_memory_usage /proc/meminfo || true
```

The explicit paths match the collectors' existing defaults.

This resolves the argument-usage findings while preserving the ability to supply synthetic fixture paths during isolated tests.

No ShellCheck warning suppression or workflow relaxation was introduced.

The correction was committed as:

```text
30423cd fix: pass explicit resource paths for SEN-028 ShellCheck
```

## Pull-Request CI Recovery

After the correction was pushed, GitHub Actions executed:

```text
SentinelOps CI #14
Pull request #43
```

Results:

```text
Shell validation: PASS
Secret safety: PASS
Container and application validation: PASS
Workflow status: SUCCESS
```

The recovery confirms that the corrected script passed the existing Bash syntax and ShellCheck validation.

The existing secret-safety and container/application jobs also passed.

## CI Run Sequence

| Run | Shell validation | Secret safety | Container and application validation | Explanation |
| --- | --- | --- | --- | --- |
| #13 | FAIL | PASS | PASS | ShellCheck identified implicit collector argument usage |
| #14 | PASS | PASS | PASS | Explicit runtime input paths resolved the findings |

The CI workflow continues to contain the same three jobs.

The synthetic collector tests were executed manually in Bash. They were not added to CI by this change.

## Deployment Validation

The updated script was copied from the Mac to the primary Ubuntu VM and syntax-checked before installation.

A copy of the previous deployed script was retained for rollback during validation.

The updated script was installed at:

```text
/home/emir/sentinelops-monitoring/health-check.sh
```

During initial deployment, script ownership and permissions were verified as:

```text
emir:emir 755 /home/emir/sentinelops-monitoring/health-check.sh
```

The deployed script passed:

```bash
bash -n /home/emir/sentinelops-monitoring/health-check.sh
```

After CI recovery, the corrected script was copied to the VM again.

The staged copy was syntax-checked and installed using:

```bash
bash -n /tmp/health-check-sen028.sh &&
sudo install -o emir -g emir -m 0755 \
  /tmp/health-check-sen028.sh \
  /home/emir/sentinelops-monitoring/health-check.sh &&
bash /home/emir/sentinelops-monitoring/health-check.sh
```

The installation and subsequent full monitoring run completed successfully.

## Ubuntu Runtime Validation

Validation host:

```text
sentinelops-ubuntu
Ubuntu Server 24.04.4 LTS
aarch64
```

The initial full runtime validation completed at:

```text
2026-09-06T18:07:46Z
```

Initial resource records were:

```text
timestamp=2026-09-06T18:07:46Z check=system_load status=PASS severity=INFO message="System load sample collected: load_1m=0.05 load_5m=0.03 load_15m=0.01; load averages, not CPU percentages; no load threshold evaluated"
timestamp=2026-09-06T18:07:46Z check=memory_usage status=PASS severity=INFO message="Memory sample collected: total_kib=3027704 available_kib=2720740; collection only, no usage threshold evaluated"
```

After installing the ShellCheck-corrected script, the final full runtime validation completed at:

```text
2026-09-06T23:19:39Z
```

Final resource records were:

```text
timestamp=2026-09-06T23:19:39Z check=system_load status=PASS severity=INFO message="System load sample collected: load_1m=0.04 load_5m=0.07 load_15m=0.03; load averages, not CPU percentages; no load threshold evaluated"
timestamp=2026-09-06T23:19:39Z check=memory_usage status=PASS severity=INFO message="Memory sample collected: total_kib=3027704 available_kib=2718420; collection only, no usage threshold evaluated"
```

The records were inspected using:

```bash
grep -E 'check=(memory_usage|system_load)' \
  /var/log/sentinelops/health-check.log | tail -n 2
```

These values are evidence from the recorded executions, not fixed expected values for subsequent runs.

## Operational Regression Results

The final full runtime execution reported:

| Check | Observed result |
| --- | --- |
| Root filesystem usage | 48%, below warning threshold |
| Backup freshness | Newest backup age 5 hours, within the 36-hour threshold |
| Failed systemd units | 0 |
| Docker service | Active |
| Nginx service | Active |
| SSH socket | Active |
| Compose application | Running |
| Application backend binding | `127.0.0.1:8000` |
| Application health endpoint | HTTP 200 |
| Host Nginx request | HTTP 200 |
| UFW | Active |
| UFW incoming policy | Deny |
| Allowed inbound services | TCP 22 and TCP 80 |

The newest backup reported by that execution was:

```text
sentinelops-backup-20260906T173305Z.tar.gz
```

This provides operational regression evidence alongside the new resource records.

## Log Permissions

After the initial runtime validation, ownership and permissions were verified as:

```text
root:emir 750 /var/log/sentinelops
emir:emir 640 /var/log/sentinelops/health-check.log
```

The subsequent correction changed the collector call arguments and reinstalled the script. It did not change log permissions.

The final runtime execution also wrote both resource records successfully.

## Validated Results

- [x] Valid memory samples produce structured records.
- [x] Valid load samples produce structured records.
- [x] Memory units and load averaging periods are explicit.
- [x] Missing memory input is rejected.
- [x] Available memory exceeding total memory is rejected.
- [x] Missing load input is rejected.
- [x] Malformed load input is rejected.
- [x] Tested collection failures return exit code `1`.
- [x] Tested collection failures produce FAIL/CRITICAL records.
- [x] Valid zero-value samples are accepted after the failure cases.
- [x] Local Bash syntax validation passes.
- [x] Working-tree and staged whitespace validation pass.
- [x] Initial ShellCheck findings are captured.
- [x] Explicit runtime paths resolve the ShellCheck findings.
- [x] Recovery CI run #14 passes all three jobs.
- [x] Corrected script is installed on the primary Ubuntu VM.
- [x] Final runtime memory and load records are present.
- [x] Final full monitoring execution reports the observed operational checks healthy.
- [x] Existing log ownership and permissions are preserved.

## Result and Boundaries

SEN-028 provides implementation and validation evidence for the resource-logging gap identified against SC-14.

Memory and load collection results now reach the structured runtime log.

Successful collection does not evaluate memory or load thresholds.

The synthetic tests cover the recorded valid, missing, invalid and zero-value inputs. They do not establish exhaustive coverage of every parser validation branch.

The full script retains its existing overall exit-status behaviour. Individual structured records remain necessary when assessing monitoring outcomes.

CI run #14 proves recovery for the implementation correction. Any subsequent documentation commit requires its own pull-request CI result before merge.

Merge verification and default-branch CI remain separate completion steps.