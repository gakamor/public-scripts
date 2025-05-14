<#
.Synopsis

    If an application installer has numerous files, there can be deployment speed benefits when combining the install 
    files into a WIM. The WIM is transferred to the target and mounted. Then setup is executed from the mounted WIM.

    This script is intended to be used in conjunction with the PowerShell Application Deployment Toolkit (PSADT) and
    extremely large applications if your deployment tool has file size limits. This script splits the WIM into 
    multiple parts so they can be uploaded to your deployment tool. 

    Once the split WIM files have been deployed to the target, they are recombined so that the WIM can be mounted as normal.

.EXAMPLE
    
    Split the target WIM into multiple parts that are 5GB in size (default)
    .\Split-ADTWim.ps1 -WimPath C:\temp\SolidWorks2025.wim

    Split the target WIM into multiple parts that are 2GB in size and remove the source WIM file
    .\Split-ADTWim.ps1 -WimPath C:\temp\SolidWorks2025.wim -FileSizeMB 2000 -RemoveSourceWIM

#>

param (
    [Parameter(Mandatory = $true)]
    [string]$WimPath,

    [Parameter(Mandatory = $false)]
    [int]$FileSizeMB = 5000,

    [Parameter(Mandatory = $false)]
    [switch] $RemoveSourceWIM
)

#Requires -RunAsAdministrator

# Validate if the input WIM file exists
if (-not (Test-Path $WimPath -PathType Leaf)) {
    Write-Error "The specified WIM file '$WimPath' does not exist."
    Exit 1
}

#Output split WIM into the same directory
$OutputDir = (Get-ChildItem -Path $WimPath).DirectoryName

# Set the base name for split WIM files
$BaseName = [System.IO.Path]::GetFileNameWithoutExtension($WimPath)
$OutputFile = Join-Path -Path $OutputDir -ChildPath "$BaseName.swm"

Write-Host "Splitting WIM file: $WimPath"
Write-Host "Saving parts to: $OutputDir"
Write-Host "Maximum split file size: ${FileSizeMB}MB"

# Perform the split operation
try {
    Split-WindowsImage -ImagePath $WimPath -SplitImagePath $OutputFile -FileSize $FileSizeMB
    if ($RemoveSourceWIM) {
        Write-Output "Removing Source WIM..."
        Start-Sleep -Seconds 5
        Remove-Item -Path $WimPath -Force
    }
    Write-Host "WIM file successfully split into parts at '$OutputDir'"
} catch {
    Write-Error "Failed to split WIM file: $_"
}

# Code for use in PSADT package
<#

# Combine split WIM for mounting
$splitWimFiles = Get-ChildItem -Path ".\Files\*.swm"
$sourceSWM = ($splitWimFiles[0]).FullName
$filePattern = ($splitWimFiles[0]).Name -replace '.swm',''
Export-WindowsImage -SourceImagePath $sourceSWM -SplitImageFilePattern ".\Files\$filePattern*.swm" -SourceIndex 1 -DestinationImagePath ".\Files\$filePattern.wim" | Out-Null
$splitWimFiles | Remove-Item -Force

#>
