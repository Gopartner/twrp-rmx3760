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
- **Build di remote** (GitHub Actions) — laptop terlalu lambat (i3-2310M, 8GB RAM)
- Workflow: `.github/workflows/build-twrp.yml`
- Manifest: `minimal-manifest-twrp/platform_manifest_twrp_aosp` branch `twrp-12.1`
- Device tree path: `device/realme/RE58C2/`
- Output: `vendor_boot.img` (NOT `recovery.img`)

## ⚠️ Build Rules (penting!)
1. **Jangan push README/docs saat build sedang berjalan** — workflow trigger `push` dan `cancel-in-progress: true` akan membatalkan build yang sedang jalan
2. Push kode dulu, dokumentasi belakangan setelah build selesai
3. Atau push perubahan di branch terpisah, baru merge setelah build selesai

## Key Config (BoardConfig.mk)
- `BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true`
- `TARGET_NO_RECOVERY := true`
- `BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 104857600` (100 MB)
- `TARGET_PREBUILT_DTB := device/realme/RE58C2/prebuilt/dtb.img` → **diganti dengan DTB dari vendor_boot stock** (Android 15 AP3A.240905.015.A2)
- `BOARD_BOOT_HEADER_VERSION := 4`

## Display Issue
- **Display blank** — DRM atomic commit gagal di Unisoc T612 (`drmModeAtomicCommit` return -22)
- **graphics_drm.cpp custom patch DIPAKAI** — custom DRM backend menyebabkan boot hang (null pointer dereference di `disable_non_main_crtcs`)
- **Patch sudah dihapus** — TWRP boot (ADB accessible) tapi display blank. Belum ada solusi.
- Kemungkinan solusi: force fbdev backend, atau fix custom DRM patch dengan benar

## Flashing
```bash
fastboot flash vendor_boot_a vendor_boot.img
fastboot reboot recovery
```

## BROM Recovery (saat device stuck)
```bash
# Masuk BROM: matikan HP, Vol Up+Down, colok USB
cd D:\Realme-C-project\01_unlock_tool\unlock_tool
.\spd_dump.exe --wait 300 exec_addr 0x65015f08 fdl fdl1-dl.bin 0x65000800 fdl fdl2-dl.bin 0x9efffe00 exec write_part vendor_boot_a D:\Realme-C-project\02_root_tools\ksu\vendor_boot_a_original.img reset
```
Stock backup: `D:\Realme-C-project\02_root_tools\ksu\vendor_boot_a_original.img` (100 MB)

## Notes
- Data decryption NOT working
- Touchscreen working (display blank, tapi touch input mungkin jalan)
- Stock vendor_boot backup location: `D:\Realme-C-project\04_backup\backup\`
- Lokasi repo lokal: `C:\Users\Rafka\AppData\Local\Temp\opencode\twrp-rmx3760` (sementara)
- Rencana clone ulang ke: `D:\twrp-rmx3760\`
