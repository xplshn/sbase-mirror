#!/bin/sh

set -e

tmp1=$$.tmp1
tmp2=$$.tmp2

trap 'rm -f $tmp1 $tmp2' EXIT
trap 'exit $?' HUP INT TERM

cat <<EOF >$tmp1
../dc: stack empty
5
148.41315910257660342111
EOF

echo 5p >$tmp2

../dc $tmp2 <<EOF 2>&1 | diff -u - $tmp1
`echo 'e(5)' | ../bc -c ../bc.library`
la sa sa sa
EOF
