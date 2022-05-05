$local:solutionDirectoryPath = "C:\Users\michal.korniak\source\repos\KRIP"

function LogMessage($message) {
    $currentTime = Get-Date -format "dd-MMM-yyyy HH:mm:ss"
    Write-Output ('[' + $currentTime + '] ' + $message)    
}

function RestoreFileBackup([string]$filePath) {
    $local:backupFilePath = ($filePath + '.backup')
    Copy-Item -Path $backupFilePath -Destination $filePath
    Remove-Item $backupFilePath
    LogMessage ($filePath + ' backup file restored')
}



$local:slnPath = (Get-ChildItem $SolutionDirectoryPath -Recurse *.sln).FullName
RestoreFileBackup $slnPath

$local:projectsPaths = (Get-ChildItem $SolutionDirectoryPath -Recurse *.csproj).FullName
foreach ($projectPath in $projectsPaths) {
    RestoreFileBackup $projectPath
}

