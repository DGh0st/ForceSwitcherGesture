export ARCHS = arm64
export TARGET = iphone:clang:latest:11.0

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ForceSwitcherGesture

ForceSwitcherGesture_FILES = Tweak.x

include $(THEOS_MAKE_PATH)/tweak.mk
