# Sing-box NAT 多协议管理脚本

一个 Bash 单文件脚本，在 Linux 服务器（NAT 机器 / VPS / 云服务器）上部署和管理 sing-box 的 **16 种代理协议**，带菜单界面、节点管理、二维码，以及**订阅服务**——让 v2rayN / Clash(mihomo) / sing-box 等客户端通过**一个订阅链接**直接导入全部节点。



> 安装后以 `sb` 命令调用管理器；`sb` 是安装时这份脚本的快照，改了源码后需 `sb update` 才生效。

---

## 快速开始


# 方式一：把脚本传到服务器后直接 bash（推荐）
```bash
bash sing-box.sh
```

# 方式二：curl 一键安装（把 <脚本下载地址> 换成你的实际地址）
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/87954621/SingBox/refs/heads/main/sing-box.sh)
```

装完后用 `sb` 进入菜单：

```bash
sb                # 进入管理菜单
sb check          # 检查管理器是否有新版本（来自 GitHub），可一键更新
sb update         # 更新已安装的管理器（用当前脚本覆盖 menu.sh）
sb version        # 查看版本
sb help           # 帮助
```

首次运行会引导安装 sing-box 内核；之后 `sb` 直接进入菜单。

---

## 主菜单

```
 1. 节点部署                  单个协议交互式部署
 2. 批量部署                  多选 / all，一次装多个协议
 3. 节点管理                  查看、改端口、看链接、扫码、删除
 4. 端口范围 / 默认端口
 5. 网络检测 / UDP 模式
 6. 客户端设置                uTLS 指纹 / UoT / SNI
 7. 服务管理                  启停、重启、配置检查
 8. sing-box 管理             内核版本、升级、重装（不碰配置和节点）
 9. 订阅与节点链接            一个 URL 适配所有客户端
10. 系统信息
11. 自检 / 修复
12. 完全卸载                  内核 + 配置 + 节点 + 本脚本
13. 检查更新                  联网比对管理器版本，可一键更新
 0. 退出
```

### 「7. 服务管理」和「8. sing-box 管理」有什么区别？

不重复，是两类不同的操作：

| | 7. 服务管理 | 8. sing-box 管理 |
|---|---|---|
| 管什么 | **服务怎么跑** | **程序本身** |
| 内容 | 启停 / 重启 / 查状态 / 检查配置 | 内核版本、升级、重装、只卸载内核（保留配置） |
| 类比 | 按电源键 | 装/换/删软件 |

> 注：「完全卸载」只保留主菜单第 12 项一个入口；「sing-box 管理」里只留「只卸载内核（保留配置和节点）」，避免重复入口与手滑。

---

## 支持的 16 种协议

| # | 协议 | 传输 |
|---|---|---|
| 1 | VLESS + Reality | TCP |
| 2 | Hysteria2 | UDP |
| 3 | Hysteria2 + Salamander | UDP |
| 4 | TUIC v5 | UDP |
| 5 | Shadowsocks 2022 | TCP |
| 6 | Trojan + TLS | TCP |
| 7 | VMess + WS + TLS | TCP |
| 8 | VLESS + WS + TLS | TCP |
| 9 | VLESS + H2 + Reality | TCP |
| 10 | VLESS + gRPC + Reality | TCP |
| 11 | AnyTLS | TCP |
| 12 | NaiveProxy | TCP |
| 13 | HTTP/2 | TCP |
| 14 | HTTP/3 | UDP |
| 15 | Hysteria2 + Realm | UDP |
| 16 | ShadowTLS v3 | TCP |

**版本要求**：HTTP/2、HTTP/3、NaiveProxy 等新协议需要 sing-box **1.15.0+**，低版本内核会被自动跳过，可到「8 → 2」升级内核。

**UDP 协议**（2/3/4/14/15）在机器不支持 UDP 时会自动从菜单隐藏，可在「5. 网络检测」里手动改判定。

---

## 订阅：一个 URL 走天下

入口：**主菜单 9（订阅与节点链接）→ 订阅服务管理**。

启动订阅服务（默认端口 8088）后得到一个形如 `http://<服务器IP>:8088/sub/<token>` 的地址，**填进任意客户端的「订阅」栏即可**，脚本按客户端的 User-Agent 自动返回对应格式：

| 客户端 | 自动返回格式 |
|---|---|
| V2rayN / v2rayNG / 小火箭 / Throne | base64 订阅（多协议） |
| Clash Verge / mihomo / Stash | YAML 配置（完整可直接用） |
| Sing-box（SFI / SFA / SFM） | JSON 配置 |

订阅服务菜单还可：停止服务、复制 URL、改监听端口、设 IP 白名单、轮换访问令牌（旧 URL 立即失效）、看日志。

### 后端实现方式：nginx（推荐）或 Python（回退），由你选择

> **绝不自动替你装 nginx。** 首次启动订阅服务时，脚本会让你在 **nginx** 和 **Python** 之间选一个；若选了 nginx 但本机没装，脚本会**先征求你同意（y/N）才安装**——因为装 HTTP 服务属于改动系统的动作（占端口、可能开机自启、影响你其它站点），必须你拍板。

- **nginx（推荐，更省资源）**：C 事件驱动，常驻仅几 MB、空闲几乎零 CPU；若服务器本来就在跑 nginx，则零额外进程（只多一份站点配置）。跨发行版（apt/dnf/yum/apk/pacman/zypper）通用，systemd 与 openrc 都只是 `reload nginx`。UA 分流 + 令牌鉴权 + IP 白名单全部由 nginx 原生完成：`map` 按 User-Agent 选文件与 Content-Type；精确 `location = /sub/<token>` 做令牌校验（其它路径一律 404）；`allow/deny` 做来源限制。**停止只删配置**：选「停止订阅服务」时只移除我们那份 `/etc/nginx/conf.d/singbox-nat-sub.conf` 并 `reload`，不动 nginx 上其它站点。
- **Python（回退）**：若你不想装 nginx、或本机装不上，选 Python。脚本用内置的自包含 Python 服务（systemd socket 激活，空闲零进程零内存），功能完全一致，只是资源占用略高于 nginx。

> 想换实现方式？订阅服务菜单里有「切换实现方式」，切换后会自动按新方式重启，并清掉旧方案的残留（nginx 配置 / Python 单元），避免端口被两套方案抢。

### Clash / mihomo 拉到的 YAML 长这样

脚本生成的 Clash 配置是**完整可直接用**的，自带：

- 骨架：`mixed-port` / `allow-lan` / `mode: rule` / `log-level` / `external-controller` / `geo-auto-update` / `geo-update-interval`；
- `proxies:` 全部节点（密码等含 `+`/`=` 的字段已正确加引号，避免解析报错）；
- `proxy-groups:` 一个 `PROXY`（select，默认走 `AUTO`）和一个 `AUTO`（url-test，按延迟自动选优）；
- `rules:` 一组 `GEOIP` / `GEOSITE` 分流规则（国内直连、广告拦截、AI / 流媒体走代理等）。

直接作为订阅导入即可，无需再手改。

### 不开订阅服务也能用

即便不开启订阅服务，「9. 订阅与节点链接」里仍有：一键复制全部链接、二维码、Clash 配置、v2rayN 订阅、sing-box 配置。

### 客户端拉取订阅超时怎么办

典型现象（v2rayN）：

```
开始获取订阅内容
OperationCanceled            ← 等了十几秒
TaskCanceledException_ctor_DefaultMessage
无效的订阅内容
```

按以下顺序排查：

1. **端口没放行**（最常见）。表现是"一直等到超时"而不是"秒速连接被拒绝"——因为 SYN 被防火墙丢弃。放行 TCP 8088：
   ```bash
   ufw allow 8088/tcp
   # 或：firewall-cmd --add-port=8088/tcp --permanent && firewall-cmd --reload
   # 云服务器还要在控制台「安全组」里放行
   ```
2. **服务没启动**。到「9 → 订阅服务管理 → 启动」，主菜单应显示 `● 运行中`。
3. **订阅内容为空**。没有节点时服务端返回 503，先去部署至少一个节点。

---

## 检查更新

主菜单 **13（检查更新）**，或命令行 **`sb check`**：

1. 从脚本内置的 `UPDATE_URL`（默认指向你的 GitHub 仓库）拉取最新脚本；
2. 解析远端脚本的 `VERSION`，与本地当前版本**按数值逐段比较**（`V1.10` 正确大于 `V1.9`）；
3. 结果分三种：
   - **有新版本** → 提示 `当前 → 远端`，回车即一键更新（写入前先 `bash -n` 语法检查，不通过就放弃、本地不动）；
   - **已是最新** → 直接告知；
   - **本地比远端新** → 说明你可能在跑开发版，不做改动。

> 与主菜单里那条「脚本更新 已装 X，当前源码 Y」提示不同：那条比的是**本机 menu.sh 快照 vs 当前源码**（本地不一致）；「检查更新」比的是**本地 vs GitHub**（远端有没有新版）。两者互补。

换更新源：改脚本里 `UPDATE_URL`（raw 地址）与 `UPDATE_REPO`（仓库主页，仅用于展示）两行即可。

---

## 目录与文件

| 路径 | 说明 |
|---|---|
| `/usr/local/bin/sing-box` | sing-box 内核 |
| `/usr/local/bin/sb` | 管理命令 |
| `/usr/local/share/singbox-nat/` | 数据目录 |
| `├ config.json` | sing-box 配置 |
| `├ nodes.json` | 节点记录 |
| `├ menu.sh` | **菜单快照**（见下） |
| `├ subscription/` | 导出的订阅文件 |
| `├ cert/` | 自签证书（TLS 类协议用） |
| `└ logs/` | 日志、启动失败诊断 |

### ⚠️ menu.sh 是安装时的快照

`menu.sh` 是安装（或 `sb update`）时从脚本复制过去的**快照**，菜单实际执行的是它，不是你手上的源码文件。

所以：**改了脚本 / 换了新版后，必须执行 `sb update`，新逻辑才生效。** 主菜单在不一致时会给出提示（正常情况不显示）：

```
脚本更新   已装 V2.1，当前源码 V2.2
生效方式   菜单跑的是 menu.sh 快照，执行 sb update 后新逻辑才生效
```

---

## 卸载

- **只卸订阅后端**：主菜单 **9 → 订阅服务管理 → 卸载订阅后端**，可单独移除 nginx 包 / Python 单元 / 订阅产物。
- **整机完全卸载**：主菜单 **12**，输入 `DELETE` 确认。会依次：停止 sing-box → 清理订阅残留（站点配置 / Python 单元 / 订阅文件）→ **询问是否连同卸载 nginx 包**（默认不卸，因为 nginx 可能还跑着你的其它站点，删包是大的系统改动，必须你拍板）→ 删除程序、配置、节点、证书、日志和本脚本。
- **卸载 nginx 会移除整个 nginx**（含你自建的其它站点与配置），脚本会明确警告；确认前请务必确认没有其它站点依赖它。

---

## 常见问题

**Q：用 `bash <(curl ...)` 安装后 `sb` 进不去 / 提示找不到 menu.sh？**
`bash <(curl URL)` 时脚本的 `$0` 是 `/dev/fd/63` 这样的**管道**，bash 执行脚本时已把管道读空，脚本无法再读自己来写 `menu.sh`（旧版会静默写出一个空文件）。V2.2 起：读不到源文件时会自动从脚本内置的更新地址重新拉取一份写入。若仍失败，改用「先下载再运行」更稳：`curl -fsSL <URL> -o sing-box.sh && bash sing-box.sh`。

**Q：菜单里显示的版本号是 `22.04.5 LTS (Jammy Jellyfish)`，不是脚本版本？**
早期版本 `detect_os()` 里直接 `. /etc/os-release`，而 os-release 自带 `VERSION="22.04.5 LTS (Jammy Jellyfish)"`，把脚本自己的 `VERSION` 变量覆盖掉了。现改为在子 shell 里读取，不再污染全局变量。

**Q：Xray 内核导入节点后启动失败，提示 `allowInsecure` 被移除？**
Xray-core v26.2.6 起彻底移除了 `allowInsecure`。脚本对 Xray 系协议（vless-ws-tls / vmess-ws-tls / trojan）改用 `pcs=<64位 hex 证书指纹>`（注意是 hex 不是 base64），对 sing-box 专属协议保留 `insecure=1`，两内核都能直接用。Clash / mihomo 侧则对自签证书用 `skip-cert-verify: false` + `fingerprint`（冒号分隔的 SHA256）。

**Q：v2rayN 导入 sing-box 专属协议（Hysteria2 / TUIC 等）报错？**
v2rayN 同时挂 Xray / sing-box / mihomo 三个内核，标准链接不携带内核信息，默认会用 Xray，而 Hysteria2 / TUIC 等是 sing-box 专属。脚本对这 8 个协议导出 `v2rayn://` 私有格式链接，显式锁定 `CoreType:24`（sing-box），导入后自动切内核。

**Q：批量部署报「成功 0；失败 16」？**
已改为逐个协议校验，坏的那个就地回滚，不牵连已成功的；开跑前也会预检内核版本，跳过不支持的协议。

**Q：Clash 导入订阅失败 / 节点为空？**
确认订阅服务已启动且 8088 端口已放行。脚本现在输出的是合法 YAML（多个节点也用 `proxies:` 块序列正确表达），密码等字段已加引号。

**Q：卸载 nginx 时报 `apt-get … Killed`？**
内存紧张的小鸡上，旧写法先 `purge` 一长串包再 `autoremove` 会重复加载包缓存、峰值内存翻倍，被 OOM Killer 干掉。现改为单趟 `apt-get autoremove -y nginx`（参考 f.sh），内存压力小很多；若仍被 Killed，请手动执行对应包管理器卸载 nginx 后重试。

**Q：卸载后运行 `sb` 提示 `menu.sh: No such file or directory`？**
说明数据目录被删了，但 `sb` 入口没被清干净（多为旧版半卸载残留）。V2.0 起：`sb` 会先检测 `menu.sh`，缺失时提示「管理器未安装或已被卸载，请重新安装」；「完全卸载」也会兜底清理 `sb`。要手动清掉：`rm -f /usr/local/bin/sb`。

**Q：nginx 明明已经卸载成功，脚本却报「卸载失败」？**
这是 V1.8 及以前的误判：bash 会把执行过的命令路径缓存进 hash 表，apt 删掉 `/usr/sbin/nginx` 后，同一次会话里 `command -v nginx` 仍会返回缓存中的旧路径，脚本据此以为 nginx 还在。V1.9 已修（命中路径后再实测文件是否存在）。如果你用的是旧版，看到此提示时 nginx 通常已卸干净，可用 `nginx -v` 复核。

---

## 轻量设计

脚本自身对系统资源的占用做了收敛（能缓存的重活都加缓存）：

| 缓存 | TTL | 说明 |
|---|---|---|
| `.sbver.cache` | 60s | 内核版本（避免反复 fork sing-box 二进制） |
| `.ip.cache` | 300s | 公网 IP（且 IPv4 成功就不再试 IPv6） |
| `.net.cache` | 600s | 网络/UDP 探测结果（跳过 dig） |
| `.cpu.cache` | 5s | CPU 占用采样（避免每次菜单重绘都等 0.3 秒） |

缓存文件都在数据目录下，卸载时随目录一起删除。

---

## 兼容性

- 系统：Debian / Ubuntu / CentOS / Rocky / AlmaLinux / Fedora / Alpine / Arch 等
- init：systemd（完整支持）、openrc、无 init 的手动进程模式
- 架构：x86_64 / arm64 等（自动检测）
- 依赖：`jq`、`curl`（脚本会自动尝试安装缺失的）

---

## 版本说明

### V2.2
- **修复 `bash <(curl ...)` 一键安装后 `menu.sh` 写不出来**：该方式下脚本的 `$0` 是 `/dev/fd/63` 这样的**管道**，bash 执行脚本时已把管道读空，脚本无法再读自己（旧版 `cp` 会静默写出一个**空 menu.sh**，于是 `sb` 进去什么都没发生）。现在 `write_self_menu` 读不到源文件时会自动从内置更新地址重新拉取一份写入；安装阶段也会检查写入结果，失败即明确中止，不再假装「安装完成」。

### V2.1
- **新增「检查更新」**：主菜单第 13 项，或命令行 `sb check`。从 GitHub 拉取最新脚本、解析其版本号并与本地比较：有新版本则提示并可一键更新（写入 `menu.sh` 前先做语法检查，通过才覆盖）；已是最新 / 本地更新则如实告知。更新源固定在脚本的 `UPDATE_URL` / `UPDATE_REPO` 两行，换仓库只改这里。
- 版本比较按数值逐段进行，`V1.10` 正确大于 `V1.9`；不依赖 `sort -V`（BusyBox / Alpine 不支持）。

### V2.0
- **所有卸载流程都带进度条**：此前只有「完全卸载」（主菜单 12）有进度条，「订阅后端卸载」（9 → 卸载订阅后端）和「只卸载内核」没有，现已补齐，观感一致。
- **修复进度条串行 / 残留**：旧 `progress()` 在 <100% 时不换行，导致①上一条更长的标签尾巴残留（`清理订阅服务残留box 系统服务`）；②紧随其后的 `ok` / `warn` 被追加到进度条同一行（`…50% 卸载 nginx 软件包⚠ …`）。现每步先清行（`\033[K`）再换行，两个问题一并根治。
- **修复卸载后 `sb` 悬空报错**：`sb` 包装脚本现在会先检查 `menu.sh` 是否存在，缺失时提示「管理器未安装或已被卸载，请重新安装」，而不是抛 `menu.sh: No such file or directory`。同时「完全卸载」会兜底清掉常见位置的 `sb` 包装脚本（仅删带本脚本标记行的文件，绝不误删同名命令）。

### V1.9
- **修复「nginx 明明卸载成功却报失败」的误判**：bash 的命令 hash 缓存导致 `command -v nginx` 在 apt 删掉二进制后仍返回旧路径，`nginx_available` 据此误判 nginx 仍在。现改为命中路径后再实测文件是否存在（`[ -x ]`），缓存失效后不再误报。
- **脚本自带 CRLF 防御**：写 `menu.sh`（`write_self_menu`）与生成 `sb` 包装脚本（`install_sb_cmd`）时统一用 `tr -d '\r'` 剥离 `\r`。即便源码或 `sb update` 下载来的文件带 Windows 行尾，落盘产物也永远是纯 LF，不会再出现 `$'\r': command not found` 导致 `sb` 静默无反应。

### V1.8
- **修复 nginx 卸载在内存紧张的小鸡上被 OOM Killer 干掉**（`apt-get … Killed`，并误报「卸载失败」）。改为参考 「单趟 `apt-get autoremove -y nginx`」，不再先 purge 一长串包再 autoremove，峰值内存减半。
- **升级 Clash 订阅为完整配置**：补齐 `mixed-port` / `external-controller` / `geo-auto-update` 等骨架，新增 `PROXY`（select）+ `AUTO`（url-test）分组与 `GEOIP` / `GEOSITE` 规则；密码等含特殊字符的字段统一加引号。
- （沿用 V1.7）修复 Clash 导入根因（非法 YAML 块序列）、nginx 卸载健壮性、`nginx -t` 报错可见、主菜单第 12 项完全卸载会清理订阅与 nginx、订阅后端实现方式严格由用户选择（绝不自动装 nginx）。
