# ADR-002: Run Nginx on the Host

## Status

Accepted

## Context

SentinelOps needs a clear application-facing entry point that can receive HTTP traffic, apply the host network boundary and proxy requests to the private application container.

The MVP runs on one Ubuntu Server VM and is intended to demonstrate practical Linux administration, firewall configuration, reverse-proxy behaviour, service monitoring and troubleshooting.

The application must not be directly exposed to the MacBook or to an external network path. Normal application traffic should pass through one controlled reverse-proxy boundary.

## Decision

Run Nginx directly on the Ubuntu Server host.

Nginx listens on the approved HTTP interface and proxies requests to the application published on the host loopback interface at:

```text
127.0.0.1:8000
```

The application container remains behind Nginx. The host firewall allows the required HTTP path and does not expose the application backend port externally.

## Alternatives Considered

### Run Nginx inside Docker

This would keep more application components inside Compose, but would add another container network boundary and make host-level service monitoring and firewall reasoning less direct for the MVP.

### Expose the application container directly

This would remove the reverse-proxy boundary and allow clients to bypass Nginx. It would weaken the intended network design and make the backend port externally reachable.

### Use a cloud load balancer

This would introduce public cloud infrastructure that is outside the single-server local MVP scope.

## Consequences

Positive consequences:

- one clear application-facing entry point;
- simple host-level Nginx validation;
- direct access and error logging;
- straightforward UFW and listening-socket checks;
- clear separation between external HTTP traffic and the container;
- easier demonstration of reverse-proxy behaviour.

Negative consequences:

- Nginx is managed separately from Docker Compose;
- provisioning must validate host Nginx configuration;
- service failures must be considered independently from container failures;
- the MVP does not demonstrate a fully containerised edge layer.

## Current Implementation

The repository contains the host Nginx asset at:

```text
provision/nginx/sentinelops
```

The provisioner installs the configuration, validates it with `nginx -t`, enables Nginx and restarts it only after successful validation.

The monitoring workflow checks both the Nginx service and the host Nginx HTTP endpoint.

## Validation

The decision is validated by:

- Nginx configuration syntax checks;
- successful HTTP access through the host;
- application health returning through Nginx;
- firewall validation;
- listening-port inspection;
- controlled host Nginx failure and recovery testing;
- backend isolation checks.
