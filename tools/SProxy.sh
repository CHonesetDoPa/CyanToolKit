#!/usr/bin/env bash

# CyanToolKit System Proxy Manager
Version="1.1.0"
Script_Special="alias sproxy='source SCRIPT_PATH'"

# 默认配置
DEFAULT_CONFIG_IP="127.0.0.1"
DEFAULT_PORT="10808"
DEFAULT_TEST_URL="https://cp.cloudflare.com"
CONFIG_FILE="$HOME/.local/share/CyanToolKit/config/proxy.conf"


# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' 

# 检查必要依赖
check_dependencies() {
    local missing=()
    for cmd in curl git npm; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${YELLOW}警告: 以下依赖未找到: ${missing[*]}${NC}"
        echo -e "${YELLOW}部分功能可能无法正常工作${NC}"
    fi
}

# 显示帮助信息
show_help() {
    echo -e "${CYAN}${BOLD}CyanToolKit System Proxy Manager v${Version}${NC}"
    echo ""
    echo -e "${BOLD}用法:${NC} sproxy [选项]"
    echo ""
    echo -e "${BOLD}选项:${NC}"
    echo -e "    ${GREEN}on${NC}, ${GREEN}enable${NC}      启用代理（自动持久化到主配置文件）"
    echo -e "    ${GREEN}off${NC}, ${GREEN}disable${NC}    关闭代理（同时清除持久化配置）"
    echo -e "    ${GREEN}status${NC}             显示详细代理状态（默认选项）"
    echo -e "    ${GREEN}config${NC}             配置代理设置（IP、端口、测试URL）"
    echo -e "    ${GREEN}test${NC}               测试代理连接"
    echo -e "    ${GREEN}version${NC}            显示版本信息"
    echo -e "    ${GREEN}-h${NC}, ${GREEN}--help${NC}        显示帮助信息"
    echo ""
    echo -e "${BOLD}说明:${NC}"
    echo "    • 启用代理后，环境变量会立即在当前shell中生效并持久化到 shell_loader.sh"
    echo "    • 新开的终端会话会自动加载持久化的代理设置"
    echo "    • 配置文件位置:"
    echo -e "      - Shell加载器: ${CYAN}\${CYANTOOLKIT_CONFIG_DIR}/shell_loader.sh${NC}"
    echo -e "      - 代理配置: ${CYAN}$CONFIG_FILE${NC}"
    echo ""
    echo -e "${BOLD}示例:${NC}"
    echo "    sproxy on              # 启用代理"
    echo "    sproxy off             # 关闭代理"
    echo "    sproxy status          # 查看状态"
    echo "    sproxy config          # 交互式配置"
    echo "    sproxy config 127.0.0.1 7890  # 直接配置"
    echo ""
    echo -e "${BOLD}工具集成:${NC}"
    echo "    自动配置 Git 和 NPM 的代理设置"
}

# 创建配置目录
create_config_dir() {
    # 创建配置文件目录
    mkdir -p "$(dirname "$CONFIG_FILE")"
    # 创建环境变量文件目录
    mkdir -p "$(dirname "$ENV_FILE")" 2>/dev/null
}

# 读取配置
read_config() {
    # 使用create_config_dir函数创建配置目录
    create_config_dir
    
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        CONFIG_IP="$DEFAULT_CONFIG_IP"
        PORT="$DEFAULT_PORT"
        TEST_URL="$DEFAULT_TEST_URL"
        # 保存配置
        save_config
    fi
    
    # 确保TEST_URL有值
    TEST_URL=${TEST_URL:-$DEFAULT_TEST_URL}
}

# 保存配置
save_config() {
    create_config_dir
    cat > "$CONFIG_FILE" << EOF
# CyanToolKit Proxy Configuration
CONFIG_IP="$CONFIG_IP"
PORT="$PORT"
TEST_URL="${TEST_URL:-$DEFAULT_TEST_URL}"
EOF
    # 确保配置文件只有当前用户可读写
    chmod 600 "$CONFIG_FILE"
    echo -e "${GREEN}配置已保存到 $CONFIG_FILE${NC}"
}

# 保存代理环境变量到 shell_loader.sh
save_proxy_to_shell_loader() {
    # 获取 CyanToolKit 配置目录
    local cyantoolkit_config="${CYANTOOLKIT_CONFIG_DIR:-$HOME/.local/share/CyanToolKit/config}"
    local shell_loader="$cyantoolkit_config/shell_loader.sh"
    
    # 如果 shell_loader 不存在，不执行操作
    if [[ ! -f "$shell_loader" ]]; then
        echo -e "${YELLOW}警告: shell_loader.sh 不存在于 $shell_loader${NC}"
        return 0
    fi
    
    # 使用临时文件安全地删除旧的代理配置
    local temp_file
    temp_file=$(mktemp) || {
        echo -e "${RED}错误: 无法创建临时文件${NC}"
        return 1
    }
    
    # 使用awk精确匹配并跳过代理环境变量区块
    awk '
        /^# Proxy Environment Variables - Auto Generated$/ { skip=1; next }
        /^# End Proxy Environment Variables$/ { skip=0; next }
        !skip { print }
    ' "$shell_loader" > "$temp_file"
    
    # 验证临时文件不为空（防止意外清空配置）
    if [[ ! -s "$temp_file" ]] && [[ -s "$shell_loader" ]]; then
        echo -e "${YELLOW}警告: 处理 shell_loader.sh 时出现问题，保留原配置${NC}"
        rm -f "$temp_file"
        return 1
    fi
    
    # 安全替换配置文件
    cat "$temp_file" > "$shell_loader" && rm -f "$temp_file"
    
    # 添加新的代理环境变量配置
    cat >> "$shell_loader" << EOF

# Proxy Environment Variables - Auto Generated
# Last Updated: $(date)
export HTTP_PROXY="http://$CONFIG_IP:$PORT"
export HTTPS_PROXY="http://$CONFIG_IP:$PORT"
export FTP_PROXY="http://$CONFIG_IP:$PORT"
export SOCKS_PROXY="socks5://$CONFIG_IP:$PORT"
export ALL_PROXY="http://$CONFIG_IP:$PORT"
export NO_PROXY="127.0.0.1,localhost,10.*,192.168.*,*.local"
export http_proxy="http://$CONFIG_IP:$PORT"
export https_proxy="http://$CONFIG_IP:$PORT"
export ftp_proxy="http://$CONFIG_IP:$PORT"
export socks_proxy="socks5://$CONFIG_IP:$PORT"
export all_proxy="http://$CONFIG_IP:$PORT"
export no_proxy="127.0.0.1,localhost,10.*,192.168.*,*.local"
# End Proxy Environment Variables
EOF
    echo -e "${GREEN}✓ 代理环境变量已持久化到 shell_loader.sh${NC}"
}

# 清除 shell_loader.sh 中的代理环境变量
clear_proxy_from_shell_loader() {
    # 获取 CyanToolKit 配置目录
    local cyantoolkit_config="${CYANTOOLKIT_CONFIG_DIR:-$HOME/.local/share/CyanToolKit/config}"
    local shell_loader="$cyantoolkit_config/shell_loader.sh"
    
    # 如果 shell_loader 不存在，不执行操作
    if [[ ! -f "$shell_loader" ]]; then
        echo -e "${YELLOW}警告: shell_loader.sh 不存在于 $shell_loader${NC}"
        return 0
    fi
    
    # 使用临时文件安全地删除代理配置
    local temp_file
    temp_file=$(mktemp) || {
        echo -e "${RED}错误: 无法创建临时文件${NC}"
        return 1
    }
    
    # 使用awk精确匹配并跳过代理环境变量区块
    awk '
        /^# Proxy Environment Variables - Auto Generated$/ { skip=1; next }
        /^# End Proxy Environment Variables$/ { skip=0; next }
        !skip { print }
    ' "$shell_loader" > "$temp_file"
    
    # 验证临时文件不为空（防止意外清空配置）
    if [[ ! -s "$temp_file" ]] && [[ -s "$shell_loader" ]]; then
        echo -e "${YELLOW}警告: 处理 shell_loader.sh 时出现问题，保留原配置${NC}"
        rm -f "$temp_file"
        return 1
    fi
    
    # 安全替换配置文件
    cat "$temp_file" > "$shell_loader" && rm -f "$temp_file"
    
    echo -e "${GREEN}✓ 已从 shell_loader.sh 清除代理环境变量${NC}"
}

# 设置代理环境变量
set_proxy() {
    read_config
    
    # 持久化到 shell_loader.sh
    save_proxy_to_shell_loader
    
    # 在当前shell中设置环境变量
    export HTTP_PROXY="http://$CONFIG_IP:$PORT"
    export HTTPS_PROXY="http://$CONFIG_IP:$PORT"
    export FTP_PROXY="http://$CONFIG_IP:$PORT"
    export SOCKS_PROXY="socks5://$CONFIG_IP:$PORT"
    export ALL_PROXY="http://$CONFIG_IP:$PORT"
    export NO_PROXY="127.0.0.1,localhost,10.*,192.168.*,*.local"
    export http_proxy="http://$CONFIG_IP:$PORT"
    export https_proxy="http://$CONFIG_IP:$PORT"
    export ftp_proxy="http://$CONFIG_IP:$PORT"
    export socks_proxy="socks5://$CONFIG_IP:$PORT"
    export all_proxy="http://$CONFIG_IP:$PORT"
    export no_proxy="127.0.0.1,localhost,10.*,192.168.*,*.local"
    
    # 设置 Git 代理
    if command -v git &> /dev/null; then
        git config --global http.proxy "$HTTP_PROXY" 2>/dev/null || true
        git config --global https.proxy "$HTTP_PROXY" 2>/dev/null || true
        echo -e "${GREEN}✓ Git 代理已设置${NC}"
    fi
    
    # 设置 npm 代理
    if command -v npm &> /dev/null; then
        npm config set proxy "$HTTP_PROXY" 2>/dev/null || true
        npm config set https-proxy "$HTTP_PROXY" 2>/dev/null || true
        echo -e "${GREEN}✓ NPM 代理已设置${NC}"
    fi
    
    echo -e "${GREEN}代理已启用: $CONFIG_IP:$PORT${NC}"
    echo -e "${GREEN}✓ 代理环境变量已在当前shell和持久化配置中生效${NC}"
}

# 关闭代理
unset_proxy() {
    # 从 shell_loader.sh 中清除代理环境变量
    clear_proxy_from_shell_loader
    
    # 在当前shell中取消环境变量
    unset HTTP_PROXY HTTPS_PROXY FTP_PROXY SOCKS_PROXY ALL_PROXY NO_PROXY
    unset http_proxy https_proxy ftp_proxy socks_proxy all_proxy no_proxy
    
    # 取消 Git 代理
    if command -v git &> /dev/null; then
        git config --global --unset http.proxy 2>/dev/null || true
        git config --global --unset https.proxy 2>/dev/null || true
        echo -e "${GREEN}✓ Git 代理已清除${NC}"
    fi
    
    # 取消 npm 代理
    if command -v npm &> /dev/null; then
        npm config delete proxy 2>/dev/null || true
        npm config delete https-proxy 2>/dev/null || true
        echo -e "${GREEN}✓ NPM 代理已清除${NC}"
    fi
    
    echo -e "${GREEN}代理已关闭${NC}"
    echo -e "${GREEN}✓ 代理环境变量已从当前shell和持久化配置中清除${NC}"
}

# 测试代理连接
test_proxy() {
    read_config
    
    if ! command -v curl &> /dev/null; then
        echo -e "  ${YELLOW}✗ 无法测试: curl 命令未安装${NC}"
        return 1
    fi
    
    # 测试 HTTP 代理
    echo -e "  HTTP 代理: ${YELLOW}测试中...${NC}\c"
    if curl -s --max-time 5 --connect-timeout 3 --retry 1 --retry-delay 1 --proxy "http://$CONFIG_IP:$PORT" -I "$TEST_URL" > /dev/null 2>&1; then
        echo -e "\r  HTTP 代理: ${GREEN}✓ 连接正常${NC}      "
    else
        echo -e "\r  HTTP 代理: ${RED}✗ 连接失败${NC}      "
    fi
    
    # 测试 SOCKS5 代理
    echo -e "  SOCKS5 代理: ${YELLOW}测试中...${NC}\c"
    if curl -s --max-time 5 --connect-timeout 3 --retry 1 --retry-delay 1 --proxy "socks5://$CONFIG_IP:$PORT" -I "$TEST_URL" > /dev/null 2>&1; then
        echo -e "\r  SOCKS5 代理: ${GREEN}✓ 连接正常${NC}   "
    else
        echo -e "\r  SOCKS5 代理: ${RED}✗ 连接失败${NC}   "
    fi
}

# 显示代理状态
show_status() {
    # 获取 CyanToolKit 配置目录
    local cyantoolkit_config="${CYANTOOLKIT_CONFIG_DIR:-$HOME/.local/share/CyanToolKit/config}"
    local shell_loader="$cyantoolkit_config/shell_loader.sh"
    
    # 读取配置
    read_config
    
    # 检查各种状态
    local current_enabled=false
    local persistent_enabled=false
    local git_configured=false
    local npm_configured=false
    local port_accessible=false
    
    # 当前会话状态
    [ -n "$HTTP_PROXY" ] && current_enabled=true
    
    # 持久化状态
    [[ -f "$shell_loader" ]] && grep -q "^# Proxy Environment Variables - Auto Generated$" "$shell_loader" 2>/dev/null && persistent_enabled=true
    
    # Git 状态
    if command -v git &> /dev/null; then
        local git_proxy
        git_proxy=$(git config --global --get http.proxy 2>/dev/null)
        [[ -n "$git_proxy" ]] && git_configured=true
    fi
    
    # NPM 状态
    if command -v npm &> /dev/null; then
        local npm_proxy
        npm_proxy=$(npm config get proxy 2>/dev/null)
        [[ -n "$npm_proxy" ]] && [[ "$npm_proxy" != "null" ]] && [[ "$npm_proxy" != "undefined" ]] && npm_configured=true
    fi
    
    # 端口状态检查
    if command -v nc &> /dev/null; then
        nc -z -w2 "$CONFIG_IP" "$PORT" 2>/dev/null && port_accessible=true
    elif command -v timeout &> /dev/null && command -v bash &> /dev/null; then
        timeout 2 bash -c "</dev/tcp/$CONFIG_IP/$PORT" 2>/dev/null && port_accessible=true
    fi
    
    # 显示简化状态
    echo ""
    echo -e "${CYAN}${BOLD}CyanToolKit System Proxy Manager v${Version}${NC}"
    # 总体状态
    if $current_enabled && $persistent_enabled && $port_accessible; then
        echo -e "🟢 ${GREEN}${BOLD}运行正常${NC} - 代理已启用"
    elif $current_enabled || $persistent_enabled; then
        echo -e "🟡 ${YELLOW}${BOLD}部分启用${NC} - 代理配置未完全生效"
    else
        echo -e "🔴 ${RED}${BOLD}未启用${NC} - 代理未配置或已关闭"
    fi
    echo ""
    
    # 详细状态 - 使用表格样式
    echo -e "组件         状态         说明"
    echo -e "${CYAN}───────────────────────────────────────────────${NC}"
    
    # 当前会话
    if $current_enabled; then
        echo -e "当前会话     ${GREEN}✓ 启用${NC}      $HTTP_PROXY"
    else
        echo -e "当前会话     ${YELLOW}✗ 关闭${NC}      执行 'sproxy on' 启用"
    fi
    
    # 持久化配置
    if $persistent_enabled; then
        echo -e "持久化       ${GREEN}✓ 已保存${NC}    新终端会自动应用"
    else
        echo -e "持久化       ${YELLOW}✗ 未保存${NC}    重启终端后会失效"
    fi
    
    # 代理服务器
    if $port_accessible; then
        echo -e "代理服务器   ${GREEN}✓ 在线${NC}      连接正常"
    else
        echo -e "代理服务器   ${RED}✗ 离线${NC}      请检查代理程序是否运行"
    fi
    
    # 工具配置
    local tool_status=""
    local tool_desc=""
    
    if command -v git &> /dev/null && command -v npm &> /dev/null; then
        if $git_configured && $npm_configured; then
            tool_status="${GREEN}✓ 已配置${NC}"
            tool_desc="Git 和 NPM 均已配置"
        elif $git_configured || $npm_configured; then
            tool_status="${YELLOW}◐ 部分${NC}"
            tool_desc=$($git_configured && echo "仅 Git 已配置" || echo "仅 NPM 已配置")
        else
            tool_status="${YELLOW}✗ 未配置${NC}"
            tool_desc="Git 和 NPM 均未配置"
        fi
    elif command -v git &> /dev/null; then
        if $git_configured; then
            tool_status="${GREEN}✓ 已配置${NC}"
            tool_desc="Git 已配置"
        else
            tool_status="${YELLOW}✗ 未配置${NC}"
            tool_desc="Git 未配置"
        fi
    elif command -v npm &> /dev/null; then
        if $npm_configured; then
            tool_status="${GREEN}✓ 已配置${NC}"
            tool_desc="NPM 已配置"
        else
            tool_status="${YELLOW}✗ 未配置${NC}"
            tool_desc="NPM 未配置"
        fi
    else
        tool_status="${YELLOW}✗ 未安装${NC}"
        tool_desc="Git 和 NPM 均未安装"
    fi
    
    echo -e "工具配置     $tool_status    $tool_desc"
    
    # 连接测试（仅在代理启用时显示）
    if $current_enabled || $persistent_enabled; then
        echo ""
        echo -e "${BLUE}${BOLD}连接测试${NC}"
        echo -e "${CYAN}───────────────────────────────────────────────${NC}"
        test_proxy
    fi
    
    echo ""
}

# 配置代理
configure_proxy() {
    read_config
    
    if [ $# -eq 2 ]; then
        CONFIG_IP="$1"
        PORT="$2"
    else
        echo -e "${BLUE}当前配置: $CONFIG_IP:$PORT${NC}"
        echo -e "${BLUE}当前测试网址: $TEST_URL${NC}"
        echo -n "请输入代理IP地址 [$CONFIG_IP]: "
        read input_ip
        [ -n "$input_ip" ] && CONFIG_IP="$input_ip"
        
        echo -n "请输入代理端口 [$PORT]: "
        read input_port
        [ -n "$input_port" ] && PORT="$input_port"
        
        echo -n "请输入测试网址 [$TEST_URL]: "
        read input_test_url
        [ -n "$input_test_url" ] && TEST_URL="$input_test_url"
    fi
    
    # 验证IP地址格式和范围
    if ! [[ $CONFIG_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo -e "${RED}错误: 无效的IP地址格式${NC}"
        return 1
    fi
    
    # 验证IP地址各部分的值是否在有效范围内
    local IFS='.'
    read -ra ip_parts <<< "$CONFIG_IP"
    for part in "${ip_parts[@]}"; do
        if [[ $part -lt 0 || $part -gt 255 ]]; then
            echo -e "${RED}错误: IP地址各部分必须在0-255范围内${NC}"
            return 1
        fi
    done
    
    if ! [[ $PORT =~ ^[0-9]+$ ]]; then
        echo -e "${RED}错误: 端口必须是数字${NC}"
        return 1
    elif [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        echo -e "${RED}错误: 无效的端口号 (必须在1-65535范围内)${NC}"
        return 1
    fi
    
    save_config
}


# 主函数
main() {
    # 检查必要依赖
    check_dependencies
    
    # 如果没有参数，显示状态作为默认操作
    local cmd=${1:-status}
    case "$cmd" in
        "on"|"enable")
            set_proxy
            ;;
        "off"|"disable")
            unset_proxy
            ;;
        "status")
            show_status
            ;;
        "config")
            configure_proxy "${@:2}"
            ;;
        "-h"|"--help"|"help"|"?")
            show_help
            ;;
        "version")
            echo "CyanToolKit System Proxy Manager v$Version"
            ;;
        *)
            echo -e "${RED}错误: 未知选项 '$cmd'${NC}"
            show_help
            ;;
    esac
}

# 执行主函数
main "$@"