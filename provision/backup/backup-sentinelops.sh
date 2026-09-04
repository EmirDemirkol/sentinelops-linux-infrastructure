#!/usr/bin/env bash

set -euo pipefail

BACKUP_DIR="/home/emir/backups/sentinelops"
RETENTION_MINUTES=10080
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
STAGING_DIR="$(mktemp -d)"
ARCHIVE="${BACKUP_DIR}/sentinelops-backup-${TIMESTAMP}.tar.gz"
CHECKSUM_FILE="${ARCHIVE}.sha256"
MANIFEST_FILE="${ARCHIVE}.manifest"

cleanup() {
    rm -rf "$STAGING_DIR"
}

trap cleanup EXIT

mkdir -p "$STAGING_DIR/application"
mkdir -p "$STAGING_DIR/monitoring"
mkdir -p "$STAGING_DIR/nginx"

cp /home/emir/sentinelops-app/index.html \
   "$STAGING_DIR/application/"

cp /home/emir/sentinelops-app/Dockerfile \
   "$STAGING_DIR/application/"

cp /home/emir/sentinelops-app/compose.yaml \
   "$STAGING_DIR/application/"

cp /home/emir/sentinelops-monitoring/health-check.sh \
   "$STAGING_DIR/monitoring/"

cp /etc/nginx/sites-available/sentinelops \
   "$STAGING_DIR/nginx/sentinelops"

tar -czf "$ARCHIVE" -C "$STAGING_DIR" .

chown emir:emir "$ARCHIVE"
chmod 600 "$ARCHIVE"

tar -tzf "$ARCHIVE" > "$MANIFEST_FILE"

chown emir:emir "$MANIFEST_FILE"
chmod 600 "$MANIFEST_FILE"

echo "Backup created:"
echo "$ARCHIVE"
echo

echo "Archive size:"
du -h "$ARCHIVE"
echo

echo "Backup manifest created:"
echo "$MANIFEST_FILE"
echo

echo "Verifying backup manifest:"

diff -u "$MANIFEST_FILE" <(tar -tzf "$ARCHIVE")

echo "Backup manifest verification complete."
echo

(
    cd "$BACKUP_DIR"
    sha256sum "$(basename "$ARCHIVE")" > "$(basename "$CHECKSUM_FILE")"
)

chown emir:emir "$CHECKSUM_FILE"
chmod 600 "$CHECKSUM_FILE"

echo "SHA-256 checksum created:"
echo "$CHECKSUM_FILE"
echo

echo "Verifying backup integrity:"

(
    cd "$BACKUP_DIR"
    sha256sum --check "$(basename "$CHECKSUM_FILE")"
)

echo
echo "Backup integrity verification complete."
echo

echo "Removing backup archives older than 7 days:"

while IFS= read -r OLD_ARCHIVE; do
    OLD_CHECKSUM="${OLD_ARCHIVE}.sha256"
    OLD_MANIFEST="${OLD_ARCHIVE}.manifest"

    echo "$OLD_ARCHIVE"

    if [[ -f "$OLD_CHECKSUM" ]]; then
        echo "$OLD_CHECKSUM"
        rm -f "$OLD_CHECKSUM"
    fi

    if [[ -f "$OLD_MANIFEST" ]]; then
        echo "$OLD_MANIFEST"
        rm -f "$OLD_MANIFEST"
    fi

    rm -f "$OLD_ARCHIVE"
done < <(
    find "$BACKUP_DIR" \
        -maxdepth 1 \
        -type f \
        -name 'sentinelops-backup-*.tar.gz' \
        -mmin +"$RETENTION_MINUTES" \
        -print
)

echo
echo "Backup retention complete."
