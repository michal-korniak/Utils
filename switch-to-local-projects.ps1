$local:solutionDirectoryPath = "C:\Users\michal.korniak\source\repos\KRIP"
$local:libraryDirectoryPath = "C:\Users\michal.korniak\source\repos\Infrastructure"

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

function GetLocalProjectsReferencesPaths($projectPath) {
    $local:matches = (Select-String -Path $projectPath 'ProjectReference Include="(.*?)"' -AllMatches).Matches;
    $local:localProjectsPaths = New-Object Collections.Generic.List[string]

    $local:projectDirectoryPath = Split-Path -Path $projectPath

    foreach ($match in $matches) {
        $local:localProjectReferenceRelativePath = $match.Groups[1];
        $local:localProjectReferenceAbsolutePath = [System.IO.Path]::GetFullPath((Join-Path -Path $projectDirectoryPath -ChildPath $localProjectReferenceRelativePath))
        $localProjectsPaths.Add($localProjectReferenceAbsolutePath);
    }

    return $localProjectsPaths;
}

function AddLocalProjectToSolution($slnPath, $projectPath) {
    dotnet sln $slnPath add $localProject --solution-folder Libraries *>$null
    $local:localProjectReferencesPaths = GetLocalProjectsReferencesPaths $projectPath
    foreach ($localProjectReferencePath in $localProjectReferencesPaths) {
        dotnet sln $slnPath add $localProjectReferencePath --solution-folder Libraries *>$null
    }
}

function ReplaceNugetPackagesWithLocalProjects($libraryProjectPathByNameDictionary, $slnPath) {
    $local:nugetPackagesNames = GetNugetReferencesNames $projectPath
    foreach ($nugetPackageName in $nugetPackagesNames) {
        if ($libraryProjectPathByNameDictionary.ContainsKey($nugetPackageName)) {
            $local:localProject = $libraryProjectPathByNameDictionary[$nugetPackageName]

            AddLocalProjectToSolution $slnPath $projectPath
            dotnet add $projectPath reference $localProject *>$null
            dotnet remove $projectPath package $nugetPackageName *>$null
        }
    }
}

$local:slnPath = (Get-ChildItem $SolutionDirectoryPath -Recurse *.sln).FullName
$local:projectsPaths = (Get-ChildItem $SolutionDirectoryPath -Recurse *.csproj).FullName
$local:libraryProjectPathByNameDictionary = CreateLibraryProjectPathByNameDictionary

CreateFileBackup $slnPath
foreach ($projectPath in $projectsPaths) {
    Write-Output ('Processing ' + $projectPath)
    CreateFileBackup $projectPath
    ReplaceNugetPackagesWithLocalProjects $libraryProjectPathByNameDictionary $slnPath
}
dotnet clean $slnPath *>$null
dotnet build $slnPath *>$null