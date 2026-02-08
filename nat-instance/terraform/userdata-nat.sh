#!/usr/bin/env bash
set -euo pipefail

# Detect egress interface dynamically (ens5 on AL2023)
EGRESS_IFACE=$(ip route | awk '/default/ {print $5; exit}')

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1
cat <<EOF > /etc/sysctl.d/99-nat.conf
net.ipv4.ip_forward = 1
EOF

# Disable rp_filter (CRITICAL for NAT)
cat <<EOF > /etc/sysctl.d/99-nat-rpfilter.conf
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.${EGRESS_IFACE}.rp_filter = 0
EOF

sysctl --system

# Install iptables stack
dnf install -y iptables iptables-nft iptables-services conntrack-tools

# Clean incorrect legacy rules
iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true

# Apply NAT rule (correct interface)
iptables -t nat -A POSTROUTING -o "${EGRESS_IFACE}" -j MASQUERADE

# Persist rules
iptables-save > /etc/sysconfig/iptables
systemctl enable iptables
systemctl restart iptables
