#
# OrangeFox Product Makefile for Realme C53 (RMX3760 / RE58C2)
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit some common OrangeFox stuff.
$(call inherit-product-if-exists, vendor/twrp/config/common.mk)
$(call inherit-product-if-exists, vendor/pb/config/common.mk)
$(call inherit-product-if-exists, vendor/recovery/config/common.mk)

# Inherit from device
$(call inherit-product, device/realme/RE58C2/device.mk)

PRODUCT_DEVICE := RE58C2
PRODUCT_NAME := fox_RE58C2
PRODUCT_BRAND := realme
PRODUCT_MODEL := RE58C2
PRODUCT_MANUFACTURER := realme

# OrangeFox recovery variables
FOX_AB_DEVICE := 1
FOX_VIRTUAL_AB_DEVICE := 1
FOX_VENDOR_BOOT_RECOVERY := 1
FOX_VANILLA_BUILD := 1
