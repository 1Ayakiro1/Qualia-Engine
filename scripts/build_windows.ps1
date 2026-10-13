# Builds the Windows release bundle + portable zip (run on Windows).
# Requires: Flutter SDK with Windows desktop toolchain, Visual Studio Build Tools.
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Version = (Get-Content "$Root\VERSION" -Raw).Trim()

Set-Location "$Root\app"
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "Flutter Windows build failed ($LASTEXITCODE)" }

$Bundle = "$Root\app\build\windows\x64\runner\Release"
if (-not (Test-Path "$Bundle\bci_engine.exe")) {
    throw "bci_engine.exe not found after build"
}
if (-not (Test-Path "$Bundle\bci_engine_core.dll")) {
    throw "Native core DLL not included in Windows bundle"
}

$Dist = if ($env:DIST_OUT) { $env:DIST_OUT } else { "$Root\builds" }
New-Item -ItemType Directory -Force -Path $Dist | Out-Null
$Zip = "$Dist\Ayakiro_BCI_Engine-$Version-windows-x64.zip"
Compress-Archive -Path "$Bundle\*" -DestinationPath $Zip -Force
Write-Host "[bci] Windows zip: $Zip"
