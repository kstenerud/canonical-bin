#!/bin/bash

set -eu

usage()
{
	echo "Usage: $(basename $0) <working log url> <broken log url>"
}

fetch_log()
{
	url="$1"
	curl --silent "$url" | gunzip
}

remove_initial_gets()
{
	sed -n '/The following additional packages will be installed:/,$p'
}

match_gets()
{
	grep 'Get:'
}

remove_get_start()
{
	sed -e 's/Get:.*\/ubuntu [a-z0-9\/-]* amd64 //g'
}

save_log()
{
	file="$1"
	url="$2"

	fetch_log "$url" | remove_initial_gets | match_gets | remove_get_start | sort > "$file"
}

if [ $# -ne 2 ]; then
	usage
	exit 1
fi

URL_1=$1
URL_2=$2
FILE_1=/tmp/build.1
FILE_2=/tmp/build.2


save_log "$FILE_1" "$URL_1"
save_log "$FILE_2" "$URL_2"

diff "$FILE_1" "$FILE_2"
