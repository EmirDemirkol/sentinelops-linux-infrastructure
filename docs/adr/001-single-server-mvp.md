# ADR-002: Run Nginx on the Ubuntu Host

## Status

Accepted

## Context

The SentinelOps application will run inside Docker.

The project requires a reverse proxy to provide a controlled application entry point and demonstrate HTTP service configuration.

Nginx could also run inside Docker, but doing so would move another major infrastructure component into the container layer.

## Decision

Nginx will run directly on the Ubuntu Server host.

The application will run inside Docker.

Nginx will proxy approved application traffic to the internal application service.

## Rationale

Running Nginx on the host allows SentinelOps to demonstrate both:

- native Linux service administration
- containerised application operations

It also creates a clear architectural boundary:

```text
Client
  |
  v
Host Nginx
  |
  v
Docker Application
```

This keeps external traffic handling separate from the application runtime.

## Consequences

### Positive

- demonstrates systemd-managed Linux services
- demonstrates Nginx configuration directly
- provides a clear reverse-proxy boundary
- simplifies external application exposure
- prevents the application container from becoming the primary network entry point

### Negative

- Nginx and Docker configuration must be managed separately
- host configuration becomes part of the deployment process
- Nginx cannot be recreated solely through Docker Compose

These trade-offs are acceptable because host-level Linux administration is a core SentinelOps learning objective.

## Future Review

A fully containerised reverse-proxy architecture may be evaluated later if the project has a technical reason to require it.

---

# ADR-003: Keep the Application Port Private

## Status

Accepted

## Context

The SentinelOps application needs an internal network port so that Nginx can communicate with it.

Publishing the application port directly to the wider virtual network would create a second application entry point and allow clients to bypass Nginx.

## Decision

The application service will remain internal to the Ubuntu VM.

Where practical, the application will bind to a local interface such as:

```text
127.0.0.1:8000
```

The exact application port may change during implementation.

Regardless of the final port number, external application traffic must flow through Nginx.

## Rationale

Keeping the application port private:

- reduces network exposure
- prevents clients from bypassing Nginx
- provides one controlled application entry point
- makes firewall behaviour easier to understand
- simplifies troubleshooting
- follows minimum-exposure principles

## Consequences

### Positive

- smaller attack surface
- clearer request path
- stronger reverse-proxy boundary
- easier network validation

### Negative

- direct testing of the application from outside the VM is intentionally prevented
- application troubleshooting may require commands executed from inside the Ubuntu VM

These consequences are desirable for the SentinelOps architecture.

## Verification Requirement

Later implementation must prove that:

- Nginx can reach the application
- the application works through Nginx
- the MacBook cannot directly reach the application port

---

# ADR-004: Use Local Monitoring Before Advanced Monitoring Platforms

## Status

Accepted

## Context

SentinelOps needs to detect service and resource failures.

Tools such as Prometheus, Node Exporter, Grafana, and Alertmanager could provide a larger monitoring platform.

However, introducing those systems immediately would hide some of the fundamental Linux checks that the project is intended to teach.

## Decision

The MVP will begin with simple local monitoring.

Initial checks will include:

- Nginx service status
- Docker container state
- application health endpoint
- disk usage
- memory usage
- CPU or system load
- backup freshness

Results will be written to SentinelOps operational logs.

## Rationale

Local monitoring allows the project to demonstrate:

- how Linux health information is obtained
- how service state is checked
- how HTTP availability is tested
- how thresholds work
- how failures are logged
- how scheduled monitoring works

The underlying monitoring behaviour should be understood before adding dashboards or external monitoring systems.

## Consequences

### Positive

- simple architecture
- transparent failure detection
- easier troubleshooting
- lower resource usage
- stronger understanding of Linux monitoring fundamentals

### Negative

- no graphical dashboards
- no centralised metrics platform
- limited historical analysis
- monitoring resides on the same server as the application

These limitations are acceptable for the MVP.

## Future Review

After the MVP is complete, SentinelOps may add:

- Node Exporter
- Prometheus
- Grafana
- Alertmanager
- external notifications
- separate monitoring infrastructure

---

# ADR-005: Use Local Backup Storage for the MVP

## Status

Accepted

## Context

SentinelOps must demonstrate backup creation, retention, integrity verification, restoration, and recovery testing.

A production environment would normally protect important backups using storage separate from the server being backed up.

The MVP is a local educational lab and does not need to demonstrate full disaster recovery against loss of the physical MacBook.

## Decision

Initial SentinelOps backups will be stored within the local lab environment.

The MVP will focus on proving:

- correct backup contents
- timestamped archives
- backup manifests
- integrity checksums
- retention
- successful restoration
- recovery documentation

## Rationale

Local backup storage allows the backup and restoration workflow to be developed and tested without introducing cloud storage or additional infrastructure.

This keeps the MVP focused on whether the backup is actually usable.

## Consequences

### Positive

- simpler implementation
- no cloud dependency
- no cloud cost
- straightforward restoration testing
- keeps focus on backup correctness

### Negative

- backups do not protect against complete VM loss
- backups do not protect against complete MacBook loss
- local storage creates a shared failure domain

These limitations must be stated clearly and must not be presented as production-grade disaster recovery.

## Future Review

After the local recovery process is proven, possible improvements include:

- backup storage outside the VM
- backup copies on the MacBook host
- remote storage
- encrypted cloud object storage
- off-site backup retention

Remote backup storage is a post-MVP enhancement.