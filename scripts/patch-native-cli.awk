# Patch upstream mu300-vpn once, using strictly matched anchors.
BEGIN {
    apply = "    sub_apply \"$1\" \"$_f\" \"$_fmt\" \"$_want\""
    preserve = apply " || { _apply_rc=$?; rm -f \"$_f\" || true; return \"$_apply_rc\"; }"
}
$0 == apply { print preserve; status++; next }
function put(f, line, rc) {
    while ((rc = (getline line < (base f))) > 0) print line
    if (rc < 0) { print "Cannot read snippet: " base f > "/dev/stderr"; exit 60 }
    close(base f)
}
index($0, "curl -fsSL -m 30 --proto \"$_p\" --proto-redir \"$_p\" -K - 2>/dev/null") &&
index($0, "printf 'url =") { put("url_get"); u++; next }
index($0, "fetch_to \"$URL\" \"$_f\" || { URL=; URL_INSECURE=; return 1; }") { put("sub_fetch"); f++; next }
index($0, "if ( profile_edit \"$_hit\" \"$3\" ) >/dev/null 2>&1; then") { put("sub_unchanged"); c++; next }
$0 == "        mihomo) _put \"$_sname\" mihomo \"$_file\" ;;" { put("sub_valid"); v++; next }
{ print }
END {
    if (status!=1 || u!=1 || f!=1 || c!=1 || v!=1) {
        print "Unsupported native CLI structure; no changes installed" > "/dev/stderr"; exit 61
    }
}
