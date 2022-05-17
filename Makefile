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

all::

INSTALL=install
JAVAC=javac
JAR=jar
ZIP=zip
MKDIR=mkdir -p
TOUCH=touch
CD=cd
FIND=find
SED=sed
XARGS=xargs

PREFIX=/usr/local
INCLUDE_PREFIX=$(PREFIX)/include

-include jardeps-env.mk
-include ./config.mk

LIBRARY += jardeps.jar
LIBRARY += common.mk
LIBRARY += utils.mk
LIBRARY += jardeps.mk
LIBRARY += install.mk
LIBRARY += parseidlout.awk
LIBRARY += extract-exclusions.xsl
LIBRARYEXEC += report.sh
LIBRARYEXEC += install.sh
LIBRARYEXEC += foldrc.sh
LIBRARYEXEC += commaline.sh
LIBRARYEXEC += cmpcp.sh
LIBRARYEXEC += store-classes.sh
LIBRARYEXEC += store-srcdeps.sh
LIBRARYEXEC += store-inputs.sh
LIBRARYEXEC += native2ascii.sh
LIBRARYEXEC += idlfun.sh

JAVALIBRARY += jardeps-apt.jar
JAVALIBRARY += jardeps-lib.jar
JAVALIBRARY += jardeps-lib-src.zip


include utils.mk


all:: jardeps.jar jardeps-lib.jar jardeps-lib-src.zip jardeps-apt.jar


jardeps-lib-src.zip: src/uk/ac/lancs/scc/jardeps/Service.java \
		src/uk/ac/lancs/scc/jardeps/Application.java
	$(CD) src ; $(ZIP) "../$@" \
	  uk/ac/lancs/scc/jardeps/Service.java \
	  uk/ac/lancs/scc/jardeps/Application.java

install::
	$(INSTALL) -d $(PREFIX)/share/java
	$(INSTALL) -m 0644 $(JAVALIBRARY) $(PREFIX)/share/java
	$(INSTALL) -d $(PREFIX)/share/jardeps
	$(INSTALL) -m 0644 $(LIBRARY) $(PREFIX)/share/jardeps
	$(INSTALL) -m 0755 $(LIBRARYEXEC) $(PREFIX)/share/jardeps
	$(INSTALL) -d $(PREFIX)/include
	$(INSTALL) -D -m 0644 hook.mk $(PREFIX)/include/jardeps.mk
	$(INSTALL) -d $(PREFIX)/bin
	$(INSTALL) -D -m 0755 jrun $(PREFIX)/bin

blank:: clean
	$(RM) jardeps.jar
	$(RM) jardeps-lib.jar
	$(RM) jardeps-lib-src.zip
	$(RM) jardeps-apt.jar

clean:: tidy
	$(RM) -r compile.done
	$(RM) -r classes

tidy::
	$(FIND) . -name "*~" -delete



## Set this to the comma-separated list of years that should appear in
## the licence.  Do not use characters other than [0-9,] - no spaces.
YEARS=2007-16,2018-19,2021-22

update-licence:
	$(FIND) . -name ".svn" -prune -or -type f -print0 | $(XARGS) -0 \
	$(SED) -i 's/Copyright ([Cc])\s[-0-9,]\+\s\+Lancaster University/Copyright (c) $(YEARS), Lancaster University/g'
