#!/bin/bash
# ============================================================
#  服务器定时重启脚本 - 一键安装 (小白版)
#
#  在服务器上复制执行这一条命令即可完成安装:
#
#    curl -fsSL https://raw.githubusercontent.com/helyel233/server-restart-scheduler/main/install.sh | sudo bash
#
#  安装内容:
#    1. 两个脚本下载到 /usr/local/bin/
#    2. 创建快捷命令 restart
#  安装完成后, 随时输入  sudo restart  打开设置菜单。
#  (脚本本身不设置任何定时任务, 计划都在菜单里选择)
# ============================================================
set -e

BASE="https://raw.githubusercontent.com/helyel233/server-restart-scheduler/main"
BIN_DIR="/usr/local/bin"

# ---------- 必须 root ----------
if [ "$(id -u)" -ne 0 ]; then
    echo "[错误] 安装需要 root 权限, 请在命令前加 sudo 后重试。"
    exit 1
fi

# ---------- 下载函数 (curl 优先, 退化 wget) ----------
fetch() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$1" -o "$2"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$2" "$1"
    else
        echo "[错误] 系统缺少 curl 和 wget, 无法下载脚本。" >&2
        exit 1
    fi
}

echo "[1/3] 下载主脚本 restart_scheduler.sh ..."
fetch "$BASE/restart_scheduler.sh" "$BIN_DIR/restart_scheduler.sh"

echo "[2/3] 下载执行脚本 restart_runner.sh ..."
fetch "$BASE/restart_runner.sh" "$BIN_DIR/restart_runner.sh"

echo "[3/3] 创建快捷命令 restart ..."
cat > "$BIN_DIR/restart" <<'EOF'
#!/bin/bash
# 服务器定时重启管理菜单快捷命令
exec bash /usr/local/bin/restart_scheduler.sh
EOF
chmod 755 "$BIN_DIR/restart_scheduler.sh" "$BIN_DIR/restart_runner.sh" "$BIN_DIR/restart"

echo ""
echo "=================================================="
echo " 安装完成!"
echo "=================================================="
echo " 接下来只需一步, 执行下面这条命令打开设置菜单:"
echo ""
echo "     sudo restart"
echo ""
echo " (若提示找不到 restart 命令, 退出并重新登录终端即可)"
echo " 所有重启频率与时机都在菜单里选择, 不需要记任何参数。"
