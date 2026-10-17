$ErrorActionPreference = 'Stop'
$wurzel = Split-Path -Parent $PSScriptRoot
$lies = { param($rel) [IO.File]::ReadAllText((Join-Path $wurzel $rel)) }

$version = ([regex]::Match((& $lies 'Skripte\Orca-Common.ps1'), "OrcaVersion = '((\d+\.\d+\.\d+)( Public Beta)?)'")).Groups
if (-not $version[1].Success) { throw 'Version in Skripte\Orca-Common.ps1 nicht gefunden' }
$name = $version[1].Value; $nummer = $version[2].Value
$technisch = $nummer + $(if ($version[3].Success) { '-beta' } else { '' })
$datei = "$nummer.0"
$soll = [ordered]@{
    'App\OrcaShield.App.csproj (InformationalVersion)' = @('App\OrcaShield.App.csproj', "<InformationalVersion>$name</InformationalVersion>")
    'App\OrcaShield.App.csproj (FileVersion)'          = @('App\OrcaShield.App.csproj', "<FileVersion>$datei</FileVersion>")
    'App\OrcaShield.App.csproj (Version)'              = @('App\OrcaShield.App.csproj', "<Version>$technisch</Version>")
    'App\app.manifest'                                 = @('App\app.manifest', "version=`"$datei`"")
    'Werkzeuge\Gui\OrcaShield.html'                    = @('Werkzeuge\Gui\OrcaShield.html', "SEITEN_VERSION = `"$name`"")
    'Readme.txt'                                       = @('Readme.txt', "Version $name")
}
# Der Changelog gehört nicht zum veröffentlichten Quelltext; ist er da, muss er passen
$falsch = @($soll.Keys | Where-Object { -not (& $lies $soll[$_][0]).Contains($soll[$_][1]) })
if ($falsch.Count) { throw "Version $name fehlt in: $($falsch -join ', ')" }
$dateiName = $name -replace '\s+', '-'
Write-Host "== Version $name ($datei)" -ForegroundColor Cyan

# --- Inno Setup suchen
$iscc = @((Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
          (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
          (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 fehlt - Installation: winget install --id JRSoftware.InnoSetup -e' }

# --- EXE bauen (beide Bauarten, mit PE-Nachweis)
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'App-Bauen.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Bau der EXE fehlgeschlagen' }

# --- Setup bauen
$iss = Join-Path $wurzel 'Installer\OrcaShield.iss'
& $iscc /Q "/DVersion=$name" "/DDateiVersion=$datei" "/DDateiName=$dateiName" $iss
if ($LASTEXITCODE -ne 0) { throw "Inno Setup meldete $LASTEXITCODE" }
$setup = Join-Path $wurzel "Installer\Ausgabe\OrcaShield-Setup-$dateiName.exe"
if (-not (Test-Path -LiteralPath $setup)) { throw "Setup nicht entstanden: $setup" }
$d = Get-Item -LiteralPath $setup
Write-Host ("Setup fertig: {0} ({1:N1} MB)" -f $d.FullName, ($d.Length / 1MB)) -ForegroundColor Green
Write-Host ("SHA-256 {0}" -f (Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash)
