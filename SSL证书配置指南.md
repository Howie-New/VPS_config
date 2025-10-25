# Ubuntu VPS SSL证书配置指南

本指南将帮助你在 Ubuntu VPS 上使用 Nginx 和 acme.sh 自动化配置 SSL 证书，实现 HTTPS 访问。

## 步骤概览
1. 系统更新与安装 Nginx
2. 域名解析设置
3. 配置 Nginx 站点
4. 安装 acme.sh 并签发证书
5. 配置 Nginx HTTPS
6. 证书自动续期

---

## 1. 系统更新与安装 Nginx
```bash
apt update && apt upgrade
apt install -y nginx
systemctl enable --now nginx
systemctl restart nginx
systemctl status nginx
```

## 2. 域名解析设置
确保你的域名已正确解析到 VPS 公网 IP。
```bash
dig +short A   yourdomain.com
dig +short AAAA yourdomain.com
```

## 3. 配置 Nginx 站点
```bash
DOMAIN="example.com" # 替换为你的主域名
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

## 4. 安装 acme.sh 并签发证书
```bash
curl https://get.acme.sh | sh -s email=my@example.com
source ~/.bashrc 2>/dev/null || true
acme.sh --set-default-ca --server letsencrypt
acme.sh --register-account -m my@example.com
acme.sh --issue -d "$DOMAIN" --nginx -k ec-256
```

## 5. 安装证书并配置 HTTPS
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

## 6. 证书自动续期与检查
acme.sh 安装时会自动加入 cron 任务，证书会自动续期。
```bash
acme.sh --list
crontab -l | grep acme.sh || true
```

---

## 一键脚本使用说明

你可以直接运行 `setup_ssl.sh` 脚本自动完成上述所有步骤。

```bash
bash setup_ssl.sh example.com my@example.com
```

- 第一个参数为你的主域名
- 第二个参数为你的邮箱

---

> 本脚本适用于 Ubuntu 20.04/22.04 及以上，需具备 root 权限。
