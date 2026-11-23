# Patch upstream mu300-vpn once, using strictly matched anchors.
function put(f, line, rc) {
    while ((rc = (getline line < (base f))) > 0) print line
    if (rc < 0) { print "Cannot read snippet: " base f > "/dev/stderr"; exit 60 }
    close(base f)
}
skip_fetch { if ($0 == "}") { skip_fetch=0; fetch_end++ }; next }
$0 == "sub_fetch_apply() {" { put("sub_fetch"); fetch++; skip_fetch=1; next }
index($0, "curl -fsSL -m 30 --proto \"$_p\" --proto-redir \"$_p\" -K - 2>/dev/null") &&
index($0, "printf 'url =") { put("url_get"); url++; next }
$0 == "sub_format() {" { print; put("sub_format"); format++; next }
index($0, "if ( profile_edit \"$_hit\" \"$3\" ) >/dev/null 2>&1; then") { put("sub_unchanged"); unchanged++; next }
$0 == "        mihomo) _put \"$_sname\" mihomo \"$_file\" ;;" { put("sub_valid"); valid++; next }
index($0, "subscription add NAME URL|- [--type auto|links|mihomo|dae]") {
    sub(/auto\|links\|mihomo\|dae/, "auto|links|mihomo|sing-box|dae"); usage++
}
index($0, "case $_type in auto|links|mihomo|dae)") {
    sub(/auto\|links\|mihomo\|dae/, "auto|links|mihomo|sing-box|dae"); types++
}
{ print }
END {
    if (fetch!=1 || fetch_end!=1 || url!=1 || format!=1 || unchanged!=1 || valid!=1 || usage!=1 || types!=1) {
        print "Unsupported native CLI structure; no changes installed" > "/dev/stderr"; exit 61
    }
}
