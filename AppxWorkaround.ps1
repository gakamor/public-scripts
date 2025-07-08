<#
Many Appx PowerShell module cmdlets are currently broken when running 
them via Enter-PSSession or Invoke-Command on 24H2 or Server 2025 targets. 
Until Microsoft provides a fix, you may see the following error:

The type initializer for '<Module>' threw an exception.
    + CategoryInfo          : NotSpecified: (:) [], TypeInitializationException
    + FullyQualifiedErrorId : System.TypeInitializationException

This script runs the Appx command as a job so that it runs locally and
bypasses the error.
#>

$job = Start-Job -ScriptBlock {
    Get-AppxPackage -AllUsers
}

do {
    Start-Sleep -Seconds 1
}
until ($job.State -eq "Completed")

$output = Receive-Job -Id $job.Id
foreach ($app in $output) {
    [PSCustomObject]@{
        Name    = $app.Name
        Version = $app.Version
    }
}

Remove-Job -Id $job.Id
