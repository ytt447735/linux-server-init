#!/bin/bash
# NTP 校时公共脚本
# 供 rhel_init.sh 和 debian_init.sh 通过 source 引入调用

# 颜色定义（如果未被父脚本定义，则在此定义）
RED=${RED:-'\033[31m'}
GREEN=${GREEN:-'\033[32m'}
YELLOW=${YELLOW:-'\033[33m'}
BLUE=${BLUE:-'\033[34m'}
CYAN='\033[36m'
PLAIN=${PLAIN:-'\033[0m'}

# ================= NTP 校时 =================
function sync_time() {
    local PKG_MGR="$1"  # yum 或 apt

    # ---------- 安装 chrony 或 ntpdate ----------
    local USE_CHRONY=0
    local USE_NTPDATE=0

    if command -v chronyc &> /dev/null; then
        USE_CHRONY=1
    elif command -v ntpdate &> /dev/null; then
        USE_NTPDATE=1
    else
        echo -e "${YELLOW}未检测到校时工具，正在安装 chrony ...${PLAIN}"
        if [ "$PKG_MGR" == "yum" ]; then
            yum install -y chrony &> /dev/null
        else
            apt-get install -y chrony &> /dev/null
        fi

        if command -v chronyc &> /dev/null; then
            USE_CHRONY=1
            echo -e "${GREEN}chrony 安装成功。${PLAIN}"
        else
            echo -e "${YELLOW}chrony 安装失败，尝试安装 ntpdate 作为替代...${PLAIN}"
            if [ "$PKG_MGR" == "yum" ]; then
                yum install -y ntpdate &> /dev/null
            else
                apt-get install -y ntpdate &> /dev/null
            fi

            if command -v ntpdate &> /dev/null; then
                USE_NTPDATE=1
                echo -e "${GREEN}ntpdate 安装成功。${PLAIN}"
            else
                echo -e "${RED}无法安装任何校时工具，请手动安装 chrony 或 ntpdate。${PLAIN}"
                return 1
            fi
        fi
    fi

    # ---------- 选择 NTP 服务商 ----------
    while true; do
        clear
        echo -e "${BLUE}============================================${PLAIN}"
        echo -e "${BLUE}          ⏰ NTP 时间同步 (校时)            ${PLAIN}"
        echo -e "${BLUE}============================================${PLAIN}"
        echo ""
        echo -e " 当前系统时间: ${CYAN}$(date '+%Y-%m-%d %H:%M:%S %Z')${PLAIN}"
        echo ""
        if [ $USE_CHRONY -eq 1 ]; then
            echo -e " 校时工具: ${GREEN}chrony${PLAIN}"
        else
            echo -e " 校时工具: ${GREEN}ntpdate${PLAIN}"
        fi
        echo ""
        echo -e "${BLUE}------------ 选择 NTP 服务商 ----------------${PLAIN}"
        echo "  1. 阿里云          (ntp.aliyun.com)"
        echo "  2. 腾讯云          (time1.cloud.tencent.com)"
        echo "  3. 华为云          (ntp.myhuaweicloud.com)"
        echo "  4. 百度            (ntp.baidu.com)"
        echo "  5. 清华大学        (ntp.tuna.tsinghua.edu.cn)"
        echo "  6. 国家授时中心    (ntp.ntsc.ac.cn)"
        echo "  7. 中国 NTP 池     (cn.pool.ntp.org)"
        echo -e "${BLUE}----------------------------------------------${PLAIN}"
        echo "  0. 返回上级菜单"
        echo ""
        read -p "  请选择 NTP 服务商 [0-7]: " ntp_choice

        local NTP_SERVER=""
        local NTP_NAME=""
        case $ntp_choice in
            1) NTP_SERVER="ntp.aliyun.com";           NTP_NAME="阿里云" ;;
            2) NTP_SERVER="time1.cloud.tencent.com";   NTP_NAME="腾讯云" ;;
            3) NTP_SERVER="ntp.myhuaweicloud.com";     NTP_NAME="华为云" ;;
            4) NTP_SERVER="ntp.baidu.com";             NTP_NAME="百度" ;;
            5) NTP_SERVER="ntp.tuna.tsinghua.edu.cn";  NTP_NAME="清华大学" ;;
            6) NTP_SERVER="ntp.ntsc.ac.cn";            NTP_NAME="国家授时中心" ;;
            7) NTP_SERVER="cn.pool.ntp.org";           NTP_NAME="中国 NTP 池" ;;
            0) return 0 ;;
            *)
                echo -e "${RED}无效选择，请重新输入。${PLAIN}"
                sleep 1
                continue
                ;;
        esac

        echo ""
        echo -e "${BLUE}----------- 开始校时 -----------${PLAIN}"
        echo -e " NTP 服务商: ${GREEN}${NTP_NAME}${PLAIN}"
        echo -e " NTP 地址:   ${GREEN}${NTP_SERVER}${PLAIN}"
        echo ""

        # 记录同步前时间
        local TIME_BEFORE=$(date '+%Y-%m-%d %H:%M:%S')

        # ---------- 执行校时 ----------
        if [ $USE_CHRONY -eq 1 ]; then
            # 使用 chrony 进行校时
            echo -e "${YELLOW}[1/3] 正在使用 chrony 同步时间...${PLAIN}"
            # 先尝试 makestep 强制同步
            chronyd -q "server ${NTP_SERVER} iburst" 2>/dev/null
            if [ $? -ne 0 ]; then
                # 如果 chronyd -q 不支持，使用 chronyc 方式
                systemctl start chronyd 2>/dev/null
                chronyc -a "burst 4/4" &>/dev/null
                sleep 2
                chronyc -a makestep &>/dev/null
            fi
        else
            # 使用 ntpdate 进行校时
            echo -e "${YELLOW}[1/3] 正在使用 ntpdate 同步时间...${PLAIN}"
            ntpdate -u "$NTP_SERVER"
        fi

        local SYNC_RESULT=$?
        local TIME_AFTER=$(date '+%Y-%m-%d %H:%M:%S')

        if [ $SYNC_RESULT -eq 0 ]; then
            echo ""
            echo -e "${GREEN}✔ 时间同步成功！${PLAIN}"
        else
            echo ""
            echo -e "${RED}✘ 时间同步可能失败，请检查网络或更换 NTP 服务商。${PLAIN}"
        fi

        echo ""
        echo -e " 同步前: ${YELLOW}${TIME_BEFORE}${PLAIN}"
        echo -e " 同步后: ${GREEN}${TIME_AFTER}${PLAIN}"

        # ---------- 是否永久配置 ----------
        echo ""
        read -p "  是否将该 NTP 源设为永久校时源并开机自启？[y/N]: " set_permanent
        if [[ "$set_permanent" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[2/3] 正在配置永久 NTP 源...${PLAIN}"

            if [ $USE_CHRONY -eq 1 ]; then
                # 配置 chrony
                local CHRONY_CONF="/etc/chrony.conf"
                [ -f /etc/chrony/chrony.conf ] && CHRONY_CONF="/etc/chrony/chrony.conf"

                # 备份原始配置
                cp "$CHRONY_CONF" "${CHRONY_CONF}.backup.$(date +%Y%m%d%H%M%S)" 2>/dev/null

                # 注释掉原有的 server/pool 行，添加新的
                sed -i '/^server /s/^/#/' "$CHRONY_CONF"
                sed -i '/^pool /s/^/#/' "$CHRONY_CONF"

                # 在文件顶部添加新的 NTP 源
                sed -i "1i\\# === 由初始化脚本自动配置 (${NTP_NAME}) ===" "$CHRONY_CONF"
                sed -i "2i\\server ${NTP_SERVER} iburst" "$CHRONY_CONF"

                echo -e "${YELLOW}[3/3] 正在启用 chrony 开机自启...${PLAIN}"
                systemctl restart chronyd
                systemctl enable chronyd 2>/dev/null

                echo -e "${GREEN}✔ 已将 ${NTP_NAME} (${NTP_SERVER}) 设为永久 NTP 源。${PLAIN}"
                echo -e "${GREEN}✔ chrony 已设置为开机自启。${PLAIN}"
            else
                # ntpdate 无守护进程，通过 crontab 实现定时校时
                local CRON_JOB="0 */6 * * * /usr/sbin/ntpdate -u ${NTP_SERVER} > /dev/null 2>&1"
                # 移除已有的 ntpdate 定时任务
                crontab -l 2>/dev/null | grep -v "ntpdate" | crontab -
                # 添加新的定时任务（每 6 小时校时一次）
                (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

                echo -e "${GREEN}✔ 已添加 crontab 定时任务，每 6 小时自动校时。${PLAIN}"
                echo -e "${GREEN}  NTP 源: ${NTP_NAME} (${NTP_SERVER})${PLAIN}"
            fi
        else
            echo -e "${YELLOW}跳过永久配置，仅完成一次性校时。${PLAIN}"
        fi

        echo ""
        read -p "按回车继续..."
    done
}
