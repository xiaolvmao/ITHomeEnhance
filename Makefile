TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
DEBUG = 0
FINALPACKAGE = 1
PACKAGE_VERSION = 1.2.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ITHomeEnhance

ITHomeEnhance_FILES = $(wildcard Sources/*.xm) $(wildcard Sources/*.m)
ITHomeEnhance_CFLAGS = -fobjc-arc -ISources/vendor -Wno-unused-function
ITHomeEnhance_FRAMEWORKS = Foundation UIKit
ITHomeEnhance_INSTALL_PATH = /Library/TweakInject

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 ITHomeClient || true"
