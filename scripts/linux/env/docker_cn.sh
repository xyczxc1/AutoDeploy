#!/bin/bash

#install docker in China network

USER_NAME="$USER"

# Docker 镜像加速器地址
DOCKER_MIRROR="https://mirrors.aliyun.com/docker-ce"

# 定义需要安装的包
PACKAGES="curl gnupg2"

# 辅助函数：检查命令是否存在
command_exists() {
    command -v "$1" &> /dev/null
}

# 检测 Linux 发行版并设置包管理器
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case $ID in
        "ubuntu" | "debian")
            PKG_MANAGER="apt-get"
            UPDATE_CMD="update"
            INSTALL_CMD="install -y"
            ADD_REPO_CMD="-y add-apt-repository"
            PACKAGES="curl gnupg lsb-release" # 对于基于Debian的系统，包括lsb-release
            ;;
        "centos" | "fedora" | "rhel")
            PKG_MANAGER="yum"
            UPDATE_CMD="makecache fast"
            INSTALL_CMD="install -y"
            ;;
        *)
            echo "Unsupported Linux distribution: $ID"
            exit 1
    esac
else
    echo "Error: Unable to detect Linux distribution"
    exit 1
fi

# 确保 curl 和必要的包管理工具已安装
echo "Installing required packages..."
sudo $PKG_MANAGER $UPDATE_CMD
sudo $PKG_MANAGER $INSTALL_CMD $PACKAGES

# 定义函数：添加 GPG 密钥
add_gpg_key() {
    local key_url="$1"      # GPG 密钥的 URL
    local key_id="$2"        # GPG 密钥的 ID 或名称（可选，用于日志记录）

    # 检测 Linux 发行版
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    fi

    # 定义密钥文件的本地路径
    local key_file="/tmp/docker-ce-public.key"

    # 下载 GPG 密钥
    if command_exists curl; then
        curl -fsSL "${key_url}" -o "${key_file}"
    elif command_exists wget; then
        wget -qO "${key_file}" "${key_url}"
    else
        echo "Error: curl or wget is required to download the GPG key."
        return 1
    fi

    # 导入 GPG 密钥
    echo "Adding GPG key to the system trust store..."
    if [ "$ID" = "ubuntu" ] || [ "$ID" = "debian" ]; then
        # 使用 apt-key 导入密钥（适用于 Debian/Ubuntu 系统）
        sudo apt-key add "${key_file}"
    else
        # 使用 rpm 导入密钥（适用于 RPM 系统）
        sudo rpm --import "${key_file}"
    fi

    # 可选：根据密钥 ID 记录或提供反馈
    if [ -n "$key_id" ]; then
        echo "GPG key '${key_id}' added successfully."
    fi

    return 0
}

# 添加 Docker 的官方 GPG 密钥
echo "Adding Docker's official GPG key..."
GPG_KEY_URL="${DOCKER_MIRROR}/linux/${ID}/gpg" # 这里应是正确的GPG密钥URL
# 调用函数添加 GPG 密钥
add_gpg_key "${GPG_KEY_URL}" "Docker-CE-KEY"

# 设置 Docker 仓库
echo "Setting up the Docker repository..."
case $ID in
    "ubuntu" | "debian")
        sudo $PKG_MANAGER $ADD_REPO_CMD "deb [arch=amd64] ${DOCKER_MIRROR}/linux/${ID} $VERSION_CODENAME stable"
        ;;
    "centos")
        sudo $PKG_MANAGER $INSTALL_CMD yum-utils
        sudo yum-config-manager --add-repo "${DOCKER_MIRROR}/linux/${ID}/7/x86_64/stable"
        ;;
    "fedora" | "rhel")
        sudo $PKG_MANAGER $INSTALL_CMD dnf-plugins-core
        sudo dnf config-manager --add-repo "${DOCKER_MIRROR}/linux/${ID}/$VERSION_ID/x86_64/stable"
        ;;
esac

# 安装 Docker Engine - Community
echo "Installing Docker Engine..."
sudo $PKG_MANAGER $INSTALL_CMD docker-ce docker-ce-cli containerd.io

# 启动 Docker 服务
echo "Starting Docker service..."
sudo systemctl start docker

# 验证 Docker 是否正确安装
echo "Verifying Docker installation..."
sudo docker version

# 将当前用户添加到 docker 组
echo "Adding $USER_NAME to the docker group..."
sudo usermod -aG docker $USER_NAME
echo "Please log out and back in for group membership to take effect."

# 设置 Docker
echo "Setting Docker "
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
    "registry-mirrors": ["$DOCKER_MIRROR"]
}
EOF
echo "Setting Docker completed."

# 重启 Docker 服务以应用配置
echo "Restarting Docker service to apply settings..."
sudo systemctl restart docker

echo "Docker installation and configuration completed."