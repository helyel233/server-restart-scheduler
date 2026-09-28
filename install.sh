#!/bin/bash
# ============================================================
#  一键远程安装脚本
#  把"下载脚本 -> 赋权 -> 安装计划"压缩成一条命令:
#
#  curl -fsSL https://raw.githubusercontent.com/helyel233/server-restart-scheduler/main/install.sh | sudo bash -s -- daily 02:30
#
#  参数与 restart_scheduler.sh 一致:
#    <类型> hourly / 6h / daily / 3d / weekly (或 1-5)
#    <时间> HH:MM 或 YYYY-MM-DD HH:MM (北京时间)
#  不带参数时下载后进入交互式菜单。
# ============================================================
set -e

BASE="https://raw.githubusercontent.com/helyel233/server-restart-scheduler/main"
TMP_SCHED="/tmp/restart_scheduler.sh"

# ---------- 下载主脚本 (curl 优先, 退化用 wget) ----------
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

echo "[1/2] 下载 restart_scheduler.sh ..."
fetch "$BASE/restart_scheduler.sh" "$TMP_SCHED"
chmod +x "$TMP_SCHED"

echo "[2/2] 开始安装 ..."
echo "--------------------------------------------------"
# 执行完即退出, 临时文件保留在 /tmp 供查看, 不影响 Cron 计划
bash "$TMP_SCHED" "$@"
