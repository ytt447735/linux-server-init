#!/bin/bash
# lang.sh - 中英文切换支持
# Repo: https://github.com/ytt447735/linux-server-init
# Author: ytt447735

LANG_FILE="/usr/local/lib/server-init/.lang"

# 加载保存的语言偏好
if [ -f "$LANG_FILE" ]; then
    LANG_CURRENT=$(cat "$LANG_FILE" 2>/dev/null)
else
    LANG_CURRENT="cn"
fi

# 切换语言
switch_language() {
    if [ "$LANG_CURRENT" = "cn" ]; then
        LANG_CURRENT="en"
    else
        LANG_CURRENT="cn"
    fi
    # 持久化保存 (仅在已安装时)
    if [ -d "/usr/local/lib/server-init" ]; then
        echo "$LANG_CURRENT" > "$LANG_FILE" 2>/dev/null
    fi
    load_strings
}

# 加载语言字符串
load_strings() {
    case "$LANG_CURRENT" in
        en)
            L_TITLE_RHEL="CentOS/RHEL Server Init Tool"
            L_TITLE_DEBIAN="Debian/Ubuntu Server Init Tool"
            L_CAT_INFO="Info"
            L_CAT_CONFIG="System Config"
            L_CAT_SOFTWARE="Software Install"
            L_CAT_SECURITY="Security"
            L_CAT_OPS="Operations"
            L_M1="System Overview"
            L_M2="Change Mirror Source"
            L_M3="System Update"
            L_M4="NTP Time Sync"
            L_M5="Hostname / Timezone"
            L_M6="Common Tools Install"
            L_M7="Install Docker"
            L_M8="Install Services"
            L_M9="Firewall Settings"
            L_M10="SSH Hardening"
            L_M11="User Management"
            L_M12="Service Management"
            L_M13="Cron Job Management"
            L_M14="System Cleanup"
            L_UPDATE="Update"
            L_VERSION="Version"
            L_REPAIR="Repair"
            L_UNINSTALL="Uninstall"
            L_LANG_SWITCH="中文"
            L_EXIT="Exit"
            L_PROMPT="Select"
            L_PRESS_ENTER="Press Enter to continue..."
            ;;
        *)
            L_TITLE_RHEL="CentOS/RHEL 服务器初始化工具"
            L_TITLE_DEBIAN="Debian/Ubuntu 服务器初始化工具"
            L_CAT_INFO="信息"
            L_CAT_CONFIG="系统配置"
            L_CAT_SOFTWARE="软件安装"
            L_CAT_SECURITY="安全管理"
            L_CAT_OPS="运维管理"
            L_M1="系统信息总览"
            L_M2="更换阿里源"
            L_M3="系统更新"
            L_M4="NTP 校时"
            L_M5="主机名 / 时区设置"
            L_M6="常用工具安装"
            L_M7="安装 Docker"
            L_M8="常用服务安装"
            L_M9="防火墙设置"
            L_M10="SSH 安全加固"
            L_M11="用户账号管理"
            L_M12="服务管理"
            L_M13="定时任务管理"
            L_M14="系统清理"
            L_UPDATE="更新"
            L_VERSION="版本"
            L_REPAIR="修复"
            L_UNINSTALL="卸载"
            L_LANG_SWITCH="EN"
            L_EXIT="退出"
            L_PROMPT="请选择"
            L_PRESS_ENTER="按回车继续..."
            ;;
    esac
}

# 初始化加载
load_strings
