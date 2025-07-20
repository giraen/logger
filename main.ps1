Set-StrictMode -Version 2

$global:currDate = Get-Date -Format 'yyMMdd'
$global:fileName = "$global:currDate-Logs.csv"
$global:logFileNamePath = ".\Logs\$global:fileName"
$global:actionLocation = ".\PastingDirectory"
$global:header = "Timestamp", "Name", "Action", "ActionLocation"
$global:name = "Unknown"

$global:refTime = @{}
$global:timeCalled = @{}

$global:flashDriveHash = @{}
$global:loggedSerials = @{}

if (-not (Test-Path $global:logFileNamePath)) {
    $null | Select-Object $global:header | Export-Csv -Path $global:logFileNamePath -NoTypeInformation
}

function Write-Logs {
    param(
        [string]$FilePath,
        [string]$Name,
        [string]$Model,
        [string]$Size,
        [string]$ActionLocation,
        [string]$UsbOperation,
        [string]$FileOperation,
        [string]$UsbName
    )

    $timeStamp = (Get-Date).ToString("HH:mm")
    if ($UsbOperation) {
        $action = "$Model($Size) named $UsbName was $UsbOperation"
    } else {
        $action = "$FileOperation"
    }
    
    [PSCustomObject]@{
        Timestamp = $timeStamp
        Name      = $Name
        Action    = $action
        ActionLocation = $ActionLocation
    } | Export-Csv -Path "$FilePath" -NoTypeInformation -Append
}

function Show-InputBox {
    param(
        [datetime]$LastTimeCalled
    )
    $advTime = $($LastTimeCalled.AddSeconds(2))
    $delayTime = $($LastTimeCalled.AddSeconds(-2))
    $isWithinRange = $(($LastTimeCalled.Second -le $advTime.Second) -and ($LastTimeCalled.Second -gt $delayTime.Second))

    $secondsFiltered = ($LastTimeCalled).ToString("MM/dd/yyyy HH:mm")

    if ($isWithinRange) {
        if (-not ($global:refTime.ContainsKey($secondsFiltered))) {
            $global:refTime[($LastTimeCalled).ToString("MM/dd/yyyy HH:mm")] = $true

            Add-Type -AssemblyName Microsoft.VisualBasic
            $global:name = [Microsoft.VisualBasic.Interaction]::InputBox("Please enter your name: ", "Name Logger")
        }
    }
    $global:timeCalled = Get-Date
}

function Show-PopUpMsgBox {
    Add-Type -AssemblyName PresentationCore, PresentationFramework
    $btnType = [System.Windows.MessageBoxButton]::OK
    $msgBoxTitle = "Logger stopped"
    $msgBoxBody = "The logger has been stopped!"
    $msgIcon = [System.Windows.MessageBoxImage]::Information
    [System.Windows.MessageBox]::Show($msgBoxBody, $msgBoxTitle, $btnType, $msgIcon)
}

function Get-FlashDrive {
    $flashDrives = @(Get-CimInstance Win32_DiskDrive `
        | Where-Object { $_.MediaType -like "*Removable*" })

    foreach ($flashDrive in $flashDrives) {
        $serial = $flashDrive.SerialNumber
        $model = $flashDrive.Model
        $size = $flashDrive.Size

        # Skip if already logged
        if ($global:loggedSerials.ContainsKey($serial)) {
            continue
        }

        # Get the volume name
        $volumeName = ""
        $partitions = Get-CimAssociatedInstance -InputObject $flashDrive -ResultClassName Win32_DiskPartition
        foreach ($partition in $partitions) {
            $logicalDisks = Get-CimAssociatedInstance -InputObject $partition -ResultClassName Win32_LogicalDisk
            foreach ($logical in $logicalDisks) {
                if ($logical.VolumeName) {
                    $volumeName = $logical.VolumeName
                    break
                }
            }
            if ($volumeName) { break }
        }

        # Add them to the hashtable if not yet added
        if (-not $global:flashDriveHash.ContainsKey($serial)) {
            # Create a value object containing model and size
            $driveInfo = [PSCustomObject]@{
                Model = $model
                Size  = $size
                VolumeName = $volumeName
            }

            # Mark the newly added serial to be logged (true)
            $global:loggedSerials[$serial] = $true
            $global:flashDriveHash[$serial] = $driveInfo 

            Write-Logs -FilePath $global:logFileNamePath `
                       -Name $global:name `
                       -Model $model `
                       -Size $size `
                       -UsbOperation "Inserted" `
                       -ActionLocation "" `
                       -UsbName "$volumeName"
        }
    }
}

function Remove-FlashDrive {
    $serialNums = [System.Collections.Generic.List[string]]::new()
    $serialNumsToRemove = @()

    $flashDrives = @(Get-WmiObject Win32_DiskDrive `
        | Where-Object { $_.MediaType -like "*Removable*" } `
        | Select-Object Model, SerialNumber, Size)

    if ($flashDrives.Count -eq 0) {
        foreach ($serial in $global:flashDriveHash.Keys) {
            $driveInfo = $global:flashDriveHash[$serial]

            Write-Logs -FilePath $global:logFileNamePath `
                       -Name $global:name `
                       -Model $driveInfo.Model `
                       -Size $driveInfo.Size `
                       -UsbOperation "Removed" `
                       -ActionLocation "" `
                       -UsbName $driveInfo.VolumeName
        }

        # Clear everything
        $global:flashDriveHash.Clear()
        $global:loggedSerials.Clear()
        return
    }

    # Get the current connected flash drives
    foreach ($flashDrive in $flashDrives) {
        $serialNums.Add($flashDrive.SerialNumber)
    }

    # Check if the connected flash drives are in the hashtable
    # If not, then add them to an array of keys to be removed
    foreach ($prevSerialNum in $global:flashDriveHash.Keys) {
        if (-not $serialNums.Contains($prevSerialNum)) {
            $serialNumsToRemove.Add($prevSerialNum)
        }
    }

    # Iterate over the keys to be removed and remove them from the hashtable
    foreach ($serialNumToRemove in $serialNumsToRemove) {
        $driveInfo = $global:flashDriveHash[$serialNumToRemove]

        Write-Logs -FilePath $global:logFileNamePath `
                   -Name $global:name `
                   -Model $driveInfo.Model `
                   -Size $driveInfo.Size `
                   -UsbOperation "Removed" `
                   -ActionLocation "" `
                   -UsbName $driveInfo.VolumeName

        $global:flashDriveHash.Remove($serialNumToRemove)
        $global:loggedSerials.Remove($serialNumToRemove)
    }
}

$global:currDate = Get-Date -Format 'yyMMdd'
$global:fileName = "$global:currDate-Logs.csv"
$global:logFileNamePath = ".\Logs\$global:fileName"
$global:flashDriveHash = @{}
$global:loggedSerials = @{}

$global:name = "Unknown"
$global:actionLocation =  "D:\Programming\02_Prototype\logger\PastingDirectory"

Register-WmiEvent -Class Win32_DeviceChangeEvent -SourceIdentifier deviceChange -Action {
    $eventData = $Event.SourceEventArgs.NewEvent

    switch ($eventData.EventType) {
        2 { 
            # Flash drive inserted
            Get-FlashDrive
        }
        3 { 
            # Flash drive removal
            Remove-FlashDrive
        }
    }
}

Write-Host "USB drive detector running. Press Ctrl+C to exit."
try {
    while($true) {
        Start-Sleep -Seconds 5
    }
}
finally {
    Write-Host "`nStopping USB drive detector..."
    Unregister-Event -SourceIdentifier deviceChange
}