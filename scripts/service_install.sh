#!/bin/bash
# 常用服务安装公共脚本

RED=${RED:-'\033[31m'}
GREEN=${GREEN:-'\033[32m'}
YELLOW=${YELLOW:-'\033[33m'}
BLUE=${BLUE:-'\033[34m'}
CYAN='\033[36m'
PLAIN=${PLAIN:-'\033[0m'}

# ================= 常用服务安装 =================
function install_services() {
    local PKG_MGR="$1"

    while true; do
        clear
        echo -e "${BLUE}=== 常用服务安装 ===${PLAIN}"
        echo ""
        echo "  1. Nginx"
        echo "  2. Node.js"
        echo "  3. Python"
        echo "  4. Golang"
        echo "  5. GCC 编译环境"
        echo "  6. Docker Compose"
        echo ""
        echo "  0. 返回"
        echo ""
        read -p "  请选择 [0-6]: " svc_choice

        case $svc_choice in
            1) _install_nginx "$PKG_MGR" ;;
            2) _install_nodejs "$PKG_MGR" ;;
            3) _install_python "$PKG_MGR" ;;
            4) _install_golang ;;
            5) _install_gcc "$PKG_MGR" ;;
            6) _install_docker_compose ;;
            0) return 0 ;;
            *) continue ;;
        esac
    done
}

# ==================== 安装方式选择 ====================
# 返回: 1=原生, 2=Docker, 0=取消
function _choose_install_method() {
    local SERVICE_NAME="$1"
    echo ""
    echo -e "  ${BLUE}请选择 ${SERVICE_NAME} 安装方式:${PLAIN}"
    echo "    1. 原生安装 (直接在系统上安装)"
    echo "    2. Docker 容器安装"
    echo "    0. 取消"
    echo ""
    read -p "  请选择 [0-2]: " method
    echo "$method"
}

# Docker 容器安装通用逻辑
function _docker_run_service() {
    local SERVICE_NAME="$1"
    local IMAGE="$2"
    local DEFAULT_PORT="$3"     # 格式: "宿主机端口:容器端口"，可为空
    local DEFAULT_VOLUME="$4"   # 格式: "宿主机路径:容器路径"，可为空
    local EXTRA_ARGS="$5"       # 额外 docker run 参数

    # 检查 Docker 是否可用
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}✘ Docker 未安装！请先安装 Docker。${PLAIN}"
        read -p "按回车继续..."
        return 1
    fi

    local CONTAINER_NAME="${SERVICE_NAME,,}"  # 转小写作为容器名
    CONTAINER_NAME=$(echo "$CONTAINER_NAME" | tr ' ' '-')

    echo ""
    echo -e "${BLUE}--- Docker 容器安装 ${SERVICE_NAME} ---${PLAIN}"
    echo -e "  镜像: ${CYAN}${IMAGE}${PLAIN}"

    # 端口映射
    local PORT_ARGS=""
    if [ -n "$DEFAULT_PORT" ]; then
        echo ""
        local HOST_PORT=$(echo "$DEFAULT_PORT" | cut -d: -f1)
        local CONTAINER_PORT=$(echo "$DEFAULT_PORT" | cut -d: -f2)
        read -p "  宿主机端口 [默认 ${HOST_PORT}]: " custom_port
        custom_port=${custom_port:-$HOST_PORT}
        PORT_ARGS="-p ${custom_port}:${CONTAINER_PORT}"
        echo -e "  端口映射: ${GREEN}${custom_port}:${CONTAINER_PORT}${PLAIN}"
    fi

    # 数据卷
    local VOLUME_ARGS=""
    if [ -n "$DEFAULT_VOLUME" ]; then
        local HOST_VOL=$(echo "$DEFAULT_VOLUME" | cut -d: -f1)
        local CONT_VOL=$(echo "$DEFAULT_VOLUME" | cut -d: -f2)
        read -p "  是否挂载数据卷 ${HOST_VOL}:${CONT_VOL}？ [Y/n]: " mount_vol
        if [[ ! "$mount_vol" =~ ^[Nn]$ ]]; then
            mkdir -p "$HOST_VOL" 2>/dev/null
            VOLUME_ARGS="-v ${HOST_VOL}:${CONT_VOL}"
            echo -e "  数据卷: ${GREEN}${HOST_VOL}:${CONT_VOL}${PLAIN}"
        fi
    fi

    # 开机自启 & 自动守护
    local RESTART_POLICY=""
    echo ""
    echo "  容器重启策略:"
    echo "    1. 不自动重启 (no)"
    echo "    2. 开机自启 + 异常自动重启 (always)"
    echo "    3. 手动停止前始终重启 (unless-stopped)"
    echo ""
    read -p "  请选择 [1-3, 默认 2]: " restart_choice
    restart_choice=${restart_choice:-2}
    case $restart_choice in
        1) RESTART_POLICY="--restart=no" ;;
        3) RESTART_POLICY="--restart=unless-stopped" ;;
        *) RESTART_POLICY="--restart=always" ;;
    esac

    # 构建完整命令
    local FULL_CMD="docker run -d --name ${CONTAINER_NAME} ${RESTART_POLICY} ${PORT_ARGS} ${VOLUME_ARGS} ${EXTRA_ARGS} ${IMAGE}"

    echo ""
    echo -e "  ${CYAN}即将执行:${PLAIN}"
    echo -e "  ${YELLOW}${FULL_CMD}${PLAIN}"
    echo ""
    read -p "  确认执行？[Y/n]: " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}已取消。${PLAIN}"
        read -p "按回车继续..."
        return 0
    fi

    # 拉取镜像
    echo -e "${YELLOW}正在拉取镜像 ${IMAGE} ...${PLAIN}"
    docker pull "$IMAGE"

    # 检查容器名是否冲突
    if docker ps -a --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
        echo -e "${YELLOW}容器 ${CONTAINER_NAME} 已存在，正在移除旧容器...${PLAIN}"
        docker rm -f "$CONTAINER_NAME" &>/dev/null
    fi

    # 启动容器
    echo -e "${YELLOW}正在启动容器...${PLAIN}"
    eval "$FULL_CMD"

    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✔ ${SERVICE_NAME} 容器启动成功！${PLAIN}"
        echo -e "  容器名称: ${CYAN}${CONTAINER_NAME}${PLAIN}"
        if [ -n "$PORT_ARGS" ]; then
            echo -e "  访问地址: ${CYAN}http://服务器IP:${custom_port}${PLAIN}"
        fi
        echo ""
        echo -e "  常用管理命令:"
        echo -e "    查看日志:   ${CYAN}docker logs -f ${CONTAINER_NAME}${PLAIN}"
        echo -e "    停止容器:   ${CYAN}docker stop ${CONTAINER_NAME}${PLAIN}"
        echo -e "    启动容器:   ${CYAN}docker start ${CONTAINER_NAME}${PLAIN}"
        echo -e "    进入容器:   ${CYAN}docker exec -it ${CONTAINER_NAME} /bin/sh${PLAIN}"
        echo -e "    删除容器:   ${CYAN}docker rm -f ${CONTAINER_NAME}${PLAIN}"
    else
        echo -e "${RED}✘ 容器启动失败，请检查错误信息。${PLAIN}"
    fi
    echo ""
    read -p "按回车继续..."
}

# ==================== Nginx ====================
function _install_nginx() {
    local PKG_MGR="$1"
    local METHOD=$(_choose_install_method "Nginx")

    case $METHOD in
        1)
            echo ""
            echo -e "${YELLOW}正在安装 Nginx...${PLAIN}"
            if [ "$PKG_MGR" == "yum" ]; then
                yum install -y epel-release &>/dev/null
                yum install -y nginx
            else
                apt-get install -y nginx
            fi

            if [ $? -eq 0 ]; then
                systemctl start nginx
                systemctl enable nginx
                echo -e "${GREEN}✔ Nginx 安装成功并已启动！${PLAIN}"
                echo -e "  访问: ${CYAN}http://服务器IP${PLAIN}"
                echo -e "  配置: ${CYAN}/etc/nginx/nginx.conf${PLAIN}"
            else
                echo -e "${RED}✘ Nginx 安装失败。${PLAIN}"
            fi
            read -p "按回车继续..."
            ;;
        2)
            _docker_run_service "Nginx" "nginx:latest" "80:80" "/data/nginx/html:/usr/share/nginx/html"
            ;;
        0) return 0 ;;
    esac
}

# ==================== Node.js ====================
function _install_nodejs() {
    local PKG_MGR="$1"
    local METHOD=$(_choose_install_method "Node.js")

    case $METHOD in
        1)
            echo ""
            echo "  选择 Node.js 版本:"
            echo "    1. Node.js 18 LTS"
            echo "    2. Node.js 20 LTS"
            echo "    3. Node.js 22 LTS"
            read -p "  请选择 [1-3, 默认 2]: " node_ver
            node_ver=${node_ver:-2}

            local NODE_VERSION=""
            case $node_ver in
                1) NODE_VERSION="18" ;;
                3) NODE_VERSION="22" ;;
                *) NODE_VERSION="20" ;;
            esac

            echo -e "${YELLOW}正在安装 Node.js ${NODE_VERSION}.x (NodeSource 官方源)...${PLAIN}"
            if [ "$PKG_MGR" == "yum" ]; then
                curl -fsSL "https://rpm.nodesource.com/setup_${NODE_VERSION}.x" | bash -
                yum install -y nodejs
            else
                curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash -
                apt-get install -y nodejs
            fi

            if command -v node &>/dev/null; then
                echo -e "${GREEN}✔ Node.js 安装成功！${PLAIN}"
                echo -e "  Node: ${CYAN}$(node -v)${PLAIN}"
                echo -e "  NPM:  ${CYAN}$(npm -v)${PLAIN}"
            else
                echo -e "${RED}✘ Node.js 安装失败。${PLAIN}"
            fi
            read -p "按回车继续..."
            ;;
        2)
            echo ""
            echo "  选择 Node.js 版本:"
            echo "    1. node:18"
            echo "    2. node:20"
            echo "    3. node:22"
            read -p "  请选择 [1-3, 默认 2]: " node_ver
            local NODE_TAG=""
            case $node_ver in
                1) NODE_TAG="18" ;;
                3) NODE_TAG="22" ;;
                *) NODE_TAG="20" ;;
            esac
            _docker_run_service "Node.js" "node:${NODE_TAG}" "" "/data/node/app:/app" "-w /app"
            ;;
        0) return 0 ;;
    esac
}

# ==================== Python ====================
function _install_python() {
    local PKG_MGR="$1"
    local METHOD=$(_choose_install_method "Python")

    case $METHOD in
        1)
            echo ""
            echo -e "${YELLOW}正在安装 Python3 及 pip...${PLAIN}"
            if [ "$PKG_MGR" == "yum" ]; then
                yum install -y python3 python3-pip python3-devel
            else
                apt-get install -y python3 python3-pip python3-venv python3-dev
            fi

            if command -v python3 &>/dev/null; then
                echo -e "${GREEN}✔ Python 安装成功！${PLAIN}"
                echo -e "  Python: ${CYAN}$(python3 --version)${PLAIN}"
                echo -e "  Pip:    ${CYAN}$(pip3 --version 2>/dev/null || echo '未安装')${PLAIN}"

                # 配置 pip 国内源
                read -p "  是否配置 pip 使用阿里云镜像源？[Y/n]: " pip_mirror
                if [[ ! "$pip_mirror" =~ ^[Nn]$ ]]; then
                    mkdir -p ~/.pip
                    cat > ~/.pip/pip.conf <<EOF
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/
trusted-host = mirrors.aliyun.com
EOF
                    echo -e "${GREEN}  ✔ pip 镜像源已配置为阿里云${PLAIN}"
                fi
            else
                echo -e "${RED}✘ Python 安装失败。${PLAIN}"
            fi
            read -p "按回车继续..."
            ;;
        2)
            echo ""
            echo "  选择 Python 版本:"
            echo "    1. python:3.10"
            echo "    2. python:3.11"
            echo "    3. python:3.12"
            read -p "  请选择 [1-3, 默认 3]: " py_ver
            local PY_TAG=""
            case $py_ver in
                1) PY_TAG="3.10" ;;
                2) PY_TAG="3.11" ;;
                *) PY_TAG="3.12" ;;
            esac
            _docker_run_service "Python" "python:${PY_TAG}" "" "/data/python/app:/app" "-w /app"
            ;;
        0) return 0 ;;
    esac
}

# ==================== Golang ====================
function _install_golang() {
    local METHOD=$(_choose_install_method "Golang")

    case $METHOD in
        1)
            echo ""
            echo "  选择 Go 版本:"
            echo "    1. Go 1.21"
            echo "    2. Go 1.22"
            echo "    3. Go 1.23"
            read -p "  请选择 [1-3, 默认 3]: " go_ver

            local GO_VERSION=""
            case $go_ver in
                1) GO_VERSION="1.21.13" ;;
                2) GO_VERSION="1.22.10" ;;
                *) GO_VERSION="1.23.5" ;;
            esac

            local ARCH=$(uname -m)
            local GO_ARCH="amd64"
            [ "$ARCH" == "aarch64" ] && GO_ARCH="arm64"

            echo -e "${YELLOW}正在下载 Go ${GO_VERSION}...${PLAIN}"
            local GO_TAR="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
            curl -LO "https://go.dev/dl/${GO_TAR}"

            if [ $? -ne 0 ]; then
                echo -e "${RED}✘ 下载失败，请检查网络。${PLAIN}"
                read -p "按回车继续..."
                return 1
            fi

            echo -e "${YELLOW}正在安装...${PLAIN}"
            rm -rf /usr/local/go
            tar -C /usr/local -xzf "$GO_TAR"
            rm -f "$GO_TAR"

            # 配置环境变量
            if ! grep -q '/usr/local/go/bin' /etc/profile; then
                cat >> /etc/profile <<'EOF'

# Golang
export GOROOT=/usr/local/go
export GOPATH=/root/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
EOF
            fi
            export PATH=$PATH:/usr/local/go/bin

            if /usr/local/go/bin/go version &>/dev/null; then
                echo -e "${GREEN}✔ Golang 安装成功！${PLAIN}"
                echo -e "  版本: ${CYAN}$(/usr/local/go/bin/go version)${PLAIN}"
                echo -e "  ${YELLOW}请执行 source /etc/profile 以加载环境变量${PLAIN}"

                # 配置 GOPROXY
                read -p "  是否配置 GOPROXY 国内代理 (goproxy.cn)？[Y/n]: " go_proxy
                if [[ ! "$go_proxy" =~ ^[Nn]$ ]]; then
                    /usr/local/go/bin/go env -w GOPROXY=https://goproxy.cn,direct
                    echo -e "${GREEN}  ✔ GOPROXY 已配置为 goproxy.cn${PLAIN}"
                fi
            else
                echo -e "${RED}✘ Golang 安装失败。${PLAIN}"
            fi
            read -p "按回车继续..."
            ;;
        2)
            echo ""
            echo "  选择 Go 版本:"
            echo "    1. golang:1.21"
            echo "    2. golang:1.22"
            echo "    3. golang:1.23"
            read -p "  请选择 [1-3, 默认 3]: " go_ver
            local GO_TAG=""
            case $go_ver in
                1) GO_TAG="1.21" ;;
                2) GO_TAG="1.22" ;;
                *) GO_TAG="1.23" ;;
            esac
            _docker_run_service "Golang" "golang:${GO_TAG}" "" "/data/golang/app:/app" "-w /app"
            ;;
        0) return 0 ;;
    esac
}

# ==================== GCC ====================
function _install_gcc() {
    local PKG_MGR="$1"
    local METHOD=$(_choose_install_method "GCC 编译环境")

    case $METHOD in
        1)
            echo ""
            echo -e "${YELLOW}正在安装 GCC 编译环境...${PLAIN}"
            if [ "$PKG_MGR" == "yum" ]; then
                yum groupinstall -y "Development Tools"
                yum install -y gcc gcc-c++ make cmake autoconf automake
            else
                apt-get install -y build-essential gcc g++ make cmake autoconf automake
            fi

            if command -v gcc &>/dev/null; then
                echo -e "${GREEN}✔ GCC 编译环境安装成功！${PLAIN}"
                echo -e "  GCC:   ${CYAN}$(gcc --version | head -1)${PLAIN}"
                echo -e "  G++:   ${CYAN}$(g++ --version 2>/dev/null | head -1 || echo 'N/A')${PLAIN}"
                echo -e "  Make:  ${CYAN}$(make --version 2>/dev/null | head -1 || echo 'N/A')${PLAIN}"
                echo -e "  CMake: ${CYAN}$(cmake --version 2>/dev/null | head -1 || echo 'N/A')${PLAIN}"
            else
                echo -e "${RED}✘ GCC 安装失败。${PLAIN}"
            fi
            read -p "按回车继续..."
            ;;
        2)
            _docker_run_service "GCC" "gcc:latest" "" "/data/gcc/src:/src" "-w /src"
            ;;
        0) return 0 ;;
    esac
}

# ==================== Docker Compose ====================
function _install_docker_compose() {
    echo ""

    # 检查 Docker
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}✘ Docker 未安装！请先安装 Docker。${PLAIN}"
        read -p "按回车继续..."
        return 1
    fi

    # 检查是否已安装 (v2 plugin or standalone)
    if docker compose version &>/dev/null; then
        echo -e "${GREEN}Docker Compose 已安装:${PLAIN}"
        docker compose version
        read -p "  是否重新安装/更新？[y/N]: " reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi

    echo -e "${BLUE}--- 安装 Docker Compose ---${PLAIN}"
    echo ""
    echo "  1. Docker Compose V2 (Docker 插件版, 推荐)"
    echo "  2. Docker Compose V1 (独立二进制版)"
    echo "  0. 取消"
    echo ""
    read -p "  请选择 [0-2, 默认 1]: " dc_ver
    dc_ver=${dc_ver:-1}

    case $dc_ver in
        1)
            echo -e "${YELLOW}正在安装 Docker Compose V2 插件...${PLAIN}"
            mkdir -p /usr/local/lib/docker/cli-plugins
            local ARCH=$(uname -m)
            [ "$ARCH" == "aarch64" ] && ARCH="aarch64"
            [ "$ARCH" == "x86_64" ] && ARCH="x86_64"

            local COMPOSE_URL="https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${ARCH}"
            curl -SL "$COMPOSE_URL" -o /usr/local/lib/docker/cli-plugins/docker-compose

            if [ $? -eq 0 ]; then
                chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
                echo -e "${GREEN}✔ Docker Compose V2 安装成功！${PLAIN}"
                docker compose version
            else
                echo -e "${RED}✘ 下载失败，请检查网络或使用国内镜像。${PLAIN}"
            fi
            ;;
        2)
            echo -e "${YELLOW}正在安装 Docker Compose V1 独立版...${PLAIN}"
            local ARCH=$(uname -m)
            local COMPOSE_URL="https://github.com/docker/compose/releases/latest/download/docker-compose-Linux-${ARCH}"
            curl -SL "$COMPOSE_URL" -o /usr/local/bin/docker-compose

            if [ $? -eq 0 ]; then
                chmod +x /usr/local/bin/docker-compose
                echo -e "${GREEN}✔ Docker Compose V1 安装成功！${PLAIN}"
                docker-compose version
            else
                echo -e "${RED}✘ 下载失败。${PLAIN}"
            fi
            ;;
        0) return 0 ;;
    esac
    read -p "按回车继续..."
}
