#!/bin/bash
# 用户账号管理公共脚本

RED=${RED:-'\033[31m'}
GREEN=${GREEN:-'\033[32m'}
YELLOW=${YELLOW:-'\033[33m'}
BLUE=${BLUE:-'\033[34m'}
CYAN='\033[36m'
PLAIN=${PLAIN:-'\033[0m'}

# ================= 用户账号管理 =================
function user_management() {
    while true; do
        clear
        echo -e "${BLUE}=== 用户账号管理 ===${PLAIN}"
        echo ""
        # 显示当前普通用户列表
        echo -e "  ${CYAN}当前系统用户 (UID ≥ 1000):${PLAIN}"
        local HAS_USERS=0
        while IFS=: read -r username _ uid gid _ home shell; do
            if [ "$uid" -ge 1000 ] && [ "$uid" -lt 65534 ] 2>/dev/null; then
                local IS_SUDO=""
                if groups "$username" 2>/dev/null | grep -qwE 'sudo|wheel'; then
                    IS_SUDO="${GREEN}[sudo]${PLAIN}"
                fi
                echo -e "    ${GREEN}•${PLAIN} ${username}  UID:${uid}  ${IS_SUDO}  ${CYAN}${shell}${PLAIN}"
                HAS_USERS=1
            fi
        done < /etc/passwd
        if [ $HAS_USERS -eq 0 ]; then
            echo -e "    ${YELLOW}(无普通用户)${PLAIN}"
        fi

        echo ""
        echo -e "${BLUE}------------------------------${PLAIN}"
        echo "  1. 添加用户"
        echo "  2. 删除用户"
        echo "  3. 修改用户密码"
        echo "  4. 授予/撤销 sudo 权限"
        echo ""
        echo "  0. 返回"
        echo ""
        read -p "  请选择 [0-4]: " user_choice

        case $user_choice in
            1) _add_user ;;
            2) _delete_user ;;
            3) _change_password ;;
            4) _toggle_sudo ;;
            0) return 0 ;;
            *) continue ;;
        esac
    done
}

# --- 添加用户 ---
function _add_user() {
    echo ""
    read -p "  请输入新用户名: " new_user

    # 检查用户名是否为空
    if [ -z "$new_user" ]; then
        echo -e "${RED}用户名不能为空。${PLAIN}"
        read -p "按回车继续..."
        return 1
    fi

    # 检查用户是否已存在
    if id "$new_user" &>/dev/null; then
        echo -e "${RED}用户 ${new_user} 已存在！${PLAIN}"
        read -p "按回车继续..."
        return 1
    fi

    # 创建用户
    useradd -m -s /bin/bash "$new_user"
    if [ $? -ne 0 ]; then
        echo -e "${RED}创建用户失败！${PLAIN}"
        read -p "按回车继续..."
        return 1
    fi

    # 设置密码
    echo -e "${YELLOW}请为用户 ${new_user} 设置密码:${PLAIN}"
    passwd "$new_user"

    # 是否赋予 sudo 权限
    echo ""
    read -p "  是否赋予 ${new_user} sudo (root) 权限？[y/N]: " grant_sudo
    if [[ "$grant_sudo" =~ ^[Yy]$ ]]; then
        # 检测 sudo 组名（CentOS 用 wheel，Debian/Ubuntu 用 sudo）
        if grep -q '^wheel:' /etc/group; then
            usermod -aG wheel "$new_user"
        else
            usermod -aG sudo "$new_user"
        fi
        echo -e "${GREEN}✔ 已赋予 ${new_user} sudo 权限。${PLAIN}"
    fi

    echo -e "${GREEN}✔ 用户 ${new_user} 创建成功！${PLAIN}"
    read -p "按回车继续..."
}

# --- 删除用户 ---
function _delete_user() {
    echo ""
    # 列出可删除的用户
    echo -e "  ${CYAN}可删除的用户:${PLAIN}"
    local USERS_LIST=()
    local IDX=0
    while IFS=: read -r username _ uid _ _ _ _; do
        if [ "$uid" -ge 1000 ] && [ "$uid" -lt 65534 ] 2>/dev/null; then
            ((IDX++))
            USERS_LIST+=("$username")
            echo -e "    ${IDX}. ${username}"
        fi
    done < /etc/passwd

    if [ $IDX -eq 0 ]; then
        echo -e "    ${YELLOW}没有可删除的普通用户。${PLAIN}"
        read -p "按回车继续..."
        return 0
    fi

    echo ""
    read -p "  请输入要删除的用户编号 [1-${IDX}]: " del_idx

    # 验证输入
    if ! [[ "$del_idx" =~ ^[0-9]+$ ]] || [ "$del_idx" -lt 1 ] || [ "$del_idx" -gt $IDX ]; then
        echo -e "${RED}无效选择。${PLAIN}"
        read -p "按回车继续..."
        return 1
    fi

    local DEL_USER="${USERS_LIST[$((del_idx-1))]}"

    # 二次确认
    echo -e "${YELLOW}⚠ 即将删除用户: ${DEL_USER}${PLAIN}"
    read -p "  是否同时删除该用户的 home 目录？[y/N]: " del_home
    read -p "  确认删除用户 ${DEL_USER}？此操作不可逆 [y/N]: " confirm_del

    if [[ ! "$confirm_del" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}已取消。${PLAIN}"
        read -p "按回车继续..."
        return 0
    fi

    if [[ "$del_home" =~ ^[Yy]$ ]]; then
        userdel -r "$DEL_USER" 2>/dev/null
    else
        userdel "$DEL_USER" 2>/dev/null
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✔ 用户 ${DEL_USER} 已删除。${PLAIN}"
    else
        echo -e "${RED}✘ 删除用户失败，该用户可能正在登录中。${PLAIN}"
    fi
    read -p "按回车继续..."
}

# --- 修改密码 ---
function _change_password() {
    echo ""
    read -p "  请输入要修改密码的用户名: " target_user

    if [ -z "$target_user" ]; then
        echo -e "${RED}用户名不能为空。${PLAIN}"
        read -p "按回车继续..."
        return 1
    fi

    if ! id "$target_user" &>/dev/null; then
        echo -e "${RED}用户 ${target_user} 不存在！${PLAIN}"
        read -p "按回车继续..."
        return 1
    fi

    echo -e "${YELLOW}请为用户 ${target_user} 设置新密码:${PLAIN}"
    passwd "$target_user"
    read -p "按回车继续..."
}

# --- 授予/撤销 sudo 权限 ---
function _toggle_sudo() {
    echo ""
    read -p "  请输入用户名: " target_user

    if [ -z "$target_user" ]; then
        echo -e "${RED}用户名不能为空。${PLAIN}"
        read -p "按回车继续..."
        return 1
    fi

    if ! id "$target_user" &>/dev/null; then
        echo -e "${RED}用户 ${target_user} 不存在！${PLAIN}"
        read -p "按回车继续..."
        return 1
    fi

    # 检测 sudo 组名
    local SUDO_GROUP="sudo"
    grep -q '^wheel:' /etc/group && SUDO_GROUP="wheel"

    # 检测当前是否有 sudo 权限
    if groups "$target_user" 2>/dev/null | grep -qw "$SUDO_GROUP"; then
        echo -e "  用户 ${target_user} ${GREEN}当前拥有${PLAIN} sudo 权限"
        read -p "  是否撤销 sudo 权限？[y/N]: " revoke
        if [[ "$revoke" =~ ^[Yy]$ ]]; then
            gpasswd -d "$target_user" "$SUDO_GROUP" &>/dev/null
            echo -e "${GREEN}✔ 已撤销 ${target_user} 的 sudo 权限。${PLAIN}"
        else
            echo -e "${YELLOW}已取消。${PLAIN}"
        fi
    else
        echo -e "  用户 ${target_user} ${RED}当前没有${PLAIN} sudo 权限"
        read -p "  是否授予 sudo 权限？[y/N]: " grant
        if [[ "$grant" =~ ^[Yy]$ ]]; then
            usermod -aG "$SUDO_GROUP" "$target_user"
            echo -e "${GREEN}✔ 已授予 ${target_user} sudo 权限。${PLAIN}"
        else
            echo -e "${YELLOW}已取消。${PLAIN}"
        fi
    fi
    read -p "按回车继续..."
}
