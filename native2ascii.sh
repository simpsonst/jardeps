#!/bin/bash
# -*- c-basic-offset: 4; indent-tabs-mode: nil -*-

JAVA="$1"
shift

CLASSPATH="$1"
shift

## This is a script to replace native2ascii in Java 9.
unset enc
unset input
unset output
unset reverse
jargs=()

while [ $# -gt 0 ] ; do
    case "$1" in
        -reverse)
            reverse=true
            ;;

        -J*)
            jargs+=("${1:2}")
            true
            ;;

        -encoding)
            shift
            enc="$1"
            ;;

        *)
            if [ -z "$input" ] ; then
                input="$1"
            elif [ -z "$output" ] ; then
                output="$1"
            else
                printf >&2 '%s: too many arguments: %s\n' "$0" "$1"
                exit 1
            fi
            ;;
    esac
    shift
done

exec ${JAVA} "${jargs[@]}" -cp "$CLASSPATH" Native2Ascii native2ascii \
     ${enc:+-encoding "$enc"} ${reverse:+-reverse} \
     ${input:+"$input"} ${output:+"$output"}
