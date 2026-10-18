
$ErrorActionPreference = 'Continue'
$basis = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $basis 'Orca-Common.ps1')

Write-OrcaLog -Level INFO -Source 'SHUTDOWN' -Message '--- Wächter (Herunterfahren) gestartet ---'
$startZeit = Get-Date

$state = Get-OrcaState
if (-not $state -and $Global:OrcaStateUnlesbar) {
    Write-OrcaLog -Level FEHLER -Source 'SHUTDOWN' -Message 'Zustandsdatei unlesbar - Bereinigung übersprungen'
    exit 1
}
if (-not $state -or -not $state.BereinigungAktiv) {
    Write-OrcaLog -Level SKIP -Source 'SHUTDOWN' -Message 'Bereinigung ist nicht aktiviert - nichts zu tun'
    exit 0
}

$script:erledigt   = 0
$script:teilweise  = 0
$script:fehler     = 0

# Profile einmal ermitteln und wiederverwenden.
# Bewusst NICHT $profile - das ist eine Automatikvariable von
# PowerShell und trägt normalerweise den Pfad zum Profilskript.
$script:orcaProfile = @(Get-OrcaBenutzerProfile)
if ($script:orcaProfile.Count -eq 0) {
    Write-OrcaLog -Level WARN -Source 'SHUTDOWN' `
        -Message 'Keine Benutzerprofile gefunden - benutzerbezogene Schritte werden übersprungen'
}

# --------------------------------------------------------------
#  HILFSFUNKTIONEN
# --------------------------------------------------------------

function Test-OrcaSchrittAn {
    param([Parameter(Mandatory)][string]$Name)
    return ($Name -notin @($state.BereinigungAus))
}

function Invoke-OrcaSchritt {
    param([string]$Name, [scriptblock]$Aktion, [string]$Schritt = '')
    if ($Schritt -and -not (Test-OrcaSchrittAn $Schritt)) {
        Write-OrcaLog -Level SKIP -Source 'SHUTDOWN' -Message "$Name - abgeschaltet"
        return
    }
    try {
        $r = & $Aktion
        if ($null -eq $r) { $r = @{ Weg = 0; Rest = 0; Text = '' } }

        $zusatz = if ($r.Text) { " - $($r.Text)" } else { '' }
        if ($r.Rest -gt 0) {
            Write-OrcaLog -Level WARN -Source 'SHUTDOWN' `
                -Message "$Name - TEILWEISE erledigt: $($r.Weg) beseitigt, $($r.Rest) nicht entfernbar$zusatz"
            # Welche es sind, steht darunter - sonst bleibt bei jedem
            # Lauf dieselbe gelbe Zeile, ohne dass man nachsehen kann.
            foreach ($b in @($r.Bleibt | Select-Object -First 5)) {
                Write-OrcaLog -Level INFO -Source 'SHUTDOWN' -Message "  bleibt: $b"
            }
            $script:teilweise++
        } else {
            Write-OrcaLog -Level OK -Source 'SHUTDOWN' -Message "$Name - erledigt ($($r.Weg))$zusatz"
            $script:erledigt++
        }
    }
    catch {
        Write-OrcaLog -Level FEHLER -Source 'SHUTDOWN' -Message "$Name - FEHLGESCHLAGEN. Grund: $($_.Exception.Message)"
        $script:fehler++
    }
}

function Remove-OrcaDateienGezaehlt {
    param([string[]]$Pfade, [Parameter(Mandatory)][string]$Wurzel)
    $weg = 0; $rest = 0; $bleibt = @()
    foreach ($p in $Pfade) {
        if (-not (Test-Path -LiteralPath $p)) { continue }
        if (Remove-OrcaPfadSicher -Wurzel $Wurzel -Pfad $p) { $weg++ } else { $rest++; $bleibt += $p }
    }
    return @{ Weg = $weg; Rest = $rest; Bleibt = $bleibt }
}

# Löscht den Inhalt eines Ordners in jedem Benutzerprofil.
# $Relativ ist der Pfad unterhalb des Profilordners.
function Clear-OrcaProfilOrdner {
    param(
        [Parameter(Mandatory)][string]$Relativ,
        [string]$Filter = '*',
        [switch]$Rekursiv,
        [string[]]$Ausnahme = @()
    )
    $weg = 0; $rest = 0; $bleibt = @()
    foreach ($p in $script:orcaProfile) {
        $ziel = Join-Path $p.Profilpfad $Relativ
        if (-not (Test-Path -LiteralPath $ziel)) { continue }
        # Kein Ordner zwischen Profil und Ziel darf eine Verknüpfung sein (etwa AppData\Local\Temp -> C:\Windows)
        if (-not (Test-OrcaWegSicher -Wurzel $p.Profilpfad -Pfad $ziel)) {
            Write-OrcaLog -Level WARN -Source 'SHUTDOWN' -Message "Übersprungen, Verzeichnisverknüpfung im Weg: $ziel"
            $rest++; $bleibt += $ziel; continue
        }
        try {
            $liste = Get-OrcaDateienSicher -Wurzel $ziel -Filter $Filter -Rekursiv:$Rekursiv
            $dateien = @($liste | Where-Object { [IO.Path]::GetFileName($_) -notin $Ausnahme })
            $r = Remove-OrcaDateienGezaehlt -Pfade $dateien -Wurzel $ziel
            $weg  += $r.Weg
            $rest += $r.Rest
            $bleibt += @($r.Bleibt)
        } catch { }
    }
    return @{ Weg = $weg; Rest = $rest; Bleibt = $bleibt }
}

# ==============================================================
#  1. PAPIERKORB LEEREN
#     Als SYSTEM leert Clear-RecycleBin nur den Papierkorb des
#     Systemkontos. Deshalb über die Ablage je Benutzerkennung.
# ==============================================================
Invoke-OrcaSchritt -Schritt 'papierkorb' -Name 'Papierkorb leeren' -Aktion {
    $weg = 0; $rest = 0
    foreach ($lw in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
        $ablage = Join-Path $lw.Root '$Recycle.Bin'
        if (-not (Test-Path -LiteralPath $ablage)) { continue }
        foreach ($p in $script:orcaProfile) {
            $meins = Join-Path $ablage $p.Sid
            if (-not (Test-Path -LiteralPath $meins)) { continue }
            if (Test-OrcaIstVerknuepfung $meins) { Write-OrcaLog -Level WARN -Source 'SHUTDOWN' -Message "Übersprungen, Verzeichnisverknüpfung: $meins"; $rest++; continue }
            # Nur die oberste Ebene aufzählen (liest nur); Ordner darin löscht Remove-OrcaPfadSicher ohne Verknüpfungen zu folgen
            $eintraege = @(Get-ChildItem -LiteralPath $meins -Force -ErrorAction SilentlyContinue)
            $r = Remove-OrcaDateienGezaehlt -Pfade @($eintraege | ForEach-Object { $_.FullName }) -Wurzel $meins
            $weg  += $r.Weg
            $rest += $r.Rest
        }
    }
    return @{ Weg = $weg; Rest = $rest; Text = 'Eintraege' }
}

if ($state.SchattenkopienLoeschen) {
    Invoke-OrcaSchritt -Name 'Volumeschattenkopien löschen' -Aktion {
        $r = Remove-OrcaSchattenkopien
        if ($r.Nachher -gt 0 -and $r.Nachher -eq $r.Vorher) {
            throw "keine der $($r.Vorher) Schattenkopien ließ sich löschen: $($r.Grund)"
        }
        return @{ Weg = ($r.Vorher - $r.Nachher); Rest = $r.Nachher
                  Text = $(if ($r.Nachher -gt 0) { $r.Grund } else { 'Schattenkopien' }) }
    }
}

# ==============================================================
#  3. MINIATURANSICHT-ZWISCHENSPEICHER LEEREN
#     Enthält Vorschaubilder auch von längst gelöschten Dateien.
# ==============================================================
Invoke-OrcaSchritt -Schritt 'miniaturansichten' -Name 'Miniaturansicht-Zwischenspeicher leeren' -Aktion {
    $rel = 'AppData\Local\Microsoft\Windows\Explorer'
    $a = Clear-OrcaProfilOrdner -Relativ $rel -Filter 'thumbcache_*.db'
    $b = Clear-OrcaProfilOrdner -Relativ $rel -Filter 'iconcache_*.db'
    return @{ Weg = ($a.Weg + $b.Weg); Rest = ($a.Rest + $b.Rest); Text = 'Dateien' }
}

# ==============================================================
#  4. DIAGNOSEPROTOKOLLE LÖSCHEN
#     Die von Windows gesammelten Telemetrie-Rohdaten.
#     Der Unterordner AutoLogger ist im laufenden Betrieb
#     geöffnet und lässt sich häufig nicht löschen - das
#     wird jetzt gemeldet statt verschwiegen.
# ==============================================================
Invoke-OrcaSchritt -Schritt 'diagnose' -Name 'Diagnoseprotokolle (ETLLogs) löschen' -Aktion {
    $pfad = "$env:ProgramData\Microsoft\Diagnosis\ETLLogs"
    if (-not (Test-Path -LiteralPath $pfad)) { return @{ Weg = 0; Rest = 0; Text = 'nichts vorhanden' } }
    $dateien = Get-OrcaDateienSicher -Wurzel $pfad -Rekursiv
    $r = Remove-OrcaDateienGezaehlt -Pfade @($dateien) -Wurzel $pfad
    $text = if ($r.Rest -gt 0) { 'im Betrieb geöffnete Ablaufverfolgungsdateien lassen sich erst nach dem Abschalten des Autologgers löschen' } else { 'Dateien' }
    return @{ Weg = $r.Weg; Rest = $r.Rest; Text = $text }
}

# ==============================================================
#  5. ZULETZT VERWENDETE DATEIEN UND SCHNELLZUGRIFF
# ==============================================================
Invoke-OrcaSchritt -Schritt 'zuletzt' -Name 'Zuletzt verwendete Dateien löschen' -Aktion {
    # Ausgenommen: die Datei, in der der Explorer die angehefteten
    # Ordner des Schnellzugriffs speichert. Verlorene Anheftungen
    # lassen sich nicht zurueckholen. Preis: Die Liste der zuletzt
    # besuchten Ordner steckt in derselben Datei und bleibt mit.
    $r = Clear-OrcaProfilOrdner -Relativ 'AppData\Roaming\Microsoft\Windows\Recent' -Rekursiv `
            -Ausnahme @('f01b4d95cf55d32a.automaticDestinations-ms')
    return @{ Weg = $r.Weg; Rest = $r.Rest; Text = 'Eintraege' }
}

# ==============================================================
#  6. TEMPORÄRE DATEIEN
#     Je Benutzerprofil plus der systemweite Ordner.
#     Dass einzelne Dateien in Benutzung sind, ist normal -
#     deshalb wird die Zahl genannt statt Erfolg behauptet.
# ==============================================================
Invoke-OrcaSchritt -Schritt 'temp' -Name 'Temporäre Dateien löschen' -Aktion {
    $r = Clear-OrcaProfilOrdner -Relativ 'AppData\Local\Temp' -Rekursiv
    $weg = $r.Weg; $rest = $r.Rest; $bleibt = @($r.Bleibt)

    $systemTemp = "$env:SystemRoot\Temp"
    if (Test-Path -LiteralPath $systemTemp) {
        # C:\Windows\Temp: dort darf jedes Konto anlegen - also ebenfalls ohne Verknüpfungen
        $dateien = Get-OrcaDateienSicher -Wurzel $systemTemp -Rekursiv
        $s = Remove-OrcaDateienGezaehlt -Pfade @($dateien) -Wurzel $systemTemp
        $weg += $s.Weg; $rest += $s.Rest; $bleibt += @($s.Bleibt)
    }
    $text = if ($rest -gt 0) { 'in Benutzung befindliche Dateien bleiben liegen' } else { 'Dateien' }
    return @{ Weg = $weg; Rest = $rest; Bleibt = $bleibt; Text = $text }
}

# ==============================================================
#  7. ABSTURZABBILDER LÖSCHEN
#     Absturzabbilder können Ausschnitte des Arbeitsspeichers
#     und damit entschlüsselte Inhalte enthalten.
# ==============================================================
Invoke-OrcaSchritt -Schritt 'absturz' -Name 'Absturzabbilder löschen' -Aktion {
    # Je Ablage mit ihrer eigenen Wurzel: CrashDumps im Profil kann das Konto durch eine Verknüpfung ersetzen
    $weg = 0; $rest = 0
    $paare = @(@{ W = $env:SystemRoot; P = "$env:SystemRoot\MEMORY.DMP" }, @{ W = $env:SystemRoot; P = "$env:SystemRoot\Minidump" })
    foreach ($p in $script:orcaProfile) { $paare += @{ W = $p.Profilpfad; P = (Join-Path $p.Profilpfad 'AppData\Local\CrashDumps') } }
    foreach ($x in $paare) {
        $r = Remove-OrcaDateienGezaehlt -Pfade @($x.P) -Wurzel $x.W
        $weg += $r.Weg; $rest += $r.Rest
    }
    return @{ Weg = $weg; Rest = $rest; Text = 'Ablagen' }
}

# ==============================================================
#  8. RUHEZUSTANDSDATEI DEAKTIVIEREN
#     Die Datei hiberfil.sys enthält ein vollständiges Abbild
#     des Arbeitsspeichers, unverschlüsselt auf der Systemplatte.
# ==============================================================
if ($state.RuhezustandDeaktivieren) {
    Invoke-OrcaSchritt -Name 'Ruhezustand deaktivieren' -Aktion {
        $rc = Invoke-OrcaProgramm -Datei 'powercfg.exe' -Argumente '-h off'
        if ($rc -ne 0) { throw "powercfg meldete Rückgabewert $rc" }
        $da = Test-Path "$env:SystemDrive\hiberfil.sys"
        return @{ Weg = 1; Rest = $(if ($da) { 1 } else { 0 })   # belegt: powercfg-Rückgabewert und hiberfil.sys geprüft
                  Text = $(if ($da) { 'hiberfil.sys liegt noch, sie verschwindet beim Herunterfahren' } else { 'hiberfil.sys entfernt' }) }
    }
}

# ==============================================================
#  9. PREFETCH
#     Windows legt für jedes gestartete Programm eine .pf-Datei
#     an - mit Name, Pfad, Startzeitpunkten und den Dateien, die
#     das Programm in den ersten Sekunden geöffnet hat. Öffnest
#     du per Doppelklick ein Dokument von einem verschlüsselten
#     Laufwerk, kann dessen Pfad darin stehen. Programme starten
#     danach beim ersten Mal minimal langsamer.
# ==============================================================
Invoke-OrcaSchritt -Schritt 'prefetch' -Name 'Prefetch-Dateien löschen' -Aktion {
    $pfad = "$env:SystemRoot\Prefetch"
    if (-not (Test-Path -LiteralPath $pfad)) { return @{ Weg = 0; Rest = 0; Text = 'nichts vorhanden' } }
    $dateien = Get-OrcaDateienSicher -Wurzel $pfad -Filter '*.pf'
    $r = Remove-OrcaDateienGezaehlt -Pfade @($dateien) -Wurzel $pfad
    return @{ Weg = $r.Weg; Rest = $r.Rest; Text = 'Dateien' }
}

# ==============================================================
#  10. EXPLORER-VERLAEUFE UND ORDNERANSICHTEN (SHELLBAGS)
#     Zuletzt geöffnete Dateien, eingetippte Pfade, Ausführen-
#     Befehle, Suchbegriffe im Explorer, Öffnen/Speichern-Dialoge
#     - und die ShellBags: Windows merkt sich zu jedem Ordner, den
#     du im Explorer geöffnet hast, Name und Ansicht. Auch Ordner
#     auf verschlüsselten Laufwerken, lange nachdem sie
#     ausgehängt sind. Folge des Löschens: Der Explorer vergisst
#     die Ansichtseinstellungen je Ordner.
#     Beim Herunterfahren sind die Benutzer bereits abgemeldet,
#     ihre Profile also nicht geladen. Sie werden dafür kurz
#     eingehängt und danach wieder ausgehängt.
# ==============================================================
$script:orcaVerlaeufe = @(
    'Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs'
    'Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths'
    'Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU'
    'Software\Microsoft\Windows\CurrentVersion\Explorer\WordWheelQuery'
    'Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU'
    'Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU'
    'Software\Microsoft\Windows\Shell\BagMRU'
    'Software\Microsoft\Windows\Shell\Bags'
    'Software\Microsoft\Windows\ShellNoRoam\BagMRU'
    'Software\Microsoft\Windows\ShellNoRoam\Bags'
)
# In UsrClass.dat - dem Teil des Profils unter HKCU\Software\Classes
$script:orcaShellBagsKlassen = @(
    'Local Settings\Software\Microsoft\Windows\Shell\BagMRU'
    'Local Settings\Software\Microsoft\Windows\Shell\Bags'
)

function Remove-OrcaRegZweige {
    param([string]$Wurzel, [string[]]$Relativ)
    $weg = 0; $rest = 0
    foreach ($r in $Relativ) {
        $p = "Registry::HKEY_USERS\$Wurzel\$r"
        if (-not (Test-Path -LiteralPath $p)) { continue }
        Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $p) { $rest++ } else { $weg++ }
    }
    return @{ Weg = $weg; Rest = $rest }
}

function Invoke-OrcaHiveArbeit {
    # Hängt eine Profildatei ein, falls nötig, lässt $Arbeit
    # darauf laufen und hängt sie wieder aus.
    param([string]$Name, [string]$Datei, [scriptblock]$Arbeit)
    $geladen = Test-Path "Registry::HKEY_USERS\$Name"
    if (-not $geladen) {
        if (-not (Test-Path -LiteralPath $Datei)) { return @{ Weg = 0; Rest = 0 } }
        $rc = Invoke-OrcaProgramm -Datei 'reg.exe' -Argumente "load `"HKU\$Name`" `"$Datei`""
        if ($rc -ne 0) { throw "Profil $Name nicht ladbar (reg load meldete $rc)" }
    }
    try {
        return (& $Arbeit $Name)
    }
    finally {
        if (-not $geladen) {
            for ($i = 1; $i -le 5; $i++) {
                [gc]::Collect(); [gc]::WaitForPendingFinalizers()
                $rc = Invoke-OrcaProgramm -Datei 'reg.exe' -Argumente "unload `"HKU\$Name`""
                if ($rc -eq 0 -or -not (Test-Path "Registry::HKEY_USERS\$Name")) { break }
                Start-Sleep -Seconds 1
            }
        }
    }
}

Invoke-OrcaSchritt -Schritt 'explorer' -Name 'Explorer-Verläufe und ShellBags löschen' -Aktion {
    $weg = 0; $rest = 0
    foreach ($p in $script:orcaProfile) {
        # Geladene Profile stehen unter ihrer Kennung; ein selbst
        # eingehängtes bekommt einen eigenen Namen, damit es nie
        # mit einem von Windows geladenen verwechselt wird.
        $nt = if (Test-Path "Registry::HKEY_USERS\$($p.Sid)") { $p.Sid } else { "OrcaShield_$($p.Sid)" }
        $r = Invoke-OrcaHiveArbeit -Name $nt -Datei $p.NtUserDat -Arbeit {
            param($w) Remove-OrcaRegZweige -Wurzel $w -Relativ $script:orcaVerlaeufe
        }
        $weg += $r.Weg; $rest += $r.Rest

        $kl = if (Test-Path "Registry::HKEY_USERS\$($p.Sid)_Classes") { "$($p.Sid)_Classes" } else { "OrcaShield_$($p.Sid)_Classes" }
        $datei = Join-Path $p.Profilpfad 'AppData\Local\Microsoft\Windows\UsrClass.dat'
        $r = Invoke-OrcaHiveArbeit -Name $kl -Datei $datei -Arbeit {
            param($w) Remove-OrcaRegZweige -Wurzel $w -Relativ $script:orcaShellBagsKlassen
        }
        $weg += $r.Weg; $rest += $r.Rest
    }
    return @{ Weg = $weg; Rest = $rest; Text = 'Registrierungszweige' }
}

Invoke-OrcaSchritt -Schritt 'auslagerung' -Name 'Auslagerungsdatei beim Herunterfahren leeren' -Aktion {
    $mm = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    if ([int](Get-OrcaRegWert -Pfad $mm -Name 'ClearPageFileAtShutdown') -eq 1) {
        return @{ Weg = 1; Rest = 0; Text = 'war bereits eingeschaltet' }   # belegt: Wert gelesen
    }
    $r = Set-OrcaRegWert -Pfad $mm -Name 'ClearPageFileAtShutdown' -Wert 1
    if (-not $r.Erfolg) { throw $r.Grund }
    if ([int](Get-OrcaRegWert -Pfad $mm -Name 'ClearPageFileAtShutdown') -ne 1) { throw 'geschrieben, aber beim Nachlesen nicht 1' }
    return @{ Weg = 1; Rest = 0; Text = 'eingeschaltet - wirkt ab dem nächsten Herunterfahren' }   # belegt: nachgelesen
}

# ==============================================================
#  ABSCHLUSS
# ==============================================================
$dauer = [math]::Round(((Get-Date) - $startZeit).TotalSeconds, 1)
$stufe = if ($script:fehler -gt 0) { 'FEHLER' } elseif ($script:teilweise -gt 0) { 'WARN' } else { 'INFO' }
$zusammen = "$($script:erledigt) vollständig, $($script:teilweise) teilweise, $($script:fehler) fehlgeschlagen, $dauer Sekunden"
Write-OrcaLog -Level $stufe -Source 'SHUTDOWN' -Message "--- Wächter (Herunterfahren) beendet: $zusammen ---"

# Der Nachweis für den nächsten Start: Der Anmelde-Wächter
# vergleicht diesen Zeitpunkt mit dem letzten Herunterfahren laut
# Systemprotokoll und meldet, wenn dieses Skript nicht lief.
Set-OrcaStateFeld -Name 'LetzterShutdownlauf' -Wert (ConvertTo-OrcaZeitstempel) | Out-Null
Set-OrcaStateFeld -Name 'LetzterShutdownErgebnis' -Wert $zusammen | Out-Null
