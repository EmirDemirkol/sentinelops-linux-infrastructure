# SentinelOps Application Proxy Baseline

## Purpose

This document records the deployment and verification of the first private containerized application behind the SentinelOps host-level Nginx reverse proxy.

The application-proxy baseline builds on:

- SEN-005 secure SSH administration
- SEN-006 UFW firewall configuration
- SEN-007 host-level Nginx deployment
- SEN-008 Docker Engine installation and container-runtime baseline

The objective is to prove the intended SentinelOps application-delivery architecture before introducing a production application.

The backend application runs inside Docker and is deliberately bound only to the Ubuntu host loopback interface.

External clients cannot connect directly to the backend port.

All external HTTP traffic continues to enter through host-level Nginx on TCP port 80.

---

## Initial State

Before SEN-009:

- Ubuntu Server 24.04.4 LTS was running in UTM
- the VM architecture was ARM64
- the VM used IPv4 address `192.168.64.2`
- secure SSH administration was operational
- SSH public-key authentication was enabled
- password SSH authentication was disabled
- direct root SSH login was disabled
- `emir` retained sudo access
- `emir` had intentional Docker administrative access
- Docker Engine was installed
- Docker Compose functionality was available
- Docker was enabled and active
- no Docker containers were running
- no stopped test containers remained
- Nginx was installed directly on the Ubuntu host
- Nginx was enabled and active
- UFW was active
- default incoming traffic was denied
- default outgoing traffic was allowed
- TCP port 22 was allowed for SSH
- TCP port 80 was allowed for Nginx HTTP
- TCP port 443 remained blocked
- no application backend port was exposed
- UTM console access remained available as a recovery path

---

## Initial Container State

The Docker container state was reviewed with:

```bash
docker ps -a
```

Result:

```text
CONTAINER ID   IMAGE   COMMAND   CREATED   STATUS   PORTS   NAMES
```

No containers were listed.

This confirmed that SEN-009 began from a clean Docker runtime state.

---

## Docker Service Baseline

Docker service state was checked with:

```bash
systemctl status docker
```

The service reported:

```text
Loaded: loaded
enabled
Active: active (running)
```

This confirmed that Docker was available before application deployment.

---

## Nginx Service Baseline

Host Nginx was checked using:

```bash
systemctl status nginx
```

The service reported:

```text
Loaded: loaded
enabled
Active: active (running)
```

This confirmed that the existing host-level HTTP entry point was operational.

---

## Firewall Baseline

The host firewall was reviewed using:

```bash
sudo ufw status verbose
```

The relevant state was:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
```

The inbound rules were:

```text
22/tcp                     ALLOW IN    Anywhere
80/tcp (Nginx HTTP)        ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
80/tcp (Nginx HTTP (v6))   ALLOW IN    Anywhere (v6)
```

No rule existed for TCP port 8000.

No rule existed for TCP port 443.

---

## Listening Socket Baseline

Host listening sockets were reviewed using:

```bash
ss -tulpn
```

Relevant externally bound TCP listeners were:

```text
0.0.0.0:22
0.0.0.0:80
[::]:22
[::]:80
```

No process was listening on TCP port 8000.

This established that no backend application endpoint existed before SEN-009.

---

## Intended Architecture

SEN-009 validates the following traffic path:

```text
Mac Host
   |
   | HTTP :80
   v
UFW
   |
   v
Host Nginx
   |
   | HTTP to 127.0.0.1:8000
   v
Docker Application Container
```

The backend must not be directly reachable from the Mac.

The host-side backend binding is therefore:

```text
127.0.0.1:8000
```

and not:

```text
0.0.0.0:8000
```

This design preserves Nginx as the controlled external application entry point.

---

## Test Application Selection

A lightweight Nginx Alpine image was used as the minimal test backend.

The image was selected only to validate:

- Docker application deployment
- host loopback binding
- container restart behaviour
- host Nginx reverse proxying
- external backend isolation
- persistence across reboot

The container is not the final SentinelOps production application.

---

## Application Container Deployment

The private backend container was started with:

```bash
docker run -d \
  --name sentinelops-app \
  --restart unless-stopped \
  -p 127.0.0.1:8000:80 \
  nginx:alpine
```

Docker automatically pulled the `nginx:alpine` image because it was not already available locally.

The container started successfully.

---

## Container Name

The application container was assigned the explicit name:

```text
sentinelops-app
```

Using a stable name makes administration, inspection, restart-policy verification, and later cleanup easier than relying on automatically generated Docker names.

---

## Container Port Mapping

The running container was reviewed using:

```bash
docker ps
```

The relevant port mapping was:

```text
127.0.0.1:8000->80/tcp
```

This confirms that:

- the container listens internally on TCP port 80
- the Ubuntu host exposes the container through host TCP port 8000
- the host binding is restricted to `127.0.0.1`
- the application is not bound to all network interfaces

This is the key isolation control implemented during SEN-009.

---

## Restart Policy

The restart policy was inspected using:

```bash
docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' sentinelops-app
```

Result:

```text
unless-stopped
```

This means Docker should automatically restart the container following daemon or host restart unless the administrator has explicitly stopped the container.

---

## Backend Listening Socket

The application port was inspected using:

```bash
ss -tulpn | grep ':8000'
```

Result:

```text
127.0.0.1:8000
```

No listener appeared on:

```text
0.0.0.0:8000
```

This confirms that the backend service is bound only to the Ubuntu loopback interface.

---

## Local Backend Verification

The backend was tested directly from the Ubuntu host:

```bash
curl -I http://127.0.0.1:8000
```

Result:

```text
HTTP/1.1 200 OK
Server: nginx/1.31.4
Content-Type: text/html
Content-Length: 896
Connection: keep-alive
```

This confirmed:

- the container was running
- the application was reachable locally
- Docker port forwarding was functioning
- the backend was returning a valid HTTP response

---

## Direct Backend Isolation Test

The backend port was then tested externally from the Mac.

The SSH session was exited:

```bash
exit
```

From macOS:

```bash
nc -vz -w 2 192.168.64.2 8000
```

No connection was established.

The command remained without a successful response and was manually terminated.

This confirmed that the private backend port was not directly reachable from the Mac.

---

## Backend Isolation Result

The combined tests demonstrated:

```text
Ubuntu host -> 127.0.0.1:8000 -> SUCCESS

Mac host -> 192.168.64.2:8000 -> NO CONNECTION
```

This is the intended security boundary.

The container is reachable by services on the Ubuntu host but not by external clients.

---

## Dedicated Nginx Site

A dedicated Nginx site was created for the SentinelOps reverse proxy.

The configuration file was:

```text
/etc/nginx/sites-available/sentinelops
```

It was created with:

```bash
sudo nano /etc/nginx/sites-available/sentinelops
```

The configuration contained:

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## Reverse Proxy Target

The backend target configured in Nginx was:

```text
http://127.0.0.1:8000
```

This means host-level Nginx forwards incoming HTTP requests to the loopback-only Docker backend.

Nginx therefore acts as the bridge between external traffic and the private application.

---

## Forwarded HTTP Headers

The Nginx configuration forwards:

```text
Host
X-Real-IP
X-Forwarded-For
X-Forwarded-Proto
```

These headers establish the basic reverse-proxy behaviour required by future web applications.

They allow a backend application to determine information about the original client and request scheme rather than seeing only the proxy connection.

---

## Enabling the SentinelOps Site

The dedicated Nginx site was enabled using:

```bash
sudo ln -s /etc/nginx/sites-available/sentinelops /etc/nginx/sites-enabled/sentinelops
```

This created the standard Nginx symbolic link from `sites-enabled` to the configuration stored in `sites-available`.

---

## Disabling the Default Nginx Site

The original Ubuntu Nginx default site was disabled using:

```bash
sudo rm /etc/nginx/sites-enabled/default
```

The configuration file itself was not required to be deleted from `sites-available`.

Removing the enabled symbolic link ensured that the new SentinelOps configuration became the default server on TCP port 80.

---

## Nginx Configuration Validation

Before reloading Nginx, configuration syntax was tested with:

```bash
sudo nginx -t
```

Result:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

This confirmed that the new reverse-proxy configuration was valid before it was applied.

---

## Nginx Reload

After successful validation, Nginx was reloaded using:

```bash
sudo systemctl reload nginx
```

The reload completed without an error.

This applied the new SentinelOps site without requiring a full host restart.

---

## Local Reverse Proxy Verification

The Nginx entry point was tested locally from Ubuntu:

```bash
curl -I http://127.0.0.1
```

Result:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Content-Type: text/html
Content-Length: 896
Connection: keep-alive
Last-Modified: Tue, 11 Aug 2026 23:21:52 GMT
```

The response body characteristics matched the backend container response.

The `Content-Length` of `896` differed from the earlier host Nginx default page baseline, confirming that Nginx was now proxying the backend container rather than serving the previous host default document.

---

## External Reverse Proxy Verification

The new application-delivery path was tested from the Mac.

After exiting the SSH session:

```bash
curl -I http://192.168.64.2
```

Result:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Content-Type: text/html
Content-Length: 896
Connection: keep-alive
```

This confirmed that the Mac could reach the application through the host-level Nginx reverse proxy.

---

## External Response Body Verification

The response body was also checked from the Mac:

```bash
curl -s http://192.168.64.2 | grep -i '<title>'
```

Result:

```text
<title>Welcome to nginx!</title>
```

This content originated from the `nginx:alpine` backend container.

The external request therefore successfully traversed:

```text
Mac
  |
  v
UFW
  |
  v
Host Nginx
  |
  v
127.0.0.1:8000
  |
  v
Docker backend
```

---

## Repeated Direct Backend Isolation Test

After reverse proxy configuration, the backend was tested externally again:

```bash
nc -vz -w 2 192.168.64.2 8000
```

The connection did not succeed.

The command was manually stopped after no connection was established.

This confirmed that configuring the Nginx reverse proxy had not accidentally exposed TCP port 8000.

---

## Firewall State Before Reboot

Before persistence testing, UFW was checked again:

```bash
sudo ufw status verbose
```

Result:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
```

Inbound rules remained:

```text
22/tcp                     ALLOW IN    Anywhere
80/tcp (Nginx HTTP)        ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
80/tcp (Nginx HTTP (v6))   ALLOW IN    Anywhere (v6)
```

No rule existed for TCP port 8000.

No rule existed for TCP port 443.

---

## Nginx Validation Before Reboot

The Nginx configuration was validated again:

```bash
sudo nginx -t
```

Result:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

This confirmed the reverse-proxy configuration remained syntactically valid before persistence testing.

---

## Restart Policy Verification Before Reboot

The container restart policy was rechecked:

```bash
docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' sentinelops-app
```

Result:

```text
unless-stopped
```

This confirmed that the container was configured to return automatically after the VM restarted.

---

## Reboot Persistence Test

The VM was rebooted with:

```bash
sudo reboot
```

The active SSH session terminated as expected.

After the Ubuntu VM completed startup, SSH connectivity was restored from the Mac.

This confirmed that secure administrative access remained available after introducing the containerized application and reverse-proxy configuration.

---

## Application Container State After Reboot

After reconnecting to Ubuntu, container state was checked with:

```bash
docker ps
```

The `sentinelops-app` container was running.

This confirmed that the `unless-stopped` restart policy worked across the VM reboot.

The backend did not require manual container startup.

---

## Nginx State After Reboot

Nginx service state was checked with:

```bash
systemctl status nginx
```

Nginx remained:

```text
enabled
active (running)
```

This confirmed that the host-level reverse proxy automatically returned after reboot.

---

## Firewall State After Reboot

UFW was checked after reboot:

```bash
sudo ufw status verbose
```

The firewall remained active with the same SSH and HTTP allow rules.

No TCP port 8000 allow rule appeared.

No HTTPS rule appeared.

This confirmed that application deployment did not alter the intended external firewall exposure.

---

## Listening Sockets After Reboot

Listening sockets were reviewed with:

```bash
ss -tulpn | grep -E ':22|:80|:8000'
```

The intended socket architecture was preserved:

```text
0.0.0.0:22
0.0.0.0:80
127.0.0.1:8000
[::]:22
[::]:80
```

The important backend entry remained:

```text
127.0.0.1:8000
```

No:

```text
0.0.0.0:8000
```

listener was introduced.

---

## External HTTP Verification After Reboot

From the Mac, the full HTTP path was tested again:

```bash
curl -I http://192.168.64.2
```

Result:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Content-Type: text/html
Content-Length: 896
Connection: keep-alive
```

This confirmed that the complete application-delivery path survived reboot.

---

## External Backend Isolation After Reboot

The Mac tested the backend port again:

```bash
nc -vz -w 2 192.168.64.2 8000
```

Result:

```text
nc: connectx to 192.168.64.2 port 8000 (tcp) failed: Operation timed out
```

This is the required post-reboot isolation result.

The backend remained externally inaccessible even though the application container had automatically restarted.

---

## Final Traffic Architecture

At completion of SEN-009, the traffic path is:

```text
Mac Host
   |
   | TCP 80
   v
UFW
   |
   | 80/tcp allowed
   v
Host Nginx
   |
   | HTTP proxy
   v
127.0.0.1:8000
   |
   v
Docker sentinelops-app
   |
   v
Container TCP 80
```

Direct external traffic to:

```text
192.168.64.2:8000
```

is not available.

---

## External Exposure

The intended external exposure remains:

```text
22/tcp      ALLOW    SSH
80/tcp      ALLOW    Nginx HTTP
443/tcp     BLOCKED
8000/tcp    NOT DIRECTLY REACHABLE
```

No additional application firewall rule was introduced.

---

## Host Versus Container Nginx

Two separate Nginx instances now exist.

The host-level instance is:

```text
nginx/1.24.0 (Ubuntu)
```

Its role is:

- external HTTP entry point
- reverse proxy
- future TLS termination point
- controlled interface between clients and backend services

The containerized instance is:

```text
nginx/1.31.4
```

Its role in SEN-009 is only to provide a minimal test backend.

It is not intended to replace the host reverse proxy.

---

## Host-Level Nginx Role

Host Nginx remains deliberately outside Docker.

This preserves the earlier SentinelOps architecture decision.

The host proxy controls incoming web traffic independently of the lifecycle of future application containers.

Future backend applications can therefore be replaced or upgraded without changing the external firewall architecture.

---

## Backend Privacy

The backend container is not considered publicly exposed because its published host port is limited to:

```text
127.0.0.1:8000
```

Only processes capable of communicating with the Ubuntu host loopback interface can reach it directly.

External clients use Nginx instead.

---

## Docker Port-Publishing Consideration

Docker port publishing must continue to be treated as a security-sensitive operation.

Publishing a future backend as:

```text
0.0.0.0:8000:8000
```

would create a materially different network posture.

The SEN-009 baseline instead demonstrates the preferred pattern:

```text
127.0.0.1:<host-backend-port>:<container-port>
```

when host Nginx needs to communicate with a containerized service.

---

## No UFW Rule for Backend

No command similar to:

```bash
sudo ufw allow 8000/tcp
```

was executed.

This was intentional.

The backend does not require external firewall exposure because Nginx communicates with it locally.

---

## Security Result

At completion of SEN-009:

- Docker remains active
- Nginx remains active
- UFW remains active
- SSH remains available
- the `sentinelops-app` container is running
- the backend container uses `nginx:alpine`
- the backend application is reachable locally
- the backend host port is `8000`
- TCP port 8000 binds only to `127.0.0.1`
- TCP port 8000 is not reachable directly from the Mac
- no UFW rule exists for TCP port 8000
- host Nginx proxies requests to `127.0.0.1:8000`
- the dedicated SentinelOps Nginx site is enabled
- the original default site is disabled
- Nginx configuration validates successfully
- external requests to TCP port 80 return the backend content
- SSH remains exposed only through TCP port 22
- HTTP remains exposed only through TCP port 80
- HTTPS remains blocked
- the backend remains private
- the container uses restart policy `unless-stopped`
- the application container returns after reboot
- Nginx returns after reboot
- UFW returns after reboot
- SSH returns after reboot
- external application access through Nginx returns after reboot
- backend isolation remains effective after reboot
- UTM console recovery access remains available

---

## Verification Summary

The following checks were successfully completed:

- confirmed no containers existed before deployment
- confirmed Docker was active
- confirmed Nginx was active
- confirmed UFW was active
- reviewed baseline listening sockets
- confirmed no TCP port 8000 listener existed initially
- deployed `sentinelops-app`
- used `nginx:alpine` as the minimal backend
- configured restart policy `unless-stopped`
- mapped container port 80 to host `127.0.0.1:8000`
- confirmed the container was running
- confirmed the restart policy
- confirmed the host listener was loopback-only
- confirmed local backend HTTP returned `200 OK`
- confirmed direct Mac access to TCP port 8000 failed
- created `/etc/nginx/sites-available/sentinelops`
- configured Nginx to proxy to `127.0.0.1:8000`
- configured standard forwarded HTTP headers
- enabled the SentinelOps Nginx site
- disabled the original default site
- validated Nginx configuration
- reloaded Nginx successfully
- confirmed local host Nginx returned backend content
- confirmed Mac HTTP requests returned backend content
- confirmed the backend title through the external Nginx path
- confirmed TCP port 8000 remained externally inaccessible
- verified UFW did not contain an 8000 rule
- rechecked restart policy
- validated Nginx again
- rebooted the VM
- restored SSH access after reboot
- confirmed the application container automatically restarted
- confirmed Nginx remained operational
- confirmed UFW remained operational
- confirmed the backend remained bound to `127.0.0.1:8000`
- confirmed external HTTP returned `200 OK` after reboot
- confirmed direct TCP port 8000 access timed out after reboot

---

## Out of Scope

SEN-009 did not introduce:

- Django
- Gunicorn
- PostgreSQL
- Redis
- production application code
- production Dockerfiles
- project Docker Compose deployment
- application secrets
- user authentication
- database credentials
- HTTPS
- TLS certificates
- Certbot
- domain names
- public Internet exposure
- CI/CD deployment
- monitoring
- backups
- cloud infrastructure
- Kubernetes
- Terraform

These capabilities remain reserved for later SentinelOps issues.

---

## Completion State

The SentinelOps Ubuntu Server VM now has a functioning private container application behind the host-level Nginx reverse proxy.

External HTTP traffic enters through UFW on TCP port 80 and is handled by Nginx on the Ubuntu host.

Nginx forwards application requests to the Docker backend through `127.0.0.1:8000`.

The backend is not directly reachable from the Mac and no UFW rule exposes its application port.

The container restart policy, Nginx service, UFW configuration, SSH access, reverse-proxy path, and backend isolation all remain operational across reboot.

This establishes the private application-delivery architecture required before a real SentinelOps application stack is deployed.