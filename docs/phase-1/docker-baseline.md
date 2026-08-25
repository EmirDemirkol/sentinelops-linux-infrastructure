# SentinelOps Docker Baseline

## Purpose

This document records the installation, configuration, security review, and verification of Docker Engine on the SentinelOps Ubuntu Server VM.

The Docker baseline builds on:

- SEN-005 secure SSH administration
- SEN-006 host firewall configuration
- SEN-007 host-level Nginx deployment

The objective is to introduce a container runtime for future SentinelOps application services while preserving the existing host-level Nginx architecture, secure SSH administration, and restricted network exposure.

No production application is deployed during SEN-008.

---

## Initial State

Before SEN-008:

- Ubuntu Server 24.04.4 LTS was running in UTM
- the VM architecture was `aarch64`
- the VM used IPv4 address `192.168.64.2`
- secure SSH administration was operational
- SSH public-key authentication was enabled
- password SSH authentication was disabled
- direct root SSH login was disabled
- the `emir` administrator account retained sudo access
- UFW was active
- default incoming traffic was denied
- default outgoing traffic was allowed
- TCP port 22 was permitted for SSH
- TCP port 80 was permitted for Nginx HTTP
- TCP port 443 remained blocked
- Nginx was installed directly on the Ubuntu host
- Nginx was active and enabled
- no application backend was deployed
- no container runtime was installed
- no container application port was exposed
- UTM console access remained available as a recovery path

---

## Docker Baseline Verification Before Installation

Docker availability was checked before installation with:

```bash
docker --version
```

Result:

```text
Command 'docker' not found
```

Docker Compose availability was also checked:

```bash
docker compose version
```

Result:

```text
Command 'docker' not found
```

The Docker systemd service was checked:

```bash
systemctl status docker
```

Result:

```text
Unit docker.service could not be found.
```

This confirmed that Docker Engine was not installed before SEN-008.

---

## Firewall State Before Installation

The existing firewall configuration was reviewed with:

```bash
sudo ufw status verbose
```

The firewall was active with:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing)
```

The explicit inbound rules were:

```text
22/tcp                     ALLOW IN    Anywhere
80/tcp (Nginx HTTP)        ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
80/tcp (Nginx HTTP (v6))   ALLOW IN    Anywhere (v6)
```

This confirmed that only SSH and HTTP were intentionally exposed before Docker installation.

---

## Listening Socket Review Before Installation

Listening sockets were reviewed using:

```bash
ss -tulpn
```

Relevant TCP listeners included:

```text
0.0.0.0:22
0.0.0.0:80
[::]:22
[::]:80
```

TCP port 22 was provided by SSH.

TCP port 80 was provided by the host-level Nginx service.

No container-related or application-specific public listener existed.

---

## Docker Installation Method

Docker Engine was installed using Docker's official Ubuntu software repository rather than the Ubuntu `docker.io` package.

The repository method provides the Docker Engine packages maintained through Docker's official package channel.

The VM architecture was confirmed as ARM64 and the repository configuration used:

```text
Suite: noble
Architecture: arm64
Component: stable
```

---

## Repository Prerequisites

The package index was refreshed:

```bash
sudo apt update
```

Required repository packages were installed:

```bash
sudo apt install ca-certificates curl -y
```

The package operation completed successfully.

---

## Docker Repository Signing Key

The APT keyring directory was prepared with:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
```

Docker's signing key was downloaded:

```bash
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
```

Read permissions were applied:

```bash
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

The signing key was therefore stored at:

```text
/etc/apt/keyrings/docker.asc
```

---

## Docker APT Repository

The Docker package repository was configured in:

```text
/etc/apt/sources.list.d/docker.sources
```

The repository configuration resolved to:

```text
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: arm64
Signed-By: /etc/apt/keyrings/docker.asc
```

The package index was refreshed again:

```bash
sudo apt update
```

APT successfully retrieved Docker repository metadata:

```text
https://download.docker.com/linux/ubuntu noble InRelease
https://download.docker.com/linux/ubuntu noble/stable arm64 Packages
```

This confirmed that the VM could successfully use Docker's official ARM64 Ubuntu repository.

---

## Docker Engine Installation

The required Docker components were installed with:

```bash
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

Installed components included:

- Docker Engine
- Docker CLI
- containerd
- Docker Buildx
- Docker Compose plugin
- Docker rootless extras

The installation completed successfully.

Systemd service links were created for:

```text
docker.service
docker.socket
containerd.service
```

---

## Docker Version Verification

Docker Engine was verified with:

```bash
docker --version
```

Result:

```text
Docker version 29.7.2, build a7dc4a0
```

Docker Compose was verified with:

```bash
docker compose version
```

Result:

```text
Docker Compose version v5.5.0
```

This confirms that both Docker Engine and Docker Compose functionality are available.

---

## Docker Service State

The Docker daemon was inspected with:

```bash
systemctl status docker
```

The service reported:

```text
Loaded: loaded
enabled
Active: active (running)
```

This confirms:

- Docker is installed as a systemd service
- Docker is enabled for automatic startup
- the Docker daemon is currently running
- the Docker API socket is available locally

---

## Docker Runtime Verification

A basic Docker container was executed using:

```bash
sudo docker run hello-world
```

Because the image was not already present locally, Docker automatically pulled:

```text
hello-world:latest
```

The container executed successfully and returned:

```text
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

This verified the complete Docker execution path:

1. the Docker CLI contacted the Docker daemon
2. the daemon retrieved the container image
3. Docker created a container
4. the container executed successfully
5. output was returned to the terminal

---

## Docker Socket Permissions

The Docker Unix socket was reviewed using:

```bash
ls -l /var/run/docker.sock
```

Result:

```text
srw-rw---- 1 root docker ... /var/run/docker.sock
```

This confirms that:

- the socket is owned by `root`
- the socket group is `docker`
- root can access the Docker API
- members of the `docker` group can access the Docker API
- other users do not have direct socket access

---

## Administrator Access Before Docker Group Membership

The `emir` account initially attempted:

```bash
docker ps
```

Result:

```text
permission denied while trying to connect to the Docker API at unix:///var/run/docker.sock
```

The account's group membership was reviewed with:

```bash
id
```

At this stage, `docker` was not listed among the account's groups.

This demonstrated that Docker administration was not automatically granted to the existing administrator account.

---

## Docker Administration Decision

The `emir` administrator account was intentionally granted Docker administration capability.

This was configured using:

```bash
sudo usermod -aG docker emir
```

The existing SSH session was then terminated:

```bash
exit
```

A new SSH session was established from the Mac:

```bash
ssh emir@192.168.64.2
```

A new login was required so that the updated supplementary group membership would be applied.

---

## Docker Group Security Consideration

Membership in the `docker` group provides highly privileged access to the Docker daemon.

A Docker administrator can create containers with access to host resources and can therefore obtain capabilities that are effectively equivalent to root-level control of the server.

For this reason, Docker group membership was treated as an intentional administrative privilege rather than ordinary user access.

The `docker` group should not be assigned casually to untrusted or non-administrative accounts.

---

## Administrator Docker Access Verification

After reconnecting, group membership was checked:

```bash
id
```

The resulting group list included:

```text
988(docker)
```

Docker was then tested without `sudo`:

```bash
docker ps
```

The command executed successfully.

A second test container was executed without `sudo`:

```bash
docker run hello-world
```

Result:

```text
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

This confirmed that the `emir` administrator account can intentionally manage Docker through the Docker Unix socket.

---

## Docker Network Baseline

Docker networks were reviewed with:

```bash
docker network ls
```

The default networks were present:

```text
NETWORK ID     NAME      DRIVER    SCOPE
...            bridge    bridge    local
...            host      host      local
...            none      null      local
```

No project-specific Docker network had been created.

This is the expected baseline immediately after Docker Engine installation.

---

## Test Container Review

Container state was inspected with:

```bash
docker ps -a
```

The temporary `hello-world` containers were present in the exited state.

Example state:

```text
IMAGE         COMMAND     STATUS
hello-world   "/hello"    Exited (0)
```

None of the test containers had a published host port.

Therefore, the runtime verification introduced no application network exposure.

---

## Listening Socket Review After Docker Installation

Host listening sockets were reviewed again with:

```bash
ss -tulpn
```

Relevant public TCP listeners remained:

```text
0.0.0.0:22
0.0.0.0:80
[::]:22
[::]:80
```

No new public application listener appeared after Docker installation.

This confirms that installing Docker itself did not expose a container application port.

---

## Docker Port Publishing Security Consideration

Docker can modify host packet-filtering and forwarding behaviour when container ports are explicitly published.

For this reason, future SentinelOps containers must not assume that UFW alone guarantees application-port isolation.

The intended architecture is to avoid directly publishing backend services to unrestricted host interfaces unless explicitly required.

The preferred application path remains:

```text
Client
   |
   v
UFW
   |
   v
Host Nginx
   |
   v
Private application endpoint
   |
   v
Docker application
```

Container port publishing must therefore be treated as a deliberate security-sensitive configuration decision.

---

## Firewall State After Docker Installation

UFW was reviewed after Docker installation:

```bash
sudo ufw status verbose
```

Result:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
```

The inbound allow rules remained:

```text
22/tcp                     ALLOW IN    Anywhere
80/tcp (Nginx HTTP)        ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
80/tcp (Nginx HTTP (v6))   ALLOW IN    Anywhere (v6)
```

No Docker-specific application port was added to UFW.

No HTTPS rule was added.

---

## Routed Firewall State Observation

Before Docker installation, previous SentinelOps firewall verification had reported the routed state as:

```text
disabled (routed)
```

After Docker installation, UFW reported:

```text
deny (routed)
```

This change was recorded as part of the Docker baseline.

No manual UFW routed allow rule was introduced during SEN-008.

Future container networking work should continue to review the interaction between Docker networking, forwarding, packet filtering, and UFW before application ports are published.

---

## Nginx Preservation

Nginx remained installed directly on the Ubuntu host.

Its service state was verified with:

```bash
systemctl status nginx
```

Result:

```text
Loaded: loaded
enabled
Active: active (running)
```

Docker installation therefore did not disrupt the host-level Nginx service.

---

## Docker Service Enablement

Automatic Docker startup was explicitly checked using:

```bash
systemctl is-enabled docker
```

Result:

```text
enabled
```

This confirmed that Docker should automatically start following a VM reboot.

---

## Reboot Persistence Test

The complete infrastructure baseline was tested across a reboot.

From the SSH session:

```bash
sudo reboot
```

The SSH connection terminated as expected.

An immediate SSH reconnect attempt returned:

```text
Operation timed out
```

because the Ubuntu VM had not yet completed startup.

After startup completed, the Mac successfully reconnected:

```bash
ssh emir@192.168.64.2
```

This confirmed SSH availability after reboot.

---

## Docker State After Reboot

Docker was checked after reboot with:

```bash
systemctl status docker
```

The service reported:

```text
Loaded: loaded
enabled
Active: active (running)
```

This confirms that Docker automatically started during system boot.

---

## Docker Administrative Access After Reboot

The administrator tested Docker again after reboot using:

```bash
docker ps
```

The command executed successfully without `sudo`.

This confirms that:

- Docker remained operational
- `emir` retained effective Docker group membership
- Docker administrative access persisted across reboot

---

## Nginx State After Reboot

Nginx was checked after reboot:

```bash
systemctl status nginx
```

Result:

```text
Loaded: loaded
enabled
Active: active (running)
```

This confirms that the existing host-level web service remained available alongside Docker.

---

## Firewall State After Reboot

UFW was checked again after reboot:

```bash
sudo ufw status verbose
```

Result:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
```

The existing inbound rules remained:

```text
22/tcp                     ALLOW IN    Anywhere
80/tcp (Nginx HTTP)        ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
80/tcp (Nginx HTTP (v6))   ALLOW IN    Anywhere (v6)
```

This confirms that:

- UFW remained active
- SSH remained permitted
- HTTP remained permitted
- no Docker application port appeared
- no HTTPS rule appeared

---

## Listening Sockets After Reboot

Listening sockets were inspected after reboot:

```bash
ss -tulpn
```

Relevant externally bound TCP listeners remained:

```text
0.0.0.0:22
0.0.0.0:80
[::]:22
[::]:80
```

No application container listener was present.

This confirms that the reboot did not introduce unexpected Docker-related host exposure.

---

## External HTTP Verification After Reboot

After exiting the SSH session, the Mac host tested the existing Nginx service:

```bash
curl -I http://192.168.64.2
```

Result:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Content-Type: text/html
Content-Length: 615
Connection: keep-alive
```

This confirms that the existing client path remained operational after Docker installation and reboot:

```text
Mac Host
   |
   | TCP 80
   v
UFW
   |
   v
Host Nginx
```

Docker did not interfere with the existing HTTP baseline.

---

## Temporary Container Cleanup

The temporary runtime-validation containers were removed after testing.

The cleanup command was:

```bash
docker container prune -f
```

Docker removed the exited `hello-world` containers and reclaimed their container-layer space.

Container state was then checked:

```bash
docker ps -a
```

Only the table headings remained, with no containers listed.

This left the Docker runtime in a clean baseline state with no test containers remaining.

The downloaded `hello-world` image was not required to be removed because it does not expose a service or consume a running container resource.

---

## Final Docker Baseline

At completion of SEN-008:

- Docker Engine is installed
- Docker CLI is installed
- Docker Compose is installed
- Docker Buildx is installed
- containerd is installed
- Docker uses the official Docker Ubuntu repository
- the repository targets Ubuntu Noble ARM64
- Docker version `29.7.2` is installed
- Docker Compose version `v5.5.0` is available
- Docker daemon is active
- Docker daemon is enabled at startup
- Docker successfully pulled and executed test containers
- Docker's default networks exist
- no custom Docker network exists
- no running container exists
- temporary test containers were removed
- no container port is published
- no application backend is deployed
- `emir` is intentionally a member of the `docker` group
- non-sudo Docker administration works
- Docker socket permissions were reviewed
- Docker group privilege implications were documented
- UFW remains active
- SSH remains allowed
- HTTP remains allowed
- HTTPS remains blocked
- no application port is exposed
- Nginx remains active on the host
- SSH remains operational
- Docker survives reboot
- Nginx survives reboot
- UFW survives reboot
- external HTTP survives reboot
- UTM console recovery access remains available

---

## Verification Summary

The following checks were successfully completed:

- confirmed Docker was absent before installation
- confirmed Docker Compose was absent before installation
- confirmed `docker.service` did not exist
- reviewed the initial UFW configuration
- reviewed listening sockets before installation
- installed repository prerequisites
- installed Docker's repository signing key
- configured Docker's official Ubuntu repository
- verified Noble ARM64 Docker packages were available
- installed Docker Engine
- installed Docker CLI
- installed containerd
- installed Docker Buildx
- installed Docker Compose
- verified Docker version
- verified Docker Compose version
- confirmed `docker.service` is active
- confirmed `docker.service` is enabled
- ran `hello-world` successfully using sudo
- reviewed `/var/run/docker.sock` permissions
- confirmed ordinary Docker access initially failed for `emir`
- reviewed account group membership
- deliberately added `emir` to the `docker` group
- established a fresh SSH login
- verified Docker group membership
- verified `docker ps` works without sudo
- verified `docker run hello-world` works without sudo
- reviewed Docker's default networks
- reviewed test-container state
- confirmed test containers published no ports
- reviewed host listening sockets
- confirmed no application port became publicly bound
- verified UFW remained active
- verified only SSH and HTTP remained allowed inbound
- recorded the observed routed-policy state
- confirmed Nginx remained active
- confirmed Docker is enabled at boot
- rebooted the VM
- restored SSH connectivity after startup
- confirmed Docker automatically restarted
- confirmed non-sudo Docker administration survived reboot
- confirmed Nginx automatically restarted
- confirmed UFW persisted
- confirmed no new listener appeared after reboot
- confirmed Nginx still returned `HTTP/1.1 200 OK` from the Mac
- removed temporary test containers
- confirmed the final container list was empty

---

## Out of Scope

SEN-008 did not introduce:

- production application containers
- project Dockerfiles
- project Docker Compose stacks
- Django
- Gunicorn
- PostgreSQL
- Redis
- reverse proxying Nginx to a container
- container application port publishing
- HTTPS
- TLS certificates
- Certbot
- monitoring
- backups
- container image CI/CD
- private container registries
- Docker Swarm
- Kubernetes
- Terraform
- cloud infrastructure
- public Internet deployment

These capabilities remain reserved for later SentinelOps issues.

---

## Completion State

The SentinelOps Ubuntu Server VM now has a functioning Docker container-runtime baseline.

Docker Engine and Docker Compose are installed from Docker's official Ubuntu repository and operate successfully on the VM's ARM64 architecture.

The `emir` administrator account has intentionally configured Docker administrative access, with the associated high-privilege security implications documented.

Docker, Nginx, UFW, SSH, and external HTTP connectivity remain operational across reboot.

No application container, backend service, or container port is currently exposed.

The existing host-level Nginx and default-deny firewall architecture remains the basis for future application deployment.

This establishes the container-runtime foundation required for later SentinelOps application packaging and deployment.