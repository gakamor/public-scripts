<#
This script uninstalls the Windows Updates listed in $KBs.
Example using August 2025 Cumulative Updates

KB5063878 Win11 24H2
KB5063875 Win11 22H2/23H2
KB5064010 Win11 LTSC 2024
KB5063709 Win10 22H2 & LTSC 2021
KB5063877 Win10 LTSC 2019
#>

$KBs = "KB5063878|KB5063875|KB5064010|KB5063709|KB5063877"

# Get all installed update packages
$allUpdates = Get-WindowsPackage -Online | Where-Object { 
    $_.ReleaseType -like "*Update*" -and $_.PackageState -eq "Installed" 
}

# Check each update's description for matching KB and remove the update
foreach ($update in $allUpdates) {
    $match = Get-WindowsPackage -Online -PackageName $update.PackageName | 
        Where-Object { $_.Description -match $KBs }

    if ($match) {
        Write-Output "Removing $($Matches[0])"
        Remove-WindowsPackage -Online -PackageName $update.PackageName -NoRestart
    }
}
