# Ubuntu VPS 安装 X-UI 并通过 Nginx 反向代理实现 HTTPS 访问

X-UI 是一款用于管理 Xray/V2Ray 的 Web 面板，支持多协议配置。通过 Nginx 反向代理和 SSL 证书，可安全地通过 HTTPS 访问 X-UI 管理界面。

## 参数说明
- `XUI_ACCOUNT`：X-UI 管理员用户名
- `XUI_PASSWORD`：X-UI 管理员密码
- `XUI_PORT`：X-UI 后台端口（如 54321）
- `XUI_DOMAIN`：用于访问面板的子域名（如 pre.example.com）

## 步骤概览
1. 安装 X-UI
2. 设置 X-UI 账号、密码、端口
3. 配置 Nginx 80 端口站点
4. 签发并安装 SSL 证书
5. 配置 Nginx 反向代理 HTTPS
6. 清理无用配置

---

## 1. 安装 X-UI
```bash
bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
```

## 2. 设置 X-UI 账号、密码、端口
安装后请根据提示设置用户名、密码和端口。

## 3. 配置 Nginx 80 端口站点
```bash
cat >/etc/nginx/sites-available/${XUI_DOMAIN}.http.conf <<'EOF'
server {
  listen 80;
  listen [::]:80;
  server_name ${XUI_DOMAIN};
  root /var/www/${XUI_DOMAIN}; # 可不存在，仅用于证书签发
}
EOF
ln -sf /etc/nginx/sites-available/${XUI_DOMAIN}.http.conf /etc/nginx/sites-enabled/${XUI_DOMAIN}.http.conf
nginx -t && systemctl reload nginx
```

## 4. 签发并安装 SSL 证书（acme.sh）
确保域名已解析到本机。
```bash
dig +short ${XUI_DOMAIN} A
dig +short ${XUI_DOMAIN} AAAA
acme.sh --issue -d "${XUI_DOMAIN}" --nginx -k ec-256 --debug 2
acme.sh --install-cert -d "${XUI_DOMAIN}" \
  --key-file       /etc/ssl/private/${XUI_DOMAIN}.key \
  --fullchain-file /etc/ssl/certs/${XUI_DOMAIN}.fullchain.pem \
  --reloadcmd     "systemctl reload nginx"
```

## 5. 配置 Nginx 反向代理 HTTPS
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

## 6. 清理无用配置
```bash
rm /etc/nginx/sites-available/${XUI_DOMAIN}.http.conf
```

---

## 一键脚本使用说明

你可以运行 `setup_xui_nginx.sh` 自动完成上述所有步骤。

```bash
bash setup_xui_nginx.sh <XUI_ACCOUNT> <XUI_PASSWORD> <XUI_PORT> <XUI_DOMAIN>
```

- 第1参数：X-UI 管理员用户名
- 第2参数：X-UI 管理员密码
- 第3参数：X-UI 后台端口
- 第4参数：用于访问的子域名

---

> 本脚本适用于 Ubuntu 20.04/22.04 及以上，需具备 root 权限。
