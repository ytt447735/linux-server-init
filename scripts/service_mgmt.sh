#!/bin/bash
# 服务管理公共脚本 (systemd)

RED=${RED:-'\033[31m'}
GREEN=${GREEN:-'\033[32m'}
YELLOW=${YELLOW:-'\033[33m'}
BLUE=${BLUE:-'\033[34m'}
CYAN='\033[36m'
PLAIN=${PLAIN:-'\033[0m'}

# ================= 服务管理 =================
function service_management() {
    # 检查 systemctl 是否可用
    if ! command -v systemctl &>/dev/null; then
        echo -e "${RED}✘ 未检测到 systemctl，仅支持 systemd 系统。${PLAIN}"
        read -p "按回车返回..."
        return 1
    fi

    while true; do
        clear
        echo -e "${BLUE}=== 服务管理 (systemd) ===${PLAIN}"
        echo ""
        echo "  1. 查看所有运行中的服务"
        echo "  2. 查看所有已启用的开机自启服务"
        echo "  3. 查看服务状态"
        echo "  4. 启动服务"
        echo "  5. 停止服务"
        echo "  6. 重启服务"
        echo "  7. 设置开机自启"
        echo "  8. 取消开机自启"
        echo "  9. 查看服务日志"
        echo " 10. 查看监听端口及对应服务"
        echo ""
        echo "  0. 返回"
        echo ""
        read -p "  请选择 [0-10]: " svc_choice

        case $svc_choice in
            1) _list_running_services ;;
            2) _list_enabled_services ;;
            3) _service_action "status" ;;
            4) _service_action "start" ;;
            5) _service_action "stop" ;;
            6) _service_action "restart" ;;
            7) _service_action "enable" ;;
            8) _service_action "disable" ;;
            9) _service_logs ;;
            10) _list_listening_ports ;;
            0) return 0 ;;
            *) continue ;;
        esac
        echo ""
        read -p "按回车继续..."
    done
}

# --- 列出运行中的服务 ---
function _list_running_services() {
    echo ""
    echo -e "${BLUE}--- 运行中的服务 ---${PLAIN}"
    echo ""
    systemctl list-units --type=service --state=running --no-pager --no-legend | \
        awk '{printf "  %-40s %s\n", $1, $4}' | head -50
    echo ""
    local TOTAL=$(systemctl list-units --type=service --state=running --no-pager --no-legend | wc -l)
    echo -e "  ${CYAN}共 ${TOTAL} 个服务正在运行${PLAIN}"
}

# --- 列出已启用的开机自启服务 ---
function _list_enabled_services() {
    echo ""
    echo -e "${BLUE}--- 开机自启服务 ---${PLAIN}"
    echo ""
    systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend | \
        awk '{printf "  %-45s %s\n", $1, $2}' | head -50
    echo ""
    local TOTAL=$(systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend | wc -l)
    echo -e "  ${CYAN}共 ${TOTAL} 个服务已设为开机自启${PLAIN}"
}

# --- 服务操作 (通用) ---
function _service_action() {
    local ACTION="$1"
    echo ""

    # 操作名称映射
    local ACTION_CN=""
    case $ACTION in
        status)  ACTION_CN="查看状态" ;;
        start)   ACTION_CN="启动" ;;
        stop)    ACTION_CN="停止" ;;
        restart) ACTION_CN="重启" ;;
        enable)  ACTION_CN="设为开机自启" ;;
        disable) ACTION_CN="取消开机自启" ;;
    esac

    read -p "  请输入服务名 (如 nginx, docker, sshd): " svc_name

    if [ -z "$svc_name" ]; then
        echo -e "${YELLOW}  已取消${PLAIN}"
        return 0
    fi

    # 自动补全 .service 后缀
    if [[ "$svc_name" != *.service ]] && [[ "$svc_name" != *.* ]]; then
        svc_name="${svc_name}.service"
    fi

    # 检查服务是否存在
    if ! systemctl list-unit-files "$svc_name" &>/dev/null && ! systemctl cat "$svc_name" &>/dev/null 2>&1; then
        echo -e "${RED}  ✘ 服务不存在: ${svc_name}${PLAIN}"
        return 1
    fi

    if [ "$ACTION" == "status" ]; then
        echo ""
        echo -e "${BLUE}--- ${svc_name} 状态 ---${PLAIN}"
        systemctl status "$svc_name" --no-pager -l 2>/dev/null
    else
        # 危险操作确认
        if [ "$ACTION" == "stop" ] || [ "$ACTION" == "disable" ]; then
            echo -e "${YELLOW}  ⚠ 即将${ACTION_CN}服务: ${svc_name}${PLAIN}"
            read -p "  确认？[y/N]: " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}  已取消${PLAIN}"
                return 0
            fi
        fi

        echo -e "${YELLOW}→ 正在${ACTION_CN} ${svc_name}...${PLAIN}"
        systemctl $ACTION "$svc_name" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}  ✔ ${svc_name} 已${ACTION_CN}${PLAIN}"
        else
            echo -e "${RED}  ✘ ${ACTION_CN}失败，请检查服务名是否正确${PLAIN}"
        fi

        # 操作后显示当前状态概要
        echo ""
        echo -e "  ${CYAN}当前状态:${PLAIN}"
        local ACTIVE=$(systemctl is-active "$svc_name" 2>/dev/null)
        local ENABLED=$(systemctl is-enabled "$svc_name" 2>/dev/null)
        echo -e "    运行状态: $([ "$ACTIVE" == "active" ] && echo -e "${GREEN}${ACTIVE}${PLAIN}" || echo -e "${RED}${ACTIVE}${PLAIN}")"
        echo -e "    开机自启: $([ "$ENABLED" == "enabled" ] && echo -e "${GREEN}${ENABLED}${PLAIN}" || echo -e "${YELLOW}${ENABLED}${PLAIN}")"
    fi
}

# --- 查看服务日志 ---
function _service_logs() {
    echo ""
    read -p "  请输入服务名 (如 nginx, docker): " svc_name

    if [ -z "$svc_name" ]; then
        echo -e "${YELLOW}  已取消${PLAIN}"
        return 0
    fi

    echo ""
    echo "  查看方式:"
    echo "  1. 最近 50 行日志"
    echo "  2. 最近 100 行日志"
    echo "  3. 今日日志"
    echo "  4. 实时跟踪 (Ctrl+C 退出)"
    echo ""
    read -p "  请选择 [1-4]: " log_choice

    echo ""
    echo -e "${BLUE}--- ${svc_name} 日志 ---${PLAIN}"
    case $log_choice in
        1) journalctl -u "$svc_name" -n 50 --no-pager 2>/dev/null ;;
        2) journalctl -u "$svc_name" -n 100 --no-pager 2>/dev/null ;;
        3) journalctl -u "$svc_name" --since today --no-pager 2>/dev/null ;;
        4)
            echo -e "${YELLOW}  按 Ctrl+C 退出实时日志...${PLAIN}"
            journalctl -u "$svc_name" -f 2>/dev/null
            ;;
        *) journalctl -u "$svc_name" -n 50 --no-pager 2>/dev/null ;;
    esac
}

# --- 查看监听端口 ---
function _list_listening_ports() {
    echo ""
    echo -e "${BLUE}--- 当前监听端口 ---${PLAIN}"
    echo ""

    if command -v ss &>/dev/null; then
        echo -e "  ${CYAN}协议   本地地址:端口           进程${PLAIN}"
        echo -e "  ${CYAN}────────────────────────────────────────────${PLAIN}"
        ss -tlnp 2>/dev/null | grep LISTEN | awk '{
            split($4, addr, ":");
            port = addr[length(addr)];
            proc = $6;
            gsub(/users:\(\("|"\)\)/, "", proc);
            gsub(/,pid=[0-9]+,fd=[0-9]+/, "", proc);
            printf "  %-6s %-25s %s\n", "TCP", $4, proc
        }' | sort -t: -k2 -n

        echo ""
        ss -ulnp 2>/dev/null | grep -v "State" | awk '{
            if ($5 != "") {
                proc = $7;
                gsub(/users:\(\("|"\)\)/, "", proc);
                gsub(/,pid=[0-9]+,fd=[0-9]+/, "", proc);
                printf "  %-6s %-25s %s\n", "UDP", $5, proc
            }
        }' | sort -t: -k2 -n
    elif command -v netstat &>/dev/null; then
        netstat -tlnp 2>/dev/null | grep LISTEN | awk '{printf "  %-6s %-25s %s\n", "TCP", $4, $7}'
        echo ""
        netstat -ulnp 2>/dev/null | grep -v "Proto" | awk '{if ($6 != "") printf "  %-6s %-25s %s\n", "UDP", $4, $6}'
    else
        echo -e "${RED}  未找到 ss 或 netstat 命令${PLAIN}"
    fi
}
