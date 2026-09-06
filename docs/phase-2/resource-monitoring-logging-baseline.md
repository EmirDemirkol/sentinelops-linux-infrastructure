# SEN-028 Resource Monitoring Logging Baseline

## Purpose

SEN-028 completes structured logging for host memory and system load samples.

Before this change, the health-check script displayed memory and load information in the terminal through `free -h` and `uptime`, but did not write those samples to the structured monitoring log.

This change addresses the resource-logging gap identified against SC-14.

GitHub issue: #42, SEN-028: Complete structured resource monitoring logs.

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

The main workflow calls:

```bash
check_system_load || true
check_memory_usage || true
```

This allows the remaining host checks to run after a resource collection failure has been reported.

The overall script exit status is not an aggregate health result. Inspect the structured records for individual check outcomes.

## Local Validation

Validation was performed on the Mac using Bash.

The following checks completed without errors:

```bash
bash -n provision/monitoring/health-check.sh
git diff --check
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

## Deployment Validation

The updated script was copied from the Mac to the primary Ubuntu VM and syntax-checked before installation.

A copy of the previous deployed script was retained for rollback during validation.

The updated script was installed at:

```text
/home/emir/sentinelops-monitoring/health-check.sh
```

Deployed script ownership and permissions were verified as:

```text
emir:emir 755 /home/emir/sentinelops-monitoring/health-check.sh
```

The deployed script passed:

```bash
bash -n /home/emir/sentinelops-monitoring/health-check.sh
```

## Ubuntu Runtime Validation

Validation host:

```text
sentinelops-ubuntu
Ubuntu Server 24.04.4 LTS
aarch64
```

The deployed script was executed using:

```bash
bash /home/emir/sentinelops-monitoring/health-check.sh
```

The full monitoring run completed on 2026-09-06.

Resource records written to the runtime log were:

```text
timestamp=2026-09-06T18:07:46Z check=system_load status=PASS severity=INFO message="System load sample collected: load_1m=0.05 load_5m=0.03 load_15m=0.01; load averages, not CPU percentages; no load threshold evaluated"
timestamp=2026-09-06T18:07:46Z check=memory_usage status=PASS severity=INFO message="Memory sample collected: total_kib=3027704 available_kib=2720740; collection only, no usage threshold evaluated"
```

These values are evidence from that execution, not fixed expected values for subsequent runs.

## Operational Regression Results

The same full runtime execution reported:

| Check | Observed result |
| --- | --- |
| Root filesystem usage | 48%, below warning threshold |
| Backup freshness | Newest backup age 0 hours |
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

This provides operational regression evidence alongside the new resource records.

## Log Permissions

After runtime validation, ownership and permissions remained:

```text
root:emir 750 /var/log/sentinelops
emir:emir 640 /var/log/sentinelops/health-check.log
```

The resource records were written successfully using the existing log permissions.

## Result and Boundaries

SEN-028 validation demonstrates:

- Valid memory and load samples reach the structured log.
- The tested missing and invalid inputs produce explicit collection failures.
- Valid zero values are accepted.
- Successful collection resumes with valid input.
- The deployed script collects real Ubuntu resource samples.
- The full monitoring workflow completes with the observed operational checks healthy.
- Existing log ownership and permissions are preserved.

The synthetic checks were executed manually in Bash. This document does not claim that they are automated by the current CI workflow.

Pull-request CI, merge verification and default-branch CI are separate completion steps.