#!/bin/bash
# Debian/Ubuntu Initialization Script
# Repo: https://github.com/ytt447735/linux-server-init

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
PLAIN='\033[0m'

# 引入公共脚本
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/sys_info.sh"
source "${SCRIPT_DIR}/ntp_sync.sh"
source "${SCRIPT_DIR}/common_tools.sh"
source "${SCRIPT_DIR}/sys_update.sh"
source "${SCRIPT_DIR}/sys_cleanup.sh"
source "${SCRIPT_DIR}/user_mgmt.sh"
source "${SCRIPT_DIR}/ssh_security.sh"
source "${SCRIPT_DIR}/service_install.sh"
source "${SCRIPT_DIR}/host_config.sh"
source "${SCRIPT_DIR}/service_mgmt.sh"
source "${SCRIPT_DIR}/cron_mgmt.sh"
source "${SCRIPT_DIR}/lang.sh"
source "${SCRIPT_DIR}/tool_mgmt.sh"

# ================= 1. 换源逻辑 =================
function change_apt_source() {
    echo -e "${BLUE}=== 更换 APT 源 (Aliyun) ===${PLAIN}"
    cp /etc/apt/sources.list /etc/apt/sources.list.backup
    
    # 区分 Ubuntu 和 Debian 的域名
    if grep -q "ubuntu" /etc/os-release; then
        sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
        sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
    else
        sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list
        sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list
    fi
    
    echo -e "${GREEN}正在更新 apt 缓存...${PLAIN}"
    apt-get update
    echo -e "${GREEN}换源完成。${PLAIN}"
}

# ================= 2. Docker 安装 =================
function install_docker() {
    echo -e "${BLUE}=== 安装 Docker ===${PLAIN}"
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    # 添加 GPG Key
    curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # 添加源
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io

    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOF
{
    "registry-mirrors": [
        "https://docker.447735.xyz",
        "https://docker.1panel.live",
        "https://docker.m.daocloud.io",
        "https://mirror.ccs.tencentyun.com"
    ]
}
EOF
    systemctl restart docker
    systemctl enable docker
    echo -e "${GREEN}Docker 安装完成。${PLAIN}"
}

# ================= 3. 防火墙 (UFW) =================
function manage_firewall() {
    if ! command -v ufw &> /dev/null; then
        echo -e "${YELLOW}未检测到 UFW，正在安装...${PLAIN}"
        apt-get install -y ufw
    fi

    while true; do
        clear
        echo -e "${BLUE}=== 防火墙管理 (UFW - Debian/Ubuntu) ===${PLAIN}"
        echo -n "状态: "
        ufw status | grep "Status: active" &> /dev/null && echo -e "${GREEN}运行中${PLAIN}" || echo -e "${RED}已停止${PLAIN}"
        echo -e "${BLUE}------------------------------${PLAIN}"
        ufw status numbered
        echo -e "${BLUE}------------------------------${PLAIN}"
        echo "1. 临时关闭 (Disable)"
        echo "2. 永久关闭 (同 Disable)"
        echo "3. 开启防火墙 (Enable)"
        echo "4. 添加端口"
        echo "5. 删除端口 (按规则编号)"
        echo "0. 返回"
        read -p "选择: " fw_choice

        case $fw_choice in
            1|2) ufw disable ;;
            3) ufw enable ;;
            4) 
                read -p "端口号: " port
                echo "1.TCP 2.UDP 3.Both"
                read -p "协议: " proto
                if [ "$proto" == "2" ]; then
                    ufw allow ${port}/udp
                elif [ "$proto" == "3" ]; then
                    ufw allow ${port}
                else
                    ufw allow ${port}/tcp
                fi
                ;;
            5)
                read -p "请输入要删除的规则编号 (列表左侧的数字): " rule_num
                echo "y" | ufw delete $rule_num
                ;;
            0) return ;;
        esac
        read -p "按回车继续..."
    done
}

# ================= 主菜单 =================
_HOSTNAME=$(hostname 2>/dev/null || echo "unknown")
_OS_INFO=$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME}" || echo "Debian/Ubuntu")

while true; do
    load_strings
    clear
    echo ""
    echo -e "  ${CYAN}┌──────────────────────────────────────────────┐${PLAIN}"
    echo -e "  ${CYAN}│${PLAIN}        ${GREEN}🚀 Linux Server Init${PLAIN}  ${YELLOW}v1.0.0${PLAIN}          ${CYAN}│${PLAIN}"
    echo -e "  ${CYAN}│${PLAIN}        ${L_TITLE_DEBIAN}         ${CYAN}│${PLAIN}"
    echo -e "  ${CYAN}└──────────────────────────────────────────────┘${PLAIN}"
    echo -e "  ${PLAIN}${_OS_INFO}  ·  ${_HOSTNAME}${PLAIN}"
    echo ""
    echo -e "  ${BLUE}▸ ${L_CAT_INFO}${PLAIN}"
    echo -e "    ${GREEN} 1${PLAIN}. ${L_M1}"
    echo ""
    echo -e "  ${BLUE}▸ ${L_CAT_CONFIG}${PLAIN}"
    echo -e "    ${GREEN} 2${PLAIN}. ${L_M2}"
    echo -e "    ${GREEN} 3${PLAIN}. ${L_M3}"
    echo -e "    ${GREEN} 4${PLAIN}. ${L_M4}"
    echo -e "    ${GREEN} 5${PLAIN}. ${L_M5}"
    echo ""
    echo -e "  ${BLUE}▸ ${L_CAT_SOFTWARE}${PLAIN}"
    echo -e "    ${GREEN} 6${PLAIN}. ${L_M6}"
    echo -e "    ${GREEN} 7${PLAIN}. ${L_M7}"
    echo -e "    ${GREEN} 8${PLAIN}. ${L_M8}"
    echo ""
    echo -e "  ${BLUE}▸ ${L_CAT_SECURITY}${PLAIN}"
    echo -e "    ${GREEN} 9${PLAIN}. ${L_M9}"
    echo -e "    ${GREEN}10${PLAIN}. ${L_M10}"
    echo -e "    ${GREEN}11${PLAIN}. ${L_M11}"
    echo ""
    echo -e "  ${BLUE}▸ ${L_CAT_OPS}${PLAIN}"
    echo -e "    ${GREEN}12${PLAIN}. ${L_M12}"
    echo -e "    ${GREEN}13${PLAIN}. ${L_M13}"
    echo -e "    ${GREEN}14${PLAIN}. ${L_M14}"
    echo ""
    echo -e "  ${CYAN}──────────────────────────────────────────────${PLAIN}"
    echo -e "    ${YELLOW}u${PLAIN}) ${L_UPDATE}   ${YELLOW}v${PLAIN}) ${L_VERSION}   ${YELLOW}r${PLAIN}) ${L_REPAIR}   ${YELLOW}x${PLAIN}) ${L_UNINSTALL}   ${YELLOW}l${PLAIN}) ${L_LANG_SWITCH}"
    echo -e "  ${CYAN}──────────────────────────────────────────────${PLAIN}"
    echo ""
    echo -e "    ${GREEN} 0${PLAIN}. ${L_EXIT}"
    echo ""
    read -p "  ${L_PROMPT} [0-14/u/v/r/x/l]: " choice
    case $choice in
        1) show_sys_info ;;
        2) change_apt_source ;;
        3) sys_update "apt" ;;
        4) sync_time "apt" ;;
        5) host_config ;;
        6) install_common_tools "apt" ;;
        7) install_docker ;;
        8) install_services "apt" ;;
        9) manage_firewall ;;
        10) ssh_security ;;
        11) user_management ;;
        12) service_management ;;
        13) cron_management ;;
        14) sys_cleanup "apt" ;;
        u|U) _tool_update ;;
        v|V) _tool_version ;;
        r|R) _tool_repair ;;
        x|X) _tool_uninstall ;;
        l|L) switch_language; continue ;;
        0) exit 0 ;;
    esac
    read -p "  ${L_PRESS_ENTER}"
done