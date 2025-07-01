<# 

This scripts displays a list of installed system and user applications with
Out-GridView along with their uninstall commands (silent commands when available).

Some apps may need additional switches or response files for a silent uninstall.

#>

#Requires -RunAsAdministrator

$allApps = @()

### User Apps ###

# Get all user hives in HKEY_USERS
$userHives = Get-ChildItem -Path Registry::HKEY_USERS\ | Where-Object { $_.Name -match '^HKEY_USERS\\S-1-5-21-[\d\-]+$' }

# Get all user apps
$userApps = @()
foreach ($user in $userHives) {
    $sid = $user.PSChildName
    $userPath1 = "Registry::HKEY_USERS\$sid\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $userPath2 = "Registry::HKEY_USERS\$sid\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    $userApps += Get-ChildItem -Path $userPath1, $userPath2 -ErrorAction SilentlyContinue
}

# Process user apps
$userApps | Get-ItemProperty | ForEach-Object {
    if ($_.UninstallString -or $_.QuietUninstallString) {
        # Prioritize silent command if available
        $uninstallCmd = if ($_.QuietUninstallString) {
            $_.QuietUninstallString
        }
        else {
            $_.UninstallString -replace 'MsiExec.exe /I', 'MsiExec.exe /X'
        }

        # Append silent switch if msiexec.exe
        if ($uninstallCmd -match '^\s*msiexec\.exe') {
            $uninstallCmd += ' /qn /norestart'
        }

        $allApps += [PSCustomObject]@{
            'Application'       = $_.DisplayName
            'Uninstall Command' = $uninstallCmd
            'Type'              = "User App"
        }
    }
}

### System Apps ###

# Get all system apps
$sysPath1 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
$sysPath2 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
$sysApps = Get-ChildItem -Path $sysPath1, $sysPath2

# Process system apps
$sysApps | Get-ItemProperty | ForEach-Object {
    if ($_.UninstallString -or $_.QuietUninstallString) {
        # Prioritize silent command if available
        $uninstallCmd = if ($_.QuietUninstallString) {
            $_.QuietUninstallString
        }
        else {
            $_.UninstallString -replace 'MsiExec.exe /I', 'MsiExec.exe /X'
        }

        # Append silent switch if msiexec.exe
        if ($uninstallCmd -match '^\s*msiexec\.exe') {
            $uninstallCmd += ' /qn /norestart'
        }

        $allApps += [PSCustomObject]@{
            'Application'       = $_.DisplayName
            'Uninstall Command' = $uninstallCmd
            'Type'              = "System App"
        }
    }
} 


# Sort and display all apps with their uninstall commands (silent when available)
$allApps | Sort-Object -Property Application | Out-GridView -Title "App Uninstall Commands"
