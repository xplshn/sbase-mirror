#!/bin/sh

set -e

tmp=tmp1.$$

cleanup()
{
	st=$?
	rm -f $tmp
	exit $st
}

trap cleanup EXIT

../echo -n --hello-- --world--! > $tmp

tr -d '\n' <<'EOF' | diff -u - $tmp
--hello-- --world--!
EOF
