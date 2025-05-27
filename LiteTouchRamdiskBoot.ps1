<#

.Synopsis
    This script will create a ramdisk containing the LiteTouchPE_x64.wim which the computer will boot to on restart.
    Unlike running LiteTouch.vbs, this method will perform the "Format and Partition Disk" MDT task.

.Prerequisites
    - From the deployment share, copy LiteTouchPE_x64.wim in the Boot folder to C:\Sources on the target
    - On the target, rename LiteTouchPE_x64.wim to boot.wim
    - From the deployment share, copy the Boot\x64\Boot folder to C:\ on the target

.Notes
    C:\Sources will be removed if LiteTouch is cancelled before the task sequence starts. 
    Because "bcdedit /bootsequence" is used, the computer should boot back into Windows when restarted if LiteTouch is cancelled.

#>

#Requires -RunAsAdministrator

# Checks that Disk 0 is the boot disk.
$DISKZERO = Get-Disk 0
if ($DISKZERO.IsBoot -ne $true) {
Write-Output "Disk 0 is not the boot disk. Exiting..."
    Exit 999
}
else {
    Write-Output "Disk 0 is the boot disk. Proceeding..."
}

# Create {ramdiskoptions} and configure
bcdedit -create "{ramdiskoptions}"
bcdedit /set "{ramdiskoptions}" ramdisksdidevice partition=C:
bcdedit /set "{ramdiskoptions}" ramdisksdipath \boot\boot.sdi

# Add LiteTouch boot device to OSLOADER
$Output = bcdedit -create /d "LiteTouch MDT" /application OSLOADER

# Obtain LiteTouch boot device GUID
$LTGUID = $Output | %{ $_.split(' ')[2] }

# Configure LiteTouch to ramdisk boot
bcdedit /set $LTGUID device "ramdisk=[C:]\sources\boot.wim,{ramdiskoptions}"
bcdedit /set $LTGUID osdevice "ramdisk=[C:]\sources\boot.wim,{ramdiskoptions}"
bcdedit /set $LTGUID systemroot \windows
bcdedit /set $LTGUID detecthal yes
bcdedit /set $LTGUID winpe yes

# Adjust for UEFI vs Legacy BIOS types
if ($env:firmware_type -eq 'UEFI'){
Write-Output "UEFI boot confirmed."
    bcdedit /set $LTGUID path \windows\system32\boot\winload.efi
}
else {
Write-Output "Legacy boot confirmed."
    bcdedit /set $LTGUID path \windows\system32\boot\winload.exe
}

# Force LiteTouch ramdisk on next boot and restart
bcdedit /bootsequence $LTGUID
Restart-Computer -Force
