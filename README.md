# 服务器定时重启脚本 (Server Scheduled Restart)

一个简单好用的 Linux 服务器定时重启工具，专为小白设计。全程中文交互菜单，输入一次时间即可自动生成定时计划。

## 功能

- 支持 5 种重启频率：**每小时 / 每6小时 / 每天 / 每3天 / 每周**
- 指定**第一次重启时间**，以**北京时间 (GMT+8)** 为准
- **自动检测服务器所在时区**，把北京时间换算成服务器本地时间，再写入 Cron
- 一键查看当前计划 / 取消计划 / 立即重启测试
- 安装时自动备份原有定时计划

## 文件说明

| 文件 | 作用 |
| --- | --- |
| `restart_scheduler.sh` | 主脚本（交互式菜单）：选择频率、输入时间、自动换算时区、生成并安装计划 |
| `restart_runner.sh` | 重启执行脚本：到点后由 Cron 调用，写日志并执行 `reboot` |
| `README.md` | 本说明文档 |

> 两个脚本必须放在**同一目录**下再运行。

---

## 一、在服务器上快速使用（3 分钟上手）

### 第 1 步：把两个脚本放到服务器

方式 A（本机上传）：把这两个文件从你电脑传到服务器，例如用 `scp`：

```bash
scp restart_scheduler.sh restart_runner.sh 用户名@服务器IP:~/
```

方式 B（从 GitHub 下载）：见下文「三、发布到 GitHub 后如何启用」。

### 第 2 步：运行主脚本（必须用 sudo）

```bash
chmod +x restart_scheduler.sh restart_runner.sh
sudo bash restart_scheduler.sh
```

### 第 3 步：按菜单操作（示例）

```
==================================================
     服务器定时重启脚本 v1.0
==================================================
 服务器时区    : CST (+0800)
 服务器本地时间: 2026-08-13 14:30:05
 当前北京时间  : 2026-08-13 14:30:05 (GMT+8)
--------------------------------------------------
 请选择功能:
   [1] 每小时重启一次
   [2] 每 6 小时重启一次
   [3] 每天重启一次
   [4] 每 3 天重启一次
   [5] 每周重启一次
   [6] 查看当前已安装的计划
   [7] 取消定时重启
   [8] 立即重启服务器 (慎用!)
   [0] 退出
--------------------------------------------------
 请输入编号: 3

 你选择了: 每天重启一次
 第一次重启时间 [北京时间, 格式 YYYY-MM-DD HH:MM, 例: 2026-08-13 02:30]: 2026-08-14 02:30

 ┌─ 计划预览 ────────────────────────
 │ 重启类型   : 每天重启
 │ 第一次重启 : 2026-08-14 02:30  (北京时间 GMT+8)
 │ 服务器本地 : 2026-08-14 02:30 CST (+0800)
 │ Cron 表达式: 30 2 * * * /usr/local/bin/restart_runner.sh
 └────────────────────────────────────
 确认安装? [y/N]: y
[OK] 重启执行脚本已就绪: /usr/local/bin/restart_runner.sh
[OK] 原定时计划已备份到: /root/crontab.backup.20260813_143015
[OK] 新计划已写入 Cron:
   30 2 * * * /usr/local/bin/restart_runner.sh >/dev/null 2>&1

[OK] 安装完成! 常用命令:
   查看计划: crontab -l | grep restart_runner
   查看日志: tail -f /var/log/server_restart.log
```

### 第 4 步：验证

```bash
# 查看已安装的定时计划
crontab -l | grep restart_runner

# 查看重启记录（重启后服务器会回来，日志文件保留）
cat /var/log/server_restart.log
```

如果服务器时区不是北京时间（例如海外服务器），脚本会自动换算，你仍然只需要输入北京时间即可。

---

## 二、发布到 GitHub

这样以后任何一台服务器都能直接下载使用，也方便版本管理。

### 方式 A：GitHub 网页上传（最简单，推荐）

1. 打开 [github.com](https://github.com)，注册并登录账号。
2. 点右上角 **`+`** 号 → **New repository**。
3. Repository name 填 `server-restart-scheduler`；选 **Public**（免费）；**不要勾选** "Add a README file"；点 **Create repository**。
4. 进入仓库页面后，点 **Add file** → **Upload files**。
5. 把 `restart_scheduler.sh`、`restart_runner.sh`、`README.md` 三个文件**拖进**页面。
6. 页面下方点 **Commit changes**。
7. 完成！点进任意文件，再点右上角 **Raw** 按钮，浏览器地址栏就是该文件的下载链接。

### 方式 B：用 git 命令行上传

在存放这三个文件的文件夹里打开终端，依次执行：

```bash
git init
git add restart_scheduler.sh restart_runner.sh README.md
git commit -m "服务器定时重启脚本"
git branch -M main
git remote add origin https://github.com/你的用户名/server-restart-scheduler.git
git push -u origin main
```

> `https://github.com/你的用户名/server-restart-scheduler.git` 这个地址在仓库页面右上角 **Code** 按钮里复制。

### 获取下载链接（raw 链接）

格式固定为：

```
https://raw.githubusercontent.com/你的用户名/server-restart-scheduler/main/文件名
```

例如：

```
https://raw.githubusercontent.com/你的用户名/server-restart-scheduler/main/restart_scheduler.sh
https://raw.githubusercontent.com/你的用户名/server-restart-scheduler/main/restart_runner.sh
```

> 如果创建仓库时默认分支叫 `master`（老账号），把链接里的 `main` 换成 `master` 即可。

---

## 三、发布到 GitHub 后，如何在服务器上启用

在任何一台 Linux 服务器上执行（只需几条命令）：

```bash
# 1. 下载两个脚本（把"你的用户名"换成你的 GitHub 用户名）
curl -O https://raw.githubusercontent.com/你的用户名/server-restart-scheduler/main/restart_scheduler.sh
curl -O https://raw.githubusercontent.com/你的用户名/server-restart-scheduler/main/restart_runner.sh

# 2. 给执行权限
chmod +x restart_scheduler.sh restart_runner.sh

# 3. 运行主脚本，按菜单选择频率并输入北京时间
sudo bash restart_scheduler.sh
```

没有 `curl` 的服务器（极少数精简系统）用 `wget` 替代：

```bash
wget -O restart_scheduler.sh https://raw.githubusercontent.com/你的用户名/server-restart-scheduler/main/restart_scheduler.sh
wget -O restart_runner.sh https://raw.githubusercontent.com/你的用户名/server-restart-scheduler/main/restart_runner.sh
```

如果服务器在国内访问 GitHub 较慢，也可以直接在本机下载后 `scp` 上传（见第一部分方式 A）。

---

## 四、工作原理（小白版）

**时区换算**：北京时间 = UTC+8。脚本先检测服务器时区偏移，把你输入的北京时间换算成服务器本地时间，再生成 Cron 计划，保证"在你想的时刻"准时重启。

| 服务器时区 | 你输入的北京时间 | 服务器实际执行时间 |
| --- | --- | --- |
| 中国 (UTC+8) | 08-13 02:30 | 08-13 02:30 |
| 伦敦 (UTC+0) | 08-13 02:30 | 08-12 18:30 |
| 美东 (UTC-5) | 08-13 02:30 | 08-12 13:30 |
| 印度 (UTC+5:30) | 08-13 02:30 | 08-13 00:00 |

**Cron 是什么**：Linux 自带的任务计划工具。计划写入 `crontab` 后永久生效，**服务器重启后计划依然存在**，不需要重新设置。

---

## 五、常见问题 (FAQ)

**1. 为什么一定要用 sudo 运行？**
重启整个系统需要 root 权限。用 `sudo` 运行后，计划会装在 root 的 crontab 下，到点后以 root 身份执行重启，不会失败。

**2. 服务器时间/时区不准怎么办？**
先修正系统时间，否则定时会不准：

```bash
# 查看当前时间与时区
timedatectl

# 设置时区（如上海）
sudo timedatectl set-timezone Asia/Shanghai

# 开启时间自动同步（一般云服务器默认已开启）
sudo timedatectl set-ntp true
```

**3. 想改重启时间/频率？**
重新运行 `sudo bash restart_scheduler.sh`，重新选择即可，会自动覆盖旧计划（旧计划会先备份）。

**4. 想取消定时重启？**
重新运行脚本，选 `[7]` 取消。

**5. "每3天"是怎么计算的？**
按日期号循环：第一次是 8 月 13 日，则 16、19、22……依此类推（13、16、19... 都是日期号除以 3 余 1 的天）。每月重置一次，月底可能出现 4~5 天的间隔，属正常现象。

**6. 输入的时间已经过了会怎样？**
脚本会提示。每小时/每6小时类型会自动顺延到下一个周期；每天/每3天/每周类型会从下一个周期开始。

**7. 想先测试流程，但不想真的重启？**
把服务器上的 `/usr/local/bin/restart_runner.sh` 里最后两行改成：

```bash
echo "$(date '+%F %T') 模拟重启(未真正重启)" >> "$LOG"
```

测试完再改回来即可。

**8. 服务器没有 crontab 命令？**
极少数精简系统没有装 cron。Debian/Ubuntu 系执行：

```bash
sudo apt update && sudo apt install -y cron
sudo systemctl enable --now cron
```

CentOS/Rocky 系：`sudo yum install -y cronie`

**9. 想改成"重启某个服务"而不是整机重启？**
编辑 `/usr/local/bin/restart_runner.sh`，把 `reboot` 那行换成你的命令（如 `systemctl restart nginx`），计划不变。

---

## 安全提醒

- 重启会中断所有正在运行的程序，**建议把第一次重启时间设在业务低峰期**（如凌晨 02:00~05:00）。
- 先在一台测试服务器上跑通，再部署到生产环境。
- 生产环境使用前，请确认业务已配置开机自启动（systemd 服务等），否则重启后服务不会自动拉起。
