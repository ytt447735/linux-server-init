#!/bin/bash
# Linux Server Init - Installer / 安装器
# Repo: https://github.com/ytt447735/linux-server-init
# Author: ytt447735

VERSION="1.0.0"
INSTALL_DIR="/usr/local/lib/server-init"
BIN_PATH="/usr/local/bin/server-init"
REPO_URL="https://github.com/ytt447735/linux-server-init"
BRANCH="main"

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
PLAIN='\033[0m'

MIRRORS=(
    "https://gh-proxy.org/${REPO_URL}/raw/refs/heads/${BRANCH}"
    "https://mirror.ghproxy.com/https://raw.githubusercontent.com/ytt447735/linux-server-init/${BRANCH}"
    "https://raw.githubusercontent.com/ytt447735/linux-server-init/${BRANCH}"
)

ALL_SCRIPTS=(
    "sys_info.sh" "ntp_sync.sh" "common_tools.sh" "sys_update.sh"
    "sys_cleanup.sh" "user_mgmt.sh" "ssh_security.sh" "service_install.sh"
    "host_config.sh" "service_mgmt.sh" "cron_mgmt.sh"
    "lang.sh" "tool_mgmt.sh"
    "rhel_init.sh" "debian_init.sh"
)

# ================= 工具函数 =================
download_file() {
    local url=$1 filepath=$2
    if command -v curl &> /dev/null; then
        curl -fsSL --connect-timeout 10 --max-time 30 -o "$filepath" "$url" 2>/dev/null
    else
        wget --timeout=10 -t 2 -q -O "$filepath" "$url" 2>/dev/null
    fi
}

show_progress() {
    local current=$1 total=$2 name=$3 width=25
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    local bar=$(printf '%*s' "$filled" '' | tr ' ' '█')
    local space=$(printf '%*s' "$empty" '' | tr ' ' '░')
    printf "\r  [%s%s] %3d%%  %-20s" "$bar" "$space" "$percent" "$name"
}

# ================= 生成 CLI 命令 =================
create_cli_command() {
    cat > "${BIN_PATH}" << 'LAUNCHER_EOF'
#!/bin/bash
INSTALL_DIR="/usr/local/lib/server-init"
BIN_PATH="/usr/local/bin/server-init"
REPO_URL="https://github.com/ytt447735/linux-server-init"
BRANCH="main"

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
PLAIN='\033[0m'

MIRRORS=(
    "https://gh-proxy.org/${REPO_URL}/raw/refs/heads/${BRANCH}"
    "https://mirror.ghproxy.com/https://raw.githubusercontent.com/ytt447735/linux-server-init/${BRANCH}"
    "https://raw.githubusercontent.com/ytt447735/linux-server-init/${BRANCH}"
)

ALL_SCRIPTS=(
    "sys_info.sh" "ntp_sync.sh" "common_tools.sh" "sys_update.sh"
    "sys_cleanup.sh" "user_mgmt.sh" "ssh_security.sh" "service_install.sh"
    "host_config.sh" "service_mgmt.sh" "cron_mgmt.sh"
    "lang.sh" "tool_mgmt.sh"
    "rhel_init.sh" "debian_init.sh"
)

if [ $(id -u) != "0" ]; then
    echo -e "${RED}Error: 必须使用 root 用户运行 / Must run as root${PLAIN}"
    exit 1
fi

if [ ! -d "${INSTALL_DIR}/scripts" ]; then
    echo -e "${RED}Error: 未检测到安装，请重新安装 / Not installed${PLAIN}"
    exit 1
fi

download_file() {
    local url=$1 filepath=$2
    if command -v curl &> /dev/null; then
        curl -fsSL --connect-timeout 10 --max-time 30 -o "$filepath" "$url" 2>/dev/null
    else
        wget --timeout=10 -t 2 -q -O "$filepath" "$url" 2>/dev/null
    fi
}

do_update() {
    source "${INSTALL_DIR}/scripts/tool_mgmt.sh" 2>/dev/null
    _tool_update
}

do_version() {
    source "${INSTALL_DIR}/scripts/tool_mgmt.sh" 2>/dev/null
    _tool_version
}

do_repair() {
    source "${INSTALL_DIR}/scripts/tool_mgmt.sh" 2>/dev/null
    _tool_repair
}

do_uninstall() {
    source "${INSTALL_DIR}/scripts/tool_mgmt.sh" 2>/dev/null
    _tool_uninstall
}

do_help() {
    echo -e "${GREEN}server-init${PLAIN} - Linux Server Init Tool"
    echo ""
    echo "  server-init              启动主菜单 / Launch menu"
    echo "  server-init update       在线更新 / Online update"
    echo "  server-init uninstall    卸载 / Uninstall"
    echo "  server-init version      版本 / Version"
    echo "  server-init help         帮助 / Help"
    echo ""
    echo "  ${REPO_URL}"
}

do_run() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        local OS=$ID
    else
        echo -e "${RED}无法检测操作系统 / Cannot detect OS${PLAIN}"
        exit 1
    fi
    case "$OS" in
        centos|rhel|almalinux|rocky) bash "${INSTALL_DIR}/scripts/rhel_init.sh" ;;
        ubuntu|debian) bash "${INSTALL_DIR}/scripts/debian_init.sh" ;;
        *) echo -e "${RED}不支持: ${OS} / Unsupported${PLAIN}"; exit 1 ;;
    esac
}

case "${1:-}" in
    update)    do_update ;;
    uninstall) do_uninstall ;;
    version|-v|--version) do_version ;;
    help|-h|--help) do_help ;;
    *)         do_run ;;
esac
LAUNCHER_EOF
    chmod +x "${BIN_PATH}"
}

# ================= --refresh-cli 模式 =================
if [ "${1:-}" = "--refresh-cli" ]; then
    create_cli_command
    exit 0
fi

# ================= 基础检查 =================
if [ $(id -u) != "0" ]; then
    echo -e "${RED}Error: 必须使用 root 用户运行 / Must run as root!${PLAIN}"
    exit 1
fi

if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
    echo -e "${RED}Error: 未找到 curl 或 wget / curl or wget not found${PLAIN}"
    echo "  CentOS: yum install -y curl"
    echo "  Ubuntu: apt-get install -y curl"
    exit 1
fi

# ================= 语言选择 =================
clear
echo ""
echo -e "  ${CYAN}┌──────────────────────────────────────────────┐${PLAIN}"
echo -e "  ${CYAN}│${PLAIN}        ${GREEN}🚀 Linux Server Init${PLAIN}  ${YELLOW}v${VERSION}${PLAIN}          ${CYAN}│${PLAIN}"
echo -e "  ${CYAN}└──────────────────────────────────────────────┘${PLAIN}"
echo ""
echo "  Please select language / 请选择语言:"
echo ""
echo -e "    ${GREEN}1${PLAIN}) 中文"
echo -e "    ${GREEN}2${PLAIN}) English"
echo ""
read -p "  [1/2] (default: 1): " lang_choice
case "$lang_choice" in
    2) LANG_CURRENT="en" ;;
    *) LANG_CURRENT="cn" ;;
esac

# ================= 安装器文本 =================
if [ "$LANG_CURRENT" = "en" ]; then
    I_WELCOME="Welcome to Linux Server Init!"
    I_DESC="A CLI tool for fast Linux server initialization and management."
    I_FEATURES="Features:"
    I_F1="  • System: Mirror source, update, NTP sync, hostname/timezone"
    I_F2="  • Software: Common tools, Docker, Nginx, Node.js, Python, Go, GCC"
    I_F3="  • Security: Firewall, SSH hardening, user management"
    I_F4="  • Operations: Service mgmt, cron jobs, system cleanup"
    I_PATH_LABEL="Install path"
    I_CMD_LABEL="Command"
    I_CONFIRM="Confirm installation?"
    I_DETECT="Detecting download sources..."
    I_AVAILABLE="available"
    I_UNAVAILABLE="unavailable"
    I_DOWNLOAD="Downloading scripts..."
    I_COPY="Copying scripts..."
    I_CREATE_CLI="Creating server-init command..."
    I_WRITE_VER="Writing version info..."
    I_COMPLETE="Installation complete!"
    I_USAGE="Usage:"
    I_LAUNCH_Q="Launch now?"
    I_LAUNCHING="Launching..."
    I_CANCEL="Installation cancelled."
    I_FAIL_COUNT="files failed to download"
    I_CONTINUE_Q="Continue anyway?"
    I_LOCAL_MODE="Local files detected, using local install..."
    I_ONLINE_MODE="Online installation mode"
    I_ALL_FAIL="All download sources unavailable!"
    I_TRY_GIT="Try: git clone ${REPO_URL}.git && cd linux-server-init && bash install.sh"
    I_OS_DETECTED="Detected OS"
else
    I_WELCOME="欢迎使用 Linux Server Init！"
    I_DESC="一个用于快速初始化和管理 Linux 服务器的 CLI 工具。"
    I_FEATURES="功能概览："
    I_F1="  • 系统配置：换源、更新、NTP 校时、主机名/时区"
    I_F2="  • 软件安装：常用工具、Docker、Nginx、Node.js、Python、Go、GCC"
    I_F3="  • 安全管理：防火墙、SSH 加固、用户管理"
    I_F4="  • 运维管理：服务管理、定时任务、系统清理"
    I_PATH_LABEL="安装目录"
    I_CMD_LABEL="使用命令"
    I_CONFIRM="确认安装？"
    I_DETECT="正在检测下载源..."
    I_AVAILABLE="可用"
    I_UNAVAILABLE="不可用"
    I_DOWNLOAD="正在下载脚本..."
    I_COPY="正在复制脚本..."
    I_CREATE_CLI="正在创建 server-init 命令..."
    I_WRITE_VER="正在写入版本信息..."
    I_COMPLETE="安装完成！"
    I_USAGE="使用方式："
    I_LAUNCH_Q="是否立即启动？"
    I_LAUNCHING="正在启动..."
    I_CANCEL="已取消安装。"
    I_FAIL_COUNT="个文件下载失败"
    I_CONTINUE_Q="是否继续？"
    I_LOCAL_MODE="检测到本地脚本，使用本地安装..."
    I_ONLINE_MODE="在线安装模式"
    I_ALL_FAIL="所有下载源均不可用！"
    I_TRY_GIT="请尝试: git clone ${REPO_URL}.git && cd linux-server-init && bash install.sh"
    I_OS_DETECTED="检测到系统"
fi

# ================= 系统检测 =================
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_PRETTY=$PRETTY_NAME
else
    echo -e "${RED}无法检测操作系统 / Cannot detect OS${PLAIN}"
    exit 1
fi

# ================= 安装确认 =================
clear
echo ""
echo -e "  ${CYAN}┌──────────────────────────────────────────────┐${PLAIN}"
echo -e "  ${CYAN}│${PLAIN}        ${GREEN}🚀 Linux Server Init${PLAIN}  ${YELLOW}v${VERSION}${PLAIN}          ${CYAN}│${PLAIN}"
echo -e "  ${CYAN}└──────────────────────────────────────────────┘${PLAIN}"
echo ""
echo -e "  ${GREEN}${I_WELCOME}${PLAIN}"
echo -e "  ${I_DESC}"
echo ""
echo -e "  ${BLUE}${I_FEATURES}${PLAIN}"
echo -e "${I_F1}"
echo -e "${I_F2}"
echo -e "${I_F3}"
echo -e "${I_F4}"
echo ""
echo -e "  ${CYAN}─────────────────────────────────${PLAIN}"
echo -e "  ${I_OS_DETECTED}: ${GREEN}${OS_PRETTY}${PLAIN}"
echo -e "  ${I_PATH_LABEL}: ${CYAN}${INSTALL_DIR}${PLAIN}"
echo -e "  ${I_CMD_LABEL}:  ${CYAN}server-init${PLAIN}"
echo -e "  ${CYAN}─────────────────────────────────${PLAIN}"
echo ""
read -p "  ${I_CONFIRM} [Y/n]: " confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo -e "  ${I_CANCEL}"
    exit 0
fi

# ================= 安装流程 =================
echo ""
mkdir -p "${INSTALL_DIR}/scripts"

SCRIPT_SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TOTAL=${#ALL_SCRIPTS[@]}

if [ -d "${SCRIPT_SELF_DIR}/scripts" ] && [ -f "${SCRIPT_SELF_DIR}/scripts/rhel_init.sh" ]; then
    # === 本地安装模式 ===
    echo -e "  ${GREEN}${I_LOCAL_MODE}${PLAIN}"
    echo ""
    for i in "${!ALL_SCRIPTS[@]}"; do
        script="${ALL_SCRIPTS[$i]}"
        current=$((i + 1))
        show_progress $current $TOTAL "$script"
        cp -f "${SCRIPT_SELF_DIR}/scripts/${script}" "${INSTALL_DIR}/scripts/${script}" 2>/dev/null
        sleep 0.05
    done
    echo ""
else
    # === 在线安装模式 ===
    echo -e "  ${GREEN}${I_ONLINE_MODE}${PLAIN}"
    echo ""

    # 选择镜像
    echo -e "  ${YELLOW}${I_DETECT}${PLAIN}"
    BASE_URL=""
    for mirror in "${MIRRORS[@]}"; do
        domain=$(echo "$mirror" | awk -F'/' '{print $3}')
        echo -n "    ${domain} ... "
        if download_file "${mirror}/install.sh" "/dev/null"; then
            echo -e "${GREEN}${I_AVAILABLE} ✔${PLAIN}"
            BASE_URL="$mirror"
            break
        else
            echo -e "${RED}${I_UNAVAILABLE} ✘${PLAIN}"
        fi
    done

    if [ -z "$BASE_URL" ]; then
        echo ""
        echo -e "  ${RED}${I_ALL_FAIL}${PLAIN}"
        echo -e "  ${YELLOW}${I_TRY_GIT}${PLAIN}"
        exit 1
    fi

    echo ""
    echo -e "  ${GREEN}${I_DOWNLOAD}${PLAIN}"
    echo ""
    FAIL=0
    for i in "${!ALL_SCRIPTS[@]}"; do
        script="${ALL_SCRIPTS[$i]}"
        current=$((i + 1))
        show_progress $current $TOTAL "$script"
        if ! download_file "${BASE_URL}/scripts/${script}" "${INSTALL_DIR}/scripts/${script}"; then
            FAIL=$((FAIL + 1))
        fi
    done
    echo ""

    if [ $FAIL -gt 0 ]; then
        echo ""
        echo -e "  ${RED}${FAIL} ${I_FAIL_COUNT}${PLAIN}"
        read -p "  ${I_CONTINUE_Q} [y/N]: " cont
        if [[ ! "$cont" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

chmod +x "${INSTALL_DIR}/scripts/"*.sh 2>/dev/null

# 创建 CLI 命令
echo ""
echo -ne "  ${I_CREATE_CLI} "
create_cli_command
echo -e "${GREEN}✔${PLAIN}"

# 写入版本信息
echo -ne "  ${I_WRITE_VER} "
cat > "${INSTALL_DIR}/.version" << EOF
server-init v${VERSION}
installed=$(date '+%Y-%m-%d %H:%M:%S')
repo=${REPO_URL}
EOF
echo -e "${GREEN}✔${PLAIN}"

# 保存语言偏好
echo "$LANG_CURRENT" > "${INSTALL_DIR}/.lang" 2>/dev/null

# ================= 安装完成 =================
echo ""
echo -e "  ${GREEN}┌──────────────────────────────────────────────┐${PLAIN}"
echo -e "  ${GREEN}│${PLAIN}              ✅ ${I_COMPLETE}                    ${GREEN}│${PLAIN}"
echo -e "  ${GREEN}└──────────────────────────────────────────────┘${PLAIN}"
echo ""
echo -e "  ${I_USAGE}"
echo -e "    ${CYAN}server-init${PLAIN}              $([ "$LANG_CURRENT" = "en" ] && echo "Launch menu" || echo "启动主菜单")"
echo -e "    ${CYAN}server-init update${PLAIN}       $([ "$LANG_CURRENT" = "en" ] && echo "Online update" || echo "在线更新")"
echo -e "    ${CYAN}server-init uninstall${PLAIN}    $([ "$LANG_CURRENT" = "en" ] && echo "Uninstall" || echo "卸载工具")"
echo -e "    ${CYAN}server-init version${PLAIN}      $([ "$LANG_CURRENT" = "en" ] && echo "Version info" || echo "版本信息")"
echo ""
sleep 1

# 自动启动
echo -e "  ${GREEN}${I_LAUNCHING}${PLAIN}"
echo ""
sleep 0.5
server-init