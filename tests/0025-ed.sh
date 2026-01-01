#!/bin/sh

tmp=tmp.$$

trap 'rm -f $tmp' EXIT
trap 'rm -f $tmp; kill -KILL $$' HUP INT TERM

cat <<'EOF' > $tmp
LLL\
static int xflag = 0;
static int gflag = 0;
extern long arflag = 0;
EOF

../ed -s /dev/null <<'EOF' | diff -u $tmp -
i
LLL
.
s/$/\\
g/^L/ a\
static int xflag = 0;\
static int gflag = 0;\
static int arflag = 0;
v! .flag!s/^static/extern/\
s# int # long #
g_^[^a-z]_d
,p
Q
EOF
