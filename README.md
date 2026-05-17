# TWRP for Realme C53 (RMX3760 / RE58C2)

Device tree for building TWRP recovery for Realme C53.
- **Chipset**: Unisoc T612 (ums9230)
- **Kernel**: `5.15.178-android13-8`
- **Android**: 15 (AP3A.240905.015.A2)
- **Build**: `realme/RMX3760/RE58C2:15/AP3A.240905.015.A2/T.R4T2.1773288057:user/release-keys`
- **Arch**: aarch64
- **Slots**: A/B

> Based on [cooked71/device_REALME_RMX3760_twrp](https://github.com/cooked71/device_REALME_RMX3760_twrp) (TWRP branch)

---

## Build with GitHub Actions

### 1. Fork this repo
Click **Fork** button on GitHub (or use the template).

### 2. Trigger build
```bash
# Go to your fork on GitHub
# Actions tab → "Build TWRP for Realme C53 (RMX3760)" → "Run workflow"
```

### 3. Download artifact
After build completes (~30-60 min):
- **Actions** tab → click completed run → scroll to **Artifacts**
- Download `twrp-rmx3760` → extract → `vendor_boot.img`

---

## Flash Instructions

### Prerequisites
- Bootloader **must be unlocked**
- ADB & Fastboot installed on PC
- Battery > 50%

### Option A: Try without flashing (temporary)
```bash
adb reboot bootloader
fastboot boot vendor_boot.img
```
This only loads TWRP in memory — reboot returns to stock.

### Option B: Flash permanently
```bash
adb reboot bootloader

# Flash to both slots (A/B safety)
fastboot flash vendor_boot_a vendor_boot.img
fastboot flash vendor_boot_b vendor_boot.img

# Boot into recovery
fastboot reboot recovery
```

### Restore stock vendor_boot
```bash
fastboot flash vendor_boot_a stock_vendor_boot.img
fastboot flash vendor_boot_b stock_vendor_boot.img
```

---

## Build Notes

| Item | Detail |
|------|--------|
| Manifest | `minimal-manifest-twrp/platform_manifest_twrp_aosp` branch `twrp-12.1` |
| Output | `vendor_boot.img` (not `recovery.img`) |
| Recovery location | Inside `vendor_boot` partition (Android 13+ VAB) |
| Touchscreen | Working |
| Data decryption | Not working (no FBE/FSCRYPT support yet) |
| MTP | Not tested |
| ADB sideload | Not tested |

### Known issues
- "Atomic commit failed ret=-22" in log — patched via custom `graphics_drm.cpp`
- No userdata decryption

---

## Device Partitions

```
boot_a / boot_b              — Kernel + ramdisk (64 MB)
init_boot_a / init_boot_b    — Init boot (for GKI)
vendor_boot_a / vendor_boot_b — Recovery ramdisk (flashed by this build)
dtb_a / dtb_b                — Device tree blob
dtbo_a / dtbo_b              — DT overlay
vbmeta_a / vbmeta_b          — Verified boot metadata
super                        — Dynamic partitions (system, product, vendor)
```

---

## Credits
- [cooked71](https://github.com/cooked71) — Original TWRP device tree
- [Team Win](https://twrp.me) — TWRP Recovery Project

## License
GPL v3
