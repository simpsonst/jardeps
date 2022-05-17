#!/bin/sh

CMP="$1"
shift

CP="$1"
shift

ECHO="$1"
shift

TOUCH="$1"
shift

MSG="$1"
shift

SRC="$1"
shift

DEST="$1"
shift

if ! $CMP "$SRC" "$DEST" 2> /dev/null ; then
    if [ "$MSG" ] ; then $ECHO "$MSG" > '/dev/stderr' ; fi
    $TOUCH "$SRC"
    $CP "$SRC" "$DEST"
fi
