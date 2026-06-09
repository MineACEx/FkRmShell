#!/system/bin/sh
# ============================================================
#  格机脚本检测工具  v3.0
#  Brick Script Detector for Android 10-16
#  彩色加粗 · 内联Base64自动解码 · 双模式
#  ============================================================

# ===================== 脚本路径自适应 =====================
SCRIPT_DIR="."
_detect_script_dir() {
    _p="$0"
    case "$_p" in */*) _d="${_p%/*}"; [ -d "$_d" ] && SCRIPT_DIR="$_d" ;; esac
    _abs=$(cd "$SCRIPT_DIR" 2>/dev/null && pwd 2>/dev/null)
    [ -n "$_abs" ] && SCRIPT_DIR="$_abs"
}
_detect_script_dir

# ===================== 配置区域 =====================
BIN_DIR="${SCRIPT_DIR}/bin"
TARGET_DIR="${SCRIPT_DIR}/script"
LOGS_DIR="${SCRIPT_DIR}/logs"

MAX_DECODE_DEPTH=20
HUGE_FILE_THRESHOLD=10485760

TMP_DIR="/data/local/tmp/script_detector_$$"
STATS_FILE="${TMP_DIR}/stats.txt"

_TIMESTAMP=$(date +%Y%m%d_%H%M%S 2>/dev/null)
[ -z "$_TIMESTAMP" ] && _TIMESTAMP="unknown"
LOG_FILE="${LOGS_DIR}/detector_${_TIMESTAMP}.log"

# 扫描节奏控制 (秒)
SCAN_INTERVAL=0.2

# 长暂停 (秒)
SCAN_INTERVAL_LONG=0.4

# ===================== 颜色系统 (彩色加粗) =====================
# Bold + 各种颜色
CB='\033[1m'    ; CN='\033[0m'
CK='\033[1;30m' ; CR='\033[1;31m' ; CG='\033[1;32m' ; CY='\033[1;33m'
CL='\033[1;34m' ; CP='\033[1;35m' ; CC='\033[1;36m' ; CW='\033[1;37m'
CD='\033[2m'    ; BG_R='\033[41;1;37m'

# 各语义色彩
c_banner()  { printf '%b' "${CW}"; }
c_info()    { printf '%b' "${CL}"; }
c_ok()      { printf '%b' "${CG}"; }
c_warn()    { printf '%b' "${CY}"; }
c_danger()  { printf '%b' "${CR}"; }
c_crit()    { printf '%b' "${BG_R}"; }
c_sep()     { printf '%b' "${CP}"; }
c_decode()  { printf '%b' "${CC}"; }
c_obfs()    { printf '%b' "${CP}"; }
c_file()    { printf '%b' "${CW}"; }
c_prompt()  { printf '%b' "${CY}"; }
c_dim()     { printf '%b' "${CD}"; }
c_reset()   { printf '%b' "${CN}"; }

_color() { _f="$1"; shift; "$_f"; printf '%s' "$*"; c_reset; }

# ===================== 输出系统 =====================
SLEEP_CMD=""
[ "$(command -v sleep 2>/dev/null)" ] && SLEEP_CMD="sleep"

_log()  { echo "$1" >> "$LOG_FILE"; }
_echo() { echo "$1"; _log "$1"; }
_echon(){ printf '%s' "$1"; _log "$1"; }
_pause(){ [ -n "$SLEEP_CMD" ] && sleep "$SCAN_INTERVAL" 2>/dev/null || true; }
_plong(){ [ -n "$SLEEP_CMD" ] && sleep "$SCAN_INTERVAL_LONG" 2>/dev/null || true; }

_info()   { _echon "$(_color c_info '[信息]') $1"; _echo ""; _pause; }
_ok()     { _echon "$(_color c_ok   '[安全]') $1"; _echo ""; _pause; }
_warn()   { _echon "$(_color c_warn '[可疑]') $1"; _echo ""; _pause; }
_danger() { _echon "$(_color c_crit '[危险]') $1"; _echo ""; _pause; }

_critical_box() {
    _echo ""
    _echon "$(_color c_crit ' ================================= ')"
    _echo ""
    _echon "$(_color c_crit '  !!! 严重警告 !!!  ')"
    _echo ""
    _echon "$(_color c_danger "  $1")"
    _echo ""
    _echon "$(_color c_crit ' ================================= ')"
    _echo ""
    _echo ""
}

_sep() {
    _echon "$(_color c_sep '──────────────────────────────────')"
    _echo ""
}

# ===================== 工具函数 =====================
safe_read_bytes() { dd if="$1" bs=1 count="$2" 2>/dev/null; }
get_file_size()   { wc -c < "$1" 2>/dev/null | tr -d ' '; }

check_cmd() {
    command -v "$1" >/dev/null 2>&1 && return 0
    [ -x "${BIN_DIR}/$1" ] && return 0
    return 1
}

get_cmd_path() {
    _p=$(command -v "$1" 2>/dev/null)
    [ -n "$_p" ] && { echo "$_p"; return 0; }
    [ -x "${BIN_DIR}/$1" ] && { echo "${BIN_DIR}/$1"; return 0; }
    return 1
}

read_magic() {
    _raw=$(safe_read_bytes "$1" "$2")
    OD_CMD=$(get_cmd_path "od")
    if [ -n "$OD_CMD" ]; then
        echo "$_raw" | "$OD_CMD" -A n -t x1 2>/dev/null | tr -d ' \n' && return 0
    fi
    HEXDUMP_CMD=$(get_cmd_path "hexdump")
    if [ -n "$HEXDUMP_CMD" ]; then
        echo "$_raw" | "$HEXDUMP_CMD" -v -e '/1 "%02x"' 2>/dev/null && return 0
    fi
    XXD_CMD=$(get_cmd_path "xxd")
    if [ -n "$XXD_CMD" ]; then
        echo "$_raw" | "$XXD_CMD" -p 2>/dev/null | tr -d '\n' && return 0
    fi
    printf '%s' "$_raw" | od -A n -t x1 2>/dev/null | tr -d ' \n' && return 0
    return 1
}

# ===================== 统计计数器 =====================
init_stats() {
    for _k in total clean suspicious dangerous skipped decoded inline_b64; do
        echo "0" > "${STATS_FILE}.${_k}"
    done
}
inc_stat() {
    _val=$(cat "${STATS_FILE}.$1" 2>/dev/null); [ -z "$_val" ] && _val=0
    echo $((_val + 1)) > "${STATS_FILE}.$1"
}
get_stat() {
    cat "${STATS_FILE}.$1" 2>/dev/null
}

# ===================== 环境检测 =====================

check_environment() {
    _info "正在检测运行环境..."
    _info "脚本路径: $SCRIPT_DIR"
    _info "工具目录: $BIN_DIR"
    _info "日志目录: $LOGS_DIR"

    if [ "$(id -u 2>/dev/null)" != "0" ]; then
        _warn "当前非 root 用户，请在文件管理器中使用 Root 模式执行"
    else
        _ok "已获取 root 权限"
    fi

    _sdk=$(getprop ro.build.version.sdk 2>/dev/null)
    _release=$(getprop ro.build.version.release 2>/dev/null)
    if [ -n "$_sdk" ]; then
        if [ "$_sdk" -ge 29 ] && [ "$_sdk" -le 36 ]; then
            _ok "Android $_release (SDK $_sdk) - 受支持版本"
        else
            _warn "Android $_release (SDK $_sdk) - 未充分测试"
        fi
    else
        _info "无法获取 Android 版本信息"
    fi

    REQUIRED_TOOLS="grep sed dd wc tr head tail"
    _missing=""
    for _t in $REQUIRED_TOOLS; do
        check_cmd "$_t" || _missing="${_missing} ${_t}"
    done
    [ -n "$_missing" ] && _warn "缺少系统工具:${_missing}"

    OPTIONAL_TOOLS="base64 gunzip gzip od hexdump xxd strings"
    _avail=""; _miss=""
    for _t in $OPTIONAL_TOOLS; do
        check_cmd "$_t" && _avail="${_avail} ${_t}" || _miss="${_miss} ${_t}"
    done
    [ -n "$_avail" ] && _info "可用可选工具:${_avail}"
    if [ -n "$_miss" ]; then
        _warn "缺少可选工具:${_miss}"
        _echo "  $(_color c_warn '缺少 base64 -> 无法检测 Base64 加密')"
        _echo "  $(_color c_warn '缺少 gunzip  -> 无法检测 Gzip 压缩')"
    fi

    mkdir -p "$TMP_DIR" 2>/dev/null
    if [ ! -d "$TMP_DIR" ]; then
        _critical_box "无法创建临时目录: $TMP_DIR"
        exit 1
    fi
    init_stats
    _info "临时目录: $TMP_DIR"
    _echo ""
}

# ===================== 文件类型检测 =====================

is_gzip_file() {
    _m=$(read_magic "$1" 2); [ "$_m" = "1f8b" ]
}

is_base64_content() {
    _sample=$(safe_read_bytes "$1" 4096); [ -z "$_sample" ] && return 1
    _inv=$(printf '%s' "$_sample" | tr -d 'A-Za-z0-9+/=\n\r\t ')
    _total=$(printf '%s' "$_sample" | wc -c | tr -d ' ')
    _inv_count=$(printf '%s' "$_inv" | wc -c | tr -d ' ')
    [ "$_total" -gt 0 ] && [ "$_inv_count" -lt $((_total / 8)) ] && return 0
    return 1
}

is_binary_file() {
    _sample=$(safe_read_bytes "$1" 1024); [ -z "$_sample" ] && return 1
    _orig=$(printf '%s' "$_sample" | wc -c | tr -d ' ')
    _clean=$(printf '%s' "$_sample" | tr -d '\000' | wc -c | tr -d ' ')
    [ "$_clean" -lt "$_orig" ] && return 0
    return 1
}

# ===================== 解密/解码 =====================

try_gunzip() {
    _out="$2"
    GZ_CMD=$(get_cmd_path "gunzip")
    if [ -n "$GZ_CMD" ]; then
        "$GZ_CMD" -c "$1" > "$_out" 2>/dev/null
    else
        GZ_CMD=$(get_cmd_path "gzip")
        [ -z "$GZ_CMD" ] && return 1
        "$GZ_CMD" -d -c "$1" > "$_out" 2>/dev/null
    fi
    [ -s "$_out" ]
}

try_base64_decode() {
    B64_CMD=$(get_cmd_path "base64"); [ -z "$B64_CMD" ] && return 1
    tr -d '\n\r\t ' < "$1" | "$B64_CMD" -d > "$2" 2>/dev/null
    [ -s "$2" ]
}

# 供内联检测使用：直接解码一个 base64 字符串
decode_base64_string() {
    B64_CMD=$(get_cmd_path "base64"); [ -z "$B64_CMD" ] && return 1
    printf '%s' "$1" | "$B64_CMD" -d > "$2" 2>/dev/null
    [ -s "$2" ]
}

recursive_decode() {
    _src="$1"; _depth="$2"; _wkdir="$3"
    [ "$_depth" -ge "$MAX_DECODE_DEPTH" ] && { echo "$_src"; return 0; }
    _cur="$_src"

    # Gzip 解压
    if is_gzip_file "$_cur"; then
        _nd=$((_depth + 1)); _out="${_wkdir}/decode_${_nd}_gzip"
        if try_gunzip "$_cur" "$_out"; then
            _echo "  $(_color c_decode '[-解压-]') $(_color c_decode "Gzip (第${_nd}层) 已解压")"
            inc_stat "decoded"
            # 解压后立即检测解压产物中是否内嵌了 base64 编码
            check_inline_base64 "$_out" "$_wkdir" 2>/dev/null
            _pause; recursive_decode "$_out" "$_nd" "$_wkdir"; return $?
        fi
    fi

    # Base64 全文解码
    if is_base64_content "$_cur"; then
        _nd=$((_depth + 1)); _out="${_wkdir}/decode_${_nd}_b64"
        if try_base64_decode "$_cur" "$_out"; then
            if grep -qE '[a-zA-Z]{3,}' "$_out" 2>/dev/null; then
                _echo "  $(_color c_decode '[-解码-]') $(_color c_decode "Base64 (第${_nd}层) 已解码")"
                inc_stat "decoded"
                # 检查解码产物中是否还内嵌 base64
                check_inline_base64 "$_out" "$_wkdir" 2>/dev/null
                _pause; recursive_decode "$_out" "$_nd" "$_wkdir"; return $?
            fi
        fi
    fi

    echo "$_cur"; return 0
}

# ===================== 内联 Base64 检测（核心增强） =====================
# 检测内联/嵌入的 base64 字符串，自动解码并分析

dangerous_in_decoded() {
    _decoded_file="$1"
    _has=0
    grep -qE 'rm[[:space:]]+-[rRfF]+[[:space:]]+/(data|sdcard|system|vendor|product|boot|persist|metadata|cache|firmware|modem|nv)([[:space:]]|/)' "$_decoded_file" 2>/dev/null && _has=1
    grep -qE 'rm[[:space:]]+-[rRfF]+[[:space:]]+/([[:space:]]|$)' "$_decoded_file" 2>/dev/null && _has=1
    grep -qE 'dd[[:space:]]+if=.*of=/dev/block/' "$_decoded_file" 2>/dev/null && _has=1
    grep -qE '(mkfs|mke2fs|make_ext4fs|make_f2fs)' "$_decoded_file" 2>/dev/null && _has=1
    grep -qE 'fastboot[[:space:]]+(erase|format|-w)' "$_decoded_file" 2>/dev/null && _has=1
    grep -qE '(cat|cp|tee)[[:space:]].*/dev/block/' "$_decoded_file" 2>/dev/null && _has=1
    return "$_has"
}

# 给定一个 base64 字符串，解码并检测是否危险
try_decode_and_check() {
    _b64_str="$1"; _label="$2"; _result_file="$3"
    OUT="${_wkdir_global}/b64_check_$$_$(echo "$_label" | tr '/' '_')"
    B64_CMD=$(get_cmd_path "base64")
    [ -z "$B64_CMD" ] && return 1
    decode_base64_string "$_b64_str" "$OUT" || return 1
    [ ! -s "$OUT" ] && return 1
    _preview=$(head -3 "$OUT" 2>/dev/null)
    _echo "  $(_color c_decode '  [-]') $(_color c_decode "解码结果:") $(_color c_dim "$_preview")"
    if dangerous_in_decoded "$OUT"; then
        _echon "  $(_color c_crit ' [!] 严重:') $(_color c_danger "解码后包含危险命令!!! ($_label)")"
        _echo ""
        echo "SEV:2|内联 Base64 解码后包含危险命令 ($_label)" >> "$_result_file"
        grep -nE 'rm |dd |mkfs|fastboot|/dev/block' "$OUT" 2>/dev/null | head -5 | while IFS= read -r _dl; do
            _echo "    $(_color c_dim '->') $(_color c_danger "$_dl")"
            echo "LINE:${_dl}" >> "$_result_file"
        done
        return 2
    else
        _echo "  $(_color c_warn '  [!]') $(_color c_warn "解码后内容高度可疑 ($_label)")"
        grep -q 'SEV:2|' "$_result_file" 2>/dev/null || echo "SEV:1|Base64 解码内容可疑 ($_label)" >> "$_result_file"
        return 1
    fi
}

check_inline_base64() {
    _file="$1"
    _wkdir="$2"
    _wkdir_global="$_wkdir"
    _result_file="${TMP_DIR}/danger_$(basename "$_file" | tr '/' '_')"
    _found_any=0

    B64_CMD=$(get_cmd_path "base64")
    [ -z "$B64_CMD" ] && return 1  # 没有 base64 工具，跳过

    # ===== 类型A: echo/printf | base64 -d 管道模式 =====
    grep -nE '(echo|printf)[[:space:]]+("[^"]{20,}"|'"'"'[^'"'"']{20,}'"'"').*\|.*base64.*-d' "$_file" 2>/dev/null | \
    while IFS= read -r _match_line; do
        _linenum=$(echo "$_match_line" | cut -d: -f1)
        _line_content=$(echo "$_match_line" | cut -d: -f2-)
        _b64_str=$(echo "$_line_content" | grep -oE '"[A-Za-z0-9+/=]{20,}"' | tr -d '"' | head -1)
        [ -z "$_b64_str" ] && _b64_str=$(echo "$_line_content" | grep -oE "'[A-Za-z0-9+/=]{20,}'" | tr -d "'" | head -1)

        if [ -n "$_b64_str" ]; then
            _echo "  $(_color c_decode '[-内联B64-]') $(_color c_decode "第${_linenum}行: 管道 base64 -d 模式，自动解码...")"
            inc_stat "inline_b64"
            try_decode_and_check "$_b64_str" "管道-第${_linenum}行" "$_result_file"
            _ret=$?
            [ "$_ret" -eq 2 ] && echo "DANGER" > "${_wkdir}/inline_b64_decoded.danger"
            _found_any=1; _pause
        fi
    done

    # ===== 类型B: 文件内嵌的独立长 base64 字符串（Gzip解压产物中常见） =====
    # 查找一行中 ≥60 字符的纯 base64 字符串（不在 echo/printf 管道中）
    grep -nE '^[[:space:]]*[A-Za-z0-9+/=]{60,}[[:space:]]*$' "$_file" 2>/dev/null | \
    while IFS= read -r _match_line; do
        _linenum=$(echo "$_match_line" | cut -d: -f1)
        _b64_str=$(echo "$_match_line" | cut -d: -f2- | tr -d '[:space:]')

        # 跳过已经在管道模式中处理过的（有 echo/printf 前缀的行）
        grep -qE "(echo|printf|base64)" "$_file" -A 0 2>/dev/null && {
            # 仅跳过明显的管道行
            sed -n "${_linenum}p" "$_file" 2>/dev/null | grep -qE '(echo|printf|base64)' && continue
        } || true

        [ ${#_b64_str} -lt 60 ] && continue
        # 基本 base64 纯度检查
        _inv=$(printf '%s' "$_b64_str" | tr -d 'A-Za-z0-9+/=')
        [ -n "$_inv" ] && continue

        _echo "  $(_color c_decode '[-嵌入B64-]') $(_color c_decode "第${_linenum}行: 发现独立 Base64 编码块(${#_b64_str}字符)，尝试解码...")"
        inc_stat "inline_b64"
        try_decode_and_check "$_b64_str" "独立块-第${_linenum}行" "$_result_file"
        _ret=$?
        [ "$_ret" -eq 2 ] && echo "DANGER" > "${_wkdir}/inline_b64_decoded.danger"
        _found_any=1; _pause
    done

    [ "$_found_any" -eq 1 ] && return 0
    return 1
}

# ===================== 混淆检测 =====================

check_obfuscation() {
    _file="$1"; _found=0

    grep -qE 'eval[[:space:]]+\$' "$_file" 2>/dev/null && \
        { _echo "  $(_color c_obfs '[混淆]') $(_color c_obfs 'eval 动态执行')"; _found=1; }
    grep -qE '\$\(.*base64[[:space:]].*-d' "$_file" 2>/dev/null && \
        { _echo "  $(_color c_obfs '[混淆]') $(_color c_obfs '运行时 Base64 解码执行')"; _found=1; }
    grep -qE 'echo[[:space:]]+".*"[[:space:]]*\|[[:space:]]*base64[[:space:]].*-d' "$_file" 2>/dev/null && \
        { _echo "  $(_color c_obfs '[混淆]') $(_color c_obfs 'echo 管道 base64 解码 (内联隐藏)')"; _found=1; }
    grep -qE '\$\(.*openssl.*-d' "$_file" 2>/dev/null && \
        { _echo "  $(_color c_obfs '[混淆]') $(_color c_obfs '运行时 OpenSSL 解密执行')"; _found=1; }
    grep -qE 'printf[[:space:]].*\\x[0-9a-fA-F][0-9a-fA-F]' "$_file" 2>/dev/null && \
        { _echo "  $(_color c_obfs '[混淆]') $(_color c_obfs 'printf 十六进制转义')"; _found=1; }
    grep -qE '\$\(.*(gunzip|gzip).*-(c|d)' "$_file" 2>/dev/null && \
        { _echo "  $(_color c_obfs '[混淆]') $(_color c_obfs '运行时 Gzip 解压执行')"; _found=1; }
    grep -qE '\$[a-zA-Z_][a-zA-Z0-9_]*\$[a-zA-Z_][a-zA-Z0-9_]' "$_file" 2>/dev/null && \
        { _echo "  $(_color c_obfs '[混淆]') $(_color c_obfs '变量拼接命令执行')"; _found=1; }
    grep -qE '\$\(.*xxd.*-r' "$_file" 2>/dev/null && \
        { _echo "  $(_color c_obfs '[混淆]') $(_color c_obfs '运行时 xxd 反向解码')"; _found=1; }

    return "$_found"
}

# ===================== 危险模式检测 =====================

check_dangerous_patterns() {
    _file="$1"
    _result_file="${TMP_DIR}/danger_$(basename "$_file" | tr '/' '_')"
    : > "$_result_file"
    _max_sev=0

    _check() {
        _regex="$2"; _sev="$3"
        _matches=$(grep -nE "$_regex" "$_file" 2>/dev/null | head -5)
        if [ -n "$_matches" ]; then
            [ "$_sev" -gt "$_max_sev" ] && _max_sev="$_sev"
            echo "SEV:${_sev}|$1" >> "$_result_file"
            echo "$_matches" | while IFS= read -r _ml; do
                echo "LINE:${_ml}" >> "$_result_file"
            done
        fi
    }

    # ---- 严重 (2) ----
    _check "rm -rf 删除关键分区" \
        'rm[[:space:]]+-[rRfF]+[[:space:]]+/(data|sdcard|system|vendor|product|boot|persist|metadata|cache|firmware|modem|nv)([[:space:]]|/)' 2
    _check "rm -rf 删除根目录" \
        'rm[[:space:]]+-[rRfF]+[[:space:]]+/([[:space:]]|$|;|&)' 2
    _check "rm -rf 删除存储空间" \
        'rm[[:space:]]+-[rRfF]+[[:space:]]+/(storage/emulated|mnt/vendor|mnt/sdcard)' 2
    _check "rm -rf 删除 data 关键子目录" \
        'rm[[:space:]]+-[rRfF]+[[:space:]]+/(data/data|data/app|data/system|data/dalvik-cache|data/media|data/dalvik)' 2
    _check "rm -rf 删除 persist" \
        'rm[[:space:]]+-[rRfF]+[[:space:]]+/(persist|mnt/vendor/persist)' 2

    _check "dd 写入块设备 (破坏分区)" \
        'dd[[:space:]]+if=.*[[:space:]]+of=/dev/block/' 2
    _check "dd 零数据覆盖分区" \
        'dd[[:space:]]+if=/dev/zero.*of=/dev/block/' 2
    _check "dd 随机数据覆盖分区" \
        'dd[[:space:]]+if=/dev/(u)?random.*of=/dev/block/' 2
    _check "dd 写入 bootloader" \
        'dd[[:space:]].*of=/dev/block/.*(boot|aboot|recovery|xbl|tz|sbl|rpm|hyp|pmic|modemst|fsg|fsc|dsp|devcfg|devinfo|limits|splash)' 2
    _check "dd 写入 persist/efs/modem" \
        'dd[[:space:]].*of=/dev/block/.*(persist|efs|modem|fsg|fsc|dsp|sec)' 2

    _check "格式化命令" \
        '(mkfs\.|mke2fs|make_ext4fs|make_f2fs|newfs_msdos|mkdosfs|^mkfs[[:space:]])' 2
    _check "fastboot 擦除" \
        'fastboot[[:space:]]+(erase|format|-w|wipe)' 2
    _check "重定向写入块设备" \
        '(cat|cp|tee|>)[[:space:]].*(/dev/block/|of=/dev/block/)' 2
    _check "分区表破坏" \
        '(fdisk.*delete|parted.*rm[[:space:]]|sgdisk.*-d|wipefs|blkdiscard)' 2
    _check "加密锁定设备" \
        'vdc[[:space:]]+cryptfs[[:space:]]+(enablecrypto|changepw|enable_in_place)' 2
    _check "恢复出厂/擦除数据" \
        '(recovery[[:space:]]+--wipe_data|wipe[[:space:]]+data[[:space:]]|pm[[:space:]]+clear)' 2

    # ---- 可疑 (1) ----
    _check "重新挂载分区为可写" \
        'mount[[:space:]].*-o[[:space:]].*remount,rw' 1
    _check "关闭 SELinux" \
        'setenforce[[:space:]]+0' 1
    _check "chmod 777 关键路径" \
        'chmod[[:space:]].*777[[:space:]].*/(system|data|vendor)' 1
    _check "重启到刷机模式" \
        'reboot[[:space:]]+(bootloader|recovery|edl|fastboot|download)' 1
    _check "find -exec rm 批量删除" \
        'find[[:space:]].*-exec[[:space:]]+rm[[:space:]]' 1
    _check "dd 读取块设备 (备份?)" \
        'dd[[:space:]]+if=/dev/block/.*of=.*\.(img|bin|raw)' 1

    echo "$_result_file"
    return "$_max_sev"
}

print_danger_findings() {
    _result_file="$1"; [ ! -f "$_result_file" ] && return

    while IFS= read -r _line; do
        case "$_line" in
            SEV:2\|*)
                _msg=$(echo "$_line" | sed 's/^SEV:2|//')
                _echo "  $(_color c_crit ' [-]') $(_color c_danger "$_msg")"
                ;;
            SEV:1\|*)
                _msg=$(echo "$_line" | sed 's/^SEV:1|//')
                _echo "  $(_color c_warn ' [!]') $(_color c_warn "$_msg")"
                ;;
            LINE:*)
                _ml=$(echo "$_line" | sed 's/^LINE://')
                _echo "    $(_color c_dim '->') $(_color c_danger "$_ml")"
                ;;
        esac
    done < "$_result_file"
    _pause
}

# ===================== 单文件扫描 =====================

scan_file() {
    _file="$1"
    _filename=$(basename "$_file")
    _file_size=$(get_file_size "$_file")

    if [ -z "$_file_size" ] || [ "$_file_size" -eq 0 ]; then
        _info "$_filename - 空文件，跳过"
        inc_stat "skipped"
        return
    fi

    inc_stat "total"

    if [ "$_file_size" -ge 1048576 ]; then
        _size_display="$((_file_size / 1048576)) MB"
    elif [ "$_file_size" -ge 1024 ]; then
        _size_display="$((_file_size / 1024)) KB"
    else
        _size_display="${_file_size} B"
    fi

    _sep; _plong
    _echon "  $(_color c_file "扫描: $_filename")"
    _echo  " $(_color c_dim "(${_size_display})")"
    _pause

    _file_tmp="${TMP_DIR}/$(echo "$_filename" | tr '/' '_')"
    mkdir -p "$_file_tmp" 2>/dev/null

    _safe_copy="${_file_tmp}/original"
    if [ "$_file_size" -gt "$HUGE_FILE_THRESHOLD" ]; then
        dd if="$_file" of="$_safe_copy" bs=1048576 count=10 2>/dev/null
        _warn "文件过大，已截取前 10MB 用于分析"
    else
        cp "$_file" "$_safe_copy" 2>/dev/null
    fi

    # 处理二进制文件
    if is_binary_file "$_safe_copy" && ! is_gzip_file "$_safe_copy"; then
        STRINGS_CMD=$(get_cmd_path "strings")
        if [ -n "$STRINGS_CMD" ]; then
            _strings_out="${_file_tmp}/strings"
            "$STRINGS_CMD" "$_safe_copy" > "$_strings_out" 2>/dev/null
            if [ -s "$_strings_out" ]; then
                _info "二进制文件，已提取可读字符串用于分析"
                _safe_copy="$_strings_out"
            else
                _info "二进制文件，无有效字符串，跳过"
                inc_stat "skipped"; return
            fi
        else
            _info "二进制文件（非压缩），跳过"
            inc_stat "skipped"; return
        fi
    fi

    # === 递归解密 ===
    _decode_target=$(recursive_decode "$_safe_copy" 0 "$_file_tmp" 2>/dev/null)
    [ -z "$_decode_target" ] || [ ! -f "$_decode_target" ] && _decode_target="$_safe_copy"
    _plong

    # === 内联 Base64 检测 ===
    check_inline_base64 "$_decode_target" "$_file_tmp" 2>/dev/null
    _plong

    # === 混淆检测 ===
    _has_obfuscation=1
    check_obfuscation "$_decode_target" 2>/dev/null && _has_obfuscation=0 && _pause
    _plong

    # === 危险模式检测 ===
    _result_file=$(check_dangerous_patterns "$_decode_target" 2>/dev/null)
    _danger_level=$?

    # 检查内联 base64 是否有危险发现
    _inline_danger="${_file_tmp}/inline_b64_decoded.danger"
    if [ -f "$_inline_danger" ]; then
        _danger_level=2
    fi

    if [ "$_danger_level" -eq 2 ]; then
        inc_stat "dangerous"
        _critical_box "此文件为危险格机脚本！请立即删除！"
        [ -f "$_result_file" ] && print_danger_findings "$_result_file"
        _echo ""
        _echon "  $(_color c_danger '>> 建议: 立即删除此文件，不要以任何方式执行它！')"
        _echo ""
        _echo ""
        _plong
    elif [ "$_danger_level" -eq 1 ]; then
        inc_stat "suspicious"
        _warn "此文件包含可疑操作，建议审查"
        [ -f "$_result_file" ] && print_danger_findings "$_result_file"
        _echo ""
        _plong
    else
        if [ "$_has_obfuscation" -eq 0 ]; then
            inc_stat "suspicious"
            _warn "未发现危险命令，但存在混淆特征，建议人工审查"
        else
            inc_stat "clean"
            _ok "未发现危险命令"
        fi
        _pause
    fi

    _plong
}

# ===================== 批量扫描 =====================

batch_scan() {
    _scan_dir="$1"

    _echo ""
    _sep; _plong
    _echon "$(_color c_info "  扫描目录: $_scan_dir")"
    _echo ""
    _pause

    if [ ! -d "$_scan_dir" ]; then
        _echo ""
        _echon "$(_color c_crit '  目录不存在  ')"
        _echo ""
        _echo ""
        _echon "$(_color c_warn "请将待检测的脚本放入: $_scan_dir")"
        _echo ""
        _info "示例目录结构:"
        _echo "  detector.sh          <- 本脚本"
        _echo "  script/              <- 待检测脚本目录"
        _echo "    |- 待检测文件..."
        _echo "    |- 可疑脚本.sh"
        _echo ""
        return 1
    fi

    _list_file="${TMP_DIR}/file_list.txt"
    find "$_scan_dir" -maxdepth 1 -type f 2>/dev/null | sort > "$_list_file"

    _file_count=$(wc -l < "$_list_file" 2>/dev/null | tr -d ' ')

    if [ "$_file_count" -eq 0 ]; then
        _echo ""
        _echon "$(_color c_warn "  script 目录为空，没有可扫描的文件")"
        _echo ""
        _echon "$(_color c_warn "  请将待检测脚本放入 ${_scan_dir} 后重新运行")"
        _echo ""
        return 1
    fi

    _info "找到 ${_file_count} 个文件，开始扫描..."
    _echo ""; _plong

    while IFS= read -r _f; do
        [ -f "$_f" ] || continue
        scan_file "$_f"
        _echo ""; _plong
    done < "$_list_file"

    return 0
}

# ===================== 单目录扫描模式 =====================

scan_single_target() {
    _target="$1"

    if [ -f "$_target" ]; then
        _info "单文件扫描模式"
        _echo ""; _plong
        scan_file "$_target"
        return 0
    elif [ -d "$_target" ]; then
        _info "目录扫描模式"
        _echo ""; _plong
        batch_scan "$_target"
        return 0
    else
        _echon "$(_color c_crit '  路径不存在: ')"
        _echon "$(_color c_danger "$_target")"
        _echo ""
        return 1
    fi
}

# ===================== 汇总报告 =====================

print_summary() {
    _total=$(get_stat "total")
    _clean=$(get_stat "clean")
    _susp=$(get_stat "suspicious")
    _dang=$(get_stat "dangerous")
    _skip=$(get_stat "skipped")
    _deco=$(get_stat "decoded")
    _ib64=$(get_stat "inline_b64")

    _echo ""
    _sep; _plong
    _echon "$(_color c_banner '     扫描汇总报告')"
    _echo ""
    _sep; _plong
    _echo ""
    _echon "  总扫描文件数: $(_color c_banner "${_total}")"
    _echo  ""
    _echon "  安全文件:     $(_color c_ok     "${_clean}")"
    _echo  ""
    _echon "  可疑文件:     $(_color c_warn   "${_susp}")"
    _echo  ""
    _echon "  危险文件:     $(_color c_danger "${_dang}")"
    _echo  ""
    _echon "  跳过文件:     $(_color c_dim    "${_skip}")"
    _echo  ""
    if [ "$_deco" -gt 0 ]; then
        _echon "  解密操作:     $(_color c_decode "${_deco} 次")"
        _echo  ""
    fi
    if [ "$_ib64" -gt 0 ]; then
        _echon "  内联B64检测:  $(_color c_decode "${_ib64} 处")"
        _echo  ""
    fi
    _echo ""

    if [ "$_dang" -gt 0 ]; then
        _critical_box "发现 ${_dang} 个危险格机脚本！请立即处理！"
        _echo ""
        _echon "$(_color c_danger '  [操作建议]')"
        _echo ""
        _echon "  $(_color c_danger '1. 不要执行任何标记为危险的脚本')"
        _echo ""
        _echon "  $(_color c_danger '2. 备份后删除这些危险文件')"
        _echo ""
        _echon "  $(_color c_danger '3. 检查设备是否已被感染')"
        _echo ""
        _echo ""
    elif [ "$_susp" -gt 0 ]; then
        _warn "发现 ${_susp} 个可疑文件，建议人工审查"
        _echo ""
    else
        _ok "所有扫描文件均未发现危险命令"
        _echo ""
    fi

    _sep; _plong
    _echo ""
}

# ===================== 模式选择菜单 =====================

show_mode_menu() {
    _echo ""
    _sep; _plong
    _echo ""
    _echon "$(_color c_banner '  >>> 请选择检测模式 <<<')"
    _echo ""
    _echo ""
    _echon "  $(_color c_info '[1]') $(_color c_file '批量检测') $(_color c_dim '- 扫描脚本目录 /script 中的所有脚本')"
    _echo ""; _pause
    _echon "  $(_color c_info '[2]') $(_color c_file '指定路径') $(_color c_dim '- 检测指定的单个文件或目录')"
    _echo ""; _pause
    _echon "  $(_color c_info '[3]') $(_color c_file '当前目录') $(_color c_dim '- 扫描脚本所在目录的所有文件')"
    _echo ""; _pause
    _echo ""
    _echon "$(_color c_prompt '请输入数字 (1/2/3) 后按回车: ')"
}

get_user_choice() {
    # 尝试从标准输入读取
    if read _choice 2>/dev/null; then
        echo "$_choice"
    else
        echo "1"  # 默认批量模式
    fi
}

# ===================== 延迟暂停 =====================

wait_for_user() {
    _echo ""
    _sep; _plong
    _echo ""
    _echon "$(_color c_ok '  >>> 检测完毕 <<<')"
    _echo ""
    _echo ""
    _echon "$(_color c_dim "  详细日志已保存至: ${LOG_FILE}")"
    _echo ""
    _echo ""
    _echon "$(_color c_prompt '  按回车键退出...')"
    _echo ""
    read _WAIT 2>/dev/null || true
    _echo ""
}

# ===================== 清理 =====================

cleanup() {
    [ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR" 2>/dev/null
}

# ===================== Banner =====================

print_banner() {
    _echo ""
    _echon "$(_color c_banner '      格机脚本检测工具  v3.1')"
    _echo ""
    _echon "$(_color c_info  '      Brick Script Detector for Android 10-16')"
    _echo ""
    _sep
    _echo ""
    _pause
}

# ===================== 主入口 =====================

main() {
    trap cleanup EXIT INT TERM

    # 创建日志目录
    mkdir -p "$LOGS_DIR" 2>/dev/null

    print_banner
    _echon "$(_color c_info '  文件管理器自适应模式 | 彩色加粗 | 内联Base64解码')"
    _echo ""; _plong
    _echo ""

    check_environment
    _plong

    # ===== 模式选择 =====
    show_mode_menu
    _user_choice=$(get_user_choice)
    _echo ""; _plong

    case "$_user_choice" in
        2)
            # 模式2: 指定路径
            _echo ""
            _echon "$(_color c_prompt '  请输入要检测的文件或目录路径: ')"
            _target_path=$(get_user_choice)
            _echo ""
            if [ -z "$_target_path" ]; then
                _warn "未输入路径，返回默认批量模式"
                _user_choice="1"
            else
                _info "检测目标: $_target_path"
                _echo ""; _pause
                if ! scan_single_target "$_target_path"; then
                    _warn "路径无效，退出"
                    wait_for_user
                    cleanup
                    exit 1
                fi
                print_summary
                wait_for_user
                cleanup
                exit 0
            fi
            ;;
        3)
            # 模式3: 当前目录
            _info "检测目标: 脚本所在目录 ($SCRIPT_DIR)"
            _echo ""; _pause
            batch_scan "$SCRIPT_DIR"
            print_summary
            wait_for_user
            cleanup
            exit 0
            ;;
        *)
            # 默认模式1: 批量检测 script/
            _info "批量检测模式: 扫描 ${TARGET_DIR}"
            _echo ""; _pause
            ;;
    esac

    # 模式1 默认流程
    if [ ! -d "$TARGET_DIR" ]; then
        _echo ""
        _echon "$(_color c_warn "  未找到 script 目录")"
        _echo ""
        _echon "$(_color c_warn "  路径: ${TARGET_DIR}")"
        _echo ""
        mkdir -p "$TARGET_DIR" 2>/dev/null
        if [ -d "$TARGET_DIR" ]; then
            _ok "已创建 script 目录，请将待检测脚本放入后重新运行"
        else
            _warn "无法创建 script 目录，请手动创建"
        fi
        _echo ""
    fi

    batch_scan "$TARGET_DIR"
    print_summary
    wait_for_user
    cleanup
}

main