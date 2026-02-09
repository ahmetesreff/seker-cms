# devbar.bar — CMS

Strapi 4 + Postgres + Webhook Relay. Docker Compose ile calisir.

## Gereksinimler

- Docker & Docker Compose v2+
- Domain DNS ayarlari (admin.devbar.bar → VPS IP)

## Hizli Baslangic

```bash
# 1. Repo'yu klonla
git clone git@github.com:OWNER/cms.git /opt/cms
cd /opt/cms

# 2. Env dosyasini olustur
cp .env.example .env

# 3. Secret'lari uret
openssl rand -base64 32   # her bir *_SECRET ve *_SALT icin
openssl rand -hex 20       # HOOK_SECRET icin

# 4. .env dosyasini duzenle (nano .env)

# 5. Calistir
docker compose up -d

# 6. Strapi admin paneline git
# https://admin.devbar.bar/admin
# Ilk giriste admin kullanicisi olusturacaksiniz
```

## Environment Degiskenleri

| Degisken | Aciklama |
|---|---|
| `POSTGRES_DB` | Veritabani adi (default: strapi) |
| `POSTGRES_USER` | Veritabani kullanicisi (default: strapi) |
| `POSTGRES_PASSWORD` | Veritabani sifresi |
| `APP_KEYS` | Strapi app key'leri (virgul ile ayrilmis) |
| `API_TOKEN_SALT` | API token salt |
| `ADMIN_JWT_SECRET` | Admin JWT secret |
| `TRANSFER_TOKEN_SALT` | Transfer token salt |
| `JWT_SECRET` | JWT secret |
| `HOOK_SECRET` | Webhook dogrulama secret'i |
| `GITHUB_TOKEN` | GitHub PAT (repo dispatch yetkili) |
| `GITHUB_REPO` | Site repo (ornek: owner/site) |

## Webhook Ayari

Strapi admin panelinde:

1. Settings → Webhooks → Create new webhook
2. Name: `Rebuild Site`
3. URL: `https://admin.devbar.bar/hooks/rebuild-site`
4. Headers: `X-Hook-Secret: <HOOK_SECRET degeri>`
5. Events: Entry → Publish secin
6. Kaydet

## Content Types

### GalleryItem
- `title` (string, zorunlu)
- `coverImage` (media, tek, zorunlu)
- `images` (media, coklu)
- `videoUrl` (string)
- `order` (integer, siralama icin)

## Backup

```bash
# Manuel backup
./scripts/backup.sh

# Cron ile gunluk backup (her gece 03:00)
crontab -e
# Ekle: 0 3 * * * /opt/cms/scripts/backup.sh >> /var/log/backup.log 2>&1
```

Backup'lar `/opt/backups/cms/` altinda saklanir. 14 gunden eski backup'lar otomatik silinir.

## Yapi

```
cms/
├── docker-compose.yml
├── .env.example
├── .gitignore
├── nginx/
│   └── devbar.conf          # Nginx reverse proxy config
├── scripts/
│   ├── vps-setup.sh          # VPS ilk kurulum
│   └── backup.sh             # Postgres + uploads backup
├── strapi/
│   ├── package.json
│   ├── config/
│   │   ├── database.js
│   │   ├── server.js
│   │   ├── admin.js
│   │   ├── plugins.js
│   │   ├── middlewares.js
│   │   └── api.js
│   └── src/api/gallery-item/  # Content type
└── webhook-relay/
    ├── package.json
    └── index.js
```
