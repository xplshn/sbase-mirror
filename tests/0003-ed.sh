#!/bin/sh

set -e

tmp1=tmp1.$$
tmp2=tmp2.$$

cleanup()
{
	st=$?
	rm -f $tmp1 $tmp2
	exit $st
}

trap cleanup EXIT

cat <<EOF >$tmp1
foo
bar

baz
EOF

# Unspecified whether quit with a dirty buffer is considered an error, allow both
../ed $tmp1 <<EOF >$tmp2 || test $? -eq 1
v#^\$#p
p
g/^\$/d
,p
q
a
fizz
buzz
.
i
foobar
.
w
v!z\$!d
,p
q
1,2j
1,2j
,p
q
EOF

diff -u - $tmp2 <<EOF
13
foo
bar
baz
baz
foo
bar
baz
?
29
baz
fizz
buzz
?
bazfizzbuzz
?
EOF

diff -u - $tmp1 <<EOF
foo
bar
baz
fizz
foobar
buzz
EOF

printf foo >$tmp1
../ed $tmp1 <<EOF >$tmp2
,p
w
EOF

# This is somewhat opinionated test for files without trailing newline, more
# documenting the current behavior, which differs from BSD and GNU eds.
diff -u - $tmp2 <<EOF || true
3
foo
4
EOF

diff -u - $tmp1 <<EOF
foo
EOF

../ed <<EOF >$tmp2
i
foo
bar
.
,t
1t
2t
2,3t
3,7p
EOF

diff -u - $tmp2 <<EOF
foo
bar
foo
bar
bar
EOF
