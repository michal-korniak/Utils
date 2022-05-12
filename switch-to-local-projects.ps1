function LoadConfigFile() {
    $local:config = Get-Content -Path "config.json" | ConvertFrom-Json
    return $config
}

function LogMessage($message) {
    $currentTime = Get-Date -format "dd-MMM-yyyy HH:mm:ss"
    Write-Output ('[' + $currentTime + '] ' + $message)    
}


function GetProjectName($projectPath) {
    $local:assemblyNameMatches = (Select-String -Path $projectPath '<AssemblyName>(.*?)<\/AssemblyName>').Matches
    if ($null -eq $assemblyNameMatches) {
        return [System.IO.Path]::GetFileNameWithoutExtension($projectPath)
    }
    return $assemblyNameMatches.Groups[1].Value
}

function CreateLibraryProjectPathByNameDictionary() {
    $local:libraryProjects = (Get-ChildItem $config.LibraryDirectoryPath -Recurse *.csproj)
    $local:resultDictionary = @{}
    foreach ($libraryProject in $libraryProjects) {
        $local:libraryProjectName = GetProjectName($libraryProject.FullName)
        if (!$resultDictionary.ContainsKey($libraryProjectName)) {
            $resultDictionary.Add($libraryProjectName, $libraryProject.FullName)
        }
    }

    return $resultDictionary;
}

function CreateFileBackup([string]$filePath) {
    Copy-Item -Path $filePath -Destination ($filePath + $config.BackupSufix)
}

function GetNugetReferencesNames($projectPath) {
    $local:matches = (Select-String -Path $projectPath 'PackageReference Include="(.*?)"' -AllMatches).Matches;
    $local:packages = New-Object Collections.Generic.List[string]
    foreach ($match in $matches) {
        $packages.Add($match.Groups[1]);
    }
    return $packages;
}

function GetDependentProjectsPaths($projectPath) {
    $local:matches = (Select-String -Path $projectPath 'ProjectReference Include="(.*?)"' -AllMatches).Matches;
    $local:dependentProjectPaths = New-Object Collections.Generic.List[string]

    $local:projectDirectoryPath = Split-Path -Path $projectPath

    foreach ($match in $matches) {
        $local:localProjectReferenceRelativePath = $match.Groups[1];
        $local:localProjectReferenceAbsolutePath = [System.IO.Path]::GetFullPath((Join-Path -Path $projectDirectoryPath -ChildPath $localProjectReferenceRelativePath))
        $dependentProjectPaths.Add($localProjectReferenceAbsolutePath);
    }

    return $dependentProjectPaths;
}

function AddProjectToSolution($slnPath, $projectPath) {
    dotnet sln $slnPath add $projectPath --solution-folder Libraries *>$null
    $local:dependentProjectsPaths = GetDependentProjectsPaths $projectPath
    foreach ($dependentProjectPath in $dependentProjectsPaths) {
        dotnet sln $slnPath add $dependentProjectPath --solution-folder Libraries *>$null
    }
}

function ReplaceNugetPackagesWithProjectsReferences($libraryProjectPathByNameDictionary, $slnPath) {
    $local:nugetPackagesNames = GetNugetReferencesNames $projectPath
    foreach ($nugetPackageName in $nugetPackagesNames) {
        if ($libraryProjectPathByNameDictionary.ContainsKey($nugetPackageName)) {
            $local:libraryProjectPath = $libraryProjectPathByNameDictionary[$nugetPackageName]

            AddProjectToSolution $slnPath $libraryProjectPath
            dotnet add $projectPath reference $libraryProjectPath *>$null
            dotnet remove $projectPath package $nugetPackageName *>$null
        }
    }
}

function DeleteBackupFileIfItIsSameAsOriginalFile($filePath) {
    $local:backupFilePath = $filePath + $config.BackupSufix
    if ((Get-FileHash $filePath).Hash -eq (Get-FileHash $backupFilePath).Hash) {
        Remove-Item $backupFilePath
    }
}

$local:config = LoadConfigFile
$local:slnPath = (Get-ChildItem $config.SolutionDirectoryPath -Recurse *.sln).FullName
$local:projectsPaths = (Get-ChildItem $config.SolutionDirectoryPath -Recurse *.csproj).FullName
$local:libraryProjectPathByNameDictionary = CreateLibraryProjectPathByNameDictionary

CreateFileBackup $slnPath
foreach ($projectPath in $projectsPaths) {
    LogMessage ('Processing ' + $projectPath)
    CreateFileBackup $projectPath
    ReplaceNugetPackagesWithProjectsReferences $libraryProjectPathByNameDictionary $slnPath
    DeleteBackupFileIfItIsSameAsOriginalFile $projectPath
}

DeleteBackupFileIfItIsSameAsOriginalFile $slnPath

LogMessage ('Cleaning solution')
dotnet clean $slnPath *>$null
LogMessage ('Building solution')
dotnet build $slnPath *>$null