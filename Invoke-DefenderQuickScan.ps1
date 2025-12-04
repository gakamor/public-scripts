
$scan = Start-MpScan -ScanType QuickScan -AsJob -ErrorAction Stop
Write-Output "Quick scan started..."

do {
    Start-Sleep -Seconds 10
    if ($scan.State -eq "Failed") {
        throw "An error occurred. Another scan may be in progress. Wait a while and try again."    
    }
}
until ($scan.State -ne "Running")

Write-Output "Scan completed"
Write-Output "Checking for detections..."
Start-Sleep -Seconds 60 # wait for cleaning actions to process

$status = Get-MpComputerStatus
$detections = Get-MpThreatDetection |
    Where-Object { $_.InitialDetectionTime -gt $status.QuickScanStartTime } |
    ForEach-Object {

        [PSCustomObject]@{
            ActionSuccess                   = $_.ActionSuccess
            AdditionalActionsBitMask        = $_.AdditionalActionsBitMask
            AMProductVersion                = $_.AMProductVersion
            CleaningActionID                = switch ($_.CleaningActionID) {
                                                    0  {'Unknown'}
                                                    1  {'Clean'}
                                                    2  {'Quarantine'}
                                                    3  {'Remove'}
                                                    4  {'Allow'}
                                                    5  {'UserDefined'}
                                                    6  {'NoAction'}
                                                    7  {'Block'}
                                                    8  {'ManualStepsRequired'}
                                                    Default {$_.CleaningActionID}
                                           }
            CurrentThreatExecutionStatusID = $_.CurrentThreatExecutionStatusID
            DetectionID                    = $_.DetectionID
            DetectionSourceTypeID          = $_.DetectionSourceTypeID
            DomainUser                     = $_.DomainUser
            InitialDetectionTime           = $_.InitialDetectionTime
            LastThreatStatusChangeTime     = $_.LastThreatStatusChangeTime
            ProcessName                    = $_.ProcessName
            RemediationTime                = $_.RemediationTime
            Resources                      = $_.Resources
            ThreatID                       = $_.ThreatID
            ThreatStatusErrorCode          = $_.ThreatStatusErrorCode
            ThreatStatusID                 = switch ($_.ThreatStatusID) {
                                                        0   {'Unknown'}
                                                        1   {'Detected'}
                                                        2   {'Cleaned'}
                                                        3   {'Quarantined'}
                                                        4   {'Removed'}
                                                        5   {'Allowed'}
                                                        6   {'Blocked'}
                                                        102 {'QuarantineFailed'}
                                                        103 {'RemoveFailed'}
                                                        104 {'AllowFailed'}
                                                        105 {'Abondoned'}
                                                        107 {'BlockedFailed'}
                                                        Default {$_.ThreatStatusID}
                                               }
        }

    }
 
if ($detections) {
    Write-Output "Malware detected since $($status.QuickScanStartTime):"
    $detections
}
else {
    Write-Output "No threats detected since $($status.QuickScanStartTime)"
}
