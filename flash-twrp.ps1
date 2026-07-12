<#
.SYNOPSIS
    Flash / Restore / Backup TWRP for Realme C53 (RMX3760)

.DESCRIPTION
    Tool untuk flash TWRP vendor_boot, restore stock, backup, dan BROM recovery.
    Auto-detect ADB / fastboot / BROM.

.NOTES
    File:     flash-twrp.ps1
    Author:   Gopartner
    Repo:     https://github.com/Gopartner/twrp-rmx3760
    Requires: ADB & Fastboot di PATH, BROM tools untuk restore darurat
#>

param(
    [switch]$Flash,
    [switch]$Restore,
    [switch]$Backup,
    [switch]$Boot,
    [switch]$Info,
    [ValidateSet("adb","fastboot","brom","")][string]$Mode = ""
)

# --- Configuration ---
$SCRIPT_DIR    = Split-Path -Parent $MyInvocation.MyCommand.Path
$BACKUP_DIR    = "$SCRIPT_DIR\backup"
$TWRP_IMAGE    = "$SCRIPT_DIR\vendor_boot.img"
$PACKAGE_NAME  = "twrp-rmx3760"
$BROM_TOOL     = "$env:USERPROFILE\scoop\apps\spd_dump\current\spd_dump.exe"
$BROM_DIR      = "$SCRIPT_DIR\brom"

# BROM fallback paths
$BROM_SEARCH   = @(
    "D:\Realme-C-project\01_unlock_tool\unlock_tool",
    "D:\Realme-C-project\recovery",
    "$env:USERPROFILE\AppData\Local\Temp\opencode\twrp-rmx3760\brom"
)

# BROM addresses (RMX3760 specific)
$FDL1_ADDR = "0x65015f08"
$FDL2_ADDR = "0x65000800"
$EXEC_ADDR = "0x9efffe00"

# --- Detection ---
function Test-Adb {
    $r = adb devices 2>&1 | Out-String
    return ($r -match "\tdevice" -and $r -notmatch "unauthorized")
}

function Test-Fastboot {
    $r = fastboot devices 2>&1 | Out-String
    return ($r -match "\tfastboot")
}

function Test-Brom {
    $port = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -match "SPRD U2S Diag" }
    return ($null -ne $port)
}

function Get-DeviceState {
    $state = @{ adb = $false; fb = $false; brom = $false; label = "None" }
    if (Test-Adb)    { $state.adb = $true;  $state.label = "ADB" }
    if (Test-Fastboot){ $state.fb = $true;  $state.label = "Fastboot" }
    if (Test-Brom)   { $state.brom = $true; $state.label = "BROM" }
    return $state
}

function Find-BromTool {
    # Check default path first
    if (Test-Path $BROM_TOOL) { return $BROM_TOOL }

    # Check brom subdirectory
    $localExe = "$BROM_DIR\spd_dump.exe"
    if (Test-Path $localExe) { return $localExe }

    # Search common locations
    foreach ($dir in $BROM_SEARCH) {
        $exe = "$dir\spd_dump.exe"
        if (Test-Path $exe) { return $exe }
    }

    return $null
}

# --- Backup ---
function Backup-VendorBoot {
    Write-Host "=== BACKUP ===" -ForegroundColor Cyan
    if (-not (Test-Adb)) {
        Write-Host "ERROR: Device not detected via ADB." -ForegroundColor Red
        return $false
    }

    New-Item -ItemType Directory -Path $BACKUP_DIR -Force | Out-Null
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupFile = "$BACKUP_DIR\vendor_boot_backup_$ts.img"

    Write-Host "Backup current vendor_boot..." -NoNewline
    adb shell "su -c 'dd if=/dev/block/by-name/vendor_boot_a of=/data/local/tmp/vendor_boot_backup.img'" 2>$null
    adb pull "/data/local/tmp/vendor_boot_backup.img" $backupFile 2>$null
    adb shell "rm -f /data/local/tmp/vendor_boot_backup.img" 2>$null

    if ((Test-Path $backupFile) -and ((Get-Item $backupFile).Length -gt 1MB)) {
        Write-Host " OK ($([math]::Round((Get-Item $backupFile).Length/1MB,1)) MB)" -ForegroundColor Green
        Write-Host "Saved: $backupFile" -ForegroundColor Green
        return $true
    } else {
        Write-Host " FAILED" -ForegroundColor Red
        return $false
    }
}

# --- Flash ---
function Flash-TWRP {
    Write-Host "=== FLASH TWRP ===" -ForegroundColor Cyan

    if (-not (Test-Path $TWRP_IMAGE)) {
        Write-Host "ERROR: $TWRP_IMAGE not found." -ForegroundColor Red
        Write-Host "Download from GitHub Actions or place vendor_boot.img in repo root." -ForegroundColor Yellow
        return $false
    }

    $state = Get-DeviceState
    if (-not $state.fb) {
        if ($state.adb) {
            Write-Host "Rebooting to bootloader..." -ForegroundColor Yellow
            adb reboot bootloader 2>$null
            Start-Sleep -Seconds 10
        } else {
            Write-Host "ERROR: Device not found. Enter fastboot mode (Vol Down + Power)." -ForegroundColor Red
            return $false
        }
    }

    Write-Host "Flashing vendor_boot_a..." -NoNewline
    fastboot flash vendor_boot_a $TWRP_IMAGE 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host " OK" -ForegroundColor Green } else { Write-Host " FAILED" -ForegroundColor Red; return $false }

    Write-Host "TWRP flashed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next: fastboot reboot recovery" -ForegroundColor Yellow
    return $true
}

# --- Restore Stock (Fastboot) ---
function Restore-StockFastboot {
    param([string]$StockImage)

    Write-Host "Restoring via fastboot..." -ForegroundColor Yellow

    $state = Get-DeviceState
    if (-not $state.fb) {
        if ($state.adb) {
            adb reboot bootloader 2>$null
            Start-Sleep -Seconds 10
        } else {
            return $false
        }
    }

    fastboot flash vendor_boot_a $StockImage 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }

    fastboot reboot 2>&1 | Out-Null
    return $true
}

# --- Restore Stock (BROM) ---
function Restore-StockBrom {
    param([string]$StockImage, [string]$BromExe)

    Write-Host "Restoring via BROM..." -ForegroundColor Yellow

    $bromDir = Split-Path $BromExe -Parent
    $fdl1 = "$bromDir\fdl1-dl.bin"
    $fdl2 = "$bromDir\fdl2-dl.bin"

    if (-not (Test-Path $fdl1) -or -not (Test-Path $fdl2)) {
        Write-Host "BROM files not found in: $bromDir" -ForegroundColor Red
        return $false
    }

    Push-Location $bromDir
    & $BromExe --wait 300 exec_addr $FDL1_ADDR fdl $fdl1 $FDL2_ADDR fdl $fdl2 $EXEC_ADDR exec write_part vendor_boot_a $StockImage reset
    $ok = ($LASTEXITCODE -eq 0)
    Pop-Location

    return $ok
}

# --- Restore ---
function Restore-Stock {
    Write-Host "=== RESTORE STOCK ===" -ForegroundColor Cyan

    # Find stock backup
    $stockCandidates = @(
        "$BACKUP_DIR\$(Get-ChildItem -Path $BACKUP_DIR -Filter 'vendor_boot_backup_*.img' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty Name)",
        "$SCRIPT_DIR\stock_vendor_boot.img",
        "$SCRIPT_DIR\vendor_boot_a_original.img"
    )

    $stockImage = $null
    foreach ($candidate in $stockCandidates) {
        if (Test-Path $candidate -PathType Leaf) {
            $stockImage = $candidate
            break
        }
    }

    if (-not $stockImage) {
        Write-Host "No stock backup found." -ForegroundColor Red
        Write-Host "Place stock vendor_boot image as: stock_vendor_boot.img" -ForegroundColor Yellow
        return $false
    }

    $size = '{0:N1}' -f ((Get-Item $stockImage).Length / 1MB)
    Write-Host "Stock image: $stockImage ($size MB)" -ForegroundColor Green

    # Try fastboot first
    Write-Host "Trying fastboot..." -ForegroundColor Yellow
    if (Restore-StockFastboot $stockImage) {
        Write-Host "Restore via fastboot SUCCESS!" -ForegroundColor Green
        Write-Host "Device rebooting to Android..." -ForegroundColor Yellow
        return $true
    }

    Write-Host "Fastboot failed or device not in fastboot mode." -ForegroundColor Yellow

    # Fallback to BROM
    $bromExe = Find-BromTool
    if (-not $bromExe) {
        Write-Host "BROM tools not found." -ForegroundColor Red
        Write-Host "To restore: enter BROM mode and run spd_dump manually." -ForegroundColor Yellow
        Write-Host "See RECOVERY-GUIDE.md for instructions." -ForegroundColor Yellow
        return $false
    }

    Write-Host "Falling back to BROM recovery..." -ForegroundColor Yellow
    Write-Host "Enter BROM mode: Turn OFF device, hold Vol Up+Down, connect USB." -ForegroundColor Yellow
    Write-Host "Waiting..." -ForegroundColor Green

    if (Restore-StockBrom $stockImage $bromExe) {
        Write-Host "Restore via BROM SUCCESS!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "BROM restore FAILED." -ForegroundColor Red
        return $false
    }
}

# --- Boot Recovery ---
function Boot-Recovery {
    Write-Host "=== BOOT RECOVERY ===" -ForegroundColor Cyan
    $state = Get-DeviceState

    if ($state.fb) {
        fastboot reboot recovery 2>&1 | Out-Null
        Write-Host "Rebooting to recovery..." -ForegroundColor Green
        return $true
    } elseif ($state.adb) {
        adb reboot recovery 2>&1 | Out-Null
        Write-Host "Rebooting to recovery..." -ForegroundColor Green
        return $true
    } else {
        Write-Host "No device detected. Boot to recovery manually." -ForegroundColor Red
        return $false
    }
}

# --- Info ---
function Show-Info {
    Write-Host "=== TWRP Flash Tool ===" -ForegroundColor Cyan
    $state = Get-DeviceState
    $a = if ($state.adb)   { "YES" } else { "no" }
    $f = if ($state.fb)    { "YES" } else { "no" }
    $b = if ($state.brom)  { "YES" } else { "no" }

    Write-Host "Device:"
    Write-Host "  ADB:      $a"
    Write-Host "  Fastboot: $f"
    Write-Host "  BROM:     $b"
    Write-Host ""

    Write-Host "Files:"
    if (Test-Path $TWRP_IMAGE) {
        $s = '{0:N1}' -f ((Get-Item $TWRP_IMAGE).Length / 1MB)
        Write-Host "  vendor_boot.img: $s MB" -ForegroundColor Green
    } else {
        Write-Host "  vendor_boot.img: NOT FOUND" -ForegroundColor Red
    }

    $backups = @(Get-ChildItem -Path $BACKUP_DIR -Filter "vendor_boot_backup_*.img" -ErrorAction SilentlyContinue)
    Write-Host "  Backups: $($backups.Count) file(s)" -ForegroundColor $(if ($backups.Count -gt 0) { "Green" } else { "Yellow" })

    $bromExe = Find-BromTool
    if ($bromExe) {
        Write-Host "  BROM tool: Available" -ForegroundColor Green
    } else {
        Write-Host "  BROM tool: Not found (restore via BROM unavailable)" -ForegroundColor Yellow
    }
}

# --- Interactive Menu ---
function Show-Menu {
    $state = Get-DeviceState

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  TWRP Flash Tool - Realme C53 (RMX3760)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  State: $($state.label)" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  1 - Flash TWRP"
    Write-Host "  2 - Restore Stock"
    Write-Host "  3 - Backup Current Vendor Boot"
    Write-Host "  4 - Boot to Recovery"
    Write-Host "  5 - Show Info"
    Write-Host "  q - Quit"
    Write-Host ""
    $sel = Read-Host "Choose"

    switch ($sel) {
        "1" { Flash-TWRP; pause }
        "2" { Restore-Stock; pause }
        "3" { Backup-VendorBoot; pause }
        "4" { Boot-Recovery; pause }
        "5" { Show-Info; pause }
        "q" { return }
        default { Write-Host "Invalid choice" -ForegroundColor Red; pause }
    }
}

# --- Main ---
try {
    if ($Info)   { Show-Info; return }
    if ($Backup) { Backup-VendorBoot; return }
    if ($Flash)  { Flash-TWRP; return }
    if ($Restore){ Restore-Stock; return }
    if ($Boot)   { Boot-Recovery; return }
    if ($Mode) {
        switch ($Mode) {
            "fastboot" { Flash-TWRP }
            "brom"     { Restore-Stock }
            "adb"      { Backup-VendorBoot }
        }
        return
    }

    # Interactive
    do {
        Show-Menu
    } while ($true)

} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    pause
}
