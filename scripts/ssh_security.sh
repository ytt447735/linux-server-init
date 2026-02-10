#!/bin/bash
# SSH 安全加固公共脚本

RED=${RED:-'\033[31m'}
GREEN=${GREEN:-'\033[32m'}
YELLOW=${YELLOW:-'\033[33m'}
BLUE=${BLUE:-'\033[34m'}
CYAN='\033[36m'
PLAIN=${PLAIN:-'\033[0m'}

SSHD_CONFIG="/etc/ssh/sshd_config"

# ================= SSH 安全加固 =================
function ssh_security() {
    while true; do
        clear
        echo -e "${BLUE}=== SSH 安全加固 ===${PLAIN}"
        echo ""

        # 显示当前 SSH 配置状态
        _show_ssh_status

        echo ""
        echo -e "${BLUE}------------------------------${PLAIN}"
        echo "  1. 生成 SSH 密钥对 (证书登录)"
        echo "  2. 禁止/允许密码登录"
        echo "  3. 修改 SSH 端口"
        echo "  4. 禁止/允许 Root 直接登录"
        echo "  5. 查看完整 SSH 配置"
        echo ""
        echo "  0. 返回"
        echo ""
        read -p "  请选择 [0-5]: " ssh_choice

        case $ssh_choice in
            1) _setup_ssh_key ;;
            2) _toggle_password_auth ;;
            3) _change_ssh_port ;;
            4) _toggle_root_login ;;
            5)
                echo ""
                echo -e "${BLUE}--- sshd_config 关键配置 ---${PLAIN}"
                grep -vE '^\s*#|^\s*$' "$SSHD_CONFIG" | head -30
                echo ""
                read -p "按回车继续..."
                ;;
            0) return 0 ;;
            *) continue ;;
        esac
    done
}

# --- 显示 SSH 状态 ---
function _show_ssh_status() {
    echo -e "  ${CYAN}当前 SSH 配置状态:${PLAIN}"

    # 端口
    local SSH_PORT=$(grep -E '^\s*Port\s+' "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)
    SSH_PORT=${SSH_PORT:-22}
    echo -e "    SSH 端口:     ${GREEN}${SSH_PORT}${PLAIN}"

    # 密码登录
    local PASS_AUTH=$(grep -E '^\s*PasswordAuthentication\s+' "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)
    if [ "$PASS_AUTH" == "no" ]; then
        echo -e "    密码登录:     ${RED}已禁止${PLAIN}"
    else
        echo -e "    密码登录:     ${GREEN}允许${PLAIN}"
    fi

    # Root 登录
    local ROOT_LOGIN=$(grep -E '^\s*PermitRootLogin\s+' "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)
    if [ "$ROOT_LOGIN" == "no" ]; then
        echo -e "    Root 登录:    ${RED}已禁止${PLAIN}"
    elif [ "$ROOT_LOGIN" == "prohibit-password" ] || [ "$ROOT_LOGIN" == "without-password" ]; then
        echo -e "    Root 登录:    ${YELLOW}仅密钥${PLAIN}"
    else
        echo -e "    Root 登录:    ${GREEN}允许${PLAIN}"
    fi

    # 密钥认证
    local PUBKEY_AUTH=$(grep -E '^\s*PubkeyAuthentication\s+' "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)
    if [ "$PUBKEY_AUTH" == "no" ]; then
        echo -e "    密钥认证:     ${RED}已禁止${PLAIN}"
    else
        echo -e "    密钥认证:     ${GREEN}允许${PLAIN}"
    fi
}

# --- 备份 sshd_config ---
function _backup_sshd_config() {
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.backup.$(date +%Y%m%d%H%M%S)"
    echo -e "  ${GREEN}✔ 已备份 sshd_config${PLAIN}"
}

# --- 重启 sshd 服务 ---
function _restart_sshd() {
    systemctl restart sshd 2>/dev/null || service sshd restart 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✔ SSH 服务已重启${PLAIN}"
    else
        echo -e "  ${RED}✘ SSH 服务重启失败，请手动检查${PLAIN}"
    fi
}

# --- 生成 SSH 密钥对 ---
function _setup_ssh_key() {
    echo ""
    echo -e "${BLUE}--- 生成 SSH 密钥对 (证书登录) ---${PLAIN}"
    echo ""

    # 选择目标用户
    read -p "  为哪个用户生成密钥？(留空=当前用户 root): " target_user
    target_user=${target_user:-root}

    if ! id "$target_user" &>/dev/null; then
        echo -e "${RED}用户 ${target_user} 不存在！${PLAIN}"
        read -p "按回车继续..."
        return 1
    fi

    # 获取用户 home 目录
    local USER_HOME=$(eval echo "~${target_user}")
    local SSH_DIR="${USER_HOME}/.ssh"
    local KEY_FILE="${SSH_DIR}/id_rsa"

    # 检查是否已有密钥
    if [ -f "${KEY_FILE}" ]; then
        echo -e "  ${YELLOW}⚠ 用户 ${target_user} 已存在 SSH 密钥${PLAIN}"
        read -p "  是否覆盖生成新密钥？[y/N]: " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}已取消。${PLAIN}"
            read -p "按回车继续..."
            return 0
        fi
    fi

    # 创建 .ssh 目录
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    chown "${target_user}:${target_user}" "$SSH_DIR" 2>/dev/null

    # 生成密钥对
    echo -e "${YELLOW}正在生成 RSA 4096 位密钥对...${PLAIN}"
    ssh-keygen -t rsa -b 4096 -f "$KEY_FILE" -N "" -C "${target_user}@$(hostname)" <<< "y" &>/dev/null

    if [ $? -eq 0 ]; then
        # 配置 authorized_keys
        cat "${KEY_FILE}.pub" >> "${SSH_DIR}/authorized_keys"
        chmod 600 "${SSH_DIR}/authorized_keys"
        chmod 600 "${KEY_FILE}"
        chmod 644 "${KEY_FILE}.pub"
        chown -R "${target_user}:${target_user}" "$SSH_DIR" 2>/dev/null

        # 确保 sshd_config 允许密钥认证
        _backup_sshd_config
        _set_sshd_option "PubkeyAuthentication" "yes"
        _restart_sshd

        echo ""
        echo -e "${GREEN}✔ SSH 密钥对生成成功！${PLAIN}"
        echo ""
        echo -e "  ${CYAN}私钥路径:${PLAIN} ${KEY_FILE}"
        echo -e "  ${CYAN}公钥路径:${PLAIN} ${KEY_FILE}.pub"
        echo ""
        echo -e "${YELLOW}⚠ 重要：请立即将私钥下载到本地，然后可以考虑禁止密码登录。${PLAIN}"
        echo -e "${YELLOW}  下载命令示例：${PLAIN}"
        local SSH_PORT=$(grep -E '^\s*Port\s+' "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)
        SSH_PORT=${SSH_PORT:-22}
        echo -e "  ${CYAN}scp -P ${SSH_PORT} ${target_user}@服务器IP:${KEY_FILE} ~/.ssh/${PLAIN}"
        echo ""
        echo -e "  ${CYAN}私钥内容 (也可直接复制):${PLAIN}"
        echo -e "${BLUE}────────────────────────────────────${PLAIN}"
        cat "$KEY_FILE"
        echo -e "${BLUE}────────────────────────────────────${PLAIN}"
    else
        echo -e "${RED}✘ 密钥生成失败！${PLAIN}"
    fi
    echo ""
    read -p "按回车继续..."
}

# --- 修改 sshd_config 配置项 ---
function _set_sshd_option() {
    local KEY="$1"
    local VALUE="$2"

    # 如果存在该配置（包括被注释的），替换之
    if grep -qE "^\s*#?\s*${KEY}\s+" "$SSHD_CONFIG"; then
        sed -i "s/^\s*#*\s*${KEY}\s\+.*/${KEY} ${VALUE}/" "$SSHD_CONFIG"
    else
        # 不存在则追加
        echo "${KEY} ${VALUE}" >> "$SSHD_CONFIG"
    fi
}

# --- 禁止/允许密码登录 ---
function _toggle_password_auth() {
    echo ""
    local CURRENT=$(grep -E '^\s*PasswordAuthentication\s+' "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)

    if [ "$CURRENT" == "no" ]; then
        echo -e "  当前状态: ${RED}密码登录已禁止${PLAIN}"
        read -p "  是否重新允许密码登录？[y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            _backup_sshd_config
            _set_sshd_option "PasswordAuthentication" "yes"
            _restart_sshd
            echo -e "${GREEN}✔ 密码登录已开启。${PLAIN}"
        fi
    else
        echo -e "  当前状态: ${GREEN}密码登录允许${PLAIN}"
        echo ""
        echo -e "  ${YELLOW}⚠ 警告：禁止密码登录前，请确保已配置好 SSH 密钥登录！${PLAIN}"
        echo -e "  ${YELLOW}  否则将无法通过 SSH 连接到服务器！${PLAIN}"
        echo ""
        read -p "  确认禁止密码登录？[y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            _backup_sshd_config
            _set_sshd_option "PasswordAuthentication" "no"
            _set_sshd_option "ChallengeResponseAuthentication" "no"
            _restart_sshd
            echo -e "${GREEN}✔ 密码登录已禁止，仅允许密钥登录。${PLAIN}"
        fi
    fi
    echo ""
    read -p "按回车继续..."
}

# --- 修改 SSH 端口 ---
function _change_ssh_port() {
    echo ""
    local CURRENT_PORT=$(grep -E '^\s*Port\s+' "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)
    CURRENT_PORT=${CURRENT_PORT:-22}
    echo -e "  当前 SSH 端口: ${GREEN}${CURRENT_PORT}${PLAIN}"
    echo ""
    read -p "  请输入新的 SSH 端口号 (1024-65535): " new_port

    # 验证端口号
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
        echo -e "${RED}无效端口号！请输入 1024-65535 之间的数字。${PLAIN}"
        read -p "按回车继续..."
        return 1
    fi

    # 检查端口是否被占用
    if ss -tlnp | grep -q ":${new_port}\s" 2>/dev/null; then
        echo -e "${RED}端口 ${new_port} 已被占用！${PLAIN}"
        read -p "按回车继续..."
        return 1
    fi

    echo ""
    echo -e "  ${YELLOW}将 SSH 端口从 ${CURRENT_PORT} 修改为 ${new_port}${PLAIN}"
    read -p "  确认修改？[y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}已取消。${PLAIN}"
        read -p "按回车继续..."
        return 0
    fi

    _backup_sshd_config
    _set_sshd_option "Port" "$new_port"

    # 自动放行防火墙
    if command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-port=${new_port}/tcp &>/dev/null
        firewall-cmd --reload &>/dev/null
        echo -e "  ${GREEN}✔ 已在 firewalld 中放行端口 ${new_port}${PLAIN}"
    elif command -v ufw &>/dev/null; then
        ufw allow ${new_port}/tcp &>/dev/null
        echo -e "  ${GREEN}✔ 已在 UFW 中放行端口 ${new_port}${PLAIN}"
    fi

    # 如果有 SELinux，也需要放行
    if command -v semanage &>/dev/null; then
        semanage port -a -t ssh_port_t -p tcp "$new_port" &>/dev/null
        echo -e "  ${GREEN}✔ 已在 SELinux 中放行端口 ${new_port}${PLAIN}"
    fi

    _restart_sshd

    echo ""
    echo -e "${GREEN}✔ SSH 端口已修改为 ${new_port}${PLAIN}"
    echo -e "${YELLOW}⚠ 请立即使用新端口测试连接：ssh -p ${new_port} user@server${PLAIN}"
    echo -e "${YELLOW}  在确认新端口可用前，请不要关闭当前会话！${PLAIN}"
    echo ""
    read -p "按回车继续..."
}

# --- 禁止/允许 Root 直接登录 ---
function _toggle_root_login() {
    echo ""
    local CURRENT=$(grep -E '^\s*PermitRootLogin\s+' "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)

    echo -e "  当前 Root 登录设置: ${GREEN}${CURRENT:-yes (默认)}${PLAIN}"
    echo ""
    echo "  1. 允许 Root 登录 (yes)"
    echo "  2. 禁止 Root 登录 (no)"
    echo "  3. 仅允许密钥登录 (prohibit-password)"
    echo "  0. 返回"
    echo ""
    read -p "  请选择 [0-3]: " root_choice

    case $root_choice in
        1)
            _backup_sshd_config
            _set_sshd_option "PermitRootLogin" "yes"
            _restart_sshd
            echo -e "${GREEN}✔ Root 登录已允许。${PLAIN}"
            ;;
        2)
            echo -e "${YELLOW}⚠ 警告：禁止 Root 登录前，请确保有其他 sudo 用户可用！${PLAIN}"
            read -p "  确认禁止？[y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                _backup_sshd_config
                _set_sshd_option "PermitRootLogin" "no"
                _restart_sshd
                echo -e "${GREEN}✔ Root 登录已禁止。${PLAIN}"
            fi
            ;;
        3)
            _backup_sshd_config
            _set_sshd_option "PermitRootLogin" "prohibit-password"
            _restart_sshd
            echo -e "${GREEN}✔ Root 仅允许密钥登录。${PLAIN}"
            ;;
        0) return 0 ;;
    esac
    echo ""
    read -p "按回车继续..."
}
