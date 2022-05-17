#!/bin/sh

## Either print a line beginning with the second argument, followed by
## all others comma-separated, or do nothing if there is nothing
## beyond the second argument.

PRINTF="$1"
shift

sep="$1"
shift

while [ $# -gt 0 ] ; do
    $PRINTF '%s%s' "$sep" "$1"
    shift
    sep=','
    term='\n'
done
$PRINTF "$term"
