#!/bin/sh

set -e

tmp=tmp1.$$

trap 'rm -f $tmp' EXIT
trap 'rm -f $tmp; kill -KILL $$' HUP INT TERM

../echo -n --hello-- --world--! > $tmp

tr -d '\n' <<'EOF' | diff -u - $tmp
--hello-- --world--!
EOF
