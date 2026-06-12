#!/system/bin/sh
#===========================================================================
# UpdateAPP.sh - 远程Shell执行 + 依赖部署 (Android busybox)
# 用法: 将本脚本 + bin/busybox 放在同一目录, sh 本脚本即可
#
# 远程脚本要求: 使用 $ROOT / $PARENT 获取目录, 不要用 $0 / dirname
#   $ROOT   = 本脚本所在目录 (./bin/busybox 在这里)
#   $PARENT = 上级目录 (bin/ 工具 + script/ 脚本目录 在这里)
#   正确: "$PARENT/bin/xxx"  "$PARENT/script/xxx"
#   错误: dirname "$0" / readlink / realpath (pipe模式下 $0 不可靠)
#===========================================================================

# ═══════════════════════════════════════════════
# 锁定脚本目录
# ═══════════════════════════════════════════════
_SELF="$0"
if [ -n "$_SELF" ] && [ "$_SELF" != "sh" ] && [ "$_SELF" != "/system/bin/sh" ]; then
    case "$_SELF" in
        /*) _D="$(dirname "$_SELF")" ;;
        *)  _D="$(cd "$(dirname "$_SELF")" 2>/dev/null && pwd)" ;;
    esac
    [ -n "$_D" ] && [ "$_D" != "/" ] && [ -d "$_D" ] && cd "$_D" 2>/dev/null
fi
cd "$(pwd)" 2>/dev/null

if [ ! -f "./bin/busybox" ]; then
    echo "[错误] 找不到 ./bin/busybox, 当前: $(pwd)"
    exit 1
fi

ROOT="$(pwd)"
export ROOT
PARENT="$(dirname "$ROOT")"
export PARENT
_home() { cd "$ROOT" 2>/dev/null; }

# ═══════════════════════════════════════════════
# 配置
# ═══════════════════════════════════════════════
REMOTE_URL="https://mineacex.github.io/Shell-Https/"
ZIP_URL="https://gh.catmak.name/https://raw.githubusercontent.com/MineACEx/Shell-Https/main/main.zip"
MAX_RETRIES=3
TIMEOUT_NO_DATA=10

BUSYBOX="./bin/busybox"
BIN_DIR="./bin"
LOG_DIR="$ROOT/logs"

# ═══════════════════════════════════════════════
# 日志
# ═══════════════════════════════════════════════
_home
mkdir -p "$LOG_DIR" 2>/dev/null
LOG_FILE="$LOG_DIR/run_$(date +%Y%m%d_%H%M%S).log"

_log() {
    printf "%s\n" "$1"
    printf "%s %s\n" "$(date +%H:%M:%S)" "$1" >> "$LOG_FILE"
}
_die() {
    _log "========================================"
    _log "[失败] $1"
    _log "  日志: $LOG_FILE"
    _log "========================================"
    exit 1
}

# ═══════════════════════════════════════════════
# 进度条 (20格, 红→橙→黄→绿)
# ═══════════════════════════════════════════════
_bar() {
    local f=$1 p=$2 c=$3 s=$4 i=0 color="" sz="" sp=""
    if   [ "$c" -ge 1048576 ] 2>/dev/null; then sz="$($BUSYBOX awk "BEGIN{printf \"%.1fM\",$c/1048576}")"
    elif [ "$c" -ge 1024    ] 2>/dev/null; then sz="$($BUSYBOX awk "BEGIN{printf \"%.1fK\",$c/1024}")"
    else sz="${c}B"; fi
    if   [ "$s" -ge 1048576 ] 2>/dev/null; then sp="$($BUSYBOX awk "BEGIN{printf \"%.1fM/s\",$s/1048576}")"
    elif [ "$s" -ge 1024    ] 2>/dev/null; then sp="$($BUSYBOX awk "BEGIN{printf \"%.1fK/s\",$s/1024}")"
    elif [ "$s" -gt 0       ] 2>/dev/null; then sp="${s}B/s"; fi
    printf "\r  ["
    while [ $i -lt $f ]; do
        [ $i -lt 5  ] && color="196"
        [ $i -ge 5  ] && [ $i -lt 10 ] && color="208"
        [ $i -ge 10 ] && [ $i -lt 15 ] && color="226"
        [ $i -ge 15 ] && color="46"
        printf "\033[38;5;%sm#\033[0m" "$color"
        i=$((i+1))
    done
    while [ $i -lt 20 ]; do printf "\033[90m-\033[0m"; i=$((i+1)); done
    printf "] \033[1m%3d%%\033[0m  %s" "$p" "$sz"
    [ -n "$sp" ] && printf "  \033[36m%s\033[0m" "$sp"
    printf "\033[K"
}

# ═══════════════════════════════════════════════
# 下载 (带进度 + 超时)
# ═══════════════════════════════════════════════
_dl() {
    local url="$1" out="$2" label="$3" pid ps pt spd cs ct iv ss=0 st pct fl fs
    _log "[下载] $label"
    rm -f "$out" 2>/dev/null
    $BUSYBOX wget -q -O "$out" "$url" &
    pid=$!; ps=0; pt=$(date +%s)
    printf "\r  等待响应..."; sleep 1
    while kill -0 $pid 2>/dev/null; do
        cs=0
        [ -f "$out" ] && cs=$($BUSYBOX stat -c%s "$out" 2>/dev/null)
        [ -z "$cs" ] && cs=0
        ct=$(date +%s); iv=$((ct-pt)); spd=0
        [ $iv -gt 0 ] && { spd=$(((cs-ps)/iv)); [ $spd -lt 0 ] 2>/dev/null && spd=0; }
        ps=$cs; pt=$ct
        if [ $cs -eq 0 ]; then
            ss=$((ss+1))
            if [ $ss -ge $TIMEOUT_NO_DATA ]; then
                printf "\r\033[K"
                _log "[超时] ${TIMEOUT_NO_DATA}s无数据, 终止 $label"
                kill $pid 2>/dev/null; wait $pid 2>/dev/null
                rm -f "$out" 2>/dev/null; return 1
            fi
        else ss=0; fi
        st=$((cs/262144)); pct=$((st*2)); [ $pct -gt 99 ] 2>/dev/null && pct=99
        fl=$((pct*20/100)); [ $fl -gt 19 ] 2>/dev/null && fl=19
        _bar $fl $pct $cs $spd; sleep 1
    done
    wait $pid 2>/dev/null; local rc=$?
    fs=0; [ -f "$out" ] && fs=$($BUSYBOX stat -c%s "$out" 2>/dev/null)
    [ -z "$fs" ] && fs=0
    _bar 20 100 $fs 0; printf "\n"
    [ $rc -ne 0 ] || [ $fs -eq 0 ] 2>/dev/null && { _log "[错误] $label 下载失败"; rm -f "$out" 2>/dev/null; return 1; }
    return 0
}

_dl_retry() {
    local t=0
    while [ $t -lt $MAX_RETRIES ]; do
        t=$((t+1)); _dl "$1" "$2" "$3 (${t}/${MAX_RETRIES})"
        [ $? -eq 0 ] && return 0
        [ $t -lt $MAX_RETRIES ] && { _log "[重试] 等2秒..."; sleep 2; }
    done
    return 1
}

# ═══════════════════════════════════════════════
# 阶段1: 依赖下载 (main.zip → ./bin/)
# ═══════════════════════════════════════════════
_home
_log "============================================"
_log "  UpdateAPP - 远程Shell + 依赖部署"
_log "  目录: $ROOT"
_log "  日志: $LOG_FILE"
_log "============================================"

if [ -f "./bin/vim" ] && [ -f "./bin/gzip" ]; then
    _log "[跳过] 依赖已存在"
else
    _log "[阶段1] 下载依赖..."
    chmod 777 "$BUSYBOX" 2>/dev/null
    $BUSYBOX echo ok >/dev/null 2>&1 || _die "busybox无法执行, 请移到/sdcard"

    mkdir -p "$BIN_DIR" 2>/dev/null
    ZT="main.zip"
    _dl_retry "$ZIP_URL" "$ZT" "依赖包" || _die "依赖下载失败"

    _home; _log "[校验] 检查ZIP..."
    MG=$($BUSYBOX dd if="$ZT" bs=1 count=2 2>/dev/null | $BUSYBOX xxd -p 2>/dev/null | $BUSYBOX tr -d '\n ')
    [ "$MG" != "504b" ] && { rm -f "$ZT"; _die "不是ZIP格式"; }

    _log "[解压] → $BIN_DIR"
    $BUSYBOX unzip -o "$ZT" -d "$BIN_DIR" >/dev/null 2>&1 || { rm -f "$ZT"; _die "解压失败"; }
    chmod -R 777 "$BIN_DIR" 2>/dev/null
    rm -f "$ZT"
    _log "[阶段1] 完成"
fi

# ═══════════════════════════════════════════════
# 阶段2: 下载远程脚本到临时文件, 再执行 (保留 stdin 给 read)
# ═══════════════════════════════════════════════
# 不能用 wget | sh 管道, 因为管道会吃掉 stdin,
# 远程脚本里的 read 命令就无法从终端读取用户输入了
# 解决方案: 先下载到临时文件, 再 sh 执行, stdin 正常连接终端
_home
_log ""
_log "[阶段2] 下载远程脚本..."
rm -f "./.bash" 2>/dev/null
_dl_retry "$REMOTE_URL" "./.bash" "远程脚本" || _die "远程脚本下载失败"

_home
_log "[校验] 检查远程脚本..."
[ -s "./.bash" ] || _die "远程脚本为空"
chmod 777 "./.bash" 2>/dev/null

# ═══════════════════════════════════════════════
# 阶段3: 执行远程脚本 (stdin 正常, read 可用)
# ═══════════════════════════════════════════════
_home
_log ""
_log "[阶段3] 执行远程脚本..."
_log "----------------------------------------"
_log "  来源: $REMOTE_URL"
_log "  目录: $ROOT"
_log "  上级: $PARENT"
_log "  可用: \$ROOT  \$ROOT/bin  \$PARENT/bin  \$PARENT/script"
_log "----------------------------------------"
sleep 1
clear
( cd "$ROOT" && sh "./.bash" )
RC=$?

_home
_log "----------------------------------------"
_log "[阶段3] 完毕 (退出码: $RC)"

# ═══════════════════════════════════════════════
# 收尾
# ═══════════════════════════════════════════════
_home
rm -f "./.bash" 2>/dev/null
_log ""
_log "============================================"
_log "[完成] 退出码: $RC"
_log "  目录: $ROOT"
_log "  日志: $LOG_FILE"
_log "============================================"