DEBUG              = 0
LAGFIX             = 0
USE_OLD_COLOUR_OPS = 0
TARGET_NAME = snes9x2002
PROFILE ?= 0

ifeq ($(platform),)
   ifeq (,$(findstring classic_,$(platform)))
      platform = unix
   endif
ifeq ($(shell uname -a),)
   platform = win
else ifneq ($(findstring MINGW,$(shell uname -a)),)
   platform = win
else ifneq ($(findstring Darwin,$(shell uname -a)),)
   platform = osx
else ifneq ($(findstring win,$(shell uname -a)),)
   platform = win
endif
endif

ifneq (,$(findstring msvc,$(platform)))
LIBM :=
else
LIBM := -lm
endif
LIBS :=

ifeq ($(platform), unix)
   TARGET := $(TARGET_NAME)_libretro.so
   fpic := 
   SHARED := -shared -Wl,--version-script=libretro/link.T -Wl,--no-undefined
   CFLAGS += -fno-builtin -fno-exceptions
else ifeq ($(platform), osx)
   TARGET := $(TARGET_NAME)_libretro.dylib
   fpic := 
   SHARED := -dynamiclib

   ifeq ($(CROSS_COMPILE),1)
		TARGET_RULE   = -target $(LIBRETRO_APPLE_PLATFORM) -isysroot $(LIBRETRO_APPLE_ISYSROOT)
		CFLAGS   += $(TARGET_RULE)
		CPPFLAGS += $(TARGET_RULE)
		CXXFLAGS += $(TARGET_RULE)
		LDFLAGS  += $(TARGET_RULE)
   endif

else ifneq (,$(findstring ios,$(platform)))
   TARGET := $(TARGET_NAME)_libretro_ios.dylib
   fpic := 
   SHARED := -dynamiclib
   MINVERSION :=

   ifeq ($(IOSSDK),)
      IOSSDK := $(shell xcodebuild -version -sdk iphoneos Path)
   endif

   ifeq ($(platform),ios-arm64)
	CC = cc -arch arm64 -isysroot $(IOSSDK)
   	CXX = c++ -arch arm64 -isysroot $(IOSSDK)   
   else
   	CC = cc -arch armv7 -isysroot $(IOSSDK)
   	CXX = c++ -arch armv7 -isysroot $(IOSSDK)
   endif
   ARM_ASM = 0
   ASM_CPU = 0
   ASM_SPC700 = 0
   ifeq ($(platform),$(filter $(platform),ios9 ios-arm64))
      MINVERSION += -miphoneos-version-min=8.0
   else
      MINVERSION += -miphoneos-version-min=5.0
   endif
   CFLAGS += $(MINVERSION)
   CXXFLAGS += $(MINVERSION)
else ifeq ($(platform), tvos-arm64)
   TARGET := $(TARGET_NAME)_libretro_tvos.dylib
   fpic := 
   SHARED := -dynamiclib
   ifeq ($(IOSSDK),)
      IOSSDK := $(shell xcodebuild -version -sdk appletvos Path)
   endif
   ARM_ASM = 0
   ASM_CPU = 0
   ASM_SPC700 = 0
   CC = cc -arch arm64 -isysroot $(IOSSDK)
else ifeq ($(platform), theos_ios)
   DEPLOYMENT_IOSVERSION = 5.0
   TARGET = iphone:latest:$(DEPLOYMENT_IOSVERSION)
   ARCHS = armv7 armv7s
   TARGET_IPHONEOS_DEPLOYMENT_VERSION=$(DEPLOYMENT_IOSVERSION)
   THEOS_BUILD_DIR := objs
   include $(THEOS)/makefiles/common.mk
   LIBRARY_NAME = $(TARGET_NAME)_libretro_ios
   ARM_ASM = 1
   ASM_CPU = 0
   ASM_SPC700 = 0
else ifeq ($(platform), ps3)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC = $(CELL_SDK)/host-win32/ppu/bin/ppu-lv2-gcc.exe
   AR = $(CELL_SDK)/host-win32/ppu/bin/ppu-lv2-ar.exe
   CFLAGS += -DBLARGG_BIG_ENDIAN=1 -D__ppc__
   CFLAGS += -DMSB_FIRST
   STATIC_LINKING := 1
else ifeq ($(platform), sncps3)
   TARGET := $(TARGET_NAME)_libretro_ps3.a
   CC = $(CELL_SDK)/host-win32/sn/bin/ps3ppusnc.exe
   AR = $(CELL_SDK)/host-win32/sn/bin/ps3snarl.exe
   CFLAGS += -DBLARGG_BIG_ENDIAN=1 -D__ppc__
   CFLAGS += -DMSB_FIRST
   STATIC_LINKING := 1
else ifeq ($(platform), xenon)
   TARGET := $(TARGET_NAME)_libretro_xenon360.a
   CC = xenon-gcc
   AR = xenon-ar
   CFLAGS += -D__LIBXENON__ -m32 -D__ppc__
   STATIC_LINKING := 1
else ifeq ($(platform), ngc)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC = $(DEVKITPPC)/bin/powerpc-eabi-gcc
   AR = $(DEVKITPPC)/bin/powerpc-eabi-ar
   CFLAGS += -DGEKKO -mrvl -mcpu=750 -meabi -mhard-float -DBLARGG_BIG_ENDIAN=1 -D__ppc__
   CFLAGS += -U__INT32_TYPE__ -U __UINT32_TYPE__ -D__INT32_TYPE__=int
   CFLAGS += -DMSB_FIRST
   STATIC_LINKING := 1

else ifeq ($(platform), wii)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC = $(DEVKITPPC)/bin/powerpc-eabi-gcc
   AR = $(DEVKITPPC)/bin/powerpc-eabi-ar
   CFLAGS += -DGEKKO -mrvl -mcpu=750 -meabi -mhard-float -DBLARGG_BIG_ENDIAN=1 -D__ppc__ -DHW_RVL
   CFLAGS += -U__INT32_TYPE__ -U __UINT32_TYPE__ -D__INT32_TYPE__=int
   CFLAGS += -DMSB_FIRST
   STATIC_LINKING := 1

else ifeq ($(platform), wiiu)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC = $(DEVKITPPC)/bin/powerpc-eabi-gcc
   AR = $(DEVKITPPC)/bin/powerpc-eabi-ar
   CFLAGS += -DGEKKO -DWIIU -mcpu=750 -meabi -mhard-float -DBLARGG_BIG_ENDIAN=1 -D__ppc__ -DHW_RVL
   CFLAGS += -ffunction-sections -fdata-sections -D__wiiu__ -D__wut__
   CFLAGS += -DMSB_FIRST
   STATIC_LINKING := 1

# (armv7 a7, hard point, neon based) ### 
# NESC, SNESC, C64 mini 
else ifeq ($(platform),$(filter $(platform),classic_armv7_a7 unix-armv7-hardfloat-neon))
	TARGET := $(TARGET_NAME)_libretro.so
	fpic := 
	SHARED := -shared -Wl,--version-script=libretro/link.T -Wl,--no-undefined
	CFLAGS += -Ofast \
	-flto=4 -fwhole-program -fuse-linker-plugin \
	-fdata-sections -ffunction-sections -Wl,--gc-sections \
	-fno-stack-protector -fno-ident -fomit-frame-pointer \
	-falign-functions=1 -falign-jumps=1 -falign-loops=1 \
	-fno-unwind-tables -fno-asynchronous-unwind-tables -fno-unroll-loops \
	-fmerge-all-constants -fno-math-errno \
	-marm -mtune=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard
	CXXFLAGS += $(CFLAGS)
	CPPFLAGS += $(CFLAGS)
	ASFLAGS += $(CFLAGS)
	HAVE_NEON = 1
	ARCH = arm
	BUILTIN_GPU = neon
	USE_DYNAREC = 1
	ifeq ($(shell echo `$(CC) -dumpversion` "< 4.9" | bc -l), 1)
	  CFLAGS += -march=armv7-a
	else
	  CFLAGS += -march=armv7ve
	  # If gcc is 5.0 or later
	  ifeq ($(shell echo `$(CC) -dumpversion` ">= 5" | bc -l), 1)
	    LDFLAGS += -static-libgcc -static-libstdc++
	  endif
	endif
#######################################

else ifeq ($(platform), ps2)
	TARGET := $(TARGET_NAME)_libretro_$(platform).a
	CC = mips64r5900el-ps2-elf-gcc$(EXE_EXT)
	CXX = mips64r5900el-ps2-elf-g++$(EXE_EXT)
	AR = mips64r5900el-ps2-elf-ar$(EXE_EXT)
	STATIC_LINKING = 1
	LOAD_FROM_MEMORY_TEST = 0
   CFLAGS += -DPS2 -G0 -fomit-frame-pointer -ffast-math
	STATIC_LINKING := 1

else ifeq ($(platform), psp1)
	TARGET := $(TARGET_NAME)_libretro_$(platform).a
	CC = psp-gcc$(EXE_EXT)
	CXX = psp-g++$(EXE_EXT)
	AR = psp-ar$(EXE_EXT)
	STATIC_LINKING = 1
	LOAD_FROM_MEMORY_TEST = 0
	FLAGS += -G0
	CFLAGS += \
		-march=allegrex -mno-abicalls -fno-pic \
		-fno-builtin -fno-exceptions -ffunction-sections
	DEFS +=  -DPSP -D_PSP_FW_VERSION=371
	STATIC_LINKING := 1

# Vita
else ifeq ($(platform), vita)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC = $(VITASDK)/bin/arm-vita-eabi-gcc$(EXE_EXT)
   CXX = $(VITASDK)/bin/arm-vita-eabi-g++$(EXE_EXT)
   AR = $(VITASDK)/bin/arm-vita-eabi-ar$(EXE_EXT)
   ARM_ASM = 1
   ASM_CPU = 0
   ASM_SPC700 = 0
   CFLAGS += -march=armv7-a -mfloat-abi=hard
   CFLAGS += -Wall -mword-relocations
   CFLAGS += -fomit-frame-pointer -ffast-math
   CFLAGS += -std=c11 -Wa,-mimplicit-it=thumb
   DEFS +=  -DVITA
   STATIC_LINKING := 1
# CTR (3DS)
else ifeq ($(platform), ctr)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC = $(DEVKITARM)/bin/arm-none-eabi-gcc$(EXE_EXT)
   CXX = $(DEVKITARM)/bin/arm-none-eabi-g++$(EXE_EXT)
   AR = $(DEVKITARM)/bin/arm-none-eabi-ar$(EXE_EXT)
   ARM_ASM = 1
   ASM_CPU = 0
   ASM_SPC700 = 0
   CFLAGS += -DARM11 -D_3DS 
   CFLAGS += -march=armv6k -mtune=mpcore -mfloat-abi=hard
   CFLAGS += -Wall -mword-relocations
   CFLAGS += -fomit-frame-pointer -ffast-math
   CFLAGS += -D_3DS
   PLATFORM_DEFINES := -D_3DS
   STATIC_LINKING := 1

# Emscripten
else ifeq ($(platform), emscripten)
   TARGET := $(TARGET_NAME)_libretro_$(platform).bc
   STATIC_LINKING := 1

# GCW0
else ifeq ($(platform), gcw0)
   TARGET := $(TARGET_NAME)_libretro.so
   CC = /opt/gcw0-toolchain/usr/bin/mipsel-linux-gcc
   CXX = /opt/gcw0-toolchain/usr/bin/mipsel-linux-g++
   AR = /opt/gcw0-toolchain/usr/bin/mipsel-linux-ar
   fpic := 
   SHARED := -shared -Wl,--version-script=libretro/link.T -Wl,--no-undefined
   CFLAGS += -std=c99 -fomit-frame-pointer -ffast-math -march=mips32 -mtune=mips32r2 -mhard-float
   CFLAGS += -fno-builtin -fno-exceptions
   CFLAGS += -DPATH_MAX=256 -DFAST_LSB_WORD_ACCESS

# MIYOO
else ifeq ($(platform), miyoo)
   TARGET := $(TARGET_NAME)_libretro.so
   CC = /opt/miyoo/usr/bin/arm-linux-gcc
   CXX = /opt/miyoo/usr/bin/arm-linux-g++
   AR = /opt/miyoo/usr/bin/arm-linux-ar
   fpic := -fno-PIC
   ARM_ASM = 1
   ASM_CPU = 0
   ASM_SPC700 = 0
   SHARED := -shared -Wl,--version-script=libretro/link.T -Wl,--no-undefined
   CFLAGS +=  -mcpu=arm926ej-s -mtune=arm926ej-s -g -D__MIYOO__ -O3 -fno-inline -finline-limit=42 -fno-unroll-loops -fno-ipa-cp -ffast-math -fno-common -fno-stack-protector -fno-caller-saves -fno-regmove 
ifeq ($(PROFILE), YES)
   CFLAGS += -fprofile-generate=$(HOMEPATH)/profile # rm path if you want dir structure intact at runtime
   LDFLAGS += -lgcov
else ifeq ($(PROFILE), APPLY)
   CFLAGS += -fprofile-use -fbranch-probabilities -Wno-error=coverage-mismatch
endif
   CFLAGS += -DFAST_ALIGNED_LSB_WORD_ACCESS \
      -DDINGUX \
      -DLSB_FIRST \
      -DPSS_STYLE=1 \
      -DHAVE_ASPRINTF \
      -DFRAMESKIP \
      -D_REENTRANT
# XYDDS
else ifeq ($(platform), xydds)
   TARGET := $(TARGET_NAME)_libretro.so
   CC = /opt/xydds/usr/bin/arm-linux-gcc
   CXX = /opt/xydds/usr/bin/arm-linux-g++
   AR = /opt/xydds/usr/bin/arm-linux-ar
   fpic := -fPIC
   ARM_ASM = 1
   ASM_CPU = 0
   ASM_SPC700 = 0
   SHARED := -shared -Wl,--version-script=libretro/link.T -Wl,--no-undefined
   CFLAGS += -DARM -mcpu=cortex-a7 -marm -mfpu=neon-vfpv4 -mfloat-abi=hard -g -D__MIYOO__ -O3 -fno-inline -finline-limit=42 -fno-unroll-loops -fno-ipa-cp -ffast-math -fno-common -fno-stack-protector -fno-caller-saves -fno-regmove 
ifeq ($(PROFILE), YES)
   CFLAGS += -fprofile-generate=$(HOMEPATH)/profile # rm path if you want dir structure intact at runtime
   LDFLAGS += -lgcov
else ifeq ($(PROFILE), APPLY)
   CFLAGS += -fprofile-use -fbranch-probabilities -Wno-error=coverage-mismatch
endif
   CFLAGS += -DFAST_ALIGNED_LSB_WORD_ACCESS \
      -DDINGUX \
      -DLSB_FIRST \
      -DPSS_STYLE=1 \
      -DHAVE_ASPRINTF \
      -DFRAMESKIP \
      -D_REENTRANT

# Windows MSVC 2010 x64
else ifeq ($(platform), windows_msvc2010_x64)
	CC  = cl.exe
	CXX = cl.exe

PATH := $(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../../VC/bin/amd64"):$(PATH)
PATH := $(PATH):$(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../IDE")
INCLUDE := $(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../../VC/include")
LIB := $(shell IFS=$$'\n'; cygpath -w "$(VS100COMNTOOLS)../../VC/lib/amd64")
BIN := $(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../../VC/bin/amd64")

WindowsSdkDir := $(shell reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.1A" -v "InstallationFolder" | grep -o '[A-Z]:\\.*')
WindowsSdkDir ?= $(shell reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.0A" -v "InstallationFolder" | grep -o '[A-Z]:\\.*')

WindowsSDKIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include")
WindowsSDKGlIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\gl")
WindowsSDKLibDir := $(shell cygpath -w "$(WindowsSdkDir)\Lib\x64")

INCFLAGS_PLATFORM = -I"$(WindowsSDKIncludeDir)"
export INCLUDE := $(INCLUDE);$(WindowsSDKIncludeDir);$(WindowsSDKGlIncludeDir)
export LIB := $(LIB);$(WindowsSDKLibDir)
TARGET := $(TARGET_NAME)_libretro.dll
PSS_STYLE :=2
LDFLAGS += -DLL
CFLAGS += -D_CRT_SECURE_NO_DEPRECATE
NO_GCC = 1

# Windows MSVC 2010 x86
else ifeq ($(platform), windows_msvc2010_x86)
	CC  = cl.exe
	CXX = cl.exe

PATH := $(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../../VC/bin"):$(PATH)
PATH := $(PATH):$(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../IDE")
INCLUDE := $(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../../VC/include")
LIB := $(shell IFS=$$'\n'; cygpath -w "$(VS100COMNTOOLS)../../VC/lib")
BIN := $(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../../VC/bin")

WindowsSdkDir := $(shell reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.1A" -v "InstallationFolder" | grep -o '[A-Z]:\\.*')
WindowsSdkDir ?= $(shell reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.0A" -v "InstallationFolder" | grep -o '[A-Z]:\\.*')

WindowsSDKIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include")
WindowsSDKGlIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\gl")
WindowsSDKLibDir := $(shell cygpath -w "$(WindowsSdkDir)\Lib")

INCFLAGS_PLATFORM = -I"$(WindowsSDKIncludeDir)"
export INCLUDE := $(INCLUDE);$(WindowsSDKIncludeDir);$(WindowsSDKGlIncludeDir)
export LIB := $(LIB);$(WindowsSDKLibDir)
TARGET := $(TARGET_NAME)_libretro.dll
PSS_STYLE :=2
LDFLAGS += -DLL
CFLAGS += -D_CRT_SECURE_NO_DEPRECATE
NO_GCC = 1

# Windows MSVC 2008 x86
else ifeq ($(platform), windows_msvc2008_x86)
	CC  = cl.exe
	CXX = cl.exe

PATH := $(shell IFS=$$'\n'; cygpath "$(VS90COMNTOOLS)../../VC/bin"):$(PATH)
PATH := $(PATH):$(shell IFS=$$'\n'; cygpath "$(VS90COMNTOOLS)../IDE")
INCLUDE := $(shell IFS=$$'\n'; cygpath "$(VS90COMNTOOLS)../../VC/include")
LIB := $(shell IFS=$$'\n'; cygpath -w "$(VS90COMNTOOLS)../../VC/lib")
BIN := $(shell IFS=$$'\n'; cygpath "$(VS90COMNTOOLS)../../VC/bin")

WindowsSdkDir := $(INETSDK)

export INCLUDE := $(INCLUDE);$(INETSDK)/Include;libretro-common/include/compat/msvc
export LIB := $(LIB);$(WindowsSdkDir);$(INETSDK)/Lib
TARGET := $(TARGET_NAME)_libretro.dll
PSS_STYLE :=2
LDFLAGS += -DLL
CFLAGS += -D_CRT_SECURE_NO_DEPRECATE
NO_GCC = 1

# Windows MSVC 2005 x86
else ifeq ($(platform), windows_msvc2005_x86)
	CC  = cl.exe
	CXX = cl.exe

PATH := $(shell IFS=$$'\n'; cygpath "$(VS80COMNTOOLS)../../VC/bin"):$(PATH)
PATH := $(PATH):$(shell IFS=$$'\n'; cygpath "$(VS80COMNTOOLS)../IDE")
INCLUDE := $(shell IFS=$$'\n'; cygpath "$(VS80COMNTOOLS)../../VC/include")
LIB := $(shell IFS=$$'\n'; cygpath -w "$(VS80COMNTOOLS)../../VC/lib")
BIN := $(shell IFS=$$'\n'; cygpath "$(VS80COMNTOOLS)../../VC/bin")

WindowsSdkDir := $(shell reg query "HKLM\SOFTWARE\Microsoft\MicrosoftSDK\InstalledSDKs\8F9E5EF3-A9A5-491B-A889-C58EFFECE8B3" -v "Install Dir" | grep -o '[A-Z]:\\.*')

WindowsSDKIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include")
WindowsSDKAtlIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\atl")
WindowsSDKCrtIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\crt")
WindowsSDKGlIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\gl")
WindowsSDKMfcIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\mfc")
WindowsSDKLibDir := $(shell cygpath -w "$(WindowsSdkDir)\Lib")

export INCLUDE := $(INCLUDE);$(WindowsSDKIncludeDir);$(WindowsSDKAtlIncludeDir);$(WindowsSDKCrtIncludeDir);$(WindowsSDKGlIncludeDir);$(WindowsSDKMfcIncludeDir);libretro-common/include/compat/msvc
export LIB := $(LIB);$(WindowsSDKLibDir)
TARGET := $(TARGET_NAME)_libretro.dll
PSS_STYLE :=2
LDFLAGS += -DLL
CFLAGS += -D_CRT_SECURE_NO_DEPRECATE
NO_GCC = 1

# Windows MSVC 2003 x86
else ifeq ($(platform), windows_msvc2003_x86)
	CC  = cl.exe
	CXX = cl.exe

PATH := $(shell IFS=$$'\n'; cygpath "$(VS71COMNTOOLS)../../Vc7/bin"):$(PATH)
PATH := $(PATH):$(shell IFS=$$'\n'; cygpath "$(VS71COMNTOOLS)../IDE")
INCLUDE := $(shell IFS=$$'\n'; cygpath "$(VS71COMNTOOLS)../../Vc7/include")
LIB := $(shell IFS=$$'\n'; cygpath -w "$(VS71COMNTOOLS)../../Vc7/lib")
BIN := $(shell IFS=$$'\n'; cygpath "$(VS71COMNTOOLS)../../Vc7/bin")

WindowsSdkDir := $(INETSDK)

export INCLUDE := $(INCLUDE);$(INETSDK)/Include;libretro-common/include/compat/msvc
export LIB := $(LIB);$(WindowsSdkDir);$(INETSDK)/Lib
TARGET := $(TARGET_NAME)_libretro.dll
PSS_STYLE :=2
LDFLAGS += -DLL
CFLAGS += -D_CRT_SECURE_NO_DEPRECATE
NO_GCC = 1
else
   TARGET := $(TARGET_NAME)_libretro.dll
   CC ?= gcc
   fpic := 
   SHARED := -shared -Wl,--no-undefined -Wl,--version-script=libretro/link.T
   LD_FLAGS += -static-libgcc -static-libstdc++ -lwinmm
   CFLAGS += -D__WIN32__ -D__WIN32_LIBRETRO__
endif

CORE_DIR     := ./src
LIBRETRO_DIR := ./libretro

ifeq ($(DEBUG), 1)
DEFINES += -O0 -g
else ifneq (,$(findstring msvc,$(platform)))
DEFINES += -O3 -DNDEBUG=1
else
DEFINES += -O3 -DNDEBUG=1
endif

ifneq (,$(findstring msvc,$(platform)))
ifeq ($(DEBUG),1)
DEFINES += -MTd
else
DEFINES += -MT
endif
endif

LDFLAGS += $(LIBM)

include Makefile.common

OBJECTS := $(SOURCES:.c=.o) $(SOURCES_ASM:.S=.o)

CFLAGS += $(DEFINES) $(COMMON_DEFINES) $(INCLUDES)

LDFLAGS += $(fpic)

FLAGS += $(fpic)

ifneq (,$(findstring msvc,$(platform)))
	LIBM =
	OBJOUT = -Fo
	LINKOUT = -out:
	LD = link.exe
else
	OBJOUT   = -o
	LINKOUT  = -o
	LD = $(CC)
endif

ifeq ($(platform), theos_ios)
COMMON_FLAGS := -DIOS $(COMMON_DEFINES) $(INCFLAGS) -I$(THEOS_INCLUDE_PATH) -Wno-error
$(LIBRARY_NAME)_CFLAGS += $(CFLAGS) $(COMMON_FLAGS)
$(LIBRARY_NAME)_CXXFLAGS += $(CXXFLAGS) $(COMMON_FLAGS)
${LIBRARY_NAME}_FILES = $(SOURCES_CXX) $(SOURCES_C)
include $(THEOS_MAKE_PATH)/library.mk
else
all: $(TARGET)

$(TARGET): $(OBJECTS)
ifeq ($(STATIC_LINKING), 1)
	$(AR) rcs $@ $(OBJECTS)
else
	$(LD) $(LINKOUT)$@ $(SHARED) $(OBJECTS) $(LDFLAGS) $(LIBS)
endif

%.o: %.c
	$(CC) $(CFLAGS) -c $(OBJOUT)$@ $<

%.o: %.S
	$(CC) $(CFLAGS) -Wa,-I./src/ -c $(OBJOUT)$@ $<

clean:
	rm -f $(OBJECTS) $(TARGET)

.PHONY: clean

endif
