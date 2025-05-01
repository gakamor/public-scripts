# Pause if MSIEXEC is running
$msiexecRunning = Get-Process -Name msiexec -ErrorAction SilentlyContinue
if ($msiexecRunning) {
    do {
        Start-Sleep -Seconds 60
    }
    until (-not (Get-Process -Name msiexec -ErrorAction SilentlyContinue))
}

# Find uninstall info
$ampUninstallReg = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall,HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall | 
    Get-ItemProperty | Where-Object {$_.UninstallString -like "*C:\Program Files*\Cisco\AMP*"}

# If AMP is installed, uninstall it
if ($ampUninstallReg) {
    $uninstallString = $ampUninstallReg.UninstallString
    $uninstallStringTrimmed = $uninstallString.Trim('"')
    Write-Output "Uninstalling AMP"
    Start-Process -FilePath $uninstallStringTrimmed -ArgumentList "/R /S /remove 1 /uninstallpassword fakePassword" -Wait -NoNewWindow

    # check if AMP Orbital is still installed and remove it
    $orbitalUninstallReg = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall,HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall | 
        Get-ItemProperty | Where-Object {$_.DisplayName -eq "Cisco AMP Orbital"}
    if ($orbitalUninstallReg) {
        Write-Output "Uninstalling Orbital"
        Uninstall-Package -Name "Cisco AMP Orbital"
    }
}
else {
    Write-Output "AMP not installed"
}
