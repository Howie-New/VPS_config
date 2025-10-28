# VPS代理服务器配置指南 (Nginx + TLS + Xray)

本指南详细介绍如何使用Nginx作为反向代理，配合TLS加密和Xray搭建代理服务器。

## 前置要求

- Ubuntu 24.04 LTS 系统
- 服务器root访问权限
- 已解析到服务器的域名
- 基本的Linux命令知识

## 1. 系统准备

### 更新系统包
```bash
apt update
apt upgrade
```

### 启用BBR TCP拥塞控制算法
BBR（Bottleneck Bandwidth and RTT）是一种TCP拥塞控制算法，可以提高网络性能。

检查当前使用的拥塞控制算法：
```bash
sysctl net.ipv4.tcp_congestion_control
```

如果不是BBR，启用它：
```bash
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
```

## 2. 域名配置

在继续之前，确保您的域名DNS记录已正确配置：
```bash
dig +short A your-domain.com
dig +short AAAA your-domain.com
```

这些命令应该返回您服务器的IPv4和IPv6地址。

## 3. Nginx安装与配置

### 安装Nginx
```bash
apt install -y nginx
systemctl enable --now nginx
```

验证Nginx安装：
```bash
nginx -t
systemctl status nginx
```

## 4. 使用acme.sh管理SSL证书

### 安装acme.sh
```bash
curl https://get.acme.sh | sh -s email=your-email@example.com
```

### 配置acme.sh
```bash
ln -s /root/.acme.sh/acme.sh /usr/local/bin/acme.sh
acme.sh --set-default-ca --server letsencrypt
```

### 申请证书
```bash
acme.sh --issue --nginx -d your-domain.com
```

### 为Nginx安装证书
```bash
acme.sh --install-cert -d your-domain.com \
  --key-file       /etc/nginx/ssl/your-domain.com.key \
  --fullchain-file /etc/nginx/ssl/your-domain.com.fullchain.pem \
  --reloadcmd     "service nginx reload"
```

## 5. Nginx配置

### 更新主Nginx配置
编辑 `/etc/nginx/nginx.conf` 添加WebSocket支持：
```nginx
# 在http块中添加
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}
```

### 配置站点特定设置
为您的域名创建新的配置文件，包含TLS和代理设置。

配置包括：
- TLS 1.2/1.3 支持
- Xray的WebSocket代理
- HTTP到HTTPS重定向
- Xray和面板访问的自定义路径
- 伪装网站代理

## 使用配置脚本

本仓库提供了配置脚本 `vps_setup.sh`。使用方法：

1. 下载脚本：
```bash
wget https://raw.githubusercontent.com/your-repo/vps_setup.sh
```

2. 添加执行权限：
```bash
chmod +x vps_setup.sh
```

3. 编辑配置变量：
```bash
nano vps_setup.sh
```

4. 运行脚本：
```bash
./vps_setup.sh
```

## 安全注意事项

1. 保持系统和软件包及时更新
2. 使用强密码保护所有服务
3. 定期监控服务器日志
4. 保持配置文件的备份
5. 定期更新SSL证书

## 故障排除

### 常见问题

1. 证书申请失败：
   - 验证DNS记录
   - 检查Nginx配置
   - 尝试更换CA服务器

2. Nginx无法启动：
   - 检查配置语法
   - 验证SSL证书路径
   - 检查端口占用情况

3. 代理连接问题：
   - 验证防火墙设置
   - 检查Nginx错误日志
   - 验证WebSocket配置

### 实用命令

```bash
# 检查Nginx状态
systemctl status nginx

# 查看Nginx错误日志
tail -f /var/log/nginx/error.log

# 测试Nginx配置
nginx -t

# 检查证书状态
acme.sh --info -d your-domain.com
```

## 维护建议

请记住：
- 定期更新系统
- 监控证书过期时间
- 保持配置文件备份
- 检查日志是否有异常

此设置提供了一个安全高效的代理解决方案，具有TLS加密和WebSocket支持。