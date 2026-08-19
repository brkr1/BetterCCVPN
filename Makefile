ARCHS = arm64 arm64e

ifeq ($(THEOS_PACKAGE_SCHEME), rootless)
    TARGET := iphone:clang:latest:15.0
    TARGET_OS_DEPLOYMENT_VERSION = 15.0
    ifneq ($(wildcard $(THEOS)/sdks/iPhoneOS15.6.sdk),)
        SYSROOT=$(THEOS)/sdks/iPhoneOS15.6.sdk
        SDKVERSION = 15.6
        INCLUDE_SDKVERSION = 15.6
    endif
else
    TARGET := iphone:clang:latest:13.0
    TARGET_OS_DEPLOYMENT_VERSION = 13.0
endif

include $(THEOS)/makefiles/common.mk

LX_PTRAUTH_FLAG := -fno-ptrauth-objc-class-ro
LX_PTRAUTH_SUPPORTED := $(shell $(TARGET_CC) -target arm64e-apple-ios15.0 -x objective-c \
	-fsyntax-only $(LX_PTRAUTH_FLAG) /dev/null >/dev/null 2>&1 && echo yes)

ifeq ($(LX_PTRAUTH_SUPPORTED),yes)
LX_PTRAUTH_CFLAGS := $(LX_PTRAUTH_FLAG)
else ifeq ($(filter arm64e,$(ARCHS)),)
LX_PTRAUTH_CFLAGS :=
else
$(error $(LX_PTRAUTH_FLAG) is not accepted by $(TARGET_CC), but arm64e is in ARCHS. \
Building anyway emits signed class_ro pointers and produces a dylib that crashes every \
process it is injected into. Build on macOS with Xcode's clang, which supports this flag.)
endif

BUNDLE_NAME = BetterCCVPN

BetterCCVPN_BUNDLE_EXTENSION = bundle
BetterCCVPN_CFLAGS = -fobjc-arc -Iheaders $(LX_PTRAUTH_CFLAGS)
BetterCCVPN_FILES = $(wildcard *.m) $(wildcard *.xm)
BetterCCVPN_LDFLAGS = Frameworks/ControlCenterUIKit.tbd
BetterCCVPN_INSTALL_PATH = /Library/ControlCenter/Bundles/

include $(THEOS_MAKE_PATH)/bundle.mk
