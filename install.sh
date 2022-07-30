#!/bin/bash
# -*- c-basic-offset: 4; indent-tabs-mode: nil -*-

#  Jardeps - per-tree Java dependencies in Make
#  Copyright (c) 2007-16,2018-19,2021-22, Lancaster University

#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

JARDEPS_OUTDIR="$1"
shift

jar="$1"
shift

release="$1"
shift

DIR="$1"
shift

# The rest is the install command.


## Strip off Git description.
if [[ "$release" =~ ^(.*)-[0-9]+-g[0-9a-f]+$ ]] ; then
    release="${BASH_REMATCH[1]}"
fi



function apply () {
    "$@"
    local rc=$?
    if [ $rc -ne 0 ] ; then exit $rc ; fi
}

# The destination directory must exist in all cases.
apply "$@" -d "$DIR"

if [ -z "$release" ] ; then
    # If no release is specified, ensure the old archives are
    # replaced.
    printf 'Installing jar %s (unversioned)\n  In %s\n' "$jar" "$DIR"
    apply "$@" -m 644 "$JARDEPS_OUTDIR/$jar.jar" "$DIR"
    apply "$@" -m 644 "$JARDEPS_OUTDIR/$jar-src.zip" "$DIR"
    if [ -r "$JARDEPS_OUTDIR/$jar-carp.zip" ] ; then
        apply "$@" -m 644 "$JARDEPS_OUTDIR/$jar-carp.zip" "$DIR"
    fi
    exit
fi

# A release has been provided, so install the archives with the
# release number.
printf 'Installing jar %s-%s\n  In %s\n' "$jar" "$release" "$DIR"
apply "$@" -m 644 "$JARDEPS_OUTDIR/$jar.jar" \
    "$DIR/$jar-$release.jar"
apply "$@" -m 644 "$JARDEPS_OUTDIR/$jar-src.zip" \
      "$DIR/$jar-src-$release.zip"
if [ -r "$JARDEPS_OUTDIR/$jar-carp.zip" ] ; then
    apply "$@" -m 644 "$JARDEPS_OUTDIR/$jar-carp.zip" \
          "$DIR/$jar-src-$release.zip"
fi



function cmp_subvers () {
    local lh="$1" ; shift
    local rh="$1" ; shift
    local lhh rhh exp

    ## Strip off identical components.
    exp='n'
    while
        case "$exp" in
            (n)
                ## Expect numerics.
                [[ "$lh" =~ ^([0-9]*)(.*)$ ]]
                lhh="${BASH_REMATCH[1]}"
                lh="${BASH_REMATCH[2]}"
                [[ "$rh" =~ ^([0-9]*)(.*)$ ]]
                rhh="${BASH_REMATCH[1]}"
                rh="${BASH_REMATCH[2]}"
                exp='t'

                test "${lhh:-0}" -eq "${rhh:-0}"
                ;;

            (t)
                ## Expect text.
                [[ "$lh" =~ ^([^0-9]*)(.*)$ ]]
                lhh="${BASH_REMATCH[1]}"
                lh="${BASH_REMATCH[2]}"
                [[ "$rh" =~ ^([^0-9]*)(.*)$ ]]
                rhh="${BASH_REMATCH[1]}"
                rh="${BASH_REMATCH[2]}"
                exp='n'

                test -n "$lhh" -a "$lhh" = "$rhh"
                ;;
        esac
    do true ; done

    case "$exp" in
        (t)
            if [ "${rhh:-0}" -gt "${lhh:-0}" ] ; then
                return 1
            elif [ "${rhh:-0}" -lt "${lhh:-0}" ] ; then
                return 2
            else
                return 0
            fi
            ;;
        (n)
            if [ "$rhh" \> "$lhh" ] ; then
                test -z "$lhh" && return 2
                return 1
            elif [ "$rhh" \< "$lhh" ] ; then
                test -z "$rhh" && return 1
                return 2
            else
                return 0
            fi
            ;;
    esac
}

function cmp_vers () {
    local left="${1,,}" ; shift
    local right="${1,,}" ; shift
    local lh rh rc

    while
        ## Extract the heads.
        lh="${left%%.*}"
        rh="${right%%.*}"
        test -n "$lh" -a -n "$rh"
    do
        ## Remove heads so we're left with the tails.
        left="${left#"$lh"}"
        left="${left#.}"
        right="${right#"$rh"}"
        right="${right#.}"

        cmp_subvers "$lh" "$rh"
        rc=$?
        test $rc -eq 0 && continue
        test $rc -lt 2
        return $?
    done

    cmp_subvers "$lh" "$rh"
    rc=$?
    test $rc -lt 2
}


# Now check to see if we should replace the unversioned archives.

altrelease="$release"
while true ; do
    lastrelease="$altrelease"
    altrelease="${altrelease%.*}"
    if [ "$altrelease" = "$lastrelease" ] ; then break; fi

    phys=$(readlink -f "$DIR/$jar-$altrelease.jar")
    phys="${phys%.jar}"
    phys="${phys#$DIR/}"
    phys="${phys#$jar-}"

    if [ ! -r "$phys" ] || [ "$phys" = "$jar" ] ||
           cmp_vers "$phys" "$release" ; then
        printf '  Symlinked as %s-%s\n' "$jar" "$altrelease"
        ln -sf "$jar-$release.jar" "$DIR/$jar-$altrelease.jar"
        ln -sf "$jar-src-$release.zip" "$DIR/$jar-src-$altrelease.zip"
        if [ -r "$jar-carp-$release.zip" ] ; then
            ln -sf "$jar-carp-$release.zip" "$DIR/$jar-carp-$altrelease.zip"
        fi
    else
        printf '  Current %s-%s is %s-%s\n' \
            "$jar" "$altrelease" "$jar" "$phys"
    fi
done

phys=$(readlink -f "$DIR/$jar.jar")
phys="${phys%.jar}"
phys="${phys#$DIR/}"
phys="${phys#$jar-}"

if [ ! -r "$phys" ] || [ "$phys" = "$jar" ] ||
       cmp_vers "$phys" "$release" ; then
    printf '  Symlinked as %s\n' "$jar"
    ln -sf "$jar-$release.jar" "$DIR/$jar.jar"
    ln -sf "$jar-src-$release.zip" "$DIR/$jar-src.zip"
    if [ -r "$jar-carp-$release.zip" ] ; then
        ln -sf "$jar-carp-$release.zip" "$DIR/$jar-carp.zip"
    fi
else
    printf '  Current %s-%s is %s-%s\n' "$jar" "$altrelease" "$jar" "$phys"
fi
