#!/bin/sh

tmp=$$.tmp

trap 'rm -f $tmp' EXIT
trap 'exit $?' HUP INT TERM

# Test negative number sqrt - should produce error message and push 0
# Test negative numbers: integers, fractions, odd and even fraction digits
$EXEC ../dc <<EOF >$tmp 2>&1
[test 1:]pc _1vp
[test 2:]pc _4vp
[test 3:]pc _.5vp
[test 4:]pc _.25vp
EOF

diff -u - $tmp <<'EOF'
../dc: square root of negative number
../dc: square root of negative number
../dc: square root of negative number
../dc: square root of negative number
test 1:
0
test 2:
0
test 3:
0
test 4:
0
EOF
