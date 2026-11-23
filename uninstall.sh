#!/bin/sh
# Remove the enhancement and restore the originals it replaced.
set -eu
[ "$(id -u)" = 0 ] || { echo '请使用 root 执行' >&2; exit 1; }
[ "$#" -eq 0 ] || { echo '用法为 sh uninstall.sh' >&2; exit 2; }
STATE=/root/.mu300-linux-vpn-enhance
RUN=/run/mu300-vpn
SELECTOR=/usr/libexec/mu300-mihomo-selector

[ -d "$STATE" ] || { echo '增强包已卸载。'; exit 0; }
[ ! -L "$STATE" ] || { echo "卸载路径为符号链接，已保留 $STATE" >&2; exit 1; }
[ -f "$STATE/uninstall-ready" ] && [ -r "$STATE/installed.sha256" ] &&
    [ -r "$STATE/originals" ] || { echo "卸载记录不完整，已保留 $STATE" >&2; exit 1; }
if [ -r "$STATE/installing-pid" ]; then
    pid=$(cat "$STATE/installing-pid")
    case "$pid" in
        ''|0|*[!0-9]*) ;;
        *) if kill -0 "$pid" 2>/dev/null; then
               echo '安装仍在运行，请等安装结束后再卸载。' >&2; exit 1
           fi ;;
    esac
fi

# Validate every managed path before restoring or removing any of them.
while IFS= read -r file; do
    [ -f "$STATE/files$file" ] || { echo "缺少原版文件备份 $file" >&2; exit 1; }
done < "$STATE/originals"
while read -r sum file; do
    if [ ! -e "$file" ] && [ ! -L "$file" ]; then continue; fi
    if [ -f "$file" ] && [ ! -L "$file" ]; then
        if [ -f "$STATE/files$file" ] && cmp -s "$file" "$STATE/files$file"; then continue; fi
        if printf '%s  %s\n' "$sum" "$file" | sha256sum -c >/dev/null 2>&1; then continue; fi
    fi
    echo "文件 $file 在安装后有其它修改。为保护当前文件，已停止卸载。" >&2
    exit 1
done < "$STATE/installed.sha256"

if [ -x "$SELECTOR" ] && "$SELECTOR" in-use >/dev/null 2>&1; then
    echo '代理节点控制仍在运行。请在 LuCI 中停止 VPN，再执行同一条卸载命令。' >&2
    exit 1
fi

: > "$STATE/uninstall-in-progress"
tmp=
trap '[ -z "$tmp" ] || rm -f "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
restore_file() {
    tmp=$(mktemp "$2.uninstall.XXXXXX")
    cp -p "$1" "$tmp" && mv -f "$tmp" "$2" || return 1
    tmp=
}

while read -r sum file; do
    if [ -f "$STATE/files$file" ]; then
        restore_file "$STATE/files$file" "$file"
    else
        rm -f "$file"
    fi
done < "$STATE/installed.sha256"
rm -f "$RUN/mihomo-control.sock" "$RUN/sing-box-controlled.json" "$RUN/sing-box-selector-owner"
rm -rf "$RUN"/.mu300-vpn-enhance-selector.*
rm -f /tmp/luci-indexcache* /var/luci-indexcache* 2>/dev/null || true
rm -rf /tmp/luci-modulecache /var/luci-modulecache 2>/dev/null || true
[ ! -x /etc/init.d/rpcd ] || /etc/init.d/rpcd restart
[ ! -x /etc/init.d/uhttpd ] || /etc/init.d/uhttpd restart
rm -rf "$STATE"
echo '增强包已完全卸载。原版 VPN 和 LuCI 文件、配置及订阅均已保留。'
