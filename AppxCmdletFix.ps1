<#
Many Appx PowerShell module cmdlets are currently broken when running 
them via Enter-PSSession or Invoke-Command on 24H2 or Server 2025 targets. 
Until Microsoft provides a fix, you may see the following error:

The type initializer for '<Module>' threw an exception.
    + CategoryInfo          : NotSpecified: (:) [], TypeInitializationException
    + FullyQualifiedErrorId : System.TypeInitializationException

This script adds new DLLs to the Global Assembly Cache which are required for
these Appx cmdlets to function over PSRemoting.
#>

Add-Type -AssemblyName "System.EnterpriseServices"
$publish = [System.EnterpriseServices.Internal.Publish]::new()

$dlls = @(
    'System.Memory.dll',
    'System.Numerics.Vectors.dll',
    'System.Runtime.CompilerServices.Unsafe.dll',
    'System.Security.Principal.Windows.dll'
)

foreach ($dll in $dlls) {
    $dllPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\$dll"
    $publish.GacInstall($dllPath)
}    

# Create a file so we can easily track that this computer was fixed (in case we need to revert)
New-Item -Path "$env:SystemRoot\System32\WindowsPowerShell\v1.0\" -Name DllFix.txt -ItemType File -Value "$dlls added to the Global Assembly Cache"
Restart-Computer


##### Use the code below to revert the changes if necessary #####

<#

if (Test-Path "$env:SystemRoot\System32\WindowsPowerShell\v1.0\DllFix.txt") {

    Add-Type -AssemblyName "System.EnterpriseServices"
    $publish = [System.EnterpriseServices.Internal.Publish]::new()

    $dlls = @(
        'System.Memory.dll',
        'System.Numerics.Vectors.dll',
        'System.Runtime.CompilerServices.Unsafe.dll',
        'System.Security.Principal.Windows.dll'
    )

    foreach ($dll in $dlls) {
        $dllPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\$dll"
        $publish.GacRemove($dllPath)
    } 

    Remove-Item -Path "$env:SystemRoot\System32\WindowsPowerShell\v1.0\DllFix.txt" -Force
    Restart-Computer
}

#>