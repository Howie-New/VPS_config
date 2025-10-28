# VPS Proxy Setup Guide with Nginx, TLS, and Xray

This guide provides detailed instructions for setting up a proxy server using Nginx as a reverse proxy with TLS encryption and Xray.

## Prerequisites

- Ubuntu 24.04 LTS
- Root access to the server
- A domain name pointing to your server
- Basic knowledge of Linux commands

## 1. System Preparation

### Update System Packages
```bash
apt update
apt upgrade
```

### Enable BBR TCP Congestion Control
BBR (Bottleneck Bandwidth and RTT) is a TCP congestion control algorithm that can improve network performance.

Check current congestion control algorithm:
```bash
sysctl net.ipv4.tcp_congestion_control
```

If not using BBR, enable it:
```bash
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
```

## 2. Domain Configuration

Before proceeding, ensure your domain's DNS records are properly configured:
```bash
dig +short A your-domain.com
dig +short AAAA your-domain.com
```

These commands should return your server's IPv4 and IPv6 addresses respectively.

## 3. Nginx Installation and Configuration

### Install Nginx
```bash
apt install -y nginx
systemctl enable --now nginx
```

Verify Nginx installation:
```bash
nginx -t
systemctl status nginx
```

## 4. SSL Certificate Management with acme.sh

### Install acme.sh
```bash
curl https://get.acme.sh | sh -s email=your-email@example.com
```

### Configure acme.sh
```bash
ln -s /root/.acme.sh/acme.sh /usr/local/bin/acme.sh
acme.sh --set-default-ca --server letsencrypt
```

### Issue Certificate
```bash
acme.sh --issue --nginx -d your-domain.com
```

### Install Certificate for Nginx
```bash
acme.sh --install-cert -d your-domain.com \
  --key-file       /etc/nginx/ssl/your-domain.com.key \
  --fullchain-file /etc/nginx/ssl/your-domain.com.fullchain.pem \
  --reloadcmd     "service nginx reload"
```

## 5. Nginx Configuration

### Update Main Nginx Configuration
Edit `/etc/nginx/nginx.conf` to add WebSocket support:
```nginx
# Add in http block
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}
```

### Configure Site-Specific Settings
Create a new configuration file for your domain with TLS and proxy settings.

The configuration includes:
- TLS 1.2/1.3 support
- WebSocket proxy for Xray
- HTTP to HTTPS redirection
- Custom paths for Xray and panel access
- Disguised website proxy

## Using the Setup Script

A setup script `vps_setup.sh` is provided in this repository. To use it:

1. Download the script:
```bash
wget https://raw.githubusercontent.com/your-repo/vps_setup.sh
```

2. Make it executable:
```bash
chmod +x vps_setup.sh
```

3. Edit the configuration variables:
```bash
nano vps_setup.sh
```

4. Run the script:
```bash
./vps_setup.sh
```

## Security Notes

1. Always keep your system and packages updated
2. Use strong passwords for all services
3. Regularly monitor server logs for suspicious activities
4. Keep backup of your configurations
5. Regularly update SSL certificates

## Troubleshooting

### Common Issues

1. Certificate issuance fails:
   - Verify DNS records
   - Check Nginx configuration
   - Try alternative CA server

2. Nginx won't start:
   - Check configuration syntax
   - Verify SSL certificate paths
   - Check port availability

3. Proxy connection issues:
   - Verify firewall settings
   - Check Nginx error logs
   - Verify WebSocket configuration

### Useful Commands

```bash
# Check Nginx status
systemctl status nginx

# View Nginx error logs
tail -f /var/log/nginx/error.log

# Test Nginx configuration
nginx -t

# Check certificate status
acme.sh --info -d your-domain.com
```

## Maintenance

Remember to:
- Regularly update your system
- Monitor certificate expiration
- Keep backups of your configuration
- Check logs for any issues

This setup provides a secure and efficient proxy solution with TLS encryption and websocket support.