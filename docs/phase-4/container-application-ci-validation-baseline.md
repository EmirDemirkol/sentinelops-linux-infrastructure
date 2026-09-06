# SEN-027 Container and Application CI Validation Baseline

## Purpose

SEN-027 extends the SentinelOps GitHub Actions CI foundation with automated container configuration validation and basic application behaviour testing.

The issue targets:

```text
FR-48: Container Validation
FR-49: Application Testing
```

Related success criteria:

```text
SC-38: Container Configuration Validation
SC-39: Application Test
```

SEN-026 established:

```text
Bash syntax validation
ShellCheck
secret-pattern safety
```

SEN-027 builds on the same workflow and adds Docker and application-level validation.

## Relationship to Previous CI Work

SEN-026 introduced:

```text
.github/workflows/ci.yml
```

with:

```text
Shell validation
Secret safety
```

SEN-027 extends the existing workflow rather than creating a separate CI system.

The resulting workflow now validates:

```text
shell syntax
shell static analysis
secret-like content
Docker Compose configuration
container security assumptions
Docker image build
application startup
application health behaviour
```

## Application Assets

The CI job validates the existing application assets:

```text
provision/application/Dockerfile
provision/application/compose.yaml
provision/application/index.html
```

Current application architecture:

```text
Docker Compose
  |
  v
sentinelops-app
  |
  v
container port 80
  |
  v
127.0.0.1:8000 on the host
```

The backend publication remains loopback-only.

## Dockerfile Baseline

The current Dockerfile uses:

```text
nginx:alpine
```

and defines:

```text
ARG SENTINELOPS_VERSION=0.1.0
```

The image creates:

```text
/health
```

with expected content:

```json
{"status":"healthy","version":"0.1.0"}
```

## Docker Compose Baseline

The current Compose service is:

```text
app
```

with container name:

```text
sentinelops-app
```

The expected host publication is:

```text
127.0.0.1:8000:80
```

The application must not expose:

```text
0.0.0.0:8000
```

or otherwise bypass the loopback-only backend design.

## Initial Local Tooling State

The development Mac did not have Docker installed.

Local commands returned:

```text
docker: command not found
```

This was not treated as a blocker.

SEN-027 intentionally performs Docker validation on the GitHub-hosted Ubuntu runner.

The workflow also records:

```text
docker --version
docker compose version
```

so runner Docker availability becomes visible CI evidence.

## New CI Job

SEN-027 adds:

```text
container-application-validation
```

displayed in GitHub Actions as:

```text
Container and application validation
```

The job uses:

```text
runs-on: ubuntu-latest
```

and sets:

```text
working-directory: provision/application
```

for application validation commands.

## Existing CI Jobs Preserved

SEN-027 preserves the SEN-026 jobs:

```text
Shell validation
Secret safety
```

The complete pull-request workflow now contains:

```text
Shell validation
Secret safety
Container and application validation
```

## Workflow Permission Model

The workflow retains:

```yaml
permissions:
  contents: read
```

SEN-027 does not require:

```text
production credentials
private SSH keys
cloud credentials
deployment tokens
repository write permissions
VM login credentials
```

The new job is validation-only.

## Docker Version Verification

The container/application job first runs:

```bash
docker --version
docker compose version
```

This provides explicit evidence that the GitHub-hosted runner contains the Docker tooling required for later validation.

If Docker becomes unavailable on the selected runner image, the job fails early.

## Docker Compose Configuration Validation

The workflow executes:

```bash
docker compose config
```

from:

```text
provision/application
```

This verifies that the Compose configuration can be parsed successfully.

An invalid Compose configuration therefore causes the CI job to fail before application startup.

## Container Security Validation

The workflow performs explicit checks against:

```text
provision/application/compose.yaml
```

The first required property is:

```text
127.0.0.1:8000:80
```

If this expected loopback-only mapping is absent, CI fails.

The second prohibited property is:

```text
privileged: true
```

If privileged container mode is explicitly enabled, CI fails.

These checks preserve two important SentinelOps security assumptions:

```text
backend remains loopback-only
application container is not privileged
```

## Docker Image Build Validation

The workflow runs:

```bash
docker compose build
```

A Dockerfile or application build failure therefore causes the CI job to fail.

This provides automated evidence that the repository's application image can be built successfully.

## Application Startup Validation

After a successful build, the workflow runs:

```bash
docker compose up -d
```

The SentinelOps application must therefore start successfully inside the CI runner before application behaviour validation continues.

## Health Endpoint Availability Wait

The workflow does not assume that the application is instantly available.

It checks:

```text
http://127.0.0.1:8000/health
```

repeatedly.

The workflow performs up to:

```text
30 attempts
```

with:

```text
2 seconds
```

between unsuccessful attempts.

The request uses curl failure handling.

If the endpoint never becomes available, CI reports diagnostic information using:

```bash
docker compose ps
docker compose logs
```

and exits non-zero.

## HTTP Status Validation

After the health endpoint becomes available, the workflow performs a dedicated HTTP status check.

Expected result:

```text
HTTP 200
```

Any other status causes CI failure.

This verifies that application availability is not inferred merely from container process state.

## Health JSON Validation

The health response is written to:

```text
/tmp/sentinelops-health.json
```

Python parses the JSON.

Expected response:

```json
{
  "status": "healthy",
  "version": "0.1.0"
}
```

The response must match both expected fields.

The validation therefore checks:

```text
status
version
```

rather than only verifying that the endpoint responds.

## CI Cleanup

The final application step uses:

```text
if: always()
```

and runs:

```bash
docker compose down --volumes --remove-orphans
```

This cleanup runs even when an earlier application validation step fails.

The workflow therefore avoids intentionally leaving the Compose application running for the remainder of the job.

## Initial SEN-027 CI Run

The first pull-request run after SEN-027 implementation was GitHub Actions run:

```text
#7
```

Result:

```text
Shell validation: PASS
Secret safety: PASS
Container and application validation: PASS
```

The new container/application job completed successfully.

## Initial Container/Application Step Results

The first successful SEN-027 run demonstrated:

```text
Docker version verification: PASS
Docker Compose version verification: PASS
Docker Compose configuration: PASS
container security validation: PASS
Docker image build: PASS
application startup: PASS
health endpoint availability: PASS
application health response: PASS
application cleanup: PASS
```

This established the first clean container and application CI baseline.

## Initial Implementation Commit

The new CI job was introduced in:

```text
e09c00b ci: add SEN-027 container and application validation
```

## Controlled Application Failure Objective

SEN-027 required evidence that application validation actually fails when expected behaviour does not match runtime behaviour.

A safe synthetic expectation mismatch was chosen.

The real application was not modified.

The Dockerfile was not deliberately broken.

The Compose networking configuration was not altered.

No secret-like content was introduced.

## Controlled Failure Method

The CI health-response expectation was temporarily changed from:

```text
0.1.0
```

to:

```text
9.9.9
```

The actual application continued to return:

```json
{"status":"healthy","version":"0.1.0"}
```

This created an intentional application-test mismatch.

## Controlled Failure Commit

The temporary mismatch was committed as:

```text
b63ea8f test: demonstrate SEN-027 application CI failure
```

and pushed to pull request #41.

## Controlled Failure CI Run

The controlled failure produced GitHub Actions run:

```text
#8
```

Result:

```text
Shell validation: PASS
Secret safety: PASS
Container and application validation: FAIL
```

This demonstrates that the existing SEN-026 jobs remained independent while the application validation job correctly failed.

## Controlled Failure Step

The failing step was:

```text
Validate application health response
```

The earlier container/application steps passed:

```text
Docker version verification
Docker Compose configuration
container security validation
Docker image build
application startup
health endpoint wait
```

The failure therefore occurred specifically at the behavioural assertion.

## Controlled Failure Output

GitHub Actions reported:

```text
ERROR: Unexpected health response: {'status': 'healthy', 'version': '0.1.0'}
```

and:

```text
Process completed with exit code 1.
```

This confirms that unexpected application behaviour produces a non-zero CI result.

## Controlled Failure Cleanup

The cleanup step still executed after the application assertion failed.

The workflow therefore demonstrated:

```text
validation failure
followed by Compose cleanup
```

rather than abandoning the running Compose project.

## Controlled Failure Assessment

The controlled failure proved that:

```text
the application is actually started in CI
the health endpoint is actually requested
the JSON response is actually parsed
the version value is actually checked
unexpected application behaviour causes CI failure
the failing validation is clearly identified
unrelated shell validation remains green
unrelated secret validation remains green
cleanup executes after failure
```

## Controlled Failure Recovery

After the failure evidence was captured, the expected version was restored to:

```text
0.1.0
```

No application source change was required because the application behaviour was already correct.

## Recovery Commit

The CI expectation was restored in:

```text
41497c5 test: recover SEN-027 application CI failure
```

and pushed to pull request #41.

## Recovery CI Run

The recovery produced GitHub Actions run:

```text
#9
```

Result:

```text
Shell validation: PASS
Secret safety: PASS
Container and application validation: PASS
```

The final recovery workflow status was:

```text
Success
```

## SEN-027 CI Run Sequence

The important SEN-027 sequence is:

```text
Run #7
Shell validation: PASS
Secret safety: PASS
Container and application validation: PASS
Reason: initial SEN-027 implementation

Run #8
Shell validation: PASS
Secret safety: PASS
Container and application validation: FAIL
Reason: controlled application version mismatch

Run #9
Shell validation: PASS
Secret safety: PASS
Container and application validation: PASS
Reason: expected version restored
```

This provides positive, negative, and recovery evidence.

## Git Commit Sequence

SEN-027 implementation and testing currently includes:

```text
e09c00b ci: add SEN-027 container and application validation
b63ea8f test: demonstrate SEN-027 application CI failure
41497c5 test: recover SEN-027 application CI failure
```

## FR-48 Assessment

FR-48 requires Docker-related project files to be validated automatically where practical.

Evidence includes:

```text
Docker availability verified in CI
Docker Compose configuration parsed automatically
loopback-only Compose publication checked
privileged container mode rejected
Docker image built automatically
container validation runs on pull requests
container validation failure produces non-zero CI result
```

Result:

```text
FR-48: SATISFIED
```

## SC-38 Assessment

SC-38 requires:

```text
container build succeeds
Docker Compose configuration parses successfully
invalid container configuration causes CI failure where applicable
```

SEN-027 provides automated build and Compose parsing.

The workflow also contains explicit security-state rejection for:

```text
missing loopback-only mapping
privileged: true
```

Result:

```text
SC-38: SATISFIED
```

## FR-49 Assessment

FR-49 requires CI to verify basic application behaviour.

Evidence includes:

```text
application starts in CI
health endpoint availability is awaited
health endpoint is requested
HTTP 200 is required
health JSON is parsed
status must equal healthy
version must equal 0.1.0
unexpected response causes CI failure
controlled failure and recovery were demonstrated
```

Result:

```text
FR-49: SATISFIED
```

## SC-39 Assessment

SC-39 requires application testing and health endpoint validation where practical.

SEN-027 directly validates:

```text
/health
HTTP status
status field
version field
```

Result:

```text
SC-39: SATISFIED
```

## Security Considerations

The SEN-027 CI job does not:

```text
connect to the SentinelOps VM
open public production ports
deploy infrastructure
use cloud credentials
use private SSH keys
use production secrets
publish container images
push to a registry
require repository write permissions
run the application outside the GitHub-hosted runner
```

The workflow remains validation-only.

## Network Boundary

The Compose application uses:

```text
127.0.0.1:8000:80
```

inside the GitHub-hosted runner.

The CI workflow accesses:

```text
127.0.0.1:8000
```

locally on that runner.

SEN-027 does not expose the CI application as a public service.

## Known Limitations

SEN-027 does not introduce:

```text
container vulnerability scanning
SBOM generation
container signing
image registry publishing
multi-architecture build matrix
production deployment
cloud deployment
integration with the live SentinelOps VM
performance testing
load testing
browser testing
full application test framework
Docker daemon hardening
Kubernetes
Ansible
Terraform
```

These remain outside the issue scope.

## Docker Runner Dependency

SEN-027 depends on Docker tooling being available in the selected GitHub-hosted Ubuntu runner.

The workflow makes this dependency explicit by running:

```text
docker --version
docker compose version
```

If the runner image changes incompatibly, the CI job will fail visibly.

## Application Test Boundary

The current application is intentionally small.

The application test therefore validates the current meaningful behaviour:

```text
container can build
container can start
health endpoint becomes available
health endpoint returns HTTP 200
health JSON matches expected state/version
```

A larger future application may require a broader automated test suite.

## Final SEN-027 Feature-Branch State

The feature branch now provides automated validation for:

```text
Bash syntax
ShellCheck
secret-pattern safety
Docker Compose configuration
loopback-only container publication
non-privileged container configuration
Docker image build
application startup
health endpoint availability
HTTP 200
health status
health version
Compose cleanup
```

## Acceptance Evidence Summary

SEN-027 demonstrated:

```text
existing SEN-026 checks preserved
Docker tooling confirmed on CI runner
Docker Compose parsing automated
loopback-only mapping validated
privileged mode rejected
Docker image build automated
application startup automated
health endpoint wait implemented
HTTP 200 validation implemented
health status validation implemented
health version validation implemented
cleanup runs automatically
initial CI run passed
controlled application mismatch introduced
controlled mismatch caused application CI failure
failing validation clearly identified
non-zero exit behaviour demonstrated
shell validation remained independent
secret validation remained independent
cleanup executed after failure
controlled mismatch reverted
recovery CI passed
FR-48 satisfied
FR-49 satisfied
SC-38 satisfied
SC-39 satisfied
```

## Final Status

SEN-027 Container and Application CI Validation:

```text
Initial application asset audit: PASS
Existing CI foundation preserved: PASS
Container/application CI job added: PASS
Docker availability check: PASS
Docker Compose validation: PASS
loopback-only mapping validation: PASS
privileged mode validation: PASS
Docker image build: PASS
application startup: PASS
health endpoint availability: PASS
HTTP 200 validation: PASS
health status validation: PASS
health version validation: PASS
cleanup behavior: PASS

Initial SEN-027 CI run: PASS

Controlled application failure: PASS
controlled mismatch detected: PASS
application validation failed as expected: PASS
exit code 1: PASS
Shell validation remained green: PASS
Secret safety remained green: PASS
cleanup after failure: PASS

Controlled recovery: PASS
final recovery CI run: PASS

FR-48: SATISFIED
FR-49: SATISFIED
SC-38: SATISFIED
SC-39: SATISFIED
```

SEN-027 extends SentinelOps from repository-level CI validation into automated container and application behaviour validation while preserving the project's existing security and least-privilege boundaries.