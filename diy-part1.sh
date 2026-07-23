#!/bin/bash
# ============================================================
# diy-part1.sh — 添加第三方 APP 插件源码
# 在 feeds 更新之后、.config 加载之前执行
# ============================================================

# 添加主题插件
git clone https://github.com/sirpdboy/luci-theme-kucat.git package/luci-theme-kucat

# 添加快速启动插件
git clone https://github.com/lq-wq/luci-app-quickstart.git package/luci-app-quickstart

# 添加 Lucky 插件（DDNS/端口转发等）
git clone https://github.com/sirpdboy/luci-app-lucky.git package/lucky

# 添加分区扩展插件
git clone https://github.com/sirpdboy/luci-app-partexp.git package/luci-app-partexp

# 添加 OpenAppFilter（应用过滤 / 家长控制）
git clone https://github.com/destan19/OpenAppFilter.git package/OpenAppFilter

# 确保所有插件在 feeds 中注册
./scripts/feeds install -a -f
