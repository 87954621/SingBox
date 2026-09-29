# Sing-box NAT 多协议管理脚本

一个 Bash 单文件脚本，在 Linux 服务器（NAT 机器 / VPS / 云服务器）上部署和管理 sing-box 的 **16 种代理协议**，带菜单界面、节点管理、二维码，以及**订阅服务**——让 v2rayN / Clash(mihomo) / sing-box / 小火箭(Shadowrocket) 等客户端通过**一个订阅链接**直接导入全部节点。



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
 3. 节点管理                  查看、改端口、看链接、扫码、重命名、清理孤儿入站、删除
 4. 端口范围 / 默认端口
 5. 网络检测 / UDP 模式
 6. 客户端设置                uTLS 指纹 / UoT / SNI / 节点命名
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

## 节点命名

新建节点时，名字默认是 **`<国家/地区> <协议类型>`**，例如：

```
中国香港 VLESS + Reality
中国香港 Hysteria2
日本 Shadowsocks 2022
```

- **国家/地区**由脚本探测本机公网 IP 自动得出（离线或探测失败时只留协议类型）；
- **单个节点部署**时，脚本会在最后多问一句「节点名称」，直接回车即用默认名，也可以当场改成任意名字；
- **批量部署**不打断流程，统一用默认名（部署完可在「3. 节点管理 → 7. 重命名节点」里批量改）。

想换个前缀？**主菜单 6（客户端设置）→ 5. 节点命名**：

| 选项 | 说明 |
|---|---|
| 设置自定义前缀 | 例如 `HK-01` / `东京`，之后新建节点名字变成 `HK-01 VLESS + Reality` |
| 清空前缀 | 改回用国家/地区名 |
| 按当前规则重命名已有节点 | 立刻把已部署的节点名统一刷新，并重新生成订阅 |

「节点管理 → 7. 重命名节点」还支持**全部加统一前缀**和**单个节点改名**。改名只影响订阅里显示的名字，不动端口和密钥。

---

## 订阅：一个 URL 走天下

入口：**主菜单 9（订阅与节点链接）→ 订阅服务管理**。

启动订阅服务（默认端口 8088）后得到一个形如 `http://<服务器IP>:8088/sub/<token>` 的地址，**填进任意客户端的「订阅」栏即可**，脚本按客户端的 User-Agent 自动返回对应格式：

| 客户端 | 自动返回格式 |
|---|---|
| V2rayN / v2rayNG / Throne | base64 订阅（sing-box 专属协议带 `v2rayn://`，自动锁 sing-box 内核） |
| 小火箭（Shadowrocket）/ Quantumult / Loon / Surge / Karing / Hiddify | base64 订阅（**纯标准链接**，识别率最高） |
| Clash Verge / mihomo / Stash | YAML 配置（完整可直接用） |
| Sing-box（SFI / SFA / SFM） | JSON 配置 |

> **小火箭为什么单独一份？** v2rayN 的 `v2rayn://` 是**私有格式**，只有 v2rayN 认识。若把它喂给小火箭，小火箭只认得出 `vless://` / `vmess://` / `trojan://` / `ss://` 这几条标准链接，Hysteria2 / TUIC / AnyTLS / ShadowTLS / HTTP2 / HTTP3 整段解析不了——表现就是「订阅只导入了部分节点」。V2.7 起按 UA 给小火箭单独返回**纯标准链接**的订阅，不再被 `v2rayn://` 卡住。

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

即便不开启订阅服务，「9. 订阅与节点链接」里仍有：一键复制全部链接、二维码、Clash 配置、v2rayN 订阅、**小火箭订阅（纯标准链接）**、sing-box 配置。

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
脚本更新   已装 V3.0，当前源码 V3.1
生效方式   菜单跑的是 menu.sh 快照，执行 sb update 后新逻辑才生效
```

---

## 卸载

- **只卸订阅后端**：主菜单 **9 → 订阅服务管理 → 卸载订阅后端**，可单独移除 nginx 包 / Python 单元 / 订阅产物。
- **整机完全卸载**：主菜单 **12**，输入 `DELETE` 确认。会依次：停止 sing-box → 清理订阅残留（站点配置 / Python 单元 / 订阅文件）→ **询问是否连同卸载 nginx 包**（默认不卸，因为 nginx 可能还跑着你的其它站点，删包是大的系统改动，必须你拍板）→ 删除程序、配置、节点、证书、日志和本脚本。
- **卸载 nginx 会移除整个 nginx**（含你自建的其它站点与配置），脚本会明确警告；确认前请务必确认没有其它站点依赖它。

---

## 常见问题

**Q：Alpine 上升级 / 切换 sing-box 内核后，服务起不来，报 `cannot execute: required file not found`？**
sing-box 每个版本为 Linux 提供三种包：`-glibc` / `-musl` / 无后缀（默认）。默认包在部分版本上是 glibc 动态链接，放到 musl 的 Alpine 上就缺 `ld-linux` 而无法执行。V2.3 起脚本会**按本机 libc 自动选对变体**（musl → `-musl` 包，glibc → `-glibc` 包，取不到再退回默认），并在安装前**实测二进制能否运行**：跑不起来就自动换下一个变体重试，绝不会把跑不起来的二进制顶掉正在工作的内核。若你用的是旧版，重装内核前先升级管理器（`sb update`）即可。

**Q：用 `bash <(curl ...)` 安装后 `sb` 进不去 / 提示找不到 menu.sh？**
`bash <(curl URL)` 时脚本的 `$0` 是 `/dev/fd/63` 这样的**管道**，bash 执行脚本时已把管道读空，脚本无法再读自己来写 `menu.sh`（旧版会静默写出一个空文件）。V2.2 起：读不到源文件时会自动从脚本内置的更新地址重新拉取一份写入。若仍失败，改用「先下载再运行」更稳：`curl -fsSL <URL> -o sing-box.sh && bash sing-box.sh`。

**Q：菜单里显示的版本号是 `22.04.5 LTS (Jammy Jellyfish)`，不是脚本版本？**
早期版本 `detect_os()` 里直接 `. /etc/os-release`，而 os-release 自带 `VERSION="22.04.5 LTS (Jammy Jellyfish)"`，把脚本自己的 `VERSION` 变量覆盖掉了。现改为在子 shell 里读取，不再污染全局变量。

**Q：Xray 内核导入节点后启动失败，提示 `allowInsecure` 被移除？**
Xray-core v26.2.6 起彻底移除了 `allowInsecure`。脚本对 Xray 系协议（vless-ws-tls / vmess-ws-tls / trojan）改用 `pcs=<64位 hex 证书指纹>`（注意是 hex 不是 base64），对 sing-box 专属协议保留 `insecure=1`，两内核都能直接用。Clash / mihomo 侧则对自签证书用 `skip-cert-verify: false` + `fingerprint`（冒号分隔的 SHA256）。

**Q：v2rayN 导入 sing-box 专属协议（Hysteria2 / TUIC 等）报错？**
v2rayN 同时挂 Xray / sing-box / mihomo 三个内核，标准链接不携带内核信息，默认会用 Xray，而 Hysteria2 / TUIC 等是 sing-box 专属。脚本对这 8 个协议导出 `v2rayn://` 私有格式链接，显式锁定 `CoreType:24`（sing-box），导入后自动切内核。

**Q：小火箭（Shadowrocket）导入订阅后只认出部分节点，Hysteria2 / TUIC 等不见了？**
因为订阅服务此前把 v2rayN 的私有格式 `v2rayn://` 也发给了小火箭，而小火箭不认识这个 scheme，只认 `vless://` / `vmess://` / `trojan://` / `ss://` 这类标准链接，其余整段被丢弃。V2.7 起订阅服务按 UA 分流：识别到小火箭就给**纯标准链接**的订阅（`hysteria2://` / `tuic://` / `anytls://` / `http://` 等），能导入多少是多少，不再被 `v2rayn://` 卡住。
> 升级后需要**重启一次订阅服务**（主菜单 9 → 订阅服务 → 1. 启动 / 刷新订阅服务），新的分流规则才会生效（nginx 后端尤其如此，它读的是磁盘上的站点配置）。也可在小火箭里直接改用「9 → 5. 小火箭订阅」的地址。

**Q：节点名全是 `Hysteria2` 这种，分不清哪条是哪台机器的？**
V2.7 起默认命名是 `<国家/地区> <协议类型>`（如 `中国香港 Hysteria2`），多台机器混进同一订阅也能区分。想自定义前缀见上面的「节点命名」一节。

**Q：Alpine 上「TLS SNI 域名优选」所有域名都显示 `0 ms`，或者卡在某个域名不动？**
两个都源于 BusyBox/musl 与 GNU 的差异，已修（`sb update` 升级即可）：
- `0 ms`：计时用了 GNU 专有的 `date +%s%3N`，BusyBox 的 date 不报错、只把 `%3N` 原样输出，导致差值恒为 0。V2.9 起改用三级回退的 `now_ms()`（GNU `%N` → `/proc/uptime` → `date +%s`）。
- 卡死：V2.9 先改用 `curl -I --connect-timeout 2 --max-time 3`，但**只修好了一半**——如果卡在**本机 DNS 解析**里，curl 自己的超时是无效的（`getaddrinfo()` 是同步阻塞调用，curl 的定时器根本没机会跑），而 BusyBox 的 `timeout` 也未必收得掉。典型现象是**每次都卡在不同域名**（一次第 7 个 `gateway.icloud.com`、一次第 10 个 `www.bing.com`）。
  **V3.0 起**在探测外面套了一层纯 bash 看门狗 `run_with_timeout`：后台起进程 + 到点 `kill -9`。SIGKILL 不可被捕获/阻塞，卡在 DNS 里也照杀，**单个域名最多耗 5 秒**；并且连续 3 个域名不可达就直接中止测速，提示你检查 `cat /etc/resolv.conf`，不再白等 12 个域名。

**Q：测速时刷屏 `menu.sh: fork: retry: Resource temporarily unavailable`？**
这是**系统进程数（pids）被占满、fork 直接失败**，不是脚本报错。V3.0 的看门狗写法有缺陷：`( sleep N; kill ) &` 里 kill 只能杀掉那个子 shell，子 shell 里的 `sleep` 会变成**孤儿**继续活满 N 秒；12 个候选域名几秒内跑完，孤儿能攒到十几个，在小 pids 限额的小鸡上就把进程数打满了。
**V3.1 起**把定时器改成「`sleep N &` 单命令后台化」——`$!` 拿到的就是 sleep 进程本身，目标一结束就**真把它杀掉，零孤儿**；并用 `wait -n` 阻塞等待（不轮询、不空转）。顺带去掉了 `mktemp`/`cat`/`rm` 三件套，命令输出直接走 stdout。**每个域名的 fork 次数从 6 次降到 2 次，测速结束不留任何后台进程。** 另加 30 秒总时长上限（用 bash 内建 `SECONDS`，零开销）兜底。

**Q：Alpine 上「系统信息」的 CPU 占用一直是 `—`？**
同一个根因（`date +%s%N` 拿不到数字），V2.9 一并修好了。

**Q：部署节点时提示 `jq: error: syntax error, unexpected label, expecting IDENT`？**
V2.7 的一个 bug：节点记录里用了一个叫 `label` 的字段，而 `label` 是 jq 的保留关键字，不能直接当对象键。升级到 **V2.8**（`sb update`）即可，该字段已改名 `proto_label`。

**Q：升级后发现某次部署「配置已应用」，但节点列表和订阅里都没有那个节点？**
那是 V2.7 的 bug 留下的**孤儿 inbound**：inbound 已写进 `config.json`，但节点记录没写成功，所以它不在订阅里、也没法在菜单里删除（还白占一个端口）。V2.8 起不会再产生；清理已有的：
- 「11. 自检 / 修复」会把它列出来；
- 「3. 节点管理 → 8. 清理孤儿入站」确认后即可删除。

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
- libc：glibc（Debian / Ubuntu / CentOS…）与 musl（Alpine / OpenWrt…）都会**自动下载对应的 sing-box 构建**，不需要手动选包
- 依赖：`jq`、`curl`（脚本会自动尝试安装缺失的）
- **不依赖 GNU 扩展**：`date +%s%N`、`sort -V`、`ps --no-headers` 这类 GNU 专有用法要么已规避、要么带 BusyBox 回退（见「版本说明 → V3.1」），Alpine / OpenWrt 这类 BusyBox 环境可正常使用
- **不依赖外部 `timeout` 命令**：需要硬超时的地方统一走脚本自带的 `run_with_timeout`（纯 bash 看门狗 + `kill -9`），精简系统上没装 `timeout` 也不影响
- **轻量**：探测类操作（SNI 优选）每个域名只 fork 2 个进程，用 `wait -n` 阻塞等待（不轮询、不吃 CPU），跑完即收干净、不留后台进程

---

## 版本说明

### V3.1
- **修复 SNI 优选刷屏 `fork: retry: Resource temporarily unavailable`（系统 pids 被占满）。**
  - V3.0 的看门狗写成 `( sleep N; kill -9 $pid ) &`，**kill 只能杀掉那个子 shell**，子 shell 里的 `sleep` 会变成**孤儿**继续活满 N 秒。12 个候选域名几秒内跑完，孤儿攒到十几个，在 pids 限额很紧的小鸡上直接把进程数打满、fork 失败刷屏。
  - 现在定时器改成 **`sleep N &` 单命令后台化** —— bash 直接 fork+exec，`$!` 拿到的就是 sleep 进程本身的 PID，目标一结束就 `kill -9` 它，**真杀掉、零孤儿**。
  - 等待方式改成 **`wait -n`**（等"先结束的那个"）：**阻塞等待，不轮询、不空转**，既不占 CPU 也不会为了"每 0.2 秒看一眼"白等。老 bash（<4.3）自动退回分片看门狗。
  - 顺带**去掉 `mktemp` / `cat` / `rm` 三件套**：命令输出直接走 stdout 由调用方 `$(...)` 捕获，省掉 3 次 fork 和 3 次磁盘 IO。
  - 结果：**每个域名 fork 次数 6 → 2，测速结束零后台进程残留**（函数返回前目标和定时器都已 `kill -9` + `wait` 收尸）。
- **新增 30 秒总时长上限**：用 bash 内建 `SECONDS` 计时（零 fork 零开销），大面积超时时果断收手，不让用户干等（最坏原本要 12×5=60 秒）。
- 老 bash（< 4.3，没有 `wait -n`）自动退回分片看门狗：每 1 秒自检一次，目标提前结束时立刻自己退出；即便被强杀，里面的 `sleep` 最多也只活 1 秒。

### V3.0
- **彻底修复 Alpine 上「SNI 优选」卡死**（V2.9 只修好了一半）。
  - 真根因：卡顿发生在**本机 DNS 解析**里。`getaddrinfo()` 是**同步阻塞调用**，curl 的 `--connect-timeout` / `--max-time` **管不了**它（定时器根本没机会触发）；BusyBox 的 `timeout` 也未必存在、未必收得掉卡住的子进程。用户实测**每次卡在不同域名**（第 7 个 `gateway.icloud.com`、第 10 个 `www.bing.com`），域名不固定 = 本机 DNS 抽风，不是某个域名的问题。
  - 修法：新增纯 bash 看门狗 **`run_with_timeout <秒> <命令...>`** —— 后台起进程 + 到点 `kill -9`。SIGKILL 不可被捕获/阻塞，卡在 DNS 里也照杀；全程只用 `sleep` / `kill` / `wait`，BusyBox 都有，**不依赖外部 `timeout` 命令**。`probe_sni` 外面套上它，**单个域名最多耗 5 秒**，无论卡在哪一步都收得掉。
  - 另外新增**连续失败熔断**：连续 3 个域名不可达即中止测速（判定为本机 DNS / 出网异常），并提示 `cat /etc/resolv.conf`、`ping -c2 1.1.1.1` 自查，不再把 12 个域名挨个白等一遍。
- **顺带去掉一处外部 `timeout` 依赖**：UDP 出站探测的兜底分支原本写 `timeout 4 bash -c '...'`，精简系统缺 `timeout` 会让整段直接判成「UDP 被限制」的**假阴性**（进而误砍 UDP 类协议）；现在改用自带的 `run_with_timeout`。

### V2.9
- **修复 Alpine（BusyBox / musl）上「SNI 优选」全部显示 `0 ms`、并且会卡死**：
  - `0 ms` 的原因：计时用了 `date +%s%3N`，而 `%N` 是 **GNU date 的扩展**。BusyBox 的 date **不报错**，只是把 `%3N` 当普通字符原样输出（得到 `1759146789%3N`），于是退出码是 0（`|| 兜底` 根本不触发）、`$((t2-t1))` 也算不出数，所有域名都成了 `0 ms`。
  - 卡死的原因：探测用的是 `timeout 2 openssl s_client …`，在 Alpine 上实测**卡在某个候选域名（如 www.bing.com）再也不往下走**——openssl 卡在 connect/DNS 时 BusyBox 的 `timeout` 没能及时回收它，把整个节点部署流程一起僵住。
  - 现在改为**新增 `now_ms()`（GNU `%N` → `/proc/uptime` → `date +%s` 三级回退，跨发行版通用）**，并把探测换成 **`curl -I` + `--connect-timeout/--max-time`**：超时由 curl 自己强制，不再依赖外部 `timeout`；`%{time_appconnect}` 直接给出 TCP+TLS 握手耗时，而且**不看 curl 退出码**（超时/对端提前断开时握手时间仍然有效），只有 `0`/空才判定为不可达。
- 顺带修好同一根因的两个地方：**「系统信息 / 订阅服务」里的 CPU 占用在 Alpine 上永远显示不出来**（`cpu_pct` 和 `sub_resource` 也用了 `date +%s%N`，拿不到数字就直接返回空）——现在统一走 `now_ms()`。

### V2.8
- **修复 V2.7 引入的严重回归：任何协议都部署不了**。V2.7 给节点记录加了一个叫 `label` 的字段，但 **`label` 是 jq 的保留关键字**（`label $out | ... break $out` 用的就是它），写成 `{label:$label}` 会被 jq 判为语法错误：
  ```
  jq: error: syntax error, unexpected label, expecting IDENT or __loc__
  ```
  于是 `add_node` 整条失败，但 `append_inbound` 早已把 inbound 写进 `config.json` —— 结果就是「配置检查通过 → 配置已应用」，可节点既没进节点列表、也没进订阅。该字段已改名为 `proto_label`（非关键字）。
- **不再产生「孤儿 inbound」**：`add_node` 现在会**判成败**并在失败时返回非 0；单协议部署会检查返回值，发现 `config.json` 真被改过就**自动回滚到操作前快照**，不会再出现「有 inbound、没节点记录」的中间态。
- **新增「孤儿 inbound」检测与清理**：config 里有 inbound、节点列表里却没有对应记录（历史遗留）时——
  - 「11. 自检 / 修复」会直接列出来并提示；
  - 「3. 节点管理 → 8. 清理孤儿入站」可一键查看并删除（逐个确认，删完自动 `validate` + 重启 + 刷新订阅）。
  判定用的是「同协议 + 同端口 + 同传输层」精确匹配，所以新旧节点共存时能准确认出哪个才是多余的（不会误删刚部署好的那个）。

### V2.7
- **修复小火箭（Shadowrocket）订阅「只认出部分节点」**：v2rayN 的 `v2rayn://` 是私有格式，只有 v2rayN 认识；订阅服务此前把它当作「未知 UA」的兜底内容发给了所有其它客户端（含小火箭），于是 Hysteria2 / TUIC / AnyTLS / ShadowTLS / HTTP2 / HTTP3 这些走 `v2rayn://` 的协议在小火箭里整段解析失败。现在按 UA 分流：**小火箭返回纯标准链接的订阅**（nginx 后端加了一条 `map` 规则，Python 后端加了对应分支），能导入多少是多少。订阅菜单新增「5. 查看 / 复制 小火箭订阅」。
- **节点名默认改为 `<国家/地区> <协议类型>`**（如 `中国香港 VLESS + Reality`），不再所有节点都叫同一个协议名。单个节点部署时会多问一句「节点名称」（回车用默认），可当场自定义；批量部署沿用默认名不打断流程。
- **新增「节点命名」设置**（主菜单 6 → 5）：可设自定义前缀（如 `HK-01`）、清空回退到国家名、或**立即把已有节点按当前规则重命名**；「节点管理 → 7. 重命名节点」还支持全部加统一前缀与单个改名。改名只影响订阅显示，不动端口与密钥。

### V2.6
- **修复 Alpine 上订阅服务启用 nginx 后 `nginx -t` 报 `"map" directive is not allowed here`**：各发行版的 nginx 站点目录并不一致 —— Debian/Ubuntu/CentOS/Arch 把 `include /etc/nginx/conf.d/*.conf;` 放在 **`http` 块内**，而 **Alpine 的 conf.d 是给主上下文（root）用的**，`http` 块里用的是 `/etc/nginx/http.d/*.conf`。脚本此前写死 `conf.d`，于是在 Alpine 上把 `map` / `server` 塞进了主上下文 → 配置非法、`nginx -t` 失败，还会**连带整台 nginx（含你自建的其它站点）一起校验不过**。现在改为**读 `/etc/nginx/nginx.conf`、定位 `http` 块内的 `include .../*.conf;` 目录**（探测不到再按 `http.d` / `conf.d` 存在性兜底），并会在启动时自动清掉旧版遗留在错误位置的配置。
- 顺带：IPv6 监听（`listen [::]:<port>`）改为**仅在系统真的启用 IPv6 时**才写入，避免无 IPv6 的机器报 `socket() [::]:port failed (97: Address family not supported by protocol)`。

### V2.5
- **「系统信息」新增「进程数量」一行**：并排显示 `sing-box N   nginx M   系统 K`（N/M 为进程数，K 为整机进程总数）。一眼看出 sing-box 是否多开/挂掉、nginx 是否还在跑；nginx 未安装时显示「未装」而不是误导性的 `0`。进程名用 `pgrep -x` 精确匹配，没有 `pgrep` 时退回 `ps -e -o comm`。
- **修复「系统信息」里 CPU / 内存 / 已运行整行消失**：这几行原本只在服务运行时才打印，服务一停就整行不见，看着像「被删掉了」。现在改为**始终占位**，取不到值时显示灰色 `—`，行位置固定不跳动。

### V2.4
- **修复「升级 / 切换内核」面板版本号显示 `null`**（V2.3 引入的回归）：V2.3 挑构建变体时误用了等值比较 `select(.name == "linux-amd64-glibc.tar.gz")`，但真实资源名带版本前缀（`sing-box-1.14.2-linux-amd64-glibc.tar.gz`），等值永远不成立 → 一个版本都选不出来 → 面板显示 `null`。现改回 `endswith`，四处 jq 全部修正；并加了一道防御：选不出时输出空而不是 `null`，面板会如实显示「查询失败，将用内置版本」。
- 顺带修正 `libc_kind()` 在 glibc 系统上的判定：`ls /lib64/... /lib/...` 两个通配符只要有一个不匹配，`ls` 就返回非零，导致 glibc 系统被误判成「未知」；现改为分别检测。

### V2.3
- **修复 Alpine（musl）上升级 / 切换内核后起不来**：sing-box 每个版本都为 Linux 提供三种包 —— `-glibc` / `-musl` / 无后缀（默认）。脚本此前只按 `endswith("linux-<arch>.tar.gz")` 匹配，永远拿到**默认包**；默认包在部分版本上是 glibc 动态链接，在 musl 的 Alpine 上执行会报 `cannot execute: required file not found`（找不到 glibc 的 ld-linux）。现在会**按本机 libc 选对变体**：musl 系统优先 `-musl` 包、glibc 系统优先 `-glibc` 包，取不到再退回默认包。版本列表、指定版本号这两条路径也改为先查该 tag 的真实资源名再挑变体，不再凭空拼 `linux-<arch>.tar.gz`。
- **安装前增加「执行自检」，并逐个变体重试**：下载后先落到 `sing-box.new` 并实测 `sing-box version` 能否运行，跑不起来就自动换下一个 libc 变体（musl → glibc → 默认）重试，全部失败才报错。这样**任何情况下都不会用跑不起来的二进制顶掉正在工作的内核**，Ubuntu 等 glibc 系统的正常路径完全不受影响。
- **修复回滚后版本号显示错误**：升级失败回滚时，旧内核二进制会换回去，但版本号文件已被新内核改写、版本缓存也没失效，界面会显示成新版本号（实测回滚后仍显示 1.14.2）。现在回滚会一并还原版本号文件、作废版本缓存；成功换内核后也会立即作废缓存。

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
