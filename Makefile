###########################################################################
#
#   makefile
#
#   Core makefile for building MAME and derivatives
#
#   Copyright (c) Nicola Salmoria and the MAME Team.
#   Visit http://mamedev.org for licensing and usage restrictions.
#
###########################################################################

NATIVE :=0

UNAME=$(shell uname -a)

ifeq ($(platform),)
platform = unix
ifeq ($(UNAME),)
   platform = win
else ifneq ($(findstring MINGW,$(UNAME)),)
   platform = win
else ifneq ($(findstring Darwin,$(UNAME)),)
   platform = osx
else ifneq ($(findstring win,$(UNAME)),)
   platform = win
endif
endif

# system platform
system_platform = unix
ifeq ($(UNAME),)
EXE_EXT = .exe
   system_platform = win
else ifneq ($(findstring Darwin,$(UNAME)),)
   system_platform = osx
else ifneq ($(findstring MINGW,$(UNAME)),)
   system_platform = win
endif

# CR/LF setup: use both on win32/os2, CR only on everything else
DEFS = -DCRLF=2 
# Default to something reasonable for all platforms
ARFLAGS = -cr

TARGET_NAME := mame2009
EXE = 
LIBS = 

#-------------------------------------------------
# compile flags
# CCOMFLAGS are common flags
# CONLYFLAGS are flags only used when compiling for C
# CPPONLYFLAGS are flags only used when compiling for C++
# COBJFLAGS are flags only used when compiling for Objective-C(++)
#-------------------------------------------------

# start with empties for everything
CCOMFLAGS = 
CONLYFLAGS =
COBJFLAGS =
CPPONLYFLAGS =
# LDFLAGS are used generally; LDFLAGSEMULATOR are additional
# flags only used when linking the core emulator
LDFLAGS =
LDFLAGSEMULATOR =

GIT_VERSION ?= " $(shell git rev-parse --short HEAD || echo unknown)"
ifneq ($(GIT_VERSION)," unknown")
	CCOMFLAGS += -DGIT_VERSION=\"$(GIT_VERSION)\"
endif

# uncomment next line to build zlib as part of MAME build
#BUILD_ZLIB = 1

# uncomment next line to build PortMidi as part of MAME/MESS build
#BUILD_MIDILIB = 1
VRENDER ?= soft

PLATCFLAGS += -D__LIBRETRO__
CCOMFLAGS  += -D__LIBRETRO__

fpic := 
ALIGNED = 0

ifeq ($(VRENDER),opengl)  
	PLATCFLAGS += -DHAVE_OPENGL
	CCOMFLAGS  += -DHAVE_OPENGL
endif

UNAME=$(shell uname -m)

ifeq ($(firstword $(filter x86_64,$(UNAME))),x86_64)
PTR64 = 1
endif
ifeq ($(firstword $(filter amd64,$(UNAME))),amd64)
PTR64 = 1
endif
ifeq ($(firstword $(filter ppc64,$(UNAME))),ppc64)
PTR64 = 1
endif
ifneq (,$(findstring mingw64-w64,$(PATH)))
PTR64=1
endif
ifneq (,$(findstring Power,$(UNAME)))
BIGENDIAN=1
endif
ifneq (,$(findstring ppc,$(UNAME)))
BIGENDIAN=1
endif

CORE_DIR = .

# UNIX
ifeq ($(platform), unix)
   TARGETLIB := $(TARGET_NAME)_libretro.so
	TARGETOS=linux  
   fpic = -fPIC
   SHARED := -shared -Wl,--version-script=src/osd/retro/link.T
   CCOMFLAGS += -fsigned-char -finline  -fno-common -fno-builtin -fweb -frename-registers -falign-functions=16 -fsingle-precision-constant
	ALIGNED=1
   PLATCFLAGS += -fstrict-aliasing -fno-merge-constants 
ifeq ($(VRENDER),opengl)  
   LIBS += -lGL
endif
LDFLAGS += $(SHARED)
   NATIVELD = gcc
   NATIVELDFLAGS = -Wl,--warn-common -lstdc++
   NATIVECC = g++
   NATIVECFLAGS = -std=gnu99
   CC_AS = gcc 
   CC = gcc
   AR = @ar
   LD = gcc 
   CCOMFLAGS += $(PLATCFLAGS) -ffast-math  
   LIBS += -lpthread 

# Android
else ifeq ($(platform), android)
EXTRA_RULES = 1
ARM_ENABLED = 1
   TARGETLIB := $(TARGET_NAME)_libretro_android.so
	TARGETOS=linux  
   fpic = -fPIC
   SHARED := -shared -Wl,--version-script=src/osd/retro/link.T
	CC_AS = @arm-linux-androideabi-gcc
	CC = @arm-linux-androideabi-g++
	AR = @arm-linux-androideabi-ar
	LD = @arm-linux-androideabi-g++ 
	ALIGNED=1
	FORCE_DRC_C_BACKEND = 1
	CCOMFLAGS += -mstructure-size-boundary=32 -mthumb-interwork -falign-functions=16 -fsigned-char -finline  -fno-common -fno-builtin -fweb -frename-registers -falign-functions=16 -fsingle-precision-constant
	PLATCFLAGS += -march=armv7-a -mfloat-abi=softfp -fstrict-aliasing -fno-merge-constants -DSDLMAME_NO64BITIO -DANDTIME -DRANDPATH
	PLATCFLAGS += -DANDROID
	LDFLAGS += -Wl,--fix-cortex-a8 -llog $(SHARED)
	NATIVELD = g++
	NATIVELDFLAGS = -Wl,--warn-common -lstdc++
	NATIVECC = g++
	NATIVECFLAGS = -std=gnu99 
	CCOMFLAGS += $(PLATCFLAGS) -ffast-math  
	LIBS += -lstdc++ 

# OS X
else ifeq ($(platform), osx)
   TARGETLIB := $(TARGET_NAME)_libretro.dylib
	TARGETOS = macosx
   fpic = -fPIC
LDFLAGSEMULATOR +=  -stdlib=libc++
   SHARED := -dynamiclib
   CC = c++ -stdlib=libc++
   LD = c++ -stdlib=libc++
   NATIVELD = c++ -stdlib=libc++
   NATIVECC = c++
	LDFLAGS +=  $(SHARED)
   CC_AS = clang
   AR = @ar
ifeq ($(COMMAND_MODE),"legacy")
ARFLAGS = -crs
endif

# iOS
else ifneq (,$(findstring ios,$(platform)))

   TARGETLIB := $(TARGET_NAME)_libretro_ios.dylib
   TARGETOS = macosx
   EXTRA_RULES = 1
   ARM_ENABLED = 1
   fpic = -fPIC
   SHARED := -dynamiclib
   PTR64 = 0

ifeq ($(IOSSDK),)
IOSSDK := $(shell xcodebuild -version -sdk iphoneos Path)
endif

   CC = c++ -arch armv7 -isysroot $(IOSSDK)
   CCOMFLAGS += -DSDLMAME_NO64BITIO -DIOS
   CFLAGS += -DIOS
   CXXFLAGS += -DIOS
   NATIVELD = $(CC) -stdlib=libc++
   LDFLAGS +=  $(SHARED)
   LD = $(CC)

# QNX
else ifeq ($(platform), qnx)
   TARGETLIB := $(TARGET_NAME)_libretro_$(platform).so
	TARGETOS=linux  
   fpic = -fPIC
   SHARED := -shared -Wl,--version-script=src/osd/retro/link.T

   CC = qcc -Vgcc_ntoarmv7le
   AR = qcc -Vgcc_ntoarmv7le
   CFLAGS += -D__BLACKBERRY_QNX__
	LIBS += -lstdc++ -lpthread

# PS3
else ifeq ($(platform), ps3)
   TARGETLIB := $(TARGET_NAME)_libretro_$(platform).a
   CC = $(CELL_SDK)/host-win32/ppu/bin/ppu-lv2-gcc.exe
   AR = $(CELL_SDK)/host-win32/ppu/bin/ppu-lv2-ar.exe
   CFLAGS += -DBLARGG_BIG_ENDIAN=1 -D__ppc__
	STATIC_LINKING = 1
	BIGENDIAN=1
	LIBS += -lstdc++ -lpthread

# PS3 (SNC)
else ifeq ($(platform), sncps3)
   TARGETLIB := $(TARGET_NAME)_libretro_ps3.a
   CC = $(CELL_SDK)/host-win32/sn/bin/ps3ppusnc.exe
   AR = $(CELL_SDK)/host-win32/sn/bin/ps3snarl.exe
   CFLAGS += -DBLARGG_BIG_ENDIAN=1 -D__ppc__
	STATIC_LINKING = 1
	BIGENDIAN=1
	LIBS += -lstdc++ -lpthread

# Lightweight PS3 Homebrew SDK
else ifeq ($(platform), psl1ght)
   TARGETLIB := $(TARGET_NAME)_libretro_$(platform).a
   CC = $(PS3DEV)/ppu/bin/ppu-gcc$(EXE_EXT)
   AR = $(PS3DEV)/ppu/bin/ppu-ar$(EXE_EXT)
   CFLAGS += -DBLARGG_BIG_ENDIAN=1 -D__ppc__
	STATIC_LINKING = 1
	BIGENDIAN=1
	LIBS += -lstdc++ -lpthread

# PSP
else ifeq ($(platform), psp1)
	TARGETLIB := $(TARGET_NAME)_libretro_$(platform).a
	CC = psp-g++$(EXE_EXT)
	AR = psp-ar$(EXE_EXT)
	CFLAGS += -DPSP -G0
	STATIC_LINKING = 1
	LIBS += -lstdc++ -lpthread

# Xbox 360
else ifeq ($(platform), xenon)
   TARGETLIB := $(TARGET_NAME)_libretro_xenon360.a
   CC = xenon-g++$(EXE_EXT)
   AR = xenon-ar$(EXE_EXT)
   CFLAGS += -D__LIBXENON__ -m32 -D__ppc__
	STATIC_LINKING = 1
	BIGENDIAN=1
	LIBS += -lstdc++ -lpthread
# Nintendo Wii U
else ifeq ($(platform), wiiu)
   TARGETLIB := $(TARGET_NAME)_libretro_wiiu.a
   CC = $(DEVKITPPC)/bin/powerpc-eabi-gcc$(EXE_EXT)
   CXX = $(DEVKITPPC)/bin/powerpc-eabi-g++$(EXE_EXT)
   AR = $(DEVKITPPC)/bin/powerpc-eabi-ar$(EXE_EXT)
   COMMONFLAGS += -DGEKKO -D__wiiu__ -mcpu=750 -meabi -mhard-float -D__POWERPC__ -D__ppc__ -DWORDS_BIGENDIAN=1 -malign-natural
   COMMONFLAGS += -U__INT32_TYPE__ -U __UINT32_TYPE__ -D__INT32_TYPE__=int -fsingle-precision-constant -mno-bit-align
   COMMONFLAGS += -DHAVE_STRTOUL -DBIGENDIAN=1 -DWIIU -DOLEFIX
   DEFS       += -DMSB_FIRST
   PLATCFLAGS += -DMSB_FIRST
   BIGENDIAN=1
   STATIC_LINKING = 1
   FORCE_DRC_C_BACKEND = 1
   PLATCFLAGS += -DSDLMAME_NO64BITIO $(COMMONFLAGS) -falign-functions=16
   PTR64 = 0
   REALCC   = $(DEVKITPPC)/bin/powerpc-eabi-gcc$(EXE_EXT)
   NATIVECC = g++
   NATIVECFLAGS = -std=gnu99
   CCOMFLAGS += $(PLATCFLAGS)
# Nintendo Game Cube
else ifeq ($(platform), ngc)
   TARGETLIB := $(TARGET_NAME)_libretro_$(platform).a
	CC = $(DEVKITPPC)/bin/powerpc-eabi-g++$(EXE_EXT)
   AR = $(DEVKITPPC)/bin/powerpc-eabi-ar$(EXE_EXT)
   CFLAGS += -DGEKKO -DHW_DOL -mrvl -mcpu=750 -meabi -mhard-float -DBLARGG_BIG_ENDIAN=1 -D__ppc__
	STATIC_LINKING = 1
	BIGENDIAN=1
	LIBS += -lstdc++ -lpthread

# Nintendo Wii
else ifeq ($(platform), wii)
   TARGETLIB := $(TARGET_NAME)_libretro_$(platform).a
   CC = $(DEVKITPPC)/bin/powerpc-eabi-g++$(EXE_EXT)
   AR = $(DEVKITPPC)/bin/powerpc-eabi-ar$(EXE_EXT)
   CFLAGS += -DGEKKO -DHW_RVL -mrvl -mcpu=750 -meabi -mhard-float -DBLARGG_BIG_ENDIAN=1 -D__ppc__
	STATIC_LINKING = 1
	BIGENDIAN=1
	LIBS += -lstdc++ -lpthread

# ARM
else ifneq (,$(findstring armv,$(platform)))
   TARGETLIB := $(TARGET_NAME)_libretro.so
   SHARED := -shared -Wl,--no-undefined
   fpic = -fPIC
   CC = g++
ifneq (,$(findstring cortexa8,$(platform)))
   CFLAGS += -marm -mcpu=cortex-a8
   ASFLAGS += -mcpu=cortex-a8
else ifneq (,$(findstring cortexa9,$(platform)))
   CFLAGS += -marm -mcpu=cortex-a9
   ASFLAGS += -mcpu=cortex-a9
endif
   CFLAGS += -marm
ifneq (,$(findstring neon,$(platform)))
   CFLAGS += -mfpu=neon
   ASFLAGS += -mfpu=neon
   HAVE_NEON = 1
endif
ifneq (,$(findstring softfloat,$(platform)))
   CFLAGS += -mfloat-abi=softfp
   ASFLAGS += -mfloat-abi=softfp
else ifneq (,$(findstring hardfloat,$(platform)))
   CFLAGS += -mfloat-abi=hard
   ASFLAGS += -mfloat-abi=hard
endif
   CFLAGS += -DARM
	LIBS += -lstdc++ -lpthread

else ifeq ($(platform), wincross)
   TARGETLIB := $(TARGET_NAME)_libretro.dll
	TARGETOS = win32
	CC ?= g++
	LD ?= g++
	NATIVELD = $(LD)
	CC_AS ?= gcc

	SHARED := -shared -static-libgcc -static-libstdc++ -s -Wl,--version-script=src/osd/retro/link.T
	CCOMFLAGS +=-D__WIN32__ -D__WIN32_LIBRETRO__
ifeq ($(VRENDER),opengl)  
	LIBS += -lopengl32
endif
	LDFLAGS +=   $(SHARED)
	EXE = .exe
	DEFS = -DCRLF=3

# Windows
else
   TARGETLIB := $(TARGET_NAME)_libretro.dll
	TARGETOS = win32
	CC = g++
	LD = g++
	NATIVELD = $(LD)
	CC_AS = gcc
	SHARED := -shared -static-libgcc -static-libstdc++ -Wl,--version-script=src/osd/retro/link.T
ifneq ($(MDEBUG),1)
	SHARED += -s
endif
CCOMFLAGS += -D__WIN32__ -D__WIN32_LIBRETRO__
ifeq ($(VRENDER),opengl)  
	LIBS += -lopengl32
endif
	LDFLAGS +=   $(SHARED)
	EXE = .exe
	DEFS = -DCRLF=3
	DEFS += -DX64_WINDOWS_ABI
endif



ifeq ($(ALIGNED),1)
	PLATCFLAGS += -DALIGN_INTS -DALIGN_SHORTS 
endif

CCOMFLAGS += $(fpic)
LDFLAGS   += $(fpic)

###########################################################################
#################   BEGIN USER-CONFIGURABLE OPTIONS   #####################
###########################################################################

NOWERROR = 1

#-------------------------------------------------
# specify core target: mame, mess, etc.
# specify subtarget: mame, mess, tiny, etc.
# build rules will be included from 
# src/$(TARGET)/$(SUBTARGET).mak
#-------------------------------------------------

ifndef TARGET
TARGET = mame
endif

ifndef SUBTARGET
SUBTARGET = $(TARGET)
endif



#-------------------------------------------------
# specify OSD layer: windows, sdl, etc.
# build rules will be included from 
# src/osd/$(OSD)/$(OSD).mak
#-------------------------------------------------

ifndef OSD
OSD = retro
endif

ifndef CROSS_BUILD_OSD
CROSS_BUILD_OSD = $(OSD)
endif



#-------------------------------------------------
# specify OS target, which further differentiates
# the underlying OS; supported values are:
# win32, unix, macosx, os2
#-------------------------------------------------




#-------------------------------------------------
# configure name of final executable
#-------------------------------------------------

# uncomment and specify prefix to be added to the name
# PREFIX =

# uncomment and specify suffix to be added to the name
# SUFFIX =



#-------------------------------------------------
# specify architecture-specific optimizations
#-------------------------------------------------

# uncomment and specify architecture-specific optimizations here
# some examples:
#   optimize for I686:   ARCHOPTS = -march=pentiumpro
#   optimize for Core 2: ARCHOPTS = -march=pentium-m -msse3
#   optimize for G4:     ARCHOPTS = -mcpu=G4
# note that we leave this commented by default so that you can
# configure this in your environment and never have to think about it
# ARCHOPTS =



#-------------------------------------------------
# specify program options; see each option below 
# for details
#-------------------------------------------------

# uncomment next line to build a debug version
# DEBUG = 1

# uncomment next line to include the internal profiler
# PROFILER = 1

# uncomment the force the universal DRC to always use the C backend
# you may need to do this if your target architecture does not have
# a native backend
# FORCE_DRC_C_BACKEND = 1



#-------------------------------------------------
# specify build options; see each option below 
# for details
#-------------------------------------------------

# uncomment next line if you are building for a 64-bit target
# PTR64 = 1

# uncomment next line if you are building for a big-endian target
# BIGENDIAN = 1

# uncomment next line to build expat as part of MAME build
#BUILD_EXPAT = 1

# uncomment next line to build zlib as part of MAME build
#BUILD_ZLIB = 1

# uncomment next line to include the symbols
# SYMBOLS = 1

# uncomment next line to include profiling information from the compiler
# PROFILE = 1

# uncomment next line to generate a link map for exception handling in windows
# MAP = 1

# uncomment next line to generate verbose build information
# VERBOSE = 1

# specify optimization level or leave commented to use the default
# (default is OPTIMIZE = 3 normally, or OPTIMIZE = 0 with symbols)
# OPTIMIZE = 3

# experimental: uncomment to compile everything as C++ for stricter type checking
# CPP_COMPILE = 1

ifeq ($(platform), wiiu)
OPTIMIZE = s
else
OPTIMIZE = 3
endif

###########################################################################
##################   END USER-CONFIGURABLE OPTIONS   ######################
###########################################################################


#-------------------------------------------------
# sanity check the configuration
#-------------------------------------------------

# specify a default optimization level if none explicitly stated
ifndef OPTIMIZE
ifndef SYMBOLS
OPTIMIZE = 3
else
OPTIMIZE = 0
endif
endif

# profiler defaults to on for DEBUG builds
ifdef DEBUG
ifndef PROFILER
PROFILER = 1
endif
endif



#-------------------------------------------------
# platform-specific definitions
#-------------------------------------------------

# extension for executables
EXE = 

#ifeq ($(TARGETOS),win32)
#EXE = .exe
#endif
#ifeq ($(TARGETOS),os2)
#EXE = .exe
#endif

#ifndef BUILD_EXE
#BUILD_EXE = $(EXE)
#endif

# compiler, linker and utilities
#AR = @ar
#CC = @gcc
#LD = @gcc
MD = -mkdir$(EXE)
RM = @rm -f
OBJDUMP = @objdump


#-------------------------------------------------
# form the name of the executable
#-------------------------------------------------

SUFFIX64 =
SUFFIXDEBUG =
SUFFIXPROFILE =

# 64-bit builds get a '64' suffix
ifeq ($(PTR64),1)
SUFFIX64 = 64
endif

# debug builds just get the 'd' suffix and nothing more
ifdef DEBUG
DEBUGSUFFIX = d
endif

# cpp builds get a 'pp' suffix
#ifdef CPP_COMPILE
#CPPSUFFIX = pp
#endif

# the name is just 'target' if no subtarget; otherwise it is
# the concatenation of the two (e.g., mametiny)
ifeq ($(TARGET),$(SUBTARGET))
NAME = $(TARGET)
else
NAME = $(TARGET)$(SUBTARGET)
endif

# fullname is prefix+name+suffix+debugsuffix
FULLNAME = $(PREFIX)$(NAME)$(CPPSUFFIX)$(SUFFIX)$(DEBUGSUFFIX)

# add an EXE suffix to get the final emulator name
#EMULATOR = $(FULLNAME)$(EXE)
EMULATOR = $(TARGET)


#-------------------------------------------------
# source and object locations
#-------------------------------------------------

# all sources are under the src/ directory
SRC = src

# build the targets in different object dirs, so they can co-exist
#OBJ = obj/$(OSD)/$(FULLNAME)
OBJ = obj/$(PREFIX)$(OSD)$(SUFFIX)$(SUFFIX64)$(SUFFIXDEBUG)$(SUFFIXPROFILE)



#-------------------------------------------------
# compile-time definitions
#-------------------------------------------------

# CR/LF setup: use both on win32/os2, CR only on everything else
#DEFS = -DCRLF=2

#ifeq ($(TARGETOS),win32)
#DEFS = -DCRLF=3
#endif
#ifeq ($(TARGETOS),os2)
#DEFS = -DCRLF=3
#endif

# map the INLINE to something digestible by GCC
DEFS += -DINLINE="static __inline__"

# define LSB_FIRST if we are a little-endian target
ifndef BIGENDIAN
DEFS += -DLSB_FIRST
endif

ifdef BIGENDIAN
DEFS       += -DMSB_FIRST
PLATCFLAGS += -DMSB_FIRST
endif

# define PTR64 if we are a 64-bit target
ifeq ($(PTR64),1)
DEFS += -DPTR64
endif

# define MAME_DEBUG if we are a debugging build
ifdef DEBUG
DEFS += -DMAME_DEBUG
else
DEFS += -DNDEBUG 
endif

# define MAME_PROFILER if we are a profiling build
ifdef PROFILER
DEFS += -DMAME_PROFILER
endif



#-------------------------------------------------
# compile flags
# CCOMFLAGS are common flags
# CONLYFLAGS are flags only used when compiling for C
# CPPONLYFLAGS are flags only used when compiling for C++
#-------------------------------------------------

# start with empties for everything
#CCOMFLAGS =
#CONLYFLAGS =
#CPPONLYFLAGS =

# CFLAGS is defined based on C or C++ targets
# (remember, expansion only happens when used, so doing it here is ok)
ifdef CPP_COMPILE
CFLAGS = $(CCOMFLAGS) $(CPPONLYFLAGS)
else
CFLAGS = $(CCOMFLAGS) $(CONLYFLAGS)
endif

# we compile C-only to C89 standard with GNU extensions
# we compile C++ code to C++98 standard with GNU extensions
CONLYFLAGS += -std=gnu89
CPPONLYFLAGS += -x c++ -std=gnu++98

# this speeds it up a bit by piping between the preprocessor/compiler/assembler
CCOMFLAGS += -pipe

# add -g if we need symbols, and ensure we have frame pointers
ifdef SYMBOLS
CCOMFLAGS += -g -fno-omit-frame-pointer
endif

# add -v if we need verbose build information
ifdef VERBOSE
CCOMFLAGS += -v
endif

# add profiling information for the compiler
ifdef PROFILE
CCOMFLAGS += -pg
endif

# add the optimization flag
CCOMFLAGS += -O$(OPTIMIZE)

# if we are optimizing, include optimization options
# and make all errors into warnings
ifneq ($(OPTIMIZE),0)
#CCOMFLAGS += -Werror -fno-strict-aliasing $(ARCHOPTS)
CCOMFLAGS += -fno-strict-aliasing $(ARCHOPTS)
endif

# add a basic set of warnings
CCOMFLAGS += \
	-Wall \
	-Wcast-align \
	-Wundef \
	-Wformat-security \
	-Wwrite-strings \
	-Wno-sign-compare 

# warnings only applicable to C compiles
CONLYFLAGS += \
	-Wpointer-arith \
	-Wbad-function-cast \
	-Wstrict-prototypes 

# this warning is not supported on the os2 compilers
ifneq ($(TARGETOS),os2)
CONLYFLAGS += -Wdeclaration-after-statement
endif



#-------------------------------------------------
# include paths
#-------------------------------------------------

# add core include paths
CCOMFLAGS += \
	-I$(SRC)/$(TARGET) \
	-I$(OBJ)/$(TARGET)/layout \
	-I$(SRC)/emu \
	-I$(OBJ)/emu \
	-I$(OBJ)/emu/layout \
	-I$(SRC)/lib/util \
	-I$(SRC)/osd \
	-I$(SRC)/osd/$(OSD) \



#-------------------------------------------------
# linking flags
#-------------------------------------------------

# LDFLAGS are used generally; LDFLAGSEMULATOR are additional
# flags only used when linking the core emulator
#LDFLAGS = -Wl,--warn-common
#LDFLAGSEMULATOR =

# add profiling information for the linker
ifdef PROFILE
LDFLAGS += -pg
endif

# strip symbols and other metadata in non-symbols and non profiling builds
ifndef SYMBOLS
ifndef PROFILE
LDFLAGS += -s
endif
endif

# output a map file (emulator only)
ifdef MAP
LDFLAGSEMULATOR += -Wl,-Map,$(FULLNAME).map
endif



#-------------------------------------------------
# define the standard object directory; other
# projects can add their object directories to
# this variable
#-------------------------------------------------

OBJDIRS = $(OBJ) $(OBJ)/$(TARGET)/$(SUBTARGET)



#-------------------------------------------------
# define standard libarires for CPU and sounds
#-------------------------------------------------
BUILD_LB := YES

ifeq ($(platform),wiiu)
BUILD_LB := NO
endif

ifeq ($(BUILD_LB),YES)
LIBEMU = $(OBJ)/libemu.a
LIBCPU = $(OBJ)/libcpu.a
LIBDASM = $(OBJ)/libdasm.a
LIBSOUND = $(OBJ)/libsound.a
LIBUTIL = $(OBJ)/libutil.a
LIBOCORE = $(OBJ)/libocore.a
LIBOSD = $(OSDOBJS)
else
#LIBEMU   = $(LIBEMUOBJS)
#LIBCPU   = $(CPUOBJS)
#LIBDASM  = $(DASMOBJS) 
#LIBSOUND = $(SOUNDOBJS)
#LIBUTIL  = $(UTILOBJS)
#LIBOCORE = $(OSDCOREOBJS)
LIBOSD   = $(OSDOBJS)
endif

#VERSIONOBJ = $(OBJ)/version.o



#-------------------------------------------------
# either build or link against the included 
# libraries
#-------------------------------------------------

# start with an empty set of libs
#LIBS = -lm

# add expat XML library
ifdef BUILD_EXPAT
CCOMFLAGS += -I$(SRC)/lib/expat
EXPAT = $(OBJ)/libexpat.a
else
LIBS += -lexpat
EXPAT =
endif

# add ZLIB compression library
ifdef BUILD_ZLIB
CCOMFLAGS += -I$(SRC)/lib/zlib
ZLIB = $(OBJ)/libz.a
else
LIBS += -lz
ZLIB =
endif



#-------------------------------------------------
# 'all' target needs to go here, before the 
# include files which define additional targets
#-------------------------------------------------
default: maketree buildtools emulator

all: maketree buildtools emulator tools



#-------------------------------------------------
# defines needed by multiple make files 
#-------------------------------------------------

BUILDSRC = $(CORE_DIR)/src/build
BUILDOBJ = $(OBJ)/build
BUILDOUT = $(BUILDOBJ)

ifeq ($(platform), wiiu)

ifeq ($(TINY),1)
include Makefiletiny.common
else
include Makefilewiiu.common
endif

else

ifeq ($(TINY),1)
include Makefiletiny.common
else
include Makefile.common
endif

endif

#-------------------------------------------------
# include the various .mak files
#-------------------------------------------------

# include OSD-specific rules first
#include $(SRC)/osd/$(OSD)/$(OSD).mak

# then the various core pieces
#include $(SRC)/$(TARGET)/$(SUBTARGET).mak
#include $(SRC)/emu/emu.mak
#include $(SRC)/lib/lib.mak
#include $(SRC)/build/build.mak
#-include $(SRC)/osd/$(CROSS_BUILD_OSD)/build.mak
#include $(SRC)/tools/tools.mak

# combine the various definitions to one
CCOMFLAGS += $(INCFLAGS) -fno-delete-null-pointer-checks
ifeq ($(platform), wiiu)
CCOMFLAGS +=  -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-exceptions
endif
CDEFS = $(DEFS) $(SOUNDDEFS) #$(COREDEFS) $(SOUNDDEFS)



#-------------------------------------------------
# primary targets
#-------------------------------------------------

emulator: maketree $(BUILD) $(EMULATOR)

buildtools: maketree $(BUILD)

tools: maketree $(TOOLS)

maketree: $(sort $(OBJDIRS))

clean: $(OSDCLEAN)
	@echo Deleting object tree $(OBJ)...
	$(RM) -r obj/*
	@echo Deleting $(EMULATOR)...
	$(RM) $(EMULATOR)
	@echo Deleting $(TOOLS)...
	$(RM) $(TOOLS)
ifdef MAP
	@echo Deleting $(FULLNAME).map...
	$(RM) $(FULLNAME).map
endif



#-------------------------------------------------
# directory targets
#-------------------------------------------------

$(sort $(OBJDIRS)):
	$(MD) -p $@



#-------------------------------------------------
# executable targets and dependencies
#-------------------------------------------------

ifndef EXECUTABLE_DEFINED

$(EMULATOR): $(OBJECTS) 
	@echo Linking  RETRO $(TARGETLIB)
ifeq ($(STATIC_LINKING), 1)
	$(AR) rcs $(TARGETLIB) $^ 
else
	@echo $(OBJECTS)
	$(LD) $(LDFLAGS) $(LDFLAGSEMULATOR) $^ $(LIBS) -o $(TARGETLIB)
endif
endif



#-------------------------------------------------
# generic rules
#-------------------------------------------------

ifeq ($(ARM_ENABLED), 1)
CFLAGS += -DARM_ENABLED
endif

$(OBJ)/%.o: $(CORE_DIR)/src/%.c | $(OSPREBUILD)
	$(CC) $(CDEFS) $(CFLAGS) -c $< -o $@

$(OBJ)/%.o: $(OBJ)/%.c | $(OSPREBUILD)
	$(CC) $(CDEFS) $(CFLAGS) -c $< -o $@

$(OBJ)/%.pp: $(CORE_DIR)/src/%.c | $(OSPREBUILD)
	$(CC) $(CDEFS) $(CFLAGS) -E $< -o $@

$(OBJ)/%.s: $(CORE_DIR)/src/%.c | $(OSPREBUILD)
	$(CC) $(CDEFS) $(CFLAGS) -S $< -o $@

$(DRIVLISTOBJ): $(DRIVLISTSRC)
	$(CC) $(CDEFS) $(CFLAGS) -c $< -o $@

$(DRIVLISTSRC): $(CORE_DIR)/src/$(TARGET)/$(SUBTARGET).lst $(MAKELIST_TARGET)
	@echo Building driver list $<...
	@$(MAKELIST) $< >$@

$(OBJ)/%.a:
	@echo Archiving $@...
	$(RM) $@
	$(AR) $(ARFLAGS) $@ $^

ifeq ($(TARGETOS),macosx)
$(OBJ)/%.o: $(SRC)/%.m | $(OSPREBUILD)
	@echo Objective-C compiling $<...
	$(CC) $(CDEFS) $(CFLAGS) -c $< -o $@
endif
