<#

    This script performs tasks necessary to integrate Abaqus, Intel Fortran, and Visual Studio.

    - Installs Visual Studio "Desktop development with C++" workload
    - Uninstalls existing Intel oneAPI and removes C:\Program Files (x86)\Intel\oneAPI to ensure a clean environment for reinstall.
    - Adds new items to the PATH system environment variable.
    - If Abaqus 2025 or lower and Intel oneAPI 2025 or higher, makes necessary adjustments to utilize ifx instead of ifort.

    Do not use Intel oneAPI 2022.1 or lower. It will no longer integrate with Visual Studio.

    After this script completes:
    
    1. Install the version of Intel oneAPI Basekit and HPC that was specified in the parameters.
    2. Add the following lines to the C:\SIMULIA\Commands\abqXXXX.bat file after "setlocal".

       call "C:\Program Files (x86)\Intel\oneAPI\setvars.bat" intel64 vs20XX
       call "C:\Program Files (x86)\Microsoft Visual Studio\20XX\Community\VC\Auxiliary\Build\vcvars64.bat"

       Replace the XX values with your version of Visual Studio.

#>

param(
    [Parameter(Mandatory = $true)]
    [string]$VisualStudioYear,
    
    [Parameter(Mandatory = $true)]
    [string]$AbaqusYear,

    [Parameter(Mandatory = $true)]
    [string]$oneapiVersion #text string that needs to be in the environment variable path
)

# Function to ensure version numbers are padded out to major/minor/build/revision format
function Normalize-Version {
    param (
        [string]$versionString
    )

    $parts = $versionString.Split('.')
    while ($parts.Count -lt 4) {
        $parts += '0'
    }

    $normalized = $parts -join '.'
    return [version]$normalized
}

# Verify Visual Studio and Abaqus are installed
$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
$vsReg = Get-ChildItem -Path $regPaths | Get-ItemProperty | Where-Object {($_.DisplayName -match "^Visual Studio (Community|Professional|Enterprise) $VisualStudioYear")}

if ($vsReg) {
    Write-Output "$($vsReg.DisplayName) found"
}
else {
    Write-Output "Visual Studio $VisualStudioYear not found"
}

$abq = Test-Path "C:\SIMULIA\EstProducts\$AbaqusYear"
if ($abq) {
    Write-Output "Abaqus $AbaqusYear found"
}
else {
    Write-Output "Abaqus $AbaqusYear not found"
}

if (-not ($vsReg) -or -not ($abq)) {
    Write-Output "Requirements not met"
    Exit 999
}

# Install Visual Studio workload if needed
$vsWhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
$desktopDevExists = & $vsWhere -products * -requires Microsoft.VisualStudio.Workload.NativeDesktop -property instanceId

if ($desktopDevExists) {
    Write-Output "Desktop development with C++ workload is already installed."
}
else {
    
    $vsInstaller = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe"
    $vsPath = "$($vsReg.InstallLocation)"
    $vsArguments = "modify --installPath `"$vsPath`" --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended --quiet --norestart"
    Write-Output "Installing Desktop development with C++ workload"
    Start-Process -FilePath $vsInstaller -ArgumentList $vsArguments
    Start-Sleep -Seconds 30
    while (Get-Process -Name setup -ErrorAction SilentlyContinue) {
        Start-Sleep -Seconds 30
    }

}

# Ensure clean oneAPI environment
$intelInstaller = "C:\Program Files (x86)\Intel\oneAPI\Installer\installer.exe"
$ids = @()

if (Test-Path $intelInstaller) {
    $cmd = "`"$intelInstaller`" --list-products"
    $output = cmd /c $cmd

    foreach ($line in $output) {
        # Skip header and separator lines
        if ($line -match '^\s*$' -or $line -match '^=+' -or $line -match '^ID\s+') { continue }

        # Match the ID at the beginning of the line
        if ($line -match '^(\S+)') {
            $ids += $matches[1]
        }
    }

    # Uninstall oneAPI products
    foreach ($id in $ids) {
        Write-Output "Uninstalling $id"
        Start-Process -FilePath $intelInstaller -ArgumentList "--action remove --product-id $id --silent" -Wait
    }

    # Remove any remaining oneAPI files
    Remove-Item -Path "C:\Program Files (x86)\Intel\oneAPI" -Recurse -Force -ErrorAction SilentlyContinue
}

# Modify PATH environment variable if necesssary
$oldPath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path

$newPathsToAdd = @(
    "C:\Program Files (x86)\Intel\oneAPI\compiler\$oneapiVersion\env",
    "$vsPath\VC\Auxiliary\Build"
)

# Filter out paths that already exist in $oldPath
$pathsToAppend = $newPathsToAdd | Where-Object { $oldPath -notlike "*$_*" }

# Only update PATH if there are new paths to add
if ($pathsToAppend.Count -gt 0) {
    $newPath = ($pathsToAppend -join ";") + ";" + $oldPath
    Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath
    Write-Output "PATH updated with new entries:"
    $pathsToAppend | ForEach-Object { Write-Output " - $_" }
} else {
    Write-Output "No new paths to add. PATH is already up to date."
}

# Adjust Fortran compiler from ifort to ifx
# https://community.intel.com/t5/Blogs/Tech-Innovation/Tools/A-Historic-Moment-for-The-Intel-Fortran-Compiler-Classic-ifort/post/1614625
# https://support.3ds.com/knowledge-base/?q=docid:QA00000329750
# https://community.intel.com/t5/Intel-Fortran-Compiler/Linking-Abaqus-2025-with-VS-2022-and-OneAPI-2025-Fortran/td-p/1702177
$oneapiVersionNormalized = Normalize-Version -versionString $oneapiVersion
if ($oneapiVersionNormalized -ge [version]"2025.0.0.0") {

    $win86_64envPath = "C:\SIMULIA\EstProducts\$AbaqusYear\win_b64\SMA\site\win86_64.env"
    $content = Get-Content -Raw -Path $win86_64envPath
    
    if ($AbaqusYear -le "2025") {
        # for Abaqus 2025 and below
        $updatedContent = $content -replace 'ifort', 'ifx' -replace "'/Qimf-arch-consistency:true',", "#'/Qimf-arch-consistency:true',"
        
        $abaqusv6envPath = "C:\SIMULIA\EstProducts\$AbaqusYear\win_b64\SMA\site\abaqus_v6.env"
        
$appendBlock = @"
# Run subroutines (compatible with previous compilers)
compile_fortran.append("/names:lowercase")

# Overwrite linking options
link_sl = 'LINK /NODEFAULTLIB:LIBCMT.LIB /dll /def:%E /out:%U %F %A %L %B'
"@

        $content2 = Get-Content -Raw -Path $abaqusv6envPath

        if ($content2 -notmatch [regex]::Escape($appendBlock.Trim())) {
            Add-Content -Path $abaqusv6envPath -Value "`r`n`n$appendBlock"
        }

    }
    else {
        # for Abaqus 2026 and above (untested, may not be necessary)
        $updatedContent = $content -replace 'ifort', 'ifx'
    }


    Set-Content -Path $win86_64envPath -Value $updatedContent
    Write-Output "Changed Abaqus config to use ifx compiler instead of ifort compiler"


}
