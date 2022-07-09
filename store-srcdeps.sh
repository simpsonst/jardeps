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

DEST="$1"
shift

PREFIX="$1"
shift

TREE="$1"
shift

( while [ $# -gt 0 ] ; do
        if [ -r "${PREFIX}$1.java" ] ; then
            printf 'srclist-%s += %s.java\n' "$TREE" "$1"
        fi
        shift
        done
) > "$DEST"
