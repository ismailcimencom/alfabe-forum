#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   Alfabe Forum - WordPress + bbPress   ${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# --- .env kontrolü / oluşturma ---
if [ ! -f .env ]; then
  echo -e "${YELLOW}.env dosyası bulunamadı.${NC}"
  echo -e "Önce ${GREEN}.env.example${NC} dosyasını kopyalayıp düzenleyin:"
  echo ""
  echo -e "   ${CYAN}cp .env.example .env${NC}"
  echo -e "   ${CYAN}nano .env${NC}"
  echo ""
  echo -e "Gerekli alanlar: ${YELLOW}DOMAIN${NC}, ${YELLOW}SSL_EMAIL${NC}"
  echo -e "Geri kalanı (şifreler) script otomatik doldurur."
  echo ""
  exit 1
fi

# .env'yi yükle
set -a; source .env; set +a

# Eksik şifreleri tamamla
NEEDS_SAVE=false

if [ -z "${DB_ROOT_PASSWORD:-}" ]; then
  DB_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -32)
  NEEDS_SAVE=true
fi

if [ -z "${DB_PASSWORD:-}" ]; then
  DB_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -32)
  NEEDS_SAVE=true
fi

if [ -z "${WP_ADMIN_PASSWORD:-}" ]; then
  WP_ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -16)
  NEEDS_SAVE=true
fi

if [ "$NEEDS_SAVE" = true ]; then
  # .env'yi güncelle (macOS/Linux uyumlu)
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/DB_ROOT_PASSWORD=$/DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD/" .env 2>/dev/null || \
    sed -i '' "s/DB_ROOT_PASSWORD=.*/DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD/" .env
    sed -i '' "s/DB_PASSWORD=$/DB_PASSWORD=$DB_PASSWORD/" .env 2>/dev/null || \
    sed -i '' "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" .env
    sed -i '' "s/WP_ADMIN_PASSWORD=$/WP_ADMIN_PASSWORD=$WP_ADMIN_PASSWORD/" .env 2>/dev/null || \
    sed -i '' "s/WP_ADMIN_PASSWORD=.*/WP_ADMIN_PASSWORD=$WP_ADMIN_PASSWORD/" .env
  else
    sed -i "s/^DB_ROOT_PASSWORD=$/DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD/" .env 2>/dev/null || \
    sed -i "s/^DB_ROOT_PASSWORD=.*/DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD/" .env
    sed -i "s/^DB_PASSWORD=$/DB_PASSWORD=$DB_PASSWORD/" .env 2>/dev/null || \
    sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" .env
    sed -i "s/^WP_ADMIN_PASSWORD=$/WP_ADMIN_PASSWORD=$WP_ADMIN_PASSWORD/" .env 2>/dev/null || \
    sed -i "s/^WP_ADMIN_PASSWORD=.*/WP_ADMIN_PASSWORD=$WP_ADMIN_PASSWORD/" .env
  fi
  echo -e "${GREEN}✓ Şifreler oluşturuldu ve .env dosyasına kaydedildi${NC}"
fi

# --- acme.json ---
mkdir -p traefik
touch traefik/acme.json
chmod 600 traefik/acme.json
echo -e "${GREEN}✓ traefik/acme.json hazır${NC}"

# --- Container'ları başlat ---
echo -e "${YELLOW}Docker container'lar başlatılıyor...${NC}"
docker compose up -d
echo -e "${GREEN}✓ Container'lar başlatıldı${NC}"

# --- WordPress kurulumu ---
echo -e "${YELLOW}WordPress'in hazır olması bekleniyor...${NC}"
for i in $(seq 1 30); do
  if docker compose exec wordpress sh -c 'test -f /var/www/html/wp-includes/version.php' 2>/dev/null; then
    break
  fi
  sleep 3
done

IS_INSTALLED=false
docker compose run --rm wp-cli core is-installed 2>/dev/null && IS_INSTALLED=true

if [ "$IS_INSTALLED" = false ]; then
  echo -e "${YELLOW}WordPress kuruluyor...${NC}"
  docker compose run --rm wp-cli core install \
    --url="https://${DOMAIN}" \
    --title="${WP_SITE_TITLE:-Alfabe Forum}" \
    --admin_user="${WP_ADMIN_USER:-admin}" \
    --admin_password="${WP_ADMIN_PASSWORD}" \
    --admin_email="${WP_ADMIN_EMAIL:-admin@alfabe.co}" \
    --skip-email
  echo -e "${GREEN}✓ WordPress kurulumu tamamlandı${NC}"

  # Dil
  if [ "${WP_LOCALE:-}" = "tr_TR" ]; then
    docker compose run --rm wp-cli language core install tr_TR 2>/dev/null || true
    docker compose run --rm wp-cli site switch-language tr_TR 2>/dev/null || true
    echo -e "${GREEN}✓ Türkçe dil desteği eklendi${NC}"
  fi

  # Permalink
  docker compose run --rm wp-cli rewrite structure '/%postname%/'
  docker compose run --rm wp-cli rewrite flush

  # bbPress forum eklentisi
  echo -e "${YELLOW}bbPress forum eklentisi kuruluyor...${NC}"
  docker compose run --rm wp-cli plugin install bbpress --activate
  echo -e "${GREEN}✓ bbPress kurulumu tamamlandı${NC}"

else
  echo -e "${GREEN}✓ WordPress zaten kurulu${NC}"
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}  Kurulum tamamlandı!${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "  Site:       ${YELLOW}https://${DOMAIN}${NC}"
echo -e "  Yönetici:   ${YELLOW}https://${DOMAIN}/wp-admin${NC}"
echo -e "  Kullanıcı:  ${WP_ADMIN_USER:-admin}"
echo -e "  Şifre:      ${YELLOW}$WP_ADMIN_PASSWORD${NC}"
echo -e "${CYAN}----------------------------------------${NC}"
echo -e "  DNS ayarlarını ${DOMAIN} → sunucu IP'sine yapmayı unutmayın!"
echo -e "  SSL sertifikası Let's Encrypt ile otomatik oluşacak."
echo -e "${CYAN}========================================${NC}"
