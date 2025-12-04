# 安装指南

📦 **CyanToolKit 安装指南**

## 系统要求

- Linux 或 WSL 环境
- bash/zsh shell

## 快速安装

```bash
# 克隆项目
git clone https://github.com/CHonesetDoPa/CyanToolKit.git
cd CyanToolKit

# 运行安装程序
./install.sh
```

## 安装选项

```bash
./install.sh              # 自动检测 shell
./install.sh --shell zsh  # 指定 shell 类型
./install.sh --help       # 查看帮助
```

## 使配置生效

> 通常情况下，安装后会自动在本终端生效  


手动生效  
```bash
# 重新加载配置
source ~/.zshrc    # 或 ~/.bashrc

# 或重新打开终端
```

## 验证安装

```bash
sproxy --help    # 检查代理工具
sdwsl            # 检查 WSL 工具
```

## 常见问题

**安装失败**
```bash
# 手动创建目录
mkdir -p ~/.local/share/CyanToolKit/{bin,config,data}

# 手动指定 shell
./install.sh --shell bash
```

**命令未找到**
```bash
# 检查配置是否加载
echo $PATH | grep CyanToolKit

# 手动加载配置
source ~/.local/share/CyanToolKit/config/shell_loader.sh
```

**完全重装**
```bash
# 清理旧安装
rm -rf ~/.local/share/CyanToolKit/

# 重新安装
./install.sh
```