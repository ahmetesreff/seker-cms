#!/usr/bin/env bash
set -euo pipefail

# =============================================================
# VPS Ilk Kurulum Scripti
# Ubuntu 22.04+ / Docker kurulu olmali
# Root olarak veya sudo ile calistirilmali
# =============================================================

SITE_DOMAIN="devbar.bar"
ADMIN_DOMAIN="admin.devbar.bar"
DEPLOY_USER="deploy"
DEPLOY_PATH="/var/www/devbar-site"
CMS_PATH="/opt/cms"

echo "=== 1. Sistem guncellemesi ==="
apt-get update && apt-get upgrade -y

echo "=== 2. Gerekli paketler ==="
apt-get install -y nginx certbot python3-certbot-nginx ufw rsync

echo "=== 3. Deploy kullanicisi olustur ==="
if ! id "$DEPLOY_USER" &>/dev/null; then
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
  echo "Deploy kullanicisi olusturuldu: $DEPLOY_USER"
fi

echo "=== 4. Site dizini olustur ==="
mkdir -p "$DEPLOY_PATH"
chown "$DEPLOY_USER":"$DEPLOY_USER" "$DEPLOY_PATH"

echo "=== 5. Deploy kullanicisina nginx reload yetkisi ==="
cat > /etc/sudoers.d/deploy-nginx <<SUDOERS
$DEPLOY_USER ALL=(ALL) NOPASSWD: /bin/systemctl reload nginx
SUDOERS
chmod 440 /etc/sudoers.d/deploy-nginx

echo "=== 6. SSH dizini ayarla ==="
DEPLOY_HOME=$(eval echo "~$DEPLOY_USER")
mkdir -p "$DEPLOY_HOME/.ssh"
chmod 700 "$DEPLOY_HOME/.ssh"
touch "$DEPLOY_HOME/.ssh/authorized_keys"
chmod 600 "$DEPLOY_HOME/.ssh/authorized_keys"
chown -R "$DEPLOY_USER":"$DEPLOY_USER" "$DEPLOY_HOME/.ssh"
echo "SSH public key'i buraya ekleyin: $DEPLOY_HOME/.ssh/authorized_keys"

echo "=== 7. CMS dizini olustur ==="
mkdir -p "$CMS_PATH"

echo "=== 8. UFW yapilandir ==="
ufw allow OpenSSH
ufw allow 'Nginx Full'
echo "y" | ufw enable || true

echo "=== 9. Nginx config kopyala ==="
cat > /etc/nginx/sites-available/devbar <<'NGINX'
# Placeholder — Gercek config cms/nginx/devbar.conf dosyasindan kopyalanmali
# Once HTTP-only ile baslayip certbot ile SSL ekleyin.

server {
    listen 80;
    server_name devbar.bar www.devbar.bar;

    root /var/www/devbar-site;
    index index.html;

    location / {
        try_files $uri $uri/index.html $uri.html /200.html;
    }
}

server {
    listen 80;
    server_name admin.devbar.bar;

    client_max_body_size 50M;

    location /hooks/ {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        proxy_pass http://127.0.0.1:1337;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
NGINX

ln -sf /etc/nginx/sites-available/devbar /etc/nginx/sites-enabled/devbar
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

echo "=== 10. SSL sertifikasi (Let's Encrypt) ==="
echo "DNS kayitlari dogru ayarlandiktan sonra calistirin:"
echo "  certbot --nginx -d $SITE_DOMAIN -d www.$SITE_DOMAIN"
echo "  certbot --nginx -d $ADMIN_DOMAIN"
echo ""
echo "Otomatik yenileme kontrol:"
echo "  certbot renew --dry-run"

echo ""
echo "=== Kurulum tamamlandi ==="
echo ""
echo "Sonraki adimlar:"
echo "  1. DNS kayitlarini VPS IP'sine yonlendirin"
echo "  2. SSH public key'i $DEPLOY_HOME/.ssh/authorized_keys dosyasina ekleyin"
echo "  3. CMS repo'yu $CMS_PATH dizinine klonlayin"
echo "  4. $CMS_PATH/.env dosyasini olusturun (.env.example'dan)"
echo "  5. cd $CMS_PATH && docker compose up -d"
echo "  6. certbot ile SSL sertifikasi alin"
echo "  7. Tam SSL config icin cms/nginx/devbar.conf dosyasini kopyalayin"
