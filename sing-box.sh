#!/bin/sh

if [ -z "${BASH_VERSION:-}" ]; then
    _sb_bash=""
    for _c in /bin/bash /usr/bin/bash /usr/local/bin/bash /opt/homebrew/bin/bash /bin/sh; do
        [ -x "$_c" ] && { _sb_bash="$_c"; break; }
    done
    case "$_sb_bash" in
        *bash) : ;;
        *) echo "错误：未找到 bash，本脚本需要 bash 运行（请先安装：apt install bash / apk add bash）" >&2; exit 1 ;;
    esac
    _sb_self="$0"
    if [ -r "$_sb_self" ] && [ "$(tr -cd '\r' < "$_sb_self" 2>/dev/null | wc -c)" -gt 0 ] 2>/dev/null; then
        if tr -d '\r' < "$_sb_self" > "${_sb_self}.lf.tmp" 2>/dev/null; then
            cat "${_sb_self}.lf.tmp" > "$_sb_self" 2>/dev/null || true
            chmod 0755 "$_sb_self" 2>/dev/null || true
            rm -f "${_sb_self}.lf.tmp" 2>/dev/null
            printf '\033[33m⚠ 检测到 CRLF 行尾，已自动转换为 LF\033[0m\n'
        fi
    fi
    _sb_target="$_sb_self"
    case "$_sb_target" in
        /*) : ;;
        */*) _sb_target="$(cd "$(dirname "$_sb_target")" 2>/dev/null && pwd)/$(basename "$_sb_target")" ;;
        *)   _sb_target="$(pwd)/$_sb_target" ;;
    esac
    if [ ! -r "$_sb_target" ]; then
        echo "错误：无法重新以 bash 运行本脚本（\$0=$_sb_self）。" >&2
        echo "请改用：bash ./脚本名  或  bash <(curl -Ls ...)  执行。" >&2
        exit 1
    fi
    exec "$_sb_bash" "$_sb_target" "$@" || {
        echo "错误：无法切换到 bash 执行（exec $_sb_bash 失败）。" >&2
        echo "请手动执行：$_sb_bash \"$_sb_target\"" >&2
        exit 1
    }
fi
if [ -z "${BASH_VERSION:-}" ]; then
    echo "错误：本脚本需要 bash 运行，当前解释器不支持。" >&2
    exit 1
fi

set -u
if [ -n "${BASH_VERSION:-}" ]; then
    set -o pipefail
fi
export LANG=C.UTF-8 LC_ALL=C.UTF-8

_self_fix_crlf(){
    local self="$1"
    [ -f "$self" ] || return 0
    [ "$(tr -cd '\r' < "$self" 2>/dev/null | wc -c)" -gt 0 ] 2>/dev/null || return 0
    if tr -d '\r' < "$self" > "${self}.lf.tmp" 2>/dev/null && [ -s "${self}.lf.tmp" ]; then
        cat "${self}.lf.tmp" > "$self" 2>/dev/null && chmod 0755 "$self" 2>/dev/null
        rm -f "${self}.lf.tmp"
        printf '\033[33m⚠ 检测到 CRLF 行尾，已自动转换为 LF：%s\033[0m\n' "$self"
    else
        rm -f "${self}.lf.tmp" 2>/dev/null
    fi
}

PUB4=""; PUB6=""; LOCAL4=""; SERVER_IP="127.0.0.1"
NAT_HINT="未检测"; UDP_HINT="未检测"
UDP_OK="1"; UDP_CHECKED=0
COUNTRY_CODE=""; COUNTRY_NAME=""
OS="unknown"; VER=""; ARCH=""; INIT="none"
REALITY_PRIVATE=""; REALITY_PUBLIC=""
BATCH_MODE=0; SB_RUN_MENU=0
BATCH_RESERVE=16
CURRENT_SNAPSHOT=""; FINGERPRINT="chrome"; UOT_ENABLED="0"
PREFERRED_SNI=""; SNI_OPTIMIZED=""
NODE_NAME_PREFIX=""
SINGBOX_CHANNEL="any"
DEFAULT_NEWEST_VERSION="1.15.0-alpha.9"
SINGBOX_WANT_VERSION=""

APP="singbox-nat"
VERSION="V3.2"
BASE="/usr/local/share/${APP}"
BIN="/usr/local/bin/sing-box"
SB="/usr/local/bin/sb"
CONF="${BASE}/config.json"
NODES="${BASE}/nodes.json"
SETTINGS="${BASE}/settings.env"
CERTDIR="${BASE}/cert"
SUBDIR="${BASE}/subscription"
BACKUP="${BASE}/backup"
LOGDIR="${BASE}/logs"
VERSION_FILE="${BASE}/version"
SUBHTTP_PY="${BASE}/subserver.py"
SUBHTTP_TOKEN="${BASE}/.sub_token"
SUBHTTP_PORT="${BASE}/.sub_port"
SUBHTTP_SVC="singbox-nat-sub"
NGINX_SITE_NAME="singbox-nat-sub.conf"
NGINX_CONF=""
NGINX_CONF_LEGACY="/etc/nginx/conf.d/${NGINX_SITE_NAME}"
MENU="${BASE}/menu.sh"

UPDATE_URL="https://raw.githubusercontent.com/87954621/SingBox/refs/heads/main/sing-box.sh"
UPDATE_REPO="https://github.com/87954621/SingBox"

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
CYAN=$'\033[36m'; BLUE=$'\033[34m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
DIM=$'\033[2m'; MAGENTA=$'\033[35m'; INVERT=$'\033[7m'

mkdir -p "$BASE" "$CERTDIR" "$SUBDIR" "$BACKUP" "$LOGDIR"

die(){ echo "${RED}错误：$*${RESET}"; exit 1; }
ok(){ echo "${GREEN}✓ $*${RESET}"; }
warn(){ echo "${YELLOW}⚠ $*${RESET}"; }
info(){ echo "${CYAN}→ $*${RESET}"; }
pause(){ read -r -p "按 Enter 返回..." _ || true; }

panel(){
    local text="$1" show_ver="${2:-ver}"
    local tw=0 i ch
    for ((i=0; i<${#text}; i++)); do
        ch="${text:i:1}"
        case "$ch" in
            [!\ -~]) tw=$((tw+2)) ;;
            *)       tw=$((tw+1)) ;;
        esac
    done
    local tag="" tagw=0
    if [ "$show_ver" = "ver" ] && [ -n "$VERSION" ]; then
        tag="脚本编号 $VERSION"
        for ((i=0; i<${#tag}; i++)); do
            ch="${tag:i:1}"
            case "$ch" in
                [!\ -~]) tagw=$((tagw+2)) ;;
                *)       tagw=$((tagw+1)) ;;
            esac
        done
        [ $(( 2 + tw + tagw + 2 )) -gt 50 ] && { tag=""; tagw=0; }
    fi
    local fill=$(( 50 - 2 - tw - tagw - 2 ))
    [ "$fill" -lt 0 ] && fill=0
    if [ -n "$tag" ]; then
        printf '\n%s  %s%*s%s  %s\n%s\n' \
            "$INVERT$BOLD" "$text" "$fill" "" "$tag" "$RESET" "$RESET"
    else
        printf '\n%s  %s%*s%s\n%s\n' \
            "$INVERT$BOLD" "$text" "$fill" "" "$RESET" "$RESET"
    fi
}
hr(){ printf '%s%s%s\n' "$DIM" "──────────────────────────────────────────────────" "$RESET"; }
dwidth(){
    local t="$1" w=0 i ch
    for ((i=0; i<${#t}; i++)); do
        ch="${t:i:1}"
        case "$ch" in
            [!\ -~]) w=$((w+2)) ;;
            *)       w=$((w+1)) ;;
        esac
    done
    printf '%d' "$w"
}
kv(){
    local k="$1" v="$2" color="${3:-$RESET}"
    local w pad
    w="$(dwidth "$k")"
    pad=$((10-w)); [ "$pad" -lt 0 ] && pad=0
    printf '  %s%s%s%*s %s%s%s\n' "$DIM" "$k" "$RESET" "$pad" "" "$color" "$v" "$RESET"
}
kv_dash(){
    local k="$1" v="$2" suffix="${3:-}"
    if [ -n "$v" ]; then kv "$k" "${v}${suffix}"
    else kv "$k" "${DIM}—${RESET}"; fi
}
kvf(){
    local indent="$1" k="$2" v="$3"
    local w pad
    w="$(dwidth "$k")"
    pad=$((10-w)); [ "$pad" -lt 0 ] && pad=0
    printf '%*s%s%s%s%*s %s\n' "$indent" "" "$DIM" "$k" "$RESET" "$pad" "" "$v"
}
status_dot(){
    if [ "$1" = "1" ]; then printf '%s●%s' "$GREEN" "$RESET"
    else printf '%s●%s' "$RED" "$RESET"; fi
}
status_line(){
    local alive="$1" sum="$2" ncnt="${3:-}"
    local st upt mem pid ver en cpu
    IFS='|' read -r st upt mem pid ver en cpu <<<"$sum"

    local out
    if [ "$alive" = 1 ]; then
        out="$(status_dot 1) ${GREEN}运行中${RESET}"
    else
        out="$(status_dot 0) ${RED}已停止${RESET}"
    fi

    if [ "$alive" = 1 ]; then
        [ -n "$upt" ] && out="${out}  ${DIM}已稳定 ${upt}${RESET}"
        if [ -n "$cpu" ]; then
            local cc="$DIM"
            awk "BEGIN{exit !($cpu > 50)}" 2>/dev/null && cc="$YELLOW"
            out="${out}  ${cc}CPU ${cpu}%${RESET}"
        fi
        [ -n "$mem" ] && out="${out}  ${DIM}内存 ${mem}${RESET}"
    fi

    if [ -n "$ncnt" ]; then
        if [ "$ncnt" -gt 0 ] 2>/dev/null; then
            out="${out}  ${CYAN}${ncnt} 个节点${RESET}"
        else
            out="${out}  ${YELLOW}暂无节点${RESET}"
        fi
    fi

    if [ "$INIT" = systemd ] || [ "$INIT" = openrc ]; then
        if [ -n "$en" ]; then out="${out}  ${DIM}· 开机自启${RESET}"
        else out="${out}  ${DIM}· 未设自启${RESET}"; fi
    fi
    printf '%s' "$out"
}
need_root(){ [ "$(id -u)" = 0 ] || die "请使用 root 运行"; }
attach_tty(){
    if [ -r /dev/tty ]; then
        exec </dev/tty
        return 0
    fi
    [ -t 0 ] || die "当前没有可用终端，请在 SSH/TTY 中运行"
}

progress(){
    local pct="$1" label="$2" width=42 filled empty
    filled=$((pct*width/100)); empty=$((width-filled))
    printf "\r\033[K${CYAN}["
    printf "%${filled}s" "" | tr ' ' '#'
    printf "%${empty}s" "" | tr ' ' '-'
    printf "]${RESET} %3d%% %s\n" "$pct" "$label"
}

COUNTRY_CODE=""; COUNTRY_NAME=""

detect_country(){
    COUNTRY_CODE=""; COUNTRY_NAME=""
    local json cc cn
    json="$(curl -fsS --max-time 5 https://ipinfo.io/json 2>/dev/null || true)"
    if [ -n "$json" ]; then
        cc="$(jq -r '.country // empty' <<<"$json" 2>/dev/null)"
        if [ -n "$cc" ]; then
            COUNTRY_CODE="$cc"
            COUNTRY_NAME="$(country_zh "$cc")"
            [ -n "$COUNTRY_NAME" ] || COUNTRY_NAME="$cc"
            return 0
        fi
    fi
    json="$(curl -fsS --max-time 5 'http://ip-api.com/json/?lang=zh-CN' 2>/dev/null || true)"
    if [ -n "$json" ]; then
        cn="$(jq -r '.country // empty' <<<"$json" 2>/dev/null)"
        cc="$(jq -r '.countryCode // empty' <<<"$json" 2>/dev/null)"
        if [ -n "$cn" ]; then
            COUNTRY_CODE="$cc"; COUNTRY_NAME="$cn"; return 0
        fi
    fi
    return 1
}

country_zh(){
    case "${1^^}" in
        US) echo "美国" ;;        HK) echo "中国香港" ;;   TW) echo "中国台湾" ;;
        JP) echo "日本" ;;        KR) echo "韩国" ;;       SG) echo "新加坡" ;;
        CN) echo "中国" ;;        DE) echo "德国" ;;       GB) echo "英国" ;;
        FR) echo "法国" ;;        NL) echo "荷兰" ;;       CA) echo "加拿大" ;;
        AU) echo "澳大利亚" ;;    RU) echo "俄罗斯" ;;     IN) echo "印度" ;;
        BR) echo "巴西" ;;        IT) echo "意大利" ;;     ES) echo "西班牙" ;;
        SE) echo "瑞典" ;;        CH) echo "瑞士" ;;       PL) echo "波兰" ;;
        TR) echo "土耳其" ;;      VN) echo "越南" ;;       TH) echo "泰国" ;;
        MY) echo "马来西亚" ;;    ID) echo "印度尼西亚" ;; PH) echo "菲律宾" ;;
        AE) echo "阿联酋" ;;      ZA) echo "南非" ;;       MX) echo "墨西哥" ;;
        AR) echo "阿根廷" ;;      IE) echo "爱尔兰" ;;     FI) echo "芬兰" ;;
        NO) echo "挪威" ;;        DK) echo "丹麦" ;;       AT) echo "奥地利" ;;
        BE) echo "比利时" ;;      CZ) echo "捷克" ;;       RO) echo "罗马尼亚" ;;
        UA) echo "乌克兰" ;;      IL) echo "以色列" ;;     NZ) echo "新西兰" ;;
        SA) echo "沙特阿拉伯" ;;  CL) echo "智利" ;;       CO) echo "哥伦比亚" ;;
        PT) echo "葡萄牙" ;;      GR) echo "希腊" ;;       HU) echo "匈牙利" ;;
        BG) echo "保加利亚" ;;    LT) echo "立陶宛" ;;     LV) echo "拉脱维亚" ;;
        EE) echo "爱沙尼亚" ;;    MD) echo "摩尔多瓦" ;;   RS) echo "塞尔维亚" ;;
        *) echo "" ;;
    esac
}

now_time(){ date '+%Y-%m-%d %H:%M:%S'; }
now_epoch(){ date '+%s'; }
now_ms(){
    local v
    v="$(date +%s%N 2>/dev/null)"
    case "$v" in
        ''|*[!0-9]*) : ;;
        *) if [ "${#v}" -ge 17 ]; then printf '%s' "$(( v / 1000000 ))"; return 0; fi ;;
    esac
    v="$(awk '{printf "%d", $1*1000}' /proc/uptime 2>/dev/null)"
    case "$v" in
        ''|*[!0-9]*) : ;;
        *) printf '%s' "$v"; return 0 ;;
    esac
    v="$(date +%s 2>/dev/null)"
    case "$v" in
        ''|*[!0-9]*) return 1 ;;
        *) printf '%s' "$(( v * 1000 ))"; return 0 ;;
    esac
}
_SB_WAITN=0
if [ "${BASH_VERSINFO[0]:-0}" -gt 4 ] 2>/dev/null; then
    _SB_WAITN=1
elif [ "${BASH_VERSINFO[0]:-0}" -eq 4 ] 2>/dev/null && [ "${BASH_VERSINFO[1]:-0}" -ge 3 ] 2>/dev/null; then
    _SB_WAITN=1
fi

run_with_timeout(){
    local secs="$1"; shift
    local pid t rc
    "$@" 2>/dev/null &
    pid=$!
    if [ "${_SB_WAITN:-0}" = "1" ]; then
        sleep "$secs" >/dev/null 2>&1 &
        t=$!
        wait -n 2>/dev/null
        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null
            wait "$pid" 2>/dev/null
            rc=124
        else
            wait "$pid" 2>/dev/null
            rc=$?
        fi
        kill -9 "$t" 2>/dev/null
        wait "$t" 2>/dev/null
    else
        (
            i=0
            while [ "$i" -lt "$secs" ]; do
                sleep 1
                i=$(( i + 1 ))
                kill -0 "$pid" 2>/dev/null || exit 0
            done
            kill -9 "$pid" 2>/dev/null
        ) >/dev/null 2>&1 &
        t=$!
        wait "$pid" 2>/dev/null
        rc=$?
        kill "$t" 2>/dev/null
        wait "$t" 2>/dev/null
    fi
    [ "$rc" -eq 137 ] && return 124
    return "$rc"
}

now_tz(){ date '+%Z'; }
uptime_human(){
    if [ -r /proc/uptime ]; then
        local s d h m
        s="$(awk '{print int($1)}' /proc/uptime)"
        d=$((s/86400)); h=$(((s%86400)/3600)); m=$(((s%3600)/60))
        [ "$d" -gt 0 ] && { printf '%d天%d小时%d分' "$d" "$h" "$m"; return; }
        [ "$h" -gt 0 ] && { printf '%d小时%d分' "$h" "$m"; return; }
        printf '%d分' "$m"
    else
        uptime 2>/dev/null | sed 's/.*up //; s/,.*load.*//'
    fi
}

detect_os(){
    OS="unknown"; VER=""
    if [ -r /etc/os-release ]; then
        OS="$(  . /etc/os-release 2>/dev/null; printf '%s' "${ID:-unknown}" )"
        VER="$( . /etc/os-release 2>/dev/null; printf '%s' "${VERSION_ID:-}" )"
    fi
    OS="${OS:-unknown}"
    case "$OS" in
        debian|ubuntu|armbian|centos|rhel|rocky|almalinux|fedora|alpine|arch|manjaro) ;;
        *) warn "未验证系统：$OS；脚本仍会尝试运行" ;;
    esac
    if command -v systemctl >/dev/null 2>&1; then INIT="systemd"
    elif command -v rc-service >/dev/null 2>&1; then INIT="openrc"
    else INIT="none"; fi
    detect_nginx_dir
    cleanup_legacy_nginx_conf
}
detect_arch(){
    case "$(uname -m)" in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l|armv7) ARCH="armv7" ;;
        armv6l) ARCH="armv6" ;;
        i386|i686) ARCH="386" ;;
        *) die "不支持 CPU 架构：$(uname -m)" ;;
    esac
}

libc_kind(){
    case "${OS:-}" in
        alpine) printf 'musl'; return 0 ;;
    esac
    if ls /lib/ld-musl-*.so.1 >/dev/null 2>&1; then printf 'musl'; return 0; fi
    if command -v ldd >/dev/null 2>&1 && ldd /bin/sh 2>&1 | grep -qi musl; then
        printf 'musl'; return 0
    fi
    if ls /lib64/ld-linux*.so.* >/dev/null 2>&1 || ls /lib/ld-linux*.so.* >/dev/null 2>&1; then
        printf 'glibc'; return 0
    fi
    printf ''
}

install_deps(){
    case "$OS" in
      debian|ubuntu|armbian)
        apt-get update -y >/dev/null 2>&1 || true
        apt-get install -y curl ca-certificates jq openssl tar gzip iproute2 procps dnsutils >/dev/null 2>&1 || true ;;
      alpine)
        apk add --no-cache curl ca-certificates jq openssl tar gzip iproute2 procps bind-tools >/dev/null 2>&1 || true ;;
      arch|manjaro)
        pacman -Sy --noconfirm curl ca-certificates jq openssl tar gzip iproute2 procps-ng bind >/dev/null 2>&1 || true ;;
      centos|rhel|rocky|almalinux|fedora)
        (dnf install -y curl ca-certificates jq openssl tar gzip iproute procps-ng bind-utils >/dev/null 2>&1) ||
        (yum install -y curl ca-certificates jq openssl tar gzip iproute procps bind-utils >/dev/null 2>&1) || true ;;
    esac
    command -v curl >/dev/null || die "curl 安装失败"
    command -v jq >/dev/null || die "jq 安装失败"
    command -v openssl >/dev/null || die "openssl 安装失败"
    command -v ss >/dev/null 2>&1 || warn "未找到 ss（iproute2），端口占用检测将不可用"
    install_qrencode
}

install_qrencode(){
    command -v qrencode >/dev/null 2>&1 && return 0
    info "安装二维码工具 qrencode ..."
    case "$OS" in
      debian|ubuntu|armbian) apt-get install -y qrencode >/dev/null 2>&1 || true ;;
      alpine)                apk add --no-cache libqrencode-tools >/dev/null 2>&1 || \
                             apk add --no-cache qrencode >/dev/null 2>&1 || true ;;
      arch|manjaro)          pacman -Sy --noconfirm qrencode >/dev/null 2>&1 || true ;;
      centos|rhel|rocky|almalinux|fedora)
                             (dnf install -y qrencode >/dev/null 2>&1) || \
                             (yum install -y qrencode >/dev/null 2>&1) || true ;;
    esac
    if command -v qrencode >/dev/null 2>&1; then
        ok "qrencode 安装成功"
    else
        warn "qrencode 安装失败，二维码功能将不可用（其余功能不受影响）"
    fi
}

get_ip(){
    if [ -n "${SERVER_IP:-}" ] && [ -n "${_IP_CACHED:-}" ]; then
        return 0
    fi
    local _ic="$BASE/.ip.cache" _now _cts="" _cv4="" _cv6=""
    _now="$(date +%s 2>/dev/null)"
    if [ -s "$_ic" ]; then
        IFS=' ' read -r _cts _cv4 _cv6 < "$_ic" 2>/dev/null || true
        if [ -n "$_cts" ] && [ -n "$_now" ] && \
           [ $(( _now - _cts )) -ge 0 ] && [ $(( _now - _cts )) -lt 300 ] && [ -n "$_cv4" -o -n "$_cv6" ]; then
            PUB4="$_cv4"; PUB6="$_cv6"
            SERVER_IP="${PUB4:-${PUB6:-}}"
            _IP_CACHED=1
            return 0
        fi
    fi
    PUB4="$(curl -4 -fsS --max-time 4 https://api.ipify.org 2>/dev/null || true)"
    PUB6=""
    if [ -z "$PUB4" ]; then
        PUB6="$(curl -6 -fsS --max-time 4 https://api64.ipify.org 2>/dev/null || true)"
    fi
    case "$PUB4" in
        *[!0-9.]*|'') PUB4="" ;;
    esac
    case "$PUB6" in
        *[!0-9a-fA-F:.]*|'') PUB6="" ;;
    esac
    SERVER_IP="${PUB4:-${PUB6:-}}"
    [ -n "$SERVER_IP" ] || SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
    [ -n "$SERVER_IP" ] || SERVER_IP="127.0.0.1"
    if [ -n "$PUB4" ] || [ -n "$PUB6" ]; then
        [ -s "$_ic" ] || { mkdir -p "$BASE" 2>/dev/null; printf '%s %s %s\n' "$_now" "$PUB4" "$PUB6" > "$_ic" 2>/dev/null || true; }
    fi
    _IP_CACHED=1
}
detect_network(){
    get_ip
    local _nc="$BASE/.net.cache" _nnow _nts="" _nudp="" _nnat="" _nl4="" _ncached=0
    _nnow="$(date +%s 2>/dev/null)"
    if [ -s "$_nc" ]; then
        IFS='|' read -r _nts _nudp _nnat _nl4 < "$_nc" 2>/dev/null || true
        if [ -n "$_nts" ] && [ -n "$_nnow" ] && \
           [ $(( _nnow - _nts )) -ge 0 ] && [ $(( _nnow - _nts )) -lt 600 ]; then
            _ncached=1
        fi
    fi
    LOCAL4="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
    if [ -n "${PUB4:-}" ] && [ -n "${LOCAL4:-}" ] && [ "$PUB4" != "$LOCAL4" ]; then
        NAT_HINT="疑似 NAT / 端口映射"
    else
        NAT_HINT="未发现明显 IPv4 NAT（仅提示）"
    fi
    if command -v ss >/dev/null 2>&1 && ss -lunH 2>/dev/null | grep -q .; then
        UDP_HINT="本机存在 UDP 监听"
    else
        UDP_HINT="暂无 UDP 监听；不能据此判断 UDP 入站是否可达"
    fi
    [ -n "$COUNTRY_NAME" ] || detect_country
    if [ "$_ncached" = 1 ]; then
        UDP_OK="$_nudp"
        [ "$UDP_OK" = "0" ] && UDP_HINT="UDP 探测未通过（缓存结果，10 分钟内）"
        return 0
    fi
    detect_udp_ok
    if [ "${UDP_CHECKED:-0}" = 1 ]; then
        [ -s "$_nc" ] || { mkdir -p "$BASE" 2>/dev/null; printf '%s|%s|%s|%s\n' "$_nnow" "$UDP_OK" "$NAT_HINT" "$LOCAL4" > "$_nc" 2>/dev/null || true; }
    fi
}

detect_udp_ok(){
    UDP_CHECKED=1

    if command -v dig >/dev/null 2>&1; then
        if dig +short +time=2 +tries=1 @1.1.1.1 example.com A 2>/dev/null | grep -q .; then
            UDP_OK=1; UDP_HINT="UDP 出站可用（DNS over UDP 探测通过）"; return 0
        fi
        UDP_OK=0; UDP_HINT="UDP 探测未通过：DNS over UDP 无响应，很可能 UDP 被限制"; return 1
    fi

    if command -v nslookup >/dev/null 2>&1; then
        if nslookup -timeout=2 example.com 1.1.1.1 >/dev/null 2>&1 || \
           nslookup -type=a -timeout=2 example.com 1.1.1.1 >/dev/null 2>&1; then
            UDP_OK=1; UDP_HINT="UDP 出站可用（DNS over UDP 探测通过）"; return 0
        fi
        UDP_OK=0; UDP_HINT="UDP 探测未通过：DNS over UDP 无响应，很可能 UDP 被限制"; return 1
    fi

    if [ -n "${BASH_VERSION:-}" ] && [ -e /dev/udp ]; then
        if run_with_timeout 4 bash -c '
            exec 3<>/dev/udp/1.1.1.1/53 || exit 1
            printf "\x12\x34\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00\x07example\x03com\x00\x00\x01\x00\x01" >&3
            IFS= read -r -n 1 -t 2 _ <&3 || exit 1
            exit 0
        ' >/dev/null 2>&1; then
            UDP_OK=1; UDP_HINT="UDP 出站可用（/dev/udp 探测收到回包）"; return 0
        fi
        UDP_OK=0; UDP_HINT="UDP 探测未通过：/dev/udp 无回包，很可能 UDP 被限制"; return 1
    fi

    UDP_OK=1; UDP_HINT="无法探测 UDP（缺少 dig/nslookup），默认按可用处理"; return 0
}

DEFAULT_TCP_START=20000
DEFAULT_UDP_START=40001
MIN_TCP=20000
MAX_TCP=40000
MIN_UDP=40001
MAX_UDP=60000
load_settings(){
    if [ -f "$SETTINGS" ]; then
        . "$SETTINGS"
    fi
    DEFAULT_TCP_START="${DEFAULT_TCP_START:-20000}"
    DEFAULT_UDP_START="${DEFAULT_UDP_START:-40001}"
    if ! valid_port "$DEFAULT_UDP_START" 2>/dev/null; then DEFAULT_UDP_START=40001; fi
    MIN_TCP="${MIN_TCP:-20000}"; MAX_TCP="${MAX_TCP:-40000}"
    MIN_UDP="${MIN_UDP:-40001}"; MAX_UDP="${MAX_UDP:-60000}"
    valid_port "$MIN_TCP" || MIN_TCP=20000; valid_port "$MAX_TCP" || MAX_TCP=40000
    valid_port "$MIN_UDP" || MIN_UDP=40001; valid_port "$MAX_UDP" || MAX_UDP=60000
    [ "$MIN_TCP" -lt "$MAX_TCP" ] || { MIN_TCP=20000; MAX_TCP=40000; }
    [ "$MIN_UDP" -lt "$MAX_UDP" ] || { MIN_UDP=40001; MAX_UDP=60000; }
    port_in_range "$DEFAULT_TCP_START" tcp || DEFAULT_TCP_START="$MIN_TCP"
    port_in_range "$DEFAULT_UDP_START" udp || DEFAULT_UDP_START="$MIN_UDP"
    FINGERPRINT="${FINGERPRINT:-chrome}"
    UOT_ENABLED="${UOT_ENABLED:-0}"
    PREFERRED_SNI="${PREFERRED_SNI:-}"
    NODE_NAME_PREFIX="${NODE_NAME_PREFIX:-}"
    case "${SINGBOX_CHANNEL:-any}" in
        stable|pre|any) : ;;
        *) SINGBOX_CHANNEL="any" ;;
    esac
    DEFAULT_NEWEST_VERSION="${DEFAULT_NEWEST_VERSION:-1.15.0-alpha.9}"
    SINGBOX_WANT_VERSION="${SINGBOX_WANT_VERSION:-}"
    SUBHTTP_ENABLED="${SUBHTTP_ENABLED:-0}"
    SUBHTTP_LISTEN="${SUBHTTP_LISTEN:-8088}"
    SUBHTTP_ALLOW_IPS="${SUBHTTP_ALLOW_IPS:-}"
    SUBHTTP_BACKEND="${SUBHTTP_BACKEND:-}"
}
save_settings(){
    cat > "$SETTINGS" <<EOF
DEFAULT_TCP_START=$DEFAULT_TCP_START
DEFAULT_UDP_START=$DEFAULT_UDP_START
MIN_TCP=$MIN_TCP
MAX_TCP=$MAX_TCP
MIN_UDP=$MIN_UDP
MAX_UDP=$MAX_UDP
FINGERPRINT=$FINGERPRINT
UOT_ENABLED=$UOT_ENABLED
PREFERRED_SNI=$PREFERRED_SNI
NODE_NAME_PREFIX=$NODE_NAME_PREFIX
SINGBOX_CHANNEL=$SINGBOX_CHANNEL
SINGBOX_WANT_VERSION=$SINGBOX_WANT_VERSION
DEFAULT_NEWEST_VERSION=$DEFAULT_NEWEST_VERSION
SUBHTTP_ENABLED=$SUBHTTP_ENABLED
SUBHTTP_LISTEN=$SUBHTTP_LISTEN
SUBHTTP_ALLOW_IPS=$SUBHTTP_ALLOW_IPS
SUBHTTP_BACKEND=$SUBHTTP_BACKEND
EOF
}
valid_port(){ [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; }
port_used(){
    local p="$1"
    if ! command -v ss >/dev/null 2>&1; then
        return 1
    fi
    ss -lntupH 2>/dev/null | awk '{print $5}' | grep -Eq "([.:])${p}$"
}
port_in_config(){
    local p="$1"
    [ -f "$CONF" ] || return 1
    local hit
    hit="$(jq -r --argjson p "$p" '[.inbounds[]? | select(.listen_port == $p)] | length' "$CONF" 2>/dev/null)"
    case "$hit" in ''|*[!0-9]*) return 1 ;; esac
    [ "$hit" -gt 0 ]
}
port_in_range(){
    local p="$1" proto="$2"
    if [ "$proto" = tcp ]; then [ "$p" -ge "$MIN_TCP" ] && [ "$p" -le "$MAX_TCP" ]
    else [ "$p" -ge "$MIN_UDP" ] && [ "$p" -le "$MAX_UDP" ]; fi
}
next_free(){
    local p="$1" proto="$2" max
    max=$([ "$proto" = tcp ] && echo "$MAX_TCP" || echo "$MAX_UDP")
    while [ "$p" -le "$max" ]; do
        if ! port_used "$p" && ! port_in_config "$p"; then
            echo "$p"; return 0
        fi
        p=$((p+1))
    done
    return 1
}
rand_free_port(){
    local proto="${1:-tcp}" reserve="${2:-16}" lo hi span i cand max
    if [ "$proto" = tcp ]; then lo="$MIN_TCP"; hi="$MAX_TCP"; else lo="$MIN_UDP"; hi="$MAX_UDP"; fi
    [ "$lo" -le "$hi" ] || return 1
    local top=$(( hi - reserve ))
    [ "$top" -lt "$lo" ] && top="$hi"
    span=$(( top - lo + 1 ))
    i=0
    while [ "$i" -lt 60 ]; do
        cand=$(( lo + RANDOM % span ))
        if ! port_used "$cand" && ! port_in_config "$cand"; then
            echo "$cand"; return 0
        fi
        i=$((i+1))
    done
    next_free "$lo" "$proto"
}
choose_port(){
    local proto="$1" def="$2" p
    if [ "${BATCH_MODE:-0}" = 1 ]; then
        local seedfile="${BASE}/.batch_seed_${proto}"
        local seed=""
        [ -s "$seedfile" ] && seed="$(cat "$seedfile" 2>/dev/null)"
        if [ -z "$seed" ]; then
            seed="$(rand_free_port "$proto" "${BATCH_RESERVE:-16}")" || {
                warn "端口范围 $MIN_TCP-$MAX_TCP / $MIN_UDP-$MAX_UDP 内没有空闲 $proto 端口"
                return 1
            }
            printf '%s\n' "$seed" > "$seedfile" 2>/dev/null
            echo "$seed"; return 0
        fi
        p="$(next_free "$seed" "$proto")" || {
            warn "端口范围 $MIN_TCP-$MAX_TCP / $MIN_UDP-$MAX_UDP 内没有空闲 $proto 端口"
            return 1
        }
        echo "$p"; return 0
    fi
    while :; do
        read -r -p "端口 [默认 $def，范围 $( [ "$proto" = tcp ] && echo "$MIN_TCP-$MAX_TCP" || echo "$MIN_UDP-$MAX_UDP" )]： " p || p=""
        p="${p:-$def}"
        valid_port "$p" || { warn "请输入 1-65535 的数字"; continue; }
        port_in_range "$p" "$proto" || { warn "端口不在当前 $proto 范围"; continue; }
        if port_used "$p"; then
            warn "端口 $p 当前已有监听，继续使用可能产生冲突"
        fi
        echo "$p"; return
    done
}
need_port(){
    local p
    p="$(choose_port "$1" "$2")" || return 1
    [ -n "$p" ] || { warn "未能分配 $1 端口"; return 1; }
    printf '%s\n' "$p"
}

uuid(){
    if [ -r /proc/sys/kernel/random/uuid ]; then
        cat /proc/sys/kernel/random/uuid
    else
        local h
        h="$(openssl rand -hex 16)" || return 1
        printf '%s-%s-4%s-a%s-%s\n' \
            "${h:0:8}" "${h:8:4}" "${h:13:3}" "${h:17:3}" "${h:20:12}"
    fi
}
rand_hex(){ openssl rand -hex "${1:-8}"; }
rand_str(){ rand_hex "${1:-8}"; }
ensure_cert(){
    if [ ! -s "$CERTDIR/server.crt" ] || [ ! -s "$CERTDIR/server.key" ]; then
        mkdir -p "$CERTDIR"
        if ! openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
              -keyout "$CERTDIR/server.key" -out "$CERTDIR/server.crt" -days 3650 \
              -subj "/CN=${SERVER_IP:-localhost}" >/dev/null 2>&1; then
            if ! openssl req -x509 -newkey rsa:2048 -nodes \
                  -keyout "$CERTDIR/server.key" -out "$CERTDIR/server.crt" -days 3650 \
                  -subj "/CN=${SERVER_IP:-localhost}" >/dev/null 2>&1; then
                warn "生成自签证书失败（$CERTDIR）；请确认已安装 openssl 且对目录有写权限"
                return 1
            fi
        fi
        chmod 600 "$CERTDIR/server.key" 2>/dev/null || true
        rm -f "$CERTDIR/.pcs.hex.cache" "$CERTDIR/.pcs.cache" "$CERTDIR/.clashfp.cache" 2>/dev/null || true
    fi
    return 0
}
reality_keys(){
    local out
    out="$("$BIN" generate reality-keypair 2>/dev/null || true)"
    REALITY_PRIVATE="$(printf '%s\n' "$out" | awk '$1=="PrivateKey:"{print $2}')"
    REALITY_PUBLIC="$(printf '%s\n' "$out" | awk '$1=="PublicKey:"{print $2}')"
    [ -n "$REALITY_PRIVATE" ] && [ -n "$REALITY_PUBLIC" ] || return 1
}
short_id(){ openssl rand -hex 4; }

SNI_CANDIDATES=(
    "www.icloud.com"
    "www.apple.com"
    "swdist.apple.com"
    "www.tesla.com"
    "www.samsung.com"
    "swscan.apple.com"
    "gateway.icloud.com"
    "mp.weixin.qq.com"
    "cloud.tencent.com"
    "www.bing.com"
    "www.cloudflare.com"
    "time.is"
)
SNI_TESTED_FILE="$BASE/sni_tested"
pick_sni_cached(){
    [ -s "$SNI_TESTED_FILE" ] && head -n1 "$SNI_TESTED_FILE" 2>/dev/null
}
probe_sni(){
    local d="$1" out ms
    command -v curl >/dev/null 2>&1 || { echo 9999; return; }
    out="$(run_with_timeout 5 curl -sS -I -o /dev/null \
            --connect-timeout 2 --max-time 3 \
            -w '%{time_appconnect}' "https://${d}/")"
    case "$out" in
        ''|0|0.0|0.000000|*[!0-9.]*) echo 9999; return ;;
    esac
    ms="$(awk -v v="$out" 'BEGIN{printf "%d", v*1000}' 2>/dev/null)"
    case "$ms" in ''|*[!0-9]*) echo 9999; return ;; esac
    echo "$ms"
}
sni_optimize(){
    panel "TLS SNI 域名优选"
    echo "  正在实测本地到各候选域名的 TLS 握手耗时（每个最多等 5 秒）..."
    echo
    command -v curl >/dev/null 2>&1 || { warn "缺少 curl，无法测速"; return 1; }
    local d ms best="" bestms=99999 line
    local results=""
    local fail_streak=0
    local _t0="$SECONDS" _budget_stop=0
    for d in "${SNI_CANDIDATES[@]}"; do
        if [ $(( SECONDS - _t0 )) -ge 30 ]; then
            echo
            warn "测速已进行 30 秒仍未测完，提前结束（本机到候选域名的网络可能异常）"
            _budget_stop=1
            break
        fi
        printf '  %-26s' "$d"
        ms="$(probe_sni "$d")"
        case "$ms" in ''|*[!0-9]*) ms=9999 ;; esac
        if [ "$ms" -ge 9999 ]; then
            printf '%s超时 / 不可达%s\n' "$DIM" "$RESET"
            fail_streak=$((fail_streak + 1))
            if [ "$fail_streak" -ge 3 ]; then
                echo
                warn "已连续 $fail_streak 个域名不可达，判定为本机 DNS 或出网异常，停止测速"
                echo "  排查建议：cat /etc/resolv.conf 看 DNS 是否可用；"
                echo "            ping -c2 1.1.1.1 看是否连外网都不通。"
                return 1
            fi
        else
            printf '%s%4d ms%s\n' "$GREEN" "$ms" "$RESET"
            fail_streak=0
            results="${results}${ms} ${d}
"
            if [ "$ms" -lt "$bestms" ]; then bestms="$ms"; best="$d"; fi
        fi
    done
    if [ -z "$best" ]; then
        if [ "$_budget_stop" = "1" ]; then
            warn "本次没测出可用结果，沿用现有默认 SNI"
        else
            warn "全部候选域名均不可达（本机可能无法直连 443，或 DNS 异常）"
        fi
        echo "  排查建议：cat /etc/resolv.conf 看 DNS 是否可用；"
        echo "            ping -c2 1.1.1.1 看是否连外网都不通。"
        return 1
    fi
    echo
    hr
    echo "  按耗时排序（最快的在最上面）："
    printf '%s' "$results" | sort -n | while read -r m h; do
        [ -n "$h" ] || continue
        printf '    %s%4d ms%s  %s\n' "$DIM" "$m" "$RESET" "$h"
    done
    hr
    printf '  推荐 SNI：%s%s%s  （%d ms）\n' "$GREEN$BOLD" "$best" "$RESET" "$bestms"
    printf '%s\n' "$best" > "$SNI_TESTED_FILE"
    SNI_OPTIMIZED="$best"
    if [ -f "$SETTINGS" ]; then
        if grep -q '^PREFERRED_SNI=' "$SETTINGS" 2>/dev/null; then
            sed -i "s|^PREFERRED_SNI=.*|PREFERRED_SNI=${best}|" "$SETTINGS"
        else
            printf 'PREFERRED_SNI=%s\n' "$best" >>"$SETTINGS"
        fi
    fi
    ok "已记住该域名，后续新建节点将默认使用它"
    return 0
}
sni_default(){
    local s=""
    [ -n "${SNI_OPTIMIZED:-}" ] && s="$SNI_OPTIMIZED"
    [ -n "$s" ] || s="$(pick_sni_cached)"
    [ -n "$s" ] || s="${PREFERRED_SNI:-}"
    printf '%s' "${s:-www.apple.com}"
}
SNI_TTL_SEC="${SNI_TTL_SEC:-0}"

sni_cache_fresh(){
    local f="$SNI_TESTED_FILE"
    [ -s "$f" ] || return 1
    [ "${SNI_TTL_SEC:-0}" = "0" ] && return 1
    local now mt age
    now="$(date +%s 2>/dev/null)" || return 1
    mt="$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null)" || return 1
    [ -n "$mt" ] || return 1
    age=$(( now - mt ))
    [ "$age" -lt "${SNI_TTL_SEC:-0}" ]
}

sni_maybe_optimize(){
    if [ "${BATCH_MODE:-0}" = "1" ] && [ -n "${SNI_OPTIMIZED:-}" ]; then
        return 0
    fi
    if [ -n "${SNI_OPTIMIZED:-}" ] && sni_cache_fresh; then
        return 0
    fi
    if sni_cache_fresh; then
        SNI_OPTIMIZED="$(pick_sni_cached)"
        return 0
    fi
    if [ "${BATCH_MODE:-0}" = "1" ]; then
        sni_optimize >/dev/null 2>&1 || warn "SNI 优选未成功，本节点沿用 $(sni_default)"
    else
        local _old=""
        _old="$(pick_sni_cached)"
        echo
        info "正在自动优选 SNI（新节点将使用当下握手最快的域名）"
        [ -n "$_old" ] && echo "  ${DIM}上次结果：${_old}${RESET}"
        sni_optimize || warn "优选未成功，沿用 $(sni_default)"
    fi
    return 0
}
handshake_default(){ sni_default; }

init_files(){
    [ -f "$NODES" ] || echo '[]' > "$NODES"
    [ -f "$CONF" ] || cat > "$CONF" <<'EOF'
{
  "log": {"level": "info"},
  "inbounds": [],
  "outbounds": [
    {"type":"direct","tag":"direct"},
    {"type":"block","tag":"block"}
  ]
}
EOF
}
backup(){
    local snap
    snap="$(_new_snapshot_dir)" || return 1
    [ -f "$CONF" ]  && cp -a "$CONF"  "$snap/config.json"
    [ -f "$NODES" ] && cp -a "$NODES" "$snap/nodes.json"
    CURRENT_SNAPSHOT="$snap"
    ls -1dt "$BACKUP"/snap-* 2>/dev/null | tail -n +21 | while read -r old; do
        rm -rf "$old"
    done
    printf '%s\n' "$snap" > "$BACKUP/.last_snapshot"
}
_new_snapshot_dir(){
    local snap
    snap="$(mktemp -d "$BACKUP/snap-$(date +%Y%m%d-%H%M%S)-XXXXXX" 2>/dev/null)" || return 1
    printf '%s\n' "$snap"
}
rollback(){
    local snap="${1:-${CURRENT_SNAPSHOT:-}}"
    if [ -z "$snap" ] || [ ! -d "$snap" ]; then
        warn "没有可用的回滚快照，请手动检查配置"
        return 1
    fi
    [ -f "$snap/config.json" ] && cp -a "$snap/config.json" "$CONF"
    [ -f "$snap/nodes.json" ]  && cp -a "$snap/nodes.json"  "$NODES"
    info "已回滚到快照：$(basename "$snap")"
}
append_inbound(){
    local x="$1" tag newtag n=1
    tag="$(jq -r '.tag // empty' <<<"$x")"
    [ -n "$tag" ] || return 1
    newtag="$tag"
    while jq -e --arg t "$newtag" '.inbounds[]? | select(.tag == $t)' "$CONF" >/dev/null 2>&1; do
        newtag="${tag}-${n}"
        n=$((n+1))
    done
    if [ "$newtag" != "$tag" ]; then
        x="$(jq --arg t "$newtag" '.tag=$t' <<<"$x")" || return 1
        info "检测到重复 tag：$tag，自动改为：$newtag"
    fi
    jq --argjson x "$x" '.inbounds += [$x]' "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"
}
node_name_default(){
    local label="$1" pre="${NODE_NAME_PREFIX:-}"
    [ -n "$pre" ] || pre="${COUNTRY_NAME:-}"
    if [ -n "$pre" ]; then printf '%s %s' "$pre" "$label"; else printf '%s' "$label"; fi
}
resolve_node_name(){
    local label="$1" def
    def="$(node_name_default "$label")"
    if [ "${BATCH_MODE:-0}" = "1" ]; then printf '%s' "$def"; return 0; fi
    local v=""
    printf '  节点名称（回车用默认「%s」）： ' "$def" >&2
    read -r v || v=""
    printf '%s' "${v:-$def}"
}
add_node(){
    local plabel="$1" type="$2" proto="$3" port="$4" uuidv="$5" pw="$6" sni="$7" extra="$8" pub="$9" sid="${10}"
    local name
    name="$(resolve_node_name "$plabel")"
    if ! jq --arg name "$name" --arg plabel "$plabel" --arg type "$type" --arg proto "$proto" --arg port "$port" \
       --arg uuid "$uuidv" --arg password "$pw" --arg sni "$sni" --arg extra "$extra" \
       --arg public_key "$pub" --arg short_id "$sid" \
       '. + [{name:$name,proto_label:$plabel,type:$type,proto:$proto,port:($port|tonumber),uuid:$uuid,password:$password,sni:$sni,extra:$extra,public_key:$public_key,short_id:$short_id}]' \
       "$NODES" > "$NODES.tmp"; then
        rm -f "$NODES.tmp"
        warn "节点记录写入失败（nodes.json 未改动），本次部署将回滚"
        return 1
    fi
    if ! mv "$NODES.tmp" "$NODES" 2>/dev/null; then
        rm -f "$NODES.tmp"
        warn "节点记录写入失败（nodes.json 未改动），本次部署将回滚"
        return 1
    fi
    return 0
}
rename_nodes_default(){
    local pre="${NODE_NAME_PREFIX:-${COUNTRY_NAME:-}}"
    jq --arg pre "$pre" '
      map( .proto_label = (.proto_label // .name)
         | .name = (if ($pre|length) > 0 then ($pre + " " + .proto_label) else .proto_label end) )' \
      "$NODES" > "$NODES.tmp" 2>/dev/null || { rm -f "$NODES.tmp"; return 1; }
    [ -s "$NODES.tmp" ] || { rm -f "$NODES.tmp"; return 1; }
    mv "$NODES.tmp" "$NODES" 2>/dev/null || { rm -f "$NODES.tmp"; return 1; }
    return 0
}
rename_nodes_prefix(){
    local pre="$1"
    [ -n "$pre" ] || return 1
    jq --arg pre "$pre" '
      map( .proto_label = (.proto_label // .name)
         | .name = ($pre + " " + .proto_label) )' \
      "$NODES" > "$NODES.tmp" 2>/dev/null || { rm -f "$NODES.tmp"; return 1; }
    [ -s "$NODES.tmp" ] || { rm -f "$NODES.tmp"; return 1; }
    mv "$NODES.tmp" "$NODES" 2>/dev/null || { rm -f "$NODES.tmp"; return 1; }
    return 0
}

tag_family_to_raw(){
    local t="$1" base raw
    for ((raw=1; raw<=16; raw++)); do
        [ "$(raw_to_tag "$raw")" = "$t" ] && { printf '%s' "$raw"; return 0; }
    done
    base="$(printf '%s' "$t" | sed -E 's/-[0-9]+$//')"
    [ "$base" = "$t" ] && return 1
    for ((raw=1; raw<=16; raw++)); do
        [ "$(raw_to_tag "$raw")" = "$base" ] && { printf '%s' "$raw"; return 0; }
    done
    return 1
}
orphan_inbounds(){
    [ -f "$CONF" ] || return 0
    local n_inb i tag port raw ntype udp_inb
    n_inb="$(jq '.inbounds | length' "$CONF" 2>/dev/null)"
    case "$n_inb" in ''|*[!0-9]*) return 0 ;; esac
    for ((i=0; i<n_inb; i++)); do
        tag="$(jq -r ".inbounds[$i].tag // empty" "$CONF" 2>/dev/null)"
        [ -n "$tag" ] || continue
        port="$(jq -r ".inbounds[$i].listen_port // empty" "$CONF" 2>/dev/null)"
        [ -n "$port" ] || continue
        raw="$(tag_family_to_raw "$tag")" || continue
        ntype="$(raw_to_node_type "$raw")"
        [ -n "$ntype" ] || continue
        udp_inb="$(jq -r --argjson i "$i" '
            .inbounds[$i]
            | if (.type == "hysteria2" or .type == "tuic") then "1"
              elif (.type == "http") then (if ((.version // []) | index(3)) != null then "1" else "0" end)
              else "0" end' "$CONF" 2>/dev/null)"
        if jq -e --arg t "$ntype" --argjson p "$port" --arg u "$udp_inb" '
              any(.[]; .type == $t
                      and ((.port | tonumber) == $p)
                      and (if .proto == "udp" then "1" else "0" end) == $u)' \
              "$NODES" >/dev/null 2>&1; then
            continue
        fi
        printf '%s\t%s\n' "$tag" "$port"
    done
}
cleanup_orphan_inbounds(){
    need_root
    local rep; rep="$(orphan_inbounds)"
    if [ -z "$rep" ]; then ok "没有发现孤儿 inbound"; return 0; fi
    warn "发现以下孤儿 inbound（config.json 里有、节点列表里没有）："
    local tag port
    while IFS=$'\t' read -r tag port; do
        [ -n "$tag" ] || continue
        printf '  · %-24s 端口 %s\n' "$tag" "$port"
    done <<<"$rep"
    echo "  ${DIM}它们不在订阅里、也无法在菜单里删除，还会白占端口。${RESET}"
    echo
    read -r -p "  删除这些孤儿 inbound？（y/N）： " _y || _y=""
    case "$_y" in y|Y|yes|YES) : ;; *) info "已取消"; return 0 ;; esac
    backup
    local _fails=0
    while IFS=$'\t' read -r tag port; do
        [ -n "$tag" ] || continue
        if jq --arg t "$tag" --argjson p "$port" '
              [ .inbounds[] | select(.tag == $t and (.listen_port == $p)) ] as $hits
              | ($hits[0]) as $v
              | if $v == null then . else .inbounds |= map(select(. != $v)) end' \
              "$CONF" > "$CONF.tmp" 2>/dev/null && [ -s "$CONF.tmp" ]; then
            mv "$CONF.tmp" "$CONF" 2>/dev/null || { rm -f "$CONF.tmp"; _fails=$((_fails+1)); }
        else
            rm -f "$CONF.tmp"; _fails=$((_fails+1))
        fi
    done <<<"$rep"
    if [ "$_fails" -gt 0 ]; then warn "$_fails 个 inbound 清理失败"; fi
    if validate; then
        apply >/dev/null 2>&1 || true
        export_all >/dev/null 2>&1 || true
        ok "孤儿 inbound 已清理，订阅已刷新"
    else
        warn "清理后配置检查未通过，正在回滚"
        rollback
    fi
}
del_node_by_raw(){
    local raw="$1"
    [ -n "$raw" ] || return 1
    local t
    t="$(raw_to_node_type "$raw")"
    [ -n "$t" ] || return 1
    local idx
    idx="$(jq -r --arg t "$t" '[.[] | .type == $t] | (length - 1) - (reverse | index(true) // -1)' "$NODES" 2>/dev/null)"
    case "$idx" in ''|*[!0-9]*) return 1 ;; esac
    [ "$idx" -ge 0 ] || return 1
    jq --argjson i "$idx" 'del(.[$i])' "$NODES" > "$NODES.tmp" 2>/dev/null \
        && mv "$NODES.tmp" "$NODES" || { rm -f "$NODES.tmp"; return 1; }
}
raw_to_node_type(){
    case "$1" in
        1)  echo "vless-reality" ;;
        2)  echo "hysteria2" ;;
        3)  echo "hy2-obfs" ;;
        4)  echo "tuic" ;;
        5)  echo "shadowsocks" ;;
        6)  echo "trojan" ;;
        7)  echo "vmess-ws-tls" ;;
        8)  echo "vless-ws-tls" ;;
        9)  echo "h2-reality" ;;
        10) echo "grpc-reality" ;;
        11) echo "anytls" ;;
        12) echo "naive" ;;
        13) echo "http2" ;;
        14) echo "http3" ;;
        15) echo "hy2-realm" ;;
        16) echo "shadowtls" ;;
        *)  echo "" ;;
    esac
}

raw_to_tag(){
    case "$1" in
        1)  echo "vless-reality" ;;
        2)  echo "hysteria2" ;;
        3)  echo "hysteria2-salamander" ;;
        4)  echo "tuic-v5" ;;
        5)  echo "shadowsocks" ;;
        6)  echo "trojan" ;;
        7)  echo "vmess-ws-tls" ;;
        8)  echo "vless-ws-tls" ;;
        9)  echo "vless-h2-reality" ;;
        10) echo "vless-grpc-reality" ;;
        11) echo "anytls" ;;
        12) echo "naive" ;;
        13) echo "http2" ;;
        14) echo "http3" ;;
        15) echo "hysteria2-realm" ;;
        16) echo "shadowtls-v3" ;;
        *)  echo "" ;;
    esac
}

proto_of_raw(){
    case "$1" in
        2|3|4|14|15) echo "udp" ;;
        1|5|6|7|8|9|10|11|12|13|16) echo "tcp" ;;
        *)  echo "" ;;
    esac
}
ask(){
    local __v="$1" prompt="$2" def="$3" v
    if [ "${BATCH_MODE:-0}" = 1 ]; then printf -v "$__v" '%s' "$def"
    else
        if [ -n "${def:-}" ]; then
            read -r -p "${prompt}（默认 ${def}）： " v || v=""
        else
            read -r -p "${prompt}： " v || v=""
        fi
        printf -v "$__v" '%s' "${v:-$def}"
    fi
}
add_vless_reality(){
    local p u s sid flow
    sni_maybe_optimize
    p="$(need_port tcp "$DEFAULT_TCP_START")" || return 1; u="$(uuid)"; sid="$(short_id)"
    ask s "Reality SNI" "$(sni_default)"
    ask flow "Flow [xtls-rprx-vision]： " "xtls-rprx-vision"
    reality_keys || { warn "Reality 密钥生成失败"; return 1; }
    local obj
    obj="$(jq -n --arg p "$p" --arg u "$u" --arg s "$s" --arg sid "$sid" --arg pr "$REALITY_PRIVATE" --arg f "$flow" '{
      type:"vless",tag:"vless-reality",listen:"::",listen_port:($p|tonumber),
      users:[{uuid:$u,flow:$f}],
      tls:{enabled:true,server_name:$s,reality:{enabled:true,handshake:{server:$s,server_port:443},private_key:$pr,short_id:[$sid]}}
    }')"
    append_inbound "$obj"
    add_node "VLESS + Reality" "vless-reality" tcp "$p" "$u" "" "$s" "$flow" "$REALITY_PUBLIC" "$sid"
}
add_vless_ws_tls(){
    ensure_cert || { warn "自签证书不可用，跳过本协议"; return 1; }
    sni_maybe_optimize
    local p u path s
    p="$(need_port tcp "$((DEFAULT_TCP_START+1))")" || return 1; u="$(uuid)"; path="/$(rand_str 4)"
    ask s "TLS SNI" "$(sni_default)"
    local obj
    obj="$(jq -n --arg p "$p" --arg u "$u" --arg s "$s" --arg path "$path" --arg CRT "$CERTDIR/server.crt" --arg KEY "$CERTDIR/server.key" '{
      type:"vless",tag:"vless-ws-tls",listen:"::",listen_port:($p|tonumber),
      users:[{uuid:$u}],
      tls:{enabled:true,server_name:$s,certificate_path:$CRT,key_path:$KEY},
      transport:{type:"ws",path:$path}
    }')"
    append_inbound "$obj"
    add_node "VLESS + WS + TLS" "vless-ws-tls" tcp "$p" "$u" "" "$s" "$path" "" ""
}
add_vmess_ws_tls(){
    ensure_cert || { warn "自签证书不可用，跳过本协议"; return 1; }
    sni_maybe_optimize
    local p u path s
    p="$(need_port tcp "$((DEFAULT_TCP_START+2))")" || return 1; u="$(uuid)"; path="/$(rand_str 4)"
    ask s "TLS SNI" "$(sni_default)"
    local obj
    obj="$(jq -n --arg p "$p" --arg u "$u" --arg s "$s" --arg path "$path" --arg CRT "$CERTDIR/server.crt" --arg KEY "$CERTDIR/server.key" '{
      type:"vmess",tag:"vmess-ws-tls",listen:"::",listen_port:($p|tonumber),
      users:[{uuid:$u}],
      tls:{enabled:true,server_name:$s,certificate_path:$CRT,key_path:$KEY},
      transport:{type:"ws",path:$path}
    }')"
    append_inbound "$obj"
    add_node "VMess + WS + TLS" "vmess-ws-tls" tcp "$p" "$u" "" "$s" "$path" "" ""
}
add_trojan(){
    ensure_cert || { warn "自签证书不可用，跳过本协议"; return 1; }
    sni_maybe_optimize
    local p pw s
    p="$(need_port tcp "$((DEFAULT_TCP_START+3))")" || return 1; pw="$(rand_str 12)"
    ask s "TLS SNI" "$(sni_default)"
    local obj
    obj="$(jq -n --arg p "$p" --arg pw "$pw" --arg s "$s" --arg CRT "$CERTDIR/server.crt" --arg KEY "$CERTDIR/server.key" '{
      type:"trojan",tag:"trojan",listen:"::",listen_port:($p|tonumber),
      users:[{password:$pw}],
      tls:{enabled:true,server_name:$s,certificate_path:$CRT,key_path:$KEY}
    }')"
    append_inbound "$obj"; add_node "Trojan + TLS" trojan tcp "$p" "" "$pw" "$s" "" "" ""
}
add_shadowtls(){
    local p pw h
    sni_maybe_optimize
    p="$(need_port tcp "$((DEFAULT_TCP_START+4))")" || return 1; pw="$(rand_str 12)"
    ask h "握手站点（需支持 TLS）" "$(handshake_default)"
    local obj
    obj="$(jq -n --arg p "$p" --arg pw "$pw" --arg h "$h" '{
      type:"shadowtls",tag:"shadowtls-v3",listen:"::",listen_port:($p|tonumber),
      version:3,users:[{password:$pw}],handshake:{server:$h,server_port:443},strict_mode:false
    }')"
    append_inbound "$obj"; add_node "ShadowTLS v3" shadowtls tcp "$p" "" "$pw" "$h" "" "" ""
}
add_anytls(){
    ensure_cert || { warn "自签证书不可用，跳过本协议"; return 1; }
    sni_maybe_optimize
    local p pw s
    p="$(need_port tcp "$((DEFAULT_TCP_START+5))")" || return 1; pw="$(rand_str 12)"
    ask s "TLS SNI" "$(sni_default)"
    local obj
    obj="$(jq -n --arg p "$p" --arg pw "$pw" --arg s "$s" --arg CRT "$CERTDIR/server.crt" --arg KEY "$CERTDIR/server.key" '{
      type:"anytls",tag:"anytls",listen:"::",listen_port:($p|tonumber),
      users:[{password:$pw}],
      tls:{enabled:true,server_name:$s,certificate_path:$CRT,key_path:$KEY}
    }')"
    append_inbound "$obj"; add_node "AnyTLS" anytls tcp "$p" "" "$pw" "$s" "" "" ""
}
add_naive(){
    ensure_cert || { warn "自签证书不可用，跳过本协议"; return 1; }
    sni_maybe_optimize
    if ! version_ge "1.15.0" "$(sb_version)"; then
        warn "NaiveProxy 需要 sing-box 1.15.0+（当前 $(sb_version)），无法创建"
        info "可到「sing-box 内核管理 → 2 升级 / 切换内核版本」切到最新测试版"
        return 1
    fi
    local p user pw s
    p="$(need_port tcp "$((DEFAULT_TCP_START+6))")" || return 1; user="user$(rand_str 3)"; pw="$(rand_str 12)"
    ask s "TLS SNI" "$(sni_default)"
    local obj
    obj="$(jq -n --arg p "$p" --arg user "$user" --arg pw "$pw" --arg CRT "$CERTDIR/server.crt" --arg KEY "$CERTDIR/server.key" '{
      type:"naive",tag:"naive",listen:"::",listen_port:($p|tonumber),
      users:[{username:$user,password:$pw}],
      tls:{enabled:true,certificate_path:$CRT,key_path:$KEY}
    }')"
    append_inbound "$obj"; add_node "NaiveProxy" naive tcp "$p" "$user" "$pw" "$s" "" "" ""
}
add_ss(){
    local p pw method
    p="$(need_port tcp "$((DEFAULT_TCP_START+7))")" || return 1; method="2022-blake3-aes-128-gcm"; pw="$(openssl rand -base64 16 | tr -d '\n')"
    local obj
    obj="$(jq -n --arg p "$p" --arg pw "$pw" --arg m "$method" '{
      type:"shadowsocks",tag:"shadowsocks",listen:"::",listen_port:($p|tonumber),
      method:$m,password:$pw
    }')"
    append_inbound "$obj"; add_node "Shadowsocks 2022" shadowsocks tcp "$p" "" "$pw" "" "$method" "" ""
}
add_hysteria2(){
    ensure_cert || { warn "自签证书不可用，跳过本协议"; return 1; }
    sni_maybe_optimize
    local p pw s
    p="$(need_port udp "$DEFAULT_UDP_START")" || return 1; pw="$(rand_str 12)"
    ask s "TLS SNI" "$(sni_default)"
    local obj
    obj="$(jq -n --arg p "$p" --arg pw "$pw" --arg s "$s" --arg CRT "$CERTDIR/server.crt" --arg KEY "$CERTDIR/server.key" '{
      type:"hysteria2",tag:"hysteria2",listen:"::",listen_port:($p|tonumber),
      users:[{password:$pw}],
      tls:{enabled:true,server_name:$s,certificate_path:$CRT,key_path:$KEY},
      masquerade:{type:"string",status_code:404}
    }')"
    append_inbound "$obj"; add_node "Hysteria2" hysteria2 udp "$p" "" "$pw" "$s" "" "" ""
}
add_hy2_obfs(){
    ensure_cert || { warn "自签证书不可用，跳过本协议"; return 1; }
    sni_maybe_optimize
    local p pw obfs s
    p="$(need_port udp "$((DEFAULT_UDP_START+1))")" || return 1; pw="$(rand_str 12)"; obfs="$(rand_str 12)"
    ask s "TLS SNI" "$(sni_default)"
    local obj
    obj="$(jq -n --arg p "$p" --arg pw "$pw" --arg obfs "$obfs" --arg s "$s" --arg CRT "$CERTDIR/server.crt" --arg KEY "$CERTDIR/server.key" '{
      type:"hysteria2",tag:"hysteria2-salamander",listen:"::",listen_port:($p|tonumber),
      users:[{password:$pw}],obfs:{type:"salamander",password:$obfs},
      tls:{enabled:true,server_name:$s,certificate_path:$CRT,key_path:$KEY},
      masquerade:{type:"string",status_code:404}
    }')"
    append_inbound "$obj"; add_node "Hysteria2 + Salamander" hy2-obfs udp "$p" "" "$pw" "$s" "$obfs" "" ""
}
add_tuic(){
    ensure_cert || { warn "自签证书不可用，跳过本协议"; return 1; }
    sni_maybe_optimize
    local p u pw s
    p="$(need_port udp "$((DEFAULT_UDP_START+2))")" || return 1; u="$(uuid)"; pw="$(rand_str 12)"
    ask s "TLS SNI" "$(sni_default)"
    local obj
    obj="$(jq -n --arg p "$p" --arg u "$u" --arg pw "$pw" --arg s "$s" --arg CRT "$CERTDIR/server.crt" --arg KEY "$CERTDIR/server.key" '{
      type:"tuic",tag:"tuic-v5",listen:"::",listen_port:($p|tonumber),
      users:[{uuid:$u,password:$pw}],
      tls:{enabled:true,server_name:$s,certificate_path:$CRT,key_path:$KEY}
    }')"
    append_inbound "$obj"; add_node "TUIC v5" tuic udp "$p" "$u" "$pw" "$s" "" "" ""
}
sb_version(){
    if [ -n "${SB_VERSION_CACHE:-}" ]; then
        printf '%s\n' "$SB_VERSION_CACHE"
        return 0
    fi
    local _vc="$BASE/.sbver.cache" _now _cts="" _cval=""
    _now="$(date +%s 2>/dev/null)"
    if [ -s "$_vc" ]; then
        IFS=' ' read -r _cts _cval < "$_vc" 2>/dev/null || true
        if [ -n "$_cts" ] && [ -n "$_cval" ] && [ -n "$_now" ] && \
           [ $(( _now - _cts )) -ge 0 ] && [ $(( _now - _cts )) -lt 60 ]; then
            SB_VERSION_CACHE="$_cval"
            printf '%s\n' "$_cval"
            return 0
        fi
    fi
    local v=""
    if [ -x "$BIN" ]; then
        v="$("$BIN" version 2>/dev/null | sed -n 's/.*version \([0-9][0-9.]*\).*/\1/p' | head -n1)"
    fi
    if [ -z "$v" ] && [ -s "$VERSION_FILE" ]; then
        v="$(sed -n 's/^v\?\([0-9][0-9.]*\).*/\1/p' "$VERSION_FILE" | head -n1)"
    fi
    if [ -z "$v" ] && command -v sing-box >/dev/null 2>&1; then
        v="$(sing-box version 2>/dev/null | sed -n 's/.*version \([0-9][0-9.]*\).*/\1/p' | head -n1)"
    fi
    if [ -n "$v" ]; then
        SB_VERSION_CACHE="$v"
        [ -s "$_vc" ] || { mkdir -p "$BASE" 2>/dev/null; printf '%s %s\n' "$_now" "$v" > "$_vc" 2>/dev/null || true; }
        printf '%s\n' "$v"
    fi
}
version_ge(){
    local want="$1" have="$2"
    [ -n "$have" ] || have="$(sb_version)"
    [ -n "$have" ] || return 1
    local i w h
    local -a wp=() hp=()
    IFS='.' read -r -a wp <<<"$want"
    IFS='.' read -r -a hp <<<"$have"
    for ((i=0; i<3; i++)); do
        w="${wp[i]:-0}"; h="${hp[i]:-0}"
        [[ "$w" =~ ^[0-9]+$ ]] || w=0
        [[ "$h" =~ ^[0-9]+$ ]] || h=0
        if [ "$h" -gt "$w" ]; then return 0; fi
        if [ "$h" -lt "$w" ]; then return 1; fi
    done
    return 0
}
http_version_supported(){
    local v
    v="$(sb_version)"
    [ -n "$v" ] || return 0
    version_ge "1.15.0" "$v"
}
ensure_http_version(){
    http_version_supported && return 0
    if [ "${BATCH_MODE:-0}" = "1" ]; then
        return 1
    fi
    local cur; cur="$(sb_version)"
    warn "当前 sing-box ${cur:-未知} 不支持 http 的 version 字段（需要 1.15.0+）"
    echo "  ${DIM}说明：HTTP/2 的显式声明、以及 HTTP/3（QUIC）都要靠 version 字段；${RESET}"
    echo "  ${DIM}它从 1.15.0-alpha.7 开始提供，官方正式版目前还停在 1.14.x。${RESET}"
    echo
    echo "  1. 现在升级到最新内核（含 alpha/beta，推荐）"
    echo "  2. 继续，按兼容模式创建（省略 version，仅 HTTP/1.1 + HTTP/2）"
    echo "  0. 取消本次部署"
    read -r -p "  请选择 [1]： " _hv || _hv=""
    case "${_hv:-1}" in
        1)
            local bak; bak="${BIN}.bak"
            [ -x "$BIN" ] && cp -f "$BIN" "$bak" 2>/dev/null || true
            info "正在升级内核 ..."
            SINGBOX_CHANNEL=any; SINGBOX_WANT_VERSION=""; save_settings
            if download_singbox; then
                strip_http_version
                if http_version_supported; then
                    ok "已升级到 $(sb_version)，可以创建节点"
                    rm -f "$bak" 2>/dev/null || true
                    return 0
                fi
                warn "升级后版本仍未达到 1.15.0，按兼容模式继续"
            else
                warn "升级失败，按兼容模式继续"
                [ -x "$bak" ] && mv -f "$bak" "$BIN" 2>/dev/null || true
            fi
            return 1 ;;
        2) return 1 ;;
        *) return 2 ;;
    esac
}
add_http2(){
    ensure_cert || { warn "自签证书不可用，跳过本协议"; return 1; }
    sni_maybe_optimize
    local p s user pw obj vfield=""
    local _hvrc=0
    ensure_http_version || _hvrc=$?
    [ "$_hvrc" = "2" ] && { info "已取消 HTTP/2 部署"; return 1; }
    p="$(need_port tcp "$((DEFAULT_TCP_START+10))")" || return 1
    ask s "HTTP/2 TLS SNI" "$(sni_default)"
    ask user "HTTP 用户名" "h2"
    pw="$(rand_str 12)"
    if http_version_supported; then
        vfield='true'
    else
        vfield='false'
        warn "sing-box $(sb_version) 不支持 version 字段（需 1.15.0+），已按兼容模式创建：省略 version，仍支持 HTTP/1.1 与 HTTP/2"
    fi
    if [ "$vfield" = "true" ]; then
        obj="$(jq -n --arg p "$p" --arg s "$s" --arg user "$user" --arg pw "$pw" --arg CRT "$CERTDIR/server.crt" --arg KEY "$CERTDIR/server.key" '{
          type:"http",tag:"http2",listen:"::",listen_port:($p|tonumber),
          users:[{username:$user,password:$pw}],
          tls:{enabled:true,server_name:$s,certificate_path:$CRT,key_path:$KEY},
          version:[2]
        }')"
    else
        obj="$(jq -n --arg p "$p" --arg s "$s" --arg user "$user" --arg pw "$pw" --arg CRT "$CERTDIR/server.crt" --arg KEY "$CERTDIR/server.key" '{
          type:"http",tag:"http2",listen:"::",listen_port:($p|tonumber),
          users:[{username:$user,password:$pw}],
          tls:{enabled:true,server_name:$s,certificate_path:$CRT,key_path:$KEY}
        }')"
    fi
    append_inbound "$obj"
    add_node "HTTP/2" http2 tcp "$p" "$user" "$pw" "$s" "" "" ""
}
add_http3(){
    ensure_cert || { warn "自签证书不可用，跳过本协议"; return 1; }
    sni_maybe_optimize
    local p s user pw obj
    local _hvrc=0
    ensure_http_version || _hvrc=$?
    if [ "$_hvrc" != "0" ]; then
        if [ "$_hvrc" = "2" ]; then
            info "已取消 HTTP/3 部署"
        else
            warn "HTTP/3 必须要有 version 字段，无法按兼容模式创建"
            info "可先用「sing-box 内核管理 → 2」换到 1.15.0+ 再回来部署"
        fi
        return 1
    fi
    p="$(need_port udp "$((DEFAULT_UDP_START+5))")" || return 1
    ask s "HTTP/3 TLS SNI" "$(sni_default)"
    ask user "HTTP 用户名" "h3"
    pw="$(rand_str 12)"
    obj="$(jq -n --arg p "$p" --arg s "$s" --arg user "$user" --arg pw "$pw" --arg CRT "$CERTDIR/server.crt" --arg KEY "$CERTDIR/server.key" '{
      type:"http",tag:"http3",listen:"::",listen_port:($p|tonumber),
      users:[{username:$user,password:$pw}],
      tls:{enabled:true,server_name:$s,certificate_path:$CRT,key_path:$KEY},
      version:[3]
    }')"
    append_inbound "$obj"; add_node "HTTP/3" http3 udp "$p" "$user" "$pw" "$s" "" "" ""
}
strip_http_version(){
    http_version_supported && return 0
    [ -f "$CONF" ] || return 0
    jq '(.inbounds // []) |= map(if (.type == "http") then del(.version) else . end)' \
        "$CONF" >"$CONF.tmp" 2>/dev/null && mv "$CONF.tmp" "$CONF" || rm -f "$CONF.tmp"
}
add_h2_reality(){
    local p u s sid
    sni_maybe_optimize
    p="$(need_port tcp "$((DEFAULT_TCP_START+8))")" || return 1; u="$(uuid)"; sid="$(short_id)"
    ask s "Reality SNI" "$(sni_default)"
    reality_keys || { warn "Reality 密钥生成失败"; return 1; }
    local obj
    obj="$(jq -n --arg p "$p" --arg u "$u" --arg s "$s" --arg sid "$sid" --arg pr "$REALITY_PRIVATE" '{
      type:"vless",tag:"vless-h2-reality",listen:"::",listen_port:($p|tonumber),
      users:[{uuid:$u}],
      tls:{enabled:true,server_name:$s,reality:{enabled:true,handshake:{server:$s,server_port:443},private_key:$pr,short_id:[$sid]}},
      transport:{type:"http"}
    }')"
    append_inbound "$obj"; add_node "VLESS + H2 + Reality" h2-reality tcp "$p" "$u" "" "$s" "" "$REALITY_PUBLIC" "$sid"
}
add_grpc_reality(){
    local p u s sid service
    sni_maybe_optimize
    p="$(need_port tcp "$((DEFAULT_TCP_START+9))")" || return 1; u="$(uuid)"; sid="$(short_id)"; service="$(rand_str 4)"
    ask s "Reality SNI" "$(sni_default)"
    reality_keys || { warn "Reality 密钥生成失败"; return 1; }
    local obj
    obj="$(jq -n --arg p "$p" --arg u "$u" --arg s "$s" --arg sid "$sid" --arg pr "$REALITY_PRIVATE" --arg svc "$service" '{
      type:"vless",tag:"vless-grpc-reality",listen:"::",listen_port:($p|tonumber),
      users:[{uuid:$u}],
      tls:{enabled:true,server_name:$s,reality:{enabled:true,handshake:{server:$s,server_port:443},private_key:$pr,short_id:[$sid]}},
      transport:{type:"grpc",service_name:$svc}
    }')"
    append_inbound "$obj"; add_node "VLESS + gRPC + Reality" grpc-reality tcp "$p" "$u" "" "$s" "$service" "$REALITY_PUBLIC" "$sid"
}
add_hy2_realm(){
    ensure_cert || { warn "自签证书不可用，跳过本协议"; return 1; }
    sni_maybe_optimize
    local p pw s url token rid
    p="$(need_port udp "$((DEFAULT_UDP_START+4))")" || return 1; pw="$(rand_str 12)"
    ask s "TLS SNI" "$(sni_default)"
    echo
    echo "  ${BOLD}Realm 是什么${RESET}"
    echo "  ${DIM}Hysteria2 官方的中继 / 打洞服务，用于服务器无公网 IP${RESET}"
    echo "  ${DIM}或端口被封时，让客户端仍能连上。${RESET}"
    echo
    echo "  ${BOLD}选一个 Realm 服务实例（直接回车 = 1）${RESET}"
    echo "  ${DIM}1. realm.hy2.io   官方公共实例，token=public，开箱可用（推荐）${RESET}"
    echo "  ${DIM}2. 自定义         自建 Realm 时填自己的地址${RESET}"
    echo
    read -r -p "  请选择 [1]： " _rl || _rl=""
    case "${_rl:-1}" in
        2)
            ask url "  自建 Realm server_url" ""
            [ -n "$url" ] || { warn "server_url 不能为空，未创建"; return 1; }
            ask token "  Realm token" ""
            ;;
        *)
            url="https://realm.hy2.io"
            token="public"
            ;;
    esac
    ask rid "  Realm ID" "hy2-$(rand_str 4)"
    url="$(printf '%s' "$url" | tr -d '[:space:]')"
    [ -n "$url" ] || { warn "Realm server_url 不能为空，未创建"; return 1; }
    case "$url" in
        http://*|https://*) : ;;
        *) url="https://${url}" ;;
    esac
    local obj
    obj="$(jq -n --arg p "$p" --arg pw "$pw" --arg s "$s" --arg url "$url" --arg token "$token" --arg rid "$rid" --arg CRT "$CERTDIR/server.crt" --arg KEY "$CERTDIR/server.key" '{
      type:"hysteria2",tag:"hysteria2-realm",listen:"::",listen_port:($p|tonumber),
      users:[{password:$pw}],tls:{enabled:true,server_name:$s,certificate_path:$CRT,key_path:$KEY},
      realm:{server_url:$url,token:$token,realm_id:$rid,stun_servers:["turn.cloudflare.com:3478","stun.nextcloud.com:3478","stun.sip.us:3478","global.stun.twilio.com:3478"]}
    }')"
    append_inbound "$obj"; add_node "Hysteria2 + Realm" hy2-realm udp "$p" "" "$pw" "$s" "${rid}@${url}" "" ""
}

validate(){
    jq empty "$CONF" >/dev/null 2>&1 || { warn "config.json JSON 格式错误"; return 1; }
    local dup
    dup="$(jq -r '[.inbounds[]?.tag // empty] | group_by(.)[] | select(length>1) | .[0]' "$CONF" 2>/dev/null | head -n1)"
    [ -z "$dup" ] || { warn "发现重复 inbound tag：$dup"; return 1; }
    "$BIN" check -c "$CONF"
}
apply(){
    validate || { warn "配置检查失败，保留当前文件但不会重启"; return 1; }
    if [ "$INIT" = systemd ] && command -v systemctl >/dev/null; then
        systemctl reset-failed sing-box >/dev/null 2>&1 || true
        systemctl restart sing-box || { warn "systemctl 重启 sing-box 失败"; return 1; }
    elif [ "$INIT" = openrc ] && command -v rc-service >/dev/null; then
        rc-service sing-box restart || { warn "rc-service 重启 sing-box 失败"; return 1; }
    else
        pkill -f "$BIN run -c $CONF" 2>/dev/null || true
        nohup "$BIN" run -c "$CONF" >>"$LOGDIR/sing-box.log" 2>&1 &
        echo $! > "$BASE/pid"
    fi
    local i
    for i in $(seq 1 20); do
        sleep 1
        if service_alive; then
            sleep 3
            service_alive && return 0
        fi
    done
    warn "sing-box 重启后未存活（已等待 20 秒）"
    local _diag _check _journal _summary
    _check="$("$BIN" check -c "$CONF" 2>&1 | head -n 8)"
    if [ "$INIT" = systemd ] && command -v journalctl >/dev/null 2>&1; then
        _journal="$(journalctl -u sing-box -n 80 --no-pager 2>/dev/null \
                    | grep -v 'systemd\[' \
                    | grep -Ei 'FATAL|ERROR|panic|unknown|invalid|denied|address already|permission|cannot|no such|failed' \
                    | tail -n 8)"
    fi
    _summary="$(jq -r '.inbounds[]? | "\(.type) tag=\(.tag) port=\(.listen_port // "-")"' "$CONF" 2>/dev/null | head -n 30)"
    _diag="==== $(date '+%F %T') 服务启动失败诊断 ====
【config check】
${_check:-（无输出）}
【journalctl】
${_journal:-（无输出）}
【配置摘要】
${_summary:-（无法读取）}
"
    printf '%s\n' "$_diag" >> "$LOGDIR/apply-error.log" 2>/dev/null || true
    if [ -n "$_check" ]; then
        printf '%s\n' "$_check" | while IFS= read -r _l; do warn "  $_l"; done
    fi
    if [ -n "$_journal" ]; then
        printf '%s\n' "$_journal" | while IFS= read -r _l; do warn "  $_l"; done
    fi
    warn "完整诊断已写入：$LOGDIR/apply-error.log"
    return 1
}
_collect_sb_error(){
    local line=""
    if [ -x "$BIN" ] && [ -f "$CONF" ]; then
        line="$("$BIN" check -c "$CONF" 2>&1 | grep -Ei 'FATAL|ERROR|panic|unknown field|decode config|cannot|invalid|duplicate|failed' | head -n 1)"
        [ -z "$line" ] && line="$("$BIN" check -c "$CONF" 2>&1 | head -n 1)"
    fi
    if [ -z "$line" ] && [ "$INIT" = systemd ] && command -v journalctl >/dev/null 2>&1; then
        line="$(journalctl -u sing-box -n 100 --no-pager 2>/dev/null \
                | grep -Ei 'FATAL|ERROR|panic|unknown field|decode config|cannot|invalid|duplicate' \
                | grep -v 'systemd\[' \
                | tail -n 1)"
    fi
    if [ -z "$line" ] && [ -s "$LOGDIR/sing-box.log" ]; then
        line="$(grep -Ei 'FATAL|ERROR|panic|unknown field|decode config|invalid|duplicate' "$LOGDIR/sing-box.log" 2>/dev/null | grep -v 'systemd\[' | tail -n 1)"
    fi
    [ -n "$line" ] && printf '%s' "$line" || printf '（未捕获到明确报错，请手动执行：%s check -c %s）' "$BIN" "$CONF"
}
service_alive(){
    if [ "$INIT" = systemd ] && command -v systemctl >/dev/null; then
        if systemctl is-active --quiet sing-box 2>/dev/null; then
            return 0
        fi
        local _p
        _p="$(pgrep -f "$BIN run -c $CONF" 2>/dev/null | head -n1)"
        if [ -n "$_p" ]; then
            local _st=""
            [ -r "/proc/$_p/stat" ] && _st="$(awk '{print $3}' "/proc/$_p/stat" 2>/dev/null)"
            [ -n "$_st" ] && [ "$_st" != "Z" ]
        else
            return 1
        fi
    elif [ "$INIT" = openrc ] && command -v rc-service >/dev/null; then
        rc-service sing-box status >/dev/null 2>&1
    else
        local pid=""
        [ -f "$BASE/pid" ] && pid="$(cat "$BASE/pid" 2>/dev/null)"
        [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
    fi
}
install_service(){
    if [ "$INIT" = systemd ]; then
cat >/etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=Sing-box NAT Multi Protocol
After=network-online.target
Wants=network-online.target
# 配置调试期间会连续重启多次，若不关掉启动限流，systemd 会在第 5 次后
# 报 "start request repeated too quickly" 并拒绝启动，看起来像配置错误，
# 实际只是被限流了。
StartLimitIntervalSec=0
[Service]
Type=simple
ExecStart=$BIN run -c $CONF
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
# 同时写文件：脚本里多处提示「请查看 $LOGDIR/sing-box.log」，
# 若只走 journald 那个文件就是空的，用户按提示去看什么都找不到。
StandardOutput=append:$LOGDIR/sing-box.log
StandardError=append:$LOGDIR/sing-box.log
[Install]
WantedBy=multi-user.target
EOF
        mkdir -p "$LOGDIR"
        touch "$LOGDIR/sing-box.log" 2>/dev/null || true
        systemctl daemon-reload
        systemctl enable sing-box >/dev/null 2>&1 || true
    elif [ "$INIT" = openrc ]; then
cat >/etc/init.d/sing-box <<EOF
#!/sbin/openrc-run
command="$BIN"
command_args="run -c $CONF"
command_background="yes"
pidfile="/run/sing-box.pid"
depend(){ need net; }
EOF
        chmod +x /etc/init.d/sing-box
        rc-update add sing-box default >/dev/null 2>&1 || true
    fi
}
status(){
    if [ "$INIT" = systemd ]; then systemctl --no-pager --full status sing-box || true
    elif [ "$INIT" = openrc ]; then rc-service sing-box status || true
    else ps -ef | grep '[s]ing-box run' || true; fi
}
upgrade_singbox(){
    clear
    panel "升级 / 切换 sing-box 内核"
    need_root
    local cur rel tag a bak want lat_any lat_stable
    cur="$(sb_version)"
    if [ -n "$cur" ]; then kv "当前版本" "$cur"
    else kv "当前版本" "${RED}未安装${RESET}"; fi
    if http_version_supported; then
        kv "HTTP/3 支持" "${GREEN}可以${RESET}"
    else
        kv "HTTP/3 支持" "${YELLOW}需升级到 1.15.0+${RESET}"
    fi
    kv "默认频道" "${SINGBOX_CHANNEL:-any}"

    info "正在查询可用版本 ..."
    SINGBOX_CHANNEL=any; rel="$(fetch_singbox_release)"
    lat_any="$(printf '%s' "$rel" | cut -f1)"
    SINGBOX_CHANNEL=stable; rel="$(fetch_singbox_release)"
    lat_stable="$(printf '%s' "$rel" | cut -f1)"
    case "$lat_any" in null) lat_any="" ;; esac
    case "$lat_stable" in null) lat_stable="" ;; esac
    echo
    if [ -n "$lat_any" ]; then
        printf '  %s1.%s 升级到最新版（含 alpha/beta）  %s%s%s  %s← 推荐，能开 HTTP/3%s\n' \
            "$BOLD" "$RESET" "$CYAN" "$lat_any" "$RESET" "$DIM" "$RESET"
    else
        printf '  %s1.%s 升级到最新版（含 alpha/beta）  %s(查询失败，将用内置版本 %s)%s\n' \
            "$BOLD" "$RESET" "$YELLOW" "$DEFAULT_NEWEST_VERSION" "$RESET"
    fi
    if [ -n "$lat_stable" ]; then
        printf '  %s2.%s 升级到最新正式版（最稳）        %s%s%s\n' \
            "$BOLD" "$RESET" "$GREEN" "$lat_stable" "$RESET"
    else
        printf '  %s2.%s 升级到最新正式版（最稳）        %s(查询失败)%s\n' \
            "$BOLD" "$RESET" "$YELLOW" "$RESET"
    fi
    printf '  %s3.%s 从列表里挑一个版本\n' "$BOLD" "$RESET"
    printf '  %s4.%s 手动输入版本号（可回退旧版）\n' "$BOLD" "$RESET"
    printf '  %s0.%s 返回\n' "$BOLD" "$RESET"
    echo
    read -r -p "请选择： " u || u=""
    local _want_ch=""
    case "$u" in
        1)
            _want_ch="any"
            want="${lat_any:-v${DEFAULT_NEWEST_VERSION}}"
            [ "$want" != "v${DEFAULT_NEWEST_VERSION}" ] || warn "未查到列表，使用内置版本 ${DEFAULT_NEWEST_VERSION}" ;;
        2)
            _want_ch="stable"
            [ -n "$lat_stable" ] || { warn "未查到正式版（网络受限或 GitHub API 被墙）"; pause; return 1; }
            want="$lat_stable" ;;
        3)
            echo
            info "正在获取版本列表 ..."
            local _list _ln=0
            _list="$(SINGBOX_CHANNEL=any list_singbox_versions | head -n 20)"
            if [ -z "$_list" ]; then
                warn "获取版本列表失败（网络受限）"; pause; return 1
            fi
            local -a _tags=()
            while IFS=$'\t' read -r _t _k; do
                [ -n "$_t" ] || continue
                _ln=$((_ln+1))
                _tags+=("$_t")
                if [ "$_k" = "测试版" ]; then
                    printf '  %s%2d.%s %-18s %s%s%s\n' "$BOLD" "$_ln" "$RESET" "$_t" "$DIM" "$_k" "$RESET"
                else
                    printf '  %s%2d.%s %-18s %s%s%s\n' "$BOLD" "$_ln" "$RESET" "$_t" "$GREEN" "$_k" "$RESET"
                fi
                [ "$_ln" -ge 20 ] && break
            done <<<"$_list"
            echo "   0. 返回"
            echo
            read -r -p "  请选择： " _li || _li=""
            [ "$_li" = "0" ] && return 0
            [[ "$_li" =~ ^[0-9]+$ ]] || { warn "无效选项"; pause; return 1; }
            [ "$_li" -ge 1 ] && [ "$_li" -le "${#_tags[@]}" ] || { warn "编号超出范围"; pause; return 1; }
            want="${_tags[$((_li-1))]}"
            _want_ch="" ;;
        4)
            echo
            echo "  ${DIM}版本号格式：1.14.2（正式版）/ 1.15.0-beta.3（测试版）${RESET}"
            echo "  ${DIM}完整列表见 https://github.com/SagerNet/sing-box/tags${RESET}"
            echo "  ${DIM}需要该版本有 linux-${ARCH} 的 Downloads 资源。${RESET}"
            echo
            read -r -p "  请输入版本号（直接回车取消）： " want || want=""
            want="$(printf '%s' "$want" | tr -d '[:space:]')"
            [ -n "$want" ] || { info "已取消"; pause; return 1; }
            if ! [[ "$want" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.]+)?$ ]]; then
                warn "版本号格式不合法：$want"; pause; return 1
            fi
            _want_ch="" ;;
        0) return 0 ;;
        *) warn "无效选项"; pause; return 1 ;;
    esac

    local tagver="${want#v}"
    if [ "$tagver" = "$cur" ]; then
        info "当前已经是该版本（$want）"
        echo
        echo "1. 强制重新安装"
        echo "0. 返回"
        read -r -p "请选择： " a || a=""
        [ "$a" = "1" ] || return 0
    else
        echo
        echo "  将切换：${BOLD}${cur:-未安装}${RESET}  →  ${GREEN}${want}${RESET}"
        echo
        echo "1. 确认"
        echo "0. 返回"
        read -r -p "请选择： " a || a=""
        [ "$a" = "1" ] || { info "已取消"; pause; return 0; }
    fi

    if [ -n "$_want_ch" ]; then
        SINGBOX_CHANNEL="$_want_ch"
        SINGBOX_WANT_VERSION=""
    fi
    save_settings
    backup
    progress 20 "备份当前内核"
    bak="${BIN}.bak"
    [ -x "$BIN" ] && cp -f "$BIN" "$bak" 2>/dev/null || true
    progress 40 "下载 sing-box ${want}"
    if ! download_singbox "$want"; then
        warn "下载失败，保持原版本"
        [ -x "$bak" ] && { mv -f "$bak" "$BIN" 2>/dev/null || true; }
        pause; return 1
    fi
    progress 70 "检查配置兼容性并重启服务"
    strip_http_version
    if validate && apply; then
        rm -f "$bak" 2>/dev/null || true
        progress 100 "完成"
        ok "sing-box 现在是 $(sb_version)"
        if http_version_supported && jq -e '(.inbounds // []) | any(.type == "http" and (has("version") | not))' "$CONF" >/dev/null 2>&1; then
            info "检测到有 HTTP/2 节点仍是兼容模式；删掉重建即可用上完整 HTTP/2 声明"
        fi
    else
        warn "校验 / 启动失败，正在回滚内核与配置"
        if [ -x "$bak" ]; then
            mv -f "$bak" "$BIN" 2>/dev/null || true
        else
            warn "未找到旧内核备份（$bak），请手动重装内核"
        fi
        if [ -n "$cur" ]; then printf '%s\n' "$cur" > "$VERSION_FILE" 2>/dev/null || true; fi
        rm -f "$BASE/.sbver.cache" 2>/dev/null || true
        SB_VERSION_CACHE=""
        rollback
        apply >/dev/null 2>&1 || true
        warn "已回滚到 ${cur:-原版本}"
    fi
    pause
}

service_summary(){
    local st="unknown" upt="" mem="" pid="" ver="" en="" cpu=""
    ver="$(sb_version)"
    if [ "$INIT" = systemd ] && command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet sing-box 2>/dev/null; then st="running"
        else st="stopped"; fi
        local props
        props="$(systemctl show sing-box \
            -p MainPID -p MemoryCurrent -p ActiveEnterTimestampMonotonic -p ExecMainStartTimestamp 2>/dev/null)"
        pid="$(printf '%s\n' "$props" | sed -n 's/^MainPID=\([0-9]*\)$/\1/p' | head -n1)"
        [ "$pid" = "0" ] && pid=""
        mem="$(printf '%s\n' "$props" | sed -n 's/^MemoryCurrent=\([0-9]*\)$/\1/p' | head -n1)"
        if [ -n "$mem" ] && [ "$mem" -gt 0 ] 2>/dev/null && [ "$mem" -lt 1099511627776 ]; then
            mem="$((mem / 1048576))M"
        else
            mem=""
        fi
        local mono now_sec
        mono="$(printf '%s\n' "$props" | sed -n 's/^ActiveEnterTimestampMonotonic=\([0-9]*\)$/\1/p' | head -n1)"
        if [ -n "$mono" ] && [ "$mono" -gt 0 ] 2>/dev/null && [ -r /proc/uptime ]; then
            now_sec="$(awk '{printf "%d", $1*1000000}' /proc/uptime 2>/dev/null)"
            if [ -n "$now_sec" ] && [ "$now_sec" -gt "$mono" ] 2>/dev/null; then
                upt="$(human_sec $(( (now_sec - mono) / 1000000 )))"
            fi
        fi
        systemctl is-enabled --quiet sing-box 2>/dev/null && en="自启"
    elif [ "$INIT" = openrc ] && command -v rc-service >/dev/null 2>&1; then
        if rc-service sing-box status >/dev/null 2>&1; then st="running"; else st="stopped"; fi
        if [ -r /run/sing-box.pid ]; then
            pid="$(cat /run/sing-box.pid 2>/dev/null)"
        fi
        rc-update show default 2>/dev/null | grep -q '^ *sing-box ' && en="自启"
    else
        if [ -f "$BASE/pid" ]; then
            pid="$(cat "$BASE/pid" 2>/dev/null)"
            [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && st="running" || st="stopped"
        else
            pid="$(pgrep -f "$BIN run -c $CONF" 2>/dev/null | head -n1)"
            [ -n "$pid" ] && st="running" || st="stopped"
        fi
    fi
    [ -n "$pid" ] || pid="$(pgrep -f "$BIN run -c $CONF" 2>/dev/null | head -n1)"
    if [ -z "$mem" ] && [ -n "$pid" ] && [ -r "/proc/$pid/status" ]; then
        mem="$(awk '/^VmRSS:/{printf "%dM", $2/1024}' "/proc/$pid/status" 2>/dev/null)"
    fi
    [ -n "$upt" ] || upt="$(human_sec "$(proc_elapsed_sec "$pid")")"
    if [ "$st" = "running" ] && [ -n "$pid" ]; then
        local cfile="$BASE/.cpu.cache" cnow cts="" cpid="" cval=""
        cnow="$(now_epoch)"
        if [ -s "$cfile" ]; then
            IFS=' ' read -r cts cpid cval < "$cfile" 2>/dev/null || true
        fi
        if [ -n "$cts" ] && [ "$cpid" = "$pid" ] && \
           [ -n "$cnow" ] && [ $(( cnow - cts )) -ge 0 ] && [ $(( cnow - cts )) -lt 5 ]; then
            cpu="$cval"
        else
            cpu="$(cpu_pct "$pid")"
            [ -n "$cnow" ] && printf '%s %s %s\n' "$cnow" "$pid" "$cpu" > "$cfile" 2>/dev/null || true
        fi
    fi
    printf '%s|%s|%s|%s|%s|%s|%s\n' "$st" "$upt" "$mem" "$pid" "$ver" "$en" "$cpu"
}
human_sec(){
    local s="${1:-}"
    [[ "$s" =~ ^[0-9]+$ ]] || { printf ''; return; }
    [ "$s" -le 0 ] && { printf ''; return; }
    local d=$((s/86400)) h=$(((s%86400)/3600)) m=$(((s%3600)/60))
    if [ "$d" -gt 0 ]; then printf '%d天%d小时' "$d" "$h"
    elif [ "$h" -gt 0 ]; then printf '%d小时%d分' "$h" "$m"
    elif [ "$m" -gt 0 ]; then printf '%d分钟' "$m"
    else printf '%d秒' "$s"; fi
}
proc_elapsed_sec(){
    local pid="${1:-}" st upt_s btime clk stime
    [ -n "$pid" ] || { printf ''; return; }
    [ -r "/proc/$pid/stat" ] || { printf ''; return; }
    st="$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null)"
    [[ "$st" =~ ^[0-9]+$ ]] || { printf ''; return; }
    upt_s="$(awk '{printf "%d", $1}' /proc/uptime 2>/dev/null)"
    [[ "$upt_s" =~ ^[0-9]+$ ]] || { printf ''; return; }
    clk="$(getconf CLK_TCK 2>/dev/null)"
    [[ "$clk" =~ ^[0-9]+$ ]] || clk=100
    printf '%d' $(( upt_s - st / clk ))
}
cpu_pct(){
    local pid="${1:-}" t1 t2 n1 n2 dticks dms v10
    [ -n "$pid" ] || { printf ''; return; }
    [ -r "/proc/$pid/stat" ] || { printf ''; return; }
    t1="$(awk '{print $14+$15}' "/proc/$pid/stat" 2>/dev/null)"
    n1="$(now_ms)"
    [[ "$t1" =~ ^[0-9]+$ ]] || { printf ''; return; }
    [[ "$n1" =~ ^[0-9]+$ ]] || { printf ''; return; }
    sleep 0.3
    [ -r "/proc/$pid/stat" ] || { printf ''; return; }
    t2="$(awk '{print $14+$15}' "/proc/$pid/stat" 2>/dev/null)"
    n2="$(now_ms)"
    [[ "$t2" =~ ^[0-9]+$ ]] || { printf ''; return; }
    [[ "$n2" =~ ^[0-9]+$ ]] || { printf ''; return; }
    dticks=$(( t2 - t1 ))
    dms=$(( n2 - n1 ))
    [ "$dticks" -ge 0 ] || { printf ''; return; }
    [ "$dms" -gt 0 ] || { printf ''; return; }
    local hz
    hz="$(getconf CLK_TCK 2>/dev/null)"
    [[ "$hz" =~ ^[0-9]+$ ]] && [ "$hz" -gt 0 ] || hz=100
    v10=$(( dticks * 1000000 / (hz * dms) ))
    printf '%d.%d' $(( v10 / 10 )) $(( v10 % 10 ))
}

urlencode(){
    jq -nr --arg x "$1" '$x|@uri'
}
b64(){ base64 2>/dev/null | tr -d '\n'; }
b64url(){ base64 2>/dev/null | tr -d '\n' | tr '+/' '-_' | tr -d '='; }

cert_sha256_pcs(){
    local cache="${CERTDIR}/.pcs.hex.cache"
    if [ -s "$cache" ]; then
        cat "$cache"
        return 0
    fi
    rm -f "${CERTDIR}/.pcs.cache" 2>/dev/null || true
    [ -s "$CERTDIR/server.crt" ] || return 1
    command -v openssl >/dev/null 2>&1 || return 1
    local v
    v="$(openssl x509 -in "$CERTDIR/server.crt" -outform der 2>/dev/null \
        | openssl dgst -sha256 -hex 2>/dev/null \
        | awk '{print $NF}' | tr -d '\n')"
    [[ "$v" =~ ^[0-9a-f]{64}$ ]] || return 1
    printf '%s' "$v" > "$cache" 2>/dev/null || true
    printf '%s' "$v"
}

cert_fingerprint_clash(){
    local cache="${CERTDIR}/.clashfp.cache"
    if [ -s "$cache" ]; then
        cat "$cache"
        return 0
    fi
    [ -s "$CERTDIR/server.crt" ] || return 1
    command -v openssl >/dev/null 2>&1 || return 1
    local v
    v="$(openssl x509 -fingerprint -noout -sha256 -in "$CERTDIR/server.crt" 2>/dev/null \
        | awk -F '=' '{print $NF}' | tr -d '\n')"
    [[ "$v" =~ ^([0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}$ ]] || return 1
    printf '%s' "$v" > "$cache" 2>/dev/null || true
    printf '%s' "$v"
}

link_for_node(){
    local row="$1"
    local name type port uuidv pw sni extra pub sid
    name="$(jq -r '.name' <<<"$row")";   type="$(jq -r '.type' <<<"$row")"
    port="$(jq -r '.port' <<<"$row")"
    uuidv="$(jq -r '.uuid // empty' <<<"$row")"; pw="$(jq -r '.password // empty' <<<"$row")"
    sni="$(jq -r '.sni // empty' <<<"$row")";    extra="$(jq -r '.extra // empty' <<<"$row")"
    pub="$(jq -r '.public_key // empty' <<<"$row")"; sid="$(jq -r '.short_id // empty' <<<"$row")"
    local flow_q=""
    local pcs_q="" _ai=0
    local _pcs=""
    if [ "${LINK_ALLOW_INSECURE:-0}" = "1" ]; then
        pcs_q="&allowInsecure=1&insecure=1"
        _ai=1
    else
        _pcs="$(cert_sha256_pcs 2>/dev/null)"
        [ -n "$_pcs" ] && pcs_q="&pcs=$(urlencode "$_pcs")"
    fi
    local uot_q=""
    if [ "$UOT_ENABLED" = "1" ]; then
        case "$type" in
          hysteria2|hy2-obfs|hy2-realm|tuic|http3) uot_q="" ;;
          *) uot_q="&udp-over-tcp=true&udp-over-tcp-version=2" ;;
        esac
    fi
    case "$type" in
      vless-reality)
        [ -n "$extra" ] && flow_q="&flow=$(urlencode "$extra")"
        printf '%s\n' "vless://${uuidv}@${SERVER_IP}:${port}?encryption=none&security=reality&sni=$(urlencode "$sni")&fp=${FINGERPRINT:-chrome}${flow_q}&pbk=${pub}&sid=${sid}&type=tcp&headerType=none${uot_q}#$(urlencode "$name")" ;;
      vless-ws-tls)
        printf '%s\n' "vless://${uuidv}@${SERVER_IP}:${port}?encryption=none&security=tls&type=ws&host=$(urlencode "$sni")&sni=$(urlencode "$sni")&path=$(urlencode "$extra")${pcs_q}${uot_q}#$(urlencode "$name")" ;;
      vmess-ws-tls)
        if [ "$UOT_ENABLED" = "1" ]; then
            jq -n --arg v "2" --arg ps "$name" --arg add "$SERVER_IP" --argjson port "$port" --arg id "$uuidv" --arg host "$sni" --arg path "$extra" --arg pcs "$_pcs" --argjson ai "$_ai" '{v:$v,ps:$ps,add:$add,port:$port,id:$id,aid:0,scy:"auto",net:"ws",type:"none",host:$host,path:$path,tls:"tls",sni:$host,alpn:"",fp:""} + (if $ai == 1 then {"allowInsecure":true} else {pcs:$pcs} end) + {"udp-over-tcp":true,"udp-over-tcp-version":2}' | b64 | sed 's/^/vmess:\/\//'
        else
            jq -n --arg v "2" --arg ps "$name" --arg add "$SERVER_IP" --argjson port "$port" --arg id "$uuidv" --arg host "$sni" --arg path "$extra" --arg pcs "$_pcs" --argjson ai "$_ai" '{v:$v,ps:$ps,add:$add,port:$port,id:$id,aid:0,scy:"auto",net:"ws",type:"none",host:$host,path:$path,tls:"tls",sni:$host,alpn:"",fp:""} + (if $ai == 1 then {"allowInsecure":true} else {pcs:$pcs} end)' | b64 | sed 's/^/vmess:\/\//'
        fi ;;
      trojan)
        printf '%s\n' "trojan://${pw}@${SERVER_IP}:${port}?security=tls&sni=$(urlencode "$sni")&type=tcp&headerType=none${pcs_q}${uot_q}#$(urlencode "$name")" ;;
      shadowsocks)
        local ss_q=""
        [ "$UOT_ENABLED" = "1" ] && ss_q="?udp-over-tcp=true&udp-over-tcp-version=2"
        printf '%s\n' "ss://$(printf '%s:%s' "$extra" "$pw" | b64)@${SERVER_IP}:${port}${ss_q}#$(urlencode "$name")" ;;
      hysteria2)
        printf '%s\n' "hysteria2://${pw}@${SERVER_IP}:${port}?security=tls&sni=$(urlencode "$sni")&alpn=h3&insecure=1#$(urlencode "$name")" ;;
      hy2-obfs)
        printf '%s\n' "hysteria2://${pw}@${SERVER_IP}:${port}?security=tls&sni=$(urlencode "$sni")&alpn=h3&obfs=salamander&obfs-password=$(urlencode "$extra")&insecure=1#$(urlencode "$name")" ;;
      hy2-realm)
        printf '%s\n' "hysteria2://${pw}@${SERVER_IP}:${port}?security=tls&sni=$(urlencode "$sni")&alpn=h3&insecure=1#$(urlencode "$name")" ;;
      tuic)
        printf '%s\n' "tuic://${uuidv}:${pw}@${SERVER_IP}:${port}?congestion_control=bbr&alpn=h3&sni=$(urlencode "$sni")&udp_relay_mode=native&allow_insecure=1#$(urlencode "$name")" ;;
      anytls)
        printf '%s\n' "anytls://${pw}@${SERVER_IP}:${port}?security=tls&sni=$(urlencode "$sni")&insecure=1${uot_q}#$(urlencode "$name")" ;;
      naive)
        printf '%s\n' "naive+https://$(urlencode "$uuidv"):$(urlencode "$pw")@${SERVER_IP}:${port}?sni=$(urlencode "$sni")&insecure=1${uot_q}#$(urlencode "$name")" ;;
      h2-reality)
        printf '%s\n' "vless://${uuidv}@${SERVER_IP}:${port}?encryption=none&security=reality&sni=$(urlencode "$sni")&alpn=h2&fp=${FINGERPRINT:-chrome}&pbk=${pub}&sid=${sid}&type=http&host=$(urlencode "$sni")&path=%2F${uot_q}#$(urlencode "$name")" ;;
      grpc-reality)
        printf '%s\n' "vless://${uuidv}@${SERVER_IP}:${port}?encryption=none&security=reality&sni=$(urlencode "$sni")&fp=${FINGERPRINT:-chrome}&pbk=${pub}&sid=${sid}&type=grpc&serviceName=$(urlencode "$extra")&mode=gun${uot_q}#$(urlencode "$name")" ;;
      shadowtls)
        local stl_plugin
        stl_plugin="$(jq -nc --arg host "$sni" --arg pw "$pw" '{version:"3",host:$host,password:$pw}' | b64url)"
        printf '%s\n' "ss://$(printf '%s:%s' "2022-blake3-aes-128-gcm" "$pw" | b64)@${SERVER_IP}:${port}?shadow-tls=${stl_plugin}#$(urlencode "$name")" ;;
      http2)
        printf '%s\n' "http://${uuidv}:${pw}@${SERVER_IP}:${port}/?protocol=https&sni=$(urlencode "$sni")&insecure=1${uot_q}#$(urlencode "$name")" ;;
      http3)
        printf '%s\n' "http://${uuidv}:${pw}@${SERVER_IP}:${port}/?protocol=h3&sni=$(urlencode "$sni")&insecure=1#$(urlencode "$name")" ;;
      *)
        return 1 ;;
    esac
}

show_links(){
    get_ip
    panel "节点链接"
    kv "服务器" "$SERVER_IP"
    [ "$UOT_ENABLED" = "1" ] && kv "UoT" "${GREEN}已开启（链接已附带 udp-over-tcp 参数）${RESET}"
    local total n=0 row link
    total="$(jq 'length' "$NODES" 2>/dev/null || echo 0)"
    if [ "$total" -eq 0 ]; then
        warn "暂无节点"
        return
    fi
    hr
    while IFS= read -r row; do
        n=$((n+1))
        local name proto port pt
        name="$(jq -r '.name' <<<"$row")"
        proto="$(jq -r '.proto' <<<"$row")"
        port="$(jq -r '.port' <<<"$row")"
        if [ "$proto" = "udp" ]; then pt="${CYAN}UDP${RESET}"; else pt="${DIM}TCP${RESET}"; fi
        printf '\n  %s%s[%d]%s %s%s%s   %s/ %s\n' \
            "$BOLD" "$MAGENTA" "$n" "$RESET" \
            "$BOLD" "$name" "$RESET" "$pt" "$port"
        link="$(link_for_node "$row")"
        if [ -n "$link" ]; then
            printf '  %s└─%s %s\n' "$DIM" "$RESET" "$link"
        else
            printf '  %s└─ （该协议暂无链接规则）%s\n' "$DIM" "$RESET"
        fi
    done < <(jq -c '.[]' "$NODES")
    hr
    info "共 ${n} 个节点。选中链接整行复制即可导入客户端。"
}

goto_sub(){
    echo
    hr
    printf '  %s订阅已就绪，一个 URL 适配所有客户端：%s\n' "$BOLD" "$RESET"
    printf '    %s·%s V2rayN / v2rayNG / 小火箭 / Throne  %s自动给 base64 订阅%s\n' \
        "$CYAN" "$RESET" "$DIM" "$RESET"
    printf '    %s·%s Clash Verge / mihomo / Stash         %s自动给 YAML 配置%s\n' \
        "$CYAN" "$RESET" "$DIM" "$RESET"
    printf '    %s·%s Sing-box (SFI / SFA / SFM)           %s自动给 JSON 配置%s\n' \
        "$CYAN" "$RESET" "$DIM" "$RESET"
    hr
    local url
    url="$(sub_url 2>/dev/null)"
    if [ "$(sub_status 2>/dev/null)" = "on" ] && [ -n "$url" ]; then
        printf '  %s订阅地址%s %s\n' "$DIM" "$RESET" "$url"
        printf '  %s把这个地址填进客户端的「订阅」栏即可，无需逐条导入。%s\n' "$DIM" "$RESET"
    else
        printf '  %s订阅 HTTP 服务未启动 → 进订阅区可一键开启（拿到上面这类地址）%s\n' \
            "$YELLOW" "$RESET"
    fi
    echo
    while :; do
        read -r -p "  进入「订阅与节点链接」？[Y/n] " a || a=""
        case "${a:-Y}" in
            [Yy]*|"") sub_menu; break ;;
            [Nn]*)    break ;;
            *) warn "请输入 Y（进入）或 n（跳过）" ;;
        esac
    done
}

have_qrencode(){ command -v qrencode >/dev/null 2>&1; }

qr_terminal(){
    local data="$1"
    have_qrencode || { warn "未安装 qrencode，无法显示二维码"; return 1; }
    local cols
    cols="$(tput cols 2>/dev/null || echo 80)"
    if [ "$cols" -lt 125 ]; then
        warn "当前终端宽 ${cols} 列，长链接二维码需要约 125 列，可能折行导致扫不出来"
        warn "建议先执行 stty cols 140 或拉宽窗口后重试"
    fi
    qrencode -t ANSIUTF8 -l L -m 2 "$data"
}

show_qr_for_node(){
    local idx="$1"
    local row link name
    row="$(jq -c ".[$idx]" "$NODES" 2>/dev/null)"
    [ -n "$row" ] || { warn "节点不存在"; return 1; }
    name="$(jq -r '.name' <<<"$row")"
    link="$(link_for_node "$row")" || { warn "该协议暂无链接规则，无法生成二维码"; return 1; }
    [ -n "$link" ] || { warn "该协议暂无链接规则，无法生成二维码"; return 1; }

    echo
    echo "${BOLD}【$((idx+1))】$name${RESET}"
    echo "$link"
    echo
    qr_terminal "$link"
}

show_qr_all(){
    local total
    total="$(jq 'length' "$NODES" 2>/dev/null || echo 0)"
    if [ "$total" -eq 0 ]; then warn "暂无节点"; return; fi
    local i
    for ((i=0; i<total; i++)); do
        show_qr_for_node "$i"
        [ "$i" -lt $((total-1)) ] && { echo; echo "----------------------------------------"; }
    done
}

export_clash(){
    mkdir -p "$SUBDIR"
    get_ip
    local proxies="" row name type port uuidv pw sni extra pub sid fp cfp tls_verify
    fp="${FINGERPRINT:-chrome}"
    cfp="$(cert_fingerprint_clash 2>/dev/null)"
    if [ -n "$cfp" ]; then
        tls_verify="skip-cert-verify: false, fingerprint: ${cfp}"
    else
        tls_verify="skip-cert-verify: true"
    fi
    while IFS= read -r row; do
        name="$(jq -r '.name' <<<"$row")";   type="$(jq -r '.type' <<<"$row")"
        port="$(jq -r '.port' <<<"$row")"
        uuidv="$(jq -r '.uuid // empty' <<<"$row")"; pw="$(jq -r '.password // empty' <<<"$row")"
        sni="$(jq -r '.sni // empty' <<<"$row")";    extra="$(jq -r '.extra // empty' <<<"$row")"
        pub="$(jq -r '.public_key // empty' <<<"$row")"; sid="$(jq -r '.short_id // empty' <<<"$row")"
        local safe_name; safe_name="$(printf '%s' "$name" | sed 's/\\/\\\\/g; s/"/\\"/g')"
        local uot=""
        if [ "$UOT_ENABLED" = "1" ]; then
            case "$type" in
              hysteria2|hy2-obfs|hy2-realm|tuic|http3) uot="" ;;
              *) uot=", udp-over-tcp: true" ;;
            esac
        fi
        local entry=""
        case "$type" in
          vless-reality) entry="{name: \"${safe_name}\", type: vless, server: \"${SERVER_IP}\", port: ${port}, uuid: ${uuidv}, network: tcp, tls: true, udp: true, flow: xtls-rprx-vision, servername: ${sni}, client-fingerprint: ${fp}, reality-opts: {public-key: ${pub}, short-id: \"${sid}\"}, skip-cert-verify: true${uot}}" ;;
          h2-reality)    entry="{name: \"${safe_name}\", type: vless, server: \"${SERVER_IP}\", port: ${port}, uuid: ${uuidv}, network: http, tls: true, udp: true, servername: ${sni}, client-fingerprint: ${fp}, reality-opts: {public-key: ${pub}, short-id: \"${sid}\"}, skip-cert-verify: true${uot}}" ;;
          grpc-reality)  entry="{name: \"${safe_name}\", type: vless, server: \"${SERVER_IP}\", port: ${port}, uuid: ${uuidv}, network: grpc, grpc-opts: {grpc-service-name: \"${extra}\"}, tls: true, udp: true, servername: ${sni}, client-fingerprint: ${fp}, reality-opts: {public-key: ${pub}, short-id: \"${sid}\"}, skip-cert-verify: true${uot}}" ;;
          vless-ws-tls)  entry="{name: \"${safe_name}\", type: vless, server: \"${SERVER_IP}\", port: ${port}, uuid: ${uuidv}, network: ws, ws-opts: {path: \"${extra}\"}, tls: true, udp: true, servername: ${sni}, ${tls_verify}${uot}}" ;;
          vmess-ws-tls)  entry="{name: \"${safe_name}\", type: vmess, server: \"${SERVER_IP}\", port: ${port}, uuid: ${uuidv}, alterId: 0, cipher: auto, network: ws, ws-opts: {path: \"${extra}\"}, tls: true, udp: true, servername: ${sni}, ${tls_verify}${uot}}" ;;
          trojan)        entry="{name: \"${safe_name}\", type: trojan, server: \"${SERVER_IP}\", port: ${port}, password: \"${pw}\", udp: true, sni: ${sni}, client-fingerprint: ${fp}, ${tls_verify}${uot}}" ;;
          anytls)        entry="{name: \"${safe_name}\", type: anytls, server: \"${SERVER_IP}\", port: ${port}, password: \"${pw}\", udp: true, sni: ${sni}, ${tls_verify}${uot}}" ;;
          shadowsocks)   entry="{name: \"${safe_name}\", type: ss, server: \"${SERVER_IP}\", port: ${port}, cipher: ${extra}, password: \"${pw}\", udp: true${uot}}" ;;
          hysteria2|hy2-obfs|hy2-realm) entry="{name: \"${safe_name}\", type: hysteria2, server: \"${SERVER_IP}\", port: ${port}, password: \"${pw}\", sni: ${sni}, ${tls_verify}}" ;;
          tuic)          entry="{name: \"${safe_name}\", type: tuic, server: \"${SERVER_IP}\", port: ${port}, uuid: ${uuidv}, password: \"${pw}\", alpn: [h3], sni: ${sni}, ${tls_verify}}" ;;
          shadowtls)     entry="{name: \"${safe_name}\", type: ss, server: \"${SERVER_IP}\", port: ${port}, cipher: 2022-blake3-aes-128-gcm, password: \"${pw}\", plugin: shadow-tls, client-fingerprint: ${fp}, plugin-opts: {host: ${sni}, password: \"${pw}\", version: 3}, ${tls_verify}}" ;;
          naive)         entry="{name: \"${safe_name}\", type: http, server: \"${SERVER_IP}\", port: ${port}, username: ${uuidv}, password: \"${pw}\", tls: true, sni: ${sni}, ${tls_verify}}" ;;
          *)             continue ;;
        esac
        [ -n "$entry" ] || continue
        if [ -z "$proxies" ]; then proxies="  - $entry"; else proxies="$proxies
  - $entry"; fi
    done < <(jq -c '.[]' "$NODES" 2>/dev/null)

    local names=""
    names="$(jq -r '.[].name' "$NODES" 2>/dev/null | while IFS= read -r n; do
        printf '      - "%s"\n' "$(printf '%s' "$n" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    done)"

    {
      echo "# Generated by singbox-nat / sing-box NAT ${VERSION}"
      echo "# 自签证书节点已用 fingerprint 锁定证书指纹（skip-cert-verify: false）"
      echo "mixed-port: 7890"
      echo "allow-lan: false"
      echo "mode: rule"
      echo "log-level: warning"
      echo "external-controller: 127.0.0.1:9090"
      echo "geo-auto-update: true"
      echo "geo-update-interval: 24"
      if [ -z "$proxies" ]; then
        echo "proxies: []"
        echo "proxy-groups:"
        echo "  - name: PROXY"
        echo "    type: select"
        echo "    proxies:"
        echo "      - DIRECT"
        echo "  - name: AUTO"
        echo "    type: url-test"
        echo "    url: \"https://www.gstatic.com/generate_204\""
        echo "    interval: 300"
        echo "    tolerance: 50"
        echo "    proxies:"
        echo "      - DIRECT"
        echo "rules:"
        echo "  - MATCH,PROXY"
      else
        echo "proxies:"
        echo "$proxies"
        echo "proxy-groups:"
        echo "  - name: PROXY"
        echo "    type: select"
        echo "    proxies:"
        echo "      - AUTO"
        echo "$names"
        echo "  - name: AUTO"
        echo "    type: url-test"
        echo "    url: \"https://www.gstatic.com/generate_204\""
        echo "    interval: 300"
        echo "    tolerance: 50"
        echo "    proxies:"
        echo "$names"
        echo "rules:"
        echo "  - GEOIP,private,DIRECT,no-resolve"
        echo "  - GEOSITE,category-ads-all,REJECT"
        echo "  - GEOSITE,openai,PROXY"
        echo "  - DOMAIN-SUFFIX,gemini.google.com,PROXY"
        echo "  - DOMAIN-SUFFIX,aistudio.google.com,PROXY"
        echo "  - DOMAIN-SUFFIX,generativelanguage.googleapis.com,PROXY"
        echo "  - DOMAIN-SUFFIX,anthropic.com,PROXY"
        echo "  - DOMAIN-SUFFIX,claude.ai,PROXY"
        echo "  - GEOSITE,netflix,PROXY"
        echo "  - GEOSITE,disney,PROXY"
        echo "  - GEOSITE,telegram,PROXY"
        echo "  - GEOSITE,cn,DIRECT"
        echo "  - GEOIP,cn,DIRECT"
        echo "  - MATCH,PROXY"
      fi
    } >"$SUBDIR/clash.yaml"

    b64 <"$SUBDIR/clash.yaml" >"$SUBDIR/clash_subscribe.txt"
}

link_v2rayn_for_node(){
    local row="$1"
    local name type port uuidv pw sni extra pub sid
    name="$(jq -r '.name' <<<"$row")";   type="$(jq -r '.type' <<<"$row")"
    port="$(jq -r '.port' <<<"$row")"
    uuidv="$(jq -r '.uuid // empty' <<<"$row")"; pw="$(jq -r '.password // empty' <<<"$row")"
    sni="$(jq -r '.sni // empty' <<<"$row")";    extra="$(jq -r '.extra // empty' <<<"$row")"
    pub="$(jq -r '.public_key // empty' <<<"$row")"; sid="$(jq -r '.short_id // empty' <<<"$row")"

    local _b64=""
    case "$type" in
      hysteria2)
        _b64="$(jq -nc --arg ps "$name" --arg add "$SERVER_IP" --argjson port "$port" \
            --arg pw "$pw" --arg sni "$sni" --argjson ver 4 \
            '{ConfigType:7,CoreType:24,ConfigVersion:$ver,Remarks:$ps,Address:$add,Port:$port,
              Password:$pw,StreamSecurity:"tls",AllowInsecure:"true",Sni:$sni}' | b64url)" ;;
      hy2-obfs)
        _b64="$(jq -nc --arg ps "$name" --arg add "$SERVER_IP" --argjson port "$port" \
            --arg pw "$pw" --arg sni "$sni" --arg obfs "$extra" --argjson ver 4 \
            '{ConfigType:7,CoreType:24,ConfigVersion:$ver,Remarks:$ps,Address:$add,Port:$port,
              Password:$pw,StreamSecurity:"tls",AllowInsecure:"true",Sni:$sni,
              ProtoExtraObj:{Obfs:"salamander",ObfsPassword:$obfs}}' | b64url)" ;;
      hy2-realm)
        _b64="$(jq -nc --arg ps "$name" --arg add "$SERVER_IP" --argjson port "$port" \
            --arg pw "$pw" --arg sni "$sni" --argjson ver 4 \
            '{ConfigType:7,CoreType:24,ConfigVersion:$ver,Remarks:$ps,Address:$add,Port:$port,
              Password:$pw,StreamSecurity:"tls",AllowInsecure:"true",Sni:$sni}' | b64url)" ;;
      tuic)
        _b64="$(jq -nc --arg ps "$name" --arg add "$SERVER_IP" --argjson port "$port" \
            --arg pw "$pw" --arg u "$uuidv" --arg sni "$sni" --argjson ver 4 \
            '{ConfigType:8,CoreType:24,ConfigVersion:$ver,Remarks:$ps,Address:$add,Port:$port,
              Password:$pw,Username:$u,StreamSecurity:"tls",AllowInsecure:"true",Sni:$sni,
              Alpn:"h3",ProtoExtraObj:{CongestionControl:"bbr"}}' | b64url)" ;;
      anytls)
        _b64="$(jq -nc --arg ps "$name" --arg add "$SERVER_IP" --argjson port "$port" \
            --arg pw "$pw" --arg sni "$sni" --arg fp "${FINGERPRINT:-chrome}" --argjson ver 4 \
            '{ConfigType:11,CoreType:24,ConfigVersion:$ver,Remarks:$ps,Address:$add,Port:$port,
              Password:$pw,StreamSecurity:"tls",AllowInsecure:"true",Sni:$sni,Fingerprint:$fp}' | b64url)" ;;
      naive)
        _b64="$(jq -nc --arg ps "$name" --arg add "$SERVER_IP" --argjson port "$port" \
            --arg pw "$pw" --arg u "$uuidv" --arg sni "$sni" --argjson ver 4 \
            '{ConfigType:12,CoreType:24,ConfigVersion:$ver,Remarks:$ps,Address:$add,Port:$port,
              Password:$pw,Username:$u,StreamSecurity:"tls",AllowInsecure:"true",Sni:$sni}' | b64url)" ;;
      shadowtls)
        _b64="$(jq -nc --arg ps "$name" --arg add "$SERVER_IP" --argjson port "$port" \
            --arg pw "$pw" --arg sni "$sni" --argjson ver 4 \
            '{ConfigType:3,CoreType:24,ConfigVersion:$ver,Remarks:$ps,Address:$add,Port:$port,
              Password:$pw,Method:"2022-blake3-aes-128-gcm",StreamSecurity:"tls",
              AllowInsecure:"true",Sni:$sni,ProtoExtraObj:{ShadowTlsVersion:3,ShadowTlsHost:$sni,ShadowTlsPassword:$pw}}' | b64url)" ;;
      http2)
        _b64="$(jq -nc --arg ps "$name" --arg add "$SERVER_IP" --argjson port "$port" \
            --arg pw "$pw" --arg u "$uuidv" --arg sni "$sni" --argjson ver 4 \
            '{ConfigType:10,CoreType:24,ConfigVersion:$ver,Remarks:$ps,Address:$add,Port:$port,
              Password:$pw,Username:$u,StreamSecurity:"tls",AllowInsecure:"true",Sni:$sni}' | b64url)" ;;
      http3)
        _b64="$(jq -nc --arg ps "$name" --arg add "$SERVER_IP" --argjson port "$port" \
            --arg pw "$pw" --arg u "$uuidv" --arg sni "$sni" --argjson ver 4 \
            '{ConfigType:10,CoreType:24,ConfigVersion:$ver,Remarks:$ps,Address:$add,Port:$port,
              Password:$pw,Username:$u,StreamSecurity:"tls",AllowInsecure:"true",Sni:$sni,
              ProtoExtraObj:{CongestionControl:"bbr",NaiveQuic:true}}' | b64url)" ;;
      vless-reality)
        return 1 ;;
      *) return 1 ;;
    esac
    [ -n "$_b64" ] || return 1
    printf 'v2rayn://%s/%s' "$(v2rayn_proto_name "$type")" "$_b64"
}

v2rayn_proto_name(){
    case "$1" in
      hysteria2|hy2-obfs|hy2-realm) echo "hysteria2" ;;
      tuic)      echo "tuic" ;;
      anytls)    echo "anytls" ;;
      naive)     echo "naive" ;;
      shadowtls) echo "shadowsocks" ;;
      http2|http3) echo "http" ;;
      *)         echo "" ;;
    esac
}

export_v2rayn(){
    mkdir -p "$SUBDIR"
    get_ip
    local plain="$SUBDIR/v2rayn_raw.txt"
    : >"$plain"
    local row link
    while IFS= read -r row; do
        link="$(link_v2rayn_for_node "$row" 2>/dev/null)" || link=""
        [ -n "$link" ] || link="$(link_for_node "$row" 2>/dev/null)" || link=""
        [ -n "$link" ] && printf '%s\n' "$link" >>"$plain"
    done < <(jq -c '.[]' "$NODES" 2>/dev/null)

    b64 <"$plain" >"$SUBDIR/v2rayn_subscribe.txt"
}

export_shadowrocket(){
    mkdir -p "$SUBDIR"
    get_ip
    local plain="$SUBDIR/shadowrocket_raw.txt"
    : >"$plain"
    local row link
    local LINK_ALLOW_INSECURE=1
    while IFS= read -r row; do
        link="$(link_for_node "$row" 2>/dev/null)" || link=""
        [ -n "$link" ] && printf '%s\n' "$link" >>"$plain"
    done < <(jq -c '.[]' "$NODES" 2>/dev/null)
    b64 <"$plain" >"$SUBDIR/shadowrocket_subscribe.txt"
}

export_all(){
    get_ip
    export_clash
    export_v2rayn
    export_shadowrocket
}
show_nodes(){
    get_ip
    local total
    total="$(jq 'length' "$NODES" 2>/dev/null || echo 0)"
    if [ "$total" -eq 0 ]; then
        panel "节点信息"
        warn "暂无节点"
        return
    fi
    panel "节点信息"
    if [ -n "${COUNTRY_NAME:-}" ]; then
        kv "服务器" "${COUNTRY_NAME}${COUNTRY_CODE:+ ($COUNTRY_CODE)}"
    fi
    kv "地址" "$SERVER_IP"
    kv "节点数" "${total} 个"
    local srv_ver
    srv_ver="$(sb_version)"
    kv "内核" "${srv_ver:-未知}   ${DIM}指纹 ${FINGERPRINT}  UoT $([ "$UOT_ENABLED" = 1 ] && echo 开 || echo 关)${RESET}"
    local synopsis
    synopsis="$(jq -r 'group_by(.type)[] | "\(.[0].type)×\(length)"' "$NODES" 2>/dev/null | paste -sd '  ' -)"
    [ -n "$synopsis" ] && kv "组成" "$synopsis"
    local i=0 row
    while IFS= read -r row; do
        i=$((i+1))
        local name type proto port pt uuidpw pw sni extra pubkey sid
        name="$(jq -r '.name' <<<"$row")"
        type="$(jq -r '.type' <<<"$row")"
        proto="$(jq -r '.proto' <<<"$row")"
        port="$(jq -r '.port' <<<"$row")"
        uuidpw="$(jq -r '.uuid // empty' <<<"$row")"
        pw="$(jq -r '.password // empty' <<<"$row")"
        [ -n "$uuidpw" ] || uuidpw="$pw"
        sni="$(jq -r '.sni // empty' <<<"$row")"
        extra="$(jq -r '.extra // empty' <<<"$row")"
        pubkey="$(jq -r '.public_key // empty' <<<"$row")"
        sid="$(jq -r '.short_id // empty' <<<"$row")"
        if [ "$proto" = "udp" ]; then pt="${CYAN}UDP${RESET}"; else pt="${DIM}TCP${RESET}"; fi

        hr
        printf '  %s%s[%2d]%s  %s%s%s   %s%s%s\n' \
            "$BOLD" "$MAGENTA" "$i" "$RESET" "$BOLD" "$name" "$RESET" "$DIM" "$type" "$RESET"
        kvf 4 "地址" "${SERVER_IP}  ${pt} / ${port}${RESET}"
        local uid_label="密码"
        case "$type" in
            vless-reality|vless-ws-tls|vmess-ws-tls|tuic|h2-reality|grpc-reality) uid_label="UUID" ;;
            http2|http3|naive)                                                    uid_label="用户名" ;;
        esac
        [ -n "$uuidpw" ] && kvf 6 "$uid_label" "$uuidpw"
        [ -n "$pw" ] && [ -n "$(jq -r '.uuid // empty' <<<"$row")" ] && kvf 6 "密码" "$pw"
        [ -n "$sni" ]    && kvf 6 "SNI" "$sni"
        [ -n "$extra" ]  && kvf 6 "额外" "$extra"
        if [ -n "$pubkey" ] || [ -n "$sid" ]; then
            printf '      %sReality%s\n' "$DIM" "$RESET"
            [ -n "$pubkey" ] && kvf 6 "公钥" "$pubkey"
            [ -n "$sid" ]    && kvf 6 "ShortID" "$sid"
        fi
        local nlink
        nlink="$(link_for_node "$row" 2>/dev/null)"
        [ -n "$nlink" ] && printf '      %s└─%s  %s%s%s\n' "$DIM" "$RESET" "$CYAN" "$nlink" "$RESET"
    done < <(jq -c '.[]' "$NODES")
    hr
    info "共 ${i} 个节点；完整链接见「订阅与节点链接」，或「管理节点 → 5」扫码导入。"
}
copy_links(){
    get_ip
    local out="" row link count=0 data=""
    while IFS= read -r row; do
        link="$(link_for_node "$row")" || continue
        [ -n "$link" ] || continue
        out="${out}${link}
"
        count=$((count+1))
    done < <(jq -c '.[]' "$NODES" 2>/dev/null)
    [ "$count" -gt 0 ] || { warn "没有可复制的节点链接"; return; }
    data="$(printf '%s' "$out" | b64)"
    printf '\033]52;c;%s\a' "$data"
    echo
    echo "已发送 OSC52 复制指令（共 ${count} 条）；终端支持时可直接粘贴。"
}

copy_text(){
    local text="$1"
    [ -n "$text" ] || { warn "没有可复制的内容"; return 1; }
    printf '\033]52;c;%s\a' "$(printf '%s' "$text" | b64)"
    echo "已发送 OSC52 复制指令（终端支持时可直接粘贴）。"
}

sub_token(){
    local f="$SUBHTTP_TOKEN"
    if [ ! -s "$f" ]; then
        mkdir -p "$BASE"
        if command -v openssl >/dev/null 2>&1; then
            openssl rand -hex 16 > "$f" 2>/dev/null
        else
            printf '%s%s%s' "$RANDOM$RANDOM" "$(now_ms)" "$RANDOM$RANDOM" \
                | md5sum | cut -c1-32 > "$f" 2>/dev/null
        fi
        chmod 600 "$f" 2>/dev/null || true
    fi
    cat "$f" 2>/dev/null
}
sub_rotate_token(){
    rm -f "$SUBHTTP_TOKEN" 2>/dev/null || true
    sub_token >/dev/null
    sub_restart >/dev/null 2>&1 || true
}

export_singbox_json(){
    mkdir -p "$SUBDIR"
    get_ip
    local out=""
    local row
    while IFS= read -r row; do
        local name type port uuidv pw sni extra pub sid ob
        name="$(jq -r '.name' <<<"$row")"; type="$(jq -r '.type' <<<"$row")"
        port="$(jq -r '.port' <<<"$row")"
        uuidv="$(jq -r '.uuid // empty' <<<"$row")"; pw="$(jq -r '.password // empty' <<<"$row")"
        sni="$(jq -r '.sni // empty' <<<"$row")";   extra="$(jq -r '.extra // empty' <<<"$row")"
        pub="$(jq -r '.public_key // empty' <<<"$row")"; sid="$(jq -r '.short_id // empty' <<<"$row")"
        ob=""
        case "$type" in
          vless-reality)
            ob="$(jq -nc --arg t "$name" --arg s "$SERVER_IP" --argjson p "$port" --arg u "$uuidv" --arg sn "$sni" --arg f "${FINGERPRINT:-chrome}" --arg pb "$pub" --arg sd "$sid" --arg fl "$extra" \
              '{type:"vless",tag:$t,server:$s,server_port:$p,uuid:$u,flow:($fl|if .=="" then null else . end),
                tls:{enabled:true,server_name:$sn,utls:{enabled:true,fingerprint:$f},
                     reality:{enabled:true,public_key:$pb,short_id:$sd}}}' 2>/dev/null)" ;;
          vless-ws-tls)
            ob="$(jq -nc --arg t "$name" --arg s "$SERVER_IP" --argjson p "$port" --arg u "$uuidv" --arg sn "$sni" --arg pa "$extra" \
              '{type:"vless",tag:$t,server:$s,server_port:$p,uuid:$u,
                tls:{enabled:true,server_name:$sn,insecure:true},
                transport:{type:"ws",path:$pa,headers:{Host:$sn}}}' 2>/dev/null)" ;;
          trojan)
            ob="$(jq -nc --arg t "$name" --arg s "$SERVER_IP" --argjson p "$port" --arg pw "$pw" --arg sn "$sni" \
              '{type:"trojan",tag:$t,server:$s,server_port:$p,password:$pw,
                tls:{enabled:true,server_name:$sn,insecure:true}}' 2>/dev/null)" ;;
          hysteria2|hy2-obfs|hy2-realm)
            ob="$(jq -nc --arg t "$name" --arg s "$SERVER_IP" --argjson p "$port" --arg pw "$pw" --arg sn "$sni" \
              '{type:"hysteria2",tag:$t,server:$s,server_port:$p,password:$pw,
                tls:{enabled:true,server_name:$sn,insecure:true}}' 2>/dev/null)" ;;
          tuic)
            ob="$(jq -nc --arg t "$name" --arg s "$SERVER_IP" --argjson p "$port" --arg u "$uuidv" --arg pw "$pw" --arg sn "$sni" \
              '{type:"tuic",tag:$t,server:$s,server_port:$p,uuid:$u,password:$pw,
                tls:{enabled:true,server_name:$sn,insecure:true,alpn:["h3"]}}' 2>/dev/null)" ;;
          anytls)
            ob="$(jq -nc --arg t "$name" --arg s "$SERVER_IP" --argjson p "$port" --arg pw "$pw" --arg sn "$sni" \
              '{type:"anytls",tag:$t,server:$s,server_port:$p,password:$pw,
                tls:{enabled:true,server_name:$sn,insecure:true}}' 2>/dev/null)" ;;
          *) ob="" ;;
        esac
        [ -n "$ob" ] && out="${out}${ob}
"
    done < <(jq -c '.[]' "$NODES" 2>/dev/null)
    { printf '{\n  "outbounds": [\n'
      printf '%s' "$out" | sed 's/^/    /; s/$/,/' | sed '$ s/,$//'
      cat <<'SBJSON'
    ,
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ],
  "outbounds_extended": 0
}
SBJSON
    } > "$SUBDIR/singbox_client.json" 2>/dev/null
}

sub_prepare(){
    mkdir -p "$SUBDIR"
    export_clash    >/dev/null 2>&1 || true
    export_v2rayn   >/dev/null 2>&1 || true
    export_shadowrocket >/dev/null 2>&1 || true
    export_singbox_json >/dev/null 2>&1 || true
}

write_subserver(){
    need_root
    if ! command -v python3 >/dev/null 2>&1; then
        warn "未检测到 python3，订阅服务不可用（可继续用「导出文件」方式）"
        return 1
    fi
    local tok port
    tok="$(sub_token)"; port="${SUBHTTP_LISTEN:-8088}"
    mkdir -p "$BASE" "$SUBDIR"
    cat > "$SUBHTTP_PY" <<PYEOF
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# sing-box NAT 订阅服务（由管理脚本生成，请勿手改）。
#
# 职责：监听一个端口，按客户端 User-Agent 返回对应格式的订阅内容。
#   - 路径 /sub/<TOKEN> 等任意带正确 token 的路径才会返回内容
#   - 其它路径一律 404，避免被扫描器发现
#   - 可选 IP 白名单
# 全部数据从磁盘文件读取，本进程不解析节点，逻辑极简、几乎不会出错。
import os, sys, re, http.server, socketserver, base64, ipaddress

BASE     = r"${BASE}"
SUBDIR   = r"${SUBDIR}"
TOKEN    = "${tok}"
PORT     = int("${port}")
ALLOWIPS = "${SUBHTTP_ALLOW_IPS}".split()

def readf(p):
    try:
        with open(p, "rb") as f:
            return f.read()
    except Exception:
        return b""

CLASH  = lambda: readf(os.path.join(SUBDIR, "clash.yaml"))
V2RAYN = lambda: readf(os.path.join(SUBDIR, "v2rayn_subscribe.txt"))
RAW    = lambda: readf(os.path.join(SUBDIR, "v2rayn_raw.txt"))
SBJSON = lambda: readf(os.path.join(SUBDIR, "singbox_client.json"))
SROCKET = lambda: readf(os.path.join(SUBDIR, "shadowrocket_subscribe.txt"))

# 只认标准链接、不认识 v2rayn:// 的客户端 UA。
# 用词边界而不是简单子串，避免 "balloon" 这类词误命中 "loon"。
STD_LINK_UA = re.compile(r"\b(shadowrocket|quantumult|loon|surge|surfboard|karing|hiddify|nekobox|nekoray)\b")

class H(http.server.BaseHTTPRequestHandler):
    server_version = "singbox-nat-sub/1.0"

    def log_message(self, *a):
        # 默认会把每个请求打到 stderr，systemd 日志会被刷爆，直接静默。
        pass

    def _ip_ok(self):
        if not ALLOWIPS:
            return True
        ip = self.client_address[0]
        try:
            a = ipaddress.ip_address(ip)
        except Exception:
            return False
        for w in ALLOWIPS:
            try:
                if a in ipaddress.ip_network(w, strict=False):
                    return True
            except Exception:
                if w == ip:
                    return True
        return False

    def do_GET(self):
        if not self._ip_ok():
            self.send_error(403, "Forbidden")
            return
        # 取路径里的 token：/sub/<token> 或 /<token> 都认，容错高一点。
        parts = [p for p in self.path.split("?")[0].split("/") if p]
        if TOKEN not in parts:
            self.send_error(404, "Not Found")
            return

        ua = (self.headers.get("User-Agent") or "").lower()
        # UA 分流：不同客户端要不同格式。
        if "clash" in ua or "mihomo" in ua or "verge" in ua or "stash" in ua:
            body, ctype = CLASH(), "text/yaml; charset=utf-8"
        elif "sing-box" in ua or "singbox" in ua or "sfa" in ua or "sfi" in ua or "sfm" in ua:
            body, ctype = SBJSON(), "application/json; charset=utf-8"
        elif STD_LINK_UA.search(ua):
            # 这些客户端都**只认标准链接**，不认识 v2rayN 的 v2rayn:// 私有格式；
            # 给它们 v2rayn 订阅会导致「只认出部分节点」。统一给纯标准链接。
            body, ctype = SROCKET(), "text/plain; charset=utf-8"
        else:
            # v2rayN / v2rayNG / Throne / 未知 → 统一给 base64 链接
            # （含 v2rayn://，由 v2rayN 自动切 sing-box 内核）。
            body, ctype = V2RAYN(), "text/plain; charset=utf-8"

        if not body:
            body, ctype = RAW(), "text/plain; charset=utf-8"
        if not body:
            self.send_error(503, "No subscription data")
            return
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        # 部分客户端（Clash）会读这两个头做流量/到期展示。
        self.send_header("Subscription-Userinfo", "upload=0; download=0; total=0; expire=0")
        self.send_header("Profile-Update-Interval", "24")
        # 【轻量化】允许客户端缓存 5 分钟：客户端通常自己也会设更新间隔，
        # 这里再让中间层/客户端少打请求，进一步降低常驻服务的负载。
        # no-cache 而不是 no-store：改了节点后客户端刷新仍能拿到新的。
        self.send_header("Cache-Control", "no-cache, max-age=300")
        self.end_headers()
        self.wfile.write(body)

def main():
    # 【为什么用多线程而不是单线程】
    # 单线程 TCPServer 一次只处理一个连接。只要某个客户端保持连接不断开
    # （keep-alive、异常断开未挥手、网络中断等），后面的请求就会全部排队 ——
    # 客户端的表现正是「等十几秒后超时」（v2rayN 报 OperationCanceled /
    # TaskCanceled，最后「无效的订阅内容」），而不是「连接被拒绝」。
    # 这个症状极易被误判成端口没放行，实际是服务端被单个连接占死了。
    #
    # 订阅服务是低频场景（客户端定时拉一两次），多线程的开销完全可控，
    # 且上面 systemd 已限 CPUQuota=10% / MemoryMax=32M，不会失控。
    # daemon_threads=True：主进程退出时不被残留连接卡住。
    class Srv(socketserver.ThreadingTCPServer):
        allow_reuse_address = True
        daemon_threads = True

    # 【按需启动：systemd socket 激活】
    # 订阅是极低频操作（客户端一天拉一两次），为它常驻一个 Python 进程
    # 白白占十几 MB 内存不划算。改成 socket 激活后：
    #   · 没请求时：没有进程、不占内存，只有 systemd 自己持有监听 socket
    #   · 有请求时：systemd 拉起本进程处理，之后继续驻留应对后续请求
    # 环境变量 LISTEN_FDS 存在即表示处于 socket 激活模式，
    # 此时 fd 3 已经是 bind + listen 好的 socket，直接拿来用，不要自己 bind。
    listen_fds = int(os.environ.get("LISTEN_FDS", "0") or 0)
    if listen_fds >= 1:
        import socket
        httpd = Srv(("0.0.0.0", PORT), H, bind_and_activate=False)
        httpd.socket = socket.socket(fileno=3)   # SD_LISTEN_FDS_START = 3
        httpd.server_address = httpd.socket.getsockname()
        httpd.serve_forever()
        return

    # 回退：没走 systemd（例如手动 python3 subserver.py）就自己监听。
    with Srv(("0.0.0.0", PORT), H) as httpd:
        httpd.serve_forever()

if __name__ == "__main__":
    main()
PYEOF
    chmod 600 "$SUBHTTP_PY" 2>/dev/null || true
    printf '%s' "$port" > "$SUBHTTP_PORT" 2>/dev/null || true
    return 0
}

install_subhttp_service(){
    [ "$INIT" = systemd ] || return 1
    systemctl stop "$SUBHTTP_SVC" >/dev/null 2>&1 || true
    systemctl disable "$SUBHTTP_SVC" >/dev/null 2>&1 || true

    cat > "/etc/systemd/system/${SUBHTTP_SVC}.socket" <<EOF
[Unit]
Description=Sing-box NAT Subscription Socket
[Socket]
ListenStream=${SUBHTTP_LISTEN:-8088}
Accept=no
[Install]
WantedBy=sockets.target
EOF

    cat > "/etc/systemd/system/${SUBHTTP_SVC}.service" <<EOF
[Unit]
Description=Sing-box NAT Subscription HTTP Server
Requires=${SUBHTTP_SVC}.socket
[Service]
Type=simple
ExecStart=$(command -v python3) $SUBHTTP_PY
CPUQuota=10%
MemoryMax=32M
Nice=5
StandardOutput=append:$LOGDIR/subhttp.log
StandardError=append:$LOGDIR/subhttp.log
EOF
    mkdir -p "$LOGDIR"; touch "$LOGDIR/subhttp.log" 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    return 0
}

_nginx_http_include_dir(){
    local conf="/etc/nginx/nginx.conf"
    [ -r "$conf" ] || return 0
    awk '
        /^[ \t]*#/ { next }
        {
            line = $0
            sub(/#.*/, "", line)
            n = gsub(/\{/, "{", line)
            m = gsub(/\}/, "}", line)
            if (depth >= 1 && line ~ /include[ \t]+[^;]*\/\*\.conf[ \t]*;/) {
                s = line
                sub(/^.*include[ \t]+/, "", s)
                sub(/[ \t]*;.*$/, "", s)
                sub(/\/\*\.conf$/, "", s)
                print s
                exit
            }
            depth += n - m
        }
    ' "$conf" 2>/dev/null
}

detect_nginx_dir(){
    local d
    d="$(_nginx_http_include_dir)"
    if [ -z "$d" ]; then
        if [ -d /etc/nginx/http.d ]; then d="/etc/nginx/http.d"
        elif [ -d /etc/nginx/conf.d ]; then d="/etc/nginx/conf.d"
        else d="/etc/nginx/conf.d"; fi
    fi
    NGINX_CONF="${d%/}/${NGINX_SITE_NAME}"
}

cleanup_legacy_nginx_conf(){
    [ -n "$NGINX_CONF" ] || detect_nginx_dir
    [ "$NGINX_CONF_LEGACY" = "$NGINX_CONF" ] && return 0
    [ -f "$NGINX_CONF_LEGACY" ] || return 0
    rm -f "$NGINX_CONF_LEGACY" 2>/dev/null || true
}

nginx_available(){
    local p
    p="$(command -v nginx 2>/dev/null)"
    [ -n "$p" ] && [ -x "$p" ]
}

nginx_install(){
    case "$OS" in
        debian|ubuntu|armbian|raspbian)
            ( apt-get update -y >/dev/null 2>&1 && apt-get install -y nginx >/dev/null 2>&1 ) ;;
        centos|rhel|rocky|almalinux|fedora|amazon|ol)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y nginx >/dev/null 2>&1
            elif command -v yum >/dev/null 2>&1; then
                ( yum install -y epel-release >/dev/null 2>&1 && yum install -y nginx >/dev/null 2>&1 )
            else return 1; fi ;;
        alpine)
            apk add --no-cache nginx >/dev/null 2>&1 ;;
        arch|manjaro)
            pacman -S --noconfirm --needed nginx >/dev/null 2>&1 ;;
        opensuse*|suse|sles)
            zypper install -y nginx >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
    nginx_available
}

nginx_unload__errlog="/tmp/singbox-nat-nginx-uninstall.log"
nginx_uninstall(){
    : > "$nginx_unload__errlog" 2>/dev/null || true
    case "$OS" in
        debian|ubuntu|armbian|raspbian)
            DEBIAN_FRONTEND=noninteractive apt-get autoremove -y nginx \
                >>"$nginx_unload__errlog" 2>&1 ;;
        centos|rhel|rocky|almalinux|fedora|amazon|ol)
            if command -v dnf >/dev/null 2>&1; then
                dnf remove -y nginx >>"$nginx_unload__errlog" 2>&1
            elif command -v yum >/dev/null 2>&1; then
                yum remove -y nginx >>"$nginx_unload__errlog" 2>&1
            else return 1; fi ;;
        alpine)
            apk del nginx >>"$nginx_unload__errlog" 2>&1 ;;
        arch|manjaro)
            pacman -R --noconfirm nginx >>"$nginx_unload__errlog" 2>&1 ;;
        opensuse*|suse|sles)
            zypper remove -y nginx >>"$nginx_unload__errlog" 2>&1 ;;
        *) return 1 ;;
    esac
    if nginx_available; then
        warn "nginx 卸载失败，包管理器日志（末 15 行）："
        tail -n 15 "$nginx_unload__errlog" 2>/dev/null | sed 's/^/    /'
        return 1
    fi
    return 0
}

nginx_reload(){
    local _tout
    if ! _tout="$(nginx -t 2>&1)"; then
        warn "nginx 配置校验失败（nginx -t），未应用更改："
        printf '%s\n' "$_tout" | sed 's/^/    /'
        return 1
    fi
    case "$INIT" in
        systemd)
            if systemctl is-active nginx >/dev/null 2>&1; then
                systemctl reload nginx >/dev/null 2>&1 && return 0
                systemctl restart nginx >/dev/null 2>&1 && return 0
            else
                systemctl enable nginx >/dev/null 2>&1
                systemctl start nginx >/dev/null 2>&1 && return 0
            fi ;;
        openrc)
            if rc-service nginx status >/dev/null 2>&1; then
                rc-service nginx reload >/dev/null 2>&1 && return 0
                rc-service nginx restart >/dev/null 2>&1 && return 0
            else
                rc-update add nginx default >/dev/null 2>&1
                rc-service nginx start >/dev/null 2>&1 && return 0
            fi ;;
    esac
    if [ -s /run/nginx.pid ] || [ -s /var/run/nginx.pid ]; then
        nginx -s reload >/dev/null 2>&1 && return 0
    fi
    nginx >/dev/null 2>&1 && return 0
    return 1
}

write_nginx_conf(){
    need_root
    [ -n "$NGINX_CONF" ] || detect_nginx_dir
    local tok port ngxconf="$NGINX_CONF"
    tok="$(sub_token)"; port="${SUBHTTP_LISTEN:-8088}"
    mkdir -p "$SUBDIR"
    local allowdeny=""
    if [ -n "$SUBHTTP_ALLOW_IPS" ]; then
        local w
        for w in $SUBHTTP_ALLOW_IPS; do
            allowdeny="${allowdeny}    allow ${w};"$'\n'
        done
        allowdeny="${allowdeny}    deny all;"$'\n'
    fi
    local v6listen=""
    [ -f /proc/net/if_inet6 ] && v6listen="    listen      [::]:${port};"
    mkdir -p "$(dirname "$ngxconf")"
    if [ "$NGINX_CONF_LEGACY" != "$ngxconf" ]; then
        rm -f "$NGINX_CONF_LEGACY" 2>/dev/null || true
    fi
    cat > "$ngxconf" <<EOF
# sing-box NAT 订阅服务（由管理脚本生成，请勿手改）
# 用 nginx 的 map 指令按 User-Agent 选文件，再用扩展名定 Content-Type；
# 比自带 Python 服务更省 CPU/内存（C 事件驱动，空闲几乎零开销）。
map \$http_user_agent \$sb_sub_file {
    default                            "v2rayn_subscribe.txt";
    "~*(clash|mihomo|verge|stash)"     "clash.yaml";
    "~*(sing-box|singbox|sfa|sfi|sfm)" "singbox_client.json";
    "~*\\b(shadowrocket|quantumult|loon|surge|surfboard|karing|hiddify|nekobox|nekoray)\\b" "shadowrocket_subscribe.txt";
}
server {
    listen      ${port};
${v6listen}
${allowdeny}
    # 仅匹配带正确 token 的路径；其它一律 404，避免被扫描发现。
    location = /sub/${tok} {
        alias ${SUBDIR}/\$sb_sub_file;
        # 按文件扩展名给定 Content-Type（yaml / json / txt），
        # 不依赖 default_type 的变量支持，兼容所有 nginx 版本。
        types {
            text/yaml            yaml;
            application/json     json;
            text/plain           txt;
        }
        default_type text/plain;
        add_header Subscription-Userinfo "upload=0; download=0; total=0; expire=0" always;
        add_header Profile-Update-Interval "24" always;
        add_header Cache-Control "no-cache, max-age=300" always;
    }
    location / {
        return 404;
    }
}
EOF
    return 0
}

sub_selftest(){
    local port="${SUBHTTP_LISTEN:-8088}" code
    command -v curl >/dev/null 2>&1 || return 0
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 \
            "http://127.0.0.1:${port}/sub/$(sub_token 2>/dev/null)" 2>/dev/null)"
    [ "$code" = "200" ]
}

cleanup_legacy_py(){
    systemctl stop "${SUBHTTP_SVC}.socket" >/dev/null 2>&1 || true
    systemctl disable "${SUBHTTP_SVC}.socket" >/dev/null 2>&1 || true
    systemctl stop "$SUBHTTP_SVC" >/dev/null 2>&1 || true
    systemctl disable "$SUBHTTP_SVC" >/dev/null 2>&1 || true
    rm -f "/etc/systemd/system/${SUBHTTP_SVC}.socket" "/etc/systemd/system/${SUBHTTP_SVC}.service" 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true
}

sub_start(){
    need_root
    echo
    local backend="${SUBHTTP_BACKEND:-}"
    if [ -z "$backend" ]; then
        sub_choose_backend || return 1
        backend="${SUBHTTP_BACKEND:-}"
    fi
    case "$backend" in
        nginx)  sub_start_nginx ;;
        python) _sub_start_python ;;
        *)      warn "未知的实现方式：${backend}"; return 1 ;;
    esac
}

sub_choose_backend(){
    echo
    panel "选择订阅服务实现方式"
    local has_ngx=0 has_py=0 py_reason=""
    nginx_available && has_ngx=1
    if command -v python3 >/dev/null 2>&1; then
        if [ "$INIT" = systemd ]; then
            has_py=1
        else
            py_reason="需要 systemd，当前是 ${INIT}"
        fi
    else
        py_reason="未安装 python3"
    fi
    echo "  ${BOLD}本机条件${RESET}"
    if [ "$has_ngx" = 1 ]; then
        echo "    ${GREEN}●${RESET} nginx    已安装，可直接用"
    else
        echo "    ${YELLOW}○${RESET} nginx    未安装（选它需要安装，会改动系统）"
    fi
    if [ "$has_py" = 1 ]; then
        echo "    ${GREEN}●${RESET} Python   已就绪（自带脚本，无需安装）"
    else
        echo "    ${RED}✗${RESET} Python   不可用（${py_reason}）"
    fi
    echo
    echo "  ${BOLD}1) nginx${RESET}    更省资源（C 事件驱动，空闲几乎零开销）"
    echo "  ${BOLD}2) Python${RESET}   自带自包含脚本，无需安装；占用略高于 nginx"
    echo
    [ "$has_py" = 0 ] && info "本机没有可用的 Python，建议使用 nginx 方案（选 1）"
    while :; do
        read -r -p "  请选择 [1/2]： " b || b=""
        case "$b" in
            1)
                if [ "$has_ngx" = 1 ]; then
                    SUBHTTP_BACKEND=nginx
                else
                    echo
                    read -r -p "  本机未安装 nginx，是否现在安装？[y/N] " y || y=""
                    case "$y" in
                        [Yy]*)
                            info "正在安装 nginx…"
                            if nginx_install; then
                                ok "nginx 安装完成"
                                SUBHTTP_BACKEND=nginx
                            else
                                warn "nginx 安装失败"
                                if [ "$has_py" = 1 ]; then
                                    SUBHTTP_BACKEND=python
                                    info "改用 Python 方案"
                                else
                                    warn "本机也没有可用的 Python —— 订阅服务暂时无法启动"
                                    return 1
                                fi
                            fi ;;
                        *)
                            if [ "$has_py" = 1 ]; then
                                SUBHTTP_BACKEND=python
                                info "未安装 nginx，改用 Python 方案"
                            else
                                warn "nginx 未安装，且本机没有 Python —— 订阅服务无法启动"
                                return 1
                            fi ;;
                    esac
                fi
                break ;;
            2)
                if [ "$has_py" = 0 ]; then
                    warn "本机没有可用的 Python（${py_reason}），请选 1（nginx）"
                    continue
                fi
                SUBHTTP_BACKEND=python
                break ;;
            *) warn "请输入 1 或 2" ;;
        esac
    done
    save_settings
    ok "已选择：${SUBHTTP_BACKEND}"
}

sub_start_nginx(){
    progress 10 "准备订阅内容"
    sub_prepare
    progress 35 "检查 nginx"
    if ! nginx_available; then
        warn "本机没有 nginx"
        info "请在订阅菜单「切换实现方式」里选 Python，或先自行安装 nginx"
        return 1
    fi
    cleanup_legacy_py
    progress 60 "写入 nginx 配置"
    write_nginx_conf || { warn "写 nginx 配置失败"; return 1; }
    progress 80 "校验并加载 nginx"
    if ! nginx_reload; then
        warn "nginx 加载失败，请运行 nginx -t 查看报错"
        return 1
    fi
    SUBHTTP_ENABLED=1; save_settings
    sleep 1
    progress 95 "本机自检"
    if sub_selftest; then
        progress 100 "完成"
        echo
        ok "订阅服务已启动（nginx）"
        sub_port_hint
        return 0
    fi
    warn "订阅服务已加载但本机自检未通过，请运行 nginx -t 或查看 error 日志"
    return 1
}

_sub_start_python(){
    need_root
    echo
    if [ "$INIT" != systemd ]; then
        warn "当前 init 不是 systemd，订阅服务暂不支持自动常驻"
        info "可继续用「一键复制全部链接」或二维码导入"
        return 1
    fi
    progress 10 "检查 python3"
    if ! command -v python3 >/dev/null 2>&1; then
        warn "未检测到 python3，订阅服务不可用"
        info "可继续用「一键复制全部链接」或二维码导入"
        return 1
    fi
    rm -f "$NGINX_CONF" "$NGINX_CONF_LEGACY" 2>/dev/null || true
    progress 30 "生成订阅内容"
    sub_prepare
    progress 50 "写入服务脚本"
    write_subserver || { warn "写服务脚本失败"; return 1; }
    progress 70 "安装 systemd 服务"
    install_subhttp_service || { warn "安装 systemd 服务失败"; return 1; }
    progress 85 "启动服务"
    systemctl enable "$SUBHTTP_SVC" >/dev/null 2>&1 || true
    systemctl restart "$SUBHTTP_SVC" >/dev/null 2>&1 || true
    sleep 1
    if systemctl is-active "$SUBHTTP_SVC" >/dev/null 2>&1; then
        progress 100 "完成"
        SUBHTTP_ENABLED=1; save_settings
        echo
        ok "订阅服务已启动（Python 回退）"
        sub_port_hint
        return 0
    fi
    warn "订阅服务启动失败，请查看 journalctl -u ${SUBHTTP_SVC} -n 30"
    return 1
}

sub_port_hint(){
    local port="${SUBHTTP_LISTEN:-8088}" ok_local=0
    if sub_selftest; then
        ok_local=1
        info "本机自检通过（HTTP 200），服务已在 ${port} 端口响应"
    else
        warn "本机自检未通过，请运行 nginx -t 或查看 nginx error 日志"
    fi
    echo
    printf '  %s外部访问需在防火墙放行 %s 端口：%s\n' "$BOLD" "$port" "$RESET"
    if command -v ufw >/dev/null 2>&1; then
        printf '    ufw allow %s/tcp\n' "$port"
    fi
    if command -v firewall-cmd >/dev/null 2>&1; then
        printf '    firewall-cmd --add-port=%s/tcp --permanent && firewall-cmd --reload\n' "$port"
    fi
    if command -v iptables >/dev/null 2>&1 && [ "$ok_local" = 1 ]; then
        printf '    iptables -I INPUT -p tcp --dport %s -j ACCEPT\n' "$port"
    fi
    printf '  %s云服务器还要在控制台「安全组 / 防火墙」里放行 TCP %s%s\n' "$DIM" "$port" "$RESET"
    if [ "$ok_local" = 1 ]; then
        printf '  %s若客户端仍报超时，按上面放行后再试；URL：%s%s\n' \
            "$DIM" "$(sub_url 2>/dev/null)" "$RESET"
    fi
}

sub_stop(){
    need_root
    rm -f "$NGINX_CONF" "$NGINX_CONF_LEGACY" 2>/dev/null || true
    if nginx_available; then
        nginx -t >/dev/null 2>&1 && nginx_reload >/dev/null 2>&1 || true
    fi
    if [ "$INIT" = systemd ]; then
        systemctl stop "${SUBHTTP_SVC}.socket" >/dev/null 2>&1 || true
        systemctl disable "${SUBHTTP_SVC}.socket" >/dev/null 2>&1 || true
        systemctl stop "$SUBHTTP_SVC" >/dev/null 2>&1 || true
        systemctl disable "$SUBHTTP_SVC" >/dev/null 2>&1 || true
    fi
    SUBHTTP_ENABLED=0; save_settings
    ok "订阅服务已停止"
}

sub_uninstall_backend(){
    need_root
    clear
    panel "卸载订阅服务后端"
    progress 15 "停止订阅服务"
    sub_stop >/dev/null 2>&1 || true
    progress 45 "移除本脚本的订阅站点配置"
    if nginx_available; then
        echo "  检测到本机已安装 nginx（曾被用于订阅服务）。"
        echo "  ${YELLOW}⚠ 警告：卸载 nginx 软件包会移除整个 nginx，包括你自建的其它站点与配置！${RESET}"
        echo "  ${DIM}本脚本只为订阅新增了一份站点配置：${NGINX_CONF}（已在上一步删除）。${RESET}"
        read -r -p "  确认卸载 nginx 软件包？[y/N]： " c || c=""
        case "$c" in
          [Yy])
            if [ "$INIT" = systemd ]; then
                systemctl stop nginx >/dev/null 2>&1 || true
                systemctl disable nginx >/dev/null 2>&1 || true
            elif [ "$INIT" = openrc ]; then
                rc-service nginx stop >/dev/null 2>&1 || true
                rc-update del nginx default >/dev/null 2>&1 || true
            fi
            progress 70 "卸载 nginx 软件包"
            if nginx_uninstall; then ok "nginx 已卸载"; else warn "nginx 卸载失败（可手动执行对应包管理器卸载 nginx）"; fi
            ;;
          *) info "已跳过卸载 nginx 包；订阅服务本身也已停止。" ;;
        esac
    else
        info "本机未安装 nginx，无需卸载。"
    fi
    progress 90 "清理 Python 残留与订阅产物"
    rm -f "$SUBHTTP_PY" 2>/dev/null || true
    rm -f "$BASE/${SUBHTTP_SVC}.service" "$BASE/${SUBHTTP_SVC}.socket" 2>/dev/null || true
    if [ "$INIT" = systemd ]; then
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
    rm -rf "$SUBDIR" 2>/dev/null || true
    SUBHTTP_BACKEND=""; SUBHTTP_ENABLED=0; save_settings
    progress 100 "完成"
    ok "订阅后端已清理（nginx 包 / Python 脚本 / 订阅产物均已移除）"
}

sub_restart(){
    need_root
    local backend="${SUBHTTP_BACKEND:-}"
    [ -n "$backend" ] || backend="$([ -f "$NGINX_CONF" ] && echo nginx || echo python)"
    if [ "$backend" = nginx ]; then
        write_nginx_conf >/dev/null 2>&1 || true
        nginx_reload >/dev/null 2>&1 || true
    else
        _sub_start_python >/dev/null 2>&1 || true
    fi
}

sub_status(){
    if command -v curl >/dev/null 2>&1; then
        sub_selftest && { echo "on"; return; }
        echo "off"; return
    fi
    local port="${SUBHTTP_LISTEN:-8088}"
    if command -v ss >/dev/null 2>&1; then
        ss -lntH 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}$" && { echo on; return; }
    fi
    if [ "$INIT" = systemd ]; then
        systemctl is-active "${SUBHTTP_SVC}.socket" >/dev/null 2>&1 && { echo on; return; }
        systemctl is-active "$SUBHTTP_SVC"          >/dev/null 2>&1 && { echo on; return; }
        [ -f "$NGINX_CONF" ] && systemctl is-active nginx >/dev/null 2>&1 && { echo on; return; }
    fi
    echo "off"
}
sub_resource(){
    local pids=""
    if [ -f "$NGINX_CONF" ]; then
        pids="$(pgrep -x nginx 2>/dev/null)"
    else
        pids="$(pgrep -f "$SUBHTTP_PY" 2>/dev/null)"
    fi
    [ -n "$pids" ] || return 0
    local cache="$BASE/.subres.cache" now ts="" val=""
    now="$(date +%s 2>/dev/null)"
    ts="$(awk -F'|' 'NR==1{print $1}' "$cache" 2>/dev/null)"
    if [ -n "$ts" ] && [ "$((now - ts))" -lt 5 ]; then
        val="$(awk -F'|' 'NR==1{print $2}' "$cache" 2>/dev/null)"
        [ -n "$val" ] && { printf '%s' "$val"; return 0; }
    fi
    local mem=0 pid rss=0 t1=0 t2=0 u="" n1 n2 dms hz v10=0 dticks=0 cpu="0.0"
    for pid in $pids; do
        rss="$(awk '/^VmRSS/{print $2}' "/proc/$pid/status" 2>/dev/null)"
        [ -n "$rss" ] && mem=$((mem + rss))
        u="$(awk '{print $14+$15}' "/proc/$pid/stat" 2>/dev/null)"
        [ -n "$u" ] && t1=$((t1 + u))
    done
    mem=$(( mem / 1024 ))
    n1="$(now_ms)"
    sleep 0.3
    for pid in $pids; do
        u="$(awk '{print $14+$15}' "/proc/$pid/stat" 2>/dev/null)"
        [ -n "$u" ] && t2=$((t2 + u))
    done
    n2="$(now_ms)"
    if [[ "$n1" =~ ^[0-9]+$ ]] && [[ "$n2" =~ ^[0-9]+$ ]]; then
        dticks=$(( t2 - t1 ))
        dms=$(( n2 - n1 ))
    else
        dticks=0; dms=0
    fi
    hz="$(getconf CLK_TCK 2>/dev/null)"; [[ "$hz" =~ ^[0-9]+$ ]] && [ "$hz" -gt 0 ] || hz=100
    if [ "$dms" -gt 0 ] && [ "$dticks" -ge 0 ]; then
        v10=$(( dticks * 1000000 / (hz * dms) ))
        cpu="$(printf '%d.%d' $(( v10 / 10 )) $(( v10 % 10 )) )"
    fi
    local out="内存 ${mem}M  CPU ${cpu}%"
    printf '%s|%s' "$now" "$out" > "$cache" 2>/dev/null
    printf '%s' "$out"
}
sub_url(){
    local tok port
    tok="$(sub_token)"; port="${SUBHTTP_LISTEN:-8088}"
    printf 'http://%s:%s/sub/%s' "$SERVER_IP" "$port" "$tok"
}
subhttp_menu(){
    while :; do
        clear
        panel "订阅服务"
        get_ip
        local st; st="$(sub_status)"
        local _be="${SUBHTTP_BACKEND:-}" _bTxt="${DIM}未选择${RESET}"
        [ "$_be" = nginx ]  && _bTxt="nginx"
        [ "$_be" = python ] && _bTxt="Python"
        if [ "$st" = "on" ]; then
            local _sr; _sr="$(sub_resource 2>/dev/null)"
            kv "运行状态" "$(status_dot 1) ${GREEN}运行中${RESET}  ${DIM}:${SUBHTTP_LISTEN:-8088}${RESET}  ${DIM}${_bTxt}${RESET}  ${_sr}"
        else
            kv "运行状态" "$(status_dot 0) ${DIM}未运行${RESET}  ${DIM}:${SUBHTTP_LISTEN:-8088}${RESET}  ${DIM}${_bTxt}${RESET}"
        fi
        hr
        local tok; tok="$(sub_token)"
        kv "访问令牌" "${DIM}${tok:0:8}…${RESET}  ${DIM}(完整值见订阅 URL)${RESET}"
        [ -n "$SUBHTTP_ALLOW_IPS" ] && kv "IP 白名单" "$SUBHTTP_ALLOW_IPS" || kv "IP 白名单" "${DIM}未限制（靠令牌保护）${RESET}"
        hr
        if [ "$st" = "on" ]; then
            echo "  ${BOLD}订阅 URL —— 客户端里粘贴这一个即可${RESET}"
            echo "  ${CYAN}$(sub_url)${RESET}"
            echo "  ${DIM}按客户端 UA 自动适配：Clash→YAML / v2rayN→base64 / sing-box→JSON / 小火箭→标准链接${RESET}"
        else
            echo "  ${DIM}当前未运行：选 1 启动后，这里会出现可复制的订阅地址${RESET}"
        fi
        echo
        echo "1. 启动 / 刷新订阅服务"
        echo "2. 停止订阅服务"
        echo "3. 复制订阅 URL"
        echo "4. 修改监听端口"
        echo "5. 设置 IP 白名单"
        echo "6. 轮换访问令牌（旧 URL 立即失效）"
        echo "7. 查看服务日志"
        echo "8. 切换实现方式（nginx / Python）"
        echo "9. 卸载订阅后端（移除 nginx 包 / Python 残留）"
        echo "0. 返回"
        read -r -p "请选择： " x || x=""
        case "$x" in
          1) sub_start; pause ;;
          2) sub_stop; pause ;;
          3)
            if [ "$(sub_status)" != on ]; then warn "服务未启动，先把 1 里启动它"; pause; continue; fi
            copy_text "$(sub_url)"; pause ;;
          4)
            echo; read -r -p "  新端口（1024-65535）： " np || np=""
            case "$np" in ''|*[!0-9]*) warn "无效端口"; pause; continue ;; esac
            [ "$np" -ge 1024 ] && [ "$np" -le 65535 ] || { warn "端口范围 1024-65535"; pause; continue; }
            if port_used "$np"; then warn "端口 $np 已被占用"; pause; continue; fi
            SUBHTTP_LISTEN="$np"; save_settings
            sub_restart >/dev/null 2>&1 || true
            ok "端口已改为 $np"; pause ;;
          5)
            echo; echo "  ${DIM}空格分隔，如 1.2.3.4 5.6.7.0/24；留空 = 不限制${RESET}"
            read -r -p "  IP 白名单： " ips || ips=""
            SUBHTTP_ALLOW_IPS="$(printf '%s' "$ips" | tr -s ' ')"
            save_settings
            sub_restart >/dev/null 2>&1 || true
            ok "已更新白名单"; pause ;;
          6)
            sub_rotate_token
            ok "令牌已轮换，请重新复制订阅 URL"; pause ;;
          7)
            if [ -f "$LOGDIR/subhttp.log" ]; then
                echo "  ${DIM}（Python 回退方案日志）${RESET}"
                tail -n 40 "$LOGDIR/subhttp.log"
            else
                echo "  ${DIM}（nginx 方案）实时错误日志：${RESET}"
                local elog="/var/log/nginx/error.log"
                [ -f "$elog" ] && tail -n 40 "$elog" || warn "未找到 nginx 错误日志（${elog}）"
            fi
            pause ;;
          8)
            local _was="$st"
            sub_choose_backend || true
            if [ "$_was" = on ] && [ -n "${SUBHTTP_BACKEND:-}" ]; then
                info "正在按新方式重启订阅服务…"
                sub_stop >/dev/null 2>&1 || true
                sub_start >/dev/null 2>&1 || true
            fi
            pause ;;
          9)
            sub_uninstall_backend; pause ;;
          0) return ;;
          *) warn "无效选项"; sleep 1 ;;
        esac
    done
}

self_repair(){
    clear
    panel "自检 / 修复"
    local bad=0
    need_root
    mkdir -p "$BASE" "$CERTDIR" "$SUBDIR" "$BACKUP" "$LOGDIR"
    if ! command -v jq >/dev/null 2>&1; then warn "缺少 jq"; bad=1; fi
    if ! command -v openssl >/dev/null 2>&1; then warn "缺少 openssl"; bad=1; fi
    if [ ! -x "$BIN" ]; then warn "sing-box 未安装"; bad=1; else echo "✓ sing-box：$($BIN version 2>/dev/null | head -n1)"; fi
    init_files
    if ! http_version_supported; then
        if jq -e '(.inbounds // []) | any(.type == "http" and has("version"))' "$CONF" >/dev/null 2>&1; then
            warn "检测到 sing-box $(sb_version) 不支持 http.version 字段，正在清理"
            strip_http_version
        fi
    fi
    if jq empty "$CONF" >/dev/null 2>&1; then echo "✓ config.json JSON 正常"; else warn "config.json JSON 损坏"; bad=1; fi
    if jq empty "$NODES" >/dev/null 2>&1; then echo "✓ nodes.json JSON 正常"; else warn "nodes.json JSON 损坏"; bad=1; fi
    if [ -x "$BIN" ] && jq empty "$CONF" >/dev/null 2>&1; then
        if validate >/dev/null 2>&1; then echo "✓ sing-box 配置检查通过"; else warn "sing-box 配置检查失败"; bad=1; fi
    fi
    local _orph
    _orph="$(orphan_inbounds 2>/dev/null)"
    if [ -n "$_orph" ]; then
        warn "发现孤儿 inbound（config.json 里有、节点列表里没有）："
        printf '%s\n' "$_orph" | while IFS=$'\t' read -r _ot _op; do
            [ -n "$_ot" ] || continue
            printf '    · %-24s 端口 %s\n' "$_ot" "$_op"
        done
        echo "    清理入口：主菜单 3（节点管理）→ 8"
        bad=1
    else
        echo "✓ 没有孤儿 inbound（配置与节点列表一致）"
    fi
    install_sb_cmd
    chmod 0755 "$MENU" 2>/dev/null || true
    local _mv
    _mv="$(script_version_of "$MENU" 2>/dev/null)"
    if [ -z "$_mv" ]; then
        warn "menu.sh 版本号读取失败（文件可能损坏）：$MENU"
        bad=1
    elif [ "$_mv" != "$VERSION" ]; then
        warn "menu.sh 版本（$_mv）与当前脚本（$VERSION）不一致，菜单里仍是旧逻辑"
        echo "    更新方法：${BOLD}sb update${RESET}（或 sb update <脚本URL>）"
        bad=1
    else
        echo "✓ menu.sh 版本一致：$VERSION"
    fi
    if [ -x "$SB" ] && head -n 2 "$SB" 2>/dev/null | grep -q '由安装脚本生成'; then
        echo "✓ sb 管理命令形态正常"
    else
        warn "sb 管理命令形态异常，已重建"
        install_sb_cmd >/dev/null 2>&1 || true
    fi
    if [ "$INIT" = systemd ]; then
        [ -f /etc/systemd/system/sing-box.service ] || { warn "服务文件不存在，重新生成"; install_service; systemctl daemon-reload; }
    fi
    if [ "$bad" -eq 0 ]; then
        export_all
        ok "自检完成，没有发现明显结构性问题"
    else
        warn "自检发现问题；未自动删除现有节点或配置"
    fi
    pause
}

PROTOCOLS=(
    "VLESS + Reality"
    "Hysteria2"
    "Hysteria2 + Salamander"
    "TUIC v5"
    "Shadowsocks 2022"
    "Trojan + TLS"
    "VMess + WS + TLS"
    "VLESS + WS + TLS"
    "VLESS + H2 + Reality"
    "VLESS + gRPC + Reality"
    "AnyTLS"
    "NaiveProxy"
    "HTTP/2"
    "HTTP/3"
    "Hysteria2 + Realm"
    "ShadowTLS v3"
)
PROTO_TRANSPORT=(
    "tcp"
    "udp"
    "udp"
    "udp"
    "tcp"
    "tcp"
    "tcp"
    "tcp"
    "tcp"
    "tcp"
    "tcp"
    "tcp"
    "tcp"
    "udp"
    "udp"
    "tcp"
)

MENU_IDS=()
build_menu_map(){
    MENU_IDS=()
    local i t
    for i in "${!PROTOCOLS[@]}"; do
        t="${PROTO_TRANSPORT[$i]}"
        if [ "$UDP_OK" = "0" ] && [ "$t" != "tcp" ]; then
            continue
        fi
        MENU_IDS+=("$((i+1))")
    done
}
print_protocol_list(){
    build_menu_map
    local n=1 raw
    for raw in "${MENU_IDS[@]}"; do
        local label="${PROTOCOLS[$((raw-1))]}"
        if [ "${PROTO_TRANSPORT[$((raw-1))]}" = "udp" ]; then
            label="${label}  ${CYAN}[UDP]${RESET}"
        fi
        printf ' %2d. %s\n' "$n" "$label"
        n=$((n+1))
    done
    printf '  0. %s\n' "返回"
}
protocol_name(){
    local n="$1"
    [[ "$n" =~ ^[0-9]+$ ]] || { echo "?"; return; }
    [ "$n" -ge 1 ] && [ "$n" -le "${#PROTOCOLS[@]}" ] && echo "${PROTOCOLS[$((n-1))]}" || echo "?"
}
menu_id_to_raw(){
    local n="$1"
    [[ "$n" =~ ^[0-9]+$ ]] || { echo ""; return; }
    [ "$n" -ge 1 ] && [ "$n" -le "${#MENU_IDS[@]}" ] && echo "${MENU_IDS[$((n-1))]}" || echo ""
}

node_menu(){
  while :; do
    clear
    panel "节点部署"
    echo "  选择要部署的协议（0 返回）："
    echo
    print_protocol_list
    echo
    read -r -p "请选择： " menu_no || menu_no=""
    BATCH_MODE=0
    [ "$menu_no" = "0" ] && return
    c="$(menu_id_to_raw "$menu_no")"
    [ -n "$c" ] || { warn "无效选项"; sleep 1; continue; }
    backup
    local _drc=0
    case "$c" in
      1) add_vless_reality || _drc=$? ;;
      2) add_hysteria2 || _drc=$? ;;
      3) add_hy2_obfs || _drc=$? ;;
      4) add_tuic || _drc=$? ;;
      5) add_ss || _drc=$? ;;
      6) add_trojan || _drc=$? ;;
      7) add_vmess_ws_tls || _drc=$? ;;
      8) add_vless_ws_tls || _drc=$? ;;
      9) add_h2_reality || _drc=$? ;;
      10) add_grpc_reality || _drc=$? ;;
      11) add_anytls || _drc=$? ;;
      12) add_naive || _drc=$? ;;
      13) add_http2 || _drc=$? ;;
      14) add_http3 || _drc=$? ;;
      15) add_hy2_realm || _drc=$? ;;
      16) add_shadowtls || _drc=$? ;;
      *) warn "无效选项"; pause; continue ;;
    esac
    if [ "$_drc" -ne 0 ]; then
        if [ -n "${CURRENT_SNAPSHOT:-}" ] && [ -f "$CURRENT_SNAPSHOT/config.json" ] \
           && ! cmp -s "$CONF" "$CURRENT_SNAPSHOT/config.json"; then
            warn "本次部署未完成，已恢复操作前快照（不会留下孤儿 inbound）"
            rollback
        else
            warn "本次部署未完成（未写入任何配置）"
        fi
        pause
        continue
    fi
    echo
    info "正在检查配置 ..."
    if validate; then
      info "配置检查通过，正在重启服务 ..."
      if apply; then
        info "正在重新生成订阅 ..."
        export_all; ok "配置已应用"
      else
        warn "服务启动失败，自动恢复操作前快照"
        rollback
        apply >/dev/null 2>&1 || warn "回滚后服务仍未能启动，请手动检查"
      fi
    else
      warn "配置检查未通过，已恢复操作前快照"
      rollback
    fi
    echo
    show_nodes
    goto_sub
  done
}
batch_menu(){
    clear
    panel "批量部署"
    kv "TCP" "${MIN_TCP}-${MAX_TCP}（默认 ${DEFAULT_TCP_START}）"
    kv "UDP" "${MIN_UDP}-${MAX_UDP}（默认 ${DEFAULT_UDP_START}）"
    hr
    echo "  可选协议（0 返回）："
    echo
    print_protocol_list
    echo
    echo "输入编号（空格分隔，如：1 2 4），或 all 全选："
    read -r -p "请选择： " list || list=""
    if [ "$list" = "0" ] || [ "$list" = "$((${#MENU_IDS[@]}+1))" ]; then return; fi
    if [ "$list" = all ]; then
        list=""
        local _i
        for ((_i=1; _i<=${#MENU_IDS[@]}; _i++)); do list="$list $_i"; done
    fi
    [ -n "$list" ] || return
    local _rawlist="" _n _raw
    for _n in $list; do
        _raw="$(menu_id_to_raw "$_n")"
        if [ -z "$_raw" ]; then warn "未知编号：$_n"; pause; return; fi
        _rawlist="$_rawlist $_raw"
    done
    local _cur_ver _skip_msg="" _kept="" _c
    _cur_ver="$(sb_version)"
    for _c in $_rawlist; do
        case "$_c" in
            12) if ! version_ge "1.15.0" "$_cur_ver"; then
                    _skip_msg="${_skip_msg}
  ${YELLOW}·${RESET} 12 NaiveProxy 需要 sing-box 1.15.0+（当前 ${_cur_ver:-未知}）"
                    continue
                fi ;;
            14) if ! version_ge "1.15.0" "$_cur_ver"; then
                    _skip_msg="${_skip_msg}
  ${YELLOW}·${RESET} 14 HTTP/3 需要 sing-box 1.15.0+（当前 ${_cur_ver:-未知}）"
                    continue
                fi ;;
        esac
        _kept="$_kept $_c"
    done
    if [ -n "$_skip_msg" ]; then
        echo
        warn "以下协议与当前内核不兼容，已自动跳过（不影响其它协议）："
        printf '%b\n' "$_skip_msg"
        echo "  ${DIM}→ 想用它们请先到「sing-box 内核管理 → 2」切到最新测试版${RESET}"
    fi
    _rawlist="$_kept"
    if [ -z "$_rawlist" ]; then
        warn "没有可部署的协议"; pause; return
    fi

    local _existing="" _dupcount=0 _raw
    for _raw in $_rawlist; do
        local _t
        _t="$(raw_to_node_type "$_raw")"
        [ -n "$_t" ] || continue
        if jq -e --arg t "$_t" 'any(.[]; .type == $t)' "$NODES" >/dev/null 2>&1; then
            _existing="$_existing $_t"
            _dupcount=$((_dupcount+1))
        fi
    done

    local MODE_OVERWRITE=0
    if [ "$_dupcount" -gt 0 ]; then
        hr
        printf '  %s已有 %d 个协议安装过：%s%s\n' "$BOLD" "$_dupcount" "${_existing# }" "$RESET"
        echo
        echo "  怎么处理这些已存在的协议？"
        echo "    1. 跳过它们，只部署还没装的（推荐，改动最小）"
        echo "    2. 覆盖重建：先删掉它们的旧节点，再全部重新部署"
        echo "    0. 取消本次批量部署"
        echo
        local _m
        read -r -p "  请选择 [1]： " _m || _m=""
        case "${_m:-1}" in
            2) MODE_OVERWRITE=1 ;;
            0) info "已取消"; pause; return ;;
            *) MODE_OVERWRITE=0 ;;
        esac
        if [ "$MODE_OVERWRITE" = 0 ]; then
            local _newlist="" _c2
            for _c2 in $_rawlist; do
                local _t2
                _t2="$(raw_to_node_type "$_c2")"
                if jq -e --arg t "$_t2" 'any(.[]; .type == $t)' "$NODES" >/dev/null 2>&1; then
                    continue
                fi
                _newlist="$_newlist $_c2"
            done
            _rawlist="$_newlist"
            if [ -z "$_rawlist" ]; then
                ok "所有选中的协议都已安装过，无需重复部署"
                pause; return
            fi
            echo
            info "本次将部署：$(for _c2 in $_rawlist; do printf '%s ' "$(protocol_name "$_c2")"; done)"
        fi
    fi

    backup
    rm -f "${BASE}/.batch_seed_tcp" "${BASE}/.batch_seed_udp" 2>/dev/null || true
    local _n_tcp=0 _n_udp=0 _c4 _proto4
    for _c4 in $_rawlist; do
        _proto4="$(proto_of_raw "$_c4")"
        [ "$_proto4" = "tcp" ] && _n_tcp=$((_n_tcp+1))
        [ "$_proto4" = "udp" ] && _n_udp=$((_n_udp+1))
    done
    BATCH_RESERVE=$(( _n_tcp > _n_udp ? _n_tcp : _n_udp ))
    [ "$BATCH_RESERVE" -gt 0 ] || BATCH_RESERVE=1
    if [ "$MODE_OVERWRITE" = 1 ]; then
        local _c3 _tag3
        for _c3 in $_rawlist; do
            _tag3="$(raw_to_tag "$_c3")"
            [ -n "$_tag3" ] || continue
            jq --arg t "$_tag3" '
              [ .inbounds[]? | .tag
                | select(. == $t or test("^" + ($t | gsub("[-\\[\\]\\^\\$\\*\\+\\?\\(\\)\\{\\}\\|]"; "\\\\" + .)) + "-[0-9]+$"))
              ] as $kill
              | .inbounds |= map(select((.tag as $x | $kill | index($x)) | not))
            ' "$CONF" > "$CONF.tmp" 2>/dev/null && mv "$CONF.tmp" "$CONF" || rm -f "$CONF.tmp"
        done
        local _t3
        for _c3 in $_rawlist; do
            _t3="$(raw_to_node_type "$_c3")"
            [ -n "$_t3" ] || continue
            jq --arg t "$_t3" 'map(select(.type != $t))' \
                "$NODES" > "$NODES.tmp" 2>/dev/null && mv "$NODES.tmp" "$NODES" || rm -f "$NODES.tmp"
        done
        info "已清理选中协议的旧节点，开始重建（共 $(echo $_rawlist | wc -w | tr -d ' ') 个）"
    fi
    echo
    info "批量部署：先做一次 SNI 优选，本批所有节点共用该结果"
    sni_optimize || warn "优选未成功，本批节点沿用 $(sni_default)"
    BATCH_MODE=1
    local okc=0 failc=0 c n=0 total
    total="$(echo $_rawlist | wc -w | tr -d ' ')"
    hr
    for c in $_rawlist; do
      n=$((n+1))
      printf '\n  %s[%d/%d]%s 部署 %s%s%s\n' \
          "$MAGENTA$BOLD" "$n" "$total" "$RESET" "$BOLD" "$(protocol_name "$c")" "$RESET"
      progress $(( n*95/total )) "第 $n / $total 个协议"
      local _before="" _ok=0
      _before="$(mktemp)"
      [ -f "$CONF" ] && cp -f "$CONF" "$_before" 2>/dev/null || true
      case "$c" in
        1) add_vless_reality && _ok=1 ;;
        2) add_hysteria2 && _ok=1 ;;
        3) add_hy2_obfs && _ok=1 ;;
        4) add_tuic && _ok=1 ;;
        5) add_ss && _ok=1 ;;
        6) add_trojan && _ok=1 ;;
        7) add_vmess_ws_tls && _ok=1 ;;
        8) add_vless_ws_tls && _ok=1 ;;
        9) add_h2_reality && _ok=1 ;;
        10) add_grpc_reality && _ok=1 ;;
        11) add_anytls && _ok=1 ;;
        12) add_naive && _ok=1 ;;
        13) add_http2 && _ok=1 ;;
        14) add_http3 && _ok=1 ;;
        15) add_hy2_realm && _ok=1 ;;
        16) add_shadowtls && _ok=1 ;;
        *) warn "跳过未知编号：$c" ;;
      esac
      if [ "$_ok" = "1" ]; then
          if jq empty "$CONF" >/dev/null 2>&1 && "$BIN" check -c "$CONF" >/dev/null 2>&1; then
              okc=$((okc+1))
          else
              warn "$(protocol_name "$c") 写入后校验未通过，仅回退该协议"
              local _cerr=""
              if ! jq empty "$CONF" >/dev/null 2>&1; then
                  _cerr="config.json JSON 结构损坏（jq 解析失败）"
              else
                  _cerr="$("$BIN" check -c "$CONF" 2>&1 | grep -v '^$' | head -n 3 | tr '\n' ' ')"
              fi
              [ -n "$_cerr" ] && warn "  报错：$_cerr"
              local _cver=""
              _cver="$(sb_version 2>/dev/null)"
              [ -n "$_cver" ] && warn "  当前内核：v$_cver（部分新协议需 1.15.0+；可到「sing-box 内核管理 → 2」升级）"
              [ -f "$_before" ] && mv -f "$_before" "$CONF" 2>/dev/null || true
              del_node_by_raw "$c" >/dev/null 2>&1 || true
              failc=$((failc+1))
          fi
      else
          [ -f "$_before" ] && mv -f "$_before" "$CONF" 2>/dev/null || true
          failc=$((failc+1))
      fi
      rm -f "$_before" 2>/dev/null || true
    done
    BATCH_MODE=0
    echo
    info "全部协议已写入，正在做整体检查 ..."
    if validate; then
      info "正在重启服务 ..."
      if apply; then
        info "正在重新生成订阅 ..."
        export_all
        progress 100 "全部完成"
        ok "批量部署完成：成功 $okc；失败 $failc"
      else
        warn "服务启动失败，恢复批量前备份"
        rollback
        failc=$((okc+failc)); okc=0
        warn "批量部署回滚：成功 $okc；失败 $failc"
      fi    else
      warn "整体检查未通过（单个协议都已通过，可能是端口冲突等跨协议问题）"
      warn "具体报错：$(_collect_sb_error)"
      warn "恢复批量前备份"
      rollback
      failc=$((okc+failc)); okc=0
      warn "批量部署回滚：成功 $okc；失败 $failc"
    fi
    echo
    show_nodes
    echo
    show_links
    goto_sub
}

client_menu(){
  while :; do
    clear
    panel "客户端设置"
    kv "uTLS 指纹" "$FINGERPRINT"
    local cur_sni
    cur_sni="$(sni_default)"
    kv "默认 SNI" "$cur_sni"
    if [ "$UOT_ENABLED" = "1" ]; then
        kv "UDP over TCP" "${GREEN}已开启${RESET}"
    else
        kv "UDP over TCP" "${DIM}已关闭${RESET}"
    fi
    local _nm_pre="${NODE_NAME_PREFIX:-${COUNTRY_NAME:-}}"
    if [ -n "$_nm_pre" ]; then
        kv "节点命名" "${_nm_pre} <协议类型>"
    else
        kv "节点命名" "${DIM}<协议类型>（未探测到国家）${RESET}"
    fi
    hr
    echo "  1. 修改 uTLS 指纹（Reality / Clash 伪装）"
    echo "  2. 切换 UDP over TCP（UoT）"
    echo "  3. SNI 域名优选（实测 TLS 握手，自动选最快的）"
    echo "  4. 手动指定默认 SNI 域名"
    echo "  5. 节点命名（默认 国家/地区 + 协议类型，可自定义前缀）"
    echo "  0. 返回"
    read -r -p "请选择： " c || c=""
    case "$c" in
      1)
        echo
        echo "${BOLD}常用客户端指纹（uTLS）：${RESET}"
        echo "  1. chrome    （默认，兼容性最好）"
        echo "  2. firefox"
        echo "  3. safari"
        echo "  4. ios"
        echo "  5. android"
        echo "  6. edge"
        echo "  7. 360"
        echo "  8. qq"
        echo "  9. random    （每次连接随机指纹）"
        echo " 10. randomized（固定但与 chrome 不同的随机值）"
        echo
        echo "当前：${BOLD}$FINGERPRINT${RESET}"
        echo "可选：输入序号，或直接输入自定义指纹值"
        read -r -p "请选择/输入 [回车保持不变]： " a || a=""
        [ -n "$a" ] || { info "保持 $FINGERPRINT 不变"; pause; continue; }
        case "$a" in
            1) a=chrome ;;
            2) a=firefox ;;
            3) a=safari ;;
            4) a=ios ;;
            5) a=android ;;
            6) a=edge ;;
            7) a=360 ;;
            8) a=qq ;;
            9) a=random ;;
            10) a=randomized ;;
        esac
        if [[ "$a" =~ ^[A-Za-z0-9_-]+$ ]]; then
            FINGERPRINT="$a"; save_settings; export_all 2>/dev/null
            ok "指纹已更新为：$FINGERPRINT（已重新生成订阅）"; pause
        else
            warn "指纹只能包含字母、数字、下划线和连字符"; pause
        fi ;;
      2)
        echo
        echo "${BOLD}UDP over TCP（UoT）${RESET}"
        echo "  把 UDP 数据封装进 TCP 连接传输，用于网络限制 UDP 的场景。"
        echo "  开启后导出的客户端链接会带上 udp-over-tcp 参数。"
        echo
        echo "  注意："
        echo "   • 只对 TCP 传输的协议生效（Reality/WS/gRPC/Trojan 等）"
        echo "   • Hysteria2 / TUIC / HTTP/3 本身就是原生 UDP，不受影响"
        echo "   • 会牺牲部分延迟（TCP 重传/队头阻塞），能用原生 UDP 时不必开"
        echo
        if [ "$UOT_ENABLED" = "1" ]; then
            echo "当前状态：${GREEN}已开启${RESET}"
        else
            echo "当前状态：${DIM}已关闭${RESET}"
        fi
        echo
        echo "1. 开启"
        echo "2. 关闭"
        echo "0. 返回"
        read -r -p "请选择： " u || u=""
        case "$u" in
          1) UOT_ENABLED=1; save_settings; export_all 2>/dev/null; ok "UoT 已开启，订阅已重新生成" ;;
          2) UOT_ENABLED=0; save_settings; export_all 2>/dev/null; ok "UoT 已关闭，订阅已重新生成" ;;
          0) continue ;;
          *) warn "无效"; sleep 1; continue ;;
        esac
        pause ;;
      3)
        sni_optimize; pause ;;
      4)
        echo
        echo "  当前默认 SNI：${BOLD}$(sni_default)${RESET}"
        echo "  直接回车保持；输入域名则改为该域名（例如 www.apple.com）"
        read -r -p "新的默认 SNI： " ns || ns=""
        if [ -z "$ns" ]; then
            info "保持不变"; pause; continue
        fi
        if [[ "$ns" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
            SNI_OPTIMIZED="$ns"
            printf '%s\n' "$ns" > "$SNI_TESTED_FILE"
            if [ -f "$SETTINGS" ]; then
                if grep -q '^PREFERRED_SNI=' "$SETTINGS" 2>/dev/null; then
                    sed -i "s|^PREFERRED_SNI=.*|PREFERRED_SNI=${ns}|" "$SETTINGS"
                else
                    printf 'PREFERRED_SNI=%s\n' "$ns" >>"$SETTINGS"
                fi
            fi
            ok "默认 SNI 已设为：$ns（后续新建节点生效）"
        else
            warn "域名格式不合法"
        fi
        pause ;;
      5)
        echo
        echo "${BOLD}节点命名规则${RESET}"
        echo "  新建节点时的名字 =「前缀 + 协议类型」，例如："
        echo "    ${CYAN}中国香港 VLESS + Reality${RESET}  /  ${CYAN}中国香港 Hysteria2${RESET}"
        echo
        echo "  当前国家/地区：${BOLD}${COUNTRY_NAME:-未探测到}${RESET}"
        echo "  当前自定义前缀：${BOLD}${NODE_NAME_PREFIX:-（未设置，用国家/地区名）}${RESET}"
        echo
        echo "  1. 设置自定义前缀（如 HK-01 / 香港01 / Tokyo）"
        echo "  2. 清空前缀，改用国家/地区名"
        echo "  3. 立即把已有节点按当前规则重命名"
        echo "  0. 返回"
        read -r -p "请选择： " nn || nn=""
        case "$nn" in
          1)
            read -r -p "  输入前缀（直接回车取消）： " _np || _np=""
            if [ -n "$_np" ]; then
              NODE_NAME_PREFIX="$_np"; save_settings
              ok "前缀已设为：$_np（新建节点时生效）"
            else
              info "已取消"
            fi ;;
          2) NODE_NAME_PREFIX=""; save_settings; ok "已改为使用国家/地区名" ;;
          3)
            if rename_nodes_default; then
              export_all >/dev/null 2>&1
              ok "已按当前规则重命名全部节点，订阅已刷新"
            else
              warn "重命名失败"
            fi ;;
          0) continue ;;
          *) warn "无效选项"; sleep 1; continue ;;
        esac
        pause ;;
      0) return ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}

port_menu(){
  while :; do
    clear
    panel "端口范围 / 默认端口"
    kv "TCP 范围" "${MIN_TCP}-${MAX_TCP}"
    kv "UDP 范围" "${MIN_UDP}-${MAX_UDP}"
    kv "TCP 默认" "$DEFAULT_TCP_START"
    kv "UDP 默认" "$DEFAULT_UDP_START"
    hr
    echo "  1. 修改 TCP 端口范围"
    echo "  2. 修改 UDP 端口范围"
    echo "  3. 修改 TCP 默认开始端口"
    echo "  4. 修改 UDP 默认开始端口"
    echo "  5. 查看节点端口"
    echo "  0. 返回"
    read -r -p "请选择： " c || c=""
    case "$c" in
      1)
        read -r -p "TCP 最小端口： " a; read -r -p "TCP 最大端口： " b
        valid_port "$a" && valid_port "$b" && [ "$a" -lt "$b" ] || { warn "范围无效"; pause; continue; }
        MIN_TCP="$a"; MAX_TCP="$b"; if ! port_in_range "$DEFAULT_TCP_START" tcp; then DEFAULT_TCP_START="$a"; fi; save_settings; ok "TCP范围已保存"; pause ;;
      2)
        read -r -p "UDP 最小端口： " a; read -r -p "UDP 最大端口： " b
        valid_port "$a" && valid_port "$b" && [ "$a" -lt "$b" ] || { warn "范围无效"; pause; continue; }
        MIN_UDP="$a"; MAX_UDP="$b"; if ! port_in_range "$DEFAULT_UDP_START" udp; then DEFAULT_UDP_START="$a"; fi; save_settings; ok "UDP范围已保存"; pause ;;
      3)
        read -r -p "TCP默认开始端口： " a
        valid_port "$a" && port_in_range "$a" tcp || { warn "端口无效"; pause; continue; }
        DEFAULT_TCP_START="$a"; save_settings; pause ;;
      4)
        read -r -p "UDP默认开始端口： " a
        valid_port "$a" && port_in_range "$a" udp || { warn "端口无效"; pause; continue; }
        DEFAULT_UDP_START="$a"; save_settings; pause ;;
      5) jq -r '.[] | "\(.name)\t\(.proto)\t\(.port)"' "$NODES"; pause ;;
      0) return ;;
      *) warn "无效"; sleep 1 ;;
    esac
  done
}

change_node_port(){
    local total
    total="$(jq 'length' "$NODES" 2>/dev/null || echo 0)"
    if [ "$total" -eq 0 ]; then warn "暂无节点"; return 1; fi

    panel "修改节点端口"
    jq -r 'to_entries[] | "  \(.key+1). \(.value.name)  [\(.value.proto)]  \(.value.port)"' "$NODES"
    local n idx
    read -r -p "  选择要修改的节点编号（0 取消）： " n || n=""
    [ "$n" = "0" ] && return 0
    case "$n" in ''|*[!0-9]*) warn "无效输入"; return 1 ;; esac
    idx=$((n-1))
    [ "$idx" -ge 0 ] && [ "$idx" -lt "$total" ] || { warn "节点编号不存在"; return 1; }

    local name proto oldport
    name="$(jq -r ".[$idx].name" "$NODES")"
    proto="$(jq -r ".[$idx].proto" "$NODES")"
    oldport="$(jq -r ".[$idx].port" "$NODES")"

    echo
    info "当前节点：$name（$proto 端口 $oldport）"
    local rng
    rng="$([ "$proto" = udp ] && echo "$MIN_UDP-$MAX_UDP" || echo "$MIN_TCP-$MAX_TCP")"
    local np
    while :; do
        read -r -p "  新端口（留空回车自动分配，范围 $rng）： " np || np=""
        if [ -z "$np" ]; then
            np="$(rand_free_port "$proto" 4)" || { warn "端口段内没有空闲端口"; return 1; }
            echo "  已自动分配：$np"
            break
        fi
        valid_port "$np" || { warn "请输入 1-65535 的数字"; continue; }
        port_in_range "$np" "$proto" || { warn "端口不在当前 $proto 段（$rng）内"; continue; }
        [ "$np" = "$oldport" ] && { warn "新端口与旧端口相同，无需修改"; continue; }
        if port_in_config "$np"; then warn "端口 $np 已被其它节点占用"; continue; fi
        if port_used "$np"; then
            local a
            read -r -p "  端口 $np 当前有进程监听，仍要使用吗？[y/N] " a || a=""
            case "$a" in y|Y) : ;; *) continue ;; esac
        fi
        break
    done

    backup
    jq --argjson old "$oldport" --argjson new "$np" --arg proto "$proto" '
      def is_udp_inbound:
        if (.type == "hysteria2" or .type == "tuic") then true
        elif (.type == "http") then ((.version // []) | index(3)) != null
        else false end;
      ( [ .inbounds[]? | select(.listen_port == $old)
            | select( if $proto == "udp"
                      then is_udp_inbound
                      else (is_udp_inbound | not) end ) ] | length ) as $cnt
      | if $cnt == 0 then .
        else
          ( [ .inbounds[]? | select(.listen_port == $old)
                | select( if $proto == "udp"
                          then is_udp_inbound
                          else (is_udp_inbound | not) end ) ][0] ) as $victim
          | .inbounds |= map(if . == $victim then .listen_port = $new else . end)
        end
    ' "$CONF" > "$CONF.tmp" 2>/dev/null && mv "$CONF.tmp" "$CONF" || { rm -f "$CONF.tmp"; warn "配置写入失败"; return 1; }

    jq --argjson i "$idx" --argjson new "$np" '.[$i].port = $new' "$NODES" > "$NODES.tmp" 2>/dev/null \
        && mv "$NODES.tmp" "$NODES" || { rm -f "$NODES.tmp"; warn "节点记录写入失败"; return 1; }

    if ! validate >/dev/null 2>&1; then
        warn "改端口后配置检查未通过，正在回滚"
        local _err
        _err="$("$BIN" check -c "$CONF" 2>&1 | head -n 3 | tr '\n' ' ')"
        [ -n "$_err" ] && warn "  $_err"
        jq --argjson new "$np" --argjson old "$oldport" --arg proto "$proto" '
          def is_udp_inbound:
            if (.type == "hysteria2" or .type == "tuic") then true
            elif (.type == "http") then ((.version // []) | index(3)) != null
            else false end;
          ( [ .inbounds[]? | select(.listen_port == $new)
                | select( if $proto == "udp"
                          then is_udp_inbound
                          else (is_udp_inbound | not) end ) ][0] ) as $v
          | .inbounds |= map(if . == $v then .listen_port = $old else . end)
        ' "$CONF" > "$CONF.tmp" 2>/dev/null && mv "$CONF.tmp" "$CONF" || rm -f "$CONF.tmp"
        jq --argjson i "$idx" --argjson old "$oldport" '.[$i].port = $old' "$NODES" > "$NODES.tmp" 2>/dev/null \
            && mv "$NODES.tmp" "$NODES" || rm -f "$NODES.tmp"
        return 1
    fi
    if apply; then
        export_all >/dev/null 2>&1 || true
        ok "端口已修改：$oldport → $np"
        info "链接、二维码、Clash 订阅均已同步更新（用「3」查看）"
    else
        warn "服务重启后未存活，配置已改但可能未生效，请到「服务管理」查看日志"
        return 1
    fi
}

manage_nodes(){
  while :; do
    clear
    show_nodes
    echo "1. 删除指定节点"
    echo "2. 删除全部节点"
    echo "3. 显示全部节点链接"
    echo "4. 一键复制全部节点"
    echo "5. 显示二维码（单个 / 全部）"
    echo "6. 修改节点端口"
    echo "7. 重命名节点（按国家+协议 / 加前缀 / 单个改名）"
    echo "8. 清理孤儿入站（config 里有、节点列表里没有）"
    echo "0. 返回"
    read -r -p "请选择： " c || c=""
    case "$c" in
      8) clear; cleanup_orphan_inbounds; pause; continue ;;
      7)
        echo
        echo "  当前命名规则：${BOLD}${NODE_NAME_PREFIX:-${COUNTRY_NAME:-（未探测到国家）}} <协议类型>${RESET}"
        echo
        echo "1. 全部按「国家/地区 + 协议类型」重命名"
        echo "2. 全部加统一前缀"
        echo "3. 单个节点改名"
        echo "0. 返回"
        read -r -p "请选择： " rn || rn=""
        case "$rn" in
          1)
            if rename_nodes_default; then
              export_all >/dev/null 2>&1; ok "已按「国家/地区 + 协议类型」重命名"
            else warn "重命名失败"; fi
            pause ;;
          2)
            read -r -p "  输入前缀（直接回车取消）： " _p || _p=""
            if [ -z "$_p" ]; then info "已取消"; pause; continue; fi
            if rename_nodes_prefix "$_p"; then
              export_all >/dev/null 2>&1; ok "已为全部节点加上前缀：$_p"
            else warn "重命名失败"; fi
            pause ;;
          3)
            jq -r 'to_entries[] | "\(.key+1). \(.value.name)"' "$NODES"
            read -r -p "输入编号： " _n || _n=""
            [[ "$_n" =~ ^[0-9]+$ ]] || { warn "无效"; pause; continue; }
            local _i=$((_n-1)) _cnt
            _cnt="$(jq 'length' "$NODES")"
            [ "$_i" -ge 0 ] && [ "$_i" -lt "$_cnt" ] || { warn "节点编号不存在"; pause; continue; }
            read -r -p "新名称： " _new || _new=""
            if [ -z "$_new" ]; then info "已取消"; pause; continue; fi
            jq --argjson i "$_i" --arg nm "$_new" '.[$i].name = $nm' \
                "$NODES" > "$NODES.tmp" 2>/dev/null && mv "$NODES.tmp" "$NODES" || { rm -f "$NODES.tmp"; warn "改名失败"; pause; continue; }
            export_all >/dev/null 2>&1; ok "已改名为：$_new"
            pause ;;
          0) continue ;;
          *) warn "无效"; sleep 1 ;;
        esac ;;
      6) clear; change_node_port; pause; continue ;;
      1)
        jq -r 'to_entries[] | "\(.key+1). \(.value.name) : \(.value.proto) \(.value.port)"' "$NODES"
        read -r -p "输入编号： " n
        [[ "$n" =~ ^[0-9]+$ ]] || { warn "无效"; pause; continue; }
        idx=$((n-1))
        count="$(jq 'length' "$NODES")"
        [ "$idx" -ge 0 ] && [ "$idx" -lt "$count" ] || { warn "节点编号不存在"; pause; continue; }
        port="$(jq -r ".[$idx].port" "$NODES")"
        proto="$(jq -r ".[$idx].proto" "$NODES")"
        jq --argjson port "$port" --arg proto "$proto" '
          def is_udp_inbound:
            if (.type == "hysteria2" or .type == "tuic") then true
            elif (.type == "http") then ((.version // []) | index(3)) != null
            else false end;
          .inbounds |= (
            [ .[] | select(.listen_port == $port)
                  | select( if $proto == "udp"
                            then is_udp_inbound
                            else (is_udp_inbound | not) end ) ] as $hits
            | if ($hits | length) == 0 then .
              else ($hits[0]) as $victim | map(select(. != $victim))
              end
          )' "$CONF" >"$CONF.tmp" && mv "$CONF.tmp" "$CONF"
        jq "del(.[$idx])" "$NODES" >"$NODES.tmp" && mv "$NODES.tmp" "$NODES"
        if validate; then apply; export_all; ok "节点已删除"; else warn "删除后配置检查失败"; fi
        pause ;;
      2)
        read -r -p "输入 DELETE 确认： " x
        [ "$x" = DELETE ] || { warn "已取消"; pause; continue; }
        echo '[]' >"$NODES"; init_files
        jq '.inbounds=[]' "$CONF" >"$CONF.tmp" && mv "$CONF.tmp" "$CONF"
        apply || true; export_all; pause ;;
      3) export_all >/dev/null 2>&1; show_links; pause ;;
      4) copy_links; pause ;;
      5)
        echo
        echo "1. 单个节点"
        echo "2. 全部节点"
        echo "0. 返回"
        read -r -p "请选择： " q || q=""
        case "$q" in
          1)
            jq -r 'to_entries[] | "\(.key+1). \(.value.name) : \(.value.proto) \(.value.port)"' "$NODES"
            read -r -p "输入编号： " n
            [[ "$n" =~ ^[0-9]+$ ]] || { warn "无效"; pause; continue; }
            idx=$((n-1))
            count="$(jq 'length' "$NODES")"
            [ "$idx" -ge 0 ] && [ "$idx" -lt "$count" ] || { warn "节点编号不存在"; pause; continue; }
            show_qr_for_node "$idx"
            pause ;;
          2) show_qr_all; pause ;;
          0) continue ;;
          *) warn "无效"; sleep 1 ;;
        esac ;;
      0) return ;;
      *) warn "无效"; sleep 1 ;;
    esac
  done
}
service_menu(){
  while :; do
    clear
    panel "Sing-box 服务管理"
    local alive=0; service_alive && alive=1
    local s_sum ncnt
    s_sum="$(service_summary)"
    ncnt="$(jq 'length' "$NODES" 2>/dev/null || echo 0)"
    kv "当前状态" "$(status_line "$alive" "$s_sum" "$ncnt")" \
       "$([ "$alive" = 1 ] && echo "$GREEN" || echo "$RED")"
    hr
    echo "1. 查看状态（systemd 完整输出）"
    echo "2. 重启"
    echo "3. 停止"
    echo "4. 启动"
    echo "5. 检查配置"
    echo "0. 返回"
    read -r -p "请选择： " x || x=""
    case "$x" in
      1) status; pause ;;
      2) apply; pause ;;
      3) if [ "$INIT" = systemd ]; then systemctl stop sing-box; elif [ "$INIT" = openrc ]; then rc-service sing-box stop; fi; pause ;;
      4) if [ "$INIT" = systemd ]; then systemctl start sing-box; elif [ "$INIT" = openrc ]; then rc-service sing-box start; fi; pause ;;
      5) validate; pause ;;
      0) return ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}
singbox_menu(){
  while :; do
    clear
    panel "sing-box 内核管理"
    local cur
    cur="$(sb_version)"
    if [ -n "$cur" ]; then
        kv "内核版本" "$cur"
    else
        kv "内核版本" "${RED}未安装${RESET}"
    fi
    if [ -x "$BIN" ]; then
        kv "二进制" "${GREEN}$BIN${RESET}"
    else
        kv "二进制" "${RED}$BIN 不存在${RESET}"
    fi
    local sz=""
    [ -d "$BASE" ] && sz="$(du -sh "$BASE" 2>/dev/null | awk '{print $1}')"
    kv "数据目录" "$BASE${sz:+  ${DIM}(${sz})${RESET}}"
    kv "配置文件" "$([ -f "$CONF" ] && echo 存在 || echo ${DIM}无${RESET})"
    kv "管理命令" "$SB"
    if [ "$INIT" = systemd ]; then
        kv "服务文件" "/etc/systemd/system/sing-box.service"
    elif [ "$INIT" = openrc ]; then
        kv "服务文件" "/etc/init.d/sing-box"
    fi
    hr
    echo "1. 查看 sing-box 版本详情"
    echo "2. 升级 / 切换内核版本（最新版 / 正式版 / 列表选择 / 手输）"
    echo "3. 只重装内核（配置和节点都保留）"
    echo "4. 查看配置文件路径与内容"
    echo "5. 只卸载内核二进制（保留配置和节点）"
    echo "0. 返回"
    echo
    echo "  ${DIM}需要彻底删除（含配置/节点/本脚本）请用主菜单的「卸载」${RESET}"
    read -r -p "请选择： " x || x=""
    case "$x" in
      1) sb_version_detail; pause ;;
      2) upgrade_singbox ;;
      3) reinstall_singbox_bin ;;
      4) sb_conf_info ;;
      5) remove_singbox_bin ;;
      0) return ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}
sb_version_detail(){
    panel "sing-box 版本详情"
    if [ ! -x "$BIN" ]; then
        warn "未找到可执行文件：$BIN"
        return 1
    fi
    "$BIN" version 2>&1 | sed 's/^/  /'
    hr
    local v; v="$(sb_version)"
    kv "解析版本" "${v:-未知}"
    if version_ge "1.15.0" "$v"; then
        kv "HTTP/3 支持" "${GREEN}支持${RESET}（version 字段可用）"
    else
        kv "HTTP/3 支持" "${YELLOW}不支持${RESET}（需 1.15.0+，可到「2」升级）"
    fi
    if version_ge "1.11.0" "$v"; then
        kv "AnyTLS 支持" "${GREEN}支持${RESET}"
    else
        kv "AnyTLS 支持" "${YELLOW}不支持${RESET}（需 1.11.0+）"
    fi
    hr
}
sb_conf_info(){
    panel "sing-box 配置文件"
    if [ ! -f "$CONF" ]; then
        warn "配置文件不存在：$CONF"
        return 1
    fi
    kv "路径" "$CONF"
    kv "大小" "$(wc -c <"$CONF" 2>/dev/null | tr -d ' ') 字节"
    kv "inbound 数" "$(jq '(.inbounds // []) | length' "$CONF" 2>/dev/null || echo 0)"
    kv "JSON 校验" "$(jq empty "$CONF" >/dev/null 2>&1 && echo "${GREEN}通过${RESET}" || echo "${RED}失败${RESET}")"
    hr
    cat "$CONF"
}
remove_singbox_bin(){
    panel "只卸载内核二进制"
    echo "将删除：$BIN"
    echo "将保留：$BASE （配置 / 节点 / 订阅 / 证书 / 日志）"
    hr
    read -r -p "输入 REMOVE 确认： " x || x=""
    [ "$x" = REMOVE ] || { info "已取消"; pause; return; }
    [ -x "$BIN" ] || { warn "$BIN 本来就不存在"; pause; return; }
    progress 40 "停止 sing-box 服务"
    if [ "$INIT" = systemd ]; then
        systemctl stop sing-box >/dev/null 2>&1 || true
    elif [ "$INIT" = openrc ]; then
        rc-service sing-box stop >/dev/null 2>&1 || true
    fi
    pkill -f "$BIN run -c $CONF" 2>/dev/null || true
    progress 80 "删除内核二进制"
    rm -f "$BIN"
    rm -f "$VERSION_FILE" 2>/dev/null || true
    progress 100 "完成"
    if [ -x "$BIN" ]; then
        warn "删除失败，请检查权限"
    else
        ok "内核二进制已删除，配置与节点仍保留在 $BASE"
        info "重新安装内核：选「2 升级 / 切换内核版本」或「3 只重装内核」"
    fi
    pause
}
reinstall_singbox_bin(){
    panel "重装 sing-box 内核"
    local cur; cur="$(sb_version)"
    kv "当前版本" "${cur:-未安装}"
    kv "下载渠道" "$(_channel_label)"
    hr
    echo "将重新下载内核并覆盖 $BIN，配置与节点不受影响。"
    read -r -p "确认重装？[Y/n] " x || x=""
    case "${x:-Y}" in n|N) info "已取消"; pause; return ;; esac
    backup
    local bak="${BIN}.bak"
    [ -x "$BIN" ] && cp -f "$BIN" "$bak" 2>/dev/null || true
    progress 30 "下载 sing-box ${cur:-最新版}"
    if ! download_singbox "${cur:-}"; then
        warn "下载失败，保持原状态"
        [ -x "$bak" ] && mv -f "$bak" "$BIN" 2>/dev/null || true
        pause; return 1
    fi
    progress 75 "重启服务验证"
    if apply; then
        rm -f "$bak" 2>/dev/null || true
        progress 100 "完成"
        ok "内核已重装：$(sb_version)"
    else
        warn "启动失败，回滚内核与配置"
        [ -x "$bak" ] && mv -f "$bak" "$BIN" 2>/dev/null || true
        rollback
        apply >/dev/null 2>&1 || true
    fi
    pause
}
sub_menu(){
  while :; do
    clear
    show_links
    echo
    if [ "$(sub_status 2>/dev/null)" = "on" ]; then
        echo "  ${GREEN}●${RESET} 订阅服务已开启，客户端填这一个地址即可："
        echo "    ${CYAN}$(sub_url 2>/dev/null)${RESET}"
    else
        echo "  ${DIM}○ 订阅服务未开启 —— 开启后可用「一个 URL 适配所有客户端」（见 6）${RESET}"
    fi
    echo
    echo "1. 一键复制全部链接（OSC52）"
    echo "2. 显示二维码（单个 / 全部）"
    echo "3. 查看 / 复制 Clash 配置（含 mihomo）"
    echo "4. 查看 / 复制 v2rayN 订阅（自动指定 sing-box 内核）"
    echo "5. 查看 / 复制 小火箭订阅（纯标准链接，识别率最高）"
    echo "6. 查看 sing-box 配置"
    echo "7. 订阅服务（开启后一个 URL 走天下，按客户端自动适配格式）"
    echo "0. 返回"
    read -r -p "请选择： " x || x=""
    case "$x" in
      1) export_all >/dev/null 2>&1; copy_links; pause ;;
      2) qr_menu ;;
      3) clash_sub_menu ;;
      4) v2rayn_sub_menu ;;
      5) shadowrocket_sub_menu ;;
      6) cat "$CONF"; pause ;;
      7) subhttp_menu ;;
      0) return ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}
v2rayn_sub_menu(){
  while :; do
    echo
    echo "1. 查看单条链接（v2rayn:// 或标准格式）"
    echo "2. 查看 v2rayN 订阅原文（base64）"
    echo "3. 复制 v2rayN 订阅到剪贴板"
    echo "0. 返回"
    read -r -p "请选择： " q || q=""
    case "$q" in
      1)
        export_v2rayn >/dev/null 2>&1
        if [ ! -s "$SUBDIR/v2rayn_raw.txt" ]; then warn "暂无节点"; pause; continue; fi
        cat "$SUBDIR/v2rayn_raw.txt"
        pause ;;
      2)
        export_v2rayn >/dev/null 2>&1
        if [ ! -s "$SUBDIR/v2rayn_subscribe.txt" ]; then warn "暂无节点"; pause; continue; fi
        echo
        info "下面整段复制，在 v2rayN「订阅 → 添加订阅 → 手动输入」里粘贴："
        echo
        cat "$SUBDIR/v2rayn_subscribe.txt"; echo
        pause ;;
      3)
        export_v2rayn >/dev/null 2>&1
        if [ ! -s "$SUBDIR/v2rayn_subscribe.txt" ]; then warn "暂无节点"; pause; continue; fi
        copy_text "$(cat "$SUBDIR/v2rayn_subscribe.txt")"
        pause ;;
      0) return ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}
shadowrocket_sub_menu(){
  while :; do
    echo
    echo "1. 查看单条链接（纯标准格式）"
    echo "2. 查看订阅原文（base64）"
    echo "3. 复制订阅到剪贴板"
    echo "0. 返回"
    read -r -p "请选择： " q || q=""
    case "$q" in
      1)
        export_shadowrocket >/dev/null 2>&1
        if [ ! -s "$SUBDIR/shadowrocket_raw.txt" ]; then warn "暂无节点"; pause; continue; fi
        echo
        info "以下为标准链接，小火箭可直接逐条导入："
        cat "$SUBDIR/shadowrocket_raw.txt"
        pause ;;
      2)
        export_shadowrocket >/dev/null 2>&1
        if [ ! -s "$SUBDIR/shadowrocket_subscribe.txt" ]; then warn "暂无节点"; pause; continue; fi
        echo
        info "下面整段复制，在小火箭「添加订阅」里粘贴："
        echo
        cat "$SUBDIR/shadowrocket_subscribe.txt"; echo
        pause ;;
      3)
        export_shadowrocket >/dev/null 2>&1
        if [ ! -s "$SUBDIR/shadowrocket_subscribe.txt" ]; then warn "暂无节点"; pause; continue; fi
        copy_text "$(cat "$SUBDIR/shadowrocket_subscribe.txt")"
        pause ;;
      0) return ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}
clash_sub_menu(){
  while :; do
    echo
    echo "1. 查看 Clash 配置（clash.yaml）"
    echo "2. 复制 Clash 订阅到剪贴板"
    echo "0. 返回"
    read -r -p "请选择： " q || q=""
    case "$q" in
      1) export_clash >/dev/null 2>&1; cat "$SUBDIR/clash.yaml"; pause ;;
      2) export_clash >/dev/null 2>&1
         if [ ! -s "$SUBDIR/clash_subscribe.txt" ]; then warn "暂无节点"; pause; continue; fi
         copy_text "$(cat "$SUBDIR/clash_subscribe.txt")"; pause ;;
      0) return ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}
qr_menu(){
  while :; do
    echo
    echo "1. 单个节点"
    echo "2. 全部节点"
    echo "0. 返回"
    read -r -p "请选择： " q || q=""
    case "$q" in
      1)
        jq -r 'to_entries[] | "\(.key+1). \(.value.name) : \(.value.proto) \(.value.port)"' "$NODES"
        read -r -p "输入编号： " n || n=""
        [[ "$n" =~ ^[0-9]+$ ]] || { warn "无效"; pause; continue; }
        local idx=$((n-1)) count
        count="$(jq 'length' "$NODES")"
        [ "$idx" -ge 0 ] && [ "$idx" -lt "$count" ] || { warn "节点编号不存在"; pause; continue; }
        show_qr_for_node "$idx"; pause ;;
      2) show_qr_all; pause ;;
      0) return ;;
      *) warn "无效"; sleep 1 ;;
    esac
  done
}

menu(){
  while :; do
    clear
    local _title="Sing-box NAT · ${VERSION} · 多协议管理器"
    local _tw=0 _ch _i
    for ((_i=0; _i<${#_title}; _i++)); do
        _ch="${_title:_i:1}"
        case "$_ch" in
            [!\ -~]) _tw=$((_tw+2)) ;;
            *)       _tw=$((_tw+1)) ;;
        esac
    done
    local _fill=$(( 50 - 2 - _tw ))
    [ "$_fill" -lt 0 ] && _fill=0
    echo "${BOLD}┌────────────────────────────────────────────────┐${RESET}"
    printf '%s│%s %s%*s %s│%s\n' \
        "$BOLD" "$RESET" \
        "${MAGENTA}${BOLD}Sing-box NAT${RESET} ${DIM}·${RESET} ${YELLOW}${BOLD}${VERSION}${RESET} ${DIM}·${RESET} ${BOLD}多协议管理器${RESET}" \
        "$_fill" "" \
        "$BOLD" "$RESET"
    echo "${BOLD}└────────────────────────────────────────────────┘${RESET}"

    local alive=0
    service_alive && alive=1
    local nodecount
    nodecount="$(jq 'length' "$NODES" 2>/dev/null || echo 0)"
    local s_sum s_st s_upt s_mem s_pid s_ver s_en s_cpu
    s_sum="$(service_summary)"
    IFS='|' read -r s_st s_upt s_mem s_pid s_ver s_en s_cpu <<<"$s_sum"
    kv "服务状态" "$(status_line "$alive" "$s_sum" "$nodecount")" \
       "$([ "$alive" = 1 ] && echo "$GREEN" || echo "$RED")"
    local _subst
    _subst="$(sub_status 2>/dev/null)"
    if [ "$_subst" = "on" ]; then
        local _subres="$(sub_resource 2>/dev/null)"
        kv "订阅服务" "$(status_dot 1) ${GREEN}运行中${RESET}  ${DIM}:${SUBHTTP_LISTEN:-8088}${RESET}  ${_subres}"
    else
        kv "订阅服务" "$(status_dot 0) ${DIM}未开启${RESET}  ${DIM}(菜单 9 → 6)${RESET}"
    fi
    kv "系统" "${OS} ${VER}"
    kv "服务器" "${COUNTRY_NAME:-未知}${COUNTRY_CODE:+ ($COUNTRY_CODE)}"
    kv "部署地址" "${SERVER_IP}"
    if [ "$UDP_OK" = "0" ]; then
        kv "端口段" "TCP ${MIN_TCP}-${MAX_TCP}   ${RED}UDP 不可用${RESET}"
    else
        kv "端口段" "TCP ${MIN_TCP}-${MAX_TCP}   ${GREEN}UDP ${MIN_UDP}-${MAX_UDP}${RESET}"
    fi
    kv "系统时间" "$(now_time)  ${DIM}[$(now_tz)  运行 $(uptime_human)]${RESET}"
    if [ -z "${_MENUV_CACHE:-}" ]; then
        _MENUV_CACHE="$(script_version_of "$MENU" 2>/dev/null)"
    fi
    local _menuv="$_MENUV_CACHE"
    if [ -n "$_menuv" ] && [ "$_menuv" != "$VERSION" ]; then
        kv "脚本更新" "${YELLOW}已装 $_menuv，当前源码 $VERSION${RESET}" "$YELLOW"
        kv "生效方式" "${DIM}菜单跑的是 menu.sh 快照，执行 ${RESET}sb update${DIM} 后新逻辑才生效${RESET}"
    fi
    hr

    local i=1
    printf '  %s%2d.%s %s\n' "$BOLD" "$i" "$RESET" "节点部署"; i=$((i+1))
    printf '  %s%2d.%s %s\n' "$BOLD" "$i" "$RESET" "批量部署（单选/多选/all）"; i=$((i+1))
    printf '  %s%2d.%s %s\n' "$BOLD" "$i" "$RESET" "节点管理"; i=$((i+1))
    echo
    printf '  %s%2d.%s %s\n' "$BOLD" "$i" "$RESET" "端口范围 / 默认端口"; i=$((i+1))
    printf '  %s%2d.%s %s\n' "$BOLD" "$i" "$RESET" "网络检测 / UDP 模式"; i=$((i+1))
    printf '  %s%2d.%s %s\n' "$BOLD" "$i" "$RESET" "客户端设置（指纹 / UoT / SNI）"; i=$((i+1))
    echo
    printf '  %s%2d.%s %s\n' "$BOLD" "$i" "$RESET" "服务管理（启停 / 重启 / 配置检查）"; i=$((i+1))
    printf '  %s%2d.%s %s\n' "$BOLD" "$i" "$RESET" "sing-box 管理（内核版本 / 升级 / 重装）"; i=$((i+1))
    printf '  %s%2d.%s %s\n' "$BOLD" "$i" "$RESET" "订阅与节点链接"; i=$((i+1))
    printf '  %s%2d.%s %s\n' "$BOLD" "$i" "$RESET" "系统信息"; i=$((i+1))
    printf '  %s%2d.%s %s\n' "$BOLD" "$i" "$RESET" "自检 / 修复"; i=$((i+1))
    printf '  %s%2d.%s %s\n' "$BOLD" "$i" "$RESET" "完全卸载（内核 + 配置 + 节点 + 本脚本）"; i=$((i+1))
    echo
    printf '  %s%2d.%s %s\n' "$BOLD" "$i" "$RESET" "检查更新（管理器）"; i=$((i+1))
    echo
    printf '  %s%2d.%s %s\n' "$BOLD" "0" "$RESET" "退出"
    echo
    read -r -p "请选择： " c || c=""
    case "$c" in
      1) node_menu ;;
      2) batch_menu ;;
      3) manage_nodes ;;
      4) port_menu ;;
      5)
        detect_network
        panel "网络检测结果"
        kv "公网 IPv4" "${PUB4:-无}"
        kv "公网 IPv6" "${PUB6:-无}"
        kv "内网 IPv4" "${LOCAL4:-无}"
        kv "NAT 判定" "$NAT_HINT"
        kv "UDP 判定" "$UDP_HINT"
        hr
        if [ "$UDP_OK" = "0" ]; then
            info "当前：UDP 不可用，协议菜单只显示 TCP"
        else
            info "当前：UDP 可用，协议菜单显示全部"
        fi
        echo
        echo "1. 保持当前判定"
        echo "2. 强制按「UDP 可用」显示全部协议"
        echo "3. 强制按「UDP 不可用」只显示 TCP 协议"
        echo "0. 返回"
        read -r -p "请选择： " u || u=""
        case "$u" in
          1) : ;;
          2) UDP_OK=1; UDP_HINT="用户手动设为可用"; ok "已切换为显示全部协议" ;;
          3) UDP_OK=0; UDP_HINT="用户手动设为不可用"; ok "已切换为只显示 TCP 协议" ;;
          0) : ;;
        esac
        case "$u" in
          2|3)
            mkdir -p "$BASE" 2>/dev/null
            printf '%s|%s|%s|%s\n' "$(now_epoch)" "$UDP_OK" "$NAT_HINT" "$LOCAL4" \
                > "$BASE/.net.cache" 2>/dev/null || true
            ;;
        esac
        pause ;;
      6) client_menu ;;
      7) service_menu ;;
      8) singbox_menu ;;
      9) sub_menu ;;
      10) clear; system_info; pause ;;
      11) self_repair ;;
      12) uninstall ;;
      13) check_update ;;
      0) exit 0 ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}

_proc_count(){
    local n="" out
    if command -v pgrep >/dev/null 2>&1; then
        n="$(pgrep -x "$1" 2>/dev/null | wc -l | tr -d ' ')"
    else
        out="$(ps -e -o comm 2>/dev/null)"
        [ -n "$out" ] || return 0
        n="$(printf '%s\n' "$out" | grep -cx -- "$1" 2>/dev/null)"
    fi
    case "$n" in ''|*[!0-9]*) return 0 ;; esac
    printf '%s' "$n"
}
_sys_proc_total(){
    local out n
    out="$(ps -e -o pid 2>/dev/null)"
    [ -n "$out" ] || return 0
    n="$(printf '%s\n' "$out" | grep -c '[0-9]' 2>/dev/null)"
    case "$n" in ''|*[!0-9]*) return 0 ;; esac
    [ "$n" -gt 0 ] || return 0
    printf '%s' "$n"
}
system_info(){
    detect_network
    panel "系统信息"
    local alive=0; service_alive && alive=1
    local s_sum ncnt
    s_sum="$(service_summary)"
    ncnt="$(jq 'length' "$NODES" 2>/dev/null || echo 0)"
    local s_st s_upt s_mem s_pid s_ver s_en s_cpu
    IFS='|' read -r s_st s_upt s_mem s_pid s_ver s_en s_cpu <<<"$s_sum"
    kv "服务状态" "$(status_line "$alive" "$s_sum" "$ncnt")" \
       "$([ "$alive" = 1 ] && echo "$GREEN" || echo "$RED")"
    kv_dash "CPU 占用" "$s_cpu" "%"
    kv_dash "内存占用" "$s_mem"
    kv_dash "已运行" "$s_upt"
    [ -n "$s_ver" ] && kv "内核版本" "sing-box $s_ver"
    [ -n "$s_pid" ] && kv "主进程" "PID $s_pid"
    local _pc_sb _pc_ng _pc_all
    _pc_sb="$(_proc_count sing-box)"; [ -n "$_pc_sb" ] || _pc_sb="${DIM}—${RESET}"
    if nginx_available; then
        _pc_ng="$(_proc_count nginx)"; [ -n "$_pc_ng" ] || _pc_ng="${DIM}—${RESET}"
    else
        _pc_ng="${DIM}未装${RESET}"
    fi
    _pc_all="$(_sys_proc_total)"; [ -n "$_pc_all" ] || _pc_all="${DIM}—${RESET}"
    kv "进程数量" "sing-box ${_pc_sb}   nginx ${_pc_ng}   系统 ${_pc_all}"
    hr
    kv "系统" "$OS $VER"
    kv "架构" "$(uname -m) -> $ARCH"
    kv "Init" "$INIT"
    kv "服务器位置" "${COUNTRY_NAME:-未知}${COUNTRY_CODE:+ ($COUNTRY_CODE)}"
    kv "系统时间" "$(now_time) [$(now_tz)]"
    kv "运行时长" "$(uptime_human)"
    hr
    kv "公网 IPv4" "${PUB4:-无}"
    kv "公网 IPv6" "${PUB6:-无}"
    kv "内网 IPv4" "${LOCAL4:-无}"
    kv "NAT 判定" "$NAT_HINT"
    kv "UDP 判定" "$UDP_HINT"
    hr
    kv "sing-box 路径" "$BIN"
    kv "配置文件" "$CONF"
    kv "节点记录" "$NODES"
    kv "TCP 范围" "$MIN_TCP-$MAX_TCP（默认 $DEFAULT_TCP_START）"
    kv "UDP 范围" "$MIN_UDP-$MAX_UDP（默认 $DEFAULT_UDP_START）"
    kv "uTLS 指纹" "$FINGERPRINT"
    kv "默认 SNI" "$(sni_default)"
    kv "UoT" "$([ "$UOT_ENABLED" = "1" ] && echo 已开启 || echo 已关闭)"
    hr
}
uninstall(){
    clear
    panel "卸载 Sing-box NAT"
    echo "将删除：sing-box、sb、配置、节点、订阅、服务、证书和日志，以及本脚本添加的订阅站点配置。"
    echo "不会主动修改系统已有防火墙规则。"
    read -r -p "输入 DELETE 确认： " x || x=""
    [ "$x" = DELETE ] || { echo "已取消"; pause; return; }

    progress 10 "停止并移除 sing-box 系统服务"
    if [ "$INIT" = systemd ]; then
        systemctl disable --now sing-box >/dev/null 2>&1 || true
        rm -f /etc/systemd/system/sing-box.service
        systemctl daemon-reload || true
    elif [ "$INIT" = openrc ]; then
        rc-service sing-box stop >/dev/null 2>&1 || true
        rc-update del sing-box default >/dev/null 2>&1 || true
        rm -f /etc/init.d/sing-box
    fi
    pkill -f "$BIN run -c $CONF" 2>/dev/null || true

    progress 30 "清理订阅服务残留"
    rm -f "$NGINX_CONF" "$NGINX_CONF_LEGACY" 2>/dev/null || true
    if nginx_available; then
        nginx -t >/dev/null 2>&1 && nginx_reload >/dev/null 2>&1 || true
    fi
    if [ "$INIT" = systemd ]; then
        systemctl stop "${SUBHTTP_SVC}.socket" "${SUBHTTP_SVC}" >/dev/null 2>&1 || true
        systemctl disable "${SUBHTTP_SVC}.socket" "${SUBHTTP_SVC}" >/dev/null 2>&1 || true
        rm -f "/etc/systemd/system/${SUBHTTP_SVC}.socket" "/etc/systemd/system/${SUBHTTP_SVC}.service" 2>/dev/null || true
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
    rm -f "$SUBHTTP_PY" 2>/dev/null || true
    rm -rf "$SUBDIR" 2>/dev/null || true

    if nginx_available; then
        echo
        echo "  ${YELLOW}⚠ 本机仍装有 nginx${RESET}（本脚本为订阅服务安装，或部分卸载后残留/已损坏）。"
        echo "  ${DIM}只移除本脚本的站点配置不会删 nginx 本身；若 nginx 已损坏，建议一并卸载。${RESET}"
        read -r -p "  是否同时卸载 nginx 软件包？[y/N]： " c || c=""
        case "$c" in
          [Yy])
            progress 50 "卸载 nginx 软件包"
            if nginx_uninstall; then ok "nginx 已卸载"; else warn "nginx 卸载失败，请手动执行对应包管理器卸载 nginx"; fi
            ;;
          *) info "已跳过卸载 nginx 包（仅移除了本脚本的站点配置）" ;;
        esac
    fi

    progress 80 "删除程序与管理命令"
    rm -f "$BIN" "$SB" 2>/dev/null || true
    hash -r 2>/dev/null || true
    local _cand
    for _cand in "$SB" /usr/local/bin/sb /usr/bin/sb; do
        [ -f "$_cand" ] || continue
        if grep -q 'sing-box NAT 管理命令入口' "$_cand" 2>/dev/null; then
            rm -f "$_cand" 2>/dev/null || true
        fi
    done
    progress 95 "删除配置 / 节点 / 订阅 / 证书 / 日志"
    rm -rf "$BASE" 2>/dev/null || true
    progress 100 "卸载完成"
    ok "卸载完成"
    exit 0
}

confirm_install(){
    echo
    panel "安装确认"
    echo "  即将在本机安装 Sing-box NAT ${BOLD}${VERSION}${RESET}："
    echo
    echo "    ${DIM}系统${RESET}      ${OS} ${VER}  ${DIM}(${ARCH} / ${INIT})${RESET}"
    echo "    ${DIM}安装目录${RESET}  ${BASE}"
    echo "    ${DIM}内核程序${RESET}  ${BIN}"
    echo "    ${DIM}管理命令${RESET}  sb"
    echo
    echo "  ${DIM}安装过程会自动补装所需依赖（curl / jq / openssl 等）。${RESET}"
    echo "  ${DIM}订阅服务默认不开 —— 装好后需要时再到菜单里自行选择并启动。${RESET}"
    echo
    read -r -p "  确认安装？[Y/n] " a || a=""
    case "${a:-Y}" in
        y|Y|yes|YES|"") return 0 ;;
        *) return 1 ;;
    esac
}
initial_install(){
    need_root
    progress 5 "检测系统环境"
    detect_os
    detect_arch
    confirm_install || { echo "已取消安装"; exit 0; }
    progress 15 "安装系统依赖"
    install_deps
    progress 30 "创建目录与默认配置"
    mkdir -p "$BASE" "$CERTDIR" "$SUBDIR" "$BACKUP" "$LOGDIR"
    load_settings
    save_settings
    init_files
    progress 45 "识别服务器地理位置"
    detect_country
    progress 55 "下载 sing-box（$(_channel_label)）"
    download_singbox
    progress 72 "安装系统服务"
    install_service
    progress 84 "写入管理器"
    if ! write_self_menu; then
        warn "管理器写入失败，安装未完成（内核已装，可重跑安装脚本）"
        exit 1
    fi
    install_sb_cmd
    chmod 0755 "$MENU" 2>/dev/null || true
    progress 92 "启动 sing-box 服务"
    if validate; then
        if [ "$INIT" = systemd ]; then
            systemctl enable --now sing-box >/dev/null 2>&1 || systemctl restart sing-box || true
        elif [ "$INIT" = openrc ]; then
            rc-service sing-box restart >/dev/null 2>&1 || rc-service sing-box start >/dev/null 2>&1 || true
        fi
    else
        warn "默认配置检查失败，已保留安装文件；请进入菜单检查配置"
    fi
    progress 100 "安装完成"
    echo
    ok "Sing-box NAT ${VERSION} 安装完成"
    echo
    echo "  ${BOLD}常用命令${RESET}"
    echo "    ${CYAN}sb${RESET}                    进入菜单"
    echo "    ${CYAN}sb version${RESET}             查看版本"
    echo "    ${CYAN}sb update [脚本URL]${RESET}    更新管理器"
    echo
    info "订阅服务默认未开启：需要时到「订阅与节点链接 → 订阅服务」自行选择实现方式并启动"
}

is_musl(){
    [ "$(libc_kind)" = musl ]
}
_asset_suffixes_json(){
    local base="linux-${ARCH}" s first=1
    local -a list
    if is_musl; then
        list=("${base}-musl" "${base}-glibc" "$base")
    else
        list=("${base}-glibc" "$base" "${base}-musl")
    fi
    printf '['
    for s in "${list[@]}"; do
        [ "$first" = 1 ] || printf ','
        first=0
        printf '"%s"' "$s"
    done
    printf ']'
}
_alt_variant_urls(){
    local url="$1" head_ prefix s
    head_="${url%/*}"
    prefix="${url##*/}"
    prefix="${prefix%.tar.gz}"
    case "$prefix" in
        *-musl)  prefix="${prefix%-musl}" ;;
        *-glibc) prefix="${prefix%-glibc}" ;;
    esac
    local -a order
    if is_musl; then order=(-musl -glibc ""); else order=(-glibc "" -musl); fi
    for s in "${order[@]}"; do
        printf '%s\n' "${head_}/${prefix}${s}.tar.gz"
    done
}
fetch_singbox_release(){
    local api="https://api.github.com/repos/SagerNet/sing-box/releases?per_page=50"
    local json
    json="$(curl -fsSL --max-time 30 "$api" 2>/dev/null)" || return 1
    printf '%s' "$json" | jq -r --argjson sufs "$(_asset_suffixes_json)" --arg ch "${SINGBOX_CHANNEL:-any}" '
      def want: if $ch == "stable" then (.prerelease == false)
                elif $ch == "pre" then (.prerelease == true)
                else true end;
      def verof: (.tag_name | sub("^v";"") | split("-")[0]);
      def restof: ( .tag_name | sub("^v";"") | split("-")[1:] | join("-") | ascii_downcase );
      def tierof:
        if (.prerelease | not) then 4
        elif (restof | contains("rc")) then 3
        elif (restof | contains("beta")) then 2
        elif (restof | contains("alpha")) then 1
        else 0 end;
      def pnumof: ( restof | [ scan("[0-9]+") ] | map(tonumber)
                    | if length > 0 then .[-1] else 0 end );
      def pick: [ $sufs[] as $s | .assets[]? | select(.name | endswith($s + ".tar.gz")) | .browser_download_url ];
      [ .[]
        | select(want)
        | select((pick | length) > 0)
        | { tag: .tag_name,
            ver: verof,
            tier: tierof,
            pnum: pnumof,
            url: ( pick[0] ) }
      ]
      | sort_by([ (.ver | split(".") | map(tonumber? // 0)), .tier, .pnum ])
      | last
      | select(. != null)
      | "\(.tag)\t\(.url)"
    ' 2>/dev/null | head -n1
}
_channel_label(){
    case "${SINGBOX_CHANNEL:-any}" in
        stable) printf '最新正式版\n' ;;
        pre)    printf '最新测试版\n' ;;
        *)      printf '最新版（含 alpha/beta）\n' ;;
    esac
}
fetch_singbox_version(){
    local want="$1" tag url json s
    want="$(printf '%s' "$want" | tr -d '[:space:]' | sed 's/^v//')"
    [ -n "$want" ] || return 1
    tag="v${want}"
    json="$(curl -fsSL --max-time 20 "https://api.github.com/repos/SagerNet/sing-box/releases/tags/${tag}" 2>/dev/null)"
    if [ -n "$json" ]; then
        url="$(printf '%s' "$json" | jq -r --argjson sufs "$(_asset_suffixes_json)" \
            '[ $sufs[] as $s | .assets[]? | select(.name | endswith($s + ".tar.gz")) | .browser_download_url ][0] // empty' 2>/dev/null)"
    fi
    if [ -z "${url:-}" ]; then
        s="linux-${ARCH}"
        is_musl && s="linux-${ARCH}-musl"
        url="https://github.com/SagerNet/sing-box/releases/download/${tag}/sing-box-${want}-${s}.tar.gz"
    fi
    printf '%s\t%s\n' "$tag" "$url"
}
list_singbox_versions(){
    local api="https://api.github.com/repos/SagerNet/sing-box/releases?per_page=50"
    local json
    json="$(curl -fsSL --max-time 30 "$api" 2>/dev/null)" || return 1
    printf '%s' "$json" | jq -r --argjson sufs "$(_asset_suffixes_json)" '
      def restof: ( .tag_name | sub("^v";"") | split("-")[1:] | join("-") | ascii_downcase );
      def tierof:
        if (.prerelease | not) then 4
        elif (restof | contains("rc")) then 3
        elif (restof | contains("beta")) then 2
        elif (restof | contains("alpha")) then 1
        else 0 end;
      def pnumof: ( restof | [ scan("[0-9]+") ] | map(tonumber)
                    | if length > 0 then .[-1] else 0 end );
      def pick: [ $sufs[] as $s | .assets[]? | select(.name | endswith($s + ".tar.gz")) ];
      [ .[]
        | select((pick | length) > 0)
        | { tag: .tag_name, pre: .prerelease, tier: tierof, pnum: pnumof,
            ver: ( .tag_name | sub("^v";"") | split("-")[0] ) }
      ]
      | sort_by([ (.ver | split(".") | map(tonumber? // 0)), .tier, .pnum ])
      | reverse
      | .[]
      | "\(.tag)\t\(if .pre then "测试版" else "正式版" end)"
    ' 2>/dev/null
}
download_singbox(){
    local want_tag="${1:-${SINGBOX_WANT_VERSION:-}}"
    local api json tag url tmp found rel
    if [ -n "$want_tag" ]; then
        rel="$(fetch_singbox_version "$want_tag")"
        [ -n "$rel" ] || { warn "版本号格式不正确：$want_tag"; return 1; }
        tag="$(printf '%s' "$rel" | cut -f1)"
        url="$(printf '%s' "$rel" | cut -f2)"
    else
        rel="$(fetch_singbox_release)"
        if [ -n "$rel" ] && [ "$rel" != $'\t' ]; then
            tag="$(printf '%s' "$rel" | cut -f1)"
            url="$(printf '%s' "$rel" | cut -f2)"
        fi
    fi
    if [ -z "${url:-}" ] && [ -n "$DEFAULT_NEWEST_VERSION" ]; then
        warn "无法从 release 列表择优，改用内置已知最新版 v${DEFAULT_NEWEST_VERSION}"
        rel="$(fetch_singbox_version "$DEFAULT_NEWEST_VERSION")"
        if [ -n "$rel" ]; then
            tag="$(printf '%s' "$rel" | cut -f1)"
            url="$(printf '%s' "$rel" | cut -f2)"
        fi
    fi
    if [ -z "${url:-}" ]; then
        warn "仍在尝试 GitHub 官方 latest（仅正式版）"
        api="https://api.github.com/repos/SagerNet/sing-box/releases/latest"
        json="$(curl -fsSL --max-time 30 "$api")" || { warn "无法访问 GitHub API"; return 1; }
        tag="$(jq -r '.tag_name // empty' <<<"$json")"
        [ -n "$tag" ] || { warn "无法获取 sing-box 版本"; return 1; }
        url="$(jq -r --argjson sufs "$(_asset_suffixes_json)" '[ $sufs[] as $s | .assets[]? | select(.name | endswith($s + ".tar.gz")) | .browser_download_url ][0] // empty' <<<"$json")"
    fi
    [ -n "$url" ] || { warn "找不到 linux-${ARCH} 的发行包（该版本可能没有此架构）"; return 1; }

    local -a _cands=("$url")
    local _alt
    for _alt in $(_alt_variant_urls "$url"); do
        [ -n "$_alt" ] || continue
        [ "$_alt" = "$url" ] && continue
        _cands+=("$_alt")
    done

    local _u _tried=0 _last=""
    local _lc="glibc"; is_musl && _lc="musl"
    for _u in "${_cands[@]}"; do
        [ -n "$_u" ] || continue
        _tried=$((_tried + 1))
        tmp="$(mktemp -d)" || { warn "无法创建临时目录"; return 1; }
        if ! curl -fL --retry 3 "$_u" -o "$tmp/sing-box.tar.gz" 2>/dev/null; then
            rm -rf "$tmp"; _last="下载失败：$(basename "$_u")"; continue
        fi
        if ! tar -xzf "$tmp/sing-box.tar.gz" -C "$tmp" 2>/dev/null; then
            rm -rf "$tmp"; _last="解压失败（文件可能不完整）"; continue
        fi
        found="$(find "$tmp" -type f -name sing-box | head -n1)"
        if [ -z "$found" ]; then
            rm -rf "$tmp"; _last="压缩包里没有找到 sing-box 可执行文件"; continue
        fi
        if ! install -m 0755 "$found" "${BIN}.new" 2>/dev/null; then
            rm -rf "$tmp"; rm -f "${BIN}.new"; _last="写入 ${BIN} 失败"; continue
        fi
        rm -rf "$tmp"
        if ! "${BIN}.new" version >/dev/null 2>&1; then
            rm -f "${BIN}.new"
            _last="该构建在本机无法执行（本机 libc：${_lc}）"
            info "该变体在本机跑不起来，换下一个变体重试 ..."
            continue
        fi
        if ! mv -f "${BIN}.new" "$BIN" 2>/dev/null; then
            rm -f "${BIN}.new"; _last="替换 ${BIN} 失败"; continue
        fi
        printf '%s\n' "$tag" > "$VERSION_FILE"
        rm -f "$BASE/.sbver.cache" 2>/dev/null || true
        SB_VERSION_CACHE=""
        info "已安装 sing-box ${tag}"
        return 0
    done
    rm -f "${BIN}.new" 2>/dev/null || true
    warn "${_last:-下载安装失败}（已尝试 ${_tried} 个构建变体）"
    return 1
}
write_self_menu(){
    local src="${1:-${BASH_SOURCE[0]:-$0}}"
    local tmp="${MENU}.tmp.$$"
    local ok=0

    if [ -r "$src" ]; then
        { tr -d '\r' < "$src" > "$tmp"; } 2>/dev/null && [ -s "$tmp" ] && ok=1
    fi

    if [ "$ok" != 1 ] && [ -n "${UPDATE_URL:-}" ] && command -v curl >/dev/null 2>&1; then
        info "脚本源不可重读（$src，多为 bash <(curl) 的管道已读空），改从更新源重新获取"
        if curl -fsSL --max-time 30 "$UPDATE_URL" 2>/dev/null | tr -d '\r' > "$tmp" && [ -s "$tmp" ]; then
            local rv; rv="$(script_version_of "$tmp" 2>/dev/null)"
            if [ -n "$rv" ] && _version_newer "$VERSION" "$rv"; then
                warn "更新源版本（$rv）低于当前（$VERSION），已放弃；请改用：sb update <脚本URL>"
                rm -f "$tmp"; return 1
            fi
            ok=1
        fi
    fi

    if [ "$ok" != 1 ]; then
        rm -f "$tmp"
        warn "写入管理器失败：无法获取脚本内容（源：$src）"
        return 1
    fi
    chmod 0755 "$tmp"
    mv -f "$tmp" "$MENU"
    chmod 0755 "$MENU"
    local old
    for old in "$BASE"/sing-box-nat-v*.sh; do
        [ -e "$old" ] || continue
        [ "$old" = "$MENU" ] && continue
        rm -f "$old" 2>/dev/null || true
    done
    for old in "$BASE"/sb "$BASE"/sb-menu.sh; do
        [ -e "$old" ] || continue
        [ -L "$old" ] || rm -f "$old" 2>/dev/null || true
    done
    install_sb_cmd
}

install_sb_cmd(){
    local bashbin="${BASH:-/bin/bash}"
    [ -x "$bashbin" ] || bashbin="/bin/bash"
    [ -x "$bashbin" ] || bashbin="/usr/bin/bash"
    [ -x "$bashbin" ] || bashbin="bash"
    cat <<EOF | tr -d '\r' > "$SB"
#!$bashbin
# sing-box NAT 管理命令入口（由安装脚本生成，请勿手改）。
# 直接指定 bash 解释器，不依赖 menu.sh 的 shebang 或内部换壳逻辑。
# menu.sh 缺失（例如已被卸载 / 半卸载）时给出明确提示，而不是让 bash 抛出
# "/usr/bin/bash: …/menu.sh: No such file or directory" 这种看不懂的报错。
_menu="$MENU"
if [ ! -r "\$_menu" ]; then
    echo "sing-box NAT 管理器未安装或已被卸载（找不到 \$_menu）。" >&2
    echo "如需重新安装，请重新运行安装脚本。" >&2
    exit 1
fi
exec "$bashbin" "\$_menu" "\$@"
EOF
    chmod 0755 "$SB" 2>/dev/null || true
    ln -sf "$SB" "$BASE/sb" 2>/dev/null || true
}

sb_update(){
    need_root
    local self="${BASH_SOURCE[0]:-$0}"
    local url="${1:-}"
    mkdir -p "$BASE"

    if [ -n "$url" ]; then
        case "$url" in
            http://*|https://*) : ;;
            *) warn "只支持 http/https 链接：$url"; return 1 ;;
        esac
        if ! command -v curl >/dev/null 2>&1; then
            warn "缺少 curl，无法下载"; return 1
        fi
        local tmp="${MENU}.dl.$$"
        info "正在下载：$url"
        if ! curl -fsSL --max-time 30 "$url" -o "$tmp"; then
            warn "下载失败（网络问题或链接失效）"; rm -f "$tmp"; return 1
        fi
        if [ ! -s "$tmp" ]; then
            warn "下载内容为空"; rm -f "$tmp"; return 1
        fi
        if ! bash -n "$tmp" 2>/dev/null; then
            warn "下载的脚本语法检查未通过，已放弃覆盖（原 menu.sh 未变）"
            rm -f "$tmp"; return 1
        fi
        self="$tmp"
        info "下载完成，语法检查通过"
    fi

    if [ ! -r "$self" ]; then
        warn "无法读取源脚本：$self"
        warn "请改用：sb update <脚本URL>"
        return 1
    fi

    if [ -z "$url" ]; then
        local _rs _rt
        _rs="$(readlink -f "$self" 2>/dev/null || echo "$self")"
        _rt="$(readlink -f "$MENU" 2>/dev/null || echo "$MENU")"
        if [ "$_rs" = "$_rt" ]; then
            echo
            warn "检测到源脚本就是已安装的 menu.sh —— 覆盖自己没有升级效果"
            info "要真正升级，请先把新版脚本放到本机，再执行："
            echo "    ${BOLD}bash /路径/新版脚本 update${RESET}"
            echo "  或从网络更新："
            echo "    ${BOLD}sb update <脚本URL>${RESET}"
            pause
            return 1
        fi
    fi

    local oldver=""
    if [ -r "$MENU" ]; then
        oldver="$(grep -m1 '^VERSION=' "$MENU" 2>/dev/null | sed 's/^VERSION=//; s/^"//; s/"$//')"
    fi

    local _dl=""
    [ -n "$url" ] && _dl="$self"
    write_self_menu "$self" || { warn "写入失败"; [ -n "$_dl" ] && rm -f "$_dl"; return 1; }
    [ -n "$_dl" ] && rm -f "$_dl" 2>/dev/null || true

    local newver=""
    newver="$(grep -m1 '^VERSION=' "$MENU" 2>/dev/null | sed 's/^VERSION=//; s/^"//; s/"$//')"
    echo
    ok "管理命令已更新：${oldver:-未知} → ${newver:-未知}"
    info "menu.sh：$MENU"
    info "下次运行 sb 即生效（本次菜单仍是旧版本，退出重进即可）"
    pause
}

_version_newer(){
    awk -v a="${1#V}" -v b="${2#V}" 'BEGIN{
        na=split(a,x,"."); nb=split(b,y,".");
        n=(na>nb?na:nb);
        for(i=1;i<=n;i++){
            ai=x[i]+0; bi=y[i]+0;
            if(ai>bi) exit 0;
            if(ai<bi) exit 1;
        }
        exit 1;
    }'
}

check_update(){
    need_root
    clear
    panel "检查更新"
    echo "  当前版本  ${BOLD}${VERSION}${RESET}"
    echo "  更新来源  ${DIM}${UPDATE_URL}${RESET}"
    echo
    if ! command -v curl >/dev/null 2>&1; then
        warn "缺少 curl，无法联网检查更新"
        pause; return 1
    fi
    mkdir -p "$BASE" 2>/dev/null || true
    local tmp="${BASE}/.update.$$"
    local rver a
    progress 30 "获取远端版本信息"
    if ! curl -fsSL --max-time 20 "$UPDATE_URL" -o "$tmp" 2>/dev/null; then
        rm -f "$tmp"
        warn "获取失败：网络不通或链接失效"
        info "可稍后重试；或手动执行：sb update ${UPDATE_URL}"
        pause; return 1
    fi
    if [ ! -s "$tmp" ]; then
        rm -f "$tmp"; warn "下载内容为空"; pause; return 1
    fi
    progress 60 "解析远端版本"
    rver="$(script_version_of "$tmp" 2>/dev/null)"
    if [ -z "$rver" ]; then
        rm -f "$tmp"; warn "无法从远端脚本解析出版本号"; pause; return 1
    fi
    progress 80 "对比版本"
    if _version_newer "$rver" "$VERSION"; then
        progress 100 "发现新版本"
        echo
        ok "发现新版本：${VERSION} → ${BOLD}${rver}${RESET}"
        echo "  ${DIM}查看更新说明：${UPDATE_REPO}${RESET}"
        echo
        read -r -p "  是否立即更新？[Y/n] " a || a=""
        case "${a:-Y}" in
          y|Y|yes|YES|"")
            if ! bash -n "$tmp" 2>/dev/null; then
                rm -f "$tmp"
                warn "远端脚本语法检查未通过，已放弃更新（本地未改动）"
                pause; return 1
            fi
            if write_self_menu "$tmp"; then
                ok "已更新到 ${rver}"
                info "退出本菜单后重新运行 sb 即生效"
            else
                warn "写入 menu.sh 失败"
            fi
            ;;
          *) info "已跳过更新" ;;
        esac
    elif [ "$rver" = "$VERSION" ]; then
        progress 100 "已是最新"
        echo
        ok "已是最新版本（${VERSION}）"
    else
        progress 100 "完成"
        echo
        info "本地（${VERSION}）比远端（${rver}）更新，无需更新"
    fi
    rm -f "$tmp"
    pause
}

script_version_of(){
    local f="$1"
    [ -r "$f" ] || { echo ""; return 1; }
    sed -n 's/^VERSION=//p' "$f" 2>/dev/null | head -n1 | tr -d '"' | tr -d "'"
}
main(){
    _self_fix_crlf "${BASH_SOURCE[0]:-$0}"

    case "${1:-}" in
        update|upgrade)
            shift
            if [ ! -x "$BIN" ] && [ ! -r "$MENU" ]; then
                echo
                warn "检测到尚未安装 sing-box，update 只更新管理器、不装内核"
                info "建议直接运行安装：bash $(basename "${BASH_SOURCE[0]:-$0}")"
                info "确实只想更新管理器？5 秒后继续，按 Ctrl-C 取消。"
                sleep 5
            fi
            sb_update "${1:-}"
            exit $?
            ;;
        check|check-update)
            need_root; detect_os; detect_arch; load_settings; init_files; attach_tty
            check_update
            exit $?
            ;;
        version|-v|--version)
            echo "Sing-box NAT ${VERSION}"
            echo "menu.sh：${MENU}$([ -r "$MENU" ] && echo "（$(script_version_of "$MENU")）" || echo "（未安装）")"
            exit 0
            ;;
        help|-h|--help)
            cat <<EOF
Sing-box NAT ${VERSION} —— 管理命令

  sb                 进入管理菜单
  sb update [URL]    用当前脚本更新已安装的 menu.sh；
                     给 URL 则先从该地址下载（下载后做语法检查再覆盖）
  sb check           联网检查管理器是否有新版本，可一键更新
  sb version         查看当前版本（含 menu.sh 版本）
  sb help            显示本帮助
EOF
            exit 0
            ;;
    esac

    if [ "${1:-}" = "__menu" ]; then
        need_root; detect_os; detect_arch; load_settings; get_ip; detect_network; init_files; attach_tty
        strip_http_version
        if [ ! -x "$SB" ] || ! head -n 2 "$SB" 2>/dev/null | grep -q '由安装脚本生成'; then
            install_sb_cmd >/dev/null 2>&1 || true
        fi
        menu "$@"; exit $?
    fi

    case "$(basename "$0")" in
        menu.sh|sb|sb-menu.sh|sing-box-nat.sh|sing-box-nat-v*.sh)
            SB_RUN_MENU=1
            ;;
    esac
    if [ "${SB_RUN_MENU:-0}" = 1 ]; then
        need_root; detect_os; detect_arch; load_settings; get_ip; detect_network; init_files; attach_tty
        strip_http_version
        if [ ! -x "$SB" ] || ! head -n 2 "$SB" 2>/dev/null | grep -q '由安装脚本生成'; then
            install_sb_cmd >/dev/null 2>&1 || true
        fi
        menu "$@"; exit $?
    fi

    if [ ! -x "$BIN" ]; then
        attach_tty
        initial_install
        [ -x "$MENU" ] && exec "${BASH:-/bin/bash}" "$MENU"
        exit 0
    fi
    need_root; detect_os; detect_arch; load_settings; get_ip; detect_network; init_files; attach_tty
    write_self_menu
    install_sb_cmd
    chmod 0755 "$MENU" 2>/dev/null || true
    menu "$@"
}
main "$@"
