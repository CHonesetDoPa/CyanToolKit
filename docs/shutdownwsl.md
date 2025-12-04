# ShutdownWSL - WSL 快速关闭工具

**一键关闭所有 WSL 实例的便捷工具**

## 使用方法

```bash
sdwsl  # 立即关闭所有 WSL 实例
```

## 功能特点

- 自动查找 `wsl.exe` 路径
- 一键关闭所有 WSL 实例  
- 无需手动配置

## 工作原理

自动搜索 `wsl.exe` 并执行 `wsl.exe --shutdown` 命令来关闭所有 WSL 实例。

## 故障排除

### 权限问题
```bash
# 检查文件系统访问权限
ls /mnt/c/
```

### 手动关闭 WSL
```bash
# 直接执行关闭命令
/mnt/c/Windows/System32/wsl.exe --shutdown
```

## 注意事项

**关闭前请保存重要工作，WSL 关闭会终止所有正在运行的 Linux 进程**