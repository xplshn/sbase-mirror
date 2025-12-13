#!/bin/sh

../ed -s /dev/null <<EOF | wc -l | grep 0 >/dev/null
a
line
.
1g/^$/p
Q
EOF
