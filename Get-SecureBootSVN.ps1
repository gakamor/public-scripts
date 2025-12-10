<#

    This script checks the Secure Boot SVN in UEFI and the SVN of a boot manager file.
    If you do not specify a boot manager path with, it will default to the Windows boot manager.

    Credit to https://www.elevenforum.com/t/finding-the-uefis-dbx-svn-number-using-powershell.42594/
    and https://github.com/cjee21/Check-UEFISecureBootVariables for figuring out how to query SVN
    from Windows.

    Usage:

    Query the Windows Boot Manager and UEFI SVN
    .\Get-SecureBootSVN.ps1

    Query alternate boot manager (WinPE for example)
    .\Get-SecureBootSVN.ps1 -BootManagerPath "D:\bootmgr.efi"

#>

#Requires -RunAsAdministrator

param (
    [Parameter(Mandatory = $false)]
    [string]$BootManagerPath
)

#### Get SVN from UEFI ####


# Get DBX as raw bytes from UEFI and convert to continuous hex string
$dbxBytes = (Get-SecureBootUEFI -Name dbx).Bytes
$dbxHex = ($dbxBytes | ForEach-Object { '{0:x2}' -f $_ }) -join ''

# Regex pattern for the DBX entry that carries the SVN
#    The prefix 01612b139dd5598843ab1c185c3cb2eb92 is the known GUID/hash
#    The dots match the variable payload that includes version fields.
$svnPattern = '01612b139dd5598843ab1c185c3cb2eb92...........'

# Find all matches
$matches = [Regex]::Matches($dbxHex, $svnPattern)
$matchValues = $matches.Value

# Get the "highest" match (contains highest version)
$DBXSVN = $matchValues | Sort-Object | Select-Object -Last 1

if ($DBXSVN) {

    # SVN Major is at byte offsets 36–37 (4 hex chars)
    $uefiSvnMajorHex = $DBXSVN.Substring(36, 4)
    $uefiSvnMajor = [int]::Parse($uefiSvnMajorHex, [System.Globalization.NumberStyles]::HexNumber)

    # SVN Minor is at byte offsets 40–41 (4 hex chars)
    $uefiSvnMinorHex = $DBXSVN.Substring(40, 4)
    $uefiSvnMinor = [int]::Parse($uefiSvnMinorHex, [System.Globalization.NumberStyles]::HexNumber)

    $uefiSVN = [version]::new($uefiSvnMajor, $uefiSvnMinor)

}



#### Get SVN from boot manager ####

if ($BootManagerPath) {
    # Use specified boot manager path
    $filePath = $BootManagerPath
}
else {
    # Get Windows Boot Manager file path
    $volume = Get-Volume | Where-Object {$_.FileSystemType -eq "FAT32" -and $_.DriveType -eq "Fixed"}
    $systemDisk = Get-Disk | Where-Object {$_.IsSystem -eq $true}
    $systemPartition = Get-Partition -DiskNumber $systemDisk.DiskNumber | Where-Object {$_.IsSystem -eq $true}
    $systemVolume = $volume | Where-Object {$_.UniqueId -match $systemPartition.Guid}
    $filePath = "$($systemVolume.Path)\EFI\Microsoft\Boot\bootmgfw.efi"
}

# Define Windows API functions using P/Invoke
if (-not ([PSObject].Assembly.GetType("ResourceHelper"))) {
    Add-Type -TypeDefinition @'
        using System;
        using System.Runtime.InteropServices;
        using System.Text;

        public class ResourceHelper {
            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern IntPtr LoadLibraryEx(string lpFileName, IntPtr hFile, uint dwFlags);
            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern IntPtr FindResource(IntPtr hModule, string lpName, uint lpType);
            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern IntPtr LoadResource(IntPtr hModule, IntPtr hResInfo);
            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern IntPtr LockResource(IntPtr hResData);
            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern uint SizeofResource(IntPtr hModule, IntPtr hResInfo);
            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern bool FreeLibrary(IntPtr hModule);

            // Constants
            public const uint LOAD_LIBRARY_AS_DATAFILE = 0x00000002;
            public const uint RT_RCDATA = 10;
        }
'@
}

$resourceName = "BOOTMGRSECURITYVERSIONNUMBER"

$hModule = [ResourceHelper]::LoadLibraryEx($filepath, [IntPtr]::Zero, [ResourceHelper]::LOAD_LIBRARY_AS_DATAFILE)
if ($hModule -eq [IntPtr]::Zero) {
    Write-Error "Failed to load the file as a data file. Win32 Error: $('0x{0:X}' -f [System.Runtime.InteropServices.Marshal]::GetLastWin32Error())"
    return $null
}

try {
    $hResInfo = [ResourceHelper]::FindResource($hModule, $resourceName, [ResourceHelper]::RT_RCDATA)
    if ($hResInfo -eq [IntPtr]::Zero) {
        Write-Error "Resource '$resourceName' not found in the file."
        return $null
    }

    $hResData = [ResourceHelper]::LoadResource($hModule, $hResInfo)
    $pResourceBytes = [ResourceHelper]::LockResource($hResData)
    $resourceSize = [ResourceHelper]::SizeofResource($hModule, $hResInfo)

    if ($pResourceBytes -eq [IntPtr]::Zero -or $resourceSize -eq 0) {
        Write-Error "Failed to load or lock resource data."
        return $null
    }

    # Copy the raw bytes without conversion or trimming
    $bmBytes = New-Object byte[] $resourceSize
    [System.Runtime.InteropServices.Marshal]::Copy($pResourceBytes, $bmBytes, 0, $resourceSize)

} finally {
    if ($hModule -ne [IntPtr]::Zero) {
        [ResourceHelper]::FreeLibrary($hModule) | Out-Null
    }
}

$bmMinorBytes = $bmBytes[0..1]
$bmSvnMinor = [System.BitConverter]::ToInt16($bmMinorBytes, 0)
$bmMajorBytes = $bmBytes[2..3]
$bmSvnMajor = [System.BitConverter]::ToInt16($bmMajorBytes, 0)
$bmSNV = [version]::new($bmSvnMajor, $bmSvnMinor)

[PSCustomObject]@{

    'UEFI SVN'         = if ($DBXSVN) { $uefiSVN } else { "Unavailable" }
    'Boot Manager SVN' = if ($bmBytes) { $bmSNV } else { "Unavailable" }

}
