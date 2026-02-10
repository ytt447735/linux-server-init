#!/bin/bash
# 系统清理公共脚本

RED=${RED:-'\033[31m'}
GREEN=${GREEN:-'\033[32m'}
YELLOW=${YELLOW:-'\033[33m'}
BLUE=${BLUE:-'\033[34m'}
CYAN='\033[36m'
PLAIN=${PLAIN:-'\033[0m'}

# ================= 系统清理 =================
function sys_cleanup() {
    local PKG_MGR="$1"

    while true; do
        clear
        # 显示当前磁盘使用情况
        local DISK_USAGE=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')
        echo -e "${BLUE}=== 系统清理 ===${PLAIN}"
        echo -e "  当前根分区使用: ${CYAN}${DISK_USAGE}${PLAIN}"
        echo ""
        echo "  1. 清理包管理器缓存"
        echo "  2. 清理系统日志"
        echo "  3. 清理 /tmp 临时文件"
        echo "  4. 清理旧内核"
        echo "  5. 清理无用依赖包"
        echo "  6. Docker 缓存清理"
        echo -e "  ${YELLOW}7. 一键全部清理 (不含 Docker)${PLAIN}"
        echo ""
        echo "  0. 返回"
        echo ""
        read -p "  请选择 [0-7]: " clean_choice

        case $clean_choice in
            1) _clean_pkg_cache "$PKG_MGR" ;;
            2) _clean_logs ;;
            3) _clean_tmp ;;
            4) _clean_old_kernels "$PKG_MGR" ;;
            5) _clean_unused_deps "$PKG_MGR" ;;
            6) _clean_docker ;;
            7)
                echo ""
                local BEFORE=$(df / | awk 'NR==2 {print $3}')
                _clean_pkg_cache "$PKG_MGR"
                _clean_logs
                _clean_tmp
                _clean_old_kernels "$PKG_MGR"
                _clean_unused_deps "$PKG_MGR"
                local AFTER=$(df / | awk 'NR==2 {print $3}')
                local FREED=$(( (BEFORE - AFTER) ))
                echo ""
                echo -e "${GREEN}════════════════════════════════${PLAIN}"
                if [ $FREED -gt 0 ]; then
                    echo -e "${GREEN}✔ 全部清理完成！共释放约 ${FREED}KB 空间${PLAIN}"
                else
                    echo -e "${GREEN}✔ 全部清理完成！${PLAIN}"
                fi
                echo -e "${GREEN}════════════════════════════════${PLAIN}"
                ;;
            0) return 0 ;;
            *) continue ;;
        esac
        echo ""
        read -p "按回车继续..."
    done
}

# --- 清理包管理器缓存 ---
function _clean_pkg_cache() {
    local PKG_MGR="$1"
    echo ""
    echo -e "${YELLOW}→ 正在清理包管理器缓存...${PLAIN}"
    if [ "$PKG_MGR" == "yum" ]; then
        yum clean all &>/dev/null
        rm -rf /var/cache/yum/* 2>/dev/null
    else
        apt-get clean &>/dev/null
        apt-get autoclean &>/dev/null
    fi
    echo -e "${GREEN}  ✔ 包管理器缓存已清理${PLAIN}"
}

# --- 清理系统日志 ---
function _clean_logs() {
    echo ""
    echo -e "${YELLOW}→ 正在清理系统日志...${PLAIN}"

    # journalctl 日志
    if command -v journalctl &>/dev/null; then
        local LOG_SIZE_BEFORE=$(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+[KMGT]' || echo "0")
        journalctl --vacuum-size=100M &>/dev/null
        journalctl --vacuum-time=30d &>/dev/null
        echo -e "${GREEN}  ✔ systemd 日志已清理 (保留最近 30 天 / 最大 100M)${PLAIN}"
    fi

    # 旧日志文件
    find /var/log -name "*.gz" -delete 2>/dev/null
    find /var/log -name "*.old" -delete 2>/dev/null
    find /var/log -name "*.[0-9]" -delete 2>/dev/null
    echo -e "${GREEN}  ✔ 旧日志文件已清理 (.gz / .old / 轮转文件)${PLAIN}"
}

# --- 清理 /tmp ---
function _clean_tmp() {
    echo ""
    echo -e "${YELLOW}→ 正在清理 /tmp 临时文件...${PLAIN}"
    local TMP_COUNT=$(find /tmp -type f -mtime +7 2>/dev/null | wc -l)
    find /tmp -type f -mtime +7 -delete 2>/dev/null
    find /var/tmp -type f -mtime +7 -delete 2>/dev/null
    echo -e "${GREEN}  ✔ 已清理 ${TMP_COUNT} 个超过 7 天的临时文件${PLAIN}"
}

# --- 清理旧内核 ---
function _clean_old_kernels() {
    local PKG_MGR="$1"
    echo ""
    echo -e "${YELLOW}→ 正在清理旧内核...${PLAIN}"

    if [ "$PKG_MGR" == "yum" ]; then
        local KERNEL_COUNT=$(rpm -q kernel 2>/dev/null | wc -l)
        if [ "$KERNEL_COUNT" -gt 1 ]; then
            # 保留当前使用的内核，清理其他
            if command -v package-cleanup &>/dev/null; then
                package-cleanup --oldkernels --count=1 -y &>/dev/null
            else
                # yum-utils 未安装时的备选方案
                local CUR_KERNEL=$(uname -r)
                rpm -q kernel | grep -v "$CUR_KERNEL" | xargs yum remove -y &>/dev/null
            fi
            echo -e "${GREEN}  ✔ 旧内核已清理 (保留当前内核)${PLAIN}"
        else
            echo -e "${GREEN}  ✔ 没有旧内核需要清理${PLAIN}"
        fi
    else
        # Debian/Ubuntu
        local OLD_KERNELS=$(dpkg -l 'linux-image-*' 2>/dev/null | grep '^ii' | awk '{print $2}' | grep -v "$(uname -r)" | grep -v 'linux-image-generic')
        if [ -n "$OLD_KERNELS" ]; then
            echo "$OLD_KERNELS" | xargs apt-get purge -y &>/dev/null
            echo -e "${GREEN}  ✔ 旧内核已清理 (保留当前内核)${PLAIN}"
        else
            echo -e "${GREEN}  ✔ 没有旧内核需要清理${PLAIN}"
        fi
    fi
}

# --- 清理无用依赖包 ---
function _clean_unused_deps() {
    local PKG_MGR="$1"
    echo ""
    echo -e "${YELLOW}→ 正在清理无用依赖包...${PLAIN}"
    if [ "$PKG_MGR" == "yum" ]; then
        if command -v package-cleanup &>/dev/null; then
            package-cleanup --leaves -y &>/dev/null
        fi
        echo -e "${GREEN}  ✔ 依赖包检查完成${PLAIN}"
    else
        apt-get autoremove -y &>/dev/null
        echo -e "${GREEN}  ✔ 无用依赖包已清理${PLAIN}"
    fi
}

# --- Docker 缓存清理 ---
function _clean_docker() {
    # 检查 Docker 是否安装
    if ! command -v docker &>/dev/null; then
        echo ""
        echo -e "${RED}✘ Docker 未安装，无需清理。${PLAIN}"
        return 0
    fi

    # 检查 Docker 是否运行
    if ! docker info &>/dev/null; then
        echo ""
        echo -e "${RED}✘ Docker 服务未运行，请先启动 Docker。${PLAIN}"
        return 1
    fi

    while true; do
        clear
        echo -e "${BLUE}=== Docker 缓存清理 ===${PLAIN}"
        echo ""

        # 显示 Docker 磁盘使用情况
        echo -e "  ${CYAN}Docker 磁盘使用概况:${PLAIN}"
        docker system df 2>/dev/null | while IFS= read -r line; do
            echo -e "    $line"
        done

        echo ""
        echo -e "  ${BLUE}--- 清理模式 ---${PLAIN}"
        echo "  1. 清理悬空镜像 (dangling images, 无标签的中间镜像)"
        echo "  2. 清理所有未使用镜像 (包括无容器引用的镜像)"
        echo "  3. 清理已停止的容器"
        echo "  4. 清理未使用的数据卷"
        echo "  5. 清理构建缓存 (build cache)"
        echo "  6. 清理未使用的网络"
        echo -e "  ${YELLOW}7. 全面清理 (一键清理以上所有)${PLAIN}"
        echo -e "  ${RED}8. 深度清理 (强制删除所有未运行资源, 慎用!)${PLAIN}"
        echo ""
        echo "  0. 返回"
        echo ""
        read -p "  请选择 [0-8]: " docker_choice

        case $docker_choice in
            1)
                echo ""
                echo -e "${YELLOW}→ 正在清理悬空镜像...${PLAIN}"
                local DANGLING=$(docker images -f 'dangling=true' -q 2>/dev/null | wc -l)
                if [ "$DANGLING" -gt 0 ]; then
                    docker image prune -f 2>/dev/null
                    echo -e "${GREEN}  ✔ 已清理 ${DANGLING} 个悬空镜像${PLAIN}"
                else
                    echo -e "${GREEN}  ✔ 没有悬空镜像需要清理${PLAIN}"
                fi
                ;;
            2)
                echo ""
                echo -e "${YELLOW}⚠ 此操作将删除所有未被容器使用的镜像${PLAIN}"
                read -p "  确认清理？[y/N]: " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    echo -e "${YELLOW}→ 正在清理未使用镜像...${PLAIN}"
                    docker image prune -a -f 2>/dev/null
                    echo -e "${GREEN}  ✔ 所有未使用镜像已清理${PLAIN}"
                else
                    echo -e "${YELLOW}  已取消${PLAIN}"
                fi
                ;;
            3)
                echo ""
                local STOPPED=$(docker ps -a -f 'status=exited' -q 2>/dev/null | wc -l)
                if [ "$STOPPED" -gt 0 ]; then
                    echo -e "${CYAN}  发现 ${STOPPED} 个已停止的容器:${PLAIN}"
                    docker ps -a -f 'status=exited' --format '    {{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null
                    echo ""
                    read -p "  确认清理所有已停止容器？[y/N]: " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        docker container prune -f 2>/dev/null
                        echo -e "${GREEN}  ✔ 已清理 ${STOPPED} 个已停止容器${PLAIN}"
                    else
                        echo -e "${YELLOW}  已取消${PLAIN}"
                    fi
                else
                    echo -e "${GREEN}  ✔ 没有已停止的容器需要清理${PLAIN}"
                fi
                ;;
            4)
                echo ""
                local UNUSED_VOL=$(docker volume ls -f 'dangling=true' -q 2>/dev/null | wc -l)
                if [ "$UNUSED_VOL" -gt 0 ]; then
                    echo -e "${YELLOW}⚠ 发现 ${UNUSED_VOL} 个未使用数据卷，删除后数据不可恢复！${PLAIN}"
                    docker volume ls -f 'dangling=true' --format '    {{.Name}}' 2>/dev/null | head -20
                    echo ""
                    read -p "  确认清理？[y/N]: " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        docker volume prune -f 2>/dev/null
                        echo -e "${GREEN}  ✔ 已清理 ${UNUSED_VOL} 个未使用数据卷${PLAIN}"
                    else
                        echo -e "${YELLOW}  已取消${PLAIN}"
                    fi
                else
                    echo -e "${GREEN}  ✔ 没有未使用数据卷需要清理${PLAIN}"
                fi
                ;;
            5)
                echo ""
                echo -e "${YELLOW}→ 正在清理构建缓存...${PLAIN}"
                docker builder prune -f 2>/dev/null
                echo -e "${GREEN}  ✔ 构建缓存已清理${PLAIN}"
                ;;
            6)
                echo ""
                echo -e "${YELLOW}→ 正在清理未使用网络...${PLAIN}"
                docker network prune -f 2>/dev/null
                echo -e "${GREEN}  ✔ 未使用网络已清理${PLAIN}"
                ;;
            7)
                echo ""
                echo -e "${YELLOW}⚠ 将执行全面清理：悬空镜像 + 已停止容器 + 未使用网络 + 构建缓存${PLAIN}"
                echo -e "${YELLOW}  (不会删除有标签的镜像和数据卷，相对安全)${PLAIN}"
                read -p "  确认执行？[y/N]: " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    echo -e "${YELLOW}→ 正在执行全面清理...${PLAIN}"
                    docker system prune -f 2>/dev/null
                    docker builder prune -f 2>/dev/null
                    echo -e "${GREEN}  ✔ Docker 全面清理完成${PLAIN}"
                else
                    echo -e "${YELLOW}  已取消${PLAIN}"
                fi
                ;;
            8)
                echo ""
                echo -e "${RED}╔══════════════════════════════════════════════╗${PLAIN}"
                echo -e "${RED}║  ⚠ 深度清理将删除：                          ║${PLAIN}"
                echo -e "${RED}║    • 所有已停止的容器                         ║${PLAIN}"
                echo -e "${RED}║    • 所有未使用的镜像 (包括有标签的)           ║${PLAIN}"
                echo -e "${RED}║    • 所有未使用的数据卷 (数据不可恢复！)       ║${PLAIN}"
                echo -e "${RED}║    • 所有未使用的网络                         ║${PLAIN}"
                echo -e "${RED}║    • 所有构建缓存                             ║${PLAIN}"
                echo -e "${RED}╚══════════════════════════════════════════════╝${PLAIN}"
                echo ""
                read -p "  输入 YES 确认深度清理: " confirm
                if [ "$confirm" == "YES" ]; then
                    echo -e "${YELLOW}→ 正在执行深度清理...${PLAIN}"
                    docker system prune -a --volumes -f 2>/dev/null
                    docker builder prune -a -f 2>/dev/null
                    echo ""
                    echo -e "${GREEN}  ✔ Docker 深度清理完成${PLAIN}"
                else
                    echo -e "${YELLOW}  已取消 (需输入大写 YES 才会执行)${PLAIN}"
                fi
                ;;
            0) return 0 ;;
            *) continue ;;
        esac

        echo ""
        echo -e "  ${CYAN}清理后 Docker 磁盘使用:${PLAIN}"
        docker system df 2>/dev/null | while IFS= read -r line; do
            echo -e "    $line"
        done
        echo ""
        read -p "  按回车继续..."
    done
}
