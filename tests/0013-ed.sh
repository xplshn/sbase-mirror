#!/bin/sh

tmp=tmp.$$

trap 'rm -f $tmp' EXIT
trap 'rm -f $tmp' HUP INT TERM

cat <<EOF >$tmp
x
y
/dev/null
EOF

../ed -s /dev/null <<EOF  | diff -u $tmp -
a
1
2
3
.
E !printf 'x\ny\n'
,p
f
EOF
