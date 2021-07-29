# Author: Emiliano Betti, copyright (C) 2011
# e-mail: betti@linux.com
# License: GNU GPLv2
#
# Version 0.17 (July 29th, 2021)
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
# - special 'bin-pkg' target to create a <target>-bin.tar.gz packet with
#   your executable file or shared library
# - special 'dev-pkg' target to create a <target>-dev.tar.gz packet with
#   your libraries and header files
# - special 'pkg' target to create a <target>.tar.gz packet with both
#   'bin' and 'dev' files
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
# You should have received a copy of the GNU General Public License version 2
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

##############################################################################
############################ Basic configuration #############################
##############################################################################

SHELL:=/bin/bash

# To customize the behaviour of this Makefile you have two options (non mutual
# exclusive):
# - edit this file
# - create a config.mk file that overrides what you want to personalize
# In the latter case you can have multiple config files and switch between
# them defining an enviroment variable. For example:
# 	BUILDALT=myalt1 make # to build using config-myalt1.mk
# 	BUILDALT=myalt2 make # to build using config-myalt2.mk
# 	make # to build using config.mk
# Note that, while one might not have a config.mk, when the BUILDALT variable
# is defined the file config-$(BUILDALT).mk must exist
ifneq ($(BUILDALT),)
include config-$(BUILDALT).mk
else
-include config.mk
endif

# Please set your own target name.
# Note that when building libraries the final library name will be:
# - lib$(TARGETNAME).so for shared libraries
# - lib$(TARGETNAME).a for static libraries
TARGETNAME?=a.out

# Target type can be:
# - 'exec' for dynamic executable
# - 'staticexec' for static executable
# - 'lib' to build as library (both shared and static)
# - 'sharedlib' for shared library
# - 'staticlib' for static library
TARGETTYPE?=exec

# Set to 'y' to enable DEBUG
# Set to 'a' to enable DEBUG and ASAN support
DEBUG?=n

# 'y' -> if you want this Makefile to use 'sudo' when installing target or
# 	 creating a package
# 'n' -> if you want to type 'sudo' yourself whenever you think you need to.
USESUDO?=y

# Change the build output directory (default is .)
BUILD_OUTPUT?=

# Add here extra include directories (EXTRA_DIRS are automatically added)
#INCFLAGS?=-I../your_include_directory

# Add here your -L and -l linker options
# Remember to add -lstdc++ when linking C++ code
LDFLAGS?=

# Add here the static libraries (*.a files) you want to link
# IMPORTANT NOTE
# The GNU ld linker is a so-called smart linker. It will keep track of the
# functions used by preceding static libraries, permanently tossing out those
# functions that are not used from its lookup tables. The result is that if you
# link a static library too early, then the functions in that library are no
# longer available to static libraries later on the link line.
# The typical UNIX linker works from left to right, so put all your dependent
# libraries on the left, and the ones that satisfy those dependencies on the
# right of the link line. You may find that some libraries depend on others
# while at the same time other libraries depend on them. This is where it gets
# complicated. When it comes to circular references, fix your code!
# For more info: http://stackoverflow.com/questions/45135/why-does-the-order-in-which-libraries-are-linked-sometimes-cause-errors-in-gcc
STATICLIBS?=

# file name for version file
VERSIONFILE?=version

# Author name
AUTHOR?=

##############################################################################
############################## Advanced tweaks ###############################
##############################################################################

# When building libraries set this variable to 'y' to manually select which
# function will be available through the library. If you choose to do this,
# remember to mark "__public" all the functions you want to export.
# For example:
#                 int __public mypublicfunc(void) { ... }
#
OPTIMIZE_LIB_VISIBILITY?=n

# Use this feature if you need to load a script that changes the environment
# for all the commands executed in this makefile
# i.e.: to me it is useful when I'm cross compiling to add the cross tools
#       to the PATH and LD_LIBRARY_PATH.
ENV_SCRIPT?=

ENV_SCRIPT_OUTPUT=/tmp/makeenv.$(TARGETNAME).$(TARGETTYPE)
ifneq ($(ENV_SCRIPT),)
IGNOREME := $(shell bash -c "source \"$(ENV_SCRIPT)\"; env | sed 's/=/:=/' | sed 's/^/export /' > \"$(ENV_SCRIPT_OUTPUT)\"")
include $(ENV_SCRIPT_OUTPUT)
endif

# Build also sources from all the directories listed in EXTRA_DIRS
# By default, files from all subdirectories are built.
# If you want to build only few directories, just list them in the variable.
# Not to include any directory, just leave the variable empty
ifeq ($(BUILD_OUTPUT),)
EXTRA_DIRS?=$(shell find -L . -mindepth 1 -path ./.git -prune -o \( -type d -a \! -empty \) -print)
SUBTARGETS_DIRS?=$(shell find -L . -mindepth 1 -path ./.git -prune -o \( -type d -a \! -empty \) -print)
else
EXTRA_DIRS?=$(shell find -L . -mindepth 1 -path ./.git -prune -o \( -type d -a \! -empty -a \! -samefile $(BUILD_OUTPUT) \) -print )
SUBTARGETS_DIRS?=$(shell find -L . -mindepth 1 -path ./.git -prune -o \( -type d -a \! -empty -a \! -samefile $(BUILD_OUTPUT) \) -print )
endif

_EXTRA_DIRS:=$(shell for i in $(EXTRA_DIRS) ; do if test ! -r $${i}/Makefile 2>/dev/null ; then echo $${i} ; fi ; done)
_SUBTARGETS_DIRS:=$(shell for i in $(SUBTARGETS_DIRS) ; do if test -r $${i}/Makefile 2>/dev/null ; then echo $${i} ; fi ; done)

# Uncomment (and eventually change the header file name)
# to install an header file along with your target
# (this is very common for libreries)
# It is allowed only one single file with extension .h
# Any file that it includes using doblue quotes (not angle brackets!) is going
# to be installed as well
#INSTALL_HEADER?=$(TARGETNAME).h

# The filesystem which you build against
# Note that in this file system will also be installed header files and libraries.
BUILDFS?=/

# The filesystem where you want your binary files (executables and shared
# libraries) to be installed into
INSTALL_ROOT?=$(BUILDFS)

INSTALL_PREFIX?=/usr/local

# INSTALL_PREFIX's subdirectory where to install targets
# Leave it commented to use defaults:
# - 'lib' (or lib64) for libraries, 'bin' for executables
#INSTALL_DIR?=mydir

#CROSS_COMPILE?=arm-arago-linux-gnueabi-
CROSS_COMPILE?=

ifneq ($(CROSS_COMPILE),)
	LIBSUBDIR?=lib
	CC=$(CROSS_COMPILE)gcc
	CXX=$(CROSS_COMPILE)g++
	CPP=$(CROSS_COMPILE)cpp
	AR=$(CROSS_COMPILE)ar
else
ifeq ($(shell uname -m), x86_64)
	LIBSUBDIR?=lib64
else
	LIBSUBDIR?=lib
endif
	CC?=gcc
	CXX?=g++
	CPP?=cpp
	AR?=ar
endif

POST_INSTALL_SCRIPT?=./post_install.sh
POST_INSTALL_SCRIPT_CMD?=BUILDFS="$(BUILDFS)" INSTALL_ROOT="$(INSTALL_ROOT)" INSTALL_PREFIX="$(INSTALL_PREFIX)" TARGETNAME="$(TARGETNAME)" $(POST_INSTALL_SCRIPT)

ifeq ($(USESUDO),y)
INSTALL?=sudo install -D
SUDORM?=sudo rm
RUN_POST_INSTALL_SCRIPT?=sudo $(POST_INSTALL_SCRIPT_CMD)
else
INSTALL?=install -D
SUDORM?=rm
RUN_POST_INSTALL_SCRIPT?=$(POST_INSTALL_SCRIPT_CMD)
endif

EXTRA_CFLAGS?=
CFLAGS?=$(EXTRA_CFLAGS) -Wall -Wextra -Wno-unused-parameter -fPIC # -Wno-missing-field-initializers
CXXFLAGS?=$(EXTRA_CFLAGS) -Wall -Wextra -Wno-unused-parameter -fPIC # -Wno-missing-field-initializers

LDFLAGS:=$(LDFLAGS) -L"$(BUILDFS)/$(INSTALL_PREFIX)/$(LIBSUBDIR)" 	\
		    -L"$(BUILDFS)/usr/$(LIBSUBDIR)"

ifeq ($(DEBUG),a)
	DEBUG=y
	USEASAN?=y
else
	USEASAN?=n
endif

# You might want to customize this...
ifeq ($(DEBUG),y)
	# The following flags are needed to support backtrace() function on
	# both x86 and arm.
	CFLAGS+= -g -O0 -rdynamic -fno-omit-frame-pointer -fno-inline -funwind-tables
	CXXFLAGS+= -g -O0 -rdynamic -fno-omit-frame-pointer -fno-inline -funwind-tables
	OPTIMIZE_LIB_VISIBILITY=n
	CFLAGS+=-D__public=
	CXXFLAGS+=-D__public=
else
	CFLAGS+= -O3 -DNDEBUG
	CXXFLAGS+= -O3 -DNDEBUG
endif

ifeq ($(USEASAN),y)
CFLAGS+=-fsanitize=address
CXXFLAGS+=-fsanitize=address
LDFLAGS+=-fsanitize=address
endif

##############################################################################
####### NOTE! You should not need to change anything below this line! ########
##############################################################################

CSRC:=$(shell for i in $(_EXTRA_DIRS) ; do ls $${i}/*.c 2>/dev/null ; done)
CSRC+=$(shell ls *.c 2>/dev/null)
CPPSRC1:=$(shell for i in $(_EXTRA_DIRS) ; do ls $${i}/*.cpp 2>/dev/null ; done)
CPPSRC1+=$(shell ls *.cpp 2>/dev/null)
CPPSRC2:=$(shell for i in $(_EXTRA_DIRS) ; do ls $${i}/*.cc 2>/dev/null ; done)
CPPSRC2+=$(shell ls *.cc 2>/dev/null)
CPPSRC3:=$(shell for i in $(_EXTRA_DIRS) ; do ls $${i}/*.C 2>/dev/null ; done)
CPPSRC3+=$(shell ls *.C 2>/dev/null)
CPPSRC:=$(CPPSRC1) $(CPPSRC2) $(CPPSRC3)
SRC:=$(CSRC) $(CPPSRC)
COBJ:=$(CSRC:.c=.o)
CPPOBJ:=$(CPPSRC1:.cpp=.o)
CPPOBJ+=$(CPPSRC2:.cc=.o)
CPPOBJ+=$(CPPSRC3:.C=.o)
OBJ:=$(COBJ) $(CPPOBJ)
DEP:=$(COBJ:.o=.d)
DEP+=$(CPPSRC1:.cpp=.dd1)
DEP+=$(CPPSRC2:.cc=.dd2)
DEP+=$(CPPSRC3:.C=.dd3)
ifneq ($(BUILD_OUTPUT),)
_CREATE_BUILD_OUTPUT:=$(shell mkdir -p $(BUILD_OUTPUT))
_CREATE_BUILD_OUTPUT:=$(shell for i in $(_EXTRA_DIRS) ; do mkdir -p $(BUILD_OUTPUT)/$${i} ; done)
# From now on, making sure there is a slash at the end
BUILD_OUTPUT:=$(BUILD_OUTPUT:%/=%)/
OBJ:=$(OBJ:%=$(BUILD_OUTPUT)%)
DEP:=$(DEP:%=$(BUILD_OUTPUT)%)
endif
HEADERS=$(shell ls *.h *.hpp 2> /dev/null)
HEADERS+=$(shell for i in $(_EXTRA_DIRS) ; do ls $${i}/*.h $${i}/*.hpp  2>/dev/null ; done)

.SECONDARY: $(DEP) $(OBJ)

INCFLAGS+=$(shell for i in $(_EXTRA_DIRS) ; do echo "-I$${i} " ; done)

# Please note that the order of "-I" directives is important. My choice is to
# first look for headers in the sources, and than in the system directories.
INCFLAGS:=-I. $(INCFLAGS) -I"$(BUILDFS)/$(INSTALL_PREFIX)/include" -I"$(BUILDFS)/usr/include"

CFLAGS+=$(INCFLAGS)
CXXFLAGS+=$(INCFLAGS)

LINK=$(CC)

TARGET=$(TARGETNAME)

ifeq ($(TARGETTYPE),exec)
	TARGETEXT=$(TARGETNAME)
	INSTALL_DIR?=bin
	OPTIMIZE_LIB_VISIBILITY=n
endif

ifeq ($(TARGETTYPE),staticexec)
	TARGETEXT=$(TARGETNAME)
	LINK+=-static
	INSTALL_DIR?=bin
	OPTIMIZE_LIB_VISIBILITY=n
endif

ifeq ($(TARGETTYPE),sharedlib)
	TARGET=lib$(TARGETNAME).so
	TARGETEXT=$(TARGETNAME)lib
	LDFLAGS+=-Wl,-soname,$(TARGET) -shared
	INSTALL_DIR?=$(LIBSUBDIR)
endif

ifeq ($(TARGETTYPE),lib)
	# Same as sharedlib!
	TARGET=lib$(TARGETNAME).so
	TARGETEXT=$(TARGETNAME)lib
	LDFLAGS+=-Wl,-soname,$(TARGET) -shared
	INSTALL_DIR?=$(LIBSUBDIR)
endif

ifeq ($(TARGETTYPE),staticlib)
	TARGET=lib$(TARGETNAME).a
	TARGETEXT=$(TARGETNAME)lib
	INSTALL_DIR?=$(LIBSUBDIR)
endif

# Checking if we are in a git repo or not
USINGGIT?=$(shell if git remote show -n &>/dev/null ;then echo -n y ; fi)
ifeq ($(USINGGIT),y)
	COMMIT=$(shell git rev-parse HEAD)
	DATE?=$(shell git show -s --format=%ci HEAD | cut -d ' ' -f 1)
	USINGGIT=$(shell if git describe --abbrev=0 --tags &>/dev/null ; then echo -n y ; else echo -n n ; fi)
endif
ifeq ($(USINGGIT),y)
	LATEST_TAG=$(shell git describe --abbrev=0 --tags)
	COUNT_EXTRA_COMMITS=$(shell git rev-list $(LATEST_TAG)..HEAD --count)
	VERSION?=$(LATEST_TAG).$(COUNT_EXTRA_COMMITS)
else
	COMMIT?='Not in a git repository'
	DATE?=$(shell date +%s)
	VERSION?=latest
endif

TMPDIR=$(shell readlink -mn $(BUILD_OUTPUT)._tmp)
PKG?=$(BUILD_OUTPUT)$(TARGETEXT).tar.gz
PKG:=$(shell readlink -mn $(PKG))
BINPKG?=$(BUILD_OUTPUT)$(TARGETEXT)-bin.tar.gz
BINPKG:=$(shell readlink -mn $(BINPKG))
DEVPKG?=$(BUILD_OUTPUT)$(TARGETEXT)-dev.tar.gz
DEVPKG:=$(shell readlink -mn $(DEVPKG))
SRCPKGDIR?=$(TARGETEXT)-src
SRCPKG?=$(BUILD_OUTPUT)$(TARGETEXT)-src-$(VERSION).tar.gz
SRCPKG:=$(shell readlink -mn $(SRCPKG))

ifneq ($(INSTALL_HEADER),)
	# Note that here I use := instead of = because I want CFLAGS to expand
	# immediately (before including $(VISHEADER))
	HEADERS_TO_INSTALL:=$(shell PATH="$(PATH)" $(CPP) $(CFLAGS) $(CXXFLAGS) -MM $(INSTALL_HEADER) | sed 's,\($*\)\.o[ :]*,\1.h: ,g' | sed 's,\\,,g')
	HEADERS_INSTALL_DIR=$(BUILDFS)/$(INSTALL_PREFIX)/include
endif

ifeq ($(OPTIMIZE_LIB_VISIBILITY),y)
	VISHEADER=$(BUILD_OUTPUT)__vis.h
	HEADERS+=$(VISHEADER)
	CFLAGS+=-fvisibility=hidden -include $(VISHEADER)
	CXXFLAGS+=-fvisibility=hidden -include $(VISHEADER)
else
	VISHEADER=
endif

INSTALL_TARGET=$(INSTALL_ROOT)/$(INSTALL_PREFIX)/$(INSTALL_DIR)/$(shell basename $(TARGET))
BUILDFS_TARGET=$(BUILDFS)/$(INSTALL_PREFIX)/$(INSTALL_DIR)/$(shell basename $(TARGET))

CTAGS=$(shell which ctags 2>/dev/null)

ifneq ($(CTAGS),)
	CTAGSTARGET=$(BUILD_OUTPUT)tags
else
	CTAGSTARGET=
endif

TARGET:=$(BUILD_OUTPUT)$(TARGET)

ifeq ($(TARGETTYPE),lib)
	ALLTARGETS=$(TARGET) $(TARGET:.so=.a)
else
	ALLTARGETS=$(TARGET)
endif

INSTALLTARGETS=$(ALLTARGETS)

ifneq ($(INSTALL_HEADER),)
	TARGET_HEADERS:=$(HEADERS_INSTALL_DIR)/$(shell basename $(INSTALL_HEADER))
endif


all: target subtargets $(CTAGSTARGET)

target: $(ALLTARGETS)

subtargets: target
	+@for t in $(_SUBTARGETS_DIRS) ; do	\
		USEASAN=$(USEASAN) make -C $$t || break;	\
	done

$(BUILD_OUTPUT)%.a: $(OBJ)
	$(AR) -rcs $@ $(OBJ)

ifneq ($(BUILD_OUTPUT),)
$(BUILD_OUTPUT)%.o: %.o
	@mv $^ $@
endif

ifneq ($(TARGETTYPE),staticlib)
$(TARGET): $(OBJ)
	$(LINK) $(OBJ) $(STATICLIBS) $(LDFLAGS) -o $@
endif

ifneq ($(MAKECMDGOALS:clean%=CLEAN),CLEAN)
-include $(DEP)
endif

# These few lines were inspired by:
# http://www.makelinux.net/make3/make3-CHP-2-SECT-7
# Note: use -MM instead of -M if you do not want to include system headers in
#       the dependencies
$(BUILD_OUTPUT)%.d: %.c $(VISHEADER)
	@$(CC) $(CFLAGS) -MM -MT $@ $< > $@.$$$$;		\
	sed 's,\($*\)\.d[ :]*,\1.o $@ : ,g' < $@.$$$$ > $@;	\
	rm -f $@.$$$$

$(BUILD_OUTPUT)%.dd1: %.cpp $(VISHEADER)
	@$(CXX) $(CXXFLAGS) -MM -MT $@ $< > $@.$$$$;		\
	sed 's,\($*\)\.dd1[ :]*,\1.o $@ : ,g' < $@.$$$$ > $@;	\
	rm -f $@.$$$$

$(BUILD_OUTPUT)%.dd2: %.cc $(VISHEADER)
	@$(CXX) $(CXXFLAGS) -MM -MT $@ $< > $@.$$$$;		\
	sed 's,\($*\)\.ddd2[ :]*,\1.o $@ : ,g' < $@.$$$$ > $@;	\
	rm -f $@.$$$$

$(BUILD_OUTPUT)%.dd3: %.C $(VISHEADER)
	@$(CXX) $(CXXFLAGS) -MM -MT $@ $< > $@.$$$$;		\
	sed 's,\($*\)\.dd3[ :]*,\1.o $@ : ,g' < $@.$$$$ > $@;	\
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

$(BUILD_OUTPUT)tags: $(SRC) $(HEADERS)
	@$(CTAGS) -f $@ $^

post-install-script:
ifneq ($(POST_INSTALL_SCRIPT),)
	@test ! -x $(POST_INSTALL_SCRIPT) || $(RUN_POST_INSTALL_SCRIPT) $@
	@for t in $(_SUBTARGETS_DIRS) ; do			\
		INSTALL_ROOT="$(INSTALL_ROOT)"			\
		BUILDFS="$(BUILDFS)"				\
			make -C $$t $@ || break ;		\
	done
endif

install: $(INSTALLTARGETS) install-bin-pkg install-dev-pkg post-install-script

install-bin install-bin-pkg: $(INSTALLTARGETS)
ifneq ($(TARGETTYPE),staticlib)
	@echo "Installing binaries to your root filesystem:"
	@echo " * $(TARGET) -> \"$(INSTALL_TARGET)\""
	@$(INSTALL) $(TARGET) "$(INSTALL_TARGET)"
endif
	@for t in $(_SUBTARGETS_DIRS) ; do			\
		INSTALL_ROOT="$(INSTALL_ROOT)"			\
		BUILDFS="$(BUILDFS)"				\
			make -C $$t $@ || break ;		\
	done

install-dev install-dev-pkg: $(TARGET_HEADERS) $(INSTALLTARGETS)
ifneq ($(findstring lib,$(TARGETTYPE)),)
ifneq ($(INSTALL_ROOT),$(BUILDFS))
	@echo "Installing binaries to your build filesystem:"
	@echo " * $(TARGET) -> \"$(BUILDFS_TARGET)\""
	@$(INSTALL) $(TARGET) "$(BUILDFS_TARGET)"
endif
ifeq ($(TARGETTYPE),lib)
	@echo " * $(TARGET:.so=.a) -> \"$(BUILDFS_TARGET:.so=.a)\""
	@$(INSTALL) $(TARGET:.so=.a) "$(BUILDFS_TARGET:.so=.a)"
endif
endif
	@for t in $(_SUBTARGETS_DIRS) ; do			\
		INSTALL_ROOT="$(INSTALL_ROOT)"			\
		BUILDFS="$(BUILDFS)"				\
			make -C $$t $@ || break ;		\
	done

ifneq ($(HEADERS_TO_INSTALL),)
$(HEADERS_INSTALL_DIR)/$(HEADERS_TO_INSTALL) $(INSTALL_HEADER)
	@echo "Installing headers to your build filesystem:"
	@for h in $^ ; do						\
		test "$$h" = "$(HEADERS_INSTALL_DIR)/$$h" && continue;	\
		echo " * $$h -> \"$(HEADERS_INSTALL_DIR)/$$h\"";	\
		$(INSTALL) $$h "$(HEADERS_INSTALL_DIR)/$$h";		\
	done
endif

$(VERSIONFILE):
	@echo "$(TARGETEXT) $(VERSION)" > $@
	@echo "Commit: $(COMMIT)" >> $@
ifneq ($(AUTHOR),)
	@echo "Copyright ${AUTHOR}"  >> $@
endif
	@echo "Release date: $(DATE)" >> $@
	@echo "Package created: $(shell date)" >> $@
	@echo "Version file:"
	@cat $@

$(TMPDIR):
	@$(SUDORM) -rf "$(TMPDIR)"
	@mkdir -p "$@"

pkg: clean-files $(TMPDIR) all
	@INSTALL_ROOT="$(TMPDIR)" BUILDFS="$(TMPDIR)" make	\
			install-bin-pkg install-dev-pkg post-install-script
	make $(PKG)

bin-pkg: clean-files $(TMPDIR) all
	@INSTALL_ROOT="$(TMPDIR)" make install-bin-pkg post-install-script
	make $(BINPKG)

dev-pkg: clean-files $(TMPDIR) all
	@BUILDFS="$(TMPDIR)" make install-dev-pkg post-install-script
	make $(DEVPKG)

src-pkg: $(TMPDIR)
	@mkdir -p "$(TMPDIR)/$(SRCPKGDIR)"
	@cp -rHv * "$(TMPDIR)/$(SRCPKGDIR)"
	@make -C "$(TMPDIR)/$(SRCPKGDIR)" clean
	@make -C "$(TMPDIR)/$(SRCPKGDIR)" $(VERSIONFILE)
	@make -C "$(TMPDIR)/$(SRCPKGDIR)" clean-files clean-pkg
	@make $(SRCPKG)

$(PKG) $(BINPKG) $(DEVPKG) $(SRCPKG): FORCE
	@if rmdir "$(TMPDIR)" 2>&1 >/dev/null ;then echo "Nothing to pack" && \
								exit 1; fi
	cd "$(TMPDIR)" && tar czvf $@ --exclude=.gitignore *
	@$(SUDORM) -rf "$(TMPDIR)"
	@echo ""
	@echo "Package $@ built"
	@echo ""

FORCE:

.PHONY: all FORCE clean clean-files clean-pkg clean-subtargets		\
	install install-bin install-bin-pkg install-dev install-dev-pkg	\
	post-install-script bin-pkg dev-pkg pkg target subtargets

clean-subtargets:
	@for t in $(_SUBTARGETS_DIRS) ; do	\
		make -C $$t clean;		\
	done

clean-files: clean-subtargets
	@rm -vf $(BUILD_OUTPUT)*.d $(BUILD_OUTPUT)*.dd? $(BUILD_OUTPUT)*.o
	@for i in $(_EXTRA_DIRS) ; do				\
		rm -vf $(BUILD_OUTPUT)$${i}/*.d ; 		\
		rm -vf $(BUILD_OUTPUT)$${i}/*.dd? ;		\
		rm -vf $(BUILD_OUTPUT)$${i}/*.o ; 		\
	done
	@rm -vf $(TARGET) $(BUILD_OUTPUT)tags $(VISHEADER)
ifeq ($(TARGETTYPE),lib)
	@rm -vf "$(TARGET:.so=.a)"
endif
	@if [ -d "$(TMPDIR)" ]; then		\
		$(SUDORM) -rf "$(TMPDIR)" ;	\
	fi

clean-pkg:
	@rm -vf $(PKG) $(BINPKG) $(DEVPKG) $(SRCPKG)

clean: clean-files clean-pkg
ifneq ($(BUILD_OUTPUT),)
	@for i in $$(find $(BUILD_OUTPUT) -mindepth 1 -type d | sort -r); do \
		rmdir -v $${i} ; done
endif
	@rm -f "$(ENV_SCRIPT_OUTPUT)"
