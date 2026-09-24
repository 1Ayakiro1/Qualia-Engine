# Builds the Windows release bundle + portable zip (run on Windows).
# Requires: Flutter SDK with Windows desktop toolchain, Visual Studio Build Tools.
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Version = (Get-Content "$Root\VERSION" -Raw).Trim()

Set-Location "$Root\app"
flutter build windows --release

$Bundle = "$Root\app\build\windows\x64\runner\Release"
if (-not (Test-Path "$Bundle\bci_engine.exe")) {
    throw "bci_engine.exe not found after build"
}

New-Item -ItemType Directory -Force -Path "$Root\builds" | Out-Null
$Zip = "$Root\builds\Ayakiro_BCI_Engine-$Version-windows-x64.zip"
Compress-Archive -Path "$Bundle\*" -DestinationPath $Zip -Force
Write-Host "[bci] Windows zip: $Zip"
