xThe running container was:

sentinelops-app

The existing deployment had been created manually with docker run.

This deployment successfully proved the reverse-proxy architecture but was not yet reproducible from project files.

Docker Compose Availability

Docker Compose availability was verified with:

docker compose version

Docker Compose was available and operational.

This confirmed that the VM was ready to manage application services declaratively.

Existing Restart Policy

The existing container restart policy was reviewed using:

docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' sentinelops-app

Result:

unless-stopped

The same restart behaviour was retained in the Compose deployment.

Existing Port Binding

The existing container port mapping was inspected.

The backend remained bound to:

127.0.0.1:8000

and forwarded to container TCP port 80.

This established the network constraint that the Compose deployment was required to preserve.

Existing Nginx Configuration Validation

Before replacing the application container, the host Nginx configuration was validated using:

sudo nginx -t

Result:

nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful

This confirmed that the existing reverse proxy was healthy before changes were introduced.

Existing Firewall State

UFW was reviewed before the Compose migration using:

sudo ufw status verbose

The firewall remained active.

The intentional inbound rules remained:

22/tcp                     ALLOW IN    Anywhere
80/tcp (Nginx HTTP)        ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
80/tcp (Nginx HTTP (v6))   ALLOW IN    Anywhere (v6)

No TCP port 8000 rule existed.

No HTTPS rule existed.

Application Directory

A dedicated application directory was created in the administrator home directory:

mkdir -p ~/sentinelops-app

The working directory was then changed to:

cd ~/sentinelops-app

The resulting application path was:

/home/emir/sentinelops-app

This directory became the deployment root for the Compose-managed application.

Application Project Structure

The application deployment used the following files:

/home/emir/sentinelops-app/
├── index.html
├── Dockerfile
└── compose.yaml

These files define:

the application content;
the application image;
the container runtime configuration.

This makes the deployment reproducible from declarative files.

Application Page

A custom application page was created in:

index.html

The page identifies the service as the SentinelOps application and records that it is operating as a private Docker Compose application behind host-level Nginx.

The page was deliberately styled with a green and purple interface to provide an obvious visual distinction from the previous default Nginx page.

The custom page also provides clear evidence that external requests are reaching the Compose-managed application rather than an old default web document.

Dockerfile

The application image definition was stored in:

Dockerfile

The Dockerfile used:

FROM nginx:alpine

COPY index.html /usr/share/nginx/html/index.html

The image therefore:

uses the lightweight Nginx Alpine base image;
copies the SentinelOps application page into the Nginx web root.

The application remains intentionally minimal because the purpose of SEN-010 is deployment reproducibility rather than production application functionality.

Docker Compose Configuration

The service definition was stored in:

compose.yaml

The configuration defined:

services:
  app:
    build: .
    container_name: sentinelops-app
    restart: unless-stopped
    ports:
      - "127.0.0.1:8000:80"

This configuration declaratively defines:

the local image build;
the container name;
the restart policy;
the loopback-only backend port mapping.
Compose Configuration Validation

Before replacing the existing container, the Compose configuration was validated using:

docker compose config

The rendered configuration reported:

name: sentinelops-app

The service build context resolved to:

/home/emir/sentinelops-app

The container name resolved to:

sentinelops-app

The restart policy resolved to:

unless-stopped

The port mapping resolved to:

host_ip: 127.0.0.1
target: 80
published: "8000"
protocol: tcp

The automatically defined Compose network was:

sentinelops-app_default

The validation completed without configuration errors.

Removal of the Manual Container

After Compose configuration was successfully validated, the temporary SEN-009 container was stopped:

docker stop sentinelops-app

The container was then removed:

docker rm sentinelops-app

This eliminated the manually managed deployment and freed the container name and backend port for the Compose-managed replacement.

Compose Image Build and Deployment

The new application image was built and the stack was started with:

docker compose up -d --build

Docker successfully built the application image from the local Dockerfile.

The service was then created and started successfully.

The application was now managed by Docker Compose rather than by a manually issued docker run command.

Running Container Verification

The running container was reviewed with:

docker ps

The sentinelops-app container was running successfully.

The port mapping remained:

127.0.0.1:8000->80/tcp

This confirmed that the migration to Compose preserved the backend isolation model.

Local Application Verification

The application was tested directly from the Ubuntu host:

curl -I http://127.0.0.1:8000

Result:

HTTP/1.1 200 OK

This confirmed that:

the Compose-managed container was running;
the locally built image was functioning;
the application was reachable through the host loopback binding.
Loopback Binding Verification

The backend listener was reviewed using:

ss -tulpn | grep ':8000'

The listener remained:

127.0.0.1:8000

No listener existed on:

0.0.0.0:8000

This preserved the private backend design established in SEN-009.

Compose Service State

Docker Compose service state was reviewed using:

docker compose ps

The application service was reported as running.

The service showed the expected loopback-only mapping:

127.0.0.1:8000->80/tcp

This confirmed that Compose recognised and managed the running service correctly.

External Reverse Proxy Verification

The Ubuntu SSH session was exited and the application was tested from the Mac through host Nginx:

curl -I http://192.168.64.2

The request returned:

HTTP/1.1 200 OK

The response was delivered through:

Mac
  |
  | TCP 80
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
Docker Compose application

This confirmed that replacing the manual container with the Compose-managed stack did not disrupt the existing reverse-proxy architecture.

Custom Application Content Verification

The external page content was inspected from the Mac.

The response contained the SentinelOps custom application content, including references to:

SentinelOps
Private Docker Compose
Phase 1

This provided clear evidence that the externally served content originated from the new Compose-managed application image.

External Backend Isolation Verification

Direct backend access was tested again from the Mac:

nc -vz -w 2 192.168.64.2 8000

No connection was established.

The command remained without a successful connection and could be manually terminated if necessary.

This confirmed that migration to Docker Compose did not expose the backend directly.

Compose Lifecycle Test

A key SEN-010 objective was to prove that the application could be destroyed and recreated entirely from the Compose definition.

The stack was removed using:

docker compose down

Docker removed:

the running application container;
the Compose-managed network.

The container state was then checked using:

docker ps

No SentinelOps application container remained running.

Compose Recreation Test

The application stack was recreated with:

docker compose up -d

Docker recreated the Compose network and application container.

The service state was then reviewed:

docker compose ps

The application was running again successfully.

This proved that the deployment no longer depended on an individually constructed docker run command.

Application Verification After Recreation

After recreation, the private backend was tested again:

curl -I http://127.0.0.1:8000

Result:

HTTP/1.1 200 OK

This confirms that the application can be removed and restored consistently from:

index.html
Dockerfile
compose.yaml
Restart Policy Verification

Before the final reboot test, the restart policy was verified again:

docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' sentinelops-app

Result:

unless-stopped

This confirmed that the recreated Compose-managed container retained the intended automatic restart behaviour.

Reboot Persistence Test

The Ubuntu VM was rebooted using:

sudo reboot

The SSH connection closed automatically as expected.

After the VM completed startup, the Mac successfully re-established SSH connectivity:

ssh emir@192.168.64.2

This confirmed that secure administrative access survived the SEN-010 deployment changes.

Compose Service State After Reboot

After reconnecting, the application directory was entered:

cd ~/sentinelops-app

Compose service state was checked:

docker compose ps

The result showed:

sentinelops-app

with status:

Up

and port mapping:

127.0.0.1:8000->80/tcp

This confirmed that Docker automatically restored the Compose-managed application container after reboot.

Nginx State After Reboot

Nginx was checked using:

systemctl status nginx

The service reported:

Loaded: loaded
enabled
Active: active (running)

This confirms that the host reverse proxy continued to start automatically with the operating system.

Firewall State After Reboot

UFW was checked using:

sudo ufw status verbose

Result:

Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)

The inbound rules remained:

22/tcp                     ALLOW IN    Anywhere
80/tcp (Nginx HTTP)        ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
80/tcp (Nginx HTTP (v6))   ALLOW IN    Anywhere (v6)

No TCP port 8000 rule appeared.

No HTTPS rule appeared.

Listening Sockets After Reboot

Relevant listening sockets were reviewed using:

ss -tulpn | grep -E ':22|:80|:8000'

The resulting architecture remained:

127.0.0.1:8000
0.0.0.0:80
0.0.0.0:22
[::]:80
[::]:22

The key backend listener remained:

127.0.0.1:8000

No:

0.0.0.0:8000

listener appeared.

This confirmed that backend isolation persisted across reboot.

External HTTP Verification After Reboot

After exiting the SSH session, the Mac tested the application again:

curl -I http://192.168.64.2

Result:

HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Content-Type: text/html
Content-Length: 1923
Connection: keep-alive

This confirms that:

UFW allowed the request;
host Nginx was operational;
Nginx successfully reached the backend;
the Compose-managed application had automatically returned after reboot.
Direct Backend Isolation After Reboot

The Mac tested TCP port 8000 directly:

nc -vz -w 2 192.168.64.2 8000

Result:

nc: connectx to 192.168.64.2 port 8000 (tcp) failed: Operation timed out

This confirms that backend isolation remained effective after reboot.

Final Deployment Model

Before SEN-010, the backend lifecycle depended on a manual command similar to:

docker run ...

After SEN-010, the deployment is represented by:

Application source
      +
Dockerfile
      +
compose.yaml
      |
      v
docker compose
      |
      v
sentinelops-app

The stack can be consistently:

built;
started;
inspected;
stopped;
removed;
recreated.
Final Traffic Architecture

The completed application path is:

Mac Host
   |
   | TCP 80
   v
UFW
   |
   v
Host Nginx
   |
   | HTTP
   v
127.0.0.1:8000
   |
   v
Docker Compose
   |
   v
sentinelops-app
   |
   v
Container TCP 80
External Network Exposure

The externally reachable services remain:

22/tcp      ALLOW    SSH
80/tcp      ALLOW    Nginx HTTP

The following remain unavailable externally:

443/tcp     BLOCKED
8000/tcp    PRIVATE

No UFW rule was added for TCP port 8000.

Security Result

At completion of SEN-010:

Docker Engine remains active;
Docker Compose is available;
application deployment is declarative;
application source exists separately from the container runtime;
a Dockerfile defines the image;
compose.yaml defines the service;
Compose configuration validates successfully;
the old manually deployed container has been removed;
the application image builds successfully;
the application runs through Docker Compose;
the container retains the stable name sentinelops-app;
restart policy is unless-stopped;
the backend binds only to 127.0.0.1:8000;
no listener exists on 0.0.0.0:8000;
host Nginx remains the external web entry point;
Nginx successfully proxies to the Compose-managed backend;
UFW remains active;
SSH remains allowed;
HTTP remains allowed;
HTTPS remains blocked;
no backend firewall rule exists;
direct Mac access to TCP port 8000 fails;
Compose stack removal works;
Compose stack recreation works;
the application returns after recreation;
the application returns after VM reboot;
Nginx returns after reboot;
UFW returns after reboot;
SSH returns after reboot;
external HTTP returns after reboot;
backend isolation remains effective after reboot;
UTM console recovery access remains available.
Verification Summary

The following checks were successfully completed:

reviewed the existing SEN-009 container;
verified Docker Compose availability;
verified the existing restart policy;
verified existing loopback-only backend exposure;
validated host Nginx configuration;
reviewed the UFW baseline;
created /home/emir/sentinelops-app;
created index.html;
created a custom SentinelOps application page;
created a Dockerfile;
created compose.yaml;
configured a local image build;
configured container name sentinelops-app;
configured restart policy unless-stopped;
configured 127.0.0.1:8000:80;
validated Compose configuration with docker compose config;
confirmed Compose resolved host IP 127.0.0.1;
stopped the old manually created container;
removed the old manually created container;
built the new application image;
deployed the application with docker compose up -d --build;
verified the new container was running;
verified local HTTP returned 200 OK;
verified the backend listener remained loopback-only;
verified Compose recognised the service;
verified external HTTP through Nginx returned 200 OK;
verified custom SentinelOps application content externally;
confirmed direct access to TCP port 8000 remained unavailable;
removed the Compose stack with docker compose down;
verified the container was removed;
recreated the stack with docker compose up -d;
verified Compose recreation succeeded;
verified the application returned after recreation;
confirmed restart policy remained unless-stopped;
rebooted the Ubuntu VM;
re-established SSH after reboot;
verified the Compose application automatically returned;
verified Nginx remained active;
verified UFW remained active;
verified the backend remained bound to 127.0.0.1:8000;
verified external HTTP returned HTTP/1.1 200 OK after reboot;
verified direct TCP port 8000 access timed out after reboot.
Out of Scope

SEN-010 did not introduce:

Django;
Gunicorn;
PostgreSQL;
Redis;
production business logic;
user authentication;
application secrets;
database credentials;
production environment configuration;
CI/CD deployment;
container registry publishing;
HTTPS;
TLS certificates;
Certbot;
domain names;
monitoring;
backups;
public Internet deployment;
cloud infrastructure;
Kubernetes;
Terraform.

These capabilities remain reserved for later SentinelOps issues.

Completion State

The SentinelOps application deployment is now managed reproducibly with Docker Compose.

The application source, Dockerfile, and Compose configuration define the deployment instead of relying on a manually constructed container command.

The application remains private on 127.0.0.1:8000 and is externally accessible only through host-level Nginx on TCP port 80.

The default-deny firewall model remains intact, and no backend application port has been exposed through UFW.

The Compose lifecycle has been validated through removal and recreation, and the complete Docker, application, Nginx, UFW, SSH, and reverse-proxy stack remains operational across reboot.

This establishes the reproducible containerized application-deployment foundation required for later SentinelOps application and operational tooling.