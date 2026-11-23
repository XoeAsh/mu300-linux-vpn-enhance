#!/bin/sh
# Exercise negotiation, preserved formats and cleanup without a network request.
set -eu
T=$1
. "$T/cli.patched"
SUBS=$T/subscriptions
RUN=$T/run
TRACE=$T/attempts
mkdir -p "$SUBS/example" "$RUN"
printf '%s\n' https://example.invalid/subscription > "$SUBS/example/url"

kv_var() {
    case "$1" in
        _ins) _ins= ;;
        _want) _want=$wanted ;;
        _previous_fmt) _previous_fmt=$saved ;;
        *) return 1 ;;
    esac
}
run_dir() { [ -d "$RUN" ]; }
json_strict() { jq -e 'type == "object"' "$1" >/dev/null; }
fetch_to() {
    printf '%s\n' "${SUB_DOWNLOAD_UA:-default}" >> "$TRACE"
    case "${SUB_DOWNLOAD_UA:-}:$responses" in
        sing-box/1.14.1:full|sing-box/1.14.1:bad-json)
            printf '%s\n' '{"outbounds":[{"type":"direct"}]}' > "$2" ;;
        ClashMeta/1.19.0:yaml|ClashMeta/1.19.0:bad-json)
            printf '%s\n' 'proxies: []' > "$2" ;;
        *) printf '%s\n' 'ss://fixture' > "$2" ;;
    esac
}
sub_apply() {
    if [ "$3:$responses" = sing-box:bad-json ]; then return 1; fi
    printf '%s\n' "$3"
}
check() {
    wanted=$1 saved=$2 responses=$3 expected=$4 attempts=$5
    : > "$TRACE"
    actual=$(sub_fetch_apply example 2>/dev/null) || actual=failed
    [ "$actual" = "$expected" ]
    [ "$(paste -sd ' ' "$TRACE")" = "$attempts" ]
    [ -z "$(ls -A "$RUN")" ]
}
check auto '' full sing-box 'sing-box/1.14.1'
check auto '' yaml mihomo 'sing-box/1.14.1 ClashMeta/1.19.0'
check auto '' bad-json mihomo 'sing-box/1.14.1 ClashMeta/1.19.0'
check auto '' links links 'sing-box/1.14.1 ClashMeta/1.19.0 default'
check auto links full links default
check auto mihomo links failed ClashMeta/1.19.0
check auto sing-box links failed sing-box/1.14.1
check sing-box '' full sing-box sing-box/1.14.1
check sing-box '' bad-json failed sing-box/1.14.1
check mihomo '' yaml mihomo ClashMeta/1.19.0
