$local:solutionDirectoryPath = "C:\Users\michal.korniak\source\repos\KRIP"
$local:libraryDirectoryPath = "C:\Users\michal.korniak\source\repos\Infrastructure"

function LogMessage($message) {
    $currentTime = Get-Date -format "dd-MMM-yyyy HH:mm:ss"
    Write-Output ('[' + $currentTime + '] ' + $message)    
}

function CreateLibraryProjectPathByNameDictionary() {
    $local:libraryProjects = (Get-ChildItem $libraryDirectoryPath -Recurse *.csproj)
    $local:resultDictionary = @{}
    foreach ($libraryProject in $libraryProjects) {
        if (!$resultDictionary.ContainsKey($libraryProject.BaseName)) {
            $resultDictionary.Add($libraryProject.BaseName, $libraryProject.FullName)
        }
    }

    return $resultDictionary;
}

function CreateFileBackup([string]$filePath) {
    Copy-Item -Path $filePath -Destination ($filePath + '.backup')
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

$local:slnPath = (Get-ChildItem $SolutionDirectoryPath -Recurse *.sln).FullName
$local:projectsPaths = (Get-ChildItem $SolutionDirectoryPath -Recurse *.csproj).FullName
$local:libraryProjectPathByNameDictionary = CreateLibraryProjectPathByNameDictionary

CreateFileBackup $slnPath
foreach ($projectPath in $projectsPaths) {
    LogMessage ('Processing ' + $projectPath)
    CreateFileBackup $projectPath
    ReplaceNugetPackagesWithProjectsReferences $libraryProjectPathByNameDictionary $slnPath
}
LogMessage ('Cleaning solution')
dotnet clean $slnPath *>$null
LogMessage ('Building solution')
dotnet build $slnPath *>$null