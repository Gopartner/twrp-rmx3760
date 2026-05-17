# AGENTS.md — TWRP Build for Realme C53 (RMX3760)

## Device Identity
- **Model**: Realme C53 (RMX3760)
- **SoC**: Unisoc T612 (ums9230)
- **Kernel**: `5.15.178-android13-8`
- **Android**: 15 (AP3A.240905.015.A2)
- **Build**: `realme/RMX3760/RE58C2:15/AP3A.240905.015.A2/T.R4T2.1773288057:user/release-keys`
- **Arch**: aarch64
- **Slots**: A/B (`vendor_boot_a`/`vendor_boot_b`)

## Build Method
- GitHub Actions workflow (`.github/workflows/build-twrp.yml`)
- Manifest: `minimal-manifest-twrp/platform_manifest_twrp_omni` branch `twrp-12.1`
- Device tree path: `device/realme/RE58C2/`
- Output: `vendor_boot.img` (NOT `recovery.img`)

## Key Config (BoardConfig.mk)
- `BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true`
- `TARGET_NO_RECOVERY := true`
- `BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 104857600` (100 MB)
- `TARGET_PREBUILT_DTB := device/realme/RE58C2/prebuilt/dtb.img`
- `BOARD_BOOT_HEADER_VERSION := 4`

## UI Fix
- `issue_atomic/graphics_drm.cpp` replaces `bootable/recovery/minuitwrp/graphics_drm.cpp`
- Fixes "Atomic commit failed ret=-22" error

## Flashing
```bash
fastboot flash vendor_boot_a vendor_boot.img
fastboot flash vendor_boot_b vendor_boot.img
fastboot reboot recovery
```

## Notes
- Data decryption NOT working
- Touchscreen working
- Stock vendor_boot backup location: `D:\Realme-C-project\04_backup\backup\`
