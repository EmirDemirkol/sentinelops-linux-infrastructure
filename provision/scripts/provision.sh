#!/usr/bin/env bash

set -Eeuo pipefail

TARGET_USER="emir"
TARGET_GROUP="emir"
TARGET_HOME="/home/${TARGET_USER}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROVISION_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

APP_SOURCE="${PROVISION_DIR}/application"
MONITORING_SOURCE="${PROVISION_DIR}/monitoring"
BACKUP_SOURCE="${PROVISION_DIR}/backup"
NGINX_SOURCE="${PROVISION_DIR}/nginx"
SYSTEMD_SOURCE="${PROVISION_DIR}/systemd"
SSH_SOURCE="${PROVISION_DIR}/ssh"

APP_DIR="${TARGET_HOME}/sentinelops-app"
MONITORING_DIR="${TARGET_HOME}/sentinelops-monitoring"
BACKUP_ROOT="${TARGET_HOME}/backups"
BACKUP_DIR="${BACKUP_ROOT}/sentinelops"
LOG_DIR="/var/log/sentinelops"
LOG_FILE="${LOG_DIR}/health-check.log"

MIN_FREE_KB=1048576

log() {
    printf '\n[SEN-025] %s\n' "$1"
}

info() {
    printf '[SEN-025] INFO: %s\n' "$1"
}

fail() {
    printf '[SEN-025] ERROR: %s\n' "$1" >&2
    exit 1
}

on_error() {
    local exit_code="$1"
    local line_number="$2"
    local command="$3"

    printf '\n[SEN-025] ERROR: Provisioning stopped unexpectedly.\n' >&2
    printf '[SEN-025] ERROR: Exit code: %s\n' "$exit_code" >&2
    printf '[SEN-025] ERROR: Line: %s\n' "$line_number" >&2
    printf '[SEN-025] ERROR: Command: %s\n' "$command" >&2

    exit "$exit_code"
}

trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        fail "provision.sh must be run as root. Run: sudo ./provision/scripts/provision.sh"
    fi
}

validate_operating_system() {
    log "Preflight: validating supported operating system"

    if [[ ! -f /etc/os-release ]]; then
        fail "/etc/os-release was not found."
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "${ID:-}" != "ubuntu" ]]; then
        fail "SentinelOps provisioning supports Ubuntu only. Detected ID=${ID:-unknown}"
    fi

    if [[ "${VERSION_ID:-}" != "24.04" ]]; then
        fail "SentinelOps provisioning currently supports Ubuntu 24.04 LTS. Detected VERSION_ID=${VERSION_ID:-unknown}"
    fi

    local architecture
    architecture="$(dpkg --print-architecture)"

    case "$architecture" in
        amd64|arm64)
            ;;
        *)
            fail "Unsupported architecture '${architecture}'. Supported architectures are amd64 and arm64."
            ;;
    esac

    echo "Supported operating system detected:"
    echo "${PRETTY_NAME:-Ubuntu 24.04 LTS}"
    echo "Architecture: ${architecture}"
}

validate_target_user() {
    log "Preflight: validating target user and group"

    if ! id "$TARGET_USER" >/dev/null 2>&1; then
        fail "Required user '${TARGET_USER}' does not exist."
    fi

    if ! getent group "$TARGET_GROUP" >/dev/null 2>&1; then
        fail "Required group '${TARGET_GROUP}' does not exist."
    fi

    if [[ ! -d "$TARGET_HOME" ]]; then
        fail "Expected target home directory '${TARGET_HOME}' does not exist."
    fi

    local actual_home
    actual_home="$(
        getent passwd "$TARGET_USER" |
            cut -d: -f6
    )"

    if [[ "$actual_home" != "$TARGET_HOME" ]]; then
        fail "User '${TARGET_USER}' has home '${actual_home}', expected '${TARGET_HOME}'."
    fi

    echo "Target user: ${TARGET_USER}"
    echo "Target group: ${TARGET_GROUP}"
    echo "Target home: ${TARGET_HOME}"
}

validate_source_assets() {
    log "Preflight: validating provisioning source assets"

    local required_files=(
        "${APP_SOURCE}/Dockerfile"
        "${APP_SOURCE}/compose.yaml"
        "${APP_SOURCE}/index.html"
        "${MONITORING_SOURCE}/health-check.sh"
        "${BACKUP_SOURCE}/backup-sentinelops.sh"
        "${NGINX_SOURCE}/sentinelops"
        "${SYSTEMD_SOURCE}/sentinelops-backup.service"
        "${SYSTEMD_SOURCE}/sentinelops-backup.timer"
        "${SSH_SOURCE}/00-sentinelops.conf"
    )

    local file

    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            fail "Required provisioning asset missing: ${file}"
        fi

        if [[ ! -r "$file" ]]; then
            fail "Required provisioning asset is not readable: ${file}"
        fi

        echo "Found: ${file}"
    done
}

validate_source_syntax() {
    log "Preflight: validating repository-managed shell scripts"

    if ! bash -n "${MONITORING_SOURCE}/health-check.sh"; then
        fail "Monitoring script failed Bash syntax validation."
    fi

    if ! bash -n "${BACKUP_SOURCE}/backup-sentinelops.sh"; then
        fail "Backup script failed Bash syntax validation."
    fi

    echo "Monitoring script syntax: valid"
    echo "Backup script syntax: valid"
}

validate_ssh_key_readiness() {
    log "Preflight: validating SSH public-key readiness"

    local ssh_dir="${TARGET_HOME}/.ssh"
    local authorized_keys="${ssh_dir}/authorized_keys"

    if [[ ! -d "$ssh_dir" ]]; then
        fail "SSH directory '${ssh_dir}' does not exist. Configure key-based SSH access before applying SentinelOps SSH hardening."
    fi

    if [[ ! -f "$authorized_keys" ]]; then
        fail "SSH authorized_keys file '${authorized_keys}' does not exist. Configure key-based SSH access before applying SentinelOps SSH hardening."
    fi

    if [[ ! -s "$authorized_keys" ]]; then
        fail "SSH authorized_keys file '${authorized_keys}' is empty."
    fi

    if ! grep -Eq \
        '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-[^[:space:]]+)[[:space:]]+' \
        "$authorized_keys"; then
        fail "No recognised SSH public key was found in '${authorized_keys}'."
    fi

    echo "SSH authorized_keys exists and contains a recognised public key."
}

validate_disk_space() {
    log "Preflight: validating available filesystem capacity"

    local available_kb
    available_kb="$(
        df -Pk / |
            awk 'NR == 2 {print $4}'
    )"

    if [[ ! "$available_kb" =~ ^[0-9]+$ ]]; then
        fail "Unable to determine available space on the root filesystem."
    fi

    echo "Available root filesystem space: ${available_kb} KiB"
    echo "Required minimum free space: ${MIN_FREE_KB} KiB"

    if (( available_kb < MIN_FREE_KB )); then
        fail "Insufficient free space on /. At least 1 GiB is required before provisioning."
    fi

    echo "Filesystem capacity preflight passed."
}

validate_repository_resolution() {
    log "Preflight: validating required repository name resolution"

    local host

    for host in \
        ports.ubuntu.com \
        archive.ubuntu.com \
        security.ubuntu.com \
        download.docker.com
    do
        if getent ahosts "$host" >/dev/null 2>&1; then
            echo "Resolvable: ${host}"
        else
            case "$host" in
                ports.ubuntu.com|archive.ubuntu.com|security.ubuntu.com)
                    info "Ubuntu mirror hostname '${host}' did not resolve on this architecture/network; continuing because Ubuntu mirror selection can vary."
                    ;;
                download.docker.com)
                    fail "Required Docker repository host '${host}' could not be resolved."
                    ;;
            esac
        fi
    done
}

validate_managed_paths() {
    log "Preflight: validating managed configuration paths"

    local nginx_enabled="/etc/nginx/sites-enabled/sentinelops"

    if [[ -e "$nginx_enabled" && ! -L "$nginx_enabled" ]]; then
        fail "Managed Nginx path '${nginx_enabled}' exists but is not a symbolic link. Refusing to overwrite unexpected configuration."
    fi

    if [[ -L "$nginx_enabled" ]]; then
        local current_target
        current_target="$(readlink "$nginx_enabled")"

        echo "Existing SentinelOps Nginx symlink target: ${current_target}"
    else
        echo "SentinelOps Nginx enabled-site symlink does not yet exist."
    fi
}

validate_port_conflicts() {
    log "Preflight: validating important TCP port conflicts"

    local port80_lines
    local port8000_lines

    port80_lines="$(ss -Hltnp 'sport = :80' 2>/dev/null || true)"
    port8000_lines="$(ss -Hltnp 'sport = :8000' 2>/dev/null || true)"

    if [[ -n "$port80_lines" ]]; then
        echo "Existing TCP port 80 listener detected:"
        echo "$port80_lines"

        if ! grep -q 'nginx' <<<"$port80_lines"; then
            fail "TCP port 80 is already occupied by a process other than Nginx."
        fi

        echo "Existing TCP port 80 listener is Nginx-compatible."
    else
        echo "TCP port 80 is currently available."
    fi

    if [[ -n "$port8000_lines" ]]; then
        echo "Existing TCP port 8000 listener detected:"
        echo "$port8000_lines"

        if grep -Eq \
            '0\.0\.0\.0:8000|\[::\]:8000|\*:8000' \
            <<<"$port8000_lines"; then
            fail "TCP port 8000 is externally bound before provisioning."
        fi

        if ! grep -q '127.0.0.1:8000' <<<"$port8000_lines"; then
            fail "TCP port 8000 is in use but not on the approved 127.0.0.1 interface."
        fi

        if command -v docker >/dev/null 2>&1; then
            if docker ps \
                --format '{{.Names}}' |
                grep -qx 'sentinelops-app'; then
                echo "Existing loopback TCP port 8000 listener belongs to the running SentinelOps application state."
            else
                fail "TCP port 8000 is occupied but the expected SentinelOps application container is not running."
            fi
        else
            fail "TCP port 8000 is occupied before Docker is available."
        fi
    else
        echo "TCP port 8000 is currently available."
    fi
}

run_preflight() {
    log "Starting SentinelOps provisioning preflight"

    require_root
    validate_operating_system
    validate_target_user
    validate_source_assets
    validate_source_syntax
    validate_ssh_key_readiness
    validate_disk_space
    validate_repository_resolution
    validate_managed_paths
    validate_port_conflicts

    log "Provisioning preflight completed successfully"
}

install_base_packages() {
    log "Installing base packages"

    apt-get update

    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        nginx \
        openssh-server \
        sudo \
        ufw
}

configure_docker_repository() {
    log "Configuring Docker package repository"

    install -m 0755 -d /etc/apt/keyrings

    curl -fsSL \
        https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc

    chmod a+r /etc/apt/keyrings/docker.asc

    local architecture
    local codename

    architecture="$(dpkg --print-architecture)"
    # shellcheck disable=SC1091
    codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"

    if [[ -z "$codename" ]]; then
        fail "Unable to determine Ubuntu VERSION_CODENAME for Docker repository configuration."
    fi

    cat > /etc/apt/sources.list.d/docker.sources <<DOCKER_EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${codename}
Components: stable
Architectures: ${architecture}
Signed-By: /etc/apt/keyrings/docker.asc
DOCKER_EOF

    apt-get update
}

install_docker() {
    log "Installing Docker Engine and Docker Compose"

    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    systemctl enable --now docker

    if id -nG "$TARGET_USER" |
        tr ' ' '\n' |
        grep -qx docker; then
        echo "User '${TARGET_USER}' is already a member of the docker group."
    else
        usermod -aG docker "$TARGET_USER"
        echo "Added user '${TARGET_USER}' to the docker group."
        echo "A new login session is required before the user receives the new supplementary group."
    fi
}

create_directories() {
    log "Creating SentinelOps directories"

    install -d -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0775 \
        "$APP_DIR"

    install -d -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0775 \
        "$MONITORING_DIR"

    install -d -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0775 \
        "$BACKUP_ROOT"

    install -d -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0775 \
        "$BACKUP_DIR"

    install -d -o root -g "$TARGET_GROUP" -m 0750 \
        "$LOG_DIR"

    touch "$LOG_FILE"

    chown "$TARGET_USER:$TARGET_GROUP" "$LOG_FILE"
    chmod 0640 "$LOG_FILE"
}

deploy_application() {
    log "Deploying application assets"

    install -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0664 \
        "${APP_SOURCE}/Dockerfile" \
        "${APP_DIR}/Dockerfile"

    install -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0664 \
        "${APP_SOURCE}/compose.yaml" \
        "${APP_DIR}/compose.yaml"

    install -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0664 \
        "${APP_SOURCE}/index.html" \
        "${APP_DIR}/index.html"
}

deploy_monitoring() {
    log "Deploying monitoring"

    install -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0775 \
        "${MONITORING_SOURCE}/health-check.sh" \
        "${MONITORING_DIR}/health-check.sh"
}

deploy_backup() {
    log "Deploying backup workflow"

    install -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0775 \
        "${BACKUP_SOURCE}/backup-sentinelops.sh" \
        "${BACKUP_DIR}/backup-sentinelops.sh"
}

deploy_nginx() {
    log "Deploying host Nginx configuration"

    install -o root -g root -m 0644 \
        "${NGINX_SOURCE}/sentinelops" \
        /etc/nginx/sites-available/sentinelops

    rm -f /etc/nginx/sites-enabled/default

    ln -sfn \
        /etc/nginx/sites-available/sentinelops \
        /etc/nginx/sites-enabled/sentinelops

    if ! nginx -t; then
        fail "Nginx configuration validation failed. Nginx was not restarted."
    fi

    systemctl enable --now nginx
    systemctl restart nginx
}

deploy_systemd_units() {
    log "Deploying backup systemd units"

    install -o root -g root -m 0644 \
        "${SYSTEMD_SOURCE}/sentinelops-backup.service" \
        /etc/systemd/system/sentinelops-backup.service

    install -o root -g root -m 0644 \
        "${SYSTEMD_SOURCE}/sentinelops-backup.timer" \
        /etc/systemd/system/sentinelops-backup.timer

    systemctl daemon-reload
    systemctl enable --now sentinelops-backup.timer
}

deploy_ssh_hardening() {
    log "Deploying SSH hardening"

    install -o root -g root -m 0644 \
        "${SSH_SOURCE}/00-sentinelops.conf" \
        /etc/ssh/sshd_config.d/00-sentinelops.conf

    if ! sshd -t; then
        fail "SSH configuration syntax validation failed. SSH was not reloaded."
    fi

    echo "SSH configuration syntax is valid."

    if systemctl is-active --quiet ssh.service; then
        systemctl reload ssh.service
        echo "SSH service reloaded successfully."
    else
        echo "SSH service is not currently active; new SSH processes will use the hardened configuration."
    fi
}

configure_firewall() {
    log "Configuring UFW"

    ufw default deny incoming
    ufw default allow outgoing
    ufw default deny routed
    ufw logging low

    ufw allow 22/tcp
    ufw allow "Nginx HTTP"

    ufw --force enable
}

deploy_application_container() {
    log "Building and starting SentinelOps application"

    cd "$APP_DIR"

    docker compose up -d --build
}

backup_archive_exists() {
    find "$BACKUP_DIR" \
        -maxdepth 1 \
        -type f \
        -name 'sentinelops-backup-*.tar.gz' \
        -print -quit |
        grep -q .
}

ensure_initial_backup() {
    log "Ensuring SentinelOps initial backup exists"

    if backup_archive_exists; then
        echo "Existing SentinelOps backup archive found."
        echo "Skipping initial backup creation during repeated provisioning."
        return 0
    fi

    echo "No existing SentinelOps backup archive found."
    echo "Running initial SentinelOps backup."

    systemctl start sentinelops-backup.service
}

validate_services() {
    log "Validating required services"

    systemctl is-enabled nginx
    systemctl is-enabled docker
    systemctl is-enabled ssh.socket
    systemctl is-enabled sentinelops-backup.timer

    systemctl is-active nginx
    systemctl is-active docker
    systemctl is-active ssh.socket
    systemctl is-active sentinelops-backup.timer
}

validate_ssh() {
    log "Validating effective SSH security configuration"

    local effective_config

    effective_config="$(
        sshd -T |
            grep -Ei \
                'passwordauthentication|permitrootlogin|pubkeyauthentication|kbdinteractiveauthentication'
    )"

    echo "$effective_config"

    grep -qx 'permitrootlogin no' <<<"$effective_config" ||
        fail "Effective SSH configuration does not contain 'permitrootlogin no'."

    grep -qx 'pubkeyauthentication yes' <<<"$effective_config" ||
        fail "Effective SSH configuration does not contain 'pubkeyauthentication yes'."

    grep -qx 'passwordauthentication no' <<<"$effective_config" ||
        fail "Effective SSH configuration does not contain 'passwordauthentication no'."

    grep -qx 'kbdinteractiveauthentication no' <<<"$effective_config" ||
        fail "Effective SSH configuration does not contain 'kbdinteractiveauthentication no'."

    echo "Effective SSH security baseline validated."
}

validate_application() {
    log "Validating application health"

    cd "$APP_DIR"

    docker compose ps

    local backend_code
    local proxy_code

    backend_code="$(
        curl -sS \
            -o /dev/null \
            -w '%{http_code}' \
            http://127.0.0.1:8000/health
    )"

    proxy_code="$(
        curl -sS \
            -o /dev/null \
            -w '%{http_code}' \
            http://127.0.0.1/health
    )"

    echo "Backend health HTTP status: ${backend_code}"
    echo "Host Nginx health HTTP status: ${proxy_code}"

    if [[ "$backend_code" != "200" ]]; then
        fail "Backend health endpoint did not return HTTP 200. Received HTTP ${backend_code}."
    fi

    if [[ "$proxy_code" != "200" ]]; then
        fail "Host Nginx health endpoint did not return HTTP 200. Received HTTP ${proxy_code}."
    fi

    curl -sS http://127.0.0.1:8000/health
    echo
}

validate_network_security() {
    log "Validating listeners and firewall"

    ss -tulpn |
        grep -E ':22|:80|:8000'

    ufw status verbose

    if ss -tln |
        grep -Eq '0\.0\.0\.0:8000|\[::\]:8000|\*:8000'; then
        fail "Application backend port 8000 is externally bound."
    fi

    if ! ss -tln |
        grep -Eq '127\.0\.0\.1:8000'; then
        fail "Expected loopback listener 127.0.0.1:8000 was not found."
    fi

    echo "Backend port 8000 remains loopback-only."
}

validate_backup() {
    log "Validating newest backup"

    local newest_backup
    local checksum_file
    local manifest_file

    newest_backup="$(
        find "$BACKUP_DIR" \
            -maxdepth 1 \
            -type f \
            -name 'sentinelops-backup-*.tar.gz' \
            -printf '%T@ %p\n' \
            | sort -nr \
            | head -1 \
            | cut -d' ' -f2-
    )"

    if [[ -z "$newest_backup" ]]; then
        fail "No SentinelOps backup archive found."
    fi

    checksum_file="${newest_backup}.sha256"
    manifest_file="${newest_backup}.manifest"

    if [[ ! -f "$checksum_file" ]]; then
        fail "Backup checksum missing for '${newest_backup}'."
    fi

    if [[ ! -f "$manifest_file" ]]; then
        fail "Backup manifest missing for '${newest_backup}'."
    fi

    (
        cd "$BACKUP_DIR"
        sha256sum --check "$(basename "$checksum_file")"
    )

    if ! diff -u \
        "$manifest_file" \
        <(tar -tzf "$newest_backup"); then
        fail "Backup manifest validation failed for '${newest_backup}'."
    fi

    echo "Backup integrity and manifest validation passed."
}

run_monitoring_check() {
    log "Running SentinelOps monitoring check"

    if ! bash "${MONITORING_DIR}/health-check.sh"; then
        fail "SentinelOps monitoring check returned a failure."
    fi

    chown "$TARGET_USER:$TARGET_GROUP" "$LOG_FILE"
    chmod 0640 "$LOG_FILE"
}

validate_failed_units() {
    log "Checking failed systemd units"

    systemctl --failed

    if systemctl --failed --no-legend |
        grep -q .; then
        fail "Failed systemd units detected."
    fi

    echo "No failed systemd units detected."
}

main() {
    run_preflight

    install_base_packages
    configure_docker_repository
    install_docker

    create_directories

    deploy_application
    deploy_monitoring
    deploy_backup
    deploy_nginx
    deploy_systemd_units
    deploy_ssh_hardening
    configure_firewall

    deploy_application_container
    ensure_initial_backup

    validate_services
    validate_ssh
    validate_application
    validate_network_security
    validate_backup
    run_monitoring_check
    validate_failed_units

    log "SentinelOps provisioning completed successfully"
}

main "$@"