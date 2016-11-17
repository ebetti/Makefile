# Author: Emiliano Betti, copyright (C) 2011
# e-mail: betti@linux.com
#
# This is a generic Makefile with automatic dependency generation.
#
# The code was partially inspired by:
# http://www.makelinux.net/make3/make3-CHP-2-SECT-7
#
# Version 0.9.3 (October 7th, 2014)
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

# Please set your own target name.
# Note that when building libraries the final library name will be:
# - lib$(TARGETNAME).so for shared libraries
# - lib$(TARGETNAME).a for static libraries
TARGETNAME=a.out

# Target type can be:
# - 'exec' (or blank - it's the default) for dynamic executable
# - 'staticexec' for static executable
# - 'lib' to build as library (both shared and static)
# - 'sharedlib' for shared library
# - 'staticlib' for static library
TARGETTYPE=exec

# Set to 'y' to enable DEBUG
DEBUG?=n

# 'n' -> if your source code is C
# 'y' -> if your source code is C++
CPLUSPLUS=n

##############################################################################
############################## Advanced tweaks ###############################
##############################################################################

ROOTFS?=/

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

INCFLAGS=-I$(ROOTFS)/$(INSTALL_PREFIX)/include -I$(ROOTFS)/usr/include

# CXXFLAGS will be the same
CFLAGS=-Wall -O2 $(INCFLAGS) -fPIC

LDFLAGS+=-L$(ROOTFS)/$(INSTALL_PREFIX)/lib -L$(ROOTFS)/usr/lib
#LDFLAGS+=-L$(ROOTFS)/$(INSTALL_PREFIX)/lib64 -L$(ROOTFS)/usr/lib64

# Build also sources from the following directories:
EXTRA_DIRS=

# Uncomment (and eventually change the header file name)
# to install an header file along with your target
# (this is very common for libreries)
#INSTALL_HEADER=$(TARGETNAME).h

# You might want to customize this...
ifeq ($(DEBUG),y)
	CFLAGS+= -g
else
	CFLAGS+= -DNDEBUG
endif

# When building libraries, set this variable to 'y' to manually select which
# function will be available through the library. If you choose to do this,
# remember to mark "__public" all the function you want to export.
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

ifeq ($(CPLUSPLUS),y)
	LINK=$(CXX)
	EXT=cpp
	HEADERS=$(shell ls *.h *.hpp 2> /dev/null)
else
	LINK=$(CC)
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

ifeq ($(OPTIMIZE_LIB_VISIBILITY),y)
	VISHEADER=.__vis.h
	HEADERS+=$(VISHEADER)
	CFLAGS+=-fvisibility=hidden -include $(VISHEADER)
else
	VISHEADER=
endif

ifneq ($(INSTALL_HEADER),)
	HEADERS_TO_INSTALL=$(shell gcc -MM $(INSTALL_HEADER) | cut -d ':' -f 2)
	HEADERS_INSTALL_DIR=$(INSTALL_ROOT)/$(INSTALL_PREFIX)/include
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

# Note: use -MM instead of -M if you do not want to include system headers in
#       the dependencies
%.d: %.$(EXT) $(VISHEADER)
	@$(CC) $(CFLAGS) -MM $< > $@.$$$$;			\
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

install: $(TARGET)
	sudo install -D $(TARGET) $(INSTALL_TARGET)
ifeq ($(TARGETTYPE),lib)
	sudo install -D $(TARGET:.so=.a) $(INSTALL_TARGET:.so=.a)
endif
ifneq ($(HEADERS_TO_INSTALL),)
	for h in $(HEADERS_TO_INSTALL) ; do sudo install -D $$h $(HEADERS_INSTALL_DIR)/$$h ; done
endif

.PHONY: clean

clean:
	rm -f *.d *.o $(TARGET) tags $(VISHEADER)
ifeq ($(TARGETTYPE),lib)
	rm -f $(TARGET:.so=.a)
endif
ifneq ($(EXTRA_DIRS),)
	for i in $(EXTRA_DIRS) ; do rm -f $${i}/*.d $${i}/*.o ; done
endif

