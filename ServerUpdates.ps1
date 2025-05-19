<#
.SYNOPSIS
Create PSWindowsUpdate scheduled tasks on desired Windows servers. 

This script determines when Patch Tuesday occurs in the current month. If the current month's Patch Tuesday plus the number of deferral days
has past, the script will go to the next month's Patch Tuesday. Computers will install updates on Patch Tuesday plus the number of deferral days.
Computers are assigned groups and each group starts installing at a certain hour.

The script will then enumerate computer objects in the specified OU - ignoring disabled computers,
non-Windows computers, and computers that have not contacted AD in a specified amount of days.

For computers to receive updates from this script, their Active Directory object's "Comment" field must be populated with "UpdateGroup1", "UpdateGroup2", etc.
Computers that have a blank "Comment" field will be skipped as will those explicitly excluded with the "NoPSWUpdates" comment.

A log file of this script's output will be emailed to the specified email address. Each computer that runs a PSWindowsUpdate scheduled task
will also have a log file located at "C:\TEMP\PSWindowsUpdate.log" that contains the results of the of the most recent PSWindowsUpdate job.

A scheduled task will also be created on the script host that sends a reminder email the day before patching occurs.

#>

#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory

# Patch Tuesday function
function Get-PatchTue {
    <#
    .SYNOPSIS
    Get the Patch Tuesday of a month
    .PARAMETER month
    The month to check
    .PARAMETER year
    The year to check
    .EXAMPLE
    Get-PatchTue -month 6 -year 2015
    .EXAMPLE
    Get-PatchTue June 2015
    #>
    param(
        [string]$month,
        [string]$year
    )
    $firstdayofmonth = [datetime]([string]$month + "/1/" + [string]$year)
    (0..30 | ForEach-Object {
        $firstdayofmonth.AddDays($_)
    } |
    Where-Object {
        $_.DayOfWeek -eq [System.DayOfWeek]::Tuesday
    })[1]
}

Import-Module ActiveDirectory

# Define variables
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmm"
$logPath = "\\myfileserver\logs\pswulogs\Create-PSWUpdateJobs-$($timestamp).log"
$serverOU = "OU=Servers,OU=Computers,DC=myorg,DC=com"
$deferralDays = 7 #Defer updates 1 to 14 days from Patch Tuesday
$InactiveThreshold = 365 #Ignore computer accounts that have been inactive longer than this (in days)

Start-Transcript -Path $logPath

# Get the next Patch Tuesday using today's date
$today = Get-Date
$currentMonth = $today.Month
$currentYear = $today.Year
$currentPatchTuesday = Get-PatchTue -month $currentMonth -year $currentYear

# Check if the current month's Patch Tuesday + deferral has already passed
if ($currentPatchTuesday.AddDays($deferralDays) -lt $today) {
    
    # Get the next month's Patch Tuesday
    $nextMonth = $currentMonth + 1
    $nextYear = $currentYear
    
    # Adjust for Dec to Jan
    if ($nextMonth -gt 12) {
        $nextMonth = 1
        $nextYear++
    }

    $nextPatchTuesday = Get-PatchTue -month $nextMonth -year $nextYear
} else {
    $nextPatchTuesday = $currentPatchTuesday
}

# Assign monthly group patch installation times
$nextTargetDate1 = $nextPatchTuesday.AddDays($deferralDays).Date.AddHours(1) #1AM
$nextTargetDate2 = $nextPatchTuesday.AddDays($deferralDays).Date.AddHours(3) #3AM

# Display the result
Write-Output "--------------------------------------------"
Write-Output "Today's date: $today"
Write-Output "Next Patch Tuesday: $nextPatchTuesday"
Write-Output "Defer Updates: $deferralDays day(s)"
Write-Output "Group 1 Date: $nextTargetDate1"
Write-Output "Group 2 Date: $nextTargetDate2"
Write-Output "--------------------------------------------"

# Get all enabled Windows computers recursively from the specified OU that are actively checking in with AD
$time = (Get-Date).Adddays(-($InactiveThreshold))
$computers = Get-ADComputer -Filter { Enabled -eq $true -and OperatingSystem -like '*Windows*' -and PasswordLastSet -ge $time } -Properties Comment -SearchBase $serverOU -SearchScope Subtree -Server myorg.com

# Common code for setting up PSWindowsUpdate job
$ScriptBlock = {
    param($nextTargetDate)

    # Check if the directory exists
    if (!(Test-Path -Path C:\TEMP -PathType Container)) {
        New-Item -Path C:\TEMP -ItemType Directory | Out-Null
    }
    
    # Install Nuget if needed
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    if (!(Get-PackageProvider -Name "Nuget" -ListAvailable -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name "Nuget" -Force -Confirm:$False
    }

    # Install PSWindowsUpdate PowerShell module if needed
    if (!(Get-Module -Name PSWindowsUpdate -ListAvailable -ErrorAction SilentlyContinue)) {
        Install-Module -Name PSWindowsUpdate -Scope AllUsers -Force
    }

    # Create PSWindowsUpdate scheduled task
    Invoke-WuJob -Script {ipmo PSWindowsUpdate; Get-WindowsUpdate -Install -WindowsUpdate -UpdateType Software -AcceptAll -AutoReboot -RecurseCycle 2 -Verbose | Out-File "C:\TEMP\PSWindowsUpdate.log"} -TriggerDate $nextTargetDate -Confirm:$false -ErrorAction SilentlyContinue
    
    # Confirm PSWindowsUpdate scheduled task exists
    $confirmJob = Get-WUJob
    foreach ($job in $confirmJob){
        if ($job.Name -eq "PSWindowsUpdate") {
            Write-Host "Job Confirmed" -ForegroundColor Green
        }
        if ($job.Name -eq $null) {
            Write-Host "ERROR APPLYING JOB" -ForegroundColor Red
        }
    }
}

# Loop through each computer and apply the update job
foreach ($computer in $computers) {
    
    Write-Output "$($computer.Name)"
    
    if ($computer.Comment -eq "UpdateGroup1") {
        Write-Output "Applying Group1 WU Job..."
        Invoke-Command -ComputerName $computer.Name -ScriptBlock $ScriptBlock -ArgumentList $nextTargetDate1
    }
    elseif ($computer.Comment -eq "UpdateGroup2") {
        Write-Output "Applying Group2 WU Job..." 
        Invoke-Command -ComputerName $computer.Name -ScriptBlock $ScriptBlock -ArgumentList $nextTargetDate2
    }            
    elseif ($null -eq $computer.Comment) {
        Write-Output "No update group assigned. Skipping..."
    }
    elseif ($computer.Comment -eq "NoPSWUpdates") {
        Write-Output "Exclusion group. Skipping..."
    }     
    else {
        Write-Output "Undefined update group assigned. Skipping..."
    }
    Write-Output "--------------------------------------------"
}

Stop-Transcript

#### Create Email Reminder task on the script host ####
$taskName = "Server Update Email Reminder"
$smtpServer = "smtp.myorg.com"
$from = "serverupdates@myorg.com"
$to = "username@myorg.com"
$subject = "Reminder: Windows Server Updates Tonight"

if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask $taskName -Confirm:$false
}

# Schedule time for 8am the day before updates run
$triggerTime = $nextPatchTuesday.AddDays($deferralDays - 1).Date.AddHours(8) 
$trigger = New-ScheduledTaskTrigger -Once -At $triggerTime

# Get list of servers that will be updated
$serverNames = ($computers | Where-Object { $_.Comment -match 'UpdateGroup\d+' }).Name
$serverNames = $serverNames | Sort-Object

# Create the email body
$body = "Automated Windows Server updates will be installed tonight. The following servers will be updated:`n"
foreach ($server in $serverNames) {
    $body += "$server`n"
}

# Create scheduled task
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-Command `"Send-MailMessage -SmtpServer '$smtpServer' -From '$from' -To '$to' -Subject '$subject' -Body '$body'`""
$principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal
Register-ScheduledTask -TaskName $taskName -InputObject $task
