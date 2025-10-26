# Ubuntu VPS X-UI Installation and Nginx Reverse Proxy for HTTPS Access

X-UI is a web panel for managing Xray/V2Ray servers. By using Nginx reverse proxy and SSL certificates, you can securely access the X-UI panel via HTTPS.

## Parameter Description
- `XUI_ACCOUNT`: X-UI admin username
- `XUI_PASSWORD`: X-UI admin password
- `XUI_PORT`: X-UI backend port (e.g., 54321)
- `XUI_DOMAIN`: Subdomain for panel access (e.g., pre.example.com)

## Steps Overview
1. Install X-UI
2. Set X-UI account, password, port
3. Configure Nginx HTTP site
4. Issue and install SSL certificate
5. Configure Nginx reverse proxy for HTTPS
6. Clean up unused config

---

## 1. Install X-UI
```bash
bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
```

## 2. Set X-UI account, password, port
Set username, password, and port as prompted after installation.

## 3. Configure Nginx HTTP site
```bash
cat >/etc/nginx/sites-available/${XUI_DOMAIN}.http.conf <<'EOF'
server {
  listen 80;
  listen [::]:80;
  server_name ${XUI_DOMAIN};
  root /var/www/${XUI_DOMAIN}; # Not required, just for certificate issuance
}
EOF
ln -sf /etc/nginx/sites-available/${XUI_DOMAIN}.http.conf /etc/nginx/sites-enabled/${XUI_DOMAIN}.http.conf
nginx -t && systemctl reload nginx
```

## 4. Issue and install SSL certificate (acme.sh)
Make sure the domain resolves to this server.
```bash
dig +short ${XUI_DOMAIN} A
dig +short ${XUI_DOMAIN} AAAA
acme.sh --issue -d "${XUI_DOMAIN}" --nginx -k ec-256 --debug 2
acme.sh --install-cert -d "${XUI_DOMAIN}" \
  --key-file       /etc/ssl/private/${XUI_DOMAIN}.key \
  --fullchain-file /etc/ssl/certs/${XUI_DOMAIN}.fullchain.pem \
  --reloadcmd     "systemctl reload nginx"
```

## 5. Configure Nginx reverse proxy for HTTPS
```bash
cat >/etc/nginx/sites-available/${XUI_DOMAIN}.conf <<'EOF'
map $http_upgrade $connection_upgrade { default upgrade; '' close; }

server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  server_name ${XUI_DOMAIN};
  ssl_certificate     /etc/ssl/certs/${XUI_DOMAIN}.fullchain.pem;
  ssl_certificate_key /etc/ssl/private/${XUI_DOMAIN}.key;
  location / {
    proxy_pass http://127.0.0.1:${XUI_PORT};
    proxy_http_version 1.1;
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Upgrade           $http_upgrade;
    proxy_set_header Connection        $connection_upgrade;
    proxy_read_timeout 300;
    proxy_send_timeout 300;
    proxy_redirect off;
  }
}

server {
  listen 80;
  listen [::]:80;
  server_name ${XUI_DOMAIN};
  return 301 https://$host$request_uri;
}
EOF
ln -sf /etc/nginx/sites-available/${XUI_DOMAIN}.conf /etc/nginx/sites-enabled/${XUI_DOMAIN}.conf
nginx -t && systemctl reload nginx
```

## 6. Clean up unused config
```bash
rm /etc/nginx/sites-available/${XUI_DOMAIN}.http.conf
```

---

## One-Click Script Usage

Run `setup_xui_nginx.sh` to automate all steps above:

```bash
bash setup_xui_nginx.sh <XUI_ACCOUNT> <XUI_PASSWORD> <XUI_PORT> <XUI_DOMAIN>
```

- 1st argument: X-UI admin username
- 2nd argument: X-UI admin password
- 3rd argument: X-UI backend port
- 4th argument: subdomain for access

---

> This script is for Ubuntu 20.04/22.04+, requires root privileges.
