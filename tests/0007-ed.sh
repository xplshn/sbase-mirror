#!/bin/sh

set -e

tmp=tmp.$$

trap 'rm -f $tmp' EXIT
trap 'rm -f $tmp; kill -KILL $$' HUP INT TERM

printf 'something important' > $tmp
../ed -s $tmp <<EOF 2>/dev/null | diff -w $tmp -
1p
EOF
