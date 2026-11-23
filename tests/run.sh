#!/bin/sh
# Host-side syntax / compatibility probes; no router filesystem touched.
set -eu
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d /tmp/mu300-enhance-tests.XXXXXX)
trap 'rm -rf "$T"' EXIT HUP INT TERM
fail() { echo "FAILED: $1" >&2; exit 1; }
for f in "$ROOT"/*.sh "$ROOT"/assets/mu300-mihomo-selector "$ROOT"/assets/mu300mselect; do
    sh -n "$f" || fail "shell $f"
done
command -v node >/dev/null 2>&1 && for f in "$ROOT"/assets/*.js; do node --check "$f" || fail "JavaScript $f"; done
jq -e '."luci-app-mu300-mihomo-select".read.ubus.mu300mselect==["get"] and
    ."luci-app-mu300-mihomo-select".write.ubus.mu300mselect==["set"]' \
    "$ROOT/assets/luci-app-mu300-mihomo-select.json" >/dev/null || fail ACL
cat > "$T/cli" <<'SRC'
url_get() {
    _p='=https'
    if command -v curl >/dev/null 2>&1; then
        printf 'url = "%s"\n' "$1" | curl -fsSL -m 30 --proto "$_p" --proto-redir "$_p" -K - 2>/dev/null
    fi
}
sub_apply() {
        if ( profile_edit "$_hit" "$3" ) >/dev/null 2>&1; then
            :
        fi
    case $_fmt in
        mihomo) _put "$_sname" mihomo "$_file" ;;
    esac
}
sub_format() {
    if grep -q '^proxies:' "$1"; then echo mihomo; else echo links; fi
}
sub_fetch_apply() {
    fetch_to "$URL" "$_f" || { URL=; URL_INSECURE=; return 1; }
    sub_apply "$1" "$_f" "$_fmt" "$_want"
    rm -f "$_f"
}
subscription_usage() {
    echo "usage: mu300-vpn subscription add NAME URL|- [--type auto|links|mihomo|dae]"
}
subscription_cmd() {
    case $_type in auto|links|mihomo|dae) : ;; esac
}
SRC
awk -v base="$ROOT/snippets/" -f "$ROOT/scripts/patch-native-cli.awk" "$T/cli" > "$T/cli.patched" || fail 'CLI patch'
grep -Fq 'SUB_DOWNLOAD_UA=sing-box/1.14.1' "$T/cli.patched" || fail 'CLI user agent'
grep -Fq 'cmp -s' "$T/cli.patched" || fail 'CLI no-change'
grep -Fq 'subscription import/check failed' "$T/cli.patched" || fail 'CLI invalid complete config'
! awk -v base="$ROOT/snippets/" -f "$ROOT/scripts/patch-native-cli.awk" "$T/cli.patched" >/dev/null 2>&1 || fail 'CLI double patch should fail'
sh "$ROOT/tests/subscriptions.sh" "$T" || fail 'CLI format selection and fallback'
cat > "$T/driver" <<'SRC'
MIHOMO_OURS='routing-mark allow-lan bind-address tun dns'
routing-mark: $((MARK))
    echo "tunnel up on $TUN (mihomo $MHPID)"
SRC
awk -f "$ROOT/scripts/patch-mihomo-driver.awk" "$T/driver" > "$T/driver.patched" || fail 'Mihomo driver patch'
grep -Fq 'external-controller-unix: /run/mu300-vpn/mihomo-control.sock' "$T/driver.patched" || fail 'Mihomo socket'
grep -Fq '/usr/libexec/mu300-mihomo-selector restore' "$T/driver.patched" || fail 'Mihomo restore'
! awk -f "$ROOT/scripts/patch-mihomo-driver.awk" "$T/driver.patched" >/dev/null 2>&1 || fail 'driver double patch should fail'
cat > "$T/sb-driver" <<'SRC'
drv_start() { exec "$BIN" run -c "$RUN/config.json" --disable-color; }
SRC
awk -f "$ROOT/scripts/patch-sing-box-driver.awk" "$T/sb-driver" > "$T/sb-driver.patched"
sh -n "$T/sb-driver.patched"
grep -Fq 'prepare-sing-box' "$T/sb-driver.patched" || fail 'sing-box controller startup'
cat > "$T/vpn-rpc" <<'SRC'
m_sub_add() {
    allowed "${type:-auto}" '(auto|links|mihomo|dae)' || return 1
}
SRC
awk -f "$ROOT/scripts/patch-subscription-rpc.awk" "$T/vpn-rpc" > "$T/vpn-rpc.patched"
sh -n "$T/vpn-rpc.patched"
grep -Fq '(auto|links|mihomo|sing-box|dae)' "$T/vpn-rpc.patched" || fail 'sing-box RPC format'
cat > "$T/sub.js" <<'SRC'
            E('option', { 'value': 'auto' }, [ _('Detect') ]),
            E('option', { 'value': 'mihomo' }, [ _('Clash/mihomo YAML: one mihomo profile') ]),
            V.note(_('The URL usually holds your account token: it is stored on the device readable by root only, and never shown again.'))
SRC
awk -v base="$ROOT/snippets/" -f "$ROOT/scripts/patch-subscription-view.awk" "$T/sub.js" > "$T/sub.patched.js" || fail 'subscriptions page patch'
grep -Fq "_('Detect (prefer full configurations)')" "$T/sub.patched.js" || fail 'subscriptions auto UI'
grep -Fq "'value': 'sing-box'" "$T/sub.patched.js" || fail 'subscriptions sing-box UI'
! awk -v base="$ROOT/snippets/" -f "$ROOT/scripts/patch-subscription-view.awk" "$T/sub.patched.js" >/dev/null 2>&1 || fail 'subscriptions double patch should fail'
cat > "$T/overview.js" <<'SRC'
'require mu300.vpn as V';
return view.extend({
load: function() {
    return Promise.all([ V.status(false), L.resolveDefault(V.call.profiles(), {}) ]);
},
render: function(data) {
    this.paint(data[0], data[1]);
},
reload: function() {
    if (a && a.tagName === 'SELECT') return;
    return Promise.all([ V.status(false), L.resolveDefault(V.call.profiles(), {}) ]).then(function(d) {
        self.paint(d[0], d[1]);
    });
},
paint: function(st, pl) {
    var grid = E('div', { 'class': 'mud-grid' }, [ ctl, ksCard, swCard, ipv6Card ]);
    var title = _('Overview');
}
});
SRC
awk -f "$ROOT/scripts/patch-stock-overview.awk" "$T/overview.js" > "$T/overview.patched.js" || fail 'stock overview patch'
grep -Fq 'MS.card(ms, function()' "$T/overview.patched.js" || fail 'Overview card'
grep -Fq 'MS.load()' "$T/overview.patched.js" || fail 'Overview offline loader'
grep -Fq 'reload: function(force)' "$T/overview.patched.js" || fail 'Overview update'
grep -Fq "'require mu300.mselect_overview_enhance as MS';" "$T/overview.patched.js" || fail 'Overview module'
grep -Fq "var title = _('Overview');" "$T/overview.patched.js" || fail 'upstream translation hook'
! awk -f "$ROOT/scripts/patch-stock-overview.awk" "$T/overview.patched.js" >/dev/null 2>&1 || fail 'Overview double patch should fail'
if command -v node >/dev/null 2>&1; then
    node --check "$T/overview.patched.js" || fail 'Overview generated JS'
    node --check "$T/sub.patched.js" || fail 'Subscription generated JS'
    node "$ROOT/tests/i18n.js" "$ROOT" "$T/sub.patched.js" || fail 'LuCI locales'
fi
printf 'PASS: Shell, LuCI JavaScript, ACL, native CLI, driver, Overview, subscription source matches, double-patch guards.\n'
sh "$ROOT/tests/controller.sh" "$ROOT" "$T"
sh "$ROOT/tests/lifecycle.sh" "$ROOT" "$T"
