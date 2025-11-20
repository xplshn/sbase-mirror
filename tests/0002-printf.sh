#!/bin/sh

set -e

exp1=tmp1.$$
exp2=tmp2.$$
res1=tmp3.$$
res2=tmp4.$$

cleanup()
{
	st=$?
	rm -f $exp1 $exp2 $res1 $res2
	exit $st
}

trap cleanup EXIT HUP INT TERM

cat <<'EOF' > $exp1
123
0
foo
bar
+001   +2 +003 -400 
Expected failure
EOF

cat <<'EOF' > $exp2
../printf: Missing format specifier.
EOF

(
	../printf '123\n'
	../printf '%d\n'
	../printf '%b' 'foo\nbar\n'

	# Two flags used simulatenously, + and 0
	../printf '%+04d %+4d ' 1 2 3 -400; ../printf "\n"
	# Missing format specifier; should have sane error message
	../printf '%000' FOO || echo "Expected failure"
) > $res1 2> $res2

diff -u $exp1 $res1
diff -u $exp2 $res2
