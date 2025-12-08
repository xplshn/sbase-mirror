#!/bin/sh

set -e

res1=tmp1.$$
res2=tmp2.$$

trap 'rm -f $res1 $res2' EXIT
trap 'rm -f $res1 $res2; kill -KILL $$' HUP INT TERM

(
	../printf '123\n'
	../printf '%d\n'
	../printf '%b' 'foo\nbar\n'

	# Two flags used simulatenously, + and 0
	../printf '%+04d %+4d ' 1 2 3 -400; ../printf "\n"
	# Missing format specifier; should have sane error message
	../printf '%000' FOO || echo "Expected failure"
) > $res1 2> $res2

diff -u - $res1 <<'EOF'
123
0
foo
bar
+001   +2 +003 -400 
Expected failure
EOF
  
diff -u - $res2 <<'EOF'
../printf: Missing format specifier.
EOF
