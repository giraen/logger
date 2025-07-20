# Hashtable for multiple flash drive
# Name  |   Value
# pnpId     model
$flashDriveHash = @{}
$loggedSerials = @{}

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

        # --- Get associated LogicalDisk (for VolumeName) ---
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
            }

            # Mark the newly added serial to be logged (true)
            $global:loggedSerials[$serial] = $true
            $global:flashDriveHash[$serial] = $driveInfo

            [PSCustomObject]@{
                Timestamp = (Get-Date).ToString("HH:mm")
                Event     = "Inserted"
                Serial    = $serial
                Model     = $model
                Size      = "{0:N2} GB" -f ($size / 1GB)
                FlashDriveName = $volumeName
            } | Export-Csv -Path ".\usb_log.csv" -NoTypeInformation -Append
        }
    }
}

function Remove-FlashDrive {
    $serialNums = [System.Collections.Generic.List[string]]::new()
    $serialNumsToRemove = @()

    $flashDrives = @(Get-CimInstance Win32_DiskDrive `
        | Where-Object { $_.MediaType -like "*Removable*" } `
        | Select-Object Model, SerialNumber, Size)

    if ($flashDrives.Count -eq 0) {
        foreach ($serial in $global:flashDriveHash.Keys) {
            $driveInfo = $global:flashDriveHash[$serial]

            [PSCustomObject]@{
                Timestamp = (Get-Date).ToString("HH:mm")
                Event     = "Removed"
                Serial    = $serial
                Model     = $driveInfo.Model
                Size      = $driveInfo.Size
            } | Export-Csv -Path ".\usb_log.csv" -NoTypeInformation -Append
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

        [PSCustomObject]@{
            Timestamp = (Get-Date).ToString("HH:mm")
            Event     = "Removed"
            Serial    = $serialNumToRemove
            Model     = $driveInfo.Model
            Size      = $driveInfo.Size
        } | Export-Csv -Path ".\usb_log.csv" -NoTypeInformation -Append

        $global:flashDriveHash.Remove($serialNumToRemove)
        $global:loggedSerials.Remove($serialNumToRemove)
    }
}

$action = {
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

Register-WmiEvent -Class Win32_DeviceChangeEvent -SourceIdentifier deviceChange -Action $action

Write-Host "`nWaiting for a new device... Press Ctrl+C to stop."
try {
    while($true) {
        Start-Sleep -Seconds 5
    }
}
finally {
    Write-Host "`nStopping flash drive detector..."
    Unregister-Event -SourceIdentifier deviceChange
}


