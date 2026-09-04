#!/usr/bin/env bash

set -euo pipefail

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

log() {
    printf '\n[SEN-024] %s\n' "$1"
}

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "ERROR: provision.sh must be run as root."
        echo "Run: sudo ./provision/scripts/provision.sh"
        exit 1
    fi
}

validate_operating_system() {
    log "Validating supported operating system"

    if [[ ! -f /etc/os-release ]]; then
        echo "ERROR: /etc/os-release not found."
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "${ID:-}" != "ubuntu" ]]; then
        echo "ERROR: SentinelOps provisioning supports Ubuntu only."
        exit 1
    fi

    if [[ "${VERSION_ID:-}" != "24.04" ]]; then
        echo "ERROR: SentinelOps provisioning currently supports Ubuntu 24.04 LTS."
        echo "Detected VERSION_ID=${VERSION_ID:-unknown}"
        exit 1
    fi

    echo "Supported operating system detected:"
    echo "${PRETTY_NAME:-Ubuntu 24.04 LTS}"
    echo "Architecture: $(dpkg --print-architecture)"
}

validate_target_user() {
    log "Validating target user"

    if ! id "$TARGET_USER" >/dev/null 2>&1; then
        echo "ERROR: Required user '${TARGET_USER}' does not exist."
        exit 1
    fi

    if ! getent group "$TARGET_GROUP" >/dev/null 2>&1; then
        echo "ERROR: Required group '${TARGET_GROUP}' does not exist."
        exit 1
    fi

    echo "Target user: ${TARGET_USER}"
    echo "Target home: ${TARGET_HOME}"
}

validate_source_assets() {
    log "Validating provisioning source assets"

    required_files=(
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

    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo "ERROR: Required provisioning asset missing: $file"
            exit 1
        fi

        echo "Found: $file"
    done
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

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc

    chmod a+r /etc/apt/keyrings/docker.asc

    local architecture
    local codename

    architecture="$(dpkg --print-architecture)"
    codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"

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

    usermod -aG docker "$TARGET_USER"
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

    nginx -t

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

    sshd -t

    if systemctl is-active --quiet ssh.service; then
        systemctl reload ssh.service
        echo "SSH configuration syntax is valid."
        echo "SSH service reloaded successfully."
    else
        echo "SSH configuration syntax is valid."
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

run_initial_backup() {
    log "Running initial SentinelOps backup"

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

    sshd -T | grep -Ei \
        'passwordauthentication|permitrootlogin|pubkeyauthentication|kbdinteractiveauthentication'
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
        echo "ERROR: Backend health endpoint did not return HTTP 200."
        exit 1
    fi

    if [[ "$proxy_code" != "200" ]]; then
        echo "ERROR: Host Nginx health endpoint did not return HTTP 200."
        exit 1
    fi

    curl -sS http://127.0.0.1:8000/health
    echo
}

validate_network_security() {
    log "Validating listeners and firewall"

    ss -tulpn | grep -E ':22|:80|:8000'

    ufw status verbose

    if ss -tln | grep -Eq '0\.0\.0\.0:8000|\[::\]:8000'; then
        echo "ERROR: Application backend port 8000 is externally bound."
        exit 1
    fi

    if ! ss -tln | grep -Eq '127\.0\.0\.1:8000'; then
        echo "ERROR: Expected loopback listener 127.0.0.1:8000 was not found."
        exit 1
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
        echo "ERROR: No SentinelOps backup archive found."
        exit 1
    fi

    checksum_file="${newest_backup}.sha256"
    manifest_file="${newest_backup}.manifest"

    if [[ ! -f "$checksum_file" ]]; then
        echo "ERROR: Backup checksum missing."
        exit 1
    fi

    if [[ ! -f "$manifest_file" ]]; then
        echo "ERROR: Backup manifest missing."
        exit 1
    fi

    (
        cd "$BACKUP_DIR"
        sha256sum --check "$(basename "$checksum_file")"
    )

    diff -u \
        "$manifest_file" \
        <(tar -tzf "$newest_backup")

    echo "Backup integrity and manifest validation passed."
}

run_monitoring_check() {
    log "Running SentinelOps monitoring check"

    bash "${MONITORING_DIR}/health-check.sh"

    chown "$TARGET_USER:$TARGET_GROUP" "$LOG_FILE"
    chmod 0640 "$LOG_FILE"
}

validate_failed_units() {
    log "Checking failed systemd units"

    systemctl --failed

    if systemctl --failed --no-legend | grep -q .; then
        echo "ERROR: Failed systemd units detected."
        exit 1
    fi

    echo "No failed systemd units detected."
}

main() {
    require_root
    validate_operating_system
    validate_target_user
    validate_source_assets

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
    run_initial_backup

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