# Ubuntu VPS SSL Certificate Setup Guide

This guide helps you automate SSL certificate setup on Ubuntu VPS using Nginx and acme.sh for HTTPS access.

## Steps Overview
1. System Update & Nginx Installation
2. Domain DNS Setup
3. Nginx Site Configuration
4. Install acme.sh & Issue Certificate
5. Configure Nginx for HTTPS
6. Certificate Auto-Renewal

---

## 1. System Update & Nginx Installation
```bash
apt update && apt upgrade
apt install -y nginx
systemctl enable --now nginx
systemctl restart nginx
systemctl status nginx
```

## 2. Domain DNS Setup
Make sure your domain points to the VPS public IP.
```bash
dig +short A   yourdomain.com
dig +short AAAA yourdomain.com
```

## 3. Nginx Site Configuration
```bash
DOMAIN="example.com" # Replace with your domain
WEBROOT="/var/www/${DOMAIN}"
mkdir -p "$WEBROOT"
echo "OK: ${DOMAIN} $(date)" > "${WEBROOT}/index.html"
cat >/etc/nginx/sites-available/${DOMAIN}.conf <<'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER;
    root WEBROOT_PLACEHOLDER;
    index index.html;
}
EOF
sed -i "s|DOMAIN_PLACEHOLDER|${DOMAIN}|g" /etc/nginx/sites-available/${DOMAIN}.conf
sed -i "s|WEBROOT_PLACEHOLDER|${WEBROOT}|g" /etc/nginx/sites-available/${DOMAIN}.conf
ln -sf /etc/nginx/sites-available/${DOMAIN}.conf /etc/nginx/sites-enabled/${DOMAIN}.conf
nginx -t && systemctl reload nginx
curl -I http://$DOMAIN/ | head -n 1
```

## 4. Install acme.sh & Issue Certificate
```bash
curl https://get.acme.sh | sh -s email=my@example.com
source ~/.bashrc 2>/dev/null || true
acme.sh --set-default-ca --server letsencrypt
acme.sh --register-account -m my@example.com
acme.sh --issue -d "$DOMAIN" --nginx -k ec-256
```

## 5. Install Certificate & Configure HTTPS
```bash
acme.sh --install-cert -d "$DOMAIN" \
  --key-file       /etc/ssl/private/${DOMAIN}.key \
  --fullchain-file /etc/ssl/certs/${DOMAIN}.fullchain.pem \
  --reloadcmd     "systemctl reload nginx"
cat >/etc/nginx/sites-available/${DOMAIN}.conf <<'EOF'
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name DOMAIN_PLACEHOLDER;
    ssl_certificate     /etc/ssl/certs/DOMAIN_PLACEHOLDER.fullchain.pem;
    ssl_certificate_key /etc/ssl/private/DOMAIN_PLACEHOLDER.key;
    root WEBROOT_PLACEHOLDER;
    index index.html;
}
server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER;
    return 301 https://$host$request_uri;
}
EOF
sed -i "s|DOMAIN_PLACEHOLDER|${DOMAIN}|g" /etc/nginx/sites-available/${DOMAIN}.conf
sed -i "s|WEBROOT_PLACEHOLDER|${WEBROOT}|g" /etc/nginx/sites-available/${DOMAIN}.conf
nginx -t && systemctl reload nginx
curl -I https://$DOMAIN/ | head -n 1
```

## 6. Certificate Auto-Renewal & Check
acme.sh will add a cron job for auto-renewal.
```bash
acme.sh --list
crontab -l | grep acme.sh || true
```

---

## One-Click Script Usage

You can run the `setup_ssl.sh` script to automate all steps above:

```bash
bash setup_ssl.sh example.com my@example.com
```

- First argument: your domain
- Second argument: your email

---

> This script is for Ubuntu 20.04/22.04+, requires root privileges.
