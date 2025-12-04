#!/usr/bin/env bash

# CyanToolKit 交互式安装脚本

set -euo pipefail  # 严格错误处理

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Shell类型设置
SHELL_TYPE="auto"  # 可选值: auto, bash, zsh

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
readonly TOOLS_DIR="$SCRIPT_DIR/tools"
readonly LOCAL_INSTALL_DIR="$HOME/.local/share/CyanToolKit/bin"

# 数据和配置目录
readonly CONFIG_DIR="$HOME/.local/share/CyanToolKit/config"
readonly DATA_DIR="$HOME/.local/share/CyanToolKit/data"

# 检查 Bash 版本兼容性
check_bash_version() {
    if [[ "${BASH_VERSION%%.*}" -lt 4 ]]; then
        echo -e "${RED}错误: 需要 Bash 4.0 或更高版本${NC}" >&2
        echo -e "当前版本: $BASH_VERSION" >&2
        return 1
    fi
}

# 安全创建临时文件
safe_mktemp() {
    local temp_file
    if ! temp_file=$(mktemp 2>/dev/null); then
        echo -e "${RED}错误: 无法创建临时文件${NC}" >&2
        return 1
    fi
    echo "$temp_file"
}

# 检查是否为root权限
check_root() {
    [[ $EUID -eq 0 ]]
}

# 确保配置和数据目录存在
ensure_dirs() {
    local dirs=("$CONFIG_DIR" "$DATA_DIR")
    local dir
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            echo -e "${CYAN}创建目录: ${BOLD}$dir${NC}"
            if ! mkdir -p "$dir" 2>/dev/null; then
                echo -e "${RED}错误: 无法创建目录 $dir${NC}" >&2
                return 1
            fi
            # 设置适当的权限 - 只有用户可读写
            if ! chmod 700 "$dir" 2>/dev/null; then
                echo -e "${YELLOW}警告: 无法设置目录权限${NC}" >&2
            fi
        fi
    done
}

# 获取终端宽度
get_terminal_width() {
    local width
    width=$(tput cols 2>/dev/null) || width=80
    echo "$width"
}

# 验证文件是否安全可写
is_file_safe_to_write() {
    local file="$1"
    local dir
    dir="$(dirname "$file")"
    
    # 检查目录是否存在或可创建
    [[ -d "$dir" ]] || mkdir -p "$dir" 2>/dev/null || return 1
    
    # 检查文件是否存在且可写，或者不存在但目录可写
    if [[ -f "$file" ]]; then
        [[ -w "$file" ]]
    else
        [[ -w "$dir" ]]
    fi
}

# 创建shell配置加载脚本（改进版）
create_shell_loader() {
    local install_dir="$1"
    local cmd_name="$2"
    local script_path="$3"
    local script_special=""
    local shell_loader="$CONFIG_DIR/shell_loader.sh"
    
    # 检查参数有效性
    if [[ -z "$install_dir" || -z "$cmd_name" || -z "$script_path" ]]; then
        echo -e "${RED}错误: create_shell_loader 参数不完整${NC}" >&2
        return 1
    fi
    
    # 检查文件写入权限
    if ! is_file_safe_to_write "$shell_loader"; then
        echo -e "${RED}错误: 无权限写入 shell_loader.sh${NC}" >&2
        return 1
    fi
    
    # 从脚本源文件读取Script_Special值
    if [[ -f "$script_path" ]]; then
        script_special=$(grep -m 1 "^Script_Special=" "$script_path" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || true)
    fi
    
    # 如果不存在则创建基础加载脚本
    if [[ ! -f "$shell_loader" ]]; then
        if ! create_basic_shell_loader "$shell_loader" "$install_dir"; then
            return 1
        fi
    fi
    
    # 验证并修复配置文件
    if ! validate_and_fix_shell_loader "$shell_loader" "$install_dir"; then
        return 1
    fi
    
    # 添加工具别名
    add_tool_alias_to_loader "$shell_loader" "$cmd_name" "$install_dir" "$script_special"
}

# 创建基础 shell 加载脚本
create_basic_shell_loader() {
    local shell_loader="$1"
    local install_dir="$2"
    
    cat > "$shell_loader" << EOF || return 1
#!/usr/bin/env bash
# CyanToolKit Shell加载脚本
# 该脚本由install.sh自动生成，融合了配置文件和工具加载功能
# 最后更新: $(date)

# ============================================
# 全局路径配置块
# ============================================
export CYANTOOLKIT_INSTALL_DIR="$install_dir"
export CYANTOOLKIT_CONFIG_DIR="$CONFIG_DIR"
export CYANTOOLKIT_DATA_DIR="$DATA_DIR"

# ============================================
# 工具别名配置块
# ============================================

EOF
    
    if ! chmod +x "$shell_loader" 2>/dev/null; then
        echo -e "${YELLOW}警告: 无法设置Shell加载脚本权限${NC}" >&2
    fi
    
    echo -e "${GREEN}│ ✓ 已创建Shell加载脚本${NC}"
    return 0
}

# 验证并修复 shell_loader
validate_and_fix_shell_loader() {
    local shell_loader="$1"
    local install_dir="$2"
    
    if [[ ! -f "$shell_loader" ]]; then
        return 0
    fi
    
    # 优先检测并清理重复行（允许失败但不退出）
    if ! detect_and_clean_duplicates "$shell_loader"; then
        echo -e "${YELLOW}│ ⚠ 重复行检测失败，继续其他处理${NC}" >&2
    fi
    
    # 然后清理已存在文件中的其他问题
    clean_existing_shell_loader "$shell_loader"
    
    # 检查配置文件完整性
    local has_global_block=false
    local has_tool_block=false
    
    if grep -q "^# 全局路径配置块$" "$shell_loader" 2>/dev/null; then
        has_global_block=true
    fi
    
    if grep -q "^# 工具别名配置块$" "$shell_loader" 2>/dev/null; then
        has_tool_block=true
    fi
    
    # 如果缺少关键区块，重建文件
    if [[ "$has_global_block" == false || "$has_tool_block" == false ]]; then
        echo -e "${YELLOW}│ → 检测到配置文件结构问题，正在修复...${NC}"
        if ! rebuild_shell_loader_structure "$shell_loader" "$install_dir"; then
            return 1
        fi
    fi
    
    # 更新全局路径配置
    update_global_paths_safe "$shell_loader" "$install_dir"
}

# 检测并清理 shell_loader.sh 中的重复行
detect_and_clean_duplicates() {
    local shell_loader="$1"
    local temp_file
    
    if [[ ! -f "$shell_loader" ]]; then
        echo -e "${GREEN}│ ✓ 配置文件不存在，跳过重复行检测${NC}"
        return 0
    fi
    
    echo -e "${CYAN}│ → 检测重复行...${NC}"
    
    # 创建临时文件
    if ! temp_file=$(safe_mktemp); then
        echo -e "${RED}│ ✗ 无法创建临时文件${NC}" >&2
        return 1
    fi
    
    # 添加错误处理，避免脚本意外退出
    set +e  # 临时关闭错误退出模式
    
    # 统计重复行
    local duplicate_count=0
    declare -A seen_lines
    declare -A seen_exports  
    declare -A seen_aliases
    
    # 添加调试信息
    echo -e "${CYAN}│ → 开始处理文件内容...${NC}"
    
    local line_count=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_count++))
        # 跳过空行
        if [[ "$line" =~ ^[[:space:]]*$ ]]; then
            echo "$line" >> "$temp_file"
            continue
        fi
        
        # 处理 export 行的重复
        if [[ "$line" =~ ^export[[:space:]]+([A-Z_]+)= ]]; then
            local var_name="${BASH_REMATCH[1]}"
            if [[ -z "${seen_exports["$var_name"]+x}" ]]; then
                seen_exports["$var_name"]=1
                echo "$line" >> "$temp_file"
            else
                ((duplicate_count++))
            fi
            continue
        fi
        
        # 处理 alias 行的重复
        if [[ "$line" =~ ^alias[[:space:]]+([^=]+)= ]]; then
            local alias_name="${BASH_REMATCH[1]}"
            if [[ -z "${seen_aliases["$alias_name"]+x}" ]]; then
                seen_aliases["$alias_name"]=1
                echo "$line" >> "$temp_file"
            else
                ((duplicate_count++))
            fi
            continue
        fi
        
        # 处理其他行的完全重复
        if [[ -z "${seen_lines["$line"]+x}" ]]; then
            seen_lines["$line"]=1
            echo "$line" >> "$temp_file"
        else
            ((duplicate_count++))
        fi
    done < "$shell_loader"
    
    echo -e "${CYAN}│ → 处理完成，共处理 $line_count 行${NC}"
    
    # 恢复错误退出模式
    set -e
    
    # 替换原文件
    if [[ -s "$temp_file" ]]; then
        if mv "$temp_file" "$shell_loader"; then
            chmod +x "$shell_loader" 2>/dev/null || true
            
            if [[ "$duplicate_count" -gt 0 ]]; then
                echo -e "${GREEN}│ ✓ 已清理 $duplicate_count 行重复内容${NC}"
            else
                echo -e "${GREEN}│ ✓ 未发现重复行${NC}"
            fi
        else
            rm -f "$temp_file"
            echo -e "${YELLOW}│ ⚠ 无法更新配置文件，保留原文件${NC}" >&2
            return 1
        fi
    else
        rm -f "$temp_file"
        echo -e "${YELLOW}│ ⚠ 清理过程中出现问题，保留原文件${NC}" >&2
        return 1
    fi
}

# 清理现有 shell_loader.sh 文件中的重复和错误内容
clean_existing_shell_loader() {
    local shell_loader="$1"
    local temp_file
    
    if [[ ! -f "$shell_loader" ]]; then
        return 0
    fi
    
    # 创建临时文件
    if ! temp_file=$(safe_mktemp); then
        return 1
    fi
    
    # 清理重复的export和错误行
    local seen_exports=()
    local in_global_block=false
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # 跳过包含 "│ →" 的日志输出行
        if [[ "$line" =~ │[[:space:]]*→ ]]; then
            continue
        fi
        
        # 检测全局配置块
        if [[ "$line" == "# 全局路径配置块" ]]; then
            in_global_block=true
            echo "$line" >> "$temp_file"
            continue
        elif [[ "$line" == "# 工具别名配置块" ]]; then
            in_global_block=false
            echo "$line" >> "$temp_file"
            continue
        fi
        
        # 处理export行的重复
        if [[ "$line" =~ ^export[[:space:]]+([A-Z_]+)= ]]; then
            local var_name="${BASH_REMATCH[1]}"
            
            # 检查是否已经见过这个变量
            local already_seen=false
            for seen_var in "${seen_exports[@]}"; do
                if [[ "$seen_var" == "$var_name" ]]; then
                    already_seen=true
                    break
                fi
            done
            
            if [[ "$already_seen" == false ]]; then
                seen_exports+=("$var_name")
                echo "$line" >> "$temp_file"
            fi
            # 如果已经见过，跳过这行
            continue
        fi
        
        echo "$line" >> "$temp_file"
    done < "$shell_loader"
    
    # 替换原文件
    if [[ -s "$temp_file" ]]; then
        mv "$temp_file" "$shell_loader" || {
            rm -f "$temp_file"
            return 1
        }
        chmod +x "$shell_loader" 2>/dev/null || true
        echo -e "${GREEN}│ ✓ 已清理配置文件中的重复内容${NC}"
    else
        rm -f "$temp_file"
        return 1
    fi
}

# 安全地重建 shell_loader 结构
rebuild_shell_loader_structure() {
    local shell_loader="$1"
    local install_dir="$2"
    local temp_file
    
    # 创建临时文件
    if ! temp_file=$(safe_mktemp); then
        return 1
    fi
    
    # 提取现有的工具别名
    local -A tool_aliases=()
    
    if [[ -f "$shell_loader" ]]; then
        # 使用更简单的方法提取别名
        while IFS= read -r line; do
            if [[ "$line" =~ ^alias[[:space:]]+([^=]+)= ]]; then
                local alias_name="${BASH_REMATCH[1]}"
                local alias_content="$line"
                tool_aliases["$alias_name"]="$alias_content"
            fi
        done < "$shell_loader"
    fi
    
    # 重建配置文件
    cat > "$temp_file" << EOF || { rm -f "$temp_file"; return 1; }
#!/usr/bin/env bash
# CyanToolKit Shell加载脚本
# 该脚本由install.sh自动生成，融合了配置文件和工具加载功能
# 最后更新: $(date)

export CYANTOOLKIT_INSTALL_DIR="$install_dir"
export CYANTOOLKIT_CONFIG_DIR="$CONFIG_DIR"
export CYANTOOLKIT_DATA_DIR="$DATA_DIR"

# ============================================

EOF
    
    # 添加现有别名
    for alias_name in "${!tool_aliases[@]}"; do
        echo >> "$temp_file"
        echo "# $alias_name 工具别名" >> "$temp_file"
        echo "${tool_aliases[$alias_name]}" >> "$temp_file"
    done
    
    # 替换原文件
    if ! mv "$temp_file" "$shell_loader"; then
        rm -f "$temp_file"
        echo -e "${RED}│ ✗ 配置文件重建失败${NC}" >&2
        return 1
    fi
    
    chmod +x "$shell_loader" 2>/dev/null || true
    echo -e "${GREEN}│ ✓ 配置文件结构已修复${NC}"
    return 0
}

# 安全地更新全局路径配置
update_global_paths_safe() {
    local shell_loader="$1"
    local install_dir="$2"
    local temp_file
    
    if [[ ! -f "$shell_loader" ]]; then
        return 0
    fi
    
    # 创建临时文件
    if ! temp_file=$(safe_mktemp); then
        return 1
    fi
    
    # 使用改进的处理逻辑，防止重复export
    local in_global_block=false
    local global_block_found=false
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "# 全局路径配置块" ]]; then
            in_global_block=true
            global_block_found=true
            echo "$line" >> "$temp_file"
            continue
        elif [[ "$line" == "# ============================================" && "$in_global_block" == true ]]; then
            # 输出更新的环境变量（只输出一次）
            echo "# ============================================" >> "$temp_file"
            echo "export CYANTOOLKIT_INSTALL_DIR=\"$install_dir\"" >> "$temp_file"
            echo "export CYANTOOLKIT_CONFIG_DIR=\"$CONFIG_DIR\"" >> "$temp_file"
            echo "export CYANTOOLKIT_DATA_DIR=\"$DATA_DIR\"" >> "$temp_file"
            echo "" >> "$temp_file"
            in_global_block=false
            continue
        elif [[ "$in_global_block" == true ]]; then
            # 跳过旧的环境变量设置和空行
            if [[ "$line" =~ ^export[[:space:]]+CYANTOOLKIT_.*= ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
                continue
            fi
        fi
        
        # 跳过重复的export行（防止在全局块外也有重复）
        if [[ "$line" =~ ^export[[:space:]]+CYANTOOLKIT_.*= ]] && [[ "$global_block_found" == true ]]; then
            continue
        fi
        
        echo "$line" >> "$temp_file"
    done < "$shell_loader"
    
    # 验证并替换文件
    if [[ -s "$temp_file" ]]; then
        mv "$temp_file" "$shell_loader" || {
            rm -f "$temp_file"
            return 1
        }
        chmod +x "$shell_loader" 2>/dev/null || true
    else
        rm -f "$temp_file"
        return 1
    fi
}

# 添加工具别名到 shell_loader
add_tool_alias_to_loader() {
    local shell_loader="$1"
    local cmd_name="$2"
    local install_dir="$3"
    local script_special="$4"
    
    # 先移除旧的别名配置（如果存在）
    remove_tool_alias_from_loader "$cmd_name" "$shell_loader"
    
    # 创建临时文件来安全地添加别名配置
    local temp_file
    if ! temp_file=$(safe_mktemp); then
        echo -e "${RED}│ 错误: 无法创建临时文件${NC}" >&2
        return 1
    fi
    
    # 复制现有内容到临时文件，同时去重任何剩余的同名alias
    if [[ -f "$shell_loader" ]]; then
        # 过滤掉任何剩余的同名alias行
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" =~ ^alias[[:space:]]+${cmd_name}[[:space:]]*= ]]; then
                # 跳过任何剩余的同名alias
                continue
            fi
            echo "$line" >> "$temp_file"
        done < "$shell_loader"
    fi
    
    # 添加新的别名配置
    {
        echo
        if [[ -n "$script_special" && "$script_special" == alias* ]]; then
            # 使用Script_Special中定义的特殊别名
            local processed_special="${script_special//SCRIPT_PATH/$install_dir/$cmd_name}"
            echo "# $cmd_name 工具别名（特殊配置: source加载）"
            echo "# Script_Special: $script_special"
            echo "$processed_special"
        else
            # 默认：创建普通的alias直接调用
            echo "# $cmd_name 工具别名"
            echo "alias $cmd_name='$install_dir/$cmd_name'"
        fi
    } >> "$temp_file"
    
    # 输出日志信息（不写入文件）
    if [[ -n "$script_special" && "$script_special" == alias* ]]; then
        local processed_special="${script_special//SCRIPT_PATH/$install_dir/$cmd_name}"
        echo -e "${CYAN}│ → 添加特殊别名: $processed_special${NC}"
    else
        echo -e "${CYAN}│ → 添加别名: alias $cmd_name='$install_dir/$cmd_name'${NC}"
    fi
    
    # 替换原文件
    if mv "$temp_file" "$shell_loader"; then
        chmod +x "$shell_loader" 2>/dev/null || true
    else
        rm -f "$temp_file"
        return 1
    fi
}

# 从shell_loader中移除指定工具的别名配置（改进版）
remove_tool_alias_from_loader() {
    local cmd_name="$1"
    local shell_loader="$2"
    local temp_file
    
    if [[ ! -f "$shell_loader" ]]; then
        return 0
    fi
    
    # 创建临时文件
    if ! temp_file=$(safe_mktemp); then
        return 1
    fi
    
    # 使用更强的清理逻辑，确保完全移除相关内容
    local in_alias_block=false
    local removed_count=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # 检查是否是目标工具的别名注释行
        if [[ "$line" =~ ^#[[:space:]]*${cmd_name}[[:space:]]*工具别名 ]]; then
            in_alias_block=true
            ((removed_count++))
            continue
        fi
        
        # 如果在别名块中，继续检查相关行
        if [[ "$in_alias_block" == true ]]; then
            # 跳过Script_Special注释行
            if [[ "$line" =~ ^#[[:space:]]*Script_Special: ]]; then
                continue
            fi
            # 跳过对应的alias行
            if [[ "$line" =~ ^alias[[:space:]]+${cmd_name}[[:space:]]*= ]]; then
                in_alias_block=false
                continue
            fi
            # 跳过紧跟的空行（最多2行）
            if [[ "$line" =~ ^[[:space:]]*$ ]]; then
                continue
            fi
            # 遇到其他内容，结束别名块
            in_alias_block=false
        fi
        
        # 额外检查：直接匹配任何包含该工具名的alias行（防止遗漏）
        if [[ "$line" =~ ^alias[[:space:]]+${cmd_name}[[:space:]]*= ]]; then
            ((removed_count++))
            continue
        fi
        
        # 保留其他行
        echo "$line" >> "$temp_file"
    done < "$shell_loader"
    
    # 替换原文件
    if [[ -s "$temp_file" ]]; then
        mv "$temp_file" "$shell_loader" || {
            rm -f "$temp_file"
            return 1
        }
        chmod +x "$shell_loader" 2>/dev/null || true
        
        if [[ "$removed_count" -gt 0 ]]; then
            echo -e "${GREEN}│ ✓ 已移除 $cmd_name 的旧配置 (${removed_count}项)${NC}"
        fi
    else
        rm -f "$temp_file"
        echo -e "${YELLOW}│ ⚠ 移除别名时出现问题，保留原配置${NC}" >&2
    fi
}

# 更新PATH环境变量（简化版）
update_path() {
    local install_dir="$1"
    local cmd_name="$2"
    local script_path="$3"
    
    # 创建shell加载脚本
    if ! create_shell_loader "$install_dir" "$cmd_name" "$script_path"; then
        return 1
    fi
    
    # 更新shell配置文件
    update_shell_config || return 1
    
    # 尝试在当前会话中加载配置
    load_config_in_current_session
}

# 更新shell配置文件
update_shell_config() {
    local shell_config=""
    local shell_name=""
    
    # 确定shell配置文件
    case "$SHELL_TYPE" in
        zsh)
            shell_config="$HOME/.zshrc"
            shell_name="zsh"
            ;;
        bash)
            shell_config="$HOME/.bashrc"
            shell_name="bash"
            ;;
        auto)
            if [[ "$SHELL" == *zsh ]]; then
                shell_config="$HOME/.zshrc"
                shell_name="zsh"
            elif [[ "$SHELL" == *bash ]]; then
                shell_config="$HOME/.bashrc"
                shell_name="bash"
            else
                echo -e "${YELLOW}│ ⚠ 无法确定shell类型，跳过shell配置更新${NC}" >&2
                echo -e "${YELLOW}│ → 请手动添加以下内容到你的shell配置文件:${NC}"
                echo -e "${CYAN}source \"${CONFIG_DIR}/shell_loader.sh\"${NC}"
                return 0
            fi
            ;;
    esac
    
    # 创建或更新shell配置文件
    if [[ -n "$shell_config" ]]; then
        if ! update_shell_config_file "$shell_config" "$shell_name"; then
            return 1
        fi
    fi
}

# 更新具体的shell配置文件
update_shell_config_file() {
    local shell_config="$1"
    local shell_name="$2"
    
    # 检查文件是否存在，不存在则创建
    if [[ ! -f "$shell_config" ]]; then
        echo -e "${YELLOW}│ ⚠ Shell配置文件不存在: $shell_config${NC}"
        echo -e "${CYAN}│ → 正在创建...${NC}"
        if ! touch "$shell_config" 2>/dev/null; then
            echo -e "${RED}│ ✗ 无法创建配置文件${NC}" >&2
            return 1
        fi
    fi
    
    # 检查是否已经添加了CyanToolKit配置
    if ! grep -q "^# CyanToolKit 配置加载$" "$shell_config" 2>/dev/null; then
        echo -e "${CYAN}│ → 添加到 ${shell_name} 配置 ($(basename "$shell_config"))...${NC}"
        
        # 确保文件末尾有换行
        if [[ -s "$shell_config" ]] && [[ -n "$(tail -c1 "$shell_config" 2>/dev/null)" ]]; then
            echo >> "$shell_config"
        fi
        
        # 添加配置加载代码
        cat >> "$shell_config" << 'EOF' || return 1

# CyanToolKit 配置加载
# 由 CyanToolKit install.sh 自动添加
# 请勿手动修改此部分，卸载时会自动清理
CYANTOOLKIT_CONFIG="${HOME}/.local/share/CyanToolKit/config/shell_loader.sh"
if [[ -f "$CYANTOOLKIT_CONFIG" ]]; then
    source "$CYANTOOLKIT_CONFIG"
fi
EOF
        echo -e "${GREEN}│ ✓ 已添加到 $shell_config${NC}"
        echo -e "${YELLOW}│ → 请执行 'source $shell_config' 或重新打开终端以应用更改${NC}"
    else
        echo -e "${GREEN}│ ✓ Shell 配置已存在，跳过添加${NC}"
    fi
}

# 在当前会话中加载配置
load_config_in_current_session() {
    local shell_loader="$CONFIG_DIR/shell_loader.sh"
    
    if [[ -f "$shell_loader" ]]; then
        echo -e "${CYAN}│ → 尝试在当前会话加载工具配置...${NC}"
        if source "$shell_loader" 2>/dev/null; then
            echo -e "${GREEN}│ ✓ 配置已在当前会话生效${NC}"
        else
            echo -e "${YELLOW}│ ⚠ 无法在当前会话加载配置，请重新打开终端${NC}"
        fi
    fi
}

# 主菜单
main_menu() {
    while true; do
        show_header
        echo -e "${CYAN}${BOLD}欢迎使用 CyanToolKit 安装程序${NC}"
        echo ""
        echo -e "安装目录: ${BOLD}$INSTALL_DIR${NC}"
        echo -e "配置目录: ${BOLD}$CONFIG_DIR${NC}"
        echo -e "数据目录: ${BOLD}$DATA_DIR${NC}"
        echo ""
        printf "${BOLD}%s)${NC} %s\n" "1" "安装脚本工具"
        printf "${BOLD}%s)${NC} %s\n" "2" "卸载脚本工具"
        printf "${BOLD}%s)${NC} %s\n" "3" "查看已安装工具"
        printf "${BOLD}%s)${NC} %s\n" "q" "退出程序"
        echo ""
        
        echo -n "请选择操作 [1-3/q]: "
        read -n 1 choice
        echo ""
        
        case $choice in
            1)
                install_mode
                ;;
            2)
                uninstall_mode
                ;;
            3)
                show_installed_tools
                ;;
            q|Q)
                echo -e "${GREEN}感谢使用 CyanToolKit！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请重试${NC}"
                echo -e "${YELLOW}按任意键继续...${NC}"
                read -n 1
                ;;
        esac
    done
}

# 创建重复字符字符串
repeat_char() {
    local char=$1
    local length=$2

    if [[ -z $char ]]; then
        return
    fi

    if (( length <= 0 )); then
        return
    fi

    local result
    printf -v result '%*s' "$length" ''
    result=${result// /$char}
    printf '%s' "$result"
}

# 显示标题
show_header() {
    clear
    local width=$(get_terminal_width)
    local min_width=72
    
    if (( width < min_width )); then
        width=$min_width
    fi

    # 创建等号分隔线
    local line=$(repeat_char '=' "$width")
    
    echo -e "${CYAN}${BOLD}${line}${NC}"
    
    local title="CyanToolKit Installer"
    local padding_len=$(( (width - ${#title}) / 2 ))
    local padding=$(repeat_char ' ' $padding_len)
    
    echo -e "${CYAN}${BOLD}${padding}${title}${padding}${NC}"
    
    echo -e "${CYAN}${BOLD}${line}${NC}"
    echo ""
}

# 检查脚本是否已安装
is_installed() {
    local script_name="$1"
    local cmd_name
    
    # 支持 .sh 和 .py 文件
    if [[ "$script_name" == *.sh ]]; then
        cmd_name=$(basename "$script_name" .sh)
    elif [[ "$script_name" == *.py ]]; then
        cmd_name=$(basename "$script_name" .py)
    else
        cmd_name="$script_name"
    fi
    
    # 检查文件是否存在于安装目录
    [[ -f "$INSTALL_DIR/$cmd_name" ]]
}

# 安装单个脚本
install_script() {
    local script_name="$1"
    local script_path="$TOOLS_DIR/$script_name"
    local cmd_name
    
    # 支持 .sh 和 .py 文件
    if [[ "$script_name" == *.sh ]]; then
        cmd_name=$(basename "$script_name" .sh)
    elif [[ "$script_name" == *.py ]]; then
        cmd_name=$(basename "$script_name" .py)
    else
        cmd_name="$script_name"
    fi
    
    local install_path="$INSTALL_DIR/$cmd_name"
    
    echo -e "${BLUE}┌─ 安装 ${BOLD}$script_name${NC}${BLUE} ─┐${NC}"
    
    # 每次安装前先检查并清理 shell_loader.sh 的重复行
    local shell_loader="$CONFIG_DIR/shell_loader.sh"
    if [[ -f "$shell_loader" ]]; then
        echo -e "${CYAN}│ → 检查配置文件完整性...${NC}"
        if ! detect_and_clean_duplicates "$shell_loader"; then
            echo -e "${YELLOW}│ ⚠ 配置文件清理失败，继续安装${NC}" >&2
        fi
    fi
    
    # 检查源文件是否存在
    if [[ ! -f "$script_path" ]]; then
        echo -e "${RED}│ 错误: 脚本文件不存在${NC}"
        echo -e "${BLUE}└─────────────────────┘${NC}"
        return 1
    fi
    
    # 显示安装位置信息
    echo -e "${CYAN}│ → 安装位置: ${BOLD}$INSTALL_DIR${NC}"
    
    # 确保安装目录存在
    if [[ ! -d "$INSTALL_DIR" ]]; then
        if ! mkdir -p "$INSTALL_DIR" 2>/dev/null; then
            echo -e "${RED}│ 错误: 无法创建安装目录${NC}"
            echo -e "${BLUE}└─────────────────────┘${NC}"
            return 1
        fi
        echo -e "${GREEN}│ ✓ 已创建目录: $INSTALL_DIR${NC}"
    fi
    
    # 检查是否已安装，询问是否覆盖
    if is_installed "$script_name"; then
        echo -e "${YELLOW}│ ⚠ 工具已存在，是否覆盖？${NC}"
        echo -ne "${BLUE}│${NC} 覆盖安装? [y/N]: "
        read -n 1 -r overwrite
        echo
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}│ 跳过安装${NC}"
            echo -e "${BLUE}└─────────────────────┘${NC}"
            return 0
        fi
        echo -e "${CYAN}│ → 覆盖安装中...${NC}"
    fi
    
    # 尝试安装脚本
    local install_success=false
    if cp "$script_path" "$install_path" 2>/dev/null && chmod +x "$install_path" 2>/dev/null; then
        install_success=true
        echo -e "${GREEN}│ 安装成功${NC}"
    elif command -v sudo >/dev/null 2>&1; then
        echo -e "${YELLOW}│ 需要管理员权限...${NC}"
        if sudo cp "$script_path" "$install_path" && sudo chmod +x "$install_path"; then
            install_success=true
            echo -e "${GREEN}│ 安装成功 (使用sudo)${NC}"
        fi
    fi
    
    if [[ "$install_success" == "true" ]]; then
        echo -e "${CYAN}│ → 命令: ${BOLD}$cmd_name${NC}"
        echo -e "${CYAN}│ → 路径: $install_path${NC}"
        
        # 如果是用户目录，更新PATH配置
        if [[ "$INSTALL_DIR" == "$HOME"* ]]; then
            update_path "$INSTALL_DIR" "$cmd_name" "$script_path" || true
        fi
    else
        echo -e "${RED}│ 安装失败${NC}"
        echo -e "${BLUE}└─────────────────────┘${NC}"
        return 1
    fi
    
    echo -e "${BLUE}└─────────────────────┘${NC}"
}

# 卸载单个脚本
uninstall_script() {
    local script_name="$1"
    local cmd_name
    
    # 支持 .sh 和 .py 文件
    if [[ "$script_name" == *.sh ]]; then
        cmd_name=$(basename "$script_name" .sh)
    elif [[ "$script_name" == *.py ]]; then
        cmd_name=$(basename "$script_name" .py)
    else
        cmd_name="$script_name"
    fi
    
    local install_path="$INSTALL_DIR/$cmd_name"
    
    echo -e "${BLUE}┌─ 卸载 ${BOLD}$script_name${NC}${BLUE} ─┐${NC}"
    
    # 检查是否已安装
    if [[ ! -f "$install_path" ]]; then
        echo -e "${YELLOW}│ 工具未安装${NC}"
        echo -e "${BLUE}└─────────────────────┘${NC}"
        return 0
    fi
    
    # 确认卸载
    echo -e "${YELLOW}│ 确认卸载工具 ${BOLD}$cmd_name${NC}${YELLOW}？${NC}"
    echo -ne "${BLUE}│${NC} 确认卸载? [y/N]: "
    read -n 1 -r confirm
    echo
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}│ 取消卸载${NC}"
        echo -e "${BLUE}└─────────────────────┘${NC}"
        return 0
    fi
    
    # 卸载文件
    echo -e "${CYAN}│ → 卸载主程序中...${NC}"
    local uninstall_success=false
    
    if rm "$install_path" 2>/dev/null; then
        uninstall_success=true
        echo -e "${GREEN}│ 卸载执行文件成功${NC}"
    elif command -v sudo >/dev/null 2>&1 && sudo rm "$install_path" 2>/dev/null; then
        uninstall_success=true
        echo -e "${GREEN}│ 卸载执行文件成功 (使用sudo)${NC}"
    else
        echo -e "${RED}│ 卸载执行文件失败${NC}"
    fi
    
    # 清理配置文件
    if [[ "$uninstall_success" == "true" ]]; then
        clean_config_files "$cmd_name"
        echo -e "${GREEN}│ 卸载成功${NC}"
    else
        echo -e "${RED}│ 卸载失败${NC}"
    fi
    
    echo -e "${BLUE}└─────────────────────┘${NC}"
    return $([[ "$uninstall_success" == "true" ]] && echo 0 || echo 1)
}

# 清理配置文件中的工具相关配置
clean_config_files() {
    local cmd_name="$1"
    local shell_loader="$CONFIG_DIR/shell_loader.sh"
    
    # 清理shell加载脚本中的工具别名
    if [[ -f "$shell_loader" ]]; then
        echo -e "${CYAN}│ → 清理Shell加载脚本...${NC}"
        remove_tool_alias_from_loader "$cmd_name" "$shell_loader"
        echo -e "${GREEN}│ ✓ Shell加载脚本已清理${NC}"
    fi
}

# 获取所有脚本列表（支持 .sh 和 .py）
get_script_list() {
    if [[ ! -d "$TOOLS_DIR" ]]; then
        echo -e "${RED}错误: tools 目录不存在${NC}" >&2
        return 1
    fi
    
    # 获取 .sh 和 .py 文件列表
    {
        find "$TOOLS_DIR" -maxdepth 1 -name "*.sh" -type f -printf '%f\n' 2>/dev/null || \
        find "$TOOLS_DIR" -maxdepth 1 -name "*.sh" -type f | sed 's|.*/||'
        
        find "$TOOLS_DIR" -maxdepth 1 -name "*.py" -type f -printf '%f\n' 2>/dev/null || \
        find "$TOOLS_DIR" -maxdepth 1 -name "*.py" -type f | sed 's|.*/||'
    } | sort
}

# 显示脚本选择菜单
show_menu() {
    local mode="$1"
    shift
    local scripts=("$@")
    
    show_header
    
    if [[ "$mode" == "install" ]]; then
        echo -e "${GREEN}${BOLD}安装模式${NC}"
        echo -e "选择要安装的脚本工具:"
    else
        echo -e "${RED}${BOLD}卸载模式${NC}"
        echo -e "选择要卸载的脚本工具:"
    fi
    
    echo
    
    # 显示脚本列表
    local i=1
    for script in "${scripts[@]}"; do
        local status_color status
        if is_installed "$script"; then
            status="[已安装]"
            status_color="${GREEN}"
        else
            status="[未安装]"
            status_color="${YELLOW}"
        fi
        
        printf "${BOLD}%2d)${NC} %-20s ${status_color}%s${NC}\\n" "$i" "$script" "$status"
        ((i++))
    done
    
    echo
    echo -e "${BOLD}q)${NC} 退出"
    echo
}

# 安装模式
install_mode() {
    local scripts
    mapfile -t scripts < <(get_script_list)
    
    if [[ ${#scripts[@]} -eq 0 ]]; then
        echo -e "${RED}错误: tools 目录中没有找到脚本文件${NC}" >&2
        echo -e "${YELLOW}按任意键返回主菜单...${NC}"
        read -n 1
        return
    fi
    
    while true; do
        show_menu "install" "${scripts[@]}"
        echo -n "请选择要安装的脚本 [1-${#scripts[@]}/q]: "
        read -n 1 choice
        echo ""
        
        case "$choice" in
            [1-9]*)
                if [[ "$choice" -ge 1 && "$choice" -le ${#scripts[@]} ]]; then
                    local selected_script="${scripts[$((choice-1))]}"
                    echo
                    install_script "$selected_script" || true  # 防止因返回值导致脚本退出
                    echo
                    echo -e "${CYAN}选择操作：${NC}"
                    echo -e "${BOLD}1)${NC} 继续安装其他工具"
                    echo -e "${BOLD}2)${NC} 返回主菜单"
                    echo -n "请选择 [1/2]: "
                    read -n 1 next_action
                    echo ""
                    case "$next_action" in
                        2)
                            return
                            ;;
                        *)
                            # 默认继续安装，什么都不做，继续循环
                            ;;
                    esac
                else
                    echo -e "${RED}无效选择${NC}"
                    echo -e "${YELLOW}按任意键继续...${NC}"
                    read -n 1
                fi
                ;;

            q|Q)
                return
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                echo -e "${YELLOW}按任意键继续...${NC}"
                read -n 1
                ;;
        esac
    done
}



# 卸载模式
uninstall_mode() {
    local scripts
    mapfile -t scripts < <(get_script_list)
    
    if [[ ${#scripts[@]} -eq 0 ]]; then
        echo -e "${RED}错误: tools 目录中没有找到脚本文件${NC}" >&2
        echo -e "${YELLOW}按任意键返回主菜单...${NC}"
        read -n 1
        return
    fi
    
    while true; do
        show_menu "uninstall" "${scripts[@]}"
        echo -n "请选择要卸载的脚本 [1-${#scripts[@]}/q]: "
        read -n 1 choice
        echo ""
        
        case "$choice" in
            [1-9]*)
                if [[ "$choice" -ge 1 && "$choice" -le ${#scripts[@]} ]]; then
                    local selected_script="${scripts[$((choice-1))]}"
                    echo
                    uninstall_script "$selected_script" || true  # 防止因返回值导致脚本退出
                    echo
                    echo -e "${CYAN}选择操作：${NC}"
                    echo -e "${BOLD}1)${NC} 继续卸载其他工具"
                    echo -e "${BOLD}2)${NC} 返回主菜单"
                    echo -n "请选择 [1/2]: "
                    read -n 1 next_action
                    echo ""
                    case "$next_action" in
                        2)
                            return
                            ;;
                        *)
                            # 默认继续卸载，什么都不做，继续循环
                            ;;
                    esac
                else
                    echo -e "${RED}无效选择${NC}"
                    echo -e "${YELLOW}按任意键继续...${NC}"
                    read -n 1
                fi
                ;;

            q|Q)
                return
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                echo -e "${YELLOW}按任意键继续...${NC}"
                read -n 1
                ;;
        esac
    done
}



# 显示已安装工具
show_installed_tools() {
    show_header
    echo -e "${GREEN}${BOLD}已安装的工具详情${NC}"
    echo
    
    local scripts 
    local installed_count=0
    local shell_loader="$CONFIG_DIR/shell_loader.sh"
    mapfile -t scripts < <(get_script_list)
    

    
    for script in "${scripts[@]}"; do
        
        if is_installed "$script"; then
            local cmd_name install_path version_info
            
            # 支持 .sh 和 .py 文件
            if [[ "$script" == *.sh ]]; then
                cmd_name=$(basename "$script" .sh)
            elif [[ "$script" == *.py ]]; then
                cmd_name=$(basename "$script" .py)
            else
                cmd_name="$script"
            fi
            
            install_path="$INSTALL_DIR/$cmd_name"
            
            # 获取版本信息
            version_info="未知"
            if [[ -f "$install_path" ]]; then
                # 尝试从脚本中提取版本信息
                local version_line
                version_line=$(grep -E "^(Version|version)=" "$install_path" 2>/dev/null | head -n1 || true)
                if [[ -n "$version_line" ]]; then
                    version_info=$(echo "$version_line" | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs)
                fi
            fi
            

            
            # 显示工具信息
            echo -e "${GREEN}┌─ ${BOLD}$cmd_name${NC}${GREEN} ─┐${NC}"
            echo -e "${GREEN}│${NC} 来源脚本: ${CYAN}$script${NC}"
            echo -e "${GREEN}│${NC} 安装路径: ${CYAN}$install_path${NC}"
            echo -e "${GREEN}│${NC} 版本信息: ${YELLOW}$version_info${NC}"
            
            # 显示文件大小和权限
            if [[ -f "$install_path" ]]; then
                local file_info
                file_info=$(ls -lh "$install_path" 2>/dev/null | awk '{print $1, $5}' || echo "无法获取")
                echo -e "${GREEN}│${NC} 文件信息: ${CYAN}$file_info${NC}"
            fi
            
            # 显示最后修改时间
            if [[ -f "$install_path" ]]; then
                local mod_time="无法获取"
                
                # 临时关闭严格模式来测试 stat 命令
                set +e
                if command -v stat >/dev/null 2>&1; then
                    # 尝试 Linux 风格的 stat
                    mod_time=$(stat -c "%y" "$install_path" 2>/dev/null | cut -d'.' -f1)
                    if [[ -z "$mod_time" ]]; then
                        # 尝试 BSD/macOS 风格的 stat
                        mod_time=$(stat -f "%Sm" "$install_path" 2>/dev/null)
                    fi
                    if [[ -z "$mod_time" ]]; then
                        mod_time="无法获取"
                    fi
                fi
                set -e
                
                echo -e "${GREEN}│${NC} 修改时间: ${CYAN}$mod_time${NC}"
            fi
            
            echo -e "${GREEN}└─────────────────────┘${NC}"
            echo
            installed_count=$((installed_count + 1))
        fi
    done
    echo -e "${YELLOW}按任意键返回主菜单...${NC}"
    read -n 1
}

# 环境检查
check_environment() {
    echo -e "${CYAN}正在检查运行环境...${NC}"
    
    # 检查 Bash 版本
    if ! check_bash_version; then
        return 1
    fi
    
    # 检查 tools 目录
    if [[ ! -d "$TOOLS_DIR" ]]; then
        echo -e "${RED}错误: tools 目录不存在${NC}" >&2
        echo -e "请确保在 CyanToolKit 根目录下运行此脚本" >&2
        echo -e "当前目录: $(pwd)" >&2
        return 1
    fi
    
    # 检查是否有可用的脚本
    local script_count
    script_count=$(find "$TOOLS_DIR" \( -name "*.sh" -o -name "*.py" \) -type f 2>/dev/null | wc -l)
    
    if [[ "$script_count" -eq 0 ]]; then
        echo -e "${RED}警告: tools 目录中没有找到任何脚本文件${NC}" >&2
        echo -e "请检查 tools 目录是否包含 .sh 或 .py 文件" >&2
        return 1
    fi
    
    echo -e "${GREEN}环境检查通过${NC}"
    echo -e "${CYAN}  - Bash 版本: ${BASH_VERSION}${NC}"
    echo -e "${CYAN}  - 找到 $script_count 个可安装的脚本${NC}"
    echo ""
}

# 显示命令行帮助信息
show_command_help() {
    echo -e "${CYAN}${BOLD}CyanToolKit 安装脚本帮助${NC}"
    echo ""
    echo -e "用法: $0 [选项]"
    echo ""
    echo -e "选项:"
    echo -e "  ${BOLD}-s, --shell TYPE${NC}    指定shell类型 (bash 或 zsh)"
    echo -e "  ${BOLD}-h, --help${NC}          显示此帮助信息并退出"
    echo ""
    echo -e "说明:"
    echo -e "  脚本会自动检测用户的默认shell。"
    echo -e "  如果自动检测不准确，可以使用 -s 参数手动指定。"
    echo ""
    echo -e "示例:"
    echo -e "  $0                 # 自动检测shell类型"
    echo -e "  $0 --shell zsh     # 强制使用zsh配置"
    echo -e "  $0 --shell bash    # 强制使用bash配置"
    echo ""
}

# 解析命令行参数
parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -s|--shell)
                if [[ -z "${2:-}" ]]; then
                    echo -e "${RED}错误: --shell 需要参数${NC}" >&2
                    show_command_help
                    return 1
                fi
                case "$2" in
                    bash|zsh)
                        SHELL_TYPE="$2"
                        echo -e "${CYAN}已指定shell类型: ${BOLD}$SHELL_TYPE${NC}"
                        ;;
                    *)
                        echo -e "${RED}错误: shell类型必须是 'bash' 或 'zsh'${NC}" >&2
                        show_command_help
                        return 1
                        ;;
                esac
                shift 2
                ;;
            -h|--help)
                show_command_help
                exit 0
                ;;
            -*)
                echo -e "${RED}错误: 未知选项 '$1'${NC}" >&2
                echo -e "${YELLOW}提示: 使用 --help 查看可用选项${NC}" >&2
                echo ""
                show_command_help
                return 1
                ;;
            *)
                echo -e "${RED}错误: 不支持的参数 '$1'${NC}" >&2
                echo -e "${YELLOW}提示: install.sh 不接受位置参数，请直接运行${NC}" >&2
                echo ""
                show_command_help
                return 1
                ;;
        esac
    done

    # 自动检测shell类型
    if [[ "$SHELL_TYPE" == "auto" ]]; then
        local detected_shell="${SHELL##*/}"
        
        case "$detected_shell" in
            zsh)
                SHELL_TYPE="zsh"
                echo -e "${CYAN}检测到用户默认shell: ${BOLD}$SHELL_TYPE${NC}"
                ;;
            bash)
                SHELL_TYPE="bash"
                echo -e "${CYAN}检测到用户默认shell: ${BOLD}$SHELL_TYPE${NC}"
                ;;
            *)
                SHELL_TYPE="bash"  # 默认为bash
                echo -e "${YELLOW}警告: 无法确定shell类型，默认使用: ${BOLD}$SHELL_TYPE${NC}"
                ;;
        esac
    fi
}

# 主程序入口
main() {
    # 解析命令行参数
    if ! parse_args "$@"; then
        return 1
    fi
    
    # 环境检查
    if ! check_environment; then
        return 1
    fi
    
    # 设置默认安装目录为用户目录
    INSTALL_DIR="$LOCAL_INSTALL_DIR"
    
    # 确保安装目录和配置数据目录存在
    if ! ensure_dirs; then
        echo -e "${RED}错误: 无法创建必要的目录${NC}" >&2
        return 1
    fi
    
    # 启动主菜单
    main_menu
}

# 运行主程序
main "$@"