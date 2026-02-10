#!/bin/bash
# 系统信息总览公共脚本

RED=${RED:-'\033[31m'}
GREEN=${GREEN:-'\033[32m'}
YELLOW=${YELLOW:-'\033[33m'}
BLUE=${BLUE:-'\033[34m'}
CYAN='\033[36m'
MAGENTA='\033[35m'
BOLD='\033[1m'
PLAIN=${PLAIN:-'\033[0m'}

# ================= 系统信息总览 =================
function show_sys_info() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${PLAIN}"
    echo -e "${BLUE}║              ${BOLD}🖥️  系统信息总览${PLAIN}${BLUE}                               ║${PLAIN}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${PLAIN}"
    echo ""

    # 主机名
    local HOSTNAME=$(hostname)
    echo -e "  ${CYAN}主机名:${PLAIN}       ${BOLD}${HOSTNAME}${PLAIN}"

    # 操作系统
    if [ -f /etc/os-release ]; then
        local OS_NAME=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2)
    else
        local OS_NAME="Unknown"
    fi
    echo -e "  ${CYAN}操作系统:${PLAIN}     ${OS_NAME}"

    # 内核版本
    local KERNEL=$(uname -r)
    echo -e "  ${CYAN}内核版本:${PLAIN}     ${KERNEL}"

    # 系统架构
    local ARCH=$(uname -m)
    echo -e "  ${CYAN}系统架构:${PLAIN}     ${ARCH}"

    echo ""
    echo -e "  ${BLUE}──────────── CPU ────────────${PLAIN}"

    # CPU 型号
    local CPU_MODEL=$(grep 'model name' /proc/cpuinfo | head -1 | awk -F': ' '{print $2}')
    local CPU_CORES=$(grep -c 'processor' /proc/cpuinfo)
    echo -e "  ${CYAN}CPU 型号:${PLAIN}     ${CPU_MODEL:-N/A}"
    echo -e "  ${CYAN}CPU 核心:${PLAIN}     ${CPU_CORES} 核"

    echo ""
    echo -e "  ${BLUE}──────────── 内存 ────────────${PLAIN}"

    # 内存信息
    local MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    local MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
    local MEM_AVAIL=$(free -h | awk '/^Mem:/ {print $7}')
    local MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.1f", $3/$2*100}')
    echo -e "  ${CYAN}总内存:${PLAIN}       ${MEM_TOTAL}"
    echo -e "  ${CYAN}已使用:${PLAIN}       ${MEM_USED} (${MEM_PERCENT}%)"
    echo -e "  ${CYAN}可用:${PLAIN}         ${MEM_AVAIL}"

    # Swap 信息
    local SWAP_TOTAL=$(free -h | awk '/^Swap:/ {print $2}')
    local SWAP_USED=$(free -h | awk '/^Swap:/ {print $3}')
    if [ "$SWAP_TOTAL" != "0B" ] && [ -n "$SWAP_TOTAL" ]; then
        echo -e "  ${CYAN}Swap:${PLAIN}         ${SWAP_USED} / ${SWAP_TOTAL}"
    else
        echo -e "  ${CYAN}Swap:${PLAIN}         ${YELLOW}未启用${PLAIN}"
    fi

    echo ""
    echo -e "  ${BLUE}──────────── 磁盘 ────────────${PLAIN}"

    # 磁盘信息
    df -h --total 2>/dev/null | grep -E '^/|^总' | while read line; do
        local FS=$(echo "$line" | awk '{print $1}')
        local SIZE=$(echo "$line" | awk '{print $2}')
        local USED=$(echo "$line" | awk '{print $3}')
        local AVAIL=$(echo "$line" | awk '{print $4}')
        local USE_PCT=$(echo "$line" | awk '{print $5}')
        local MOUNT=$(echo "$line" | awk '{print $6}')
        echo -e "  ${CYAN}${MOUNT:-总计}${PLAIN}  ${SIZE}  已用 ${USED}(${USE_PCT})  可用 ${AVAIL}"
    done

    echo ""
    echo -e "  ${BLUE}──────────── 网络 ────────────${PLAIN}"

    # 内网 IP
    local INTERNAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo -e "  ${CYAN}内网 IP:${PLAIN}      ${INTERNAL_IP:-N/A}"

    # 公网 IP（带超时）
    local PUBLIC_IP=$(curl -s --connect-timeout 3 --max-time 5 ifconfig.me 2>/dev/null || echo "获取失败")
    echo -e "  ${CYAN}公网 IP:${PLAIN}      ${PUBLIC_IP}"

    echo ""
    echo -e "  ${BLUE}──────────── 运行状态 ────────────${PLAIN}"

    # 系统运行时间
    local UPTIME=$(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F', *[0-9]+ user' '{print $1}')
    echo -e "  ${CYAN}运行时间:${PLAIN}     ${UPTIME}"

    # 系统负载
    local LOAD=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    echo -e "  ${CYAN}系统负载:${PLAIN}     ${LOAD} (1/5/15 min)"

    # 当前登录用户数
    local USERS=$(who | wc -l)
    echo -e "  ${CYAN}登录用户:${PLAIN}     ${USERS} 个"

    # 当前时间
    local NOW=$(date '+%Y-%m-%d %H:%M:%S %Z')
    echo -e "  ${CYAN}系统时间:${PLAIN}     ${NOW}"

    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${PLAIN}"
    echo ""
}
