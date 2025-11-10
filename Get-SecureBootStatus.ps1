<# 
    This script returns the following information related to Secure Boot:
    - Checks if Secure Boot is enabled
    - 2023 Secure Boot certificates are installed
    - Windows boot manager file is signed with the 2023 certificate
    - 2011 PCA certificate is revoked for Black Lotus remediation
    - Microsoft UEFI CA 2011 is installed in UEFI (if not present, the 2023 equivalent and the 2023 Option ROM may not install)
    - Current value of the AvailableUpdate registry entry
    - Latest Event Log entry for required reboots related to Secure Boot

    AvailableUpdates:
    5944 - Apply all 2023 certificates and update the boot manager

    Order of processing the hex bits:
    40   - Apply the Windows UEFI CA 2023 to the db
    800  - Apply the Microsoft UEFI CA 2023 to the db (if the 2011 is present)
    1000 - Apply the Microsoft Option ROM CA 2023 to the db (if 2011 is present)
    4    - Look for the KEK signed by OEM PK
    100  - Apply the 2023 boot manager
    4000 - Finished processing

    https://support.microsoft.com/en-us/topic/registry-key-updates-for-secure-boot-windows-devices-with-it-managed-updates-a7be69c9-4634-42e1-9ca1-df06f43f360d
    https://support.microsoft.com/en-us/topic/secure-boot-db-and-dbx-variable-update-events-37e47cf8-608b-4a87-8175-bdead630eb69
    https://support.microsoft.com/en-us/topic/secure-boot-certificate-updates-guidance-for-it-professionals-and-organizations-e2b43f9f-b424-42df-bc6a-8476db65ab2f
    https://support.microsoft.com/en-us/topic/windows-secure-boot-certificate-expiration-and-ca-updates-7ff40d33-95dc-4c3c-8725-a9b95457578e
    https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-secure-boot-key-creation-and-management-guidance?view=windows-11#14-signature-databases-db-and-dbx
    https://support.microsoft.com/en-us/topic/how-to-manage-the-windows-boot-manager-revocations-for-secure-boot-changes-associated-with-cve-2023-24932-41a975df-beb2-40c1-99a3-b3ff139f832d

#>
if ($env:firmware_type -ne "UEFI") {
    # Exit script if set to legacy BIOS
    Exit 0
}

$secureBootEnabled = Confirm-SecureBootUEFI
$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
$valueName = 'AvailableUpdates'

if ($null -ne (Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue)) {
    $value = Get-ItemPropertyValue -Path $regPath -Name $valueName
    $hex = [System.Convert]::ToString($value, 16)

    # Check for reboot required event
    $rebootEvent = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-TPM-WMI'; Id=1800} -MaxEvents 1 -ErrorAction SilentlyContinue

}
else {
    $hex = 'AvailableUpdates registry value does not exist'
}

# Check for 2023 Secure Boot certificates in UEFI
$uefiWin2023CA = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2023'
$uefi2023kek = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI kek).bytes) -match 'Microsoft Corporation KEK 2K CA 2023'
$uefiMS2023CA = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Microsoft UEFI CA 2023'
$uefiROM2023CA = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Microsoft Option ROM CA 2023'
$uefiMS2011 = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Microsoft UEFI CA 2011'

# Check if Windows boot manager file is signed by the 2023 certificate (credit to Gary Blok https://garytown.com/)
$volume = Get-Volume | Where-Object {$_.FileSystemType -eq "FAT32" -and $_.DriveType -eq "Fixed"}
$systemDisk = Get-Disk | Where-Object {$_.IsSystem -eq $true}
$systemPartition = Get-Partition -DiskNumber $systemDisk.DiskNumber | Where-Object {$_.IsSystem -eq $true}
$systemVolume = $volume | Where-Object {$_.UniqueId -match $systemPartition.Guid}
$filePath = "$($systemVolume.Path)\EFI\Microsoft\Boot\bootmgfw.efi"
$certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
$certCollection.Import($filePath, $null, 'DefaultKeySet')
if ($certCollection.Subject -like "*Windows UEFI CA 2023*") {
    $bootManager2023 = $true
}
else {
    $bootManager2023 = $false
}

# Check for 2011 certificate revocation
$uefi2011PCArevoked = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbx).bytes) -match 'Windows Production PCA 2011'

[PSCustomObject]@{
    'SecureBoot'            = $secureBootEnabled
    'Windows UEFI CA 2023'  = $uefiWin2023CA
    'MS KEK CA 2023'        = $uefi2023kek
    'MS UEFI CA 2023'       = $uefiMS2023CA
    'MS Option ROM CA 2023' = $uefiROM2023CA
    'MS UEFI CA 2011'       = $uefiMS2011
    'Boot Manager 2023'     = $bootManager2023
    '2011 PCA Revoked'      = $uefi2011PCArevoked
    'AvailableUpdates'      = $hex
    'Reboot Log Time'       = if ($rebootEvent) {$($rebootEvent.TimeCreated).ToString("MM/dd/yyyy HH:mm")} else {$null}
    'Reboot Log Message'    = $rebootEvent.Message
}
