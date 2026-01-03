# Ubuntu VPS BBR Congestion Control Enable Guide

BBR (Bottleneck Bandwidth and Round-trip propagation time) is a TCP congestion control algorithm developed by Google. It greatly improves network throughput and reduces latency, suitable for both IPv4 and IPv6. Using BBR with the fq queue discipline further optimizes queue management.

## BBR Advantages Explained
- **High Throughput**: Maximizes bandwidth usage for faster data transfer.
- **Low Latency**: Reduces queuing delay for better real-time performance.
- **Adaptive**: Dynamically adjusts to network conditions, suitable for various environments.

## Steps Overview
1. Write BBR configuration file
2. Apply configuration immediately
3. Verify BBR activation

---

## 1. Write BBR configuration file
```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/99-bbr.conf
# Use fq queue discipline for BBR
net.core.default_qdisc=fq
# Switch congestion control algorithm to BBR
net.ipv4.tcp_congestion_control=bbr
EOF
```

## 2. Apply configuration immediately
```bash
sudo sysctl --system
```

## 3. Verify BBR activation
```bash
# Check current congestion control algorithm
sysctl net.ipv4.tcp_congestion_control
# List available algorithms
sysctl net.ipv4.tcp_available_congestion_control
# Confirm module is loaded
lsmod | grep bbr
```

- If you see `net.ipv4.tcp_congestion_control = bbr` and the `tcp_bbr` module is loaded, BBR is enabled.

---

## One-Click Script Usage

You can run the `enable_bbr.sh` script to automate all steps above:

```bash
bash enable_bbr.sh
```

---

> This script is for Ubuntu 18.04/20.04/22.04+, requires root privileges.
