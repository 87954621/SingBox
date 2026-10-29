# Sing-box NAT 多协议管理脚本

一个 Bash 单文件脚本，在 Linux 服务器上部署和管理 sing-box 的 **16 种代理协议**，带菜单界面、节点管理和**订阅服务**——让 v2rayN / Clash(mihomo) / sing-box / 小火箭 等客户端通过**一个订阅链接**导入全部节点。

**V3.9.11**

> **本次更新**：**SNI 优选的测速站全换成国外的**——原来 4 个国内测速站全部移除，换成 `speed.cloudflare.com` / `www.speedtest.net` / `www.ookla.com` / `testmy.net`（都是国外站点、大陆可直连、走全球 CDN）。此前版本已有：cloudflared 能卸干净、Argo 状态行显示内存 CPU、Argo 提升主菜单第 12 项、Clash 配置可直接下载、修复 fork bomb、OpenRC 支持。详见文末「更新日志」。

---

## 快速开始

```bash
# 方式一：下载后运行（推荐）
bash sing-box.sh

# 方式二：一键安装（把 URL 换成你的实际地址）
bash <(curl -fsSL https://raw.githubusercontent.com/87954621/SingBox/refs/heads/main/sing-box.sh)

# 方式三：没有 curl 的精简系统（Alpine / BusyBox 自带 wget）——先下载再运行
wget -qO sb.sh https://raw.githubusercontent.com/87954621/SingBox/refs/heads/main/sing-box.sh && bash sb.sh
```

> ⚠️ **别写成 `wget -qO- URL | bash`**：安装过程会在终端问你 y/N（如「是否安装 nginx」），管道里这些 `read` 会把后面的脚本内容当答案吞掉，表现为「提示一闪就跳过、装到一半莫名报错」。要么先下载再运行（方式三），要么用 `bash <(wget -qO- URL)`（限 bash；sh/ash 没有进程替换请用方式三）。

装完后用 `sb` 进入菜单：

```bash
sb            # 管理菜单
sb check      # 检查管理器更新
sb update     # 更新管理器
sb version    # 查看版本
sb help       # 帮助
```

首次运行会引导安装 sing-box 内核。

> `sb` 是**安装时这份脚本的快照**。改了源码后需 `sb update` 才生效。

---

## 主菜单

```
 1. 节点部署                  单个协议交互式部署（末项为 Argo 隧道）
 2. 批量部署                  多选 / all，一次装多个协议
 3. 节点管理                  查看、改端口、看链接、扫码、重命名、清理、删除
 4. 端口范围 / 默认端口
 5. 网络检测 / UDP 模式
 6. 入站 IP / 端口映射        客户端连不上时的第一排查点
 7. 客户端设置                uTLS 指纹 / UoT / SNI / 节点命名 / 证书放行 / Clash 分流
 8. 服务管理                  启停、重启、配置检查
 9. sing-box 管理             内核版本、升级、重装（不碰配置和节点）
10. 订阅与节点链接            链接 / 二维码 / 各客户端订阅
11. 订阅服务                  订阅后端 / 订阅 URL / 日志 / 令牌 / 白名单
12. Argo 隧道                 CF 内网穿透：临时/Token 隧道、换域名、传输协议
13. 系统信息
14. 自检 / 修复
15. 完全卸载                  内核 + 配置 + 节点 + 本脚本
16. 检查更新                  联网比对管理器版本，可一键更新
 0. 退出
```

菜单顶部那几行状态是实时的：

```
服务状态   ● 运行中  CPU 0.0%  内存 25M  2 个节点  · 开机自启
订阅服务   ● 运行中  :38088  内存 4M  CPU 0.0%
Argo 隧道  ● 运行中  1 个节点  内存 32M  CPU 0.0%   ← 只在你有 Argo 节点时才出现
```

> **Argo 隧道那一行为什么重要**：Argo 节点靠 cloudflared 隧道回源。隧道一旦停了，节点还在订阅里、客户端也显示「已导入」，但**一条都连不通**。所以有 Argo 节点时这一行会常驻，隧道挂了立刻变红。

---

## 支持的 16 种协议

按部署菜单里的顺序：

```
 1. VLESS + Reality              TCP     9. VLESS + H2 + Reality      TCP
 2. Hysteria2                    UDP    10. VLESS + gRPC + Reality    TCP
 3. Hysteria2 + Salamander       UDP    11. AnyTLS                    TCP
 4. TUIC v5                      UDP    12. NaiveProxy                TCP
 5. Shadowsocks 2022             TCP    13. HTTP/2                    TCP
 6. Trojan + TLS                 TCP    14. HTTP/3                    UDP
 7. VMess + WS + TLS             TCP    15. Hysteria2 + Realm         UDP
 8. VLESS + WS + TLS             TCP    16. ShadowTLS v3              TCP
```

端口从 `20000`（TCP）/ `40001`（UDP）起自动分配，可改（主菜单 4）。

> UDP 相关协议需要服务商放行 UDP 入站。脚本会自动探测，若不可用则菜单只显示 TCP 协议（可在「5. 网络检测 / UDP 模式」里手动覆盖）。

每个节点默认命名为 **「国家/地区 + 协议类型」**（如 `中国香港 Hysteria2`），多台机器混进同一订阅也能区分。想改前缀：**主菜单 7 → 5**。

---

## 订阅：一个 URL 走天下

入口：**主菜单 11**，或 **主菜单 10 → 8**。

启动订阅服务（默认端口 8088）后得到一个地址，填进任意客户端的「订阅」栏即可：

```
http://<服务器IP>:8088/sub/<token>
```

脚本按客户端 User-Agent 自动返回对应格式：

| 客户端 | 自动返回 |
|---|---|
| v2rayN / v2rayNG / Throne | base64 订阅（sing-box 专属协议自动锁 sing-box 内核） |
| 小火箭 / Quantumult / Loon / Surge / Karing / Hiddify / v2rayA | base64 订阅（纯标准链接，识别率最高） |
| Clash Verge / mihomo / Stash | YAML 配置（完整可直接用） |
| Sing-box（SFI / SFA / SFM） | JSON 配置 |

**没被识别出来的客户端**？用**通用订阅 URL**（订阅服务面板里会显示）：

```
http://<服务器IP>:8088/sub/<token>/std
```

它**不看 UA**，固定返回纯标准链接，任何客户端都能导入。

> 这份纯标准链接里**不含 `http2` / `http3`**（Xray 系客户端会判格式错误）。这两个协议请用 **sing-box JSON** 或 **Clash YAML** 导入。

### Clash 订阅带分流规则（七组）

Clash / mihomo 拿到的**不只是节点**，而是一份能直接用的分流配置：

| 代理组 | 走什么 |
|---|---|
| 🔰 节点选择 | 手动挑节点（AI / GitHub / Steam 默认走这里） |
| ♻️ 自动选择 | 延迟测速自动选，排在节点选择第一位 |
| 🎯 全球直连 | 国内网站 / Apple / 微软 / iCloud |
| 🛑 全球拦截 | 广告 / 追踪器 / 域名劫持 |
| 🌍 国外媒体 | Netflix / YouTube / Disney+ / TikTok |
| 🌏 国内媒体 | Bilibili / 腾讯视频 / 爱奇艺 |
| 📲 电报信息 | Telegram |
| 🐟 漏网之鱼 | 兜底 |

规则集（OpenAI / Claude / GitHub / 流媒体 / 广告拦截…共 31 个）走 **jsDelivr CDN**，客户端首次导入会下载几十个小文件，几秒钟完事。

> **连不上 CDN 或只想立刻能用？** 主菜单 **7（客户端设置）→ 7** 切到「精简分流」——只用内核自带的 GEOSITE / GEOIP，一个字节都不用下载。

### 想要一个文件而不是一个地址：直接下载 Clash 配置

**主菜单 10 → 3（查看 / 复制 Clash 配置）→ 3（下载）**。三条路任选：

| 方式 | 怎么做 | 适合 |
|---|---|---|
| 浏览器下载 | 打开 `http://<IP>:8088/sub/<token>/clash` | 电脑 / 手机浏览器，点开就下载 `clash.yaml` |
| scp 拉文件 | `scp root@<IP>:/路径/clash.yaml .` | 订阅服务没开、或端口连不上 |
| 本机复制 | `cp <路径>/clash.yaml ~/clash.yaml` | 就在服务器上操作 |

`/sub/<token>/clash` 这个地址**不看 UA**，浏览器打开会以**附件**形式下载（不会在页面里摊开一大段 YAML）。订阅服务没开时这条地址打不开，用 scp 那条。

> ⚠️ **本地文件不会自动更新**。以后加了节点、改了分流，得重新下载一次。想让它自己跟着变，就用上面的「订阅地址」填进客户端，客户端会定时拉取。

### 手机导入最省事：扫码

**主菜单 10 → 7（订阅链接二维码）** 或 **订阅服务面板第 4 项**，把订阅 URL 显示成二维码，手机扫一下直接导入，不用手打地址。

### 不开启订阅服务也能用

「10. 订阅与节点链接」里仍有一键复制链接、二维码、Clash 配置、v2rayN 订阅、小火箭订阅、sing-box 配置。

### 后端：nginx（推荐）或 Python（回退）

**绝不自动替你装 nginx。** 首次启动会让你选一个；选 nginx 但本机没装时，脚本会**先问过你（y/N）才安装**。

- **nginx**：更省资源，UA 分流 / 令牌鉴权 / IP 白名单全部原生完成。站点配置目录按发行版现场探测（Debian→`conf.d`，Alpine→`http.d`），写完还会实测 `nginx -t` 自检纠位。
- **Python**：不想装 nginx 时用，功能完全一致，占用略高。

想换方式？订阅服务菜单里有「切换实现方式」，会自动重启用并清掉旧方案残留。

---

## ⚠️ 客户端连不上？先看「入站 IP」

绝大多数情况什么都不用设。但下面这些场景里，**客户端能连到的地址 ≠ 本机探测到的出站 IP**：

- VPS 是 **NAT / 共享公网 IP**（Hax、LXC、容器、部分廉价 VPS）
- 前面挂了**中转 / 隧道**
- 端口被服务商**映射**过

这时按出站 IP 导出的链接**一条都连不上**，而面板看不出问题。

**解决：主菜单 6（入站 IP / 端口映射）** —— 已从「客户端设置」里提出来单独成项。

## Argo 隧道：NAT 机器没有公网入口时

上面那招解决的是「地址填错了」，但有一种情况它救不了：**根本没有可连的入口**。

- 服务商只给你内网 IP，公网端口要额外买
- 端口全被封，只有 80 / 443 能出去
- 共享 IP，别人把你的端口占满了

这时候用 **Argo（Cloudflare 隧道）**：让流量绕道 Cloudflare。

```
客户端 --wss/443--> Cloudflare 边缘 --隧道--> cloudflared --明文HTTP--> sing-box(127.0.0.1)
```

**关键点：本机不需要开放任何端口，也不需要公网 IP 和域名。** cloudflared 是**主动往外连** Cloudflare 的（出站 TCP，NAT 机器天生允许），CF 再把请求送回来。所以 NAT 机器不但能用，还正是它最适合的场景。

> **本机不需要 443。** 客户端连的那个 `:443` 是 **Cloudflare 的** 443，不是你的机器。你的机器只负责「出站连 CF」这一件事，监听的是 `127.0.0.1:20007` 这种只有本机能访问的高位端口。
>
> 万一连**出站 443** 都被机房封了，菜单第 5 项可以把传输协议切成 `quic`（改走出站 UDP 7844）。部署时如果 30 秒拿不到域名，脚本也会**自动**帮你切一次。

入口：**主菜单 1（节点部署）→ 最后一项「Argo 隧道」**

| 模式 | 域名 | 适合 |
|---|---|---|
| **临时隧道** | CF 随机分配 `xxx.trycloudflare.com` | 先用起来、没有域名。**注意：每次重启域名都会变**，变了用菜单第 3 项「换临时隧道域名」 |
| **Token 隧道** | 你自己在 CF 绑定的域名 | 长期用。域名固定、重启不变 |

几个必须知道的限制：

- **只有 ws 类协议能套**（VLESS / VMess + WS）。Hysteria2 / TUIC 这些 UDP 协议走不了 Argo —— 隧道只转 TCP/HTTP。
- 首次使用会问你要不要下载 **cloudflared**（Cloudflare 官方客户端，约 20MB），装到脚本自己的目录，不动系统包管理器。
- Argo 节点**不用跳过证书验证**：CF 边缘是正规证书，正常校验就行（这跟自签证书的节点不一样）。
- 临时隧道的 `*.trycloudflare.com` 在部分网络下会被干扰，长期用建议换 Token 模式绑自己的域名。

```
1. 设置入站（客户端连接）IP        比如 13.26.52.13
2. 设置端口映射起始端口            比如 30000（本机 20000 → 客户端 30000）
3. 清空全部设置
```

设置后所有**链接 / 二维码 / 订阅**立刻改用你填的地址，例如：

```
anytls://xxxx@125.24.53.19:20000  →  anytls://xxxx@13.26.52.13:30000
```

**本机监听端口一个都不变**（config.json / nodes.json 原样），只是导出时换地址，随时可改可清空。两个值都留空时输出与设置前**完全一致**。

> **怎么确认自己是这种情况？** 在**另一台**机器上 `curl -s ifconfig.me`，得到的是你**看到**的公网 IP。与面板显示的「本机出站 IP」比对，不一致就是 NAT / 映射。

---

## 证书放行：为什么有的节点要手动开「跳过证书验证」

脚本用的是**自签证书**（CN = 服务器 IP），客户端默认不信任，必须被告知放行。问题在于——**「放行」这三种写法互不兼容**，而一条链接只能带一种：

| 写法 | 谁认 |
|---|---|
| `pcs=<证书指纹>` | Xray / v2rayN 系（新版 Xray 唯一的官方写法） |
| `insecure=1` | sing-box 系（Hiddify / NekoBox / Karing） |
| `allowInsecure=1` | 通用 / 小火箭（Shadowrocket） |

所以物理上**做不到「所有客户端一个参数全搞定」**，只能各客户端出口各配一套。

**默认的「自动」策略已经替你把这件事做了** —— 正常情况下导入后**直接能用，不用手动开任何开关**。

- 通用 / 标准链接出口 → 带 `allowInsecure=1&insecure=1`（小火箭、Hiddify 等直接认）
- v2rayN 出口 → 带 `pcs`（**不能**给 v2rayN 发 `allowInsecure`，新版 Xray 会**直接拒绝启动**）
- Clash / mihomo 出口 → 用证书指纹校验（比"跳过"更安全）

想自己控制？**主菜单 7（客户端设置）→ 6（证书放行策略）**：

```
1. 自动（推荐）  各客户端开箱即用        ← 默认
2. 指纹钉死 pcs  最安全；只用 v2rayN 时选它（小火箭需自己开）
3. 统一跳过校验  最省事；只用小火箭/sing-box 系时选它（v2rayN 会启动失败）
```

> 只改导出时内嵌的参数，**服务端配置不变**。改完客户端**重新拉一次订阅**即可生效。

---

## 常见问题

**Q：拉取订阅一直转圈，最后超时？**
最常见是**端口没放行**（表现是"等到超时"而不是"秒速拒绝"）：
```bash
ufw allow 8088/tcp
# 云服务器还要在控制台「安全组」放行
```
其次是服务没启动（主菜单应显示 `● 运行中`），或没有节点（服务端返回 503）。

**Q：`nginx -t` 通过了，订阅还是无法访问？**
`nginx -t` 通过只代表**语法合法**，不代表**我们的站点在跑**。按顺序查：
1. 订阅服务面板有没有报警「订阅站点配置缺失」→ 有就选 **1「启动 / 刷新订阅服务」** 重写
2. `pgrep -a nginx` 看进程在不在
3. `ss -lntp | grep 8088` 看端口有没有人听
4. `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8088/sub/<token>` → 200 才算通

**Q：小火箭导入后只认出部分节点？**
v2rayN 的 `v2rayn://` 是私有格式，只有 v2rayN 认。脚本对小火箭按 UA 单独返回纯标准链接。升级后**重启一次订阅服务**（主菜单 11 → 1）即可。

**Q：Xray 客户端导入后启动失败，提示 `allowInsecure` 被移除？**
新版 Xray 移除了 `allowInsecure`。脚本对 Xray 系协议改用 `pcs=<证书指纹>`，对 sing-box 专属协议保留 `insecure=1`，两边都能直接用。

**Q：为什么有的客户端导入后还要我自己去开「跳过证书验证 / 允许不安全」？**
不是脚本漏了——客户端世界**没有统一的"跳过校验"参数**（详见上文「证书放行」）。默认的**「自动」策略**已替大多数客户端配好，**正常情况下不用手动开**。换了客户端生态想自己调：**主菜单 7 → 6（证书放行策略）**。

**Q：v2rayN 导入 Hysteria2 / TUIC 报错？**
标准链接不携带内核信息，v2rayN 默认用 Xray。脚本对 sing-box 专属协议（Hysteria2 系 / TUIC / AnyTLS / NaiveProxy / ShadowTLS / HTTP2 / HTTP3）导出 `v2rayn://` 私有格式，显式锁定 sing-box 内核，导入后自动切换。

**Q：Alpine 上升级内核后服务起不来，报 `cannot execute: required file not found`？**
Alpine 是 musl，需用 `-musl` 构建。脚本会按本机 libc 自动选对变体，并在安装前实测二进制能否运行，绝不会顶掉正在工作的内核。旧版请先 `sb update`。

**Q：`bash <(curl ...)` 安装后 `sb` 找不到 menu.sh？**
`bash <(curl URL)` 时脚本 `$0` 是管道，读不到自己。改用「先下载再运行」更稳：
```bash
curl -fsSL <URL> -o sing-box.sh && bash sing-box.sh
```

**Q：菜单里的版本号显示成 `22.04.5 LTS (Jammy Jellyfish)`？**
早期版本被 `/etc/os-release` 覆盖了 VERSION 变量，已修。

**Q：Alpine 上 SNI 优选显示 `0 ms`？**
BusyBox 的 `date` 不支持 `%N`。已改用三级回退，`sb update` 升级即可。

---

## 目录与文件

| 路径 | 说明 |
|---|---|
| `/usr/local/bin/sb` | 管理命令入口 |
| `/usr/local/bin/sing-box` | sing-box 内核 |
| `/usr/local/share/singbox-nat/config.json` | sing-box 运行配置 |
| `/usr/local/share/singbox-nat/nodes.json` | 节点列表 |
| `/usr/local/share/singbox-nat/cert/` | 自签证书 |
| `/usr/local/share/singbox-nat/settings.env` | 管理器设置 |
| `/etc/systemd/system/sing-box.service` | 服务单元（openrc 则为 `/etc/init.d/sing-box`） |
| `/etc/nginx/http.d/singbox-nat-sub.conf` | 订阅站点配置（Alpine） |
| `/etc/nginx/conf.d/singbox-nat-sub.conf` | 订阅站点配置（Debian 系） |

---

## 卸载

- **只卸订阅后端**：主菜单 **11 → 10. 卸载订阅后端**
- **整机完全卸载**：主菜单 **15**，输入 `DELETE` 确认。会询问是否连同卸载 nginx 包（默认不卸，因为你可能还有别的站点在用）。

**Argo / cloudflared 会怎样？**

| 项目 | 卸载时 |
|---|---|
| Argo 隧道服务 | **会停掉**，并摘除开机自启（systemd 单元 / OpenRC 脚本 / pidfile） |
| cloudflared 在脚本目录（脚本自己下载的） | **直接删除**，不问你 |
| cloudflared 在系统路径（包管理器装的 / 你手动下的） | **会问你要不要一并卸载**，默认 N |

系统路径那份为什么还要问：它可能是 `apt install cloudflared` 装的，也可能别的项目在用。选了 Y 之后：

- 包管理器装的 → 走包管理器卸包（`apt purge` / `apk del` / `dnf remove` …），安装记录一起清掉
- 手动下载的散装文件 → 直接删二进制，连软链一起清

卸载确认屏会**当场告诉你是哪一种**，不用猜。卸完还会实测 `command -v cloudflared`，没清干净就把包管理器日志尾巴打出来。

> 卸载 nginx 会移除**整个** nginx（含你自建的其它站点），脚本会明确警告。

---

## 兼容性

- **系统**：Debian / Ubuntu / CentOS / Rocky / AlmaLinux / Fedora / Alpine / Arch
- **init**：systemd、openrc、无 init 手动进程
- **架构**：x86_64 / arm64 等，自动检测
- **libc**：glibc 与 musl 都自动下载对应 sing-box 构建
- **依赖**：`jq`、`curl`（缺失时脚本会尝试安装）
- **不依赖 GNU 扩展**：BusyBox 环境（Alpine / OpenWrt）可正常使用
- **轻量**：探测类操作跑完即收，不留后台进程

---

## 更新日志

### V3.9.11（当前版本）
- **SNI 优选里的测速站全换成国外的**：原来那 4 个国内测速站（`m.speedtest.cn` / `test.nju.edu.cn` / `test.ustc.edu.cn` / `www.speedtest.cn`）全部移除，换成**国外 + 大陆可直连**的 4 个
  - `speed.cloudflare.com`（约 0.29s）、`www.speedtest.net`（约 0.46s）、`www.ookla.com`（约 0.68s）、`testmy.net`（约 0.78s）
  - 为什么要换：客户端在国内、VPS 在海外，SNI 指向国外站点才和「访问国外网站」的流量特征一致；指向国内站点反而让握手目标和实际出口对不上，更可疑
  - 四个都落在 Cloudflare / Fastly 这类全球 CDN 上，国内可直连；**没有单机托管的小站**（`librespeed.org` 在德国 Hetzner 单机，国内慢，没加）
  - `fast.com` 是 Netflix 的，国内打不开；`speedof.me` 连 TLS 握手都失败 —— 都没加
  - 除 `speed.cloudflare.com` 外都支持 h2（ALPN 实测）；做 Reality 且在意 h2 指纹就避开它

### V3.9.10
- **cloudflared 现在真的能卸干净了**：系统路径下那份不再「只停服务、留着程序」，改成**问你要不要一并卸载**（默认 N）
  - 包管理器装的 → 走包管理器卸包，安装记录一起清（`apt purge` / `apk del` / `dnf remove` / `pacman -R` / `zypper remove`）
  - 手动下载的散装文件 → 直接删二进制 + 清软链
  - 为什么要先判断来源：直接 `rm` 掉包管理器管的文件，会留下「文件没了、包还在」的坏状态，之后 `apt` 一操作就报 `files list file ... missing`
  - 卸完实测 `command -v cloudflared`，没清干净就把日志尾巴打出来
- 卸载确认屏文案同步改成「稍后会问你要不要一并卸载」

### V3.9.9
- **Argo 状态行显示内存 / CPU**：和「订阅服务」那一行同格式（`内存 32M  CPU 0.0%`），带 5 秒缓存不拖慢菜单
  - cloudflared 是 Go 写的，常驻 20~40M 属正常，别拿它跟 sing-box 比大小
- **卸载确认屏把 Argo 说清楚了**：原来只写「配置、节点、订阅…」，用户不知道 Argo 会不会被带走
  - 现在会明说「Argo 隧道服务会停掉、摘除自启」，并**当场判断** cloudflared 是脚本下载的（一并删）还是系统原有的（只停服务、保留程序）

### V3.9.8
- **Argo 隧道提升为主菜单第 12 项**（原来只挂在「1. 节点部署 → 最后一项」）
  - 原因很直接：部署只是第一步，之后还要看隧道跑没跑、临时域名变了要换、出站 443 被封要切 quic、不要了要停服务 —— 这些都在 Argo 自己的菜单里，藏在协议列表末尾等于「装完就找不到」
  - 两个入口都保留：主菜单 12 管服务，节点部署末项管装机
- **主菜单新增 Argo 隧道状态行**：只在你有 Argo 节点时才显示，`● 运行中` / `● 已停止` 一目了然
  - 之前最怕的情况：节点还在订阅里、隧道却悄悄挂了 —— 客户端一条都连不通，面板上完全看不出来
- **Clash 配置可以直接下载成文件**：`/sub/<token>/clash`，浏览器点开即以附件下载 `clash.yaml`
  - 这条路由**不看 UA**（浏览器 UA 不是 clash，按 UA 分流只会拿到一段 base64）
  - 菜单里同时给出 scp 命令和本机路径，订阅服务没开也能拿文件
- ⚠️ **修掉一个致命 bug**：「停止 / 移除 Argo 服务」的 systemd 分支在调用自己 —— 无限递归，一点就 fork 到进程表爆掉
- 「移除 Argo 服务」不再写死 `systemctl`，三种托管统一走 `argo_svc_remove`（原来 Alpine 上等于没删）
- 服务管理器探测补上 `/sbin/rc-service`、`/usr/sbin/rc-service` 两个绝对路径 —— 精简系统 PATH 里没有 `/sbin` 时会误判成「无 init」
- `systemctl` 存在但 systemd 不是 PID 1（容器 / chroot）时，Argo 自动退回后台进程运行，不再直接报「启动失败」

### V3.9.7
- **Argo 支持 OpenRC / 无 init 系统**：不再写死 systemd。Alpine、以及没有 init 的精简系统也能托管 cloudflared
  - 自动按系统分派：systemd 单元 / OpenRC 服务脚本 / 直接 `setsid` 后台跑
  - 「Argo 隧道」面板新增一行「服务托管」，直接显示当前用的是哪种
- **SNI 优选候选加入中国大陆测速站**：`m.speedtest.cn`（约 0.17s，最快）、`test.nju.edu.cn`（约 0.34s）、`test.ustc.edu.cn`（约 0.66s）、`www.speedtest.cn`（约 1.90s）
  - 实测了 17 个大陆测速域名，只有这 4 个握手成功；浙大 / 上交 / 清华 / 北大 / 华科 / 腾讯 / 阿里等 13 个都连不上，**没有加进去**（加了只会让优选变慢）
  - 裸域 `speedtest.cn` 没开 TLS，不能用作 SNI
  - ⚠️ **这一组已在 V3.9.11 全部移除**，换成国外可直连的测速站（见 V3.9.11）

### V3.9.5
- **Argo 传输协议可选**（菜单第 5 项）：`http2`（出站 TCP 443，默认）/ `quic`（出站 UDP 7844）
- 部署时若 30 秒拿不到域名（或 Token 隧道 20 秒未注册成功），**自动从 http2 兜底切到 quic** 再试一次
- Token 隧道新增**连通性判定**：不只看服务是否在跑，还要在日志里等到 `Registered tunnel connection` —— 否则「服务活着但没连上」会骗过用户
- 文档补一句最容易误会的话：**本机不需要 443**，那个 443 是 Cloudflare 的

### V3.9.4
- 新增 **Argo 隧道**（主菜单 1 节点部署 → 最后一项）：NAT / 共享 IP / 端口被封时，本机**不开放任何端口**也能用
  - **临时隧道**：CF 随机分配 `xxx.trycloudflare.com`，免域名；重启后域名会变，菜单里有「换临时隧道域名」一键更新
  - **Token 隧道**：绑定自己的域名，域名固定、重启不变
  - 首次使用会问你要不要下载 cloudflared（约 20MB），装到脚本自己目录
- 新节点类型 `vless-ws-argo`：inbound 只听 `127.0.0.1`、**不开 TLS**（TLS 由 CF 边缘终结），导出时 server 换成隧道域名、端口换成 443
- Argo 节点**不套自签证书那套** pcs / allowInsecure —— CF 是正规证书，带上自己的指纹反而连不上
- 只有 ws 类协议能套 Argo；Hysteria2 / TUIC 等 UDP 协议走不了（隧道只转 TCP/HTTP）

### V3.9.3
- **Clash 订阅带分流规则**：从「只有节点 + 几条 GEOSITE」升级为 ACL4SSR 那套**七组布局**——节点选择 / 自动选择 / 全球直连 / 全球拦截 / 国外媒体 / 国内媒体 / 电报信息 / 漏网之鱼
- **31 个规则集**（rule-providers）：ChatGPT、Claude、GitHub、Netflix、YouTube、Disney+、Spotify、TikTok、Bilibili、腾讯、阿里、Steam、Telegram、Apple、iCloud、微软、广告 / 隐私 / 域名劫持拦截、国内域名与网段…
- 规则集走 **jsDelivr CDN** 而不是 `raw.githubusercontent.com`——客户端首次导入时还没连上代理，raw 域名在境内基本不可达，规则集会全军覆没
- 新增**分流模式开关**（主菜单 7 → 7）：`完整分流`（七组 + 远程规则集）/ `精简分流`（只用内核自带 GEOSITE/GEOIP，不下载任何东西）
- 没节点时也生成合法配置（`proxies: []` + 全直连），不会导入报错

### V3.9.2
- **入站 IP / 端口映射提升为「主菜单第 6 项」**（原来藏在「客户端设置」里）——这是「节点部署完却连不上」的头号根因，不该埋两层菜单
- 新增**证书放行策略**（主菜单 7 → 6）：`自动` / `指纹钉死 pcs` / `统一跳过校验` 三选一。**默认「自动」已替各客户端配好，正常情况下不用手动开「跳过证书验证」**
- 「入站 IP」面板补充「不改也能用」「怎么知道自己该填什么（看服务商面板哪一栏）」；改完会提示客户端重新拉订阅
- 主菜单 14 项 → 15 项

### V3.9.1
- **入站 IP / 端口映射**：NAT VPS / 前面挂中转 / 端口被服务商映射过时，把导出的链接地址换成客户端**真正能连**的 IP，端口按偏移量映射。本机监听一个字节不动，随时可改可清空
- **订阅链接二维码**：订阅 URL 直接渲染成二维码，手机扫一下导入，不用手打地址

### V3.8 / V3.7 / V3.6
- **V3.8**：修「`nginx -t` 明明通过，订阅却无法访问」——清理旧配置时只删不写，可能留下「语法合法但一个站点都没有」的空状态。现在面板会检测到配置缺失并提示一键重写
- **V3.7**：日志里几分钟前的旧 `[emerg]` 紧跟着一句「校验：通过」会把人唬住。现在明确标注**「这是历史记录，不是当前状态」**
- **V3.6**：「订阅服务」提升为主菜单单列一项，启停 / 后端 / 日志 / 令牌 / IP 白名单一屏可及

### V3.4 / V3.5
- **V3.5**：`http2` / `http3` 的分享链接带 path + query，Xray 系客户端会报「格式错误的 http 链接」，**一条坏链接就可能让整份订阅导入失败**。现在纯标准链接订阅自动跳过这两条，改由 sing-box JSON / Clash YAML 承载
- **V3.4**：新增**通用订阅** `/sub/<token>/std`，**不看 UA**、固定返回纯标准链接，给 UA 猜不准的客户端兜底（v2rayA 等）

### 更早（V1.8 – V3.3）
以 **NAT VPS / Alpine / BusyBox 兼容**和稳定性为主：
- BusyBox 的 `date +%N` **静默失效**（不报错、退出码 0）→ 改三级回退，否则 SNI 永远是 `0 ms`
- 自实现 `run_with_timeout` 硬超时：`getaddrinfo()` 是同步阻塞调用，curl 的 `--connect-timeout` 管不了它
- sing-box 内核按 libc 自动选 `-glibc` / `-musl` 变体，且**装前先实测二进制能否运行**，绝不顶掉正在工作的内核
- Alpine 的 nginx 站点配置写对目录（`http.d` 而非主上下文的 `conf.d`），写完还自检纠位，**绝不留下让整台 nginx 起不来的配置**
- `v2rayn://` 私有格式帮 v2rayN 锁定 sing-box 内核；小火箭单独发纯标准链接订阅
- Clash 订阅改回合法 YAML 块序列；jq 保留字 `label` 改名 `proto_label`
