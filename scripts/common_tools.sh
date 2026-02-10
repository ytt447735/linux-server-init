#!/bin/bash
# 常用工具一键安装公共脚本

RED=${RED:-'\033[31m'}
GREEN=${GREEN:-'\033[32m'}
YELLOW=${YELLOW:-'\033[33m'}
BLUE=${BLUE:-'\033[34m'}
CYAN='\033[36m'
PLAIN=${PLAIN:-'\033[0m'}

# ================= 常用工具一键安装 =================
function install_common_tools() {
    local PKG_MGR="$1"

    # 基础工具包
    local BASIC_TOOLS_YUM="vim wget curl git unzip lsof net-tools tree tar zip"
    local BASIC_TOOLS_APT="vim wget curl git unzip lsof net-tools tree tar zip"
    
    # 增强运维包（在基础包之上）
    local EXTRA_TOOLS_YUM="htop iotop iftop nload tmux jq sysstat bash-completion"
    local EXTRA_TOOLS_APT="htop iotop iftop nload tmux jq sysstat bash-completion"

    while true; do
        clear
        echo -e "${BLUE}=== 常用工具一键安装 ===${PLAIN}"
        echo ""
        echo "  1. 基础工具包"
        echo -e "     ${CYAN}vim, wget, curl, git, unzip, lsof, net-tools, tree, tar, zip${PLAIN}"
        echo ""
        echo "  2. 增强运维包 (包含基础包)"
        echo -e "     ${CYAN}+ htop, iotop, iftop, nload, tmux, jq, sysstat${PLAIN}"
        echo ""
        echo "  3. 查看已安装工具"
        echo ""
        echo "  0. 返回"
        echo ""
        read -p "  请选择 [0-3]: " tool_choice

        case $tool_choice in
            1)
                echo ""
                echo -e "${YELLOW}正在安装基础工具包...${PLAIN}"
                if [ "$PKG_MGR" == "yum" ]; then
                    _install_tools_list "$PKG_MGR" "$BASIC_TOOLS_YUM"
                else
                    _install_tools_list "$PKG_MGR" "$BASIC_TOOLS_APT"
                fi
                echo ""
                echo -e "${GREEN}✔ 基础工具包安装完成！${PLAIN}"
                read -p "按回车继续..."
                ;;
            2)
                echo ""
                echo -e "${YELLOW}正在安装增强运维包（含基础包）...${PLAIN}"
                if [ "$PKG_MGR" == "yum" ]; then
                    _install_tools_list "$PKG_MGR" "$BASIC_TOOLS_YUM $EXTRA_TOOLS_YUM"
                else
                    _install_tools_list "$PKG_MGR" "$BASIC_TOOLS_APT $EXTRA_TOOLS_APT"
                fi
                echo ""
                echo -e "${GREEN}✔ 增强运维包安装完成！${PLAIN}"
                read -p "按回车继续..."
                ;;
            3)
                echo ""
                echo -e "${BLUE}--- 工具安装状态 ---${PLAIN}"
                if [ "$PKG_MGR" == "yum" ]; then
                    local ALL_TOOLS="$BASIC_TOOLS_YUM $EXTRA_TOOLS_YUM"
                else
                    local ALL_TOOLS="$BASIC_TOOLS_APT $EXTRA_TOOLS_APT"
                fi
                for tool in $ALL_TOOLS; do
                    if command -v "$tool" &>/dev/null; then
                        local VER=$($tool --version 2>/dev/null | head -1 || echo "已安装")
                        echo -e "  ${GREEN}✔${PLAIN} $tool  ${CYAN}${VER}${PLAIN}"
                    else
                        echo -e "  ${RED}✘${PLAIN} $tool  ${YELLOW}未安装${PLAIN}"
                    fi
                done
                echo ""
                read -p "按回车继续..."
                ;;
            0) return 0 ;;
            *) continue ;;
        esac
    done
}

# 内部函数：逐个安装工具（跳过已安装的）
function _install_tools_list() {
    local PKG_MGR="$1"
    local TOOLS="$2"
    local INSTALLED=0
    local SKIPPED=0
    local FAILED=0

    for tool in $TOOLS; do
        if command -v "$tool" &>/dev/null; then
            echo -e "  ${GREEN}✔${PLAIN} $tool 已安装，跳过"
            ((SKIPPED++))
        else
            echo -ne "  ${YELLOW}→${PLAIN} 正在安装 $tool ... "
            if [ "$PKG_MGR" == "yum" ]; then
                yum install -y "$tool" &>/dev/null
            else
                apt-get install -y "$tool" &>/dev/null
            fi
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}成功${PLAIN}"
                ((INSTALLED++))
            else
                echo -e "${RED}失败${PLAIN}"
                ((FAILED++))
            fi
        fi
    done

    echo ""
    echo -e "  安装结果: ${GREEN}成功 ${INSTALLED}${PLAIN} | ${YELLOW}跳过 ${SKIPPED}${PLAIN} | ${RED}失败 ${FAILED}${PLAIN}"
}
