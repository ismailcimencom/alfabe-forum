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
- Yenileme: `scripts/renew-cert.sh` (cron: `0 3 * * *`)

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

## 🔧 Geliştirme

```bash
NGINX_PORT=8081 docker compose up -d
```
