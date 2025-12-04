# CyanToolKit

**轻量级 Linux/WSL 系统工具集**

为 Linux 和 WSL 环境提供实用的系统管理工具和自动化脚本。

## 特性

- **模块化设计** - 独立工具，按需安装
- **一键安装** - 交互式安装，自动配置环境
- **智能集成** - 支持 bash/zsh，自动 shell 集成
- **用户级安装** - 无需 root 权限
- **完整管理** - 支持单独安装/卸载

## 快速开始

```bash
git clone https://github.com/CHonesetDoPa/CyanToolKit.git
cd CyanToolKit
./install.sh
```

## 工具

| 工具 | 命令 | 功能 | 文档 |
|-----|------|------|------|
| **SProxy** | `sproxy` | 系统代理管理器 | [详细文档](docs/sproxy.md) |
| **ShutdownWSL** | `sdwsl` | WSL 快速关闭工具 | [详细文档](docs/shutdownwsl.md) |

## 文档

- [安装指南](docs/installation.md) - 详细安装和配置说明
- [SProxy 文档](docs/sproxy.md) - 代理管理器使用指南  
- [ShutdownWSL 文档](docs/shutdownwsl.md) - WSL 工具使用说明

## 项目结构

```
CyanToolKit/
├── install.sh          # 主安装脚本
├── tools/              # 工具脚本目录
├── docs/               # 详细文档
└── README.md           # 项目说明
```

## 环境要求

- **系统**: Linux / WSL
- **Shell**: bash 4.0+ / zsh  
- **依赖**: curl, git (可选)

## 快速示例

```bash
# 代理管理
sproxy config 127.0.0.1 7890  # 配置代理
sproxy on                      # 启用代理
sproxy status                  # 查看状态

# WSL 管理
sdwsl  # 关闭 WSL
```

## 卸载

```bash
./install.sh  # 选择卸载选项
# 或手动清理
rm -rf ~/.local/share/CyanToolKit/
```

## 协议

[CC0 1.0 Universal](LICENSE) - 完全开源免费

## 贡献

欢迎 Issue 和 PR！

**项目地址**: https://github.com/CHonesetDoPa/CyanToolKit

---

*让 Linux 和 WSL 使用更简单！*