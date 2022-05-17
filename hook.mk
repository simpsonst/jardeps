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

JARDEPS_REAL_INCLUDE := $(dir $(word $(words $(MAKEFILE_LIST)), $(MAKEFILE_LIST)))
JARDEPS_REAL_HOME1=$(JARDEPS_REAL_INCLUDE:%/include/=%)
JARDEPS_REAL_HOME=$(JARDEPS_REAL_HOME1:include/=.)


-include jardeps-user.mk

JARDEPS_HOME ?= $(JARDEPS_REAL_HOME)
JARDEPS_SHAREJAVA ?= $(JARDEPS_HOME)/share/java
JARDEPS_LIB ?= $(JARDEPS_HOME)/share/jardeps
JARDEPS_INCLUDE ?= $(JARDEPS_HOME)/include/jardeps
JARDEPS_ETC ?= $(JARDEPS_HOME)/etc/jardeps

JARDEPS_CLASSPATH ?= $(JARDEPS_LIB)/jardeps.jar
CLASSPATH += $(JARDEPS_SHAREJAVA)/jardeps-lib.jar
PROCPATH += $(JARDEPS_SHAREJAVA)/jardeps-lib.jar
PROCPATH += $(JARDEPS_SHAREJAVA)/jardeps-apt.jar

include $(JARDEPS_LIB)/utils.mk
include $(JARDEPS_LIB)/common.mk
