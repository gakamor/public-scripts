# Prerequisite - September 2025 Cumulative Update or later
# https://support.microsoft.com/en-us/topic/unexpected-uac-prompts-when-running-msi-repair-operations-after-installing-the-august-2025-windows-security-update-5806f583-e073-4675-9464-fe01974df273

# Filter for products to include
$filter = @(
    
    "AutoCAD", #simple string match
    "^Autodesk Civil 3D \d{4}(?!.*Private Pack).*" #or match with regex

)

# Get a list of installed MSI products
$Installer = New-Object -ComObject WindowsInstaller.Installer
$InstallerProducts = $Installer.ProductsEx("", "", 7)
$InstalledProducts = foreach ($Product in $InstallerProducts){
    try {
        [PSCustomObject]@{
            ProductCode   = $Product.ProductCode()
            LocalPackage  = $Product.InstallProperty("LocalPackage")
            VersionString = $Product.InstallProperty("VersionString")
            ProductName   = $Product.InstallProperty("ProductName")
        }
    }
    catch {
        # Suppress errors for products missing certain properties
    }
}

# Match products by filter
$MatchingProducts = $InstalledProducts | Where-Object {
    foreach ($f in $filter) {
        if ($_.ProductName -match $f) { return $true }
    }
    return $false
}


# Modify the registry
$RegPath  = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer"
New-ItemProperty -Path $RegPath -Name "SecureRepairPolicy" -Value 2 -PropertyType DWord -Force | Out-Null

if (-not (Test-Path $RegPath\SecureRepairWhitelist)) {
    New-Item -Path $RegPath\SecureRepairWhitelist -Force | Out-Null
}

foreach ($m in $MatchingProducts) {
    $code = $m.ProductCode
    Write-Output "Adding $($m.ProductName) to the Secure Repair Whitelist"
    New-ItemProperty -Path $RegPath\SecureRepairWhitelist -Name $code -PropertyType String -Force | Out-Null
}
