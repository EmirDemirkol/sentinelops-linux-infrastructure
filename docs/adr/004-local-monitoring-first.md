# ADR-004: Use Local-First Monitoring

## Status

Accepted

## Context

SentinelOps must demonstrate monitoring of services, application health, resources, backup freshness and failure conditions.

The MVP is a single Ubuntu Server VM running in a private local lab. The project also requires manual understanding of the underlying Linux checks before introducing a larger observability platform.

A local monitoring workflow is sufficient to demonstrate collection, structured records, operational diagnosis, scheduled execution and failure detection.

## Decision

Use repository-managed Bash health checks, structured local monitoring logs and systemd scheduling for the MVP.

The monitoring workflow records:

- service health;
- Compose application state;
- application endpoint health;
- host Nginx endpoint health;
- filesystem usage;
- backup freshness;
- memory samples;
- system-load samples.

The scheduled monitoring service runs the protected root-owned health-check script. The timer executes the service every minute after boot.

The dedicated log is:

```text
/var/log/sentinelops/health-check.log
```

## Alternatives Considered

### Prometheus and Grafana

These tools would provide a more advanced monitoring platform, but they are not required to prove the underlying checks and would add complexity before the local monitoring model is understood.

### Cloud monitoring

Cloud monitoring is outside the local single-server MVP scope and would require a public or cloud-hosted environment.

### External alerting

External alerting is useful future work, but the MVP first needs reliable local records and measured failure detection.

## Security and Operational Consequences

Positive consequences:

- checks are visible and understandable;
- monitoring works without external services;
- systemd provides repeatable scheduling;
- structured records support diagnosis and evidence;
- the monitoring workflow can be tested with controlled local failures;
- the approach is reproducible on a clean Ubuntu host.

Negative consequences:

- monitoring cannot run while the VM is powered off;
- the MVP does not provide external alert delivery;
- log rotation is outside this decision;
- the service exit status does not aggregate every individual health result;
- automatic remediation is not provided.

## Current Implementation

The repository contains:

```text
provision/monitoring/health-check.sh
provision/systemd/sentinelops-monitoring.service
provision/systemd/sentinelops-monitoring.timer
```

SEN-028 added structured memory and system-load collection. SEN-029 added scheduled execution and measured failure detection within the required monitoring interval.

## Validation

The decision is validated by:

- Bash syntax validation;
- systemd unit validation;
- scheduled execution;
- reboot persistence;
- structured log inspection;
- repeated provisioning;
- controlled Nginx failure and recovery;
- measured detection-time evidence;
- service and timer status checks.
