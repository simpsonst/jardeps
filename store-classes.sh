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

## This script expects the following arguments: DEST PREFIX
## classids... -- outputs...
##
## Output is written to $DEST.  A classid is of the form
## org/example/Foo (for class org.example.Foo, for example).  Each is
## written to $DEST with .class appended, on a line of its own.  Each
## output has $PREFIX removed from its head, before writing it out on
## a line of its own.

DEST="$1"
shift

PREFIX="$1"
shift

{
    while [ $# -gt 0 ] ; do
        if [ "$1" = "--" ] ; then
            shift
            break
        fi
        printf '%s.class\n' "$1"
        shift
    done

    while [ $# -gt 0 ] ; do
        arg="$1"
        shift
        sfx="${arg#"${PREFIX}"}"
        if [ "$sfx" = "$arg" ] ; then continue ; fi
        printf '%s\n' "$sfx"
    done
} > "$DEST"
