#!/bin/bash
# Ubuntu VPS BBR Congestion Control Automated Enable Script
# Usage: bash enable_bbr.sh
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# 1. Write BBR config
cat <<EOF | tee /etc/sysctl.d/99-bbr.conf
# Use fq queue discipline for BBR
net.core.default_qdisc=fq
# Switch congestion control algorithm to BBR
net.ipv4.tcp_congestion_control=bbr
EOF

# 2. Apply config
sysctl --system

# 3. Verify
sysctl net.ipv4.tcp_congestion_control
sysctl net.ipv4.tcp_available_congestion_control
lsmod | grep bbr

echo "BBR setup complete. If you see 'net.ipv4.tcp_congestion_control = bbr' and 'tcp_bbr' module loaded, BBR is enabled."
