function LoadConfigFile() {
    $local:config = Get-Content -Path "config.json" | ConvertFrom-Json
    return $config
}

function LogMessage($message) {
    $currentTime = Get-Date -format "dd-MMM-yyyy HH:mm:ss"
    Write-Output ('[' + $currentTime + '] ' + $message)    
}

function RestoreFileBackup([string]$filePath) {
    $local:backupFilePath = ($filePath + $config.BackupSufix)
    if (Test-Path $backupFilePath -PathType Leaf) {
        Copy-Item -Path $backupFilePath -Destination $filePath
        Remove-Item $backupFilePath
        LogMessage ($filePath + ' backup file restored')
    }
}

$local:config = LoadConfigFile
$local:slnPath = (Get-ChildItem $config.SolutionDirectoryPath -Recurse *.sln).FullName
RestoreFileBackup $slnPath

$local:projectsPaths = (Get-ChildItem $config.SolutionDirectoryPath -Recurse *.csproj).FullName
foreach ($projectPath in $projectsPaths) {
    RestoreFileBackup $projectPath
}

