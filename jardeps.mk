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

-include jardeps-user.mk

JAVAC ?= javac

JARDEPS_HOME ?= jardeps
JARDEPS_LIB ?= $(JARDEPS_HOME)

JARDEPS_CLASSPATH ?= $(JARDEPS_TMPDIR)/jardeps.jar
CLASSPATH += $(JARDEPS_TMPDIR)/jardeps-lib.jar
PROCPATH += $(JARDEPS_TMPDIR)/jardeps-lib.jar
PROCPATH += $(JARDEPS_TMPDIR)/jardeps-apt.jar

include $(JARDEPS_HOME)/common.mk
include $(JARDEPS_HOME)/utils.mk

$(trees:%=$(JARDEPS_TMPDIR)/tree-%.compiled): \
	$(JARDEPS_TMPDIR)/jardeps.jar \
	$(JARDEPS_TMPDIR)/jardeps-lib.jar \
	$(JARDEPS_TMPDIR)/jardeps-apt.jar
