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
