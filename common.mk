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

## Remove a whole directory tree.
RMTREE ?= $(RM) -r

## Sort, and drop duplicate lines.
SORTU ?= $(SORT) -u

## Some basic Unixy commands
CAT ?= cat
SORT ?= sort
GREP ?= grep
TOUCH ?= touch
PRINTF ?= printf
FIND ?= find
CMP ?= cmp -s
CD ?= cd
CP ?= cp
MV ?= mv
ECHO ?= echo
BLANK ?= echo
TEST ?= test
TEE ?= tee
AWK ?= awk
TRUE ?= true

## Ensure a directory hierarchy exists.
MKDIR ?= mkdir -p

## Remove an empty directory.
RMDIR ?= rmdir

## Java-related commands
JAR ?= jar
JAVA ?= java
JAVAC ?= javac
IDLJ ?= idlj
JAVAC_JAVA ?= $(JAVA) -client
NATIVE2ASCII ?= $(JARDEPS_LIB)/native2ascii.sh "$(JAVA)" "$(JARDEPS_CLASSPATH)"

## These commands are only used to extract a root-class list from the
## Eclipse .classpath file, which is not a mature feature.  cut is
## currently only used to compute the names of source files in a tree,
## and is probably broken as it assumes a containing directory called
## 'src'.  find -printf "$tree"'/%P\n' might be more effective here.
CUT ?= cut
TR ?= tr
XSLTPROC ?= xsltproc
XARGS ?= xargs

DEFAULT_LANGUAGE ?= en
DEFAULT_CHARSET ?= UTF-8

JARDEPS_OUTDIR ?= out
JARDEPS_TMPDIR ?= tmp
JARDEPS_SRCDIR ?= src
JARDEPS_IDLDIR ?= idl
JARDEPS_DEPDIR ?= $(JARDEPS_SRCDIR)
JARDEPS_JDEPDIR ?= $(JARDEPS_DEPDIR)
JARDEPS_CLASSDIR ?= classes
JARDEPS_MERGEDIR ?= merge
JARDEPS_JNIDIR ?= $(JARDEPS_TMPDIR)/obj

## grep exits with failure if it fails to find a matching line, but
## sometimes we don't care whether it finds one or not, only if it
## fails for other reasons.  This wrapper script masks exit code 1 as
## 0 to prevent Make from aborting.
safegrep=$(JARDEPS_LIB)/foldrc.sh 1 0 -- $(GREP)

## This command takes a string as a message, a source filename and a
## destination filename.  It quietly compares their contents, and if
## different, prints the message (and a newline, if not empty), and
## copies the source to the destination.  Otherwise, it does nothing.
cmpcp=$(JARDEPS_LIB)/cmpcp.sh '$(CMP)' '$(CP)' '$(ECHO)' '$(TOUCH)'

## This command takes three fixed arguments followed by an optional
## list.  It prints each item in the list, using the printf-like
## format string given by the second argument.  It also prints the
## first argument before any output, and the last after all output,
## but only if the list is not empty.  TODO: Create a version not
## requiring printf, only echo.
report=$(JARDEPS_LIB)/report.sh '$(PRINTF)'

## This command takes a prefix and a list.  If the list is not empty,
## it prints the prefix, then prints the list items separated by
## commas.  Otherwise it prints nothing.  TODO: Use echo instead of
## printf.
commaline=$(JARDEPS_LIB)/commaline.sh '$(PRINTF)'

jardeps_comma := ,
jardeps_blank :=
jardeps_space := $(jardeps_blank) $(jardeps_blank)

## Escape spaces in the current directory.  TODO: Should we escape
## backslash too?
JARDEPS_CURDIR:=$(subst $(jardeps_space),\$(jardeps_space),$(CURDIR)/)

## Provide a version of $(abspath) that can cope with spaces in the
## current directory.
JARDEPS_ABSPATH=$(foreach f,$1,$(if $(patsubst /%,,$f),$(JARDEPS_CURDIR)$f,$f))

inferred_jars=$(sort $(jars) \
$(patsubst trees_%,%,$(filter trees_%,$(.VARIABLES))) \
$(patsubst version_%,%,$(filter version_%,$(.VARIABLES))) \
$(foreach V,$(filter jdeps_%,$(.VARIABLES)) \
$(filter jppdeps_%,$(.VARIABLES)) \
$(filter jrtdeps_%,$(.VARIABLES)) \
$(filter japdeps_%,$(.VARIABLES)),$($V)))

trees=$(sort $(foreach jar,$(inferred_jars),$(trees_$(jar))))

## Deprecated
ALL_TREES=$(trees)


idl_trees=$(sort $(patsubst idls_%,%,$(filter idls_%,$(.VARIABLES))))
idl_modules=$(sort $(patsubst idlpkg_%,%,$(filter idlpkg_%,$(.VARIABLES))))
idl_prefixes=$(sort $(patsubst idlpfx_%,%,$(filter idlpfx_%,$(.VARIABLES))))


dlplist_src=$(foreach pack,$(dlps_$1),$(wildcard $(JARDEPS_SRCDIR)/$1/$(subst .,/,$(pack))*.properties))
dlplist_dst=$(patsubst $(JARDEPS_SRCDIR)/$1/%,$(JARDEPS_CLASSDIR)/$1/%,$(call dlplist_src,$1))


## $1 is the tree.  $2 is the package.  $3 is a space-separated list
## of leafnames.
jardeps_files=$(foreach i,$3,$(JARDEPS_CLASSDIR)/$1/$(subst .,/,$2)/$i)

blank::
	@$(RM) jardeps-install.sh
	@$(RM) jardeps-install.mk

jardeps-install.sh: $(JARDEPS_LIB)/install.sh
	@$(CP) "$<" "$@"

jardeps-install.mk: jardeps-install.sh \
	$(JARDEPS_LIB)/common.mk $(JARDEPS_LIB)/install.mk
	@$(CP) "$(JARDEPS_LIB)/install.mk" "$@"


## defs4* macros should only contain macro definitions.  deps4* macros
## should only contain rules and recipes.

## These definitions are made for each tree in each jar.  $1 is the
## jar; $2 is the tree.
define defs4tree4jar_template
## Infer the reverse relationship between a tree and a jar.
unsortedjars_$2 += $1

endef

## These definitions are made for each jar, $1.
define defs4jar_template
trees_$1 ?= $1
sortedtrees_$1=$$(sort $$(trees_$1))
jarmerge_$1=$$(sort $$(foreach tree,$$(trees_$1),$$(merge_$$(tree))))
jardep_$1=$$(sort $$(foreach t,$$(trees_$1),$$(jdeps_$$t)) $$(foreach tt,$$(sort $$(foreach t,$$(trees_$1),$$(deps_$$t))),$$(unsortedjars_$$(tt))))
jarcarp_$1=$$(sort $$(foreach tree,$$(trees_$1),$$(carp_$$(tree):%=$$(tree)/%)))

endef

## These definitions are made for each tree, $1.
define defs4tree_template
INTERNAL_CLASSPATH_$1 += $$(jdeps_$1:%=$$(JARDEPS_OUTDIR)/%.jar)
INTERNAL_CLASSPATH_$1 += $$(jppdeps_$1:%=$$(JARDEPS_OUTDIR)/%.jar)
INTERNAL_CLASSPATH_$1 += $$(deps_$1:%=$$(JARDEPS_CLASSDIR)/%)
INTERNAL_CLASSPATH_$1 += $$(ppdeps_$1:%=$$(JARDEPS_CLASSDIR)/%)
INTERNAL_PROCPATH_$1 += $$(japdeps_$1:%=$$(JARDEPS_OUTDIR)/%.jar)
INTERNAL_PROCPATH_$1 += $$(apdeps_$1:%=$$(JARDEPS_CLASSDIR)/%)
jrtdeps_$1 += $$(japdeps_$1)
rtdeps_$1 += $$(apdeps_$1)
merge_$1 += $$(services_$1:%=META-INF/services/%)
jars_$1=$$(sort $$(unsortedjars_$1))

statics_$1 += $$(foreach p,$$(patsubst files_$1/%,%,$$(filter files_$1/%,$$(.VARIABLES))),$$(foreach f,$$(files_$1/$$p),$$(subst .,/,$$p)/$$f))

carpfound_$1=$$(filter-out $$(carpexroots_$1),$$(subst /,.,$$(patsubst $$(JARDEPS_SRCDIR)/$1/%/carp.rpc,%,$$(shell $$(FIND) $$(JARDEPS_SRCDIR)/$1 -mindepth 1 -type f -name "carp.rpc"))))

carp_$1 ?= $$(carpfound_$1)

found_$1=$$(filter-out $$(exroots_$1),$$(subst /,.,$$(patsubst $$(JARDEPS_SRCDIR)/$1/%.java,%,$$(shell $$(FIND) $$(JARDEPS_SRCDIR)/$1 -name "*.java" | $$(safegrep) -Fv -e 'module-info'))))

eclipse_exroots_$1=$$(subst /,.,$$(patsubst %.java,%,$$(shell \
$$(XSLTPROC) --stringparam ROOT '$$(JARDEPS_SRCDIR)/$1' \
$$(JARDEPS_LIB)/extract-exclusions.xsl .classpath | \
$$(TR) '|' '\n')))

## For paths, we put the most specific first, e.g., CLASSPATH_foo,
## PROJECT_CLASSPATH, then CLASSPATH.  APPLIED_*PATH_$1 is passed to
## the compiler.  SHOWN_*PATH_$1 is displayed in the summary. Changes
## to DEPENDENCY_*PATH_$1 trigger recompilation of tree $1.

APPLIED_CLASSPATH_$1 += $$(CLASSPATH_$1)
DEPENDENCY_CLASSPATH_$1 += $$(PROJECT_CLASSPATH_$1)
DEPENDENCY_CLASSPATH_$1 += $$(INTERNAL_CLASSPATH_$1)
DEPENDENCY_CLASSPATH_$1 += $$(PROJECT_CLASSPATH)
APPLIED_CLASSPATH_$1 += $$(DEPENDENCY_CLASSPATH_$1)
APPLIED_CLASSPATH_$1 += $$(CLASSPATH)
SHOWN_CLASSPATH_$1 += $$(CLASSPATH_$1)
SHOWN_CLASSPATH_$1 += $$(PROJECT_CLASSPATH_$1)
SHOWN_CLASSPATH_$1 += $$(PROJECT_CLASSPATH)
SHOWN_CLASSPATH_$1 += $$(CLASSPATH)


APPLIED_PROCPATH_$1 += $$(PROCPATH_$1)
DEPENDENCY_PROCPATH_$1 += $$(PROJECT_PROCPATH_$1)
DEPENDENCY_PROCPATH_$1 += $$(INTERNAL_PROCPATH_$1)
DEPENDENCY_PROCPATH_$1 += $$(PROJECT_PROCPATH)
APPLIED_PROCPATH_$1 += $$(DEPENDENCY_PROCPATH_$1)
APPLIED_PROCPATH_$1 += $$(PROCPATH)
SHOWN_PROCPATH_$1 += $$(PROCPATH_$1)
SHOWN_PROCPATH_$1 += $$(PROJECT_PROCPATH_$1)
SHOWN_PROCPATH_$1 += $$(PROJECT_PROCPATH)
SHOWN_PROCPATH_$1 += $$(PROCPATH)

DEPENDENCY_IDLPATH_$1 += $$(IDLPATH_$1)
DEPENDENCY_IDLPATH_$1 += $$(PROJECT_IDLPATH)
APPLIED_IDLPATH_$1 += $$(DEPENDENCY_IDLPATH_$1)
APPLIED_IDLPATH_$1 += $$(IDLPATH)

## For flags, we put the most specific last, e.g., JAVACFLAGS,
## PROJECT_JAVACFLAGS, JAVACFLAGS_foo.
DEPENDENCY_JAVACFLAGS_$1 += $$(PROJECT_JAVACFLAGS)
DEPENDENCY_JAVACFLAGS_$1 += $$(JAVACFLAGS_$1)
APPLIED_JAVACFLAGS_$1 += $$(JAVACFLAGS)
APPLIED_JAVACFLAGS_$1 += $$(DEPENDENCY_JAVACFLAGS_$1)

DEPENDENCY_IDLJFLAGS_$1 += $$(PROJECT_IDLJFLAGS)
DEPENDENCY_IDLJFLAGS_$1 += $$(IDLJFLAGS_$1)
APPLIED_IDLJFLAGS_$1 += $$(IDLJFLAGS)
APPLIED_IDLJFLAGS_$1 += $$(DEPENDENCY_IDLJFLAGS_$1)

treetargets_$1 += $$(JARDEPS_TMPDIR)/tree-$1.statics
treetargets_$1 += $$(JARDEPS_TMPDIR)/tree-$1.compiled
treetargets_$1 += $$(JARDEPS_TMPDIR)/tree-$1.lang
treetargets_$1 += $$(JARDEPS_TMPDIR)/tree-$1.merged
endef


define deps4tree_template
compile-tree-$1: $$(JARDEPS_TMPDIR)/tree-$1.compiled
lang-tree-$1: $$(JARDEPS_TMPDIR)/tree-$1.lang
statics-tree-$1: $$(JARDEPS_TMPDIR)/tree-$1.statics
merge-tree-$1: $$(JARDEPS_TMPDIR)/tree-$1.merged
tree-$1: compile-tree-$1 lang-tree-$1 statics-tree-$1 merge-tree-$1

.PHONY: compile-tree-$1 lang-tree-$1 statics-tree-$1 merge-tree-$1 tree-$1

## Creating a full merge list for a single tree depends on having
## compiled (and therefore annotation-processed) the tree, and having
## generated the static list.
$$(JARDEPS_TMPDIR)/tree-$1.full-merge-list: \
$$(JARDEPS_TMPDIR)/tree-$1.compiled \
$$(JARDEPS_TMPDIR)/tree-$1.merge-list

## Merging the static and dynamic parts of a tree depends on the full
## list of files to be determined, and on the static files themselves.
$$(JARDEPS_TMPDIR)/tree-$1.merged: \
$$(JARDEPS_TMPDIR)/tree-$1.full-merge-list \
$$(merge_$1:%=$$(JARDEPS_MERGEDIR)/$1/%)

## We must recompile if some trees'/jars' APIs have changed, or if
## some trees'/jars' implementations have changed, or if any of our
## source files have changed, or if the list of root classes has
## changed.
$$(JARDEPS_TMPDIR)/tree-$1.compiled: \
$$(sort $$(deps_$1:%=$$(JARDEPS_TMPDIR)/tree-%.api) \
      $$(ppdeps_$1:%=$$(JARDEPS_TMPDIR)/tree-%.api)) \
$$(ppdeps_$1:%=$$(JARDEPS_TMPDIR)/tree-%.ppi) \
$$(sort $$(jdeps_$1:%=$$(JARDEPS_TMPDIR)/jar-%.api) \
      $$(jppdeps_$1:%=$$(JARDEPS_TMPDIR)/jar-%.api)) \
$$(jppdeps_$1:%=$$(JARDEPS_TMPDIR)/jar-%.ppi) \
$$(foreach t,$$(rtdeps_$1),$$(treetargets_$t)) \
$$(jrtdeps_$1:%=$$(JARDEPS_OUTDIR)/%.jar) \
$$(srclist-$1:%=$$(JARDEPS_SRCDIR)/$1/%) \
$$(JARDEPS_TMPDIR)/tree-$1.root-list \
$$(JARDEPS_TMPDIR)/tree-$1.idl-list \
$$(JARDEPS_TMPDIR)/tree-$1.classpath \
$$(JARDEPS_TMPDIR)/tree-$1.procpath \
$$(JARDEPS_TMPDIR)/tree-$1.flags

## Although this target requires no processing of its own, other than
## being touched, it makes a convenient target for other targets that
## depend on it.
$$(JARDEPS_TMPDIR)/tree-$1.statics: \
  $$(JARDEPS_TMPDIR)/tree-$1.static-list \
  $$(statics_$1:%=$$(JARDEPS_CLASSDIR)/$1/%)

## This rule is only needed for the parallel-build hack, ensuring that
## compilation occurs before these files are compared and optionally
## copied.
$$(JARDEPS_TMPDIR)/tree-$1.provided \
$$(JARDEPS_TMPDIR)/tree-$1.externals \
$$(JARDEPS_TMPDIR)/tree-$1.api \
$$(JARDEPS_TMPDIR)/tree-$1.ppi: | $$(JARDEPS_TMPDIR)/tree-$1.compiled

## Work out which families of properties files are language-dependent.
$$(JARDEPS_TMPDIR)/tree-$1.lang: \
  $$(call dlplist_dst,$1) $$(JARDEPS_TMPDIR)/tree-$1.dlps-list

## Creation of trimmed externals uses the list of external references
## (compilation by-product), and the manual list of excluded imports.
$$(JARDEPS_TMPDIR)/tree-$1.trimmed-externals: \
  $$(JARDEPS_TMPDIR)/tree-$1.externals \
  $$(JARDEPS_TMPDIR)/tree-$1.excluded-imports

## A tree's source zip depends on the files that last went in it, or
## changes to the containing directories.  We also need a blank rule
## to prevent deleted files from breaking the build.
$$(JARDEPS_TMPDIR)/tree-$1.docsrc-list: \
  $$(docsrc-$1:%=$$(JARDEPS_SRCDIR)/$1/%)
$$(docsrc-$1:%=$$(JARDEPS_SRCDIR)/$1/%):

## Properties must be converted to US-ASCII.
$$(JARDEPS_CLASSDIR)/$1/%.properties: $$(JARDEPS_SRCDIR)/$1/%.properties
	@$$(ECHO) '[JARDEPS] $1: $$(DEFAULT_CHARSET) properties $$*' \
	  > /dev/stderr
	@$$(MKDIR) "$$(@D)"
	@$$(TOUCH) '$$(JARDEPS_CLASSDIR)/CACHEDIR.TAG'
	@$$(NATIVE2ASCII) -encoding "$$(DEFAULT_CHARSET)" "$$<" "$$@-tmp"
	@$$(MV) "$$@-tmp" "$$@"

## Unmodified files can be copied straight from the source tree.
$$(JARDEPS_CLASSDIR)/$1/%: $$(JARDEPS_SRCDIR)/$1/%
	@$$(ECHO) '[JARDEPS] $1: Copy: $$*' > /dev/stderr
	@$$(MKDIR) "$$(@D)"
	@$$(TOUCH) '$$(JARDEPS_CLASSDIR)/CACHEDIR.TAG'
	@$$(CP) "$$<" "$$@-tmp"
	@$$(MV) "$$@-tmp" "$$@"
endef


define deps4idltree_template
$$(JARDEPS_TMPDIR)/tree-$1.compiled: \
$$(JARDEPS_TMPDIR)/tree-$1.idl-flags \
$$(JARDEPS_TMPDIR)/tree-$1.idl-path

endef





define deps4jar_template
## Some convenient targets for this jar
statics-jar-$1: $$(foreach t,$$(trees_$1),statics-tree-$$t)
merge-jar-$1: $$(JARDEPS_TMPDIR)/jar-$1.merged
manifest-jar-$1: $$(JARDEPS_TMPDIR)/jar-$1.manifest
source-jar-$1: $$(JARDEPS_OUTDIR)/$1-src.zip
jar-$1: $$(JARDEPS_OUTDIR)/$1.jar
jarsummary-$1: topjarsummary-$1 $$(trees_$1:%=treesummary-%)

clean-jar-$1:: $$(foreach t,$$(trees_$1),clean-tree-$$t)

carp-$1: $$(JARDEPS_OUTDIR)/$1-carp.zip

$$(JARDEPS_OUTDIR)/$1-carp.zip: $$(foreach tree,$$(trees_$1),$$(foreach mod,$$(carp_$$(tree)),$$(JARDEPS_SRCDIR)/$$(tree)/$$(subst .,/,$$(mod))/carp.rpc))

## Merging several trees' files for a single jar depends on working
## out the union of all trees' merge lists, and on already having
## merged explicit files with generated files.
$$(JARDEPS_TMPDIR)/jar-$1.merged: \
  $$(JARDEPS_TMPDIR)/jar-$1.merge-list \
  $$(foreach t,$$(trees_$1),$$(JARDEPS_TMPDIR)/tree-$$t.merged)

## Creating the list of all merged files in a jar depends on having
## the corresponding lists for the component trees, the union of
## them can be computed.
$$(JARDEPS_TMPDIR)/jar-$1.merge-list: \
  $$(foreach t,$$(trees_$1),$$(JARDEPS_TMPDIR)/tree-$$t.full-merge-list)

## Creating the list of all generated classes for a jar depends on
## having all the component trees' lists to catenate.
$$(JARDEPS_TMPDIR)/jar-$1.list: \
  $$(foreach t,$$(trees_$1),$$(JARDEPS_TMPDIR)/tree-$$t.list)

## Creating the list of all statics for a jar depends on having all
## the component trees' lists to catenate.
$$(JARDEPS_TMPDIR)/jar-$1.static-list: \
  $$(foreach t,$$(trees_$1),$$(JARDEPS_TMPDIR)/tree-$$t.static-list)

## Assembly of a jar depends on all component trees having been
## compiled, their statics copied, their language packs processed, and
## their APIs/PPIs being ready.  
$$(JARDEPS_OUTDIR)/$1.jar: \
  $$(JARDEPS_TMPDIR)/jar-$1.tree-list \
  $$(foreach t,$$(trees_$1),$$(JARDEPS_TMPDIR)/tree-$$t.compiled) \
  $$(foreach t,$$(trees_$1),$$(JARDEPS_TMPDIR)/tree-$$t.lang) \
  $$(foreach t,$$(trees_$1),$$(JARDEPS_TMPDIR)/tree-$$t.statics) \
  $$(JARDEPS_TMPDIR)/jar-$1.manifest \
  $$(JARDEPS_TMPDIR)/jar-$1.merged

## This rule is only needed for the parallel-build hack.
$$(JARDEPS_TMPDIR)/jar-$1.api $$(JARDEPS_TMPDIR)/jar-$1.ppi: | \
  $$(JARDEPS_OUTDIR)/$1.jar

## Our imports change if the trees' explicit imports, provided
## packages or external references change.
$$(JARDEPS_TMPDIR)/jar-$1.imports: \
  $$(JARDEPS_TMPDIR)/jar-$1.provided \
  $$(JARDEPS_TMPDIR)/jar-$1.excluded-imports \
  $$(foreach t,$$(trees_$1), \
               $$(JARDEPS_TMPDIR)/tree-$$t.imports \
               $$(JARDEPS_TMPDIR)/tree-$$t.trimmed-externals)

## To determine the set of packages provided by a jar, we use the
## union of the sets of packages provided by its trees.
$$(JARDEPS_TMPDIR)/jar-$1.provided: \
   $$(foreach t,$$(trees_$1),$$(JARDEPS_TMPDIR)/tree-$$t.provided)

## The jar's exported packages are built up from its trees' exports.
$$(JARDEPS_TMPDIR)/jar-$1.exports: \
  $$(foreach t,$$(trees_$1),$$(JARDEPS_TMPDIR)/tree-$$t.exports)

## The jar's manifest depends on all sorts.
$$(JARDEPS_TMPDIR)/jar-$1.manifest: \
  $$(JARDEPS_TMPDIR)/jar-$1.manual-manifest \
  $$(JARDEPS_TMPDIR)/jar-$1.deps \
  $$(JARDEPS_TMPDIR)/jar-$1.imports \
  $$(JARDEPS_TMPDIR)/jar-$1.exports \
  $$(foreach t,$$(trees_$1),$$(JARDEPS_TMPDIR)/tree-$$t.manual-manifest) \
  $$(foreach t,$$(trees_$1),$$(JARDEPS_TMPDIR)/tree-$$t.apt-manifest)

## A zip of the source for a jar depends on the file lists generated
## for each component tree.
$$(JARDEPS_OUTDIR)/$1-src.zip: \
  $$(trees_$1:%=$$(JARDEPS_TMPDIR)/tree-%.docsrc-list)

endef






$(foreach jar,$(inferred_jars),$(eval $(call defs4jar_template,$(jar))))

-include $(call JARDEPS_ABSPATH,$(trees:%=$(JARDEPS_TMPDIR)/tree-%.mk))
-include $(call JARDEPS_ABSPATH,$(trees:%=$(JARDEPS_TMPDIR)/inputs-%.mk))
-include $(call JARDEPS_ABSPATH,$(trees:%=$(JARDEPS_TMPDIR)/tree-%.idl.mk))
-include $(call JARDEPS_ABSPATH,$(trees:%=$(JARDEPS_TMPDIR)/deps-%.mk))
-include $(call JARDEPS_ABSPATH,$(trees:%=$(JARDEPS_TMPDIR)/tree-%.manifest.mk))
-include $(call JARDEPS_ABSPATH,$(trees:%=$(JARDEPS_TMPDIR)/tree-%.docsrc.mk))
-include $(call JARDEPS_ABSPATH,$(inferred_jars:%=$(JARDEPS_TMPDIR)/jar-%.manifest.mk))

$(foreach tree,$(trees),$(eval $(call defs4tree_template,$(tree))))


$(JARDEPS_OUTDIR)/%-carp.zip: $(JARDEPS_TMPDIR)/jar-%.carp
	@$(ECHO) '[JARDEPS] $*-carp.zip: Collecting $(words $(jarcarp_$*)) modules' > /dev/stderr
	@$(report) '' '[JARDEPS]   %s\n' '' $(jarcarp_$*:%='%') > /dev/stderr
	@$(MKDIR) '$(@D)'
	@$(JAR) cfm '$@-tmp' /dev/null $(foreach tree,$(trees_$*),$(foreach mod,$(carp_$(tree)),-C $(JARDEPS_SRCDIR)/$(tree) $(subst .,/,$(mod))/carp.rpc))
	@$(MV) '$@-tmp' '$@'

## These are all potentially non-updating by-products of the preamble.
preamble_byproducts=\
$(trees:%=$(JARDEPS_TMPDIR)/tree-%.root-list) \
$(trees:%=$(JARDEPS_TMPDIR)/tree-%.idl-list) \
$(trees:%=$(JARDEPS_TMPDIR)/tree-%.static-list) \
$(trees:%=$(JARDEPS_TMPDIR)/tree-%.dlps-list) \
$(trees:%=$(JARDEPS_TMPDIR)/tree-%.merge-list) \
$(trees:%=$(JARDEPS_TMPDIR)/tree-%.imports) \
$(trees:%=$(JARDEPS_TMPDIR)/tree-%.exports) \
$(trees:%=$(JARDEPS_TMPDIR)/tree-%.excluded-imports) \
$(trees:%=$(JARDEPS_TMPDIR)/tree-%.classpath) \
$(trees:%=$(JARDEPS_TMPDIR)/tree-%.idl-path) \
$(trees:%=$(JARDEPS_TMPDIR)/tree-%.procpath) \
$(trees:%=$(JARDEPS_TMPDIR)/tree-%.flags) \
$(trees:%=$(JARDEPS_TMPDIR)/tree-%.idl-flags) \
$(inferred_jars:%=$(JARDEPS_TMPDIR)/jar-%.tree-list) \
$(inferred_jars:%=$(JARDEPS_TMPDIR)/jar-%.excluded-imports) \
$(inferred_jars:%=$(JARDEPS_TMPDIR)/jar-%.deps) \
$(inferred_jars:%=$(JARDEPS_TMPDIR)/jar-%.carp) \
$(JARDEPS_TMPDIR)/jar.list \
$(JARDEPS_TMPDIR)/idl.map


$(JARDEPS_TMPDIR)/jar-%.api: $(JARDEPS_OUTDIR)/%.jar
	@$(cmpcp) '[JARDEPS] $*.jar: API changed' \
	  '$(JARDEPS_TMPDIR)/jar-$*.api-tmp' \
	  '$(JARDEPS_TMPDIR)/jar-$*.api'

$(JARDEPS_TMPDIR)/jar-%.ppi: $(JARDEPS_OUTDIR)/%.jar
	@$(cmpcp) '[JARDEPS] $*.jar: PPI changed' \
	  '$(JARDEPS_TMPDIR)/jar-$*.ppi-tmp' \
	  '$(JARDEPS_TMPDIR)/jar-$*.ppi'

$(JARDEPS_TMPDIR)/tree-%.externals: $(JARDEPS_TMPDIR)/tree-%.compiled
	@$(cmpcp) '[JARDEPS] $*: Package use changed' '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/tree-%.provided: $(JARDEPS_TMPDIR)/tree-%.compiled
	@$(cmpcp) '[JARDEPS] $*: Package provision changed' '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/tree-%.api: $(JARDEPS_TMPDIR)/tree-%.compiled
	@$(cmpcp) '[JARDEPS] $*: API changed' '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/tree-%.ppi: $(JARDEPS_TMPDIR)/tree-%.compiled
	@$(cmpcp) '[JARDEPS] $*: PPI changed' '$@-tmp' '$@'


$(foreach tree,$(trees),$(eval $(call deps4tree_template,$(tree))))

$(foreach tree,$(idl_trees),$(eval $(call deps4idltree_template,$(tree))))

$(foreach jar,$(inferred_jars),$(eval $(call deps4jar_template,$(jar))))

$(foreach J,$(inferred_jars),$(foreach T,$(trees_$J),\
$(eval $(call defs4tree4jar_template,$J,$T))))



## Building these targets should not be regarded as activity that
## suppresses a 'Nothing to be done for...' or '... is up-to-date'
## message.  These rules only have an effect when using a version of
## Make patched to recognize the special .IDLE target.
.IDLE: $(trees:%=$(JARDEPS_TMPDIR)/tree-%.provided)
.IDLE: $(trees:%=$(JARDEPS_TMPDIR)/tree-%.externals)
.IDLE: $(trees:%=$(JARDEPS_TMPDIR)/tree-%.api)
.IDLE: $(trees:%=$(JARDEPS_TMPDIR)/tree-%.ppi)
.IDLE: $(inferred_jars:%=$(JARDEPS_TMPDIR)/jar-%.api)
.IDLE: $(inferred_jars:%=$(JARDEPS_TMPDIR)/jar-%.ppi)








## These rules allow us to deal with deleted merge/source files that
## still have rules depending on them.
$(foreach jar,$(inferred_jars),$(foreach tree,$(trees_$(jar)),$(foreach file,$(jarmerge_$(jar)),$(JARDEPS_CLASSDIR)/$(tree)/$(file)))):
$(foreach tree,$(trees),$(srclist-$(tree):%=$(JARDEPS_SRCDIR)/$(tree)/%)):

treesummary-%:
	@$(PRINTF) '\nTree %s:\n' "$*"
	@$(report) '' '       In jar %s\n' '' $(jars_$*)
	@$(report) '' '         Root %s\n' '' $(roots_$*)
	@$(report) '' '      AP Root %s\n' '' $(aroots_$*)
	@$(report) '' '    Lang pack %s\n' '' $(dlps_$*)
	@$(report) '' '       Static %s\n' '' $(statics_$*)
	@$(report) '' '      Service %s\n' '' $(services_$*)
	@$(report) '' '        Merge %s\n' '' $(merge_$*)
	@$(report) '' '       Export %s\n' '' $(exports_$*)
	@$(report) '' '       Import %s\n' '' $(imports_$*)
	@$(report) '' ' Excl. import %s\n' '' $(excluded_imports_$*)
	@$(report) '' ' Tree API dep %s\n' '' $(deps_$*)
	@$(report) '' ' Tree PPI dep %s\n' '' $(ppdeps_$*)
	@$(report) '' '  Tree RT dep %s\n' '' $(rtdeps_$*)
	@$(report) '' '  Tree AP dep %s\n' '' $(apdeps_$*)
	@$(report) '' '  Jar API dep %s\n' '' $(jdeps_$*)
	@$(report) '' '  Jar PPI dep %s\n' '' $(jppdeps_$*)
	@$(report) '' '   Jar RT dep %s\n' '' $(jrtdeps_$*)
	@$(report) '' '   Jar AP dep %s\n' '' $(japdeps_$*)
	@$(report) '' '    Classpath %s\n' '' $(subst :,$(jardeps_space),$(SHOWN_CLASSPATH_$*))
	@$(report) '' '     Procpath %s\n' '' $(subst :,$(jardeps_space),$(SHOWN_PROCPATH_$*))
	@$(PRINTF) '        Flags %s\n' "$(JAVACFLAGS_$*)"

topjarsummary-%:
	@$(PRINTF) '\nJar %s:\n' "$*"
	@$(report) '' '         Tree %s\n' '' $(trees_$*)
	@$(report) '' ' Excl. import %s\n' '' $(jexcluded_imports_$*)

topsummary:
	@$(PRINTF) '\nProject:\n'
	@$(report) '' '          Jar %s\n' '' $(inferred_jars)

summary:: topsummary $(inferred_jars:%=jarsummary-%)

.PHONY: $(trees:%=tree-%)
.PHONY: $(trees:%=compile-tree-%)
.PHONY: $(trees:%=lang-tree-%)
.PHONY: $(trees:%=statics-tree-%)
.PHONY: $(trees:%=merge-tree-%)

.PHONY: $(inferred_jars:%=manifest-%)
.PHONY: $(inferred_jars:%=statics-%)
.PHONY: $(inferred_jars:%=merge-%)
.PHONY: $(inferred_jars:%=source-%)
.PHONY: $(inferred_jars:%=jar-%)


## Determine the list of files that a tree contributes to the source
## zip.  Two lists are created.  source-foo.mk defines a list of
## tree-relative files and directories that should be pre-requisites
## for the next build, and includes all *.java files, anything in a
## doc-files directory, and all directories.  tree-foo.docsrc-list is
## a list of arguments to be passed to jar to create a source zip, and
## excludes directories to avoid duplicates when several trees are
## merged into one zip.
$(JARDEPS_TMPDIR)/tree-%.docsrc-list:
	@$(ECHO) '[JARDEPS] $*: Listing documentation sources' > /dev/stderr
	@$(MKDIR) '$(@D)'
	@$(TOUCH) '$(JARDEPS_TMPDIR)/CACHEDIR.TAG'
	@$(if $(wildcard $(JARDEPS_SRCDIR)/$*),$(FIND) '$(JARDEPS_SRCDIR)/$*' \
	  \( \( -type d -not -path '$(JARDEPS_SRCDIR)/$*' \) \
	     -o -name '*.java' -o -path '*/doc-files/*' \) \
	  -printf 'docsrc-$* += %P\n' \
	  > '$(JARDEPS_TMPDIR)/tree-$*.docsrc.mk-tmp', \
	  $(TOUCH) '$(JARDEPS_TMPDIR)/tree-$*.docsrc.mk-tmp')
	@$(MV) '$(JARDEPS_TMPDIR)/tree-$*.docsrc.mk-tmp' \
	  '$(JARDEPS_TMPDIR)/tree-$*.docsrc.mk'
	@$(if $(wildcard $(JARDEPS_SRCDIR)/$*),$(FIND) '$(JARDEPS_SRCDIR)/$*' \
	  -type f \( -name '*.java' -o -path '*/doc-files/*' \) \
	  -printf '%P\n' > '$@-tmp',$(TOUCH) '$@-tmp')
	@$(MV) '$@-tmp' '$@'

## A jar's source zip is built by combining the generated file lists
## for each component tree, and passing them to jar.
$(JARDEPS_OUTDIR)/%-src.zip:
	@$(ECHO) '[JARDEPS] $*.jar: Creating source documentation' > /dev/stderr
	@$(MKDIR) '$(@D)'
	@$(TOUCH) '$(JARDEPS_OUTDIR)/CACHEDIR.TAG'
	@$(RM) '$@-tmp'
	@$(JAR) cf '$@-tmp' \
	  $(foreach t, $(trees_$*), $(foreach f, $(shell $(CAT) '$(JARDEPS_TMPDIR)/tree-$t.docsrc-list'), -C '$(JARDEPS_SRCDIR)/$t' '$f'))
	@$(MV) '$@-tmp' '$@'
	@$(BLANK)

clean:: $(inferred_jars:%=clean-jar-%)
	@$(ECHO) '[JARDEPS] Removing intermediate Java files' > /dev/stderr
	@$(RMTREE) $(JARDEPS_TMPDIR)
	@$(RMTREE) $(JARDEPS_CLASSDIR)

blank:: clean
	@$(ECHO) '[JARDEPS]: Removing final Java files' > /dev/stderr
	@$(RM) $(inferred_jars:%=$(JARDEPS_OUTDIR)/%.jar)
	@$(RM) $(inferred_jars:%=$(JARDEPS_OUTDIR)/%-src.zip)
	@$(RMTREE) $(JARDEPS_OUTDIR)


$(JARDEPS_OUTDIR)/%.jar:
	@$(ECHO) '[JARDEPS] $*.jar: Creating from $(trees_$*)' > /dev/stderr
	@$(MKDIR) "$(@D)"
	@$(TOUCH) '$(JARDEPS_OUTDIR)/CACHEDIR.TAG'
	@$(CAT) /dev/null $(foreach t,$(trees_$*),$(JARDEPS_TMPDIR)/tree-$t.api-tmp) | $(SORT) > "$(JARDEPS_TMPDIR)/jar-$*.api-tmp"
	@$(CAT) /dev/null $(foreach t,$(trees_$*),$(JARDEPS_TMPDIR)/tree-$t.ppi-tmp) | $(SORT) > "$(JARDEPS_TMPDIR)/jar-$*.ppi-tmp"
	@$(JAR) cfm0 "$@-tmp" "$(JARDEPS_TMPDIR)/jar-$*.manifest" \
	  $(foreach t,$(trees_$*), $(foreach i,$(statics_$t) $(patsubst $(JARDEPS_CLASSDIR)/$t/%,%,$(call dlplist_dst,$t)),-C '$(JARDEPS_CLASSDIR)/$t' '$i')) \
	  $(foreach f,$(jarmerge_$*),-C '$(JARDEPS_TMPDIR)/merge/$*' '$f') \
	  $(foreach t,$(trees_$*),$(foreach i,$(shell $(CAT) "$(JARDEPS_TMPDIR)/tree-$t.list"),-C '$(JARDEPS_CLASSDIR)/$t' '$i')) \
	  $(foreach i,$(shell $(CAT) "$(JARDEPS_TMPDIR)/jar-$*.merge-list"),-C "$(JARDEPS_TMPDIR)/merge/$*" '$i')
	@$(MV) "$@-tmp" "$@"

$(JARDEPS_TMPDIR)/tree-%.statics:
	@$(MKDIR) "$(@D)"
	@$(TOUCH) '$(JARDEPS_TMPDIR)/CACHEDIR.TAG'
	@$(TOUCH) "$@-tmp"
	@$(MV) "$@-tmp" "$@"

$(JARDEPS_TMPDIR)/tree-%.lang:
	@$(ECHO) '[JARDEPS] $*: Transfering defaults' > /dev/stderr
	@$(MKDIR) "$(@D)"
	@$(TOUCH) '$(JARDEPS_TMPDIR)/CACHEDIR.TAG'
	@$(JAVA) -cp $(JARDEPS_CLASSPATH) PropertyDefaulter \
	  $(foreach pack,$(dlps_$*),"$(pack)" \
	    $(JARDEPS_CLASSDIR)/$*/$(subst .,/,$(pack))_$(DEFAULT_LANGUAGE).properties \
	    $(JARDEPS_CLASSDIR)/$*/$(subst .,/,$(pack)).properties)
	@$(TOUCH) "$@-tmp"
	@$(MV) "$@-tmp" "$@"

jardirs_vsfx=$(if $(version_$1),:$(version_$1))

jardeps_ssdocargs += $(foreach jar,$(inferred_jars),-jardirs $(jar).jar$(call jardirs_vsfx,$(jar)) $(subst $(jardeps_space),:,$(foreach t,$(trees_$(jar)),$(JARDEPS_SRCDIR)/$t $(JARDEPS_TMPDIR)/apt/$t)))

show-ssdocargs:
	@$(PRINTF) "\n%s\n" "$(jardeps_ssdocargs)" > /dev/stderr

jardeps_srcdirs4trees=$(foreach t,$1,$(JARDEPS_SRCDIR)/$t $(JARDEPS_TMPDIR)/apt/$t $(JARDEPS_TMPDIR)/idl/$t)
jardeps_srcdirs4jars=$(foreach t,$(sort $(foreach j,$1,$(trees_$j))),$(JARDEPS_SRCDIR)/$t $(JARDEPS_TMPDIR)/apt/$t $(JARDEPS_TMPDIR)/idl/$t)

jardeps_srcpath4trees=$(subst $(jardeps_space),:,$(call jardeps_srcdirs4trees,$1))

jardeps_srcpath4jars=$(subst $(jardeps_space),:,$(call jardeps_srcdirs4jars,$1))

jardeps_srcdirs=$(foreach t,$(trees),$(JARDEPS_SRCDIR)/$t $(JARDEPS_TMPDIR)/apt/$t)

jardeps_srcpath=$(subst $(jardeps_space),:,$(jardeps_srcdirs))

show-srcdirs:
	@$(PRINTF) "\n%s\n" "$(jardeps_srcdirs)" > /dev/stderr
	@$(PRINTF) "\n%s\n" "$(jardeps_srcpath)" > /dev/stderr

## Copy tree-specific rules from one of two locations, or use blank
## rules.
$(JARDEPS_TMPDIR)/deps-%.mk: $(JARDEPS_DEPDIR)/deps-%.mk
	@$(MKDIR) "$(@D)"
	@$(CP) '$<' '$@-tmp'
	@$(MV) '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/deps-%.mk: $(JARDEPS_SRCDIR)/%/deps.mk
	@$(MKDIR) "$(@D)"
	@$(CP) '$<' '$@-tmp'
	@$(MV) '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/deps-%.mk:
	@$(MKDIR) "$(@D)"
	@$(TOUCH) '$@'

## Allow user-specified tree-specific manifest-affecting rules to be
## separate, so that a tree's contribution to its containing jar's
## manifest can be regenerated separately if those rules are changed.
$(JARDEPS_TMPDIR)/tree-%.manifest.mk: $(JARDEPS_DEPDIR)/manifest-%.mk
	@$(MKDIR) "$(@D)"
	@$(TOUCH) '$(JARDEPS_TMPDIR)/CACHEDIR.TAG'
	@$(CP) "$<" "$@-tmp"
	@$(MV) "$@-tmp" "$@"

## If the user specifies no manifest-affecting rules for a tree,
## create a blank set.
$(JARDEPS_TMPDIR)/tree-%.manifest.mk:
	@$(MKDIR) "$(@D)"
	@$(TOUCH) '$(JARDEPS_TMPDIR)/CACHEDIR.TAG'
	@$(TOUCH) "$@"

## Allow user-specified jar-specific manifest-affecting rules to be
## separate, so that contributions to a jar's manifest can be
## regenerated separately if those rules are changed.
$(JARDEPS_TMPDIR)/jar-%.manifest.mk: $(JARDEPS_JDEPDIR)/jmanifest-%.mk
	@$(MKDIR) "$(@D)"
	@$(TOUCH) '$(JARDEPS_TMPDIR)/CACHEDIR.TAG'
	@$(CP) "$<" "$@-tmp"
	@$(MV) "$@-tmp" "$@"

## If the user specifies no manifest-affecting rules for a jar, create
## a blank set.
$(JARDEPS_TMPDIR)/jar-%.manifest.mk:
	@$(MKDIR) "$(@D)"
	@$(TOUCH) '$(JARDEPS_TMPDIR)/CACHEDIR.TAG'
	@$(TOUCH) "$@"





########################################################################
## Merging

## Contributions for merging come from two sources.  First,
## $(merge_TREE) identifies files in $(JARDEPS_MERGEDIR)/TREE that are
## static.  Second, compilation of a source tree can generate files
## under $(JARDEPS_TMPDIR)/aptbin/TREE.

## Merging occurs in two stages.  First, for each tree, a complete
## list of files to merge (from either compilation or static source)
## is created, and files are merged into $(JARDEPS_CLASSDIR)/TREE.
## Second, to prepare for a jar being built, all files from all
## composite trees are merged into the directory
## $(JARDEPS_TMPDIR)/merge, and these will be used to construct the
## jar command.


## Get the full list of files to be merged in a tree.  Some files are
## defined by $(merge_TREE), and some are generated by annotation
## processors.
$(JARDEPS_TMPDIR)/tree-%.full-merge-list:
	@$(ECHO) '[JARDEPS] $*: Creating merge list' > /dev/stderr
	@$(MKDIR) "$(JARDEPS_TMPDIR)/aptbin/$*"
	@$(TOUCH) '$(JARDEPS_TMPDIR)/CACHEDIR.TAG'
	@$(report) '' '%s\n' '' $(merge_$*) > '$@-unsorted'
	@$(FIND) "$(JARDEPS_TMPDIR)/aptbin/$*" -type f -printf '%P\n' \
	  >> '$@-unsorted'
	@$(SORTU) < '$@-unsorted' > "$@-tmp"
	@$(MV) "$@-tmp" "$@"

define tree_merge
$(ECHO) '  $2'
$(RM) '$(JARDEPS_CLASSDIR)/$1/$2'
$(MKDIR) '$(dir $(JARDEPS_CLASSDIR)/$1/$2)'
$(TOUCH) '$(JARDEPS_CLASSDIR)/$1/$2'
$(TOUCH) '$(JARDEPS_CLASSDIR)/CACHEDIR.TAG'
-$(CAT) '$(JARDEPS_MERGEDIR)/$1/$2' >> '$(JARDEPS_CLASSDIR)/$1/$2' 2> /dev/null || $(TRUE)
-$(CAT) '$(JARDEPS_TMPDIR)/aptbin/$1/$2' >> '$(JARDEPS_CLASSDIR)/$1/$2' 2> /dev/null || $(TRUE)

endef

## Merge computed files with static files within a single tree.
$(JARDEPS_TMPDIR)/tree-%.merged:
	@$(ECHO) '[JARDEPS] $*: Merging' > /dev/stderr
	@$(foreach item,$(shell $(CAT) "$(JARDEPS_TMPDIR)/tree-$*.full-merge-list"),$(call tree_merge,$*,$(item)))
	@$(TOUCH) "$@"


## Get the full list of files to be merged in a jar.
$(JARDEPS_TMPDIR)/jar-%.merge-list:
	@$(ECHO) '[JARDEPS] $*.jar: Creating merge list' > /dev/stderr
	@$(CAT) $(foreach tree,$(trees_$*),"$(JARDEPS_TMPDIR)/tree-$(tree).full-merge-list") | $(SORTU) > "$@-tmp"
	@$(MV) "$@-tmp" "$@"

define jar_merge
$(ECHO) '  $2'
$(RM) '$(JARDEPS_TMPDIR)/merge/$1/$2'
$(MKDIR) '$(dir $(JARDEPS_TMPDIR)/merge/$1/$2)'
$(CAT) > '$(JARDEPS_TMPDIR)/merge/$1/$2' 2> /dev/null \
   $(foreach t,$(trees_$1),'$(JARDEPS_CLASSDIR)/$t/$2') || $(TRUE)

endef

## Merge files from several trees contributing to the same jar.
$(JARDEPS_TMPDIR)/jar-%.merged:
	@$(ECHO) '[JARDEPS] $*.jar: Merging' > /dev/stderr
	@$(MKDIR) "$(JARDEPS_TMPDIR)/merge/$*"
	@$(TOUCH) '$(JARDEPS_TMPDIR)/CACHEDIR.TAG'
	@$(foreach i,$(shell $(CAT) "$(JARDEPS_TMPDIR)/jar-$*.merge-list"),$(call jar_merge,$*,$i))
	@$(TOUCH) "$@"






## NOTUSED: Get the full list of generated class files in a jar.
$(JARDEPS_TMPDIR)/jar-%.list:
	@$(ECHO) '[JARDEPS] $*.jar: Creating class list' > /dev/stderr
	@$(CAT) $(foreach t,$(trees_$*),"$(JARDEPS_TMPDIR)/tree-$t.list") | $(SORTU) > "$@-tmp"
	@$(MV) "$@-tmp" "$@"

## NOTUSED: Get the full list of static files in a jar.
$(JARDEPS_TMPDIR)/jar-%.static-list:
	@$(ECHO) '[JARDEPS] $*.jar: Creating static list' > /dev/stderr
	@$(CAT) $(foreach tree,$(trees_$*),"$(JARDEPS_TMPDIR)/tree-$(tree).static-list") | $(SORTU) > "$@-tmp"
	@$(MV) "$@-tmp" "$@"

define show-path
$(ECHO) '  $1: $2'

endef

IDLPFXS=$(sort $(patsubst idlpfx_%,%,$(filter idlpfx_%,$(.VARIABLES))) $(patsubst idlpkg_%,%,$(filter idlpkg_%,$(.VARIABLES))))

IDLPFX_FLAGS=$(foreach p,$(IDLPFXS),$(idlpkg_$p:%=-pkgTranslate $p %) $(idlpfx_$p:%=-pkgPrefix $p %))

## How to compile the source
$(JARDEPS_TMPDIR)/tree-%.compiled:
	@$(ECHO) '[JARDEPS] $*: Compiling with [$(APPLIED_JAVACFLAGS)]' \
	  > /dev/stderr
	@$(MKDIR) "$(JARDEPS_CLASSDIR)/$*" \
	  "$(JARDEPS_TMPDIR)/apt/$*" \
	  "$(JARDEPS_TMPDIR)/idl/$*" \
	  "$(JARDEPS_TMPDIR)/aptbin/$*/META-INF/services"
	@$(TOUCH) '$(JARDEPS_CLASSDIR)/CACHEDIR.TAG'
	@$(TOUCH) '$(JARDEPS_TMPDIR)/CACHEDIR.TAG'
	@$(FIND) "$(JARDEPS_CLASSDIR)/$*" -name "*.class" -delete
	@$(FIND) "$(JARDEPS_TMPDIR)/apt/$*" -name "*.java" -delete
	@$(FIND) "$(JARDEPS_TMPDIR)/idl/$*" -name "*.java" -delete
	@$(RM) "$(JARDEPS_TMPDIR)/tree-$*.idlout"
	@$(foreach i,$(subst :,$(jardeps_space),$(APPLIED_CLASSPATH_$*)),$(call show-path,CP,$i))
	@$(foreach i,$(subst :,$(jardeps_space),$(APPLIED_PROCPATH_$*)),$(call show-path,PP,$i))
	@$(foreach i,$(subst :,$(jardeps_space),$(APPLIED_IDLPATH_$*)),$(call show-path,IP,$i))
	@$(ECHO) '  Cause:' > /dev/stderr
	@$(report) '' '   Class %s\n' '' $(subst /,.,$(patsubst $(JARDEPS_SRCDIR)/$*/%.java,%,$(filter $(JARDEPS_SRCDIR)/$*/%.java,$?))) > /dev/stderr
	@$(report) '   API:' ' %s' '\n' $(subst /,.,$(patsubst $(JARDEPS_TMPDIR)/tree-%.api,%,$(filter $(JARDEPS_TMPDIR)/tree-%.api,$?))) > /dev/stderr
	@$(report) '   PPI:' ' %s' '\n' $(subst /,.,$(patsubst $(JARDEPS_TMPDIR)/tree-%.ppi,%,$(filter $(JARDEPS_TMPDIR)/tree-%.ppi,$?))) > /dev/stderr
	@$(report) '   Jar API:' ' %s' '\n' $(subst /,.,$(patsubst $(JARDEPS_TMPDIR)/jar-%.api,%,$(filter $(JARDEPS_TMPDIR)/jar-%.api,$?))) > /dev/stderr
	@$(report) '   Jar PPI:' ' %s' '\n' $(subst /,.,$(patsubst $(JARDEPS_TMPDIR)/jar-%.ppi,%,$(filter $(JARDEPS_TMPDIR)/jar-%.ppi,$?))) > /dev/stderr
	@$(report) '   Classes of: ' ' %s' '\n' $(patsubst $(JARDEPS_TMPDIR)/tree-%.compiled,%,$(filter $(JARDEPS_TMPDIR)/tree-%.compiled,$?)) > /dev/stderr
	@$(report) '   Statics of: ' ' %s' '\n' $(patsubst $(JARDEPS_TMPDIR)/tree-%.statics,%,$(filter $(JARDEPS_TMPDIR)/tree-%.statics,$?)) > /dev/stderr
	@$(report) '   Language packs of: ' ' %s' '\n' $(patsubst $(JARDEPS_TMPDIR)/tree-%.lang,%,$(filter $(JARDEPS_TMPDIR)/tree-%.lang,$?)) > /dev/stderr
	@$(report) '   Merged files of: ' ' %s' '\n' $(patsubst $(JARDEPS_TMPDIR)/tree-%.merged,%,$(filter $(JARDEPS_TMPDIR)/tree-%.merged,$?)) > /dev/stderr
	@$(report) '' '   %s.jar\n' '' $(patsubst $(JARDEPS_OUTDIR)/%.jar,%,$(filter $(JARDEPS_OUTDIR)/%.jar,$?)) > /dev/stderr
	@$(report) '   Root list\n' '' '' $(filter $(JARDEPS_TMPDIR)/tree-%.root-list,$?) > /dev/stderr
	@$(report) '   IDL list\n' '' '' $(filter $(JARDEPS_TMPDIR)/tree-%.idl-list,$?) > /dev/stderr
	@$(report) '   Classpath\n' '' '' $(filter $(JARDEPS_TMPDIR)/tree-%.classpath,$?) > /dev/stderr
	@$(report) '   IDL include path\n' '' '' $(filter $(JARDEPS_TMPDIR)/tree-%.idl-path,$?) > /dev/stderr
	@$(report) '   Processor path\n' '' '' $(filter $(JARDEPS_TMPDIR)/tree-%.procpath,$?) > /dev/stderr
	@$(report) '   Compiler flags\n' '' '' $(filter $(JARDEPS_TMPDIR)/tree-%.flags,$?) > /dev/stderr
	@$(report) '   IDL flags\n' '' '' $(filter $(JARDEPS_TMPDIR)/tree-%.idl-flags,$?) > /dev/stderr
	@$(TOUCH) "$(JARDEPS_TMPDIR)/tree-$*.idlout"
	@$(JARDEPS_LIB)/idlfun.sh \
	  --dir "$(JARDEPS_IDLDIR)" \
	  --out "$(JARDEPS_TMPDIR)/tree-$*.idlout" \
	  --td "$(JARDEPS_TMPDIR)/idl/$*)" \
	  --array CD $(words $(CD)) $(CD:%='%') \
	  --array TEE $(words $(TEE)) $(TEE:%='%') \
	  --array PRINTF $(words $(PRINTF)) $(PRINTF:%='%') \
	  --array IDLJ $(words $(IDLJ)) $(IDLJ:%='%') \
	  --array IDLJFLAGS $(words $(APPLIED_IDLJFLAGS_$*)) $(APPLIED_IDLJFLAGS_*:%='%') \
	  --array IDLJFLAGS $(words $(APPLIED_IDLPATH_$*)) $(APPLIED_IDLPATH_*:%='%') \
	  --array IDLJFLAGS $(words $(IDLPFX_FLAGS)) $(IDLPFX_FLAGS) \
	  $(idls_$*)
	@$(FIND) "$(JARDEPS_TMPDIR)/idl/$*" -name "*.java" > "$(JARDEPS_TMPDIR)/tree-$*.idljava-list"
	@$(AWK) -f "$(JARDEPS_LIB)/parseidlout.awk" \
	  -v TARGET="$*" -v DIR="$(JARDEPS_IDLDIR)" \
	  "$(JARDEPS_TMPDIR)/tree-$*.idlout" > "$(JARDEPS_TMPDIR)/tree-$*.idl.mk"
	@$(JAVAC_JAVA) $(JAVAC_JAVAFLAGS) \
	  -cp "$(JARDEPS_CLASSPATH)" JardepsCompiler \
	  $(APPLIED_JAVACFLAGS_$*) -implicit:class \
	  -d "$(JARDEPS_CLASSDIR)/$*" \
	  -cp "$(subst $(jardeps_space),:,$(APPLIED_CLASSPATH_$*))" \
	  -processorpath "$(subst $(jardeps_space),:,$(APPLIED_PROCPATH_$*))" \
	  -s "$(JARDEPS_TMPDIR)/apt/$*" \
	  -h "$(JARDEPS_JNIDIR)" \
	  -sourcepath "$(JARDEPS_SRCDIR)/$*":"$(JARDEPS_TMPDIR)/idl/$*" \
	  -profile:public "$(JARDEPS_TMPDIR)/tree-$*.api-tmp" \
	  -profile:default "$(JARDEPS_TMPDIR)/tree-$*.ppi-tmp" \
	  -packages:provided "$(JARDEPS_TMPDIR)/tree-$*.provided-tmp" \
	  -packages:used "$(JARDEPS_TMPDIR)/tree-$*.externals-tmp" \
	  -Auk.ac.lancs.scc.jardeps.service.dir="$(JARDEPS_TMPDIR)/aptbin/$*/META-INF/services" \
	  -Auk.ac.lancs.scc.jardeps.manifest="$(JARDEPS_TMPDIR)/tree-$*.apt-manifest" \
	  -list:sources:3 "$(JARDEPS_LIB)/store-srcdeps.sh" \
	    "$(JARDEPS_TMPDIR)/tree-$*.mk" \
	    "$(JARDEPS_SRCDIR)/$*/" \
	    "$*" \
	  -list:inputs:3 "$(JARDEPS_LIB)/store-inputs.sh" \
	    "$(JARDEPS_TMPDIR)/inputs-$*.mk" \
	    "$(JARDEPS_SRCDIR)/$*/" \
	    "$*" \
	  -list:classes:2 "$(JARDEPS_LIB)/store-classes.sh" \
	    "$(JARDEPS_TMPDIR)/tree-$*.list" \
	    "$(JARDEPS_CLASSDIR)/$*/" \
	  $(foreach root,$(roots_$*),"$(JARDEPS_SRCDIR)/$*/$(subst .,/,$(root)).java") \
	  "@$(JARDEPS_TMPDIR)/tree-$*.idljava-list"
	@$(TOUCH) "$@"
	@$(ECHO) '  Compilation complete' > /dev/stderr
	@$(BLANK)

show-all-trees::
	@$(PRINTF) '%s\n' $(trees)

## Housekeeping

clean-jar-%::
	@$(ECHO) '[JARDEPS] $*.jar: Deleting intermediate files' > /dev/stderr
	@$(RM) '$(JARDEPS_TMPDIR)/jar-$*.'*

clean-tree-%::
	@$(ECHO) '[JARDEPS] $*: Deleting intermediate files' > /dev/stderr
	@$(RMTREE) '$(JARDEPS_CLASSDIR)/$*'
	@$(RM) '$(JARDEPS_TMPDIR)/tree-$*.'*



## Get a copy of a tree's manually provided manifest.  If none is
## provided, create a blank one.
$(JARDEPS_TMPDIR)/tree-%.manual-manifest: $(JARDEPS_DEPDIR)/tree-%.manifest
	@$(CP) "$<" "$@-tmp"
	@$(MV) "$@-tmp" "$@"
$(JARDEPS_TMPDIR)/tree-%.manual-manifest:
	@$(TOUCH) "$@"

## Create the manifest that the annotation processor should have
## generated.
$(JARDEPS_TMPDIR)/tree-%.apt-manifest:
	@$(TOUCH) "$@"

## Create the list of imports to actually be made, with exclusions
## applied.  We take all the detected referenced packages, and
## subtract the list of excluded ones.
$(JARDEPS_TMPDIR)/tree-%.trimmed-externals:
	@$(ECHO) '[JARDEPS] $*: Excluding packages' > /dev/stderr
	@$(CAT) "$(JARDEPS_TMPDIR)/tree-$*.externals" \
	  | $(safegrep) -Fvx -f "$(JARDEPS_TMPDIR)/tree-$*.excluded-imports" \
	  > "$@-tmp"
	@$(MV) "$@-tmp" "$@"

## Get a copy of a jar's manually provided manifest.  If none is
## provided, create a blank one.
$(JARDEPS_TMPDIR)/jar-%.manual-manifest: $(JARDEPS_JDEPDIR)/jar-%.manifest
	@$(CP) "$<" "$@-tmp"
	@$(MV) "$@-tmp" "$@"
$(JARDEPS_TMPDIR)/jar-%.manual-manifest:
	@$(TOUCH) "$@"

## Work out what packages a jar provided by catenating the
## corresponding lists of the component trees, sorting, and removing
## duplicates.
$(JARDEPS_TMPDIR)/jar-%.provided:
	@$(ECHO) '[JARDEPS] $*.jar: Identifying provided packages' > /dev/stderr
	@$(CAT) $(trees_$*:%='$(JARDEPS_TMPDIR)/tree-%.provided') | \
	  $(SORTU) > "$@-tmp"
	@$(MV) "$@-tmp" "$@"

## Generate the jar manifest by concatenating the manually provided
## part with the generated imports and exports, and adding the
## component trees' manually provided parts.
$(JARDEPS_TMPDIR)/jar-%.manifest:
	@$(ECHO) '[JARDEPS] $*.jar: Compiling manifest' > /dev/stderr
	@$(CAT) '$(JARDEPS_TMPDIR)/jar-$*.manual-manifest' \
	  '$(JARDEPS_TMPDIR)/jar-$*.deps' \
	  '$(JARDEPS_TMPDIR)/jar-$*.imports' \
	  '$(JARDEPS_TMPDIR)/jar-$*.exports' \
	  $(trees_$*:%='$(JARDEPS_TMPDIR)/tree-%.apt-manifest') \
	  $(trees_$*:%='$(JARDEPS_TMPDIR)/tree-%.manual-manifest') > "$@-tmp"
	@$(MV) "$@-tmp" "$@"


## Work out the manifest lines that import packages from a jar.
## Catenate the import lists of component trees, sort, and remove
## duplicates, packages provided by the same jar, and explicitly
## excluded packages.
$(JARDEPS_TMPDIR)/jar-%.imports:
	@$(ECHO) '[JARDEPS] $*.jar: Generating imports' > /dev/stderr
	@$(commaline) 'Import-Package: ' $(call jar-import-list,$*) > "$@-tmp"
	@$(MV) "$@-tmp" "$@"

jar-import-list=$(shell $(CAT) $(trees_$1:%='$(JARDEPS_TMPDIR)/tree-%.imports') \
  $(trees_$1:%='$(JARDEPS_TMPDIR)/tree-%.trimmed-externals') | \
  $(SORTU) | \
  $(safegrep) -Fvx -f '$(JARDEPS_TMPDIR)/jar-$1.provided' | \
  $(safegrep) -Fvx -f '$(JARDEPS_TMPDIR)/jar-$1.excluded-imports' | \
  $(safegrep) -Ev '^java\.')

## Work out the manifest lines that export packages from a jar.
## Catenate the export lists of component trees, sort, and remove
## duplicates.
$(JARDEPS_TMPDIR)/jar-%.exports:
	@$(ECHO) '[JARDEPS] $*.jar: Generating exports' > /dev/stderr
	@$(commaline) 'Export-Package: ' $(call jar-export-list,$*) > "$@-tmp"
	@$(MV) "$@-tmp" "$@"

jar-export-list=\
$(shell $(CAT) $(trees_$1:%=$(JARDEPS_TMPDIR)/tree-%.exports) | $(SORTU))

## All trees that include IDLs depend on the IDL module->package
## mapping.
$(idl_trees:%=$(JARDEPS_TMPDIR)/tree-%.compiled): $(JARDEPS_TMPDIR)/idl.map

## This is an attempt at generating source file lists from files
## managed by Eclipse.  It's not really finished atm.
$(JARDEPS_TMPDIR)/exclusions.done: .classpath
	@$(PRINTF) "Generating source lists from Eclipse classpath...\n"
	@$(MKDIR) "$(@D)"
	@$(TOUCH) '$(JARDEPS_TMPDIR)/CACHEDIR.TAG'
	@for tree in $(trees) ; do \
  $(XSLTPROC) --stringparam ROOT '$(JARDEPS_SRCDIR)/'"$$tree" \
    $(JARDEPS_LIB)/extract-exclusions.xsl .classpath | \
    $(TR) '|' '\n' \
    > "$(JARDEPS_TMPDIR)/tree-$$tree-eclipse-exclusions.list" ; \
  ($(CD) '$(JARDEPS_SRCDIR)/'"$$tree" ; \
   $(FIND) . -name "*.java") | $(CUT) -c 3- | \
  $(safegrep) -Fvx \
    -f "$(JARDEPS_TMPDIR)/tree-$$tree-eclipse-exclusions.list" | \
  $(SORT) | $(XARGS) -l1 $(PRINTF) 'SOURCE_FILES_%s += %s\n' "$$tree" \
    > "$(JARDEPS_TMPDIR)/tree-$$tree-eclipse.mk-tmp" ; \
  $(CMP) "$(JARDEPS_TMPDIR)/tree-$$tree-eclipse.mk-tmp" \
    "$(JARDEPS_DEPDIR)/autodeps-$$tree.mk" || \
  ($(MV) "$(JARDEPS_TMPDIR)/tree-$$tree-eclipse.mk-tmp" \
     "$(JARDEPS_DEPDIR)/autodeps-$$tree.mk" ; \
   $(PRINTF) '  Changed tree %s\n' "$$tree") ; \
done
	@$(TOUCH) "$@"







########################################################################
## The preamble generates files containing lists specified in Makefile
## variables.  For each one, a temporary file is created for every
## preamble, but is only copied to the actual file if changed.  This
## allows us to detect changes in the project definition at the
## granularity of variables, rather than the cruder granularity of
## files.


## These files are per-tree.
$(JARDEPS_TMPDIR)/tree-%.root-list:
	@$(cmpcp) '[JARDEPS] $*: Root list changed' '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/tree-%.idl-list:
	@$(cmpcp) '[JARDEPS] $*: IDL list changed' '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/tree-%.static-list:
	@$(cmpcp) '[JARDEPS] $*: Static list changed' '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/tree-%.dlps-list:
	@$(cmpcp) '[JARDEPS] $*: Language-pack list changed' '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/tree-%.merge-list:
	@$(cmpcp) '[JARDEPS] $*: Merge list changed' '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/tree-%.exports:
	@$(cmpcp) '[JARDEPS] $*: Export list changed' '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/tree-%.imports:
	@$(cmpcp) '[JARDEPS] $*: Import list changed' '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/tree-%.excluded-imports:
	@$(cmpcp) '[JARDEPS] $*: Import exclusion list changed' '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/tree-%.classpath:
	@$(cmpcp) '[JARDEPS] $*: Classpath changed' '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/tree-%.procpath:
	@$(cmpcp) '[JARDEPS] $*: Processor path changed' '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/tree-%.flags:
	@$(cmpcp) '[JARDEPS] $*: Compiler flags changed' '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/tree-%.idl-flags:
	@$(cmpcp) '[JARDEPS] $*: IDL flags changed' '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/tree-%.idl-path:
	@$(cmpcp) '[JARDEPS] $*: IDL include path changed' '$@-tmp' '$@'

## These files are per-jar.
$(JARDEPS_TMPDIR)/jar-%.excluded-imports:
	@$(cmpcp) '[JARDEPS] $*.jar: Import exclusion list changed' '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/jar-%.tree-list:
	@$(cmpcp) '[JARDEPS] $*.jar: Tree list changed' '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/jar-%.deps:
	@$(cmpcp) '[JARDEPS] $*.jar: Local classpath changed' '$@-tmp' '$@'

$(JARDEPS_TMPDIR)/jar-%.carp:
	@$(cmpcp) '[JARDEPS] $*.jar: CARP modules' '$@-tmp' '$@'


## These files are singletons.
$(JARDEPS_TMPDIR)/jar.list:
	@$(cmpcp) '[JARDEPS] Jar list changed' '$@-tmp' '$@'
$(JARDEPS_TMPDIR)/idl.map:
	@$(cmpcp) '[JARDEPS] IDL map changed' '$@-tmp' '$@'


define preamble4tree
$(report) '' '%s\n' '' $(sort $(roots_$1)) \
  > '$(JARDEPS_TMPDIR)/tree-$1.root-list-tmp'
$(report) '' '%s\n' '' $(sort $(idls_$1)) \
  > '$(JARDEPS_TMPDIR)/tree-$1.idl-list-tmp'
$(report) '' '%s\n' '' $(sort $(statics_$1)) \
  > '$(JARDEPS_TMPDIR)/tree-$1.static-list-tmp'
$(report) '' '%s\n' '' $(sort $(dlps_$1)) \
  > '$(JARDEPS_TMPDIR)/tree-$1.dlps-list-tmp'
$(report) '' '%s\n' '' $(sort $(merge_$1)) \
  > '$(JARDEPS_TMPDIR)/tree-$1.merge-list-tmp'
$(report) '' '%s\n' '' $(sort $(imports_$1)) \
  > '$(JARDEPS_TMPDIR)/tree-$1.imports-tmp'
$(report) '' '%s\n' '' $(sort $(excluded_imports_$1)) \
  > '$(JARDEPS_TMPDIR)/tree-$1.excluded-imports-tmp'
$(report) '' '%s\n' '' $(sort $(exports_$1)) \
  > '$(JARDEPS_TMPDIR)/tree-$1.exports-tmp'
$(report) '' '%s\n' '' $(DEPENDENCY_CLASSPATH_$1) \
  > '$(JARDEPS_TMPDIR)/tree-$1.classpath-tmp'
$(report) '' '%s\n' '' $(DEPENDENCY_IDLPATH_$1) \
  > '$(JARDEPS_TMPDIR)/tree-$1.idl-path-tmp'
$(report) '' '%s\n' '' $(DEPENDENCY_IDLJFLAGS_$1) \
  > '$(JARDEPS_TMPDIR)/tree-$1.idl-flags-tmp'
$(report) '' '%s\n' '' $(DEPENDENCY_PROCPATH_$1) \
  > '$(JARDEPS_TMPDIR)/tree-$1.procpath-tmp'
$(report) '' '%s\n' '' $(DEPENDENCY_JAVACFLAGS_$1) \
  > '$(JARDEPS_TMPDIR)/tree-$1.flags-tmp'

endef

define preamble4jar
$(report) '' '%s\n' '' $(sort $(trees_$1)) \
  > '$(JARDEPS_TMPDIR)/jar-$1.tree-list-tmp'
$(report) '' '%s\n' '' $(sort $(jexcluded_imports_$1)) \
  > '$(JARDEPS_TMPDIR)/jar-$1.excluded-imports-tmp'
$(report) 'Class-Path:' ' %s.jar' '\n' $(jardep_$1) \
  > '$(JARDEPS_TMPDIR)/jar-$1.deps-tmp'
$(report) '' '%s' '\n' $(jarcarp_$1) \
  > '$(JARDEPS_TMPDIR)/jar-$1.carp-tmp'

endef

## The preamble target should be ignored if it ever gets created as a
## file.
.PHONY: $(JARDEPS_TMPDIR)/preamble

$(JARDEPS_TMPDIR)/preamble:
	@$(MKDIR) "$(@D)"
	@$(report) '' '%s\n' '' $(inferred_jars) \
	  > '$(JARDEPS_TMPDIR)/jar.list-tmp'
	@( $(TRUE) $(foreach m,$(idl_modules),; $(PRINTF) 'map:%s: %s\n' '$m' '$(idlpkg_$m)') $(foreach m,$(idl_prefixes),; $(PRINTF) 'pfx:%s: %s\n' '$m' '$(idlpfx_$m)')) > '$(JARDEPS_TMPDIR)/idl.map-tmp'
	@$(foreach j,$(inferred_jars),$(call preamble4jar,$j))
	@$(foreach t,$(trees),$(call preamble4tree,$t))
#	@$(ECHO) 'Preamble complete'

$(preamble_byproducts): \
  $(JARDEPS_TMPDIR)/preamble

## Activity in building the preamble target or any of its byproducts
## should not be regarded as actual work done towards creating the
## targets that depend on it.  These rules only have an effect when
## using a version of Make patched to recognize the special .IDLE
## target.
.IDLE: $(preamble_byproducts)
.IDLE: $(JARDEPS_TMPDIR)/preamble
