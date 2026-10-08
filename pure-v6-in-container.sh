#!/usr/bin/env bash
# ============================================================
#  容器内一键：关闭所有非 lo 网卡的 IPv4，只保留 IPv6
#  用途：客户在自己买的容器里以 root 运行，关掉 IPv4（如 Incus 内网 NAT 卡的 10.x）
#  注意：运行前请确保已有可用的 IPv6 默认路由，否则关掉 IPv4 后会断网
#  用法：bash pure-v6-in-container.sh
# ============================================================
set -uo pipefail

echo "=== 关闭 IPv4 / 只保留 IPv6 ==="

# 0. 前置检查：确认有 IPv6 默认路由
if ! ip -6 route | grep -q '^default'; then
  echo "!! 警告：当前没有 IPv6 默认路由。继续会导致断网！"
  echo "   请先确认你的 IPv6（HE 隧道/原生）已能出网，再运行本脚本。"
  printf "   仍要强制继续? [y/N]: "; read -r FORCE
  [ "${FORCE:-N}" = y ] || { echo "已中止"; exit 1; }
fi

# 1. 打印当前 IPv4（排除回环）做记录
echo "[1] 当前非回环 IPv4："
ip -4 addr show | awk '/inet / && $2 !~ /^127\./ {print "   "$2}'
[ -z "$(ip -4 addr show | awk '/inet / && $2 !~ /^127\./ {print $2}')" ] && echo "   (无)"

# 2. 立即删除所有非 lo 网卡的 IPv4 地址
echo "[2] 清除各网卡 IPv4 地址"
for dev in $(ip -o link show | awk -F': ' '{print $2}' | sed 's/@.*//' | grep -v '^lo$'); do
  ip -4 addr flush dev "$dev" 2>/dev/null && echo "   flush $dev"
done

# 3. 停掉 DHCP 客户端，防止续租把 IPv4 要回来
echo "[3] 停止 DHCP 客户端"
pkill -x udhcpc  2>/dev/null && echo "   stopped udhcpc"
pkill -x dhclient 2>/dev/null && echo "   stopped dhclient"
systemctl stop systemd-networkd 2>/dev/null; systemctl disable systemd-networkd 2>/dev/null

# 4. 改 OS 网络配置，持久禁用 IPv4（按发行版）
echo "[4] 持久化网络配置（禁用 IPv4 DHCP）"
if [ -f /etc/alpine-release ]; then
  sed -i -E 's/^(iface (eth|ens|enp|venet)[0-9]+) inet dhcp/\1 inet manual/' /etc/network/interfaces 2>/dev/null
  echo "   Alpine: /etc/network/interfaces 中 inet dhcp -> manual"
elif [ -d /etc/network ]; then
  sed -i -E 's/^(iface (eth|ens|enp|venet)[0-9]+) inet dhcp/\1 inet manual/' /etc/network/interfaces 2>/dev/null
  echo "   Debian/ifupdown: /etc/network/interfaces 已修改"
fi
if ls /etc/netplan/*.yaml >/dev/null 2>&1; then
  sed -i -E '/dhcp4:[[:space:]]*true/d' /etc/netplan/*.yaml 2>/dev/null
  netplan apply 2>/dev/null && echo "   netplan: 已移除 dhcp4"
fi

# 5. DNS 改为纯 IPv6
echo "[5] DNS 改为 IPv6"
cat > /etc/resolv.conf <<'EOF'
nameserver 2001:4860:4860::8888
nameserver 2606:4700:4700::1111
EOF

# 6. 验证
echo
echo "=== 验证结果 ==="
LEFT=$(ip -4 addr show | awk '/inet / && $2 !~ /^127\./ {print $2}')
if [ -z "$LEFT" ]; then
  echo "  [OK] 已无任何非回环 IPv4 地址（仅剩 lo 127.0.0.1）"
else
  echo "  [!!] 仍存在 IPv4: $LEFT"
fi
ip -6 route | grep -q '^default' && echo "  [OK] 有 IPv6 默认路由" || echo "  [!!] 缺少 IPv6 默认路由，可能已断网"
echo "  测试 IPv6 出网："
curl -6 -s -m 6 ipinfo.io 2>/dev/null | head -4 || echo "    (curl 测试失败，请手动确认 IPv6 出网)"
echo
echo "提示：容器重启后 IPv4 不应再出现（已改持久配置）。"
