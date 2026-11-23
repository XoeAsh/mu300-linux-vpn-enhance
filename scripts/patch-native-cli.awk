# Patch upstream mu300-vpn once, using strictly matched anchors.
# All four edits must match once; otherwise do not install the generated file.
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
    if (u!=1 || f!=1 || c!=1 || v!=1) {
        print "Unsupported native CLI structure; no changes installed" > "/dev/stderr"; exit 61
    }
}
