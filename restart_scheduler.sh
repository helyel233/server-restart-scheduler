#!/bin/bash
# ============================================================
#  服务器定时重启脚本 (Server Scheduled Restart Script) v2.0
# ------------------------------------------------------------
#  小白专用: 所有设置都在交互菜单中完成, 不需要输入任何参数。
#  功能:
#   1. 选择重启类型: 每小时 / 每6小时 / 每天 / 每3天 / 每周
#   2. 选择第一次重启时机 (以北京时间 GMT+8 为准):
#      立即 / 5分钟 / 10分钟 / 30分钟 / 1小时 / 6小时 / 12小时 / 18小时 / 24小时
#   3. 自动检测服务器时区, 换算为服务器本地时间后写入 Cron
#   4. 可随时查看 / 取消 / 测试重启
#  适用: Ubuntu / Debian / CentOS / Rocky Linux / 阿里云 Linux 等
#  运行: sudo restart                     (推荐, 安装后可用的快捷命令)
#        sudo bash restart_scheduler.sh   (效果相同)
#  安装: curl -fsSL https://raw.githubusercontent.com/helyel233/server-restart-scheduler/main/install.sh | sudo bash
# ============================================================

RUNNER="/usr/local/bin/restart_runner.sh"
RUNNER_NAME="restart_runner.sh"
LOG_FILE="/var/log/server_restart.log"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[提示]${NC} $*"; }
err()  { echo -e "${RED}[错误]${NC} $*"; }

# ---------- 前置检查 ----------
# 1. 重启系统必须 root 权限
if [ "$(id -u)" -ne 0 ]; then
    err "本脚本需要 root 权限才能设置系统定时重启。"
    echo ""
    echo "  请改用:  sudo restart"
    echo ""
    exit 1
fi

# 2. 需要 GNU date (主流 Linux 均自带)
if ! date -d "@0" "+%F %T" >/dev/null 2>&1; then
    err "当前系统不支持 GNU date, 请确认运行环境是主流 Linux 服务器。"
    exit 1
fi

# ---------- 时间工具函数 ----------
# 当前北京时间 (GMT+8)
get_bj_now() {
    if TZ=Asia/Shanghai date "+%F %T" >/dev/null 2>&1; then
        TZ=Asia/Shanghai date "+%F %T"
    else
        date -u -d "+8 hours" "+%F %T"
    fi
}

# 北京时间(墙钟) -> Unix 时间戳 (北京 = UTC+8, 即先按UTC解析再减8小时)
bj_to_epoch() {
    local t="$1" e
    e=$(date -u -d "$t" "+%s" 2>/dev/null) || return 1
    echo $((e - 28800))
}

# Unix 时间戳 -> 服务器本地时间
epoch_to_local() {
    date -d "@$1" "+%F %H:%M %Z (%z)"
}

# ---------- 界面 ----------
show_header() {
    clear 2>/dev/null || true
    echo "=================================================="
    echo "     服务器定时重启脚本 v2.0"
    echo "=================================================="
    echo " 服务器时区    : $(date '+%Z (%z)')"
    echo " 服务器本地时间: $(date '+%F %T')"
    echo " 当前北京时间  : $(get_bj_now) (GMT+8)"
    echo "--------------------------------------------------"
}

show_menu() {
    echo " 请选择功能 (输入编号后按回车):"
    echo " 设置定时重启:"
    echo "   [1] 每小时重启一次"
    echo "   [2] 每 6 小时重启一次"
    echo "   [3] 每天重启一次"
    echo "   [4] 每 3 天重启一次"
    echo "   [5] 每周重启一次"
    echo " 管理:"
    echo "   [6] 查看当前计划 (含最近重启记录)"
    echo "   [7] 取消定时重启"
    echo " 其他:"
    echo "   [8] 立即重启服务器 (慎用! 马上重启, 不等待)"
    echo "   [0] 退出"
    echo "--------------------------------------------------"
}

# ---------- 选择第一次重启时机 ----------
# 以当前时刻为基准选择延迟量, 自动换算为第一次重启的北京时间
DELAY_SECONDS=-1    # -1=尚未选择, 0=立即, >0=延迟秒数
DELAY_LABEL=""

# 根据 DELAY_SECONDS 计算第一次重启的北京时间
calc_first_time() {
    if [ "$DELAY_SECONDS" -eq 0 ]; then
        local t
        t="$(get_bj_now)"
        FIRST_TIME="${t%:*}"          # 去掉秒, 保持 YYYY-MM-DD HH:MM
    else
        # 目标时刻 = 当前时间 + 延迟, 向上取整到整分钟, 换算为北京时间墙钟
        local epoch
        epoch=$(( $(date +%s) + DELAY_SECONDS ))
        epoch=$(( epoch + (60 - epoch % 60) % 60 ))
        FIRST_TIME="$(date -u -d "@$(( epoch + 28800 ))" "+%F %H:%M")"
    fi
}

ask_first_delay() {
    local c
    echo " 选择第一次重启时机 (基准: 当前北京时间 $(get_bj_now)) :"
    echo "   [1] 立即启用 (确认后立即开始第一次重启)"
    echo "   [2] 5 分钟后"
    echo "   [3] 10 分钟后"
    echo "   [4] 30 分钟后"
    echo "   [5] 1 小时后"
    echo "   [6] 6 小时后"
    echo "   [7] 12 小时后"
    echo "   [8] 18 小时后"
    echo "   [9] 24 小时后"
    while :; do
        read -r -p " 请输入编号 [1-9]: " c
        case "$c" in
            1) DELAY_SECONDS=0;     DELAY_LABEL="立即" ;;
            2) DELAY_SECONDS=300;   DELAY_LABEL="5 分钟后" ;;
            3) DELAY_SECONDS=600;   DELAY_LABEL="10 分钟后" ;;
            4) DELAY_SECONDS=1800;  DELAY_LABEL="30 分钟后" ;;
            5) DELAY_SECONDS=3600;  DELAY_LABEL="1 小时后" ;;
            6) DELAY_SECONDS=21600; DELAY_LABEL="6 小时后" ;;
            7) DELAY_SECONDS=43200; DELAY_LABEL="12 小时后" ;;
            8) DELAY_SECONDS=64800; DELAY_LABEL="18 小时后" ;;
            9) DELAY_SECONDS=86400; DELAY_LABEL="24 小时后" ;;
            *) err "无效选项, 请输入 1-9"; continue ;;
        esac
        break
    done
    calc_first_time
}

# 立即模式: 安装完成后马上执行第一次重启 (由 RUNNER 负责写日志并 reboot)
run_first_restart_now() {
    echo ""
    warn "立即模式: 3 秒后执行第一次重启, 服务器即将重启..."
    sleep 3
    "$RUNNER"
}

# ---------- 生成 Cron 计划 ----------
TYPE_NAMES[1]="每小时"
TYPE_NAMES[2]="每6小时"
TYPE_NAMES[3]="每天"
TYPE_NAMES[4]="每3天"
TYPE_NAMES[5]="每周"

build_plan() {
    local type="$1" epoch min hour dow dom d
    epoch=$(bj_to_epoch "$FIRST_TIME") || { err "时间解析失败"; return 1; }
    PLAN_EPOCH=$epoch
    min=$(date -d "@$epoch" "+%M")
    hour=$((10#$(date -d "@$epoch" "+%H")))
    dow=$(date -d "@$epoch" "+%w")          # 0=周日 ... 6=周六
    dom=$((10#$(date -d "@$epoch" "+%d")))
    case "$type" in
        1) CRON_EXPR="$min * * * *" ;;
        2) CRON_EXPR="$min $((hour % 6))-23/6 * * *" ;;
        3) CRON_EXPR="$min $hour * * *" ;;
        4) d=$((dom % 3)); [ "$d" -eq 0 ] && d=3
           CRON_EXPR="$min $hour $d-31/3 * *" ;;
        5) CRON_EXPR="$min $hour * * $dow" ;;
    esac
    LOCAL_TIME="$(epoch_to_local "$epoch")"
    return 0
}

# ---------- 安装重启执行脚本 ----------
install_runner() {
    local src="${SCRIPT_DIR}/restart_runner.sh"
    if [ -f "$src" ]; then
        cp -f "$src" "$RUNNER"
    else
        warn "同目录下没有 restart_runner.sh, 自动生成默认执行脚本。"
        cat > "$RUNNER" <<'EOF'
#!/bin/bash
LOG="/var/log/server_restart.log"
echo "$(date '+%Y-%m-%d %H:%M:%S') [$(hostname)] 定时重启触发, 服务器即将重启..." >> "$LOG"
sync
reboot 2>/dev/null || shutdown -r now
EOF
    fi
    chmod 755 "$RUNNER"
    ok "重启执行脚本已就绪: $RUNNER"
}

# ---------- 安装 Cron 计划 ----------
install_plan() {
    local cron_line="$1" backup
    backup="${HOME:-/root}/crontab.backup.$(date +%Y%m%d_%H%M%S)"
    crontab -l > "$backup" 2>/dev/null
    ok "原定时计划已备份到: $backup"
    ( crontab -l 2>/dev/null | grep -v "$RUNNER_NAME"; echo "$cron_line" ) | crontab -
    ok "新计划已写入 Cron:"
    echo "   $cron_line"
}

# ---------- 不接收任何参数, 一切设置都在交互菜单中完成 ----------
if [ $# -gt 0 ]; then
    err "本脚本不接收参数, 所有设置都在交互菜单里完成。"
    echo ""
    echo "  请运行:  sudo restart"
    echo ""
    exit 1
fi

# ---------- 主循环 ----------
while :; do
    show_header
    show_menu
    read -r -p " 请输入编号: " choice
    case "$choice" in
        1|2|3|4|5)
            TYPE="$choice"
            echo ""
            echo " 你选择了: ${TYPE_NAMES[$TYPE]}重启一次"
            ask_first_delay
            build_plan "$TYPE" || continue
            echo ""
            echo " ┌─ 计划预览 ────────────────────────"
            echo " │ 重启类型   : ${TYPE_NAMES[$TYPE]}重启"
            if [ "$DELAY_SECONDS" -eq 0 ]; then
                echo " │ 第一次重启 : 立即 (确认后马上重启, 之后按周期自动执行)"
            else
                echo " │ 第一次重启 : $FIRST_TIME  (北京时间 GMT+8, $DELAY_LABEL)"
            fi
            echo " │ 服务器本地 : $LOCAL_TIME"
            echo " │ Cron 表达式: $CRON_EXPR $RUNNER"
            echo " └────────────────────────────────────"
            if [ "$DELAY_SECONDS" -ne 0 ] && [ "$PLAN_EPOCH" -le "$(date +%s)" ]; then
                case "$TYPE" in
                    1) warn "该分钟已过, 将从下一个整点开始执行。" ;;
                    2) warn "该时刻已过, 将按每6小时自动顺延到下一个时刻。" ;;
                    3|4) warn "今天该时刻已过, 将从下一个周期 (明天/3天后) 开始执行。" ;;
                    5) warn "本周该时刻已过, 将从下周开始执行。" ;;
                esac
            fi
            read -r -p " 确认安装? [y/N]: " ans
            case "$ans" in y|Y|yes|YES)
                install_runner || continue
                install_plan "$CRON_EXPR $RUNNER >/dev/null 2>&1"
                echo ""
                ok "安装完成! 之后随时可以:"
                echo "   打开菜单: sudo restart"
                echo "   查看日志: tail -f $LOG_FILE"
                echo "   取消计划: 打开菜单选 [7]"
                if [ "$DELAY_SECONDS" -eq 0 ]; then
                    run_first_restart_now
                fi
                echo ""
                break ;;
            *)
                warn "已取消, 未做任何修改。"
                continue ;;
            esac
            ;;
        6)
            echo ""
            if crontab -l 2>/dev/null | grep -q "$RUNNER_NAME"; then
                echo " 当前定时重启计划:"
                crontab -l | grep "$RUNNER_NAME" | sed 's/^/   /'
                echo ""
                if [ -f "$LOG_FILE" ]; then
                    echo " 最近的重启记录:"
                    tail -n 3 "$LOG_FILE" | sed 's/^/   /'
                else
                    echo " 暂无重启记录 ($LOG_FILE)"
                fi
            else
                echo " (尚未安装定时重启计划)"
            fi
            echo ""
            read -r -p " 按回车返回菜单..." _tmp
            ;;
        7)
            echo ""
            crontab -l 2>/dev/null | grep -v "$RUNNER_NAME" | crontab -
            ok "已取消定时重启计划。"
            echo "  (执行脚本 $RUNNER 与日志已保留, 重新运行本脚本可再次安装)"
            echo ""
            read -r -p " 按回车返回菜单..." _tmp
            ;;
        8)
            echo ""
            warn "即将立即重启服务器! 所有未保存数据可能丢失。"
            read -r -p " 确认请输入 yes: " ans
            if [ "$ans" = "yes" ]; then
                echo " 3 秒后重启..."
                sleep 3
                sync
                reboot 2>/dev/null || shutdown -r now
            else
                warn "已取消。"
            fi
            ;;
        0|q|Q)
            echo " 再见!"
            exit 0
            ;;
        *)
            err "无效选项, 请重新输入。"
            ;;
    esac
done
