#!/bin/bash
# Ubuntu VPS X-UI Install & Nginx HTTPS Reverse Proxy Script
# Usage: bash setup_xui_nginx.sh <XUI_ACCOUNT> <XUI_PASSWORD> <XUI_PORT> <XUI_DOMAIN>
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

XUI_ACCOUNT="$1"
XUI_PASSWORD="$2"
XUI_PORT="$3"
XUI_DOMAIN="$4"

if [ -z "$XUI_ACCOUNT" ] || [ -z "$XUI_PASSWORD" ] || [ -z "$XUI_PORT" ] || [ -z "$XUI_DOMAIN" ]; then
  echo "Usage: $0 <XUI_ACCOUNT> <XUI_PASSWORD> <XUI_PORT> <XUI_DOMAIN>"
  exit 1
fi

# 1. Install X-UI
bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
# 用户需在安装后设置账号密码端口

# 2. Configure Nginx HTTP site for certificate issuance
cat >/etc/nginx/sites-available/${XUI_DOMAIN}.http.conf <<EOF
server {
  listen 80;
  listen [::]:80;
  server_name ${XUI_DOMAIN};
  root /var/www/${XUI_DOMAIN};
}
EOF
ln -sf /etc/nginx/sites-available/${XUI_DOMAIN}.http.conf /etc/nginx/sites-enabled/${XUI_DOMAIN}.http.conf
nginx -t && systemctl reload nginx

# 3. Issue and install SSL certificate
acme.sh --issue -d "${XUI_DOMAIN}" --nginx -k ec-256 --debug 2
acme.sh --install-cert -d "${XUI_DOMAIN}" \
  --key-file       /etc/ssl/private/${XUI_DOMAIN}.key \
  --fullchain-file /etc/ssl/certs/${XUI_DOMAIN}.fullchain.pem \
  --reloadcmd     "systemctl reload nginx"

# 4. Configure Nginx HTTPS reverse proxy
cat >/etc/nginx/sites-available/${XUI_DOMAIN}.conf <<EOF
map \$http_upgrade \$connection_upgrade { default upgrade; '' close; }

server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  server_name ${XUI_DOMAIN};
  ssl_certificate     /etc/ssl/certs/${XUI_DOMAIN}.fullchain.pem;
  ssl_certificate_key /etc/ssl/private/${XUI_DOMAIN}.key;
  location / {
    proxy_pass http://127.0.0.1:${XUI_PORT};
    proxy_http_version 1.1;
    proxy_set_header Host              \$host;
    proxy_set_header X-Real-IP         \$remote_addr;
    proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header Upgrade           \$http_upgrade;
    proxy_set_header Connection        \$connection_upgrade;
    proxy_read_timeout 300;
    proxy_send_timeout 300;
    proxy_redirect off;
  }
}

server {
  listen 80;
  listen [::]:80;
  server_name ${XUI_DOMAIN};
  return 301 https://\$host\$request_uri;
}
EOF
ln -sf /etc/nginx/sites-available/${XUI_DOMAIN}.conf /etc/nginx/sites-enabled/${XUI_DOMAIN}.conf
nginx -t && systemctl reload nginx

# 5. Clean up
rm /etc/nginx/sites-available/${XUI_DOMAIN}.http.conf

echo "X-UI and Nginx HTTPS reverse proxy setup complete. Access panel via https://${XUI_DOMAIN}/"
