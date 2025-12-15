#!/bin/sh

tmp=tmp.$$

trap 'rm -f $tmp' EXIT
trap 'rm -f $tmp; kill -KILL $$' HUP INT TERM

touch $tmp
../ed -s $tmp <<EOF | (read a && test $a = 1)
a
1
.
w
,c
2
.
W
e
1p
EOF
