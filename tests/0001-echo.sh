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

trap cleanup EXIT HUP INT TERM

cat <<'EOF' | tr -d '\n' > $tmp1
--hello-- --world--!
EOF

../echo -n --hello-- --world--! > $tmp2

diff -u $tmp1 $tmp2
