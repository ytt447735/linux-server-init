#!/bin/bash
# 主机名与时区设置公共脚本

RED=${RED:-'\033[31m'}
GREEN=${GREEN:-'\033[32m'}
YELLOW=${YELLOW:-'\033[33m'}
BLUE=${BLUE:-'\033[34m'}
CYAN='\033[36m'
PLAIN=${PLAIN:-'\033[0m'}

# ================= 主机名 / 时区设置 =================
function host_config() {
    while true; do
        clear
        echo -e "${BLUE}=== 主机名 / 时区设置 ===${PLAIN}"
        echo ""

        # 当前状态
        local CUR_HOSTNAME=$(hostname)
        local CUR_TIMEZONE=$(timedatectl 2>/dev/null | grep "Time zone" | awk '{print $3}' || cat /etc/timezone 2>/dev/null || echo "未知")
        local CUR_TIME=$(date '+%Y-%m-%d %H:%M:%S %Z')

        echo -e "  当前主机名: ${CYAN}${CUR_HOSTNAME}${PLAIN}"
        echo -e "  当前时区:   ${CYAN}${CUR_TIMEZONE}${PLAIN}"
        echo -e "  当前时间:   ${CYAN}${CUR_TIME}${PLAIN}"
        echo ""
        echo "  1. 修改主机名"
        echo "  2. 设置时区"
        echo ""
        echo "  0. 返回"
        echo ""
        read -p "  请选择 [0-2]: " hc_choice

        case $hc_choice in
            1) _set_hostname ;;
            2) _set_timezone ;;
            0) return 0 ;;
            *) continue ;;
        esac
        echo ""
        read -p "按回车继续..."
    done
}

# --- 修改主机名 ---
function _set_hostname() {
    echo ""
    local CUR_HOSTNAME=$(hostname)
    echo -e "  当前主机名: ${CYAN}${CUR_HOSTNAME}${PLAIN}"
    echo ""
    read -p "  请输入新的主机名 (留空取消): " new_hostname

    if [ -z "$new_hostname" ]; then
        echo -e "${YELLOW}  已取消${PLAIN}"
        return 0
    fi

    # 验证主机名格式 (RFC 1123)
    if ! echo "$new_hostname" | grep -qP '^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$'; then
        echo -e "${RED}  ✘ 主机名格式不合法！只能包含字母、数字和连字符，不能以连字符开头或结尾。${PLAIN}"
        return 1
    fi

    # 使用 hostnamectl 或回退方案
    if command -v hostnamectl &>/dev/null; then
        hostnamectl set-hostname "$new_hostname"
    else
        echo "$new_hostname" > /etc/hostname
        hostname "$new_hostname"
    fi

    # 更新 /etc/hosts
    if grep -q "127.0.0.1" /etc/hosts; then
        # 确保 127.0.0.1 行包含新主机名
        if ! grep -q "$new_hostname" /etc/hosts; then
            sed -i "s/127.0.0.1.*/& $new_hostname/" /etc/hosts
        fi
    fi

    echo -e "${GREEN}  ✔ 主机名已设置为: ${new_hostname}${PLAIN}"
    echo -e "${YELLOW}  提示: 重新登录 SSH 后将看到新的主机名提示符。${PLAIN}"
}

# --- 设置时区 ---
function _set_timezone() {
    echo ""
    local CUR_TZ=$(timedatectl 2>/dev/null | grep "Time zone" | awk '{print $3}' || cat /etc/timezone 2>/dev/null || echo "未知")
    echo -e "  当前时区: ${CYAN}${CUR_TZ}${PLAIN}"
    echo ""
    echo -e "  ${BLUE}--- 常用时区 ---${PLAIN}"
    echo "  1. Asia/Shanghai      (中国 - 北京/上海)"
    echo "  2. Asia/Hong_Kong     (中国 - 香港)"
    echo "  3. Asia/Taipei        (中国 - 台北)"
    echo "  4. Asia/Tokyo         (日本 - 东京)"
    echo "  5. Asia/Seoul         (韩国 - 首尔)"
    echo "  6. Asia/Singapore     (新加坡)"
    echo "  7. America/New_York   (美国 - 纽约 EST)"
    echo "  8. America/Los_Angeles(美国 - 洛杉矶 PST)"
    echo "  9. Europe/London      (英国 - 伦敦 GMT)"
    echo " 10. UTC                (世界协调时)"
    echo "  c. 手动输入时区"
    echo ""
    echo "  0. 返回"
    echo ""
    read -p "  请选择: " tz_choice

    local timezone=""
    case $tz_choice in
        1) timezone="Asia/Shanghai" ;;
        2) timezone="Asia/Hong_Kong" ;;
        3) timezone="Asia/Taipei" ;;
        4) timezone="Asia/Tokyo" ;;
        5) timezone="Asia/Seoul" ;;
        6) timezone="Asia/Singapore" ;;
        7) timezone="America/New_York" ;;
        8) timezone="America/Los_Angeles" ;;
        9) timezone="Europe/London" ;;
        10) timezone="UTC" ;;
        c|C)
            echo ""
            echo -e "${YELLOW}  提示: 输入格式如 Asia/Shanghai, America/Chicago 等${PLAIN}"
            echo -e "${YELLOW}  可通过 timedatectl list-timezones 查看所有可用时区${PLAIN}"
            read -p "  请输入时区: " timezone
            if [ -z "$timezone" ]; then
                echo -e "${YELLOW}  已取消${PLAIN}"
                return 0
            fi
            # 验证时区是否存在
            if [ ! -f "/usr/share/zoneinfo/${timezone}" ]; then
                echo -e "${RED}  ✘ 时区不存在: ${timezone}${PLAIN}"
                return 1
            fi
            ;;
        0) return 0 ;;
        *) return 0 ;;
    esac

    if [ -z "$timezone" ]; then
        return 0
    fi

    # 设置时区
    if command -v timedatectl &>/dev/null; then
        timedatectl set-timezone "$timezone"
    else
        ln -sf /usr/share/zoneinfo/${timezone} /etc/localtime
        echo "$timezone" > /etc/timezone
    fi

    echo ""
    echo -e "${GREEN}  ✔ 时区已设置为: ${timezone}${PLAIN}"
    echo -e "${GREEN}  当前时间: $(date '+%Y-%m-%d %H:%M:%S %Z')${PLAIN}"
}
