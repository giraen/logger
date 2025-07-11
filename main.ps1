function Search-File{
    param(
        [string]$FilePath
    )

    if (Test-Path $FilePath) {
        $true
    } else {
        $false
    }
}

function Write-Logs {
    param(
        [boolean]$FileExistence,
        [string]$FilePath,
        [string]$Name,
        [string]$Action,
        [string]$ActionLocation
    )

    $logdate = Get-Date -Format "yyyy/MM/dd HH:mm"
    if ($FileExistence) {
        Add-Content -Path $FilePath -Value "$logdate, $Name, $Action, $ActionLocation"
    } Else {
        New-item -Path "$FilePath" -ItemType File

        Add-content -Path "$FilePath" -Value "Date, Name, Action, location"
        Add-Content -Path $FilePath -Value "$logdate, $Name, $Action, $ActionLocation"
    }
}

function Show-InputBox {
    Add-Type -AssemblyName Microsoft.VisualBasic
    $global:name = [Microsoft.VisualBasic.Interaction]::InputBox("Please enter your name: ", "Name Logger")
}

$currDate = Get-Date -Format 'yyMMdd'
$fileName = "$currDate-Logs.csv"
$logFileNamePath = ".\Logs\$fileName"

$isScenario1 = $false
$isScenario2 = $false
$name = "ken harvey p. Girasol"
$flashDriveName = "E:\"
$actionLocation =  "D:\Programming\02_Prototype\logger\PastingDirectory"

#S1
#S2

$logFileExists = Search-File -FilePath $logFileNamePath
If ($isScenario1 -and $logFileExists) {
    $actionPerformed = "'$flashDriveName' mounted"

    Write-Logs -FileExistence $logFileExists -FilePath "$logFileNamePath" -Name "$name" -Action "$actionPerformed"
}

If ($isScenario2 -and $logFileExists) {
    Write-Logs -FileExistence $logFileExists -FilePath "$logFileNamePath" -Name "$name" -Action "$actionPerformed" -actionLocation "$actionLocation"
}