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

JARDEPS_UTILS += JardepsCompiler
JARDEPS_UTILS += PropertyDefaulter
JARDEPS_UTILS += Native2Ascii
JARDEPS_UTILS += ClassAnalysis
JARDEPS_UTILS += ConstantPoolBuilder
JARDEPS_UTILS += ConstantPool
JARDEPS_UTILS += NameAndType
JARDEPS_UTILS += Ref
JARDEPS_UTILS += Constants
JARDEPS_UTILS += ClassId
JARDEPS_UTILS += Visibility
JARDEPS_UTILS += MemberEntry
#JARDEPS_UTILS += ClassTracker
#JARDEPS_UTILS += ClassSink
#JARDEPS_UTILS += DeferredClassSink
JARDEPS_UTILS += uk.ac.lancs.scc.jardeps.Service
JARDEPS_UTILS += uk.ac.lancs.scc.jardeps.Application
JARDEPS_UTILS += uk.ac.lancs.scc.jardeps.apt.ServiceProcessor




ifeq ($(JARDEPS_HOME),)
## We're preparing for a formal installation.
JARDEPS_UTILS_FILE=utils.mk
JARDEPS_INTERNAL_SRCDIR=src
JARDEPS_INTERNAL_CLASSDIR=classes
JARDEPS_COMPILATION=compile.done
JARDEPS_COMPILER_JAR=jardeps.jar
JARDEPS_LIBRARY_JAR=jardeps-lib.jar
JARDEPS_LIBRARY_SRCZIP=jardeps-lib-src.zip
JARDEPS_PROCESSOR_JAR=jardeps-apt.jar
else
## We're embedded in another project.
JARDEPS_UTILS_FILE=$(JARDEPS_HOME)/utils.mk
JARDEPS_INTERNAL_SRCDIR=$(JARDEPS_HOME)/src
JARDEPS_INTERNAL_CLASSDIR=$(JARDEPS_HOME)/classes
JARDEPS_COMPILATION=$(JARDEPS_TMPDIR)/compile.done
JARDEPS_COMPILER_JAR=$(JARDEPS_TMPDIR)/jardeps.jar
JARDEPS_LIBRARY_JAR=$(JARDEPS_TMPDIR)/jardeps-lib.jar
JARDEPS_LIBRARY_SRCZIP=$(JARDEPS_TMPDIR)/jardeps-lib-src.zip
JARDEPS_PROCESSOR_JAR=$(JARDEPS_TMPDIR)/jardeps-apt.jar
endif

JARDEPS_SOURCES=$(foreach src,$(JARDEPS_UTILS),$(JARDEPS_INTERNAL_SRCDIR)/$(subst .,/,$(src)).java)

JARDEPS_COMPILER_CLASSES=$(patsubst $(JARDEPS_INTERNAL_CLASSDIR)/%,'%',$(wildcard $(JARDEPS_INTERNAL_CLASSDIR)/*.class))
JARDEPS_LIBRARY_CLASSES=$(patsubst $(JARDEPS_INTERNAL_CLASSDIR)/%,'%',$(wildcard $(JARDEPS_INTERNAL_CLASSDIR)/uk/ac/lancs/scc/jardeps/*.class))
JARDEPS_PROCESSOR_CLASSES=$(patsubst $(JARDEPS_INTERNAL_CLASSDIR)/%,'%',$(wildcard $(JARDEPS_INTERNAL_CLASSDIR)/uk/ac/lancs/scc/jardeps/apt/*.class))

$(JARDEPS_COMPILATION): $(JARDEPS_SOURCES) $(JARDEPS_UTILS_FILE)
	$(MKDIR) $(JARDEPS_INTERNAL_CLASSDIR)
	$(JAVAC) $(JAVACFLAGS) \
	  -d $(JARDEPS_INTERNAL_CLASSDIR) \
	  -sourcepath $(JARDEPS_INTERNAL_SRCDIR) \
	  $(JARDEPS_SOURCES)
	$(TOUCH) "$@"

$(JARDEPS_COMPILER_JAR): $(JARDEPS_COMPILATION)
	$(JAR) cf "$@" \
	  $(JARDEPS_COMPILER_CLASSES:%=-C $(JARDEPS_INTERNAL_CLASSDIR) %)

$(JARDEPS_LIBRARY_JAR): $(JARDEPS_COMPILATION)
	$(JAR) cf "$@" \
	  $(JARDEPS_LIBRARY_CLASSES:%=-C $(JARDEPS_INTERNAL_CLASSDIR) %)

$(JARDEPS_PROCESSOR_JAR): $(JARDEPS_COMPILATION)
	$(JAR) cf "$@" \
	  $(JARDEPS_PROCESSOR_CLASSES:%=-C $(JARDEPS_INTERNAL_CLASSDIR) %) \
	  -C $(JARDEPS_INTERNAL_SRCDIR) \
	  META-INF/services/javax.annotation.processing.Processor
