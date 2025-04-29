# Check if acad.exe is running
$acadProcess = Get-Process -Name "acad" -ErrorAction SilentlyContinue
if ($acadProcess) {
    Write-Warning "Please close AutoCAD and/or Civil3D before proceeding."
    Write-Output "Waiting for AutoCAD/Civil3D to be closed...`n"
    
    do {
        # Check if acad.exe is still running
        $acadProcess = Get-Process -Name "acad" -ErrorAction SilentlyContinue
        if ($acadProcess) {
            Start-Sleep -Seconds 5
        }
    } while ($acadProcess)

}

# Display numbered menu for reset choice
Write-Output "Select the product(s) you would like to reset:"
Write-Output "1. AutoCAD"
Write-Output "2. Civil3D"
Write-Output "3. Both"
$resetChoice = Read-Host "Enter the number corresponding to your choice (1, 2, or 3)"

# Define the regex pattern for matching the directory paths
$regexPatternDirectories = ".*\\Autodesk\\(?:C3D|AutoCAD) \d{4}"

# Get all matching directories
$matchingDirectories = Get-ChildItem -Path $env:APPDATA, $env:LOCALAPPDATA -Recurse -Depth 1 -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match $regexPatternDirectories }

# Define the regex pattern for matching the registry key path
$regexPatternRegistry = "HKEY_CURRENT_USER\\Software\\Autodesk\\AutoCAD\\R\d+\.\d+\\ACAD-\d+:\d+"

# Get all matching registry keys
$matchingKeysRegistry = Get-ChildItem -Path "HKCU:\Software\Autodesk\AutoCAD\" -Recurse -Depth 1 -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $regexPatternRegistry }

# Select registry keys based on user choice
switch ($resetChoice) {
    1 {
        $keysToDelete = $matchingKeysRegistry | Where-Object { $_.GetValue("AllUsersFolder") -like "*AutoCAD*" }
    }
    2 {
        $keysToDelete = $matchingKeysRegistry | Where-Object { $_.GetValue("AllUsersFolder") -like "*C3D*" }
    }
    3 {
        $keysToDelete = $matchingKeysRegistry
    }
    Default {
        Write-Output "Invalid choice. No registry entries will be deleted."
        return
    }
}

# Delete each matching registry key
if ($keysToDelete) {
    foreach ($key in $keysToDelete) {
        Write-Output "Deleting registry key: $($key.Name)"
        Remove-Item -Path $key.PSPath -Force -Recurse
    }
}
else {
    Write-Warning "No registry settings detected"
}

# Delete directories based on user choice
switch ($resetChoice) {
    1 {
        $directoriesToDelete = $matchingDirectories | Where-Object { $_.FullName -match "Autodesk\\AutoCAD \d{4}" }
    }
    2 {
        $directoriesToDelete = $matchingDirectories | Where-Object { $_.FullName -match "Autodesk\\C3D \d{4}" }
    }
    3 {
        $directoriesToDelete = $matchingDirectories
    }
    Default {
        Write-Output "Invalid choice. No directories will be deleted."
        return
    }
}

# Delete each matching directory
if ($directoriesToDelete) {
    foreach ($directory in $directoriesToDelete) {
        Write-Output "Deleting directory: $($directory.FullName)"
        Remove-Item -Path $directory.FullName -Recurse -Force
    }
}
else {
    Write-Warning "No settings directories detected"
}

# Reset notification
if ($keysToDelete -or $directoriesToDelete) {
    switch ($resetChoice) {
        1 {
            Write-Host "`nSuccess!" -ForegroundColor Green
            Write-Output "AutoCAD settings have been reset. Please launch AutoCAD."
            Write-Output "You may close this window"
            return
        }
        2 {
            Write-Host "`nSuccess!" -ForegroundColor Green
            Write-Output "Civil3D settings have been reset. Please launch Civil3D."
            Write-Output "You may close this window"
            return
        }
        3 {
            Write-Host "`nSuccess!" -ForegroundColor Green
            Write-Output "AutoCAD and Civil3D settings have been reset. Please launch either application."
            Write-Output "You may close this window"
            return
        }
        Default {
            Write-Output "Invalid choice"
            return
        }
    }
}