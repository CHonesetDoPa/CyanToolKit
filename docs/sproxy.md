# SProxy - 系统代理管理器

**一键配置和管理系统代理**

## 基本用法

```bash
sproxy on       # 启用代理
sproxy off      # 关闭代理
sproxy status   # 查看状态
sproxy config   # 配置代理
```

## 配置代理

### 交互式配置
```bash
sproxy config
# 按提示输入代理服务器 IP 和端口
```

### 快速配置
```bash
sproxy config 127.0.0.1 7890
```

## 功能说明

-  自动配置系统、Git 和 NPM 代理
-  支持 HTTP/HTTPS/SOCKS5 协议
-  重启终端自动生效
-  连接状态测试

## 常见问题

**代理无法生效**
```bash
sproxy status    # 检查状态
source ~/.zshrc  # 重新加载配置
```

**重置所有配置**
```bash
sproxy off
rm ~/.local/share/CyanToolKit/config/proxy.conf
```