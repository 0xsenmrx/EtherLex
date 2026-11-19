# Builds the release app, then packs it into
# installer\Output\EtherLex-Setup-<version>.exe (version from pubspec.yaml).
# Always use this rather than running ISCC alone: the installer packs
# whatever is in build\windows\x64\runner\Release, however old it is.
#
#   powershell -ExecutionPolicy Bypass -File installer\build.ps1

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

$version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)').Matches[0].Groups[1].Value
Write-Host "Building EtherLex $version (release)..."

flutter build windows --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$iscc = @(
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 (ISCC.exe) was not found. Install it from jrsoftware.org.' }

& $iscc "/DAppVersion=$version" installer\etherlex.iss
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Done: installer\Output\EtherLex-Setup-$version.exe"
