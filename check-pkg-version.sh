#!/bin/bash
set -eu

if [ $# -ne 1 ]; then
	echo "Usage: $(basename $0) <package>"
	exit 1
fi

PACKAGE=$1
DEBIAN_PACKAGE_VERSION="$(rmadison -u debian $PACKAGE | grep "unstable " | tail -1 |cut -d "|" -f 2)"
UBUNTU_PACKAGE_VERSION="$(rmadison $PACKAGE | tail -1 |cut -d "|" -f 2)"

echo "U: $UBUNTU_PACKAGE_VERSION"
echo "D: $DEBIAN_PACKAGE_VERSION"
