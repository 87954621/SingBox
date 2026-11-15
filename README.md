# Sing-box NAT

一个 Bash 单文件脚本，在 Linux 上一键部署和管理 **16 种 sing-box 协议**，自带中文菜单、节点管理、订阅链接和 Argo 隧道。支持 Debian / Ubuntu / CentOS / Alpine / Arch，systemd / OpenRC / 无 init 都能跑，**NAT 小鸡没有公网端口也能用**。

**V3.9.19**

---

## 安装

```bash
# 推荐：先下载，再运行
wget -qO sb.sh https://raw.githubusercontent.com/87954621/SingBox/refs/heads/main/sing-box.sh && bash sb.sh

# 或者用 curl
curl -fsSL https://raw.githubusercontent.com/87954621/SingBox/refs/heads/main/sing-box.sh -o sing-box.sh && bash sing-box.sh
```

> ⚠️ **别用 `wget -qO- URL | bash`**：安装过程要问你两个问题，管道会把脚本内容当成答案吞掉。两道提问都必须真正输入内容，只按回车不算选择；三次无效会停止安装，不改动系统。

安装确认屏会让你选内核：

| 输入 | 装到什么 | 适合 |
|---|---|---|
| **1** 最新版（含 alpha/beta） | GitHub 最新 tag，目前 1.15.0-alpha/beta | **推荐**，16 协议全开（含 HTTP/3） |
| **2** 正式版 | 官方 `/releases/latest`，目前 1.14.x | 求稳；**用不了 HTTP/3** |
| **3** Alpine 系统包版 | `apk add sing-box`，版本由软件源决定 | **仅 Alpine**；连不上 GitHub 时用 |

选项 3 会显示软件源里查到的版本（例如 edge/community 的 `1.13.21-r1`）。注意：Alpine 稳定分支的仓库通常没有 sing-box，脚本**不会擅自加 edge 源**；这一版也比较旧，**用不了 HTTP/3**。装完后随时可在「菜单 9 → 2」切换来源。

## 常用命令

```bash
sb            # 进入菜单
sb version    # 查看版本
sb update     # 更新脚本（改了源码后必须跑，sb 是安装时的快照）
sb check      # 检查是否有新版本
sb help       # 帮助
```

## 菜单速查

| 入口 | 用途 |
|---|---|
| `1` / `2` | 单协议部署 / 批量部署（16 协议，末项是 Argo 隧道） |
| `3` | 节点管理：改端口、看链接、扫码、重命名、删除 |
| `6` | **入站 IP / 端口映射** —— NAT 机器客户端连不上时先看这里 |
| `7` | 客户端设置：SNI、证书放行、Clash 分流、节点命名 |
| `8 → 6` | 内存体检 / 低内存模式开关 |
| `9 → 2` | 升级或切换内核（含切到系统包版、切回 GitHub） |
| `10` / `11` | 导出链接与订阅 / 订阅服务 |
| `12` | Argo 隧道（无公网入口时用） |
| `14` / `15` / `16` | 自检修复 / 完全卸载 / 检查更新 |

菜单顶部实时显示服务状态、节点数、内存和 CPU。**协议默认全部允许跳过证书校验**，客户端导入后不用再手动开开关。

## 订阅

启动订阅服务（菜单 `11`）后得到一个地址，填进客户端「订阅」栏即可，脚本会按客户端自动返回 v2rayN / 小火箭 / Clash / sing-box 对应格式：

```
http://<服务器IP>:8088/sub/<token>
```

- 客户端没被识别 → 用面板里的**通用地址** `/sub/<token>/std`，任何客户端都能导入。
- 想要本地文件 → 菜单 `10 → 3 → 3` 下载 `clash.yaml`（也可用 scp / 本机复制）。
- **订阅服务默认不开**，nginx 不会自动安装；不开服务也能在菜单 10 里复制链接、扫码、导出各客户端配置。
- 拉不到订阅：先放行 `8088/tcp`（云服务器还要在控制台安全组放行），再确认面板显示「● 运行中」。

## 小内存机器

| 手段 | 入口 | 说明 |
|---|---|---|
| **只留 1~3 个协议** | 菜单 `3` 删除节点 | 收益最大，每个协议都要常驻 TLS/QUIC 上下文 |
| 不开 Argo / 订阅 | 菜单 `12` / `11` | cloudflared 常驻 20~40M |
| 低内存模式 | 菜单 `8 → 6` | Go 堆软上限 + warn 日志；≤512 MiB 的机器首次安装自动开 |

GOMEMLIMIT 是**软目标**，只让 GC 更积极，不会把主服务 OOM kill；Swap 命令体检屏只打印、不代做。换安装源（apk 版 / 官方二进制）**不会更省内存**，两者是同一个 Go 程序。

## 常见问题

- **卡在「55% 下载 sing-box」**：连不上 GitHub。看 `logs/singbox-download.log`，可挂代理、`SINGBOX_DOWNLOAD_MIRROR=https://ghproxy.net/ bash sb.sh`，或重跑并选 `3` 用 Alpine 系统包版。现在下载失败会**立即停止安装**，不会再打印假的「安装完成」。
- **客户端连不上但面板正常**：多半是 NAT / 端口映射，去菜单 `6` 填入站 IP 和映射端口。
- **升级后菜单还是旧功能**：`sb` 是安装时的快照，跑一次 `sb update`。
- **Alpine 提示 `cannot execute: required file not found`**：musl 需要 `-musl` 构建，脚本会自动选；旧版先 `sb update`。
- **系统包版不能开 HTTP/3**：版本低于 1.15.0，缺 `version` 字段；到菜单 `9 → 2` 选 1 换回官方二进制。

## 卸载

菜单 `15` → 输入 `DELETE` 确认。会停掉 Argo 隧道服务；系统路径下的 cloudflared、nginx 会**先问你**要不要一并卸（默认不卸，避免影响别的项目）。选了 Alpine 系统包版时，脚本只删自己创建的软链，系统包需自行 `apk del sing-box sing-box-openrc`。

---

<details>
<summary>维护者说明与更新日志（普通用户可跳过）</summary>

### 交付约定

- 本地交付恰好三份：`sing-box-nat-v3.9.19.sh`、`sing-box-nat-v3.9.19-nocomment.sh`、`README.md`（固定名）。每次 `VERSION` +0.1 时前两份同步重命名，README 头部徽标与更新日志同步。
- **仓库入口永远叫 `sing-box.sh`**：`UPDATE_URL` 与已部署机器的 `sb update` 都依赖这个固定地址，改名会让旧机器集体失效。发布时把带版本号的文件复制/上传成 `sing-box.sh`，原件留作归档。
- 校验四件套：两份脚本 `bash -n`、非注释代码行逐字一致、heredoc 体逐字一致、纯 LF；版本号在源码 `VERSION`、第 9 行文件头、无注释版、README 徽标四处一致。

### 更新日志

### V3.9.19（当前版本）
- 安装时可选 **Alpine 系统包版**：识别系统后查 apk 源版本并显示在确认屏，走 Alpine CDN、不碰 GitHub，`$BIN` 用软链跟随系统包升级。
- 修掉「下载失败仍继续写服务并打印安装完成」；两条安装路径都检查返回值。
- 接管 apk 自带的 `/etc/init.d/sing-box` 前先备份，卸载时按需还原；卸载确认屏说明系统包不会自动卸掉。
- 升级菜单新增第 5 项反向切到系统包版；「只重装内核」按当前来源重装；预查频道不再污染默认频道。
- 重写 README 为面向用户的精简版，技术细节与历史日志收进本折叠区。

### V3.9.18
- 确认屏不再把**空行**当成用户选了默认：必须显式输入 `1`/`2` 和 `y`，三次无效即中止。
- 新增低内存模式（`GOMEMLIMIT` / warn 日志 / fd 上限）与「服务管理 → 6 内存体检」。
- 交付文件名改为带完整小版本号。

### V3.9.17
- 确认屏不再把 **EOF** 当成默认选择；读不到输入就停止安装并给出正确运行方式，无人值守需 `SB_ASSUME_DEFAULTS=1`。

### V3.9.16
- 安装确认屏新增「最新版 / 正式版」二选一；修掉 stable 断网兜底会装到 alpha 的缺陷。

更早版本（V3.9.15 及以前）见仓库提交历史。

</details>
