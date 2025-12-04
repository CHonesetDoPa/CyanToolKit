# GitFastPointPushfast - 快速Git提交推送工具

**在很急的情况下，一键快速提交和推送Git更改**

## 基本用法

```bash
gfpp    # 使用默认或配置的提交消息快速提交推送
```

## 设置提交消息

### 设置自定义提交消息
```bash
gfpp --set-commit-message "你的提交消息"
```

### 查看当前配置
配置文件位于 `~/.local/share/CyanToolKit/config/gitfastpoint.conf`

## 功能说明

- 自动添加所有更改 (`git add .`)
- 使用配置或默认消息提交 (`git commit -m "message"`)
- 推送更改 (`git push`)
- 支持自定义提交消息配置

## 常见问题

**提交消息未生效**
```bash
# 检查配置文件
cat ~/.local/share/CyanToolKit/config/gitfastpoint.conf

# 重新设置消息
gfpp --set-commit-message "新消息"
```

**Git操作失败**
```bash
# 检查Git状态
git status

# 确保在Git仓库中
pwd
```

