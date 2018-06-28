#Requires -Version 3.0

Param(
	[switch]$LocalOnly
)

$Common = "Common"
$TempName = "CommonTemp"
$RootDir =  Resolve-Path "$PSScriptRoot\.."
$TempDir = "$RootDir\$TempName"
$LocalDir = Resolve-Path "$RootDir\..\common"
$CommonRepo = "https://github.com/andburn/hdt-plugin-common.git"
$CopyIgnore = @(".git", ".vs", "packages", "TestResults")

Function RemoveDirectoryIfExists {
Param( [string]$Directory )
    if (Test-Path $Directory) {
        Remove-Item $Directory -Force -Recurse
    }
}

Function DirectoryExistsAndIsNonEmpty {
Param( [string]$Directory )
    Test-Path "$Directory\*"
}

Function ErrorAndExit {
Param( [string]$Message )
    Write-Host -ForegroundColor Red "Error: $Message"
    Exit
}

Function GetSolutionName {
    (Get-ChildItem -Path $RootDir | Where { $_.Name -match ".+?\.sln" }).BaseName
}

Function GetProjectGUIDFromSolution {
Param( [string]$Name )
    $Solution = "$RootDir\$Name.sln"
    $Project = "$Name.$Common"
    if (-not (Test-Path $Solution)) {
        ErrorAndExit "$Solution not found"
    }
    $regex = " = `"$Project`", `"$Project\\$Project.csproj`", `"\{([A-Z0-9\-]+)\}`""
    Get-Content $Solution | ForEach-Object {
        if($_ -match $regex){
            return $Matches[1]
        }
    }
}

Function ReplaceCommonProjectItem {
Param(
    [string]$Name,
    [string]$Value
)
    $Project = "$TempDir\$Common\$Common.csproj"
    if (-not (Test-Path $Project)) {
        ErrorAndExit "$Project not found"
    }
    $file = Get-Content $Project
    $file -replace "<$Name>.+?</$Name>", "<$Name>$Value</$Name>" | Set-Content $Project
}

Function ReplacePackAddresses {
Param(
    [string]$Name
)
    # not the most robust way, but faster than searching all files
    $files = "Controls\MoonTextButton.xaml", "Controls\Styles.xaml", "Utils\PluginMenu.cs"
    foreach ($f in $files) {
        $file = "$TempDir\$Common\$f"
        $content = Get-Content $file
        $content -replace "pack://application:,,,/$Common;", "pack://application:,,,/$Name.$Common;" | Set-Content $file
    }
}

Function EditAndReplaceCommonProject {
	if (-not (DirectoryExistsAndIsNonEmpty $TempDir)) {
        ErrorAndExit "failed to copy repository"
    }
    Write-Host "Renaming project files"
    # get the name of the plugin/solution
    $name = GetSolutionName
    # get the GUID assigned to the common project of this plugin
    $guid = GetProjectGUIDFromSolution $name
    # replace the original GUID with the this plugins one
    ReplaceCommonProjectItem "ProjectGuid" "{$guid}"
    # prefix the assembly name witht ths plugin's name
    ReplaceCommonProjectItem "AssemblyName" "$name.$Common"
    # replace pack addresses with new name
    ReplacePackAddresses $name
    # rename the common project for this plugin
    Rename-Item "$TempDir\$Common\$Common.csproj" "$TempDir\$Common\$name.$Common.csproj"
    Rename-Item "$TempDir\$Common" "$TempDir\$name.$Common"
    # delete any existing files in this plugins common project
    Write-Host "Cleaning up"
    RemoveDirectoryIfExists "$RootDir\$name.$Common"
    # copy the new Common project in its place
    Copy-Item "$TempDir\$name.$Common" $RootDir -Force -Recurse
    # remove the temporary files
    RemoveDirectoryIfExists $TempDir
}

# if local switch is given, copy local repo
if ($LocalOnly) {
	RemoveDirectoryIfExists $TempDir
	mkdir $TempDir > $null
	Copy-Item "$LocalDir\*" $TempDir -Recurse -Exclude $CopyIgnore
	EditAndReplaceCommonProject
# if git is found pull remote repo, exit if not found
} elseif (Get-Command "git.exe" -ErrorAction SilentlyContinue) {
    RemoveDirectoryIfExists $TempDir
    # clone the Common repo to a temp directory
    Write-Host "Cloning common repo"
    git clone -q --branch=master --depth=1 $CommonRepo $TempDir
    EditAndReplaceCommonProject
} else {
    ErrorAndExit "git not found, make sure it is included in `$Path"
}
