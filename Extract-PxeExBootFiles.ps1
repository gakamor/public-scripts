<#

    This script extracts PXE boot files for WDS from the Windows ADK PE addon
    that are signed by the 2023 PCA.

    Install the latest ADK and matching WinPE addon before running this script. 
    https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install

#>

#Requires -RunAsAdministrator

$architecture = "amd64" # amd64 or arm64
$winpePath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\$architecture\en-us\winpe.wim"
$mountPath = "C:\Mount_WinPE"
$newPxeFilesPath = "C:\NewPXEFiles"

Import-Module Dism
if (-not (Test-Path -Path $mountPath)) {
    New-Item -Path $mountPath -ItemType Directory | Out-Null
}

if (-not (Test-Path -Path $newPxeFilesPath)) {
    New-Item -Path $newPxeFilesPath -ItemType Directory | Out-Null
}

Mount-WindowsImage -ImagePath $winpePath -Index 1 -Path $mountPath -ErrorAction Stop | Out-Null
Copy-Item -Path "$mountPath\Windows\Boot\PXE_EX\wdsmgfw_ex.efi" -Destination "$newPxeFilesPath\wdsmgfw.efi" -Force
Copy-Item -Path "$mountPath\Windows\Boot\EFI_EX\bootmgfw_ex.efi" -Destination "$newPxeFilesPath\bootmgfw.efi" -Force
Dismount-WindowsImage -Path $mountPath -Discard | Out-Null

if ($architecture -eq "amd64") {
    Write-Output "Copy files in $newPxeFilesPath to C:\RemoteInstall\Boot\x64 on your WDS server after making a backup of the 2 files being replaced."
}
elseif ($architecture -eq "arm64") {
    Write-Output "Copy files in $newPxeFilesPath to C:\RemoteInstall\Boot\arm64 on your WDS server after making a backup of the 2 files being replaced."
}
else {
    Write-Output "Invalid architecture"
}

Remove-Item -Path $mountPath -Force
