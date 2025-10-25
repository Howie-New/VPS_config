#!/bin/bash
# Ubuntu VPS SSL Certificate Automated Setup Script
# Usage: bash setup_ssl.sh example.com my@example.com
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

DOMAIN="$1"
EMAIL="$2"
WEBROOT="/var/www/${DOMAIN}"

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
  echo "Usage: $0 <domain> <email>"
  exit 1
fi

# 1. Update system and install nginx
apt update && apt upgrade -y
apt install -y nginx
systemctl enable --now nginx
systemctl restart nginx
systemctl status nginx

# 2. Check DNS records
echo "Checking DNS records for $DOMAIN..."
dig +short A   "$DOMAIN"
dig +short AAAA "$DOMAIN"

# 3. Setup webroot and nginx config
mkdir -p "$WEBROOT"
echo "OK: ${DOMAIN} $(date)" > "${WEBROOT}/index.html"
cat >/etc/nginx/sites-available/${DOMAIN}.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    root ${WEBROOT};
    index index.html;
}
EOF
ln -sf /etc/nginx/sites-available/${DOMAIN}.conf /etc/nginx/sites-enabled/${DOMAIN}.conf
nginx -t && systemctl reload nginx
curl -I http://$DOMAIN/ | head -n 1

# 4. Install acme.sh and issue certificate
curl https://get.acme.sh | sh -s email=$EMAIL
source ~/.bashrc 2>/dev/null || true
acme.sh --set-default-ca --server letsencrypt
acme.sh --register-account -m $EMAIL
acme.sh --issue -d "$DOMAIN" --nginx -k ec-256

# 5. Install certificate and configure HTTPS
acme.sh --install-cert -d "$DOMAIN" \
  --key-file       /etc/ssl/private/${DOMAIN}.key \
  --fullchain-file /etc/ssl/certs/${DOMAIN}.fullchain.pem \
  --reloadcmd     "systemctl reload nginx"
cat >/etc/nginx/sites-available/${DOMAIN}.conf <<EOF
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};
    ssl_certificate     /etc/ssl/certs/${DOMAIN}.fullchain.pem;
    ssl_certificate_key /etc/ssl/private/${DOMAIN}.key;
    root ${WEBROOT};
    index index.html;
}
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    return 301 https://$host$request_uri;
}
EOF
nginx -t && systemctl reload nginx
curl -I https://$DOMAIN/ | head -n 1

# 6. Show certificate list and cron job
acme.sh --list
crontab -l | grep acme.sh || true

echo "SSL setup complete for $DOMAIN."
