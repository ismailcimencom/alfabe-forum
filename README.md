# Alfabe Forum — Topluluk Forumu

> bbPress + WordPress tabanlı forum, forum.alfabe.co

## 🏗 Altyapı

```
forum.alfabe.co ──► Cloudflare (Full strict SSL)
                        │
                        ▼
                 alfabe-proxy (nginx:alpine, port 80/443)
                        │
                        ▼
                  wordpress:80
                (WordPress + bbPress)
                        │
                        ▼
                  mariadb:3306
```

### Servisler

| Servis | Container | Port | Ağ |
|--------|-----------|------|-----|
| **Proxy** | alfabe-proxy | `80`/`443` | `internal`, `alfabe_net` |
| **WordPress** | wordpress | `8080` → `80` | `internal` |
| **MariaDB** | mariadb | `3306` | `internal` |

### Bağımlılıklar
- `alfabe_net` — external Docker network (alfabemail ile paylaşılır)

### SSL
- Let's Encrypt + Cloudflare DNS challenge
- Sertifikalar: `/etc/letsencrypt/live/alfabe.co/`
- Yenileme: `scripts/renew-cert.sh` (cron: `0 3:30 * * *`)

### Yedekleme
- `scripts/backup.sh` — Günlük `03:00`'da her iki DB'yi `mysqldump` → gzip `/backup/`, 7 gün retention
- Kurulu cron: `0 3 * * * /opt/alfabe-forum/scripts/backup.sh >/dev/null 2>&1`

## 🚀 Kurulum

```bash
docker compose up -d
docker compose run --rm wp-cli core install \
  --url=https://forum.alfabe.co \
  --title="Alfabe Forum" \
  --admin_user=$WP_ADMIN_USER \
  --admin_password=$WP_ADMIN_PASSWORD \
  --admin_email=$WP_ADMIN_EMAIL
```

## 🛠 Pratik Komutlar

```bash
# Loglar
docker compose logs -f nginx
docker compose logs -f wordpress

# Restart
docker compose restart nginx

# Container içine gir
docker compose exec nginx sh
docker compose exec wordpress bash

# Nginx config test
docker compose exec nginx nginx -t

# Sertifika yenile (manuel)
/opt/alfabe-forum/scripts/renew-cert.sh

# Yedek al (manuel)
/opt/alfabe-forum/scripts/backup.sh
```

## ♻️ Yedekten Geri Yükleme

```bash
# Alfabemail DB
gunzip -c /backup/alfabemail_2026-05-23.sql.gz \
  | docker compose -f /opt/alfabemail/compose.yaml exec -T mysql \
    mysql -u sail -p"$DB_PASSWORD" alfabemail

# Forum DB
gunzip -c /backup/forum_2026-05-23.sql.gz \
  | docker compose exec -T mariadb \
    mysql -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME"
```

## ➕ Yeni Site Ekleme (ör. oyun.alfabe.co)

1. **DNS:** Cloudflare'de `oyun.alfabe.co` → `2.59.119.28` (A kaydı, turuncu proxy)
2. **Proxy:** `nginx/default.conf`'a yeni `server` block ekle:
   ```nginx
   server {
       listen 443 ssl;
       server_name oyun.alfabe.co;
       ssl_certificate /etc/letsencrypt/live/alfabe.co/fullchain.pem;
       ssl_certificate_key /etc/letsencrypt/live/alfabe.co/privkey.pem;
       location / {
           proxy_pass http://oyun:80;
       }
   }
   ```
3. **SSL:** Sertifikaya domain ekle: `certbot --expand -d alfabe.co -d oyun.alfabe.co`
4. **Ağ:** Yeni container'ı `alfabe_net` network'üne bağla
5. **Restart:** `docker compose restart nginx`

## 🔧 Geliştirme (Local)

```bash
NGINX_PORT=8081 docker compose up -d
```
