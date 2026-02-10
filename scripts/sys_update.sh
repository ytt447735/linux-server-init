#!/bin/bash
# 系统更新公共脚本

RED=${RED:-'\033[31m'}
GREEN=${GREEN:-'\033[32m'}
YELLOW=${YELLOW:-'\033[33m'}
BLUE=${BLUE:-'\033[34m'}
PLAIN=${PLAIN:-'\033[0m'}

# ================= 系统更新 =================
function sys_update() {
    local PKG_MGR="$1"

    echo -e "${BLUE}=== 系统更新 ===${PLAIN}"
    echo ""

    # 显示当前系统信息
    if [ -f /etc/os-release ]; then
        local OS_NAME=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2)
        echo -e "  当前系统: ${GREEN}${OS_NAME}${PLAIN}"
    fi
    local KERNEL=$(uname -r)
    echo -e "  当前内核: ${GREEN}${KERNEL}${PLAIN}"
    echo ""

    # 确认更新
    read -p "  确认要更新系统吗？这可能需要一些时间 [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}已取消系统更新。${PLAIN}"
        return 0
    fi

    echo ""

    if [ "$PKG_MGR" == "yum" ]; then
        echo -e "${YELLOW}[1/3] 正在清理缓存...${PLAIN}"
        yum clean all &>/dev/null

        echo -e "${YELLOW}[2/3] 正在检查更新...${PLAIN}"
        local UPDATE_COUNT=$(yum check-update 2>/dev/null | grep -c '^\S')
        echo -e "  发现 ${GREEN}${UPDATE_COUNT}${PLAIN} 个可更新的包"

        if [ "$UPDATE_COUNT" -eq 0 ]; then
            echo -e "${GREEN}系统已是最新状态，无需更新。${PLAIN}"
            return 0
        fi

        echo -e "${YELLOW}[3/3] 正在执行更新...${PLAIN}"
        yum update -y
    else
        echo -e "${YELLOW}[1/3] 正在更新软件源索引...${PLAIN}"
        apt-get update

        echo -e "${YELLOW}[2/3] 正在检查更新...${PLAIN}"
        local UPDATE_COUNT=$(apt list --upgradable 2>/dev/null | grep -c 'upgradable')
        echo -e "  发现 ${GREEN}${UPDATE_COUNT}${PLAIN} 个可更新的包"

        if [ "$UPDATE_COUNT" -eq 0 ]; then
            echo -e "${GREEN}系统已是最新状态，无需更新。${PLAIN}"
            return 0
        fi

        echo -e "${YELLOW}[3/3] 正在执行更新...${PLAIN}"
        apt-get upgrade -y
    fi

    local RESULT=$?
    echo ""
    if [ $RESULT -eq 0 ]; then
        echo -e "${GREEN}✔ 系统更新完成！${PLAIN}"
        echo -e "  更新后内核: ${GREEN}$(uname -r)${PLAIN}"
        
        # 检查是否需要重启
        if [ -f /var/run/reboot-required ] 2>/dev/null; then
            echo -e "  ${YELLOW}⚠ 建议重启系统以应用内核更新。${PLAIN}"
        elif [ "$PKG_MGR" == "yum" ]; then
            local NEW_KERNEL=$(rpm -q kernel --last 2>/dev/null | head -1 | awk '{print $1}')
            local CUR_KERNEL="kernel-$(uname -r)"
            if [ -n "$NEW_KERNEL" ] && [ "$NEW_KERNEL" != "$CUR_KERNEL" ]; then
                echo -e "  ${YELLOW}⚠ 检测到新内核，建议重启系统以应用更新。${PLAIN}"
            fi
        fi
    else
        echo -e "${RED}✘ 系统更新过程中出现错误，请检查日志。${PLAIN}"
    fi
}
