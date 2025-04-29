<# 

.Synopsis
    This script will force the target computer to PXE boot if it is configured for UEFI mode
    and disk 0 is the boot disk.
    
    Error Code 1 = Not configured for UEFI mode
    Error Code 2 = Disk 0 is not the boot disk. Useful if the intent is to reimage the target.
    Error Code 3 = Network boot option likely missing from script.

    The script relies on network boot option keywords. Some common network boot keywords are 
    included but you may need to add more keywords to the script if you get Error Code 3. If 
    you get Error Code 3, look at the output to find the name of your network boot option.
    
        Included Keywords:
        IPV4 = most network boot options
        EFI Network = Hyper-V network boot option
        UEFI:Network Device = some Lenovo devices
        IP4 = another common network boot option

#> 

#Requires -RunAsAdministrator

$keywords = "IPV4|EFI Network|UEFI:Network Device|IP4"

# Audit mode prevents the changes to the boot order and suppresses the reboot.
# Allows you to confirm that the script is selecting the correct network boot option by viewing the output.
$auditMode = $false

# Ensure device is in UEFI boot mode
if ($env:firmware_type -ne "UEFI") {
    Write-Output "Device is not configured for UEFI booting."
    Exit 1
}

# Checks that Disk 0 is the boot disk.
$diskZero = Get-Disk 0
if ($diskZero.IsBoot -ne $true) {
    Write-Output "Disk 0 is not the boot disk. Exiting..."
    Exit 2
}

try {
    # Get all boot options
    $bcdOutput = bcdedit /enum firmware

    # Search for network boot option based on keywords variable and capture the GUID of that boot option.
    $FullLine = ($bcdOutput | Select-String "$keywords" -Context 1 -ErrorAction Stop).Context.PreContext[0]

    # Remove all text but the GUID
    $GUID = '{' + $FullLine.split('{')[1]

    if ($auditMode) {
        Write-Output "AUDIT MODE: bcdedit /set `"{fwbootmgr}`" bootsequence `"$GUID`""
        Write-Output "AUDIT MODE: Make sure the GUID matches the network boot device below."
        Write-Output "AUDIT MODE: Captured bcdedit output:"
        Write-Output $bcdOutput
    }
    else {
        # Add the network boot option to the top of the boot order on next boot
        Write-Output "Temporarily adjusting boot order..."
        bcdedit /set "{fwbootmgr}" bootsequence "$GUID"
        
        Write-Output "Restarting the computer..."
        shutdown /r /t 10 /f
    }
}
catch {
    Write-Output "An error occurred. The network boot option for this device may need to be added to the script. Confirm the network boot option in the bcdedit output."
    Write-Output "Captured bcdedit output:"
    Write-Output $bcdOutput
    Exit 3
}
