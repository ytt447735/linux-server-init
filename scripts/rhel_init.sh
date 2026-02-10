#!/bin/bash
# CentOS/RHEL Initialization Script
# Repo: https://github.com/ytt447735/linux-server-init
# 支持: CentOS 7/8, Stream 8/9

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

# 获取大版本号
OS_VERSION=$(rpm -E %{rhel})

# ================= 1. 换源逻辑 =================
function change_yum_source() {
    echo -e "${BLUE}=== 更换 Yum 源 (Aliyun) ===${PLAIN}"
    
    # 备份
    mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup 2>/dev/null

    if [ "$OS_VERSION" == "7" ]; then
        curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
    elif [ "$OS_VERSION" == "8" ]; then
        find /etc/yum.repos.d/ -name "*.repo" -exec sed -i 's/mirrorlist/#mirrorlist/g' {} \;
        find /etc/yum.repos.d/ -name "*.repo" -exec sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://mirrors.aliyun.com|g' {} \;
    elif [ "$OS_VERSION" == "9" ]; then
        curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-stream-9.repo
    fi

    echo -e "${GREEN}正在生成缓存...${PLAIN}"
    yum clean all
    yum makecache
    echo -e "${GREEN}换源完成。${PLAIN}"
}

# ================= 2. Docker 安装 =================
function install_docker() {
    echo -e "${BLUE}=== 安装 Docker ===${PLAIN}"
    yum install -y yum-utils device-mapper-persistent-data lvm2
    yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    yum install -y docker-ce docker-ce-cli containerd.io

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
    systemctl daemon-reload
    systemctl start docker
    systemctl enable docker
    echo -e "${GREEN}Docker 安装完成。${PLAIN}"
}

# ================= 3. 防火墙 (Firewalld) =================
function manage_firewall() {
    while true; do
        clear
        echo -e "${BLUE}=== 防火墙管理 (Firewalld - CentOS) ===${PLAIN}"
        echo -n "状态: "
        systemctl is-active --quiet firewalld && echo -e "${GREEN}运行中${PLAIN}" || echo -e "${RED}已停止${PLAIN}"
        echo -e "${BLUE}------------------------------${PLAIN}"
        firewall-cmd --zone=public --list-ports | sed 's/ /\n/g' | sed 's/^/  - /'
        echo -e "${BLUE}------------------------------${PLAIN}"
        echo "1. 临时关闭"
        echo "2. 永久关闭"
        echo "3. 开启防火墙"
        echo "4. 添加端口"
        echo "5. 删除端口"
        echo "0. 返回"
        read -p "选择: " fw_choice

        case $fw_choice in
            1) systemctl stop firewalld ;;
            2) systemctl stop firewalld; systemctl disable firewalld ;;
            3) systemctl start firewalld; systemctl enable firewalld ;;
            4) 
                read -p "端口号: " port
                echo "1.TCP 2.UDP 3.Both"
                read -p "协议: " proto
                if [ "$proto" == "2" ]; then
                    firewall-cmd --zone=public --add-port=${port}/udp --permanent
                elif [ "$proto" == "3" ]; then
                    firewall-cmd --zone=public --add-port=${port}/tcp --permanent
                    firewall-cmd --zone=public --add-port=${port}/udp --permanent
                else
                    firewall-cmd --zone=public --add-port=${port}/tcp --permanent
                fi
                firewall-cmd --reload
                ;;
            5)
                read -p "端口号: " port
                echo "1.TCP 2.UDP 3.Both"
                read -p "协议: " proto
                if [ "$proto" == "2" ]; then
                    firewall-cmd --zone=public --remove-port=${port}/udp --permanent
                elif [ "$proto" == "3" ]; then
                    firewall-cmd --zone=public --remove-port=${port}/tcp --permanent
                    firewall-cmd --zone=public --remove-port=${port}/udp --permanent
                else
                    firewall-cmd --zone=public --remove-port=${port}/tcp --permanent
                fi
                firewall-cmd --reload
                ;;
            0) return ;;
        esac
    done
}

# ================= 主菜单 =================
_HOSTNAME=$(hostname 2>/dev/null || echo "unknown")
_OS_INFO=$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME}" || echo "CentOS/RHEL")

while true; do
    load_strings
    clear
    echo ""
    echo -e "  ${CYAN}┌──────────────────────────────────────────────┐${PLAIN}"
    echo -e "  ${CYAN}│${PLAIN}        ${GREEN}🚀 Linux Server Init${PLAIN}  ${YELLOW}v1.0.0${PLAIN}          ${CYAN}│${PLAIN}"
    echo -e "  ${CYAN}│${PLAIN}        ${L_TITLE_RHEL}          ${CYAN}│${PLAIN}"
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
        2) change_yum_source ;;
        3) sys_update "yum" ;;
        4) sync_time "yum" ;;
        5) host_config ;;
        6) install_common_tools "yum" ;;
        7) install_docker ;;
        8) install_services "yum" ;;
        9) manage_firewall ;;
        10) ssh_security ;;
        11) user_management ;;
        12) service_management ;;
        13) cron_management ;;
        14) sys_cleanup "yum" ;;
        u|U) _tool_update ;;
        v|V) _tool_version ;;
        r|R) _tool_repair ;;
        x|X) _tool_uninstall ;;
        l|L) switch_language; continue ;;
        0) exit 0 ;;
    esac
    read -p "  ${L_PRESS_ENTER}"
done