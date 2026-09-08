# ADR-003: Keep the Application Port Private

## Status

Accepted

## Context

The SentinelOps application runs in a Docker container, while Nginx provides the approved application-facing entry point.

The application must be reachable by Nginx but must not be directly reachable from the MacBook or an external network path. This prevents clients from bypassing the reverse proxy and keeps the network design easy to inspect.

## Decision

Publish the application container on the Ubuntu host loopback interface only:

```text
127.0.0.1:8000:80
```

The container listens on its internal port 80. The host exposes that service only through `127.0.0.1:8000`.

Nginx proxies requests to the loopback address. External application traffic enters through Nginx on TCP 80.

## Alternatives Considered

### Publish the application on all host interfaces

This would make the backend directly reachable and would bypass Nginx. It would increase exposure and weaken the intended trust boundary.

### Use the Docker bridge address directly

This would make the deployment more dependent on Docker network details and would make the host firewall and external reachability model less obvious.

### Place Nginx in the same application container

This would combine the edge proxy and application concerns and reduce the clarity of host-level service validation.

## Consequences

Positive consequences:

- direct backend exposure is prevented;
- application traffic has one documented entry point;
- UFW only needs to permit the required SSH and HTTP services;
- backend isolation can be tested from the MacBook;
- Nginx remains responsible for the application-facing request path.

Negative consequences:

- Nginx must be available for normal external application access;
- the application cannot be reached externally for direct debugging;
- provisioning must preserve the loopback binding;
- an Nginx failure and an application failure are separate operational conditions.

## Current Implementation

The Compose configuration publishes the application through the host loopback interface.

The Nginx configuration proxies requests to the private backend. The provisioning and validation documentation treats TCP 8000 as a local-only service.

## Validation

The decision is validated by:

- inspecting the Compose port mapping;
- inspecting listening sockets;
- confirming application access through host Nginx;
- confirming the health endpoint response;
- testing that direct external backend access is not available;
- verifying that UFW does not expose TCP 8000.
