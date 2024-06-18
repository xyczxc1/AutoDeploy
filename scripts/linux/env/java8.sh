#!/bin/bash

# 检查是否已经安装了Java 8
echo "开始安装java"
if type java &> /dev/null && [[ "$(java -version 2>&1)" == *"version \"1.8"* ]]; then
    echo "Java 8 已经安装。"
else
    echo "Java 8 未安装，开始安装..."

    # 检测是使用apt还是yum/dnf
    if command -v apt-get &> /dev/null; then
        # 使用apt-get
        sudo apt-get update
        sudo apt-get install -y openjdk-8-jdk
    elif command -v yum &> /dev/null; then
        # 使用yum
        sudo yum install -y java-1.8.0-openjdk
    elif command -v dnf &> /dev/null; then
        # 使用dnf
        sudo dnf install -y java-1.8.0-openjdk
    else
        echo "未找到合适的包管理器，请手动安装Java 8。"
        exit 1
    fi

    # 配置环境变量
    echo 'export JAVA_HOME=$(dirname $(dirname $(realpath $(which java))))' >> ~/.bashrc
    echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.bashrc

    # 使环境变量生效
    source ~/.bashrc

    echo "Java 8 安装并配置完成。"
fi