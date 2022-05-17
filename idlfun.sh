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

while [ $# -gt 0 ]
do
    arg="$1" ; shift
    case "$arg" in
	(--array)
	    vn="$1" ; shift
	    vc="$1" ; shift
	    while [ "$vc" -gt 0 ]
	    do
		eval "$vn"'+=("$1")'
		shift
		vc=$((vc-1))
	    done
	    ;;

	(--out)
	    OUTFILE="$(realpath -mP "$1")"
	    shift
	    ;;

	(--td)
	    TDFILE="$(realpath -mP "$1")"
	    shift
	    ;;

	(--dir)
	    DIR="$1"
	    shift
	    ;;

	(*)
	    idls+="$arg"
	    ;;
    esac
done

if [ "${#idls[@]}" -eq 0 ] ; then exit ; fi

"${CD[@]}" "$DIR" || exit 1
for i in "${idls}" ; do
    "${PRINTF[@]}" >&2 '[JARDEPS] Compiling IDL %s\n' '$i'
    {
	"${IDLJ[@]}" "${APPLIED_IDLJFLAGS[@]}" \
		     -v -td "$TDFILE" "$i.idl" || exit 1
    } |	"${TEE[@]}" -a "$OUTFILE"
done


#	@$(if $(idls_$*),$(CD) $(JARDEPS_IDLDIR) $(foreach i,$(idls_$*),; $(PRINTF) '[JARDEPS] Compiling IDL %s\n' '$i' > /dev/stderr ; $(IDLJ) $(APPLIED_IDLJFLAGS_$*) $(APPLIED_IDLPATH_$*:%=-i %) $(foreach p,$(IDLPFXS),$(idlpkg_$p:%=-pkgTranslate $p %) $(idlpfx_$p:%=-pkgPrefix $p %)) -v -td $(abspath $(JARDEPS_TMPDIR)/idl/$*) $i.idl | $(TEE) -a $(abspath "$(JARDEPS_TMPDIR)/tree-$*.idlout")))
