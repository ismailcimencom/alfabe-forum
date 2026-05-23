#!/bin/bash
BACKUP_DIR="/backup"
TIMESTAMP=$(date +%Y-%m-%d)
RETENTION_DAYS=7

mkdir -p "$BACKUP_DIR"

ALFABEMAIL_PASS=$(grep '^DB_PASSWORD=' /opt/alfabemail/.env | head -1 | cut -d= -f2)
FORUM_PASS=$(grep '^DB_PASSWORD=' /opt/alfabe-forum/.env | head -1 | cut -d= -f2)
FORUM_DB=$(grep '^DB_NAME=' /opt/alfabe-forum/.env | head -1 | cut -d= -f2)
FORUM_USER=$(grep '^DB_USER=' /opt/alfabe-forum/.env | head -1 | cut -d= -f2)

docker compose -f /opt/alfabemail/compose.yaml exec -T mysql \
  mysqldump -u sail -p"$ALFABEMAIL_PASS" alfabemail \
  > "$BACKUP_DIR/alfabemail_$TIMESTAMP.sql"

docker compose -f /opt/alfabe-forum/docker-compose.yml exec -T mariadb \
  mysqldump -u "$FORUM_USER" -p"$FORUM_PASS" "$FORUM_DB" \
  > "$BACKUP_DIR/forum_$TIMESTAMP.sql"

gzip -f "$BACKUP_DIR/alfabemail_$TIMESTAMP.sql"
gzip -f "$BACKUP_DIR/forum_$TIMESTAMP.sql"

find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
