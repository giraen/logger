function Write-Logs {
    param(
        [string]$FilePath,
        [string]$Name,
        [string]$Model,
        [string]$Size,
        [string]$ActionLocation,
        [string]$UsbOperation
    )

    $timeStamp = (Get-Date).ToString("HH:mm")
    if ($UsbOperation) {
        $action = "$Model($Size) $UsbOperation"
    } else {
        $action = "this is meant for file operations!"
    }
    
    [PSCustomObject]@{
        Timestamp = $timeStamp
        Name      = $Name
        Action    = $action
        ActionLocation = $ActionLocation
    } | Export-Csv -Path "$FilePath" -NoTypeInformation -Append
}

function Show-InputBox {
    Add-Type -AssemblyName Microsoft.VisualBasic
    $global:name = [Microsoft.VisualBasic.Interaction]::InputBox("Please enter your name: ", "Name Logger")
}

function Get-FlashDrive {
    $flashDrives = @(Get-WmiObject Win32_DiskDrive `
        | Where-Object { $_.MediaType -like "*Removable*" } `
        | Select-Object Model, SerialNumber, Size)

    foreach ($flashDrive in $flashDrives) {
        $serial = $flashDrive.SerialNumber
        $model = $flashDrive.Model
        $size = $flashDrive.Size

        # Skip if already logged
        if ($global:loggedSerials.ContainsKey($serial)) {
            continue
        }

        # Add them to the hashtable if not yet added
        if (-not $global:flashDriveHash.ContainsKey($serial)) {
            # Create a value object containing model and size
            $driveInfo = [PSCustomObject]@{
                Model = $model
                Size  = $size
            }

            # Mark the newly added serial to be logged (true)
            $global:loggedSerials[$serial] = $true
            $global:flashDriveHash[$serial] = $driveInfo 

            Write-Logs -FilePath $global:logFileNamePath `
                       -Name $global:name `
                       -Model $model `
                       -Size $size `
                       -UsbOperation "Inserted" `
                       -ActionLocation ""
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
                       -ActionLocation ""
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
                   -ActionLocation ""

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