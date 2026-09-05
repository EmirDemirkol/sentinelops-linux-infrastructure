# SEN-026 GitHub Actions CI Baseline

## Purpose

SEN-026 introduces the first GitHub Actions continuous-integration workflow for SentinelOps.

The issue establishes the CI foundation required before MVP release and targets:

```text
FR-46: Continuous Integration
FR-47: Shell Validation
FR-50: Secret Protection
```

The implementation intentionally keeps the workflow small, understandable, and limited to repository validation.

Container validation and application behaviour testing remain separate follow-up work under:

```text
FR-48
FR-49
```

## Relationship to Previous Work

SEN-024 established repeatable clean-host provisioning.

SEN-025 hardened provisioning idempotency, prerequisite validation, and failure behaviour.

SEN-026 adds automated repository validation so important errors can be detected automatically on pull requests and pushes to the default branch.

## Initial Repository CI State

Before SEN-026:

```text
.github/workflows/: absent
GitHub Actions workflow: absent
ShellCheck CI: absent
automated repository secret-pattern validation: absent
```

The repository already documented GitHub Actions as an MVP requirement, but no workflow existed.

## Repository Shell Inventory

The repository contained three shell scripts:

```text
provision/scripts/provision.sh
provision/monitoring/health-check.sh
provision/backup/backup-sentinelops.sh
```

These became the initial automated shell-validation scope.

## Local Tooling Baseline

Before SEN-026 implementation, the development Mac did not have:

```text
shellcheck
docker
```

installed.

This was not treated as a blocker.

The CI workflow was designed to install or use required validation tooling inside the GitHub-hosted runner rather than depending on developer-workstation state.

## GitHub Actions Workflow

SEN-026 adds:

```text
.github/workflows/ci.yml
```

Workflow name:

```text
SentinelOps CI
```

The workflow contains two jobs:

```text
Shell validation
Secret safety
```

## Workflow Triggers

The workflow runs automatically for:

```text
pull requests
pushes to main
```

This provides validation:

```text
before merge
after changes reach the default branch
```

## Workflow Permissions

The workflow declares:

```yaml
permissions:
  contents: read
```

The CI jobs therefore operate with read-only repository content access.

The workflow does not require:

```text
repository write permissions
deployment credentials
production secrets
cloud credentials
VM credentials
```

## Shell Validation Job

The shell-validation job:

```text
checks out the repository
installs ShellCheck
discovers shell scripts under provision/
fails if no shell scripts are found
runs bash -n
runs ShellCheck
```

The discovery mechanism allows new shell scripts under the provisioning tree to be included automatically.

## Bash Syntax Validation

The workflow validates shell syntax using:

```bash
bash -n
```

against all discovered:

```text
*.sh
```

files under:

```text
provision/
```

A syntax-invalid script causes CI to fail with a non-zero status.

## ShellCheck Validation

GitHub Actions installs ShellCheck using the Ubuntu package manager.

ShellCheck then runs against all discovered provisioning shell scripts.

The workflow therefore does not require ShellCheck to be installed on the developer Mac.

## Existing ShellCheck Directive

Before SEN-026, `provision/scripts/provision.sh` already contained one specific ShellCheck directive:

```bash
# shellcheck disable=SC1091
```

This exists because the provisioner sources:

```text
/etc/os-release
```

which is an operating-system file outside the repository.

SEN-026 does not introduce a broad ShellCheck disable.

## First CI Execution

The initial GitHub Actions run was triggered after pull request #39 was opened.

Result:

```text
Shell validation: FAIL
Secret safety: PASS
```

The shell-validation failure occurred during:

```text
Run ShellCheck
```

## First ShellCheck Finding

ShellCheck reported:

```text
SC1091
```

against:

```text
provision/scripts/provision.sh
```

at the line:

```bash
codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
```

The diagnostic indicated that:

```text
/etc/os-release
```

could not be followed because it was not part of the repository input.

## ShellCheck Finding Assessment

This finding was reviewed rather than automatically suppressed globally.

The source is an operating-system file intentionally provided by Ubuntu at runtime.

The provisioner requires that file to determine:

```text
VERSION_CODENAME
```

for Docker repository configuration.

The finding therefore represented a static-analysis limitation rather than a SentinelOps logic error.

## ShellCheck Finding Resolution

A specific directive was added immediately before the runtime source operation:

```bash
# shellcheck disable=SC1091
```

No global ShellCheck configuration was added.

No other warning class was disabled.

Commit:

```text
63f5c68 fix: resolve SEN-026 ShellCheck finding
```

## Clean CI Baseline After ShellCheck Fix

After the specific SC1091 fix was pushed, GitHub Actions ran again.

Result:

```text
Shell validation: PASS
Secret safety: PASS
```

This established the first clean SentinelOps CI baseline.

## Secret Safety Job

The secret-safety job scans tracked repository files for obvious prohibited secret patterns.

Patterns include:

```text
RSA private-key header patterns
OpenSSH private-key header patterns
EC private-key header patterns
DSA private-key header patterns
obvious password assignments
obvious token assignments
obvious secret assignments
```

The scan uses:

```text
git grep
```

against tracked repository content.

## Secret Logging Behaviour

When suspicious content is found, the workflow is designed to print:

```text
affected file paths
```

without printing the matching secret-like content itself.

This reduces the risk of leaking sensitive values into GitHub Actions logs.

## Secret Safety Baseline Result

The first GitHub Actions run reported:

```text
Secret safety: PASS
```

The secret-safety job continued to pass through later SEN-026 test runs.

No real secret material was introduced.

## GitHub Workflow Push Authentication

The first attempt to push:

```text
.github/workflows/ci.yml
```

was rejected by GitHub.

GitHub reported that the Personal Access Token being used was not permitted to create or update workflow files.

The failed push did not alter repository state.

## Fine-Grained Token Correction

A repository-scoped fine-grained Personal Access Token was created with:

```text
Contents: Read and write
Workflows: Read and write
Metadata: Read-only
```

The token was limited to:

```text
EmirDemirkol/sentinelops-linux-infrastructure
```

The old cached Git credential was removed from the macOS credential helper.

The branch push then succeeded.

No token value was stored in:

```text
source code
workflow configuration
documentation
Git history
```

## CI Foundation Commit

Initial workflow commit:

```text
8ef73ba ci: add SEN-026 GitHub Actions foundation
```

The commit added:

```text
.github/workflows/ci.yml
```

## Controlled CI Failure Objective

SEN-026 required proof that the workflow fails when invalid shell automation is introduced.

A safe synthetic Bash syntax failure was chosen.

This avoided:

```text
modifying a real SentinelOps runtime script
introducing fake secret material
altering production configuration
```

## Controlled Failure Script

The temporary file was:

```text
provision/sen-026-ci-failure-test.sh
```

Contents intentionally omitted the closing:

```text
fi
```

from an `if` statement.

The script contained only synthetic harmless test content.

## Local Controlled Failure

Local validation produced:

```text
provision/sen-026-ci-failure-test.sh: line 5: syntax error: unexpected end of file
```

and:

```text
EXIT_CODE=2
```

This confirmed the file was intentionally invalid before it was pushed.

## Controlled Failure Commit

The temporary invalid script was committed as:

```text
6d14acd test: demonstrate SEN-026 CI shell failure
```

and pushed to the existing SEN-026 pull request branch.

## Controlled Failure CI Result

GitHub Actions automatically started a new pull-request run.

Result:

```text
Shell validation: FAIL
Secret safety: PASS
```

The failed step was:

```text
Validate Bash syntax
```

The workflow output showed:

```text
Checking Bash syntax: provision/backup/backup-sentinelops.sh
Checking Bash syntax: provision/monitoring/health-check.sh
Checking Bash syntax: provision/scripts/provision.sh
Checking Bash syntax: provision/sen-026-ci-failure-test.sh
```

followed by:

```text
provision/sen-026-ci-failure-test.sh: line 5: syntax error: unexpected end of file
```

GitHub Actions reported:

```text
Process completed with exit code 2.
```

## Controlled Failure Assessment

The controlled failure demonstrated that:

```text
new shell scripts are automatically discovered
invalid Bash syntax blocks the workflow
the failing file is identified
the job returns a non-zero result
unrelated Secret safety validation can still pass independently
```

This provides direct evidence for automated failure enforcement.

## Controlled Failure Recovery

After the failing CI result was captured, the synthetic file was deleted.

Real SentinelOps scripts were revalidated locally with:

```text
bash -n
```

All passed.

`git diff --check` also passed before recovery commit.

## Recovery Commit

The synthetic failure file was removed in:

```text
5a40a22 test: recover SEN-026 CI failure simulation
```

The recovery commit was pushed to the existing pull request branch.

## Final Recovery CI Run

GitHub Actions ran again after the recovery commit.

Final result:

```text
Shell validation: PASS
Secret safety: PASS
```

The pull request also reported:

```text
No conflicts with base branch
```

The final feature-branch CI state was therefore green.

## CI Run Sequence

The SEN-026 pull request produced the following important sequence:

```text
Run 1
Shell validation: FAIL
Secret safety: PASS
Reason: ShellCheck SC1091

Run 2
Shell validation: PASS
Secret safety: PASS
Reason: specific SC1091 handling added

Run 3
Shell validation: FAIL
Secret safety: PASS
Reason: controlled synthetic Bash syntax failure

Run 4
Shell validation: PASS
Secret safety: PASS
Reason: synthetic failure removed
```

This sequence provides both positive and negative CI evidence.

## Local Static Validation

During SEN-026, local validation included:

```text
bash -n
git diff --check
git diff --cached --check
repository secret-pattern scan
```

The final implementation must pass these checks before merge.

## GitHub Actions Warning Observation

GitHub Actions displayed a warning indicating that:

```text
actions/checkout@v4
```

targets an older Node.js runtime and is being forced to run on a newer runtime by GitHub.

This warning did not cause workflow failure.

It remains an external action/runtime compatibility warning rather than a SentinelOps validation failure.

The workflow should continue to use a supported checkout action version and can be updated when an appropriate newer stable version is adopted.

## Pull Request

SEN-026 uses:

```text
Pull request #39
```

The PR is linked to:

```text
Issue #38
```

and is configured to close the issue after successful merge.

## FR-46 Assessment

FR-46 requires the repository to use GitHub Actions for automated project validation before MVP release.

Evidence includes:

```text
.github/workflows/ci.yml exists
workflow runs on pull requests
workflow runs on pushes to main
real pull-request runs executed
workflow results appear directly on the PR
failing jobs block the clean-check state
successful recovery produces green checks
```

Result:

```text
FR-46: SATISFIED
```

## FR-47 Assessment

FR-47 requires shell scripts to receive automated checks for common errors or quality problems.

Evidence includes:

```text
bash -n runs automatically
ShellCheck runs automatically
all three existing SentinelOps shell scripts are included
new shell scripts under provision/ are automatically discovered
real SC1091 finding was reviewed
specific fix was applied
controlled syntax error caused CI failure
clean recovery passed
```

Result:

```text
FR-47: SATISFIED
```

## FR-50 Assessment

FR-50 requires the repository to avoid real passwords, private SSH keys, cloud credentials, and other sensitive material.

Evidence includes:

```text
automated secret-pattern job exists
private-key patterns are scanned
obvious password/token/secret assignments are scanned
matching secret-like content is not printed
workflow requires no production secrets
workflow permissions are read-only
secret-safety job passed during SEN-026 runs
local secret scan also passed
```

Result:

```text
FR-50: SATISFIED
```

## Success Criteria Mapping

SEN-026 provides evidence for:

```text
SC-36: GitHub Actions Validation
SC-37: Shell Script Validation
SC-40: Secret-Free Repository
```

Container and application CI success criteria remain future work:

```text
SC-38
SC-39
```

## Security Considerations

The CI workflow does not:

```text
deploy infrastructure
connect to SentinelOps VMs
store private SSH keys
use production credentials
write to repository contents
modify cloud infrastructure
```

The job permission model is intentionally minimal.

## Known Limitations

SEN-026 does not implement:

```text
Docker image build validation
Docker Compose validation
application runtime testing
health-endpoint CI testing
deployment automation
VM provisioning from GitHub Actions
cloud deployment
Ansible
Terraform
Kubernetes
transactional CI rollback
third-party secret-scanning platforms
```

These are outside the issue scope.

## FR-48 and FR-49 Boundary

The following remain explicitly separate:

```text
FR-48: Container Validation
FR-49: Application Testing
```

The next CI work should build on the SEN-026 workflow instead of creating a separate unrelated validation system.

## Final Implementation State

The feature branch contains:

```text
.github/workflows/ci.yml
specific ShellCheck SC1091 handling
CI failure/recovery history
CI baseline documentation
```

The temporary controlled-failure script does not remain in the final working tree.

## Acceptance Evidence Summary

SEN-026 demonstrated:

```text
GitHub Actions workflow introduced
pull-request trigger working
push-to-main trigger configured
Bash syntax validation automated
ShellCheck automated
real ShellCheck finding detected
real ShellCheck finding reviewed
specific ShellCheck correction applied
clean CI baseline achieved
secret-pattern validation automated
secret-safety job passed
controlled CI failure demonstrated
invalid shell script detected automatically
failing file identified in CI
non-zero CI failure produced
controlled failure recovered
synthetic artifact removed
final clean CI run passed
read-only workflow permissions retained
no repository secret required
```

## Final Status

SEN-026 GitHub Actions CI foundation:

```text
Initial CI audit: PASS
GitHub Actions absence confirmed: PASS
Workflow created: PASS
Pull request trigger: PASS
Push-to-main trigger configured: PASS
Read-only workflow permissions: PASS
Bash syntax validation: PASS
ShellCheck integration: PASS
Initial ShellCheck finding detected: PASS
SC1091 finding reviewed: PASS
Specific ShellCheck handling added: PASS
First clean CI baseline: PASS
Secret-pattern validation: PASS
Secret safety workflow: PASS
Controlled CI failure created: PASS
Controlled Bash syntax failure detected: PASS
Controlled CI exit behaviour: PASS
Secret safety remained independent: PASS
Controlled failure evidence captured: PASS
Synthetic failure removed: PASS
Recovery commit: PASS
Final Shell validation: PASS
Final Secret safety: PASS
No PR branch conflict: PASS
FR-46: SATISFIED
FR-47: SATISFIED
FR-50: SATISFIED
SC-36: SATISFIED
SC-37: SATISFIED
SC-40: SATISFIED
```

SEN-026 establishes the first automated SentinelOps repository validation baseline and demonstrates both successful CI enforcement and controlled CI failure detection before MVP release.

---

## Security Baseline Update

Replace the existing `# SB-31: CI Validation Before MVP Release` section in `docs/security/security-baseline.md` with:

# SB-31: CI Validation Before MVP Release

The repository shall use automated validation before the MVP is considered complete.

SEN-026 establishes the initial GitHub Actions validation baseline.

Current automated checks include:

- Bash syntax validation;
- ShellCheck static analysis;
- repository secret-pattern validation.

The workflow runs automatically for:

```text
pull requests
pushes to main
```

Current workflow permissions are restricted to:

```yaml
contents: read
```

The workflow does not require production credentials or deployment secrets.

Container configuration validation and application behaviour testing remain separate CI follow-up work.

Purpose:

- detect shell syntax errors before changes are accepted;
- identify common shell quality problems;
- detect obvious prohibited secret material;
- expose validation results directly on pull requests;
- establish automated repository checks before MVP release.

Verification:

- confirm the SentinelOps GitHub Actions workflow executes on pull requests;
- confirm Shell validation passes for valid repository state;
- confirm Secret safety passes for valid repository state;
- confirm an intentionally invalid synthetic shell script causes Shell validation to fail;
- confirm the synthetic failure can be removed and the workflow returns to a passing state;
- confirm required GitHub Actions checks pass before merge.

---

## Provisioning README Update

Replace the existing `## Continuous Integration Boundary` section in `provision/README.md` with:

## Continuous Integration

SEN-026 introduces the first SentinelOps GitHub Actions validation workflow:

```text
.github/workflows/ci.yml
```

The workflow currently implements:

```text
FR-46: Continuous Integration
FR-47: Shell Validation
FR-50: Secret Protection
```

Automated checks currently include:

```text
Bash syntax validation
ShellCheck
repository secret-pattern validation
```

The workflow runs for:

```text
pull requests
pushes to main
```

The workflow uses:

```yaml
permissions:
  contents: read
```

and does not require production credentials.

All current provisioning shell scripts under:

```text
provision/
```

are discovered automatically by the shell-validation job.

A controlled SEN-026 test confirmed that a syntax-invalid shell script causes GitHub Actions to fail with a non-zero result.

After the synthetic invalid script was removed, the final CI recovery run returned:

```text
Shell validation: PASS
Secret safety: PASS
```

Remaining CI requirements are:

```text
FR-48: Docker Project Validation
FR-49: Application Behaviour Validation
```

These remain separate follow-up work that should build on the SEN-026 GitHub Actions foundation.