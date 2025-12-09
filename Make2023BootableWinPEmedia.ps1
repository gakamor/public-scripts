<#
    Requires December 2024 ADK with WinPE addon or later.

    This script updates a WinPE ISO to use boot binaries signed with the 'Windows UEFI CA 2023' certificate.
    The original ISO is left intact and a new ISO is created at C:\winpe_files

    Use the -NoPrompt switch if you do not want to press "any key" when booting to the new ISO

    Examples:
    .\Make2023BootableWinPEmedia.ps1 -ISOPath "C:\iso\MyWinPE.iso"
    .\Make2023BootableWinPEmedia.ps1 -ISOPath "C:\iso\MyWinPE.iso" -NoPrompt

    NOTE: If your environment is fully remediated against Black Lotus vulnerabilites, this script 
    does not apply the latest SVN to the new ISO . If you need the latest SVN, apply the latest 
    Cumulative Update to your "C:\winpe_setup\extracted_ISO\Sources\boot.wim" and recreate the ISO manually. (Untested but I think it will work)
    https://learn.microsoft.com/en-us/windows/deployment/customize-boot-image?tabs=powershell#step-7-add-cumulative-update-cu-to-boot-image
#>

param (

	[Parameter(mandatory=$true)]
	[string] $ISOPath,

	[Parameter(mandatory=$false)]
	[switch] $NoPrompt    

)

#Requires -RunAsAdministrator

# Define variables and create folder structure
$WinPE_Architecture = "amd64" # or arm64
$ADK_Path = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit"
$WinPE_ADK_Path = $ADK_Path + "\Windows Preinstallation Environment"
$winpeWIM = "$WinPE_ADK_Path\$WinPE_Architecture\en-us\winpe.wim"

$OSCDIMG_Path = $ADK_Path + "\Deployment Tools" + "\$WinPE_Architecture\Oscdimg"

$setupFolder = "C:\winpe_setup"
if (Test-Path -Path $setupFolder) {
    Remove-Item -Path $setupFolder -Recurse -Force # Delete setup folder if it exists
}
if (-not (Test-Path -Path $setupFolder)) {
    New-Item -Path $setupFolder -ItemType Directory -Force | Out-Null
}

$mountPathwinpeWIM = "$setupFolder\adk_winpe_wim"
if (-not (Test-Path -Path $mountPathwinpeWIM)) {
    New-Item -Path $mountPathwinpeWIM -ItemType Directory -Force | Out-Null
}

$outputFolder = "C:\winpe_files"
if (-not (Test-Path -Path $outputFolder)) {
    New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
}

# Validate ISO and ADK
if (-not (Test-Path -Path $ADK_Path)) {
    throw "ADK not found. Please ensure that the Dec 2024 ADK or later is installed."
}
if (-not (Test-Path -Path $winpeWIM)) {
    throw "WinPE ADK addon not found. Please ensure that the WinPE ADK addon is installed."
}
if (-not (Test-Path -Path $ISOPath)) {
    throw "Target ISO is not found. Please ensure that the path is correct."
}

# Extract ISO to folder and get volume label
$extractedISO = "$setupFolder\extracted_ISO"
if (-not (Test-Path -Path $extractedISO)) {
    New-Item -Path $extractedISO -ItemType Directory -Force | Out-Null
}

$mountedISO = Mount-DiskImage -ImagePath $ISOPath -PassThru
$driveLetter = ($mountedISO | Get-Volume).DriveLetter
$isoLabel = (Get-Volume -DriveLetter ($mountedISO | Get-Volume).DriveLetter).FileSystemLabel
if (-not ($isoLabel)){
    $isoLabel = "2023PCAWINPE"
}

Write-Output "Copying ISO contents to staging area..."
Copy-Item "$($driveLetter):\*" -Destination $extractedISO -Recurse
Dismount-DiskImage -ImagePath $ISOPath | Out-Null
Get-ChildItem -Path $extractedISO -Recurse -File | Set-ItemProperty -Name IsReadOnly -Value $false

# Update ISO media files
Write-Output "Updating ISO media files..."
Copy-Item "$WinPE_ADK_Path\$WinPE_Architecture\Media\*" "$extractedISO" -Recurse -Force

# Mount ADK winpe.wim
Write-Output "Mounting ADK WinPE WIM for access to 2023 boot manager binaries..."
Mount-WindowsImage -ImagePath $winpeWIM -Index 1 -Path $mountPathwinpeWIM -ReadOnly | Out-Null
 
# Copy from mounted ADK winpe.wim bootmgfw_EX.efi to extracted ISO as \EFI\BOOT\bootx64.efi and \EFI\MICROSOFT\BOOT\bootmgfw.efi
Write-Output "Updating ISO boot manager files with 2023 binaries..."
Copy-Item -Path "$mountPathwinpeWIM\Windows\Boot\EFI_EX\bootmgfw_EX.efi" -Destination "$extractedISO\EFI\BOOT\bootx64.efi" -Force
Copy-Item -Path "$mountPathwinpeWIM\Windows\Boot\EFI_EX\bootmgfw_EX.efi" -Destination "$extractedISO\EFI\MICROSOFT\BOOT\bootmgfw.efi" -Force
Dismount-WindowsImage -Path $mountPathwinpeWIM -Discard | Out-Null

# arm64 fix
if ($WinPE_Architecture -eq "arm64") {
    if (-not (Test-Path -Path "$OSCDIMG_Path\etfsboot.com")) {
        $etfsboot = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\etfsboot.com"
        Copy-Item $etfsboot -Destination "$OSCDIMG_Path\etfsboot.com" -Force
    }
}
    
# Create ISO using efisys_EX.bin or efisys_noprompt_EX.bin
Write-Output "Creating new ISO..."
$filename = Get-ChildItem -Path $ISOPath -Name
$newISO = Join-Path $outputFolder $filename

if ($NoPrompt) {
    $bootData='2#p0,e,b"{0}"#pEF,e,b"{1}"' -f "$OSCDIMG_Path\etfsboot.com","$OSCDIMG_Path\efisys_noprompt_EX.bin"
}
else {
    $bootData='2#p0,e,b"{0}"#pEF,e,b"{1}"' -f "$OSCDIMG_Path\etfsboot.com","$OSCDIMG_Path\efisys_EX.bin"
}

$oscdimg = Start-Process -FilePath "$OSCDIMG_Path\oscdimg.exe" -ArgumentList @("-l$isoLabel","-bootdata:$bootData",'-u2','-udfver102',"$extractedISO","$newISO") -PassThru -Wait -NoNewWindow
if($oscdimg.ExitCode -ne 0)
{
    throw "Failed to generate ISO with exitcode: $($oscdimg.ExitCode)"
}
    
Write-Output "`nUpdated ISO located at `"$newISO`""
