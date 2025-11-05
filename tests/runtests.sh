#!/bin/sh

export TZ=UTC

cleanup()
{
	st=$?
	rm -f test.res
	exit $st
}

trap cleanup EXIT HUP INT TERM

for i in *-*.sh
do
	printf "Test: %s\n\n" $i >> test.log
	(./$i >> test.log 2>&1 && printf '[PASS]\t' || printf '[FAIL]\t'
	echo "$i") | tee -a test.log
done |
tee test.res

! grep FAIL test.res >/dev/null
