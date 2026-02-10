#!/bin/bash
# 定时任务管理公共脚本

RED=${RED:-'\033[31m'}
GREEN=${GREEN:-'\033[32m'}
YELLOW=${YELLOW:-'\033[33m'}
BLUE=${BLUE:-'\033[34m'}
CYAN='\033[36m'
PLAIN=${PLAIN:-'\033[0m'}

# ================= 定时任务管理 =================
function cron_management() {
    while true; do
        clear
        echo -e "${BLUE}=== 定时任务管理 (Crontab) ===${PLAIN}"
        echo ""
        echo "  1. 查看当前用户定时任务"
        echo "  2. 查看所有用户定时任务"
        echo "  3. 添加定时任务"
        echo "  4. 添加常用定时任务 (模板)"
        echo "  5. 删除定时任务"
        echo "  6. 编辑定时任务 (vi)"
        echo "  7. 查看 cron 表达式说明"
        echo ""
        echo "  0. 返回"
        echo ""
        read -p "  请选择 [0-7]: " cron_choice

        case $cron_choice in
            1) _list_crontab ;;
            2) _list_all_crontab ;;
            3) _add_crontab ;;
            4) _add_crontab_template ;;
            5) _delete_crontab ;;
            6) _edit_crontab ;;
            7) _show_cron_help ;;
            0) return 0 ;;
            *) continue ;;
        esac
        echo ""
        read -p "按回车继续..."
    done
}

# --- 查看当前用户定时任务 ---
function _list_crontab() {
    echo ""
    echo -e "${BLUE}--- 当前用户 ($(whoami)) 的定时任务 ---${PLAIN}"
    echo ""
    local TASKS=$(crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$')
    if [ -z "$TASKS" ]; then
        echo -e "  ${YELLOW}暂无定时任务${PLAIN}"
    else
        local IDX=1
        crontab -l 2>/dev/null | grep -v '^$' | while IFS= read -r line; do
            if [[ "$line" == \#* ]]; then
                echo -e "  ${CYAN}${line}${PLAIN}"
            else
                echo -e "  [${IDX}] ${line}"
                IDX=$((IDX + 1))
            fi
        done
    fi
}

# --- 查看所有用户定时任务 ---
function _list_all_crontab() {
    echo ""
    echo -e "${BLUE}--- 所有用户的定时任务 ---${PLAIN}"

    # 系统级 cron
    echo ""
    echo -e "  ${CYAN}[系统级 /etc/crontab]${PLAIN}"
    if [ -f /etc/crontab ]; then
        grep -v '^#' /etc/crontab | grep -v '^$' | while IFS= read -r line; do
            echo "    $line"
        done
    fi

    # /etc/cron.d/
    if [ -d /etc/cron.d ]; then
        echo ""
        echo -e "  ${CYAN}[/etc/cron.d/ 目录]${PLAIN}"
        for f in /etc/cron.d/*; do
            [ -f "$f" ] || continue
            echo -e "    ${YELLOW}$(basename $f):${PLAIN}"
            grep -v '^#' "$f" | grep -v '^$' | while IFS= read -r line; do
                echo "      $line"
            done
        done
    fi

    # 各用户 crontab
    echo ""
    echo -e "  ${CYAN}[用户级 Crontab]${PLAIN}"
    local HAS_USER_CRON=false
    for user_home in /home/*; do
        local user=$(basename "$user_home")
        local user_cron=$(crontab -l -u "$user" 2>/dev/null | grep -v '^#' | grep -v '^$')
        if [ -n "$user_cron" ]; then
            HAS_USER_CRON=true
            echo -e "    ${YELLOW}${user}:${PLAIN}"
            echo "$user_cron" | while IFS= read -r line; do
                echo "      $line"
            done
        fi
    done

    # root
    local root_cron=$(crontab -l -u root 2>/dev/null | grep -v '^#' | grep -v '^$')
    if [ -n "$root_cron" ]; then
        HAS_USER_CRON=true
        echo -e "    ${YELLOW}root:${PLAIN}"
        echo "$root_cron" | while IFS= read -r line; do
            echo "      $line"
        done
    fi

    if [ "$HAS_USER_CRON" == "false" ]; then
        echo "    暂无"
    fi

    # 周期性任务目录
    echo ""
    echo -e "  ${CYAN}[周期性任务目录]${PLAIN}"
    for dir in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
        local count=$(ls -1 "$dir" 2>/dev/null | wc -l)
        echo -e "    $(basename $dir): ${count} 个任务"
    done
}

# --- 添加定时任务 ---
function _add_crontab() {
    echo ""
    echo -e "${BLUE}--- 添加定时任务 ---${PLAIN}"
    echo ""
    echo -e "  ${CYAN}Cron 表达式格式: 分 时 日 月 周 命令${PLAIN}"
    echo -e "  ${CYAN}示例: */5 * * * * /usr/bin/curl http://example.com${PLAIN}"
    echo ""

    read -p "  请输入 cron 表达式 (分 时 日 月 周): " cron_expr
    if [ -z "$cron_expr" ]; then
        echo -e "${YELLOW}  已取消${PLAIN}"
        return 0
    fi

    read -p "  请输入要执行的命令: " cron_cmd
    if [ -z "$cron_cmd" ]; then
        echo -e "${YELLOW}  已取消${PLAIN}"
        return 0
    fi

    read -p "  添加备注 (可选，留空跳过): " cron_comment

    local FULL_LINE="${cron_expr} ${cron_cmd}"

    echo ""
    echo -e "  ${CYAN}将添加的定时任务:${PLAIN}"
    if [ -n "$cron_comment" ]; then
        echo -e "  # ${cron_comment}"
    fi
    echo -e "  ${FULL_LINE}"
    echo ""
    read -p "  确认添加？[y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if [ -n "$cron_comment" ]; then
            (crontab -l 2>/dev/null; echo "# ${cron_comment}"; echo "${FULL_LINE}") | crontab -
        else
            (crontab -l 2>/dev/null; echo "${FULL_LINE}") | crontab -
        fi
        echo -e "${GREEN}  ✔ 定时任务已添加${PLAIN}"
    else
        echo -e "${YELLOW}  已取消${PLAIN}"
    fi
}

# --- 常用定时任务模板 ---
function _add_crontab_template() {
    echo ""
    echo -e "${BLUE}--- 常用定时任务模板 ---${PLAIN}"
    echo ""
    echo "  1. 每日凌晨 3 点执行脚本"
    echo "  2. 每小时执行一次"
    echo "  3. 每 5 分钟执行一次"
    echo "  4. 每周一凌晨 2 点执行"
    echo "  5. 每月 1 号凌晨执行"
    echo "  6. 每日清理 /tmp 超 7 天文件"
    echo "  7. 每日备份数据库 (MySQL)"
    echo "  8. 每日重启某个服务"
    echo ""
    echo "  0. 返回"
    echo ""
    read -p "  请选择模板 [0-8]: " tpl_choice

    local cron_expr=""
    local cron_cmd=""
    local cron_comment=""

    case $tpl_choice in
        1)
            cron_expr="0 3 * * *"
            cron_comment="每日凌晨 3 点执行脚本"
            read -p "  请输入要执行的脚本路径: " cron_cmd
            ;;
        2)
            cron_expr="0 * * * *"
            cron_comment="每小时执行一次"
            read -p "  请输入要执行的命令: " cron_cmd
            ;;
        3)
            cron_expr="*/5 * * * *"
            cron_comment="每 5 分钟执行一次"
            read -p "  请输入要执行的命令: " cron_cmd
            ;;
        4)
            cron_expr="0 2 * * 1"
            cron_comment="每周一凌晨 2 点执行"
            read -p "  请输入要执行的命令: " cron_cmd
            ;;
        5)
            cron_expr="0 0 1 * *"
            cron_comment="每月 1 号凌晨执行"
            read -p "  请输入要执行的命令: " cron_cmd
            ;;
        6)
            cron_expr="0 2 * * *"
            cron_cmd="find /tmp -type f -mtime +7 -delete"
            cron_comment="每日凌晨 2 点清理 /tmp 超 7 天文件"
            ;;
        7)
            cron_expr="0 3 * * *"
            cron_comment="每日凌晨 3 点备份 MySQL"
            read -p "  数据库名: " db_name
            read -p "  备份目录 (默认 /backup/mysql): " backup_dir
            backup_dir=${backup_dir:-/backup/mysql}
            cron_cmd="mkdir -p ${backup_dir} && mysqldump -u root ${db_name} | gzip > ${backup_dir}/${db_name}_\$(date +\\%Y\\%m\\%d_\\%H\\%M\\%S).sql.gz"
            ;;
        8)
            cron_expr="0 4 * * *"
            cron_comment="每日凌晨 4 点重启服务"
            read -p "  请输入服务名 (如 nginx): " svc_name
            cron_cmd="systemctl restart ${svc_name}"
            ;;
        0) return 0 ;;
        *) return 0 ;;
    esac

    if [ -z "$cron_cmd" ]; then
        echo -e "${YELLOW}  已取消${PLAIN}"
        return 0
    fi

    local FULL_LINE="${cron_expr} ${cron_cmd}"
    echo ""
    echo -e "  ${CYAN}将添加的定时任务:${PLAIN}"
    echo -e "  # ${cron_comment}"
    echo -e "  ${FULL_LINE}"
    echo ""
    read -p "  确认添加？[y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        (crontab -l 2>/dev/null; echo "# ${cron_comment}"; echo "${FULL_LINE}") | crontab -
        echo -e "${GREEN}  ✔ 定时任务已添加${PLAIN}"
    else
        echo -e "${YELLOW}  已取消${PLAIN}"
    fi
}

# --- 删除定时任务 ---
function _delete_crontab() {
    echo ""
    echo -e "${BLUE}--- 删除定时任务 ---${PLAIN}"

    local CRON_CONTENT=$(crontab -l 2>/dev/null)
    if [ -z "$CRON_CONTENT" ]; then
        echo -e "  ${YELLOW}暂无定时任务${PLAIN}"
        return 0
    fi

    echo ""
    local IDX=1
    local LINES=()
    while IFS= read -r line; do
        LINES+=("$line")
        if [[ "$line" != \#* ]] && [[ -n "$line" ]]; then
            echo -e "  [${IDX}] ${line}"
            IDX=$((IDX + 1))
        fi
    done <<< "$CRON_CONTENT"

    echo ""
    echo "  a. 清空所有定时任务"
    echo "  0. 返回"
    echo ""
    read -p "  请输入要删除的编号: " del_choice

    if [ "$del_choice" == "0" ]; then
        return 0
    fi

    if [ "$del_choice" == "a" ] || [ "$del_choice" == "A" ]; then
        echo -e "${YELLOW}  ⚠ 将清空所有定时任务！${PLAIN}"
        read -p "  确认清空？[y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            crontab -r 2>/dev/null
            echo -e "${GREEN}  ✔ 所有定时任务已清空${PLAIN}"
        else
            echo -e "${YELLOW}  已取消${PLAIN}"
        fi
        return 0
    fi

    # 按编号删除 (只计算非注释非空行)
    if [[ "$del_choice" =~ ^[0-9]+$ ]]; then
        local TARGET_IDX=1
        local NEW_CRON=""
        local SKIP_COMMENT=false

        for i in "${!LINES[@]}"; do
            local line="${LINES[$i]}"
            if [[ "$line" == \#* ]] || [[ -z "$line" ]]; then
                # 如果下一个非注释行是要删除的，跳过这行注释
                if [[ "$line" == \#* ]]; then
                    # 检查下一个非注释行是否是目标
                    local next_idx=$((i + 1))
                    if [ $next_idx -lt ${#LINES[@]} ]; then
                        local next_line="${LINES[$next_idx]}"
                        if [[ "$next_line" != \#* ]] && [[ -n "$next_line" ]]; then
                            if [ $TARGET_IDX -eq $del_choice ]; then
                                SKIP_COMMENT=true
                                continue
                            fi
                        fi
                    fi
                fi
                if [ "$SKIP_COMMENT" == "true" ]; then
                    SKIP_COMMENT=false
                    continue
                fi
                NEW_CRON="${NEW_CRON}${line}\n"
            else
                if [ $TARGET_IDX -eq $del_choice ]; then
                    echo -e "${YELLOW}  将删除: ${line}${PLAIN}"
                    TARGET_IDX=$((TARGET_IDX + 1))
                    continue
                fi
                NEW_CRON="${NEW_CRON}${line}\n"
                TARGET_IDX=$((TARGET_IDX + 1))
            fi
        done

        read -p "  确认删除？[y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "$NEW_CRON" | crontab -
            echo -e "${GREEN}  ✔ 定时任务已删除${PLAIN}"
        else
            echo -e "${YELLOW}  已取消${PLAIN}"
        fi
    else
        echo -e "${RED}  ✘ 无效输入${PLAIN}"
    fi
}

# --- 编辑定时任务 ---
function _edit_crontab() {
    echo ""
    echo -e "${YELLOW}  即将打开 vi 编辑器编辑定时任务...${PLAIN}"
    echo -e "${YELLOW}  保存退出: :wq    不保存退出: :q!${PLAIN}"
    read -p "  继续？[y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        crontab -e
    fi
}

# --- Cron 表达式说明 ---
function _show_cron_help() {
    echo ""
    echo -e "${BLUE}=== Cron 表达式说明 ===${PLAIN}"
    echo ""
    echo -e "  ${CYAN}格式: 分  时  日  月  周  命令${PLAIN}"
    echo ""
    echo -e "  ${CYAN}字段说明:${PLAIN}"
    echo "  ┌──────── 分钟 (0-59)"
    echo "  │ ┌────── 小时 (0-23)"
    echo "  │ │ ┌──── 日期 (1-31)"
    echo "  │ │ │ ┌── 月份 (1-12)"
    echo "  │ │ │ │ ┌ 星期 (0-7, 0和7都是周日)"
    echo "  │ │ │ │ │"
    echo "  * * * * * command"
    echo ""
    echo -e "  ${CYAN}特殊字符:${PLAIN}"
    echo "  *     任意值"
    echo "  ,     多个值      (1,3,5)"
    echo "  -     范围        (1-5)"
    echo "  /     步进        (*/5 = 每5跳一次)"
    echo ""
    echo -e "  ${CYAN}常用示例:${PLAIN}"
    echo "  */5 * * * *         每 5 分钟"
    echo "  0 * * * *           每小时整点"
    echo "  0 2 * * *           每天凌晨 2 点"
    echo "  0 2 * * 1           每周一凌晨 2 点"
    echo "  0 0 1 * *           每月 1 号零点"
    echo "  0 0 1 1 *           每年 1 月 1 日零点"
    echo "  30 3 * * 1-5        每个工作日的 3:30"
    echo "  0 */2 * * *         每 2 小时"
    echo "  0 9-18 * * 1-5      工作日 9 点到 18 点每小时"
}
