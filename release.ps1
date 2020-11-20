#Requires -Version 3.0

Param(
	[string]$Platform="x86",
	[string]$Config="Release"
)

$ReleaseDir = "release"
$ProjectPath = (Get-Location).Path
$ProjectName = (Get-ChildItem -Path $ProjectPath | Where { $_.Name -match ".+?\.sln" }).BaseName

$ReleaseDll = "$ProjectPath\$($ProjectName)\bin\$Platform\$Config\$ProjectName.dll"
$ReleaseArchive = "hdt-plugin-" + $ProjectName.ToLower() + ".zip"

if (Test-Path -Path "$ProjectPath\$ReleaseDir") {
	Remove-Item -ErrorAction SilentlyContinue "$ProjectPath\$ReleaseDir\*" -Recurse
} else {
	New-Item -ErrorAction SilentlyContinue -ItemType directory -Path "$ProjectPath\$ReleaseDir" | Out-Null
}

Write-Host "Using $ReleaseDll"
Write-Host "Version" ([Reflection.AssemblyName]::GetAssemblyName($ReleaseDll).Version)
Compress-Archive $ReleaseDll "$ReleaseDir\$ReleaseArchive"