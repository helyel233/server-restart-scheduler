#!/bin/bash
# ============================================================
#  定时重启执行脚本
#  由 restart_scheduler.sh 安装到 /usr/local/bin/restart_runner.sh,
#  到点后由 Cron 调用, 负责写日志并执行重启。
#  如需修改"重启时做什么", 直接编辑服务器上的这个文件即可。
# ============================================================
LOG="/var/log/server_restart.log"

echo "$(date '+%Y-%m-%d %H:%M:%S') [$(hostname)] 定时重启触发, 服务器即将重启..." >> "$LOG"

# 先把磁盘数据落盘, 避免重启丢失
sync

# 执行重启 (reboot 不可用则退回 shutdown -r now)
reboot 2>/dev/null || shutdown -r now
