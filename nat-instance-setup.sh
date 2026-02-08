#!/usr/bin/env bash
set -euo pipefail

echo "==============================================="
echo "  NAT INSTANCE BOOTSTRAP - Amazon Linux 2023"
echo "==============================================="

#------------------------------------------------
# 1. Detect primary egress interface dynamically
#------------------------------------------------
EGRESS_IFACE=$(ip route | awk '/default/ {print $5; exit}')

if [[ -z "$EGRESS_IFACE" ]]; then
  echo "ERROR: Unable to detect egress interface"
  exit 1
fi

echo "Detected egress interface: $EGRESS_IFACE"

#------------------------------------------------
# 2. Enable IPv4 forwarding (runtime + persistent)
#------------------------------------------------
echo "Enabling IP forwarding..."

sysctl -w net.ipv4.ip_forward=1

cat <<EOF > /etc/sysctl.d/99-nat.conf
net.ipv4.ip_forward = 1
EOF

#------------------------------------------------
# 3. Disable reverse path filtering (CRITICAL)
#------------------------------------------------
echo "Disabling rp_filter (required for NAT)..."

cat <<EOF > /etc/sysctl.d/99-nat-rpfilter.conf
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.${EGRESS_IFACE}.rp_filter = 0
EOF

sysctl --system

#------------------------------------------------
# 4. Install iptables stack (AL2023 compatible)
#------------------------------------------------
echo "Installing iptables (nf_tables backend)..."

dnf install -y \
  iptables \
  iptables-nft \
  iptables-services \
  conntrack-tools

#------------------------------------------------
# 5. Clean any incorrect legacy NAT rules
#------------------------------------------------
echo "Cleaning existing NAT rules (if any)..."

iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true

#------------------------------------------------
# 6. Configure NAT (MASQUERADE on correct iface)
#------------------------------------------------
echo "Configuring NAT MASQUERADE rule..."

# Ensure idempotency
if ! iptables -t nat -C POSTROUTING -o "$EGRESS_IFACE" -j MASQUERADE 2>/dev/null; then
  iptables -t nat -A POSTROUTING -o "$EGRESS_IFACE" -j MASQUERADE
fi

#------------------------------------------------
# 7. Persist iptables rules across reboot
#------------------------------------------------
echo "Persisting iptables rules..."

iptables-save > /etc/sysconfig/iptables
systemctl enable iptables
systemctl restart iptables

#------------------------------------------------
# 8. Show final NAT status (for logs)
#------------------------------------------------
echo "==============================================="
echo " NAT INSTANCE CONFIGURATION COMPLETE"
echo "==============================================="

echo
echo "Egress interface:"
ip route | grep default || true

echo
echo "sysctl:"
sysctl net.ipv4.ip_forward
sysctl net.ipv4.conf.all.rp_filter
sysctl net.ipv4.conf.default.rp_filter

echo
echo "iptables NAT table:"
iptables -t nat -L POSTROUTING -n -v

echo
echo "NOTE:"
echo " - Ensure Source/Destination Check is DISABLED on the EC2 instance"
echo " - Ensure private subnet route table points 0.0.0.0/0 -> NAT ENI"
echo "==============================================="
