#!/bin/bash
# tool_mgmt.sh - 工具管理 (更新/修复/卸载/版本)
# Repo: https://github.com/ytt447735/linux-server-init
# Author: ytt447735

INSTALL_DIR="/usr/local/lib/server-init"
BIN_PATH="/usr/local/bin/server-init"
REPO_URL="https://github.com/ytt447735/linux-server-init"
BRANCH="main"

_MIRRORS=(
    "https://gh-proxy.org/${REPO_URL}/raw/refs/heads/${BRANCH}"
    "https://mirror.ghproxy.com/https://raw.githubusercontent.com/ytt447735/linux-server-init/${BRANCH}"
    "https://raw.githubusercontent.com/ytt447735/linux-server-init/${BRANCH}"
)

_ALL_SCRIPTS=(
    "sys_info.sh" "ntp_sync.sh" "common_tools.sh" "sys_update.sh"
    "sys_cleanup.sh" "user_mgmt.sh" "ssh_security.sh" "service_install.sh"
    "host_config.sh" "service_mgmt.sh" "cron_mgmt.sh"
    "lang.sh" "tool_mgmt.sh"
    "rhel_init.sh" "debian_init.sh"
)

# 检查是否处于已安装状态
_check_installed() {
    if [ ! -d "${INSTALL_DIR}/scripts" ] || [ ! -f "${BIN_PATH}" ]; then
        echo -e "${YELLOW}⚠  工具未安装到系统，请先运行 install.sh 安装。${PLAIN}"
        echo -e "   当前为本地运行模式，不支持此功能。"
        return 1
    fi
    return 0
}

_dl_file() {
    local url=$1 filepath=$2
    if command -v curl &> /dev/null; then
        curl -fsSL --connect-timeout 10 --max-time 30 -o "$filepath" "$url" 2>/dev/null
    else
        wget --timeout=10 -t 2 -q -O "$filepath" "$url" 2>/dev/null
    fi
}

_select_mirror() {
    echo -e "${YELLOW}正在检测可用下载源...${PLAIN}"
    for mirror in "${_MIRRORS[@]}"; do
        local domain=$(echo "$mirror" | awk -F'/' '{print $3}')
        echo -n "  测试: ${domain} ... "
        if _dl_file "${mirror}/install.sh" "/dev/null"; then
            echo -e "${GREEN}✔${PLAIN}"
            _BASE_URL="$mirror"
            return 0
        else
            echo -e "${RED}✘${PLAIN}"
        fi
    done
    echo -e "${RED}所有下载源均不可用！请检查网络。${PLAIN}"
    return 1
}

# ================= 更新 =================
_tool_update() {
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────┐${PLAIN}"
    echo -e "${CYAN}  │${PLAIN}         📥 在线更新 / Online Update       ${CYAN}│${PLAIN}"
    echo -e "${CYAN}  └──────────────────────────────────────────┘${PLAIN}"
    echo ""
    _check_installed || return
    _select_mirror || return 1
    echo ""
    echo -e "${GREEN}正在更新脚本...${PLAIN}"
    local fail=0
    for script in "${_ALL_SCRIPTS[@]}"; do
        echo -n "  ${script} ... "
        if _dl_file "${_BASE_URL}/scripts/${script}" "${INSTALL_DIR}/scripts/${script}"; then
            echo -e "${GREEN}✔${PLAIN}"
        else
            echo -e "${RED}✘${PLAIN}"
            fail=$((fail + 1))
        fi
    done
    chmod +x "${INSTALL_DIR}/scripts/"*.sh 2>/dev/null
    echo "updated=$(date '+%Y-%m-%d %H:%M:%S')" >> "${INSTALL_DIR}/.version"
    echo ""
    if [ $fail -eq 0 ]; then
        echo -e "${GREEN}✅ 更新完成！重新进入菜单后生效。${PLAIN}"
    else
        echo -e "${YELLOW}⚠️  有 ${fail} 个文件更新失败。${PLAIN}"
    fi
}

# ================= 修复 =================
_tool_repair() {
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────┐${PLAIN}"
    echo -e "${CYAN}  │${PLAIN}         🔧 修复工具 / Repair Tool        ${CYAN}│${PLAIN}"
    echo -e "${CYAN}  └──────────────────────────────────────────┘${PLAIN}"
    echo ""
    _check_installed || return
    echo -e "${YELLOW}将重新下载所有脚本并重建 CLI 命令。${PLAIN}"
    echo ""
    read -p "  确认修复？[y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "  已取消。"
        return
    fi
    echo ""
    _select_mirror || return 1
    echo ""
    mkdir -p "${INSTALL_DIR}/scripts"
    local fail=0
    for script in "${_ALL_SCRIPTS[@]}"; do
        echo -n "  ${script} ... "
        if _dl_file "${_BASE_URL}/scripts/${script}" "${INSTALL_DIR}/scripts/${script}"; then
            echo -e "${GREEN}✔${PLAIN}"
        else
            echo -e "${RED}✘${PLAIN}"
            fail=$((fail + 1))
        fi
    done
    chmod +x "${INSTALL_DIR}/scripts/"*.sh 2>/dev/null
    # 重建 CLI 命令
    echo -n "  重建 CLI 命令 ... "
    local tmp_installer=$(mktemp /tmp/server-init-repair.XXXXXX)
    if _dl_file "${_BASE_URL}/install.sh" "$tmp_installer"; then
        bash "$tmp_installer" --refresh-cli 2>/dev/null
        echo -e "${GREEN}✔${PLAIN}"
    else
        echo -e "${RED}✘${PLAIN}"
        fail=$((fail + 1))
    fi
    rm -f "$tmp_installer"
    echo ""
    if [ $fail -eq 0 ]; then
        echo -e "${GREEN}✅ 修复完成！${PLAIN}"
    else
        echo -e "${YELLOW}⚠️  修复完成，但有 ${fail} 个文件失败。${PLAIN}"
    fi
}

# ================= 版本 =================
_tool_version() {
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────┐${PLAIN}"
    echo -e "${CYAN}  │${PLAIN}         📋 版本信息 / Version Info       ${CYAN}│${PLAIN}"
    echo -e "${CYAN}  └──────────────────────────────────────────┘${PLAIN}"
    echo ""
    if [ -f "${INSTALL_DIR}/.version" ]; then
        while IFS= read -r line; do
            echo "  $line"
        done < "${INSTALL_DIR}/.version"
    else
        echo "  版本信息不可用 (可能未安装到系统)"
    fi
    echo ""
    echo -e "  安装目录: ${CYAN}${INSTALL_DIR}${PLAIN}"
    echo -e "  命令路径: ${CYAN}${BIN_PATH}${PLAIN}"
    local count=$(ls "${INSTALL_DIR}/scripts/"*.sh 2>/dev/null | wc -l)
    echo -e "  脚本数量: ${CYAN}${count}${PLAIN} 个"
    echo -e "  项目地址: ${CYAN}${REPO_URL}${PLAIN}"
}

# ================= 卸载 =================
_tool_uninstall() {
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────┐${PLAIN}"
    echo -e "${CYAN}  │${PLAIN}         🗑️  卸载工具 / Uninstall          ${CYAN}│${PLAIN}"
    echo -e "${CYAN}  └──────────────────────────────────────────┘${PLAIN}"
    echo ""
    _check_installed || return
    echo -e "  ${YELLOW}即将卸载 server-init 工具${PLAIN}"
    echo -e "  安装目录: ${INSTALL_DIR}"
    echo -e "  命令文件: ${BIN_PATH}"
    echo ""
    read -p "  确认卸载？[y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "  已取消。"
        return
    fi
    rm -rf "${INSTALL_DIR}"
    rm -f "${BIN_PATH}"
    echo ""
    echo -e "${GREEN}✅ 卸载完成！${PLAIN}"
    exit 0
}
