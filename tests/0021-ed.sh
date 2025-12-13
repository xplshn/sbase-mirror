#!/bin/sh

tmp=tmp.$$

trap 'rm -f $tmp' EXIT
trap 'rm -f $tmp; kill -KILL $$' HUP INT TERM

cat <<EOF >$tmp
1
2
3
EOF

../ed -s /dev/null <<EOF | diff -u $tmp -
a
1
2
3
.
g/^$/d
,p
Q
EOF
