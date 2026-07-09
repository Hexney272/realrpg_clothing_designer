param(
    [Parameter(Mandatory=$true)] [string]$CodeWalkerCorePath,
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$project = Join-Path $PSScriptRoot "RealRpgClothingBridge.csproj"
if (!(Test-Path $CodeWalkerCorePath)) { throw "CodeWalker.Core.dll not found: $CodeWalkerCorePath" }

dotnet build $project -c $Configuration /p:CodeWalkerCorePath="$CodeWalkerCorePath"

$out = Join-Path $PSScriptRoot "bin\$Configuration\net48"
Write-Host "Built bridge in: $out"
Write-Host "Copy RealRpgClothingBridge.exe and CodeWalker runtime DLLs into realrpg_clothing_worker/tools/."
