#!/bin/sh
# Exercise installation and full removal with temporary device paths.
set -eu
ROOT=$1 T=$2
DEVICE=$T/router PACKAGE=$T/package
BIN=$DEVICE/opt/mu300/bin
STATE=$DEVICE/root/.mu300-linux-vpn-enhance
CRON=$DEVICE/etc/crontabs/root
VPN_RUN=$DEVICE/run/mu300-vpn
VPN_STORE=$DEVICE/etc/mu300/vpn
MENU=$DEVICE/usr/share/luci/menu.d/luci-app-mu300.json
VIEW=$DEVICE/www/luci-static/resources/view/mu300
I18N=$DEVICE/usr/lib/lua/luci/i18n
VPN_RPC=$DEVICE/usr/libexec/rpcd/mu300vpn
mkdir -p "$PACKAGE" "$BIN" "$BIN/../lib/vpn" "$DEVICE/tmp" "$DEVICE/root" "$VPN_RUN" "$VPN_STORE" \
    "$DEVICE/etc/init.d" "${CRON%/*}" "${MENU%/*}" "${VPN_RPC%/*}" "$VIEW" "$I18N"
cp -R "$ROOT/assets" "$ROOT/scripts" "$ROOT/snippets" "$ROOT/i18n" "$ROOT/VERSION" "$PACKAGE/"
sed "s|/run/mu300-vpn|$VPN_RUN|g; s|/etc/mu300/vpn|$VPN_STORE|g; s|/root/.mu300-linux-vpn-enhance|$STATE|g" \
    "$ROOT/assets/mu300-mihomo-selector" > "$PACKAGE/assets/mu300-mihomo-selector"
for file in install.sh uninstall.sh; do
    sed "s|/tmp/|$DEVICE/tmp/|g; s|/root/|$DEVICE/root/|g; s|/etc/|$DEVICE/etc/|g;
         s|/www/|$DEVICE/www/|g; s|/usr/libexec/|$DEVICE/usr/libexec/|g;
         s|/usr/share/luci/|$DEVICE/usr/share/luci/|g; s|/usr/share/rpcd/|$DEVICE/usr/share/rpcd/|g;
         s|/usr/lib/lua/luci/i18n|$I18N|g;
         s|/run/mu300-vpn|$VPN_RUN|g;
         s|/var/luci-|$DEVICE/var/luci-|g" "$ROOT/$file" > "$PACKAGE/$file"
done
cp "$T/driver" "$BIN/../lib/vpn/mihomo.sh"
cp "$T/sb-driver" "$BIN/../lib/vpn/sing-box.sh"
cp "$T/vpn-rpc" "$VPN_RPC"
cp "$T/sub.js" "$VIEW/vpn-subscriptions.js"
cp "$T/overview.js" "$VIEW/vpn-overview.js"
printf '%s\n' '{"admin/vpn/mu300-overview":{"action":{"path":"mu300/vpn-overview"}},"admin/vpn/mu300-subscriptions":{"action":{"path":"mu300/vpn-subscriptions"}}}' > "$MENU"
{
    printf '#!/bin/sh\n'
    cat "$T/cli"
    cat <<'SRC'
[ "$1" != version ] || printf '2.0.4\n'
SRC
} > "$BIN/mu300-vpn"
printf '#!/bin/sh\nprintf "0\\n"\n' > "$BIN/id"
printf '#!/bin/sh\nprintf "Features: UnixSockets\\n"\n' > "$BIN/curl"
printf '#!/bin/sh\nexit 0\n' > "$BIN/jsonfilter"
printf '#!/bin/sh\ntest "${TEST_FAIL_RPC:-0}" = 0\n' > "$DEVICE/etc/init.d/rpcd"
printf '#!/bin/sh\nexit 1\n' > "$DEVICE/etc/init.d/cron"
chmod +x "$BIN/mu300-vpn" "$BIN/id" "$BIN/curl" "$BIN/jsonfilter" "$DEVICE/etc/init.d/rpcd" "$DEVICE/etc/init.d/cron"
export PATH="$BIN:$PATH"
printf '23 3 * * * /bin/true\n# 17 * * * * mu300-vpn subscription refresh --due\n' > "$CRON"
printf 'upstream translation catalog\n' > "$I18N/mu300.tr.lmo"
printf 'original VPN configuration\n' > "$VPN_RUN/config.json"
printf 'original VPN profile\n' > "$VPN_STORE/example"
cp "$CRON" "$T/original-cron"
cp "$BIN/mu300-vpn" "$T/original-cli"
cp "$MENU" "$T/original-menu"
run() {
    file=$1; shift
    if ! sh "$file" "$@" > "$T/lifecycle.log" 2>&1; then
        cat "$T/lifecycle.log" >&2; exit 1
    fi
}
reject() {
    file=$1; shift
    if sh "$file" "$@" > "$T/lifecycle.log" 2>&1; then
        echo "Expected failure: $file" >&2; exit 1
    fi
}

TEST_FAIL_RPC=1 reject "$PACKAGE/install.sh"
[ -f "$STATE/uninstall-ready" ] && [ ! -e "$STATE/installed-version" ]
[ -f "$VIEW/vpn-overview-enhance.js" ] && [ -f "$I18N/mu300-vpn-enhance.tr.lmo" ]
run "$STATE/uninstall.sh"
cmp "$CRON" "$T/original-cron"
cmp "$BIN/mu300-vpn" "$T/original-cli"
cmp "$BIN/../lib/vpn/sing-box.sh" "$T/sb-driver"
cmp "$VPN_RPC" "$T/vpn-rpc"
[ ! -e "$VIEW/vpn-overview-enhance.js" ]
[ ! -e "$I18N/mu300-vpn-enhance.tr.lmo" ]
[ ! -e "$STATE" ]

run "$PACKAGE/install.sh"
cmp "$CRON" "$T/original-cron"
grep -Fq 'prepare-sing-box' "$BIN/../lib/vpn/sing-box.sh"
grep -Fq 'auto|links|mihomo|sing-box|dae' "$VPN_RPC"
for lang in zh-cn tr; do
    name=mu300-vpn-enhance.$lang.lmo
    cmp "$ROOT/i18n/$name" "$I18N/$name"
done
cp "$MENU" "$T/enhanced-menu"
printf 'unrelated local change\n' > "$MENU"
reject "$STATE/uninstall.sh"
[ "$(cat "$MENU")" = 'unrelated local change' ]
[ -r "$VIEW/vpn-overview-enhance.js" ]
cp "$T/enhanced-menu" "$MENU"
printf '[]\n' > "$STATE/selections.json"
printf 'owned runtime file\n' > "$VPN_RUN/sing-box-controlled.json"
TEST_FAIL_RPC=1 reject "$STATE/uninstall.sh"
[ -f "$STATE/uninstall-in-progress" ]
run "$STATE/uninstall.sh"
run "$PACKAGE/uninstall.sh"
cmp "$CRON" "$T/original-cron"
cmp "$MENU" "$T/original-menu"
cmp "$BIN/mu300-vpn" "$T/original-cli"
[ ! -e "$I18N/mu300-vpn-enhance.zh-cn.lmo" ] && [ ! -e "$STATE" ]
[ ! -e "$VPN_RUN/sing-box-controlled.json" ]
[ "$(cat "$VPN_RUN/config.json")" = 'original VPN configuration' ]
[ "$(cat "$VPN_STORE/example")" = 'original VPN profile' ]
[ "$(cat "$I18N/mu300.tr.lmo")" = 'upstream translation catalog' ]
mv "$CRON" "$T/cron-detached"
run "$PACKAGE/install.sh"
[ ! -e "$CRON" ]
run "$STATE/uninstall.sh"
[ ! -e "$CRON" ]
echo 'PASS: Complete uninstall, conflict protection, catalogs, and stock files and scheduler preserved.'
