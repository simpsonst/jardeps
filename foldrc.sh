#!/bin/bash

while [ $# -gt 0 ] ; do
    if [ "$1" == '--' ] ; then
	shift
	break
    fi

    if [ -z "$src" ] ; then
	src="$1"
    else
	MAP[$src]="$1"
	unset src
    fi

    shift
done

"$@"

rc="$?"
if [ -n "${MAP[$rc]}" ] ; then
    exit "${MAP[$rc]}"
fi

exit "$rc"
