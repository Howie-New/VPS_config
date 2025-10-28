#!/bin/bash

# VPS Setup Script for Nginx + TLS + Xray
# This script automates the setup process for a proxy server with Nginx, TLS, and Xray

# Exit on any error
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables - EDIT THESE BEFORE RUNNING
DOMAIN=""           # Your domain name
EMAIL=""            # Your email for SSL certificate
DISGUISED_URL=""    # URL to disguise the proxy (e.g., "www.google.com")
UI_PORT="3000"      # Port for web UI
XRAY_PORT="10000"   # Port for Xray

# Function to print messages
print_message() {
    echo -e "${GREEN}[+] $1${NC}"
}

# Function to print errors
print_error() {
    echo -e "${RED}[!] $1${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root"
    exit 1
fi

# Check if configuration is set
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ] || [ -z "$DISGUISED_URL" ]; then
    print_error "Please edit the script and set DOMAIN, EMAIL, and DISGUISED_URL variables"
    exit 1
fi

# 1. System Update and BBR Setup
print_message "Updating system packages..."
apt update && apt upgrade -y

print_message "Configuring BBR..."
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
fi

# 2. Install Nginx
print_message "Installing Nginx..."
apt install -y nginx
systemctl enable --now nginx

# 3. Install acme.sh
print_message "Installing acme.sh..."
if [ ! -f "/root/.acme.sh/acme.sh" ]; then
    curl https://get.acme.sh | sh -s email="$EMAIL"
    ln -s /root/.acme.sh/acme.sh /usr/local/bin/acme.sh
    acme.sh --set-default-ca --server letsencrypt
fi

# 4. Create SSL directory
mkdir -p /etc/nginx/ssl

# 5. Issue certificate
print_message "Issuing SSL certificate..."
acme.sh --issue --nginx -d "$DOMAIN"
acme.sh --install-cert -d "$DOMAIN" \
    --key-file       /etc/nginx/ssl/"$DOMAIN".key \
    --fullchain-file /etc/nginx/ssl/"$DOMAIN".fullchain.pem \
    --reloadcmd     "service nginx reload"

# 6. Configure Nginx
print_message "Configuring Nginx..."

# Add WebSocket support to main config
if ! grep -q "map \$http_upgrade \$connection_upgrade" /etc/nginx/nginx.conf; then
    sed -i '/http {/a \    map $http_upgrade $connection_upgrade {\n        default upgrade;\n        \'\'\' close;\n    }' /etc/nginx/nginx.conf
fi

# Create site configuration
cat > /etc/nginx/sites-available/"$DOMAIN".conf <<EOF
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate     /etc/nginx/ssl/$DOMAIN.fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/$DOMAIN.key;

    location / {
        proxy_pass https://www.$DISGUISED_URL;
        proxy_redirect off;
        proxy_ssl_server_name on;
        sub_filter_once off;
        sub_filter "$DISGUISED_URL" \$server_name;
        proxy_set_header Host "$DISGUISED_URL";
        proxy_set_header Referer \$http_referer;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header User-Agent \$http_user_agent;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Accept-Encoding "";
        proxy_set_header Accept-Language "zh-CN";
    }
    
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;
    ssl_session_tickets off;
    ssl_protocols    TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;

    location /ray {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:$XRAY_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
    
    location /xui {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:$UI_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }
}

server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/html;
        default_type "text/plain";
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF

# Enable site configuration
ln -sf /etc/nginx/sites-available/"$DOMAIN".conf /etc/nginx/sites-enabled/

# Test and reload Nginx
print_message "Testing Nginx configuration..."
nginx -t && systemctl reload nginx

print_message "Setup completed successfully!"
print_message "Please install and configure Xray separately."
print_message "Remember to configure your firewall to allow ports 80, 443, $UI_PORT, and $XRAY_PORT"