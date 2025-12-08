#!/bin/sh

set -e

tmp=tmp.$$

trap 'rm -f $tmp' EXIT
trap 'rm -f $tmp; kill -KILL $$' HUP INT TERM

../ed <<EOF > /dev/null
../ed -s <<EOF > /dev/null
0a
This is important
.
s/^@//
w $tmp
EOF

echo 'This is important' | diff -u - $tmp
