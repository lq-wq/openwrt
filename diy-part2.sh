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
# 如果上述路径不存在，通过修改启动参数实现
if grep -q "ttyd" package/network/services/ttyd/Makefile 2>/dev/null; then
  sed -i 's/command=/command=\/usr\/bin\/login -f root /g' package/network/services/ttyd/files/ttyd.config 2>/dev/null || true
fi

# --------------------------------------------------
# 4. 内核和系统分区大小（X86 专用）
#    内核分区: 128MB，根分区: 2048MB
# --------------------------------------------------
if [ "$DEVICE" = "x86" ] || [ -z "$DEVICE" ]; then
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
# 在 /etc/openwrt_release 中添加签名
sed -i "/DISTRIB_REVISION=/c\DISTRIB_REVISION='${SIGN} ${BUILD_DATE}'" package/base-files/files/etc/openwrt_release 2>/dev/null || true

# --------------------------------------------------
# 6. 更换固件内核为 6.6
#    openwrt-25.12 默认内核为 6.12，强制切换至 6.6
# --------------------------------------------------
sed -i 's/LINUX_VERSION_6_12=.*/LINUX_VERSION_6_12=y/g' .config 2>/dev/null || true
# 如果内核版本通过 KERNEL_PATCHVER 控制，则修改
find target/linux -name "Makefile" -exec sed -i 's/KERNEL_PATCHVER:=6.12/KERNEL_PATCHVER:=6.6/g' {} \; 2>/dev/null || true
echo "CONFIG_LINUX_6_6=y" >> .config

# --------------------------------------------------
# 7. 增加 AdGuardHome 插件和核心
# --------------------------------------------------
echo "CONFIG_PACKAGE_luci-app-adguardhome=y" >> .config
echo "CONFIG_PACKAGE_adguardhome=y" >> .config
echo "CONFIG_PACKAGE_adguardhome_core=y" >> .config

# --------------------------------------------------
# 8. 千兆带宽优化 — 让 OpenWrt 跑满 1000M
# --------------------------------------------------

# 8.1 开启 Flow Offloading（流量硬件卸载）
echo "CONFIG_PACKAGE_kmod-nft-offload=y" >> .config
echo "CONFIG_PACKAGE_kmod-offload=y" >> .config

# 8.2 开启 SFE（Shortcut Forwarding Engine）加速
echo "CONFIG_PACKAGE_kmod-fast-classifier=y" >> .config
echo "CONFIG_PACKAGE_shortcut-fe=y" >> .config
echo "CONFIG_PACKAGE_shortcut-fe-cm=y" >> .config
echo "CONFIG_PACKAGE_shortcut-fe-drv=y" >> .config

# 8.3 开启 BBR 拥塞控制算法
echo "CONFIG_PACKAGE_kmod-tcp-bbr=y" >> .config

# 8.4 开启完整的 nftables + flowtable 支持
echo "CONFIG_PACKAGE_kmod-nf-flowtable=y" >> .config

# 8.5 优化内核网络参数（写入 /etc/sysctl.d/ 使其生效）
mkdir -p package/base-files/files/etc/sysctl.d
cat > package/base-files/files/etc/sysctl.d/99-network-optimize.conf << 'EOF'
# 千兆带宽优化 — 网络协议栈调优

# 最大接收/发送缓冲区
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 262144
net.core.wmem_default = 262144

# TCP 缓冲区 (min, default, max)
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# 启用 TCP 窗口缩放
net.ipv4.tcp_window_scaling = 1

# BBR 拥塞控制
net.ipv4.tcp_congestion_control = bbr

# 启用 TCP 快速打开
net.ipv4.tcp_fastopen = 3

# 增大 backlog 队列
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 4096

# 提高连接跟踪最大数
net.netfilter.nf_conntrack_max = 65535

# 缩短 TIME_WAIT 超时
net.ipv4.tcp_fin_timeout = 15

# 复用 TIME_WAIT 连接
net.ipv4.tcp_tw_reuse = 1

# 开启 TCP 选择性确认
net.ipv4.tcp_sack = 1

# 启用 MTU 探测
net.ipv4.tcp_mtu_probing = 1
EOF

# 8.6 开启 IRQ 平衡（多核CPU优化）
echo "CONFIG_PACKAGE_irqbalance=y" >> .config

# 8.7 开启网卡多队列支持（X86 专用）
echo "CONFIG_PACKAGE_kmod-r8169=y" >> .config
echo "CONFIG_PACKAGE_kmod-igb=y" >> .config
echo "CONFIG_PACKAGE_kmod-ixgbe=y" >> .config

# 8.8 关闭不必要的日志输出，减少 CPU 开销
sed -i 's/^log_level=.*/log_level=0/g' package/base-files/files/etc/config/system 2>/dev/null || true

# 重新加载配置
make defconfig
