#!/bin/sh
tmp=tmp.$$

trap 'rm -f $tmp' EXIT
trap 'rm -f $tmp; kill -KILL $$' HUP INT TERM

set -e

../ed -s $tmp <<EOF >/dev/null
a
1
2
.
5d
x
EOF

printf '1\n2\n' | diff -u $tmp -
