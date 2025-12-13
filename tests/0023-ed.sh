#!/bin/sh

tmp=tmp.$$

trap 'rm -f $tmp' EXIT
trap 'rm -f $tmp; kill -KILL $$' HUP INT TERM

cat <<EOF >$tmp
Line
EOF

ed -s /dev/null <<EOF | diff -u $tmp -
0a
   Line
.
s# *##
,p
Q
EOF
