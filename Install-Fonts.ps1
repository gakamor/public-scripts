# Get font files in the same directory as the script
$source = $PSScriptRoot
$fontFolder = 'C:\Windows\Fonts'
$fonts = Get-ChildItem -Path $source -Include '*.ttf', '*.otf' -Recurse

# Process each font contained in the source directory
foreach ($font in $fonts) {

    $targetFontPath = Join-Path $fontFolder $font.Name

    # If the font does not exist in the target folder, copy the font
    if (!(Test-Path $targetFontPath)) {
 
        $sourceFont = Join-Path $source $font.Name
        Copy-Item $sourceFont -Destination $targetFontPath -Force
   
        # Change the registry based on the font type
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        switch ($font.extension) {
            '.otf' { 
                New-ItemProperty -Path "$regPath" -Name "$($font.Name -replace ".{4}$") (OpenType)" -Type String -Value $font.name -Force
            }
            '.ttf' {
                New-ItemProperty -Path "$regPath" -Name "$($font.Name -replace ".{4}$") (TrueType)" -Type String -Value $font.name -Force
            }
        }
    }
}
