# Add the full JSON format to the stock subscription view.
function put(f, line, rc) {
    while ((rc = (getline line < (base f))) > 0) print line
    if (rc < 0) { print "Cannot read snippet: " base f > "/dev/stderr"; exit 60 }
    close(base f)
}
index($0, "E('option', { 'value': 'auto' },") { put("ui_auto"); a++; next }
index($0, "Clash/mihomo YAML: one mihomo profile") { put("ui_mihomo"); m++; next }
index($0, "The URL usually holds your account token") { put("ui_note"); n++; next }
{print}
END {
    if (a!=1 || m!=1 || n!=1) {
        print "Unsupported subscriptions page; no changes installed" > "/dev/stderr"; exit 62
    }
}
