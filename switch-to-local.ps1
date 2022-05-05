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

function GetNugetReferencesNames($projectPath) {
    $local:matches = (Select-String -Path $projectPath 'PackageReference Include="(.*?)"' -AllMatches).Matches;
    $local:packages = New-Object Collections.Generic.List[string]
    foreach ($match in $matches) {
        $packages.Add($match.Groups[1]);
    }
    return $packages;
}

function ReplaceNugetPackageWithLocalProject($slnPath, $projectPath, $nugetPackageName, $localProject) {
    dotnet sln $slnPath add $localProject
    dotnet add $projectPath reference $localProject
    dotnet remove $projectPath package $nugetPackageName
}


$local:slnPath = (Get-ChildItem $SolutionDirectoryPath -Recurse *.sln).FullName
$local:projectsPaths = (Get-ChildItem $SolutionDirectoryPath -Recurse *.csproj).FullName
$local:libraryProjectPathByNameDictionary = CreateLibraryProjectPathByNameDictionary

foreach ($projectPath in $projectsPaths) {
    $nugetPackagesNames = GetNugetReferencesNames $projectPath
    foreach ($nugetPackageName in $nugetPackagesNames) {
        if ($libraryProjectPathByNameDictionary.ContainsKey($nugetPackageName)) {
            $local:localProjectPath= $libraryProjectPathByNameDictionary[$nugetPackageName]
            ReplaceNugetPackageWithLocalProject $slnPath $projectPath $nugetPackageName $localProjectPath
        }
    }
}


Write-Output "end"


