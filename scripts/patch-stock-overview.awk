# Source-compatible patch for mu300-linux LuCI vpn-overview.js; fail if structure changes.
BEGIN { req=0; load=0; reload=0; render=0; repaint=0; sig=0; grid=0; reloadsig=0; skip=0 }
{
  line=$0
  if (line == "'require mu300.vpn as V';") {
    print line
    print "'require mu300.mselect_overview_enhance as MS';"
    req++
    next
  }
  if (index(line, "return Promise.all([ V.status(false), L.resolveDefault(V.call.profiles(), {}) ]);") > 0) {
    sub(/\]\);/, ", MS.load() ]);", line)
    load++
  }
  if (index(line, "return Promise.all([ V.status(false), L.resolveDefault(V.call.profiles(), {}) ]).then(function(d) {") > 0) {
    sub(/\]\)\.then\(function\(d\) \{/, ", MS.load() ]).then(function(d) {", line)
    reload++
  }
  if (index(line, "this.paint(data[0], data[1]);") > 0) {
    gsub(/this.paint\(data\[0\], data\[1\]\);/, "this.paint(data[0], data[1], data[2]);", line)
    render++
  }
  if (index(line, "self.paint(d[0], d[1]);") > 0) {
    gsub(/self.paint\(d\[0\], d\[1\]\);/, "self.paint(d[0], d[1], d[2]);", line)
    repaint++
  }
  if (index(line, "reload: function() {") > 0) {
    sub(/reload: function\(\) \{/, "reload: function(force) {", line)
    reloadsig++
  }
  if (index(line, "if (a && a.tagName === 'SELECT'") > 0) {
    line = substr(line, 1, index(line, "if (a &&") - 1) "if (!force && a &&" substr(line, index(line, "if (a &&") + length("if (a &&"))
    skip++
  }
  if (index(line, "paint: function(st, pl) {") > 0) {
    sub(/paint: function\(st, pl\)/, "paint: function(st, pl, ms)", line)
    sig++
  }
  if (index(line, "var grid = E('div', { 'class': 'mud-grid' }, [ ctl, ksCard, swCard, ") > 0 && line ~ / \]\);$/) {
    sub(/ \]\);$/, ", MS.card(ms, function() { return self.reload(true); }) ]);", line)
    grid++
  }
  print line
}
END {
  if (req != 1 || load != 1 || reload != 1 || render != 1 || repaint != 1 || sig != 1 || grid != 1 || reloadsig != 1 || skip != 1) {
    print "Unexpected VPN Overview layout: required patch points not found exactly once" > "/dev/stderr"
    exit 1
  }
}
