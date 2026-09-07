# ADR-005: Use Local Backup Storage for the MVP

## Status

Accepted

## Context

SentinelOps must demonstrate backup creation, manifest generation, checksum validation, retention, restoration and recovery.

The MVP runs on one local Ubuntu Server VM and uses synthetic application data. The primary objective is to prove that the backup lifecycle is understood and repeatable before adding remote storage or cloud infrastructure.

## Decision

Store SentinelOps backup archives locally on the Ubuntu Server VM under:

```text
/home/emir/backups/sentinelops
```

The repository-managed backup workflow creates timestamped archives, manifests and SHA-256 checksums. The workflow applies the documented retention policy and records backup results.

Restoration is performed from a verified local archive to a safe location before ownership, permissions and service behaviour are checked.

## Alternatives Considered

### Remote object storage

Remote storage would improve durability, but it would introduce cloud credentials, network dependencies and a larger security boundary before the local backup process had been demonstrated.

### Network-mounted backup storage

A network share would add another service and failure dependency to the single-server MVP.

### Backups inside the application container

Container-local storage would make backup persistence and host-level recovery less clear. It would also couple backup lifecycle behaviour to the application container.

## Security and Operational Consequences

Positive consequences:

- the backup workflow is understandable and easy to inspect;
- no cloud credentials are required;
- manifests and checksums can be validated locally;
- restoration can be tested using synthetic data;
- the MVP remains reproducible without external infrastructure.

Negative consequences:

- local storage does not protect against loss of the VM or host;
- the MVP does not provide off-host disaster recovery;
- remote replication and alerting remain future work;
- disk capacity must be monitored;
- backup permissions must prevent unauthorised access.

## Current Implementation

The repository contains:

```text
provision/backup/backup-sentinelops.sh
provision/systemd/sentinelops-backup.service
provision/systemd/sentinelops-backup.timer
```

The provisioner deploys the backup workflow, enables the timer and validates backup creation, integrity and restoration behaviour.

## Validation

The decision is validated by:

- timestamped archive creation;
- manifest generation;
- SHA-256 checksum generation and verification;
- retention testing;
- controlled restoration using synthetic data;
- ownership and permission checks;
- backup timer validation;
- recovery and application health verification.
