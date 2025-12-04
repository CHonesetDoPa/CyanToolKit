#!/bin/bash
# GitFastPoint Pushfast
Version="1.0.0"
Script_Special="alias gfpp='SCRIPT_PATH'"

# 配置目录和文件
CONFIG_DIR="$HOME/.local/share/CyanToolKit/config"
CONFIG_FILE="$CONFIG_DIR/gitfastpoint.conf"

# 默认提交消息
DEFAULT_COMMIT_MESSAGE="Urgently committed some changes"

# 确保配置目录存在
mkdir -p "$CONFIG_DIR"

# 检查参数
if [ "$1" = "--set-commit-message" ]; then
    if [ -z "$2" ]; then
        echo "Usage: $0 --set-commit-message \"Your commit message\""
        exit 1
    fi
    echo "COMMIT_MESSAGE=\"$2\"" > "$CONFIG_FILE"
    echo "Commit message set to: $2"
    exit 0
fi

echo "GitFastPoint Pushfast"
echo -e "\n"

# 读取配置文件中的提交消息
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    COMMIT_MESSAGE="${COMMIT_MESSAGE:-$DEFAULT_COMMIT_MESSAGE}"
else
    COMMIT_MESSAGE="$DEFAULT_COMMIT_MESSAGE"
fi

git add .
git commit -m "$COMMIT_MESSAGE"
git push