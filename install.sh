#!/bin/bash

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



function less_than () {
    local left="$1"
    local right="$2"

    left="$(echo "$left" | \
	sed -e 's/\([0-9]\)\([^0-9]\)/\1.\2/g' \
	-e 's/\([^0-9]\)\([0-9]\)/\1.\2/g')"

    right="$(echo "$right" | \
	sed -e 's/\([0-9]\)\([^0-9]\)/\1.\2/g' \
	-e 's/\([^0-9]\)\([0-9]\)/\1.\2/g')"

    if [ "$left" == "$1" -a "$right" == "$2" ] ; then
	# We're dealing with atoms, so do the direct comparison.
	if [[ "$left" =~ ^-?[0-9]+$ ]] ; then
	    if [[ "$right" =~ ^-?[0-9]+$ ]] ; then
		# Numeric comparison is possible.
		if [ "$1" -lt "$2" ] ; then
		    return 0
		else
		    return 1
		fi
	    else
	        # The name (right) is always less than the number
	        # (left).
		return 1
	    fi
	else
	    if [[ "$right" =~ ^-?[0-9]+$ ]] ; then
	        # The name (left) is always less than the number
	        # (right).
		return 0
	    else
	        # Do alphabetic comparison.
		if [ "$left" \< "$right" ] ; then
		    return 0
		else
		    return 1
		fi
	    fi
	fi
    else
	if [ "$left" == "$1" ] ; then left="$left.0" ; fi
	if [ "$right" == "$1" ] ; then left="$right.0" ; fi
	# At least one operand is compound, so apply the more complex
	# comparison.
	if cmp_vers "$left" "$right" ; then
	    return 0
	else
	    return 1
	fi
    fi


#    if [ "$1" -lt "$2" ] ; then
#	return 0
#    fi
#    return 1
}

# Return 0 (true) if the second version number is at least as recent
# as the first.  $1 <= $2  or $2 >= $1
function cmp_vers () {
    local v1="$1" ; shift
    local v2="$1" ; shift
    local nv1
    local nv2

    while true ; do
	# Remove and store suffixes.
	nv1="${v1#*.}"
	if [ "$nv1" == "$v1" ] ; then
	    unset nv1
	else
	    v1="${v1%%.*}"
	fi
	nv2="${v2#*.}"
	if [ "$nv2" == "$v2" ] ; then
	    unset nv2
	else
	    v2="${v2%%.*}"
	fi

	# Check number at this level to see if it fails the
	# requirement.
	less_than "$v2" "$v1" && return 1
	less_than "$v1" "$v2" && return 0

	# The numbers must be identical here.

	# If there is no further requirement, we have a match.
	[ -z "$nv1" ] && return 0

	# If there is nothing more available, we have a failure.
	[ -z "$nv2" ] && return 1

	# Move on to next segments.
	v1="$nv1"
	v2="$nv2"
    done
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

    if [ "$phys" = "$jar" ] || cmp_vers "$phys" "$release" ; then
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

if [ "$phys" = "$jar" ] || cmp_vers "$phys" "$release" ; then
    printf '  Symlinked as %s\n' "$jar"
    ln -sf "$jar-$release.jar" "$DIR/$jar.jar"
    ln -sf "$jar-src-$release.zip" "$DIR/$jar-src.zip"
    if [ -r "$jar-carp-$release.zip" ] ; then
	ln -sf "$jar-carp-$release.zip" "$DIR/$jar-carp.zip"
    fi
else
    printf '  Current %s-%s is %s-%s\n' "$jar" "$altrelease" "$jar" "$phys"
fi
