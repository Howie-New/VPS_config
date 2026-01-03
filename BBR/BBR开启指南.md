# Ubuntu VPS BBR 拥塞控制开启指南

BBR（Bottleneck Bandwidth and Round-trip propagation time）是 Google 推出的 TCP 拥塞控制算法，能显著提升网络吞吐和降低延迟，适用于 IPv4/IPv6。BBR 结合 fq 队列调度器可进一步优化队列管理。

## BBR 优势详解
- **高吞吐**：充分利用带宽，提升大流量场景下的传输速率。
- **低延迟**：有效减少排队延迟，提升实时性。
- **自适应**：根据链路状况动态调整，适合多种网络环境。

## 步骤概览
1. 写入 BBR 配置文件
2. 立即应用配置
3. 验证 BBR 是否启用

---

## 1. 写入 BBR 配置文件
```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/99-bbr.conf
# 使用 fq 队列调度器以配合 BBR
net.core.default_qdisc=fq
# 将拥塞控制算法切换为 BBR
net.ipv4.tcp_congestion_control=bbr
EOF
```

## 2. 立即应用配置
```bash
sudo sysctl --system
```

## 3. 验证 BBR 是否启用
```bash
# 查看当前拥塞控制算法
sysctl net.ipv4.tcp_congestion_control
# 查看可用算法
sysctl net.ipv4.tcp_available_congestion_control
# 确认模块已加载
lsmod | grep bbr
```

- 若显示 `net.ipv4.tcp_congestion_control = bbr`，且 `tcp_bbr` 模块已加载，则 BBR 已成功启用。

---

## 一键脚本使用说明

你可以直接运行 `enable_bbr.sh` 脚本自动完成上述所有步骤。

```bash
bash enable_bbr.sh
```

---

> 本脚本适用于 Ubuntu 18.04/20.04/22.04 及以上，需具备 root 权限。
