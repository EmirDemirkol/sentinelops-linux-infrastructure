#!/usr/bin/env bash

LOG_FILE="/var/log/sentinelops/health-check.log"

DISK_WARNING_THRESHOLD=80
DISK_CRITICAL_THRESHOLD=90

BACKUP_DIR="/home/emir/backups/sentinelops"
BACKUP_FRESHNESS_THRESHOLD_HOURS=36
BACKUP_FRESHNESS_THRESHOLD_SECONDS=$((BACKUP_FRESHNESS_THRESHOLD_HOURS * 3600))

log_result() {
    local check_name="$1"
    local status="$2"
    local severity="$3"
    local message="$4"
    local timestamp

    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    printf 'timestamp=%s check=%s status=%s severity=%s message="%s"\n' \
        "$timestamp" \
        "$check_name" \
        "$status" \
        "$severity" \
        "$message" \
        >> "$LOG_FILE"
}

echo "========================================"
echo " SentinelOps Health Check"
echo "========================================"
echo

echo "Timestamp:"
date
echo

echo "=== HOST UPTIME / LOAD ==="
uptime
echo

echo "=== MEMORY ==="
free -h
echo

echo "=== FILESYSTEM ==="
df -h /
echo

echo "=== DISK THRESHOLD CHECK ==="

DISK_USAGE="$(df -P / | awk 'NR==2 {gsub(/%/, "", $5); print $5}')"

if (( DISK_USAGE >= DISK_CRITICAL_THRESHOLD )); then
    echo "CRITICAL: Root filesystem usage is ${DISK_USAGE}%"
    log_result \
        "disk_usage" \
        "FAIL" \
        "CRITICAL" \
        "Root filesystem usage is ${DISK_USAGE}%, at or above critical threshold of ${DISK_CRITICAL_THRESHOLD}%"
elif (( DISK_USAGE >= DISK_WARNING_THRESHOLD )); then
    echo "WARNING: Root filesystem usage is ${DISK_USAGE}%"
    log_result \
        "disk_usage" \
        "PASS" \
        "WARNING" \
        "Root filesystem usage is ${DISK_USAGE}%, at or above warning threshold of ${DISK_WARNING_THRESHOLD}%"
else
    echo "OK: Root filesystem usage is ${DISK_USAGE}%"
    log_result \
        "disk_usage" \
        "PASS" \
        "INFO" \
        "Root filesystem usage is ${DISK_USAGE}%, below warning threshold of ${DISK_WARNING_THRESHOLD}%"
fi

echo

echo "=== BACKUP FRESHNESS ==="

NEWEST_BACKUP="$(
    find "$BACKUP_DIR" \
        -maxdepth 1 \
        -type f \
        -name 'sentinelops-backup-*.tar.gz' \
        -printf '%T@ %p\n' \
        | sort -nr \
        | head -1 \
        | cut -d' ' -f2-
)"

if [[ -z "$NEWEST_BACKUP" ]]; then
    echo "CRITICAL: No matching SentinelOps backup archive found"
    log_result \
        "backup_freshness" \
        "FAIL" \
        "CRITICAL" \
        "No matching SentinelOps backup archive was found"
else
    BACKUP_MTIME="$(stat -c %Y "$NEWEST_BACKUP")"
    NOW_EPOCH="$(date -u +%s)"
    BACKUP_AGE_SECONDS=$((NOW_EPOCH - BACKUP_MTIME))

    if (( BACKUP_AGE_SECONDS < 0 )); then
        echo "CRITICAL: Newest backup has a future modification timestamp"
        log_result \
            "backup_freshness" \
            "FAIL" \
            "CRITICAL" \
            "Newest backup has a future modification timestamp"
    else
        BACKUP_AGE_HOURS=$((BACKUP_AGE_SECONDS / 3600))
        BACKUP_NAME="$(basename "$NEWEST_BACKUP")"

        echo "Newest backup: $BACKUP_NAME"
        echo "Backup age: ${BACKUP_AGE_HOURS} hour(s)"

        if (( BACKUP_AGE_SECONDS <= BACKUP_FRESHNESS_THRESHOLD_SECONDS )); then
            echo "Backup freshness: OK"
            log_result \
                "backup_freshness" \
                "PASS" \
                "INFO" \
                "Newest backup ${BACKUP_NAME} is ${BACKUP_AGE_HOURS} hour(s) old, within freshness threshold of ${BACKUP_FRESHNESS_THRESHOLD_HOURS} hours"
        else
            echo "Backup freshness: CRITICAL"
            log_result \
                "backup_freshness" \
                "FAIL" \
                "CRITICAL" \
                "Newest backup ${BACKUP_NAME} is ${BACKUP_AGE_HOURS} hour(s) old, exceeding freshness threshold of ${BACKUP_FRESHNESS_THRESHOLD_HOURS} hours"
        fi
    fi
fi

echo

echo "=== FAILED SYSTEMD UNITS ==="
systemctl --failed
echo

echo "=== SERVICE HEALTH ==="

printf "Docker: "
if systemctl is-active --quiet docker; then
    echo "active"
    log_result \
        "docker_service" \
        "PASS" \
        "INFO" \
        "Docker service is active"
else
    echo "inactive"
    log_result \
        "docker_service" \
        "FAIL" \
        "CRITICAL" \
        "Docker service is not active"
fi

printf "Nginx:  "
if systemctl is-active --quiet nginx; then
    echo "active"
    log_result \
        "nginx_service" \
        "PASS" \
        "INFO" \
        "Nginx service is active"
else
    echo "inactive"
    log_result \
        "nginx_service" \
        "FAIL" \
        "CRITICAL" \
        "Nginx service is not active"
fi

printf "SSH:    "
if systemctl is-active --quiet ssh.socket; then
    echo "active"
    log_result \
        "ssh_service" \
        "PASS" \
        "INFO" \
        "SSH socket is active"
else
    echo "inactive"
    log_result \
        "ssh_service" \
        "FAIL" \
        "CRITICAL" \
        "SSH socket is not active"
fi

echo

echo "=== COMPOSE APPLICATION ==="
cd /home/emir/sentinelops-app || exit 1
docker compose ps
echo

if docker compose ps --status running --services | grep -qx "app"; then
    log_result \
        "compose_application" \
        "PASS" \
        "INFO" \
        "Compose application service is running"
else
    log_result \
        "compose_application" \
        "FAIL" \
        "CRITICAL" \
        "Compose application service is not running"
fi

echo "=== CONTAINER RESOURCE USAGE ==="
docker stats --no-stream
echo

echo "=== APPLICATION HEALTH ==="

APP_HTTP_CODE="$(curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/health || true)"

if [[ "$APP_HTTP_CODE" == "200" ]]; then
    echo "HTTP 200"
    echo "Application health endpoint reachable"
    log_result \
        "application_health" \
        "PASS" \
        "INFO" \
        "Application health endpoint returned HTTP 200"
else
    echo "HTTP ${APP_HTTP_CODE:-000}"
    echo "Application health check FAILED"
    log_result \
        "application_health" \
        "FAIL" \
        "CRITICAL" \
        "Application health endpoint returned HTTP ${APP_HTTP_CODE:-000}"
fi

echo

echo "=== HOST NGINX HEALTH ==="

NGINX_HTTP_CODE="$(curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1 || true)"

if [[ "$NGINX_HTTP_CODE" == "200" ]]; then
    echo "HTTP 200"
    echo "Nginx reachable"
    log_result \
        "host_nginx_health" \
        "PASS" \
        "INFO" \
        "Host Nginx returned HTTP 200"
else
    echo "HTTP ${NGINX_HTTP_CODE:-000}"
    echo "Nginx health check FAILED"
    log_result \
        "host_nginx_health" \
        "FAIL" \
        "CRITICAL" \
        "Host Nginx returned HTTP ${NGINX_HTTP_CODE:-000}"
fi

echo

echo "=== LISTENING TCP PORTS ==="
ss -tln
echo

echo "=== UFW ==="
sudo ufw status verbose
echo

echo "========================================"
echo " Health Check Complete"
echo "========================================"
