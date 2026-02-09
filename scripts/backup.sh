#!/usr/bin/env bash
set -euo pipefail

# =============================================================
# Backup Scripti: Postgres dump + Uploads rsync
# Cron ile gunluk calistirilabilir:
#   0 3 * * * /opt/cms/scripts/backup.sh >> /var/log/backup.log 2>&1
# =============================================================

BACKUP_DIR="/opt/backups/cms"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
KEEP_DAYS=14

# Docker compose proje dizini
CMS_DIR="/opt/cms"

mkdir -p "$BACKUP_DIR"

echo "[$TIMESTAMP] Backup basliyor..."

# 1. Postgres dump
echo "  -> Postgres dump..."
docker compose -f "$CMS_DIR/docker-compose.yml" exec -T postgres \
  pg_dump -U strapi strapi \
  | gzip > "$BACKUP_DIR/db_$TIMESTAMP.sql.gz"

# 2. Uploads rsync
echo "  -> Uploads kopyalaniyor..."
UPLOADS_VOLUME=$(docker volume inspect cms_uploads --format '{{ .Mountpoint }}' 2>/dev/null || echo "")
if [ -n "$UPLOADS_VOLUME" ]; then
  rsync -a "$UPLOADS_VOLUME/" "$BACKUP_DIR/uploads_$TIMESTAMP/"
else
  echo "  !! uploads volume bulunamadi, atlaniyor"
fi

# 3. Eski backup'lari temizle
echo "  -> $KEEP_DAYS gunden eski backup'lar siliniyor..."
find "$BACKUP_DIR" -name "db_*.sql.gz" -mtime +$KEEP_DAYS -delete
find "$BACKUP_DIR" -maxdepth 1 -name "uploads_*" -type d -mtime +$KEEP_DAYS -exec rm -rf {} +

echo "[$TIMESTAMP] Backup tamamlandi."
echo "  DB:      $BACKUP_DIR/db_$TIMESTAMP.sql.gz"
[ -n "$UPLOADS_VOLUME" ] && echo "  Uploads: $BACKUP_DIR/uploads_$TIMESTAMP/"
