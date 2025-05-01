#Export print drivers for installed printers

$driverDestination = "C:\temp\printdrivers"

$printers = Get-Printer -Name *
foreach ($printer in $printers) {
    $driver= Get-PrinterDriver -Name $printer.DriverName

    if ($driver.PrinterEnvironment -eq "Windows x64") {
        $driverType = "x64"
    }
    else {
        $driverType = "x86"
    }

    $inf = $driver.InfPath
    if ($inf) {
         $folder = Split-Path -Path $inf -Parent
         Write-Output "Copying $($driver.Name) $driverType"
         robocopy "$folder" "$driverDestination\$driverType\$($driver.Name)" /E /NFL /NDL /NJH /NJS /NP
    }
}
