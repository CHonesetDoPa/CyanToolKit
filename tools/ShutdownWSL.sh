#!/usr/bin/env bash

# ShutdownWSL.sh - Windows Subsystem for Linux Shutdown Script
Version=2.0
Script_Special="alias sdwsl='source SCRIPT_PATH'"


# 查找可用的 wsl.exe
find_wsl_exe() {
    local candidates=(
        '/mnt/c/Windows/System32/wsl.exe'
        '/mnt/c/Program Files/WSL/wsl.exe' 
        '/mnt/c/Program Files/wsl/wsl.exe'
        '/mnt/c/Program Files/WindowsApps/wsl.exe'
    )

    for p in "${candidates[@]}"; do
        if [ -x "$p" ] 2>/dev/null; then
            echo "$p"
            return 0
        fi
    done

    if command -v wsl.exe >/dev/null 2>&1; then
        command -v wsl.exe
        return 0
    fi

    if [ -d /mnt/c ]; then
        local found
        found=$(find /mnt/c -maxdepth 4 -type f -iname 'wsl.exe' 2>/dev/null | head -n1 || true)
        if [ -n "$found" ]; then
            echo "$found"
            return 0
        fi
    fi

    # 默认回退到原始路径（不显示错误）
    echo "/mnt/c/Program Files/WSL/wsl.exe"
    return 0
}

date
echo "Shutdowning Windows SubSystem For Linux..."
sleep 0.2

WSL_PATH=$(find_wsl_exe)
"$WSL_PATH" --shutdown