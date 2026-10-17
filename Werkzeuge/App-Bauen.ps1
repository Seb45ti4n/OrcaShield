param([ValidateSet('Release', 'Debug')][string]$Konfiguration = 'Release')

$ErrorActionPreference = 'Stop'
$app = Join-Path (Split-Path -Parent $PSScriptRoot) 'App'
$dotnet = Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'
if (-not (Test-Path -LiteralPath $dotnet)) { throw ".NET SDK fehlt ($dotnet) - Installation: winget install --id Microsoft.DotNet.SDK.8 -e" }

$fehler = 0
foreach ($art in @('x64', 'ARM64')) {
    $ziel = Join-Path $app ('Ausgabe\' + $art.ToLower())
    Write-Host "== $art -> $ziel" -ForegroundColor Cyan
    # Eigener Zwischenordner je Bauart, sonst übernimmt der Bau alte Dateien der anderen Bauart.
    $obj = Join-Path $app ('obj\' + $art.ToLower() + '\')
    & $dotnet build (Join-Path $app 'OrcaShield.App.csproj') -c $Konfiguration -nologo `
        "-p:PlatformTarget=$art" "-p:BaseIntermediateOutputPath=$obj" "-p:MSBuildProjectExtensionsPath=$obj" -o $ziel
    if ($LASTEXITCODE -ne 0) { $fehler++; Write-Host "Bau $art fehlgeschlagen" -ForegroundColor Red; continue }

    $b = [IO.File]::ReadAllBytes((Join-Path $ziel 'OrcaShield.exe'))
    $pe = [BitConverter]::ToInt32($b, 0x3C)
    $m = [BitConverter]::ToUInt16($b, $pe + 4)
    $soll = if ($art -eq 'x64') { 0x8664 } else { 0xAA64 }
    if ($m -eq $soll) { Write-Host ("   PE-Kopf 0x{0:X4} - stimmt" -f $m) -ForegroundColor Green }
    else { Write-Host ("   PE-Kopf 0x{0:X4} - erwartet 0x{1:X4}" -f $m, $soll) -ForegroundColor Red; $fehler++ }
}
if ($fehler) { Write-Host "$fehler Fehler" -ForegroundColor Red; exit 1 }
Write-Host 'Beide Bauarten fertig.' -ForegroundColor Green
