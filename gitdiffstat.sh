#!/bin/bash

set -eu


usage()
{
	echo
}

show_help()
{
	echo
}

show_commit_diffstats()
{
	until_line=$1
	until_commit=$2
	until_import=$3
	line_number=0

	for commit in $(git log --oneline |awk '{print $1}' -); do
		if [ $line_number -eq $until_line ]; then
			return 0
		fi

		if [ $until_import -eq 1 ]; then
		    if git show --oneline $commit | head -1| grep "tag: pkg/import" >>/dev/null; then
		    	return 0
		    fi
		fi

		echo;
		git show --oneline $commit | head -1
		git show $commit | diffstat

		if [ "$commit" == "$until_commit" ]; then
			return 0
		fi
		line_number=$(expr $line_number + 1)
	done
}

UNTIL_LINE=-1
UNTIL_COMMIT=_
UNTIL_IMPORT=1

while getopts "?l:u:a" o; do
    case "$o" in
        \?)
            show_help
            exit 0
            ;;
        l)
            UNTIL_LINE=$OPTARG
            UNTIL_IMPORT=0
            ;;
        u)
            UNTIL_COMMIT=$OPTARG
            UNTIL_IMPORT=0
            ;;
        u)
            UNTIL_LINE=-1
            UNTIL_COMMIT=_
            UNTIL_IMPORT=0
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

show_commit_diffstats $UNTIL_LINE $UNTIL_COMMIT $UNTIL_IMPORT
