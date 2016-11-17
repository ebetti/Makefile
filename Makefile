# Author: Emiliano Betti, copyright (C) 2011
# e-mail: betti@linux.com
#
# Version 0.9.7-rc2 (December 2nd, 2014)
#
# "One to build them all!"
#
# This Makefile is meant to be a 'generic' Makefile, useful to build
# simple applications, but also shared and static libraries.
# Main features are:
# - support for C and C++ code (C++ is partially tested though)
# - automatic header files dependency generation
# - support for building static or dynamic executables
# - support for building shared and static libraries
# - support for customize 'visibility' in libraries
# - special 'install' target to install binaries and header files
# - special 'pkg' target to create a .tar.gz packet
#
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

##############################################################################
############################ Basic configuration #############################
##############################################################################

# To customize the behaviour of this Makefile you have two options (non mutual
# exclusive):
# - edit this file
# - create a config.mk file that overrides what you want to personalize
-include config.mk

# Please set your own target name.
# Note that when building libraries the final library name will be:
# - lib$(TARGETNAME).so for shared libraries
# - lib$(TARGETNAME).a for static libraries
TARGETNAME?=a.out

# Target type can be:
# - 'exec' (or blank - it's the default) for dynamic executable
# - 'staticexec' for static executable
# - 'lib' to build as library (both shared and static)
# - 'sharedlib' for shared library
# - 'staticlib' for static library
TARGETTYPE?=exec

# Set to 'y' to enable DEBUG
DEBUG?=n

# 'n' -> if your source code is C
# 'y' -> if your source code is C++
CPLUSPLUS?=n

# 'y' -> if you want this Makefile to use 'sudo' when installing the target or
# 	 creating a package
# 'n' -> if you want to type 'sudo' yourself whenever you think you need to.
USESUDO?=y

# Add here extra include directories
#INCFLAGS=-I../your_include_directory

# Add here your -L and -l linker options
LIBS?=

##############################################################################
############################## Advanced tweaks ###############################
##############################################################################

# Build also sources from the following directories:
EXTRA_DIRS=

# Uncomment (and eventually change the header file name)
# to install an header file along with your target
# (this is very common for libreries)
# It is allowed only one single file with extension .h
# Any file that it includes using doblue quotes (not angle brackets!) is going
# to be installed as well
#INSTALL_HEADER=$(TARGETNAME).h

ROOTFS?=/

TMPDIR=$(shell pwd -P)/._tmp
PKG=$(shell pwd -P)/$(TARGETNAME).tar.gz
pkg: INSTALL_ROOT=$(TMPDIR)

INSTALL_ROOT?=$(ROOTFS)

INSTALL_PREFIX?=/usr/local

# Leave it commented to use defaults:
# - 'lib' for libraries, 'bin' for executables
#INSTALL_DIR=lib64

#CROSS_COMPILE?=arm-arago-linux-gnueabi-
CROSS_COMPILE?=

CC=$(CROSS_COMPILE)gcc
CXX=$(CROSS_COMPILE)g++
AR=$(CROSS_COMPILE)ar

POST_INSTALL_SCRIPT=./post_install.sh
POST_INSTALL_SCRIPT_CMD=ROOTFS=$(ROOTFS) INSTALL_ROOT=$(INSTALL_ROOT) INSTALL_PREFIX=$(INSTALL_PREFIX) TARGETNAME=$(TARGETNAME) $(POST_INSTALL_SCRIPT)

ifeq ($(USESUDO),y)
INSTALL=sudo install -D
RUN_POST_INSTALL_SCRIPT=sudo $(POST_INSTALL_SCRIPT_CMD)
else
INSTALL=install -D
RUN_POST_INSTALL_SCRIPT=$(POST_INSTALL_SCRIPT_CMD)
endif

# CXXFLAGS will be the same
CFLAGS=-Wall -O2 -fPIC

LDFLAGS+=-L$(ROOTFS)/$(INSTALL_PREFIX)/lib -L$(ROOTFS)/usr/lib $(LIBS)
#LDFLAGS+=-L$(ROOTFS)/$(INSTALL_PREFIX)/lib64 -L$(ROOTFS)/usr/lib64 $(LIBS)

# You might want to customize this...
ifeq ($(DEBUG),y)
	# The following flags are needed to support backtrace() function on
	# both x86 and arm.
	CFLAGS+= -g -rdynamic -fno-omit-frame-pointer -fno-inline -funwind-tables
else
	CFLAGS+= -DNDEBUG
endif

# When building libraries set this variable to 'y' to manually select which
# function will be available through the library. If you choose to do this,
# remember to mark "__public" all the functions you want to export.
# For example:
#                 int __public mypublicfunc(void) { ... }
#
OPTIMIZE_LIB_VISIBILITY=n

##############################################################################
####### NOTE! You should not need to change anything below this line! ########
##############################################################################

ifneq ($(EXTRA_DIRS),)
	INCFLAGS+=$(shell for i in $(EXTRA_DIRS) ; do echo "-I$${i} " ; done)
endif

# Please note that the order of "-I" directives is important. My choice is to
# first look for headers in the sources, and than in the system directories.
INCFLAGS:=-I. $(INCFLAGS) -I$(ROOTFS)/$(INSTALL_PREFIX)/include -I$(ROOTFS)/usr/include

CFLAGS+=$(INCFLAGS)

ifeq ($(CPLUSPLUS),y)
	LINK=$(CXX)
	MAKEDEP=$(CXX)
	EXT=cpp
	HEADERS=$(shell ls *.h *.hpp 2> /dev/null)
else
	LINK=$(CC)
	MAKEDEP=$(CC)
	EXT=c
	HEADERS=$(shell ls *.h 2> /dev/null)
endif

TARGET=$(TARGETNAME)

ifeq ($(TARGETTYPE),exec)
	INSTALL_DIR?=bin
	OPTIMIZE_LIB_VISIBILITY=n
endif

ifeq ($(TARGETTYPE),staticexec)
	LINK+=-static
	INSTALL_DIR?=bin
	OPTIMIZE_LIB_VISIBILITY=n
endif

ifeq ($(TARGETTYPE),sharedlib)
	TARGET=lib$(TARGETNAME).so
	LDFLAGS+=-Wl,-soname,$(TARGET) -shared
	INSTALL_DIR?=lib
endif

ifeq ($(TARGETTYPE),lib)
	# Same as sharedlib!
	TARGET=lib$(TARGETNAME).so
	LDFLAGS+=-Wl,-soname,$(TARGET) -shared
	INSTALL_DIR?=lib
endif

ifeq ($(TARGETTYPE),staticlib)
	TARGET=lib$(TARGETNAME).a
	INSTALL_DIR?=lib
endif

ifneq ($(INSTALL_HEADER),)
	# Note that here I use := instead of = because I want CFLAGS to expand immediately (before including $(VISHEADER))
	HEADERS_TO_INSTALL:=$(shell $(MAKEDEP) $(CFLAGS) -MM $(INSTALL_HEADER) | sed 's,\($*\)\.o[ :]*,\1.h: ,g' | sed 's,\\,,g')
	HEADERS_INSTALL_DIR=$(INSTALL_ROOT)/$(INSTALL_PREFIX)/include
endif

ifeq ($(OPTIMIZE_LIB_VISIBILITY),y)
	VISHEADER=.__vis.h
	HEADERS+=$(VISHEADER)
	CFLAGS+=-fvisibility=hidden -include $(VISHEADER)
else
	VISHEADER=
endif

CXXFLAGS=$(CFLAGS)

INSTALL_TARGET=$(INSTALL_ROOT)/$(INSTALL_PREFIX)/$(INSTALL_DIR)/$(shell basename $(TARGET))

SRC:=$(shell for i in $(EXTRA_DIRS) ; do ls $${i}/*.$(EXT) ; done)
SRC+=$(shell ls *.$(EXT))
OBJ=$(SRC:.$(EXT)=.o)
DEP=$(OBJ:.o=.d)

CTAGS=$(shell which ctags 2>/dev/null)

ifneq ($(CTAGS),)
	ALLTARGETS=$(TARGET) tags
else
	ALLTARGETS=$(TARGET)
endif

INSTALLTARGETS=$(TARGET)

ifneq ($(INSTALL_HEADER),)
	INSTALLTARGETS+=$(HEADERS_INSTALL_DIR)/$(shell basename $(INSTALL_HEADER))
endif

ifneq ($(TARGETTYPE),lib)

all: $(ALLTARGETS)

else

all: $(ALLTARGETS) $(TARGET:.so=.a)

endif

%.a: $(OBJ)
	$(AR) -rcs $@ $(OBJ)

ifneq ($(TARGETTYPE),staticlib)
$(TARGET): $(OBJ)
	$(LINK) $(CFLAGS) $(OBJ) $(LDFLAGS) -o $@
endif

-include $(DEP)

# These few lines were inspired by:
# http://www.makelinux.net/make3/make3-CHP-2-SECT-7
# Note: use -MM instead of -M if you do not want to include system headers in
#       the dependencies
%.d: %.$(EXT) $(VISHEADER)
	@$(MAKEDEP) $(CFLAGS) -MM $< > $@.$$$$;			\
	sed 's,\($*\)\.o[ :]*,\1.o $@ : ,g' < $@.$$$$ > $@;	\
	rm -f $@.$$$$

ifeq ($(OPTIMIZE_LIB_VISIBILITY),y)
$(VISHEADER):
	@echo '#ifndef _VIS_H_'				>  $(VISHEADER)
	@echo '#define _VIS_H_'				>> $(VISHEADER)
	@echo '#pragma GCC visibility push(default)'	>> $(VISHEADER)
	@echo '#pragma GCC visibility pop'		>> $(VISHEADER)
	@echo '#define __public __attribute__((visibility ("default")))' \
							>> $(VISHEADER)
	@echo '#endif'					>> $(VISHEADER)
endif

tags: $(SRC) $(HEADERS)
	@$(CTAGS) $^

install: $(INSTALLTARGETS)
	@echo "Installing binaries:"
	@echo " * $(TARGET) -> $(INSTALL_TARGET)"
	@$(INSTALL) $(TARGET) $(INSTALL_TARGET)
ifeq ($(TARGETTYPE),lib)
	@echo " * $(TARGET:.so=.a) -> $(INSTALL_TARGET:.so=.a)"
	@$(INSTALL) $(TARGET:.so=.a) $(INSTALL_TARGET:.so=.a)
endif
ifneq ($(POST_INSTALL_SCRIPT),)
	@test ! -x $(POST_INSTALL_SCRIPT) || $(RUN_POST_INSTALL_SCRIPT)
endif

ifneq ($(HEADERS_TO_INSTALL),)
$(HEADERS_INSTALL_DIR)/$(HEADERS_TO_INSTALL)
	@echo "Installing headers:"
	@for h in $^ ; do						\
		bh=$$(basename $$h);					\
		test "$$h" = "$(HEADERS_INSTALL_DIR)/$$bh" &&		\
			echo " ! Skipping already installed file $$h" &&\
		       	continue;					\
		echo " * $$h -> $(HEADERS_INSTALL_DIR)/$$bh";		\
		$(INSTALL) $$h $(HEADERS_INSTALL_DIR)/$$bh;		\
	done
endif

$(TMPDIR):
	@mkdir -p $@

pkg: clean $(TMPDIR) all install
	@cd $(TMPDIR) && tar czvf $(PKG) *
ifeq ($(USESUDO),y)
	@sudo rm -rf $(TMPDIR)
else
	@rm -rf $(TMPDIR)
endif
	@echo ""
	@echo "Package $(PKG) built"
	@echo ""

.PHONY: clean

clean:
	rm -f *.d *.o $(TARGET) tags $(VISHEADER)
	rm -rf $(TMPDIR) $(PKG)
ifeq ($(TARGETTYPE),lib)
	rm -f $(TARGET:.so=.a)
endif
ifneq ($(EXTRA_DIRS),)
	for i in $(EXTRA_DIRS) ; do rm -f $${i}/*.d $${i}/*.o ; done
endif

