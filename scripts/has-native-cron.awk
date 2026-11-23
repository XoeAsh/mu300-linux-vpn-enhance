# Match a scheduled command, excluding comments and cron environment assignments.
($1 !~ /^#/ && $6 ~ /(^|\/)mu300-vpn$/ &&
 $7 == "subscription" && $8 == "refresh" && $9 == "--due") { found=1 }
END { exit !found }
