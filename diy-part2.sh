#!/bin/bash
# ============================================================
# diy-part2.sh — 系统配置、网络优化、固件个性化
# 在 .config 加载并 defconfig 之后执行
# ============================================================

# --------------------------------------------------
# 1. 网络配置 — 设置管理 IP 为 192.168.6.1
# --------------------------------------------------
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# --------------------------------------------------
# 2. 系统标识 — 设置主机名为 Openwrt-NIT
# --------------------------------------------------
sed -i "s/hostname='OpenWrt'/hostname='Openwrt-NIT'/g" package/base-files/files/bin/config_generate

# --------------------------------------------------
# 3. ttyd 自动登录 — 配置终端免密登录
# --------------------------------------------------
sed -i 's/^\/bin\/login/\#\/bin\/login/g' package/utils/ttyd/files/ttyd.config 2>/dev/null || true

# --------------------------------------------------
# 4. 内核和系统分区大小（X86-64 专用）
# --------------------------------------------------
if [ "$DEVICE" = "x86-64" ] || [ -z "$DEVICE" ]; then
  sed -i 's/CONFIG_TARGET_KERNEL_PARTSIZE=.*/CONFIG_TARGET_KERNEL_PARTSIZE=128/g' .config
  sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=2048/g' .config
  echo "CONFIG_TARGET_KERNEL_PARTSIZE=128" >> .config
  echo "CONFIG_TARGET_ROOTFS_PARTSIZE=2048" >> .config
fi

# --------------------------------------------------
# 5. 个性签名 — 编译者标识 + 自动日期
# --------------------------------------------------
SIGN="04543473"
BUILD_DATE=$(TZ=UTC-8 date "+%Y.%m.%d")
echo "DISTRIB_REVISION='${SIGN} ${BUILD_DATE}'" >> package/base-files/files/usr/lib/os-release 2>/dev/null || true
sed -i "/DISTRIB_REVISION=/c\DISTRIB_REVISION='${SIGN} ${BUILD_DATE}'" package/base-files/files/etc/openwrt_release 2>/dev/null || true

# --------------------------------------------------
# 6. 默认主题 — 设置为 luci-theme-argon
# --------------------------------------------------
sed -i 's/option mediaurlbase.*/option mediaurlbase "\/luci-static\/argon"/g' feeds/luci/modules/luci-base/root/etc/config/luci 2>/dev/null || true
echo "CONFIG_PACKAGE_luci-theme-argon=y" >> .config

# --------------------------------------------------
# 7. 在线固件更新插件 — luci-app-attendedsysupgrade
# --------------------------------------------------
echo "CONFIG_PACKAGE_luci-app-attendedsysupgrade=y" >> .config
echo "CONFIG_PACKAGE_attendedsysupgrade=y" >> .config

# --------------------------------------------------
# 8. 增加 AdGuardHome 插件和核心
# --------------------------------------------------
echo "CONFIG_PACKAGE_luci-app-adguardhome=y" >> .config
echo "CONFIG_PACKAGE_adguardhome=y" >> .config
echo "CONFIG_PACKAGE_adguardhome_core=y" >> .config

# --------------------------------------------------
# 9. 新增插件 — luci-app-upnp, luci-app-store, luci-app-dockerman
# --------------------------------------------------
# UPNP（miniupnpd）
echo "CONFIG_PACKAGE_luci-app-upnp=y" >> .config
echo "CONFIG_PACKAGE_miniupnpd=y" >> .config

# iStore 应用商店
echo "CONFIG_PACKAGE_luci-app-store=y" >> .config

# Docker 管理
echo "CONFIG_PACKAGE_luci-app-dockerman=y" >> .config
echo "CONFIG_PACKAGE_dockerd=y" >> .config
echo "CONFIG_PACKAGE_docker=y" >> .config
echo "CONFIG_PACKAGE_luci-lib-docker=y" >> .config

# --------------------------------------------------
# 10. OpenClash 自动下载核心
# --------------------------------------------------
echo "CONFIG_PACKAGE_luci-app-openclash=y" >> .config

# 创建 OpenClash 核心目录
mkdir -p files/etc/openclash/core

# 根据架构下载 Clash 核心（编译时自动下载）
CORE_ARCH=""
if [ "$DEVICE" = "x86-64" ]; then
  CORE_ARCH="amd64"
else
  CORE_ARCH="mipsle-softfloat"
fi

# 下载 Clash 核心（使用 clash.meta 内核）
CLASH_META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-${CORE_ARCH}.tar.gz"
echo "正在下载 OpenClash 核心（${CORE_ARCH}）..."
wget -q --no-check-certificate "$CLASH_META_URL" -O /tmp/clash.tar.gz 2>/dev/null || true
if [ -f /tmp/clash.tar.gz ]; then
  tar -xzf /tmp/clash.tar.gz -C files/etc/openclash/core/ 2>/dev/null || true
  chmod +x files/etc/openclash/core/clash* 2>/dev/null || true
  rm -f /tmp/clash.tar.gz
  echo "OpenClash 核心下载完成"
else
  echo "OpenClash 核心下载失败，固件安装后需手动下载核心"
fi

# --------------------------------------------------
# 11. 千兆带宽优化 — 让 OpenWrt 跑满 1000M
# --------------------------------------------------

# Flow Offloading
echo "CONFIG_PACKAGE_kmod-nft-offload=y" >> .config
echo "CONFIG_PACKAGE_kmod-offload=y" >> .config

# SFE 加速
echo "CONFIG_PACKAGE_kmod-fast-classifier=y" >> .config
echo "CONFIG_PACKAGE_shortcut-fe=y" >> .config
echo "CONFIG_PACKAGE_shortcut-fe-cm=y" >> .config
echo "CONFIG_PACKAGE_shortcut-fe-drv=y" >> .config

# BBR
echo "CONFIG_PACKAGE_kmod-tcp-bbr=y" >> .config

# nftables flowtable
echo "CONFIG_PACKAGE_kmod-nf-flowtable=y" >> .config

# 网络参数优化
mkdir -p package/base-files/files/etc/sysctl.d
cat > package/base-files/files/etc/sysctl.d/99-network-optimize.conf << 'EOF'
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 4096
net.netfilter.nf_conntrack_max = 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_mtu_probing = 1
EOF

# IRQ 平衡
echo "CONFIG_PACKAGE_irqbalance=y" >> .config

# 网卡驱动
echo "CONFIG_PACKAGE_kmod-r8169=y" >> .config
echo "CONFIG_PACKAGE_kmod-igb=y" >> .config
echo "CONFIG_PACKAGE_kmod-ixgbe=y" >> .config

# 关闭日志
sed -i 's/^log_level=.*/log_level=0/g' package/base-files/files/etc/config/system 2>/dev/null || true

# 重新加载配置
make defconfig
