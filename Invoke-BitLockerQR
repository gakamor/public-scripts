<#
.DESCRIPTION
    This script creates BitLocker Recover Key QR codes for specified computers. This
    will allow the administrator to quickly use the key(s) on one or more computers
    using a barcode scanner. The QR codes are automatically displayed by the 
    OS default application for PNG files. From there, they can be printed or
    scanned from the display.

.PARAMETERS 
    -ComputerName
        Required. The computer name(s) that you want to generate QR codes for.
  
    -MaxCodesPerPage
        Specify the maximum number of QR codes per page. Defaults to 20 which 
        fits well on a sheet of 8.5x11 paper in portrait. May need to use
        "Shrink to Fit" printing options.

.EXAMPLE

    Get a QR code for a single computer:
    .\Invoke-BitLockerQR.ps1 -ComputerName pc01

    Get QR codes for multiple computers:
    .\Invoke-BitLockerQR.ps1 -ComputerName pc01,pc02,pc03,pc04

    Get QR codes for computers in a CSV file (no header):
    $list = Get-Content -Path .\mycomputerlist.csv
    .\Invoke-BitLockerQR.ps1 -ComputerName $list

#>

param (
    [Parameter(Mandatory = $true)]
    [array]$ComputerName,

    [Parameter(Mandatory = $false)]
    [int]$MaxCodesPerPage = 20
)

#Requires -Modules ActiveDirectory

function Combine-ImagesWithLabels {
    param (
        [Parameter(Mandatory)]
        [PSCustomObject[]]$ImageList,   # Each object must have Name, Path
        [string]$OutPath,
        [int]$Columns = 4,
        [int]$Padding = 20,
        [string]$FontName = 'Arial',
        [int]$FontSize = 12
    )

    Add-Type -AssemblyName System.Drawing

    # Load images from paths
    $images = @()
    foreach ($entry in $ImageList) {
        $img = [System.Drawing.Image]::FromFile($entry.Path)
        $images += [PSCustomObject]@{
            Name = $entry.Name
            Image = $img
        }
    }

    $qrWidth = $images[0].Image.Width
    $qrHeight = $images[0].Image.Height

    # Measure text height using dummy graphics context
    $dummyBmp = New-Object System.Drawing.Bitmap 1,1
    $dummyGraphics = [System.Drawing.Graphics]::FromImage($dummyBmp)
    $font = New-Object System.Drawing.Font $FontName, $FontSize
    $textHeight = $dummyGraphics.MeasureString("Sample", $font).Height
    $dummyGraphics.Dispose()
    $dummyBmp.Dispose()

    $cellHeight = $qrHeight + $textHeight + 5
    $cellWidth = $qrWidth

    $rows = [math]::Ceiling($images.Count / $Columns)
    $bitmapWidth = ($cellWidth + $Padding) * $Columns - $Padding
    $bitmapHeight = ($cellHeight + $Padding) * $rows - $Padding

    $bitmap = New-Object System.Drawing.Bitmap $bitmapWidth, $bitmapHeight
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::White)
    $brush = [System.Drawing.Brushes]::Black

    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = 'Center'

    for ($i = 0; $i -lt $images.Count; $i++) {
        $row = [math]::Floor($i / $Columns)
        $col = $i % $Columns
        $x = $col * ($cellWidth + $Padding)
        $y = $row * ($cellHeight + $Padding)

        $graphics.DrawImage($images[$i].Image, $x, $y, $qrWidth, $qrHeight)

        $labelY = $y + $qrHeight + 2
        $labelRect = New-Object System.Drawing.RectangleF($x, $labelY, $qrWidth, $textHeight)
        $graphics.DrawString($images[$i].Name, $font, $brush, $labelRect, $sf)

        $images[$i].Image.Dispose()
    }

    $bitmap.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
}

$domain = "mydomain.com"

# Ensure output directory is available
$qrDir = "C:\TEMP"
if (-not(Test-Path -Path $qrDir -PathType Container)) {
    New-Item -Path $qrDir -ItemType Directory | Out-Null
}

# Ensure QR module is installed
if (-not(Get-Module -Name QRCodeGenerator -ListAvailable -ErrorAction SilentlyContinue)) {
    Install-Module -Name QRCodeGenerator -Force
}

# Loop through computer names, get the latest Bitlocker key, and generate QR Codes.
$imageList = @()
foreach ($computer in $ComputerName) {
    $pngPath = "$($qrDir)\$($computer)-$(Get-Date -Format 'yyyyMMdd-HHmmss').png"
    
    $objComputer = $null
    try {
        $objComputer = Get-ADComputer $computer -Server $domain
    }
    catch {
        Write-Warning "$computer not found in AD"
        Continue
    }

    $objBitlocker = Get-ADObject -Server $domain -Filter {objectclass -eq 'msFVE-RecoveryInformation'} `
        -SearchBase $objComputer.DistinguishedName -Properties 'msFVE-RecoveryPassword', 'whenCreated' |
        Sort-Object whenCreated -Descending | Select-Object -First 1
    $bitlockerKey = $objBitlocker.'msFVE-RecoveryPassword'

    if (-not ($bitlockerKey)){
        Write-Warning "Key not found for $computer"
        Continue
    }

    New-QRCodeText -Text "$bitlockerKey" -OutPath "$pngPath" -Width 10

    $imageList += [PSCustomObject]@{
        Name = $computer
        Path = $pngPath
    }
}

# Limit the amount of combined QR codes per page
$pageSize = $MaxCodesPerPage
$totalItems = $imageList.Count
$pageCount = [math]::Ceiling($totalItems / $pageSize)

for ($page = 0; $page -lt $pageCount; $page++) {
    $startIndex = $page * $pageSize
    $endIndex = [math]::Min(($startIndex + $pageSize - 1), $totalItems - 1)
    $pageItems = $imageList[$startIndex..$endIndex]
    $outputFile = Join-Path $qrDir "CombinedQRs-Page$($page + 1)-$(Get-Date -Format 'yyyy-MM-dd-HHmm').png"
    $columns = [math]::Min(4, $pageItems.Count)  # Adjust columns dynamically
    Combine-ImagesWithLabels -ImageList $pageItems -OutPath $outputFile -Columns $columns
    Start-Process -FilePath "$outputFile"
}

# Cleanup temp QR images
$imageList | ForEach-Object { Remove-Item -Path $_.Path -Force }
