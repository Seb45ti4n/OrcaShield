
$ErrorActionPreference = 'Continue'
$basis = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $basis 'Orca-Common.ps1')

Initialize-OrcaKonsole -Titel 'OrcaShield'
$startZeit = Get-Date

# --------------------------------------------------------------
#  VORSPANN - sofort etwas zeigen, geladen wird danach
# --------------------------------------------------------------
$kopf = "  ┌─[ orcashield $($Global:OrcaVersion) ]─[ $("$env:USERNAME@$env:COMPUTERNAME".ToLower()) ]"
Write-Host ''
Write-OrcaTipp -Text $kopf -Farbe DarkGray -ZeichenProSekunde 700
Write-OrcaTipp -Text '  └──> hallo, freund.' -Farbe Cyan -ZeichenProSekunde 120
Write-Host ''
Write-OrcaWal -Form Kompakt
Write-Host ''

. (Join-Path $basis 'Orca-Settings.ps1')
. (Join-Path $basis 'Orca-Engine.ps1')
. (Join-Path $basis 'Orca-Debloat.ps1')

Write-OrcaLog -Level INFO -Source 'WAECHTER' -Message "--- Wächter gestartet für $env:USERNAME ---"

# --------------------------------------------------------------
#  AUSGABE
#  Jede Zeile: Bereich, Punkte, Ergebnis - Zeichen für Zeichen.
#  WARN und ALARM werden gesammelt und entscheiden am Ende über
#  die Farbe des Fensters. HINWEIS ist gelb, zählt aber nicht als
#  Problem (etwa: Windows-Update erkannt).
# --------------------------------------------------------------
$script:Befunde = New-Object System.Collections.ArrayList
$script:Laenger = $false
$script:Wartezeit = [timespan]::Zero

function Write-OrcaWZeile {
    param(
        [string]$Bereich,
        [string]$Text,
        [ValidateSet('OK','HINWEIS','WARN','ALARM','INFO')][string]$Stufe = 'OK'
    )
    $farbe = switch ($Stufe) { 'OK' { 'Green' } 'HINWEIS' { 'Yellow' } 'WARN' { 'Yellow' } 'ALARM' { 'Red' } default { 'Gray' } }
    $links  = "  > $Bereich "
    $punkte = ('.' * [Math]::Max(3, 24 - $links.Length)) + ' '
    Write-OrcaTipp -Text $links  -Farbe Gray     -ZeichenProSekunde 500  -OhneUmbruch
    Write-OrcaTipp -Text $punkte -Farbe DarkGray -ZeichenProSekunde 3000 -OhneUmbruch
    Write-OrcaTipp -Text $Text   -Farbe $farbe   -ZeichenProSekunde 500

    if ($Stufe -in @('WARN','ALARM')) { [void]$script:Befunde.Add(@{ Stufe = $Stufe; Bereich = $Bereich; Text = $Text }) }
    if ($Stufe -eq 'HINWEIS') { $script:Laenger = $true }
    $log = switch ($Stufe) { 'OK' { 'OK' } 'ALARM' { 'FEHLER' } 'INFO' { 'INFO' } default { 'WARN' } }
    Write-OrcaLog -Level $log -Source 'WAECHTER' -Message "$($Bereich): $Text"
}

function Write-OrcaWDetail {
    param([string]$Text, [System.ConsoleColor]$Farbe = [System.ConsoleColor]::DarkGray)
    Write-OrcaTipp -Text "      ↳ $Text" -Farbe $Farbe -ZeichenProSekunde 900
    Write-OrcaLog -Level INFO -Source 'WAECHTER' -Message "  $Text"
}

function Close-OrcaWaechter {
    param([int]$Code = 0)
    $alarm = @($script:Befunde | Where-Object { $_.Stufe -eq 'ALARM' })
    $warn  = @($script:Befunde | Where-Object { $_.Stufe -eq 'WARN' })
    $dauer = [math]::Round(((Get-Date) - $startZeit - $script:Wartezeit).TotalSeconds, 1)

    Write-Host ''
    Write-Host ('  ' + ('─' * 60)) -ForegroundColor DarkGray
    if ($alarm.Count -gt 0) {
        Write-OrcaTipp -Text "   ALARM  ·  $($alarm.Count) $(if ($alarm.Count -eq 1) { 'Befund' } else { 'Befunde' })" -Farbe Red -ZeichenProSekunde 60
        foreach ($a in $alarm) { Write-OrcaTipp -Text "   ■ $($a.Bereich): $($a.Text)" -Farbe Red }
        foreach ($w in $warn)  { Write-OrcaTipp -Text "   · $($w.Bereich): $($w.Text)" -Farbe Yellow }
        Write-Host ''
        Write-OrcaTipp -Text '   Das ist kein Fehlalarm, den man wegklickt. Bitte ansehen.' -Farbe White
        Write-OrcaLog -Level FEHLER -Source 'WAECHTER' -Message "--- Wächter beendet nach $dauer Sekunden: ALARM ($($alarm.Count)) ---"
        Wait-OrcaTaste -Text 'Taste drücken, wenn du es gelesen hast'
    }
    elseif ($warn.Count -gt 0) {
        Write-OrcaTipp -Text "   $($warn.Count) $(if ($warn.Count -eq 1) { 'Hinweis' } else { 'Hinweise' })" -Farbe Yellow -ZeichenProSekunde 60
        Write-OrcaLog -Level WARN -Source 'WAECHTER' -Message "--- Wächter beendet nach $dauer Sekunden: $($warn.Count) Hinweise ---"
        Write-Host ''
        Wait-OrcaCountdown -Sekunden 10
    }
    else {
        Write-OrcaTipp -Text '   alles sauber.' -Farbe Green -ZeichenProSekunde 60
        Write-OrcaLog -Level OK -Source 'WAECHTER' -Message "--- Wächter beendet nach $dauer Sekunden: alles sauber ---"
        Write-Host ''
        Wait-OrcaCountdown -Sekunden $(if ($script:Laenger) { 10 } else { 5 })
    }
}

# --------------------------------------------------------------
#  VORAUSSETZUNGEN
# --------------------------------------------------------------
$state = Get-OrcaState
if (-not $state) {
    if ($Global:OrcaStateUnlesbar) {
        Write-OrcaWZeile 'zustand' "Zustandsdatei unlesbar ($($Global:OrcaState)) - letzte gute Fassung liegt daneben als .vorher" -Stufe ALARM
    } else {
        Write-OrcaWZeile 'zustand' "Zustandsdatei fehlt ($($Global:OrcaState)) - OrcaShield neu einrichten" -Stufe ALARM
    }
    Close-OrcaWaechter
    exit 1
}
if (Test-OrcaAlsSystem) {
    Write-OrcaWZeile 'konto' 'läuft als SYSTEM - die Aufgabe muss im Benutzerkonto laufen' -Stufe ALARM
    Close-OrcaWaechter
    exit 1
}
if (-not (Test-OrcaAdmin)) {
    Write-OrcaWZeile 'rechte' 'ohne Administratorrechte gestartet - die Aufgabe muss mit höchsten Rechten laufen' -Stufe ALARM
    Close-OrcaWaechter
    exit 1
}
$eigeneSid = Get-OrcaEigeneSid
if ($state.BenutzerSid -and $eigeneSid -and $state.BenutzerSid -ne $eigeneSid) {
    Write-OrcaWZeile 'konto' "OrcaShield gehört zu einem anderen Konto - nichts zu tun" -Stufe INFO
    Wait-OrcaCountdown -Sekunden 3
    exit 0
}

# --------------------------------------------------------------
#  BEREICHE
#  Welche Bereiche der Wächter prüft, stellst du ein (Feld
#  WaechterAus in orca-state.json). Abgeschaltete Bereiche nennt
#  er einmal in einer Zeile, damit nichts still wegfällt.
# --------------------------------------------------------------
$waechterAus = @($state.WaechterAus | Where-Object { $_ })
function Test-OrcaWBereich {
    param([string]$Name)
    return ($Name -notin $waechterAus)
}
if ($waechterAus.Count -gt 0) {
    $namen = @($Global:OrcaWaechterBereiche | Where-Object { $_.Name -in $waechterAus } | ForEach-Object { $_.Anzeige })
    Write-OrcaWZeile 'bereiche' "ausgeschaltet: $($namen -join ', ')" -Stufe INFO
}

$ed = Get-OrcaWindowsEdition
$nachUpdate = ($state.WindowsBuild -and [int]$state.WindowsBuild -ne [int]$ed.Build)
if ($nachUpdate) {
    Write-OrcaWZeile 'windows' "Build $($state.WindowsBuild) → $($ed.Build): Update erkannt, Rücksetzungen siehe unten" -Stufe HINWEIS
} else {
    Write-OrcaWZeile 'windows' "$($ed.Anzeige) · Build $($ed.Build)"
}

# --------------------------------------------------------------
#  2. KATALOG-UMSTELLUNG
# --------------------------------------------------------------
try {
    # Ohne @(): Die Funktion gibt ihre Liste mit dem Komma-Operator
    # zurueck. @() darum gaebe eine Liste, die eine (leere) Liste
    # enthaelt - Anzahl 1, obwohl nichts umgestellt wurde.
    $mig = Invoke-OrcaKatalogMigration -State $state
    if ($mig.Count -gt 0) {
        Write-OrcaWZeile 'katalog' "$($mig.Count) Punkte auf $($Global:OrcaVersion) umgestellt" -Stufe HINWEIS
        foreach ($m in $mig) { Write-OrcaWDetail $m }
    }
    if ($state.Version -ne $Global:OrcaVersion) {
        Set-OrcaStateFeld -Name 'Version' -Wert $Global:OrcaVersion | Out-Null
    }
} catch {
    Write-OrcaWZeile 'katalog' "Umstellung abgebrochen: $($_.Exception.Message)" -Stufe WARN
}
$state = Get-OrcaState

$aktiv = @($Global:OrcaEinstellungen | Where-Object { $_.Id -in @($state.AktiveEinstellungen) -and -not $_.Ausgemustert })
if (Test-OrcaWBereich 'einstellungen') {
    try {
        $erg = Invoke-OrcaAbgleich -Settings $aktiv -Quelle 'ABGLEICH'
        $script:Abgleich = $erg   # für den Bericht nach einem Funktionsupdate (Abschnitt 10)
        $probleme = $erg.Offen + $erg.Fehler
        $text = "$($erg.Geprueft) geprüft"
        if ($erg.Korrigiert -gt 0) { $text += " · $($erg.Korrigiert) zurückgestellt" }
        if ($probleme -gt 0)       { $text += " · $probleme ohne Wirkung" }
        if ($erg.Korrigiert -eq 0 -and $probleme -eq 0) { $text += ' · alles im Soll' }
        if ($erg.Ausgenommen -gt 0) { $text += " · $($erg.Ausgenommen) ausgenommen" }
        Write-OrcaWZeile 'einstellungen' $text -Stufe $(if ($probleme -gt 0) { 'WARN' } else { 'OK' })
        foreach ($k in $erg.KorrigiertListe) { Write-OrcaWDetail "zurückgestellt: $k" }
        foreach ($o in $erg.OffenListe)      { Write-OrcaWDetail "ohne Wirkung: $o" -Farbe Yellow }
        foreach ($f in $erg.FehlerListe)     { Write-OrcaWDetail "fehlgeschlagen: $f" -Farbe Yellow }

        # Ausnahmen (BenoetigtVon) werden einmal gemeldet, wenn sie
        # entstehen oder wegfallen - nicht bei jeder Anmeldung.
        $vorher = @($state.Ausnahmen | Where-Object { $_ })
        $jetzt  = @($erg.AusgenommenListe)
        foreach ($a in $jetzt) {
            if ($a -notin $vorher) { Write-OrcaWDetail "ausgenommen: $a" -Farbe Yellow; $script:Laenger = $true }
        }
        foreach ($a in $vorher) {
            if ($a -notin $jetzt) { Write-OrcaWDetail "wieder unter Aufsicht: $(($a -split ':')[0])" -Farbe Yellow; $script:Laenger = $true }
        }
        if ((($vorher | Sort-Object) -join '|') -ne (($jetzt | Sort-Object) -join '|')) {
            Set-OrcaStateFeld -Name 'Ausnahmen' -Wert $jetzt | Out-Null
        }

        $zaehler = @{}
        foreach ($e in @($state.Rueckkehrer)) { if ([string]$e -match '^(\w+):(\d+)$') { $zaehler[$matches[1]] = [int]$matches[2] } }
        $rueck = @()
        foreach ($id in @($erg.KorrigiertIds | Select-Object -Unique)) {
            $n = 1 + [int]$zaehler[$id]
            $rueck += "${id}:$n"
            if ($n -eq 3) {
                Write-OrcaWDetail "$id kehrt nach jeder Anmeldung zurück (3-mal in Folge) - etwas stellt es um; wird weiter zurückgestellt" -Farbe Yellow
                $script:Laenger = $true
            }
        }
        if ((@($state.Rueckkehrer | Where-Object { $_ }) -join '|') -ne ($rueck -join '|')) {
            Set-OrcaStateFeld -Name 'Rueckkehrer' -Wert $rueck | Out-Null
        }
    } catch {
        Write-OrcaWZeile 'einstellungen' "Abgleich abgebrochen: $($_.Exception.Message)" -Stufe WARN
    }
}

# --------------------------------------------------------------
#  4. ENTFERNTE APPS
#  Ein einziger Abruf aller Pakete, dann im Speicher verglichen.
#  Edge wird an seiner Programmdatei erkannt, nicht am Paket.
# --------------------------------------------------------------
$weg = @($state.EntfernteApps | Where-Object { $_ })
if ($weg.Count -gt 0 -and (Test-OrcaWBereich 'apps')) {
    try {
        $pakete = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
        $zurueck = @()
        foreach ($app in @($Global:OrcaApps | Where-Object { $_.Id -in $weg -and $_.Id -ne 'M10' })) {
            $da = $false
            foreach ($n in (Get-OrcaAppNamen -App $app)) {
                if (@($pakete | Where-Object { $_ -like "*$n*" }).Count -gt 0) { $da = $true; break }
            }
            if ($da) { $zurueck += $app }
        }
        $edgeZurueck = ('M10' -in $weg -and (Get-OrcaEdgePfad))

        if ($zurueck.Count -eq 0 -and -not $edgeZurueck) {
            Write-OrcaWZeile 'apps' "$($weg.Count) entfernt · keine zurückgekehrt"
        } else {
            $nichtWeg = @()
            foreach ($app in $zurueck) {
                $r = Remove-OrcaApp -App $app
                if ($r.Erfolg -and $r.Entfernt) { Clear-OrcaAppReste -App $app | Out-Null }
                else { $nichtWeg += "$($app.Anzeige): $($r.Grund)" }
            }
            if ($edgeZurueck) {
                $r = Remove-OrcaEdge
                if (-not $r.Erfolg) { $nichtWeg += "Microsoft Edge: $($r.Grund)" }
            }
            $namen = @($zurueck | ForEach-Object { $_.Anzeige }) + @(if ($edgeZurueck) { 'Microsoft Edge' })
            if ($nichtWeg.Count -eq 0) {
                Write-OrcaWZeile 'apps' "zurückgekehrt und wieder entfernt: $($namen -join ', ')" -Stufe HINWEIS
            } else {
                Write-OrcaWZeile 'apps' "zurückgekehrt, nicht entfernbar: $($nichtWeg.Count)" -Stufe WARN
                foreach ($x in $nichtWeg) { Write-OrcaWDetail $x -Farbe Yellow }
            }
        }
    } catch {
        Write-OrcaWZeile 'apps' "Prüfung abgebrochen: $($_.Exception.Message)" -Stufe WARN
    }
}

if (Test-OrcaWBereich 'defender') {
    try {
        $bekannt = $null
        if ($null -ne $state.DefenderAusnahmenBekannt) { $bekannt = @($state.DefenderAusnahmenBekannt) }
        $seit = $null
        if ($state.DefenderFundeBis) { $seit = ConvertFrom-OrcaZeitstempel -Text $state.DefenderFundeBis -Ersatz ([datetime]::MinValue) }
        $lage = Get-OrcaDefenderLage -BekannteAusnahmen $bekannt -FundeSeit $seit
        if ($null -eq $bekannt) {
            Set-OrcaStateFeld -Name 'DefenderAusnahmenBekannt' -Wert @($lage.Ausnahmen) | Out-Null
        }
        if ($lage.FundeBis) {
            Set-OrcaStateFeld -Name 'DefenderFundeBis' -Wert (ConvertTo-OrcaZeitstempel -Zeit $lage.FundeBis) | Out-Null
        }
        $gut = @($lage.Befunde | Where-Object { $_.Stufe -eq 'OK' } | ForEach-Object { $_.Text })
        $schlecht = @($lage.Befunde | Where-Object { $_.Stufe -notin @('OK','INFO') })
        if ($schlecht.Count -eq 0) {
            Write-OrcaWZeile 'defender' ($gut -join ' · ')
        } else {
            foreach ($s in $schlecht) { Write-OrcaWZeile 'defender' $s.Text -Stufe $s.Stufe }
        }
        foreach ($s in @($lage.Befunde | Where-Object { $_.Stufe -eq 'INFO' })) { Write-OrcaWDetail $s.Text }
    } catch {
        Write-OrcaWZeile 'defender' "Prüfung abgebrochen: $($_.Exception.Message)" -Stufe ALARM
    }
}

# --------------------------------------------------------------
#  5b. GERÄTEKENNUNG
#  Nur wenn die Sperre der Microsoft-Adressen aktiv ist. Liegt trotz
#  Sperre eine echte Kennung vor, ist das eine alte - entfernen lässt
#  sie sich auf Knopfdruck in OrcaShield (Seite Gerätekennung). Ist zusätzlich die
#  Kontoanmeldung gesperrt (NET009) und trotzdem eine da: Alarm.
# --------------------------------------------------------------
if ('NET005' -in @($state.AktiveEinstellungen) -and (Test-OrcaWBereich 'kennung')) {
    try {
        $g = Get-OrcaGdidStand
        if ($g.Echt -eq 0) {
            Write-OrcaWZeile 'kennung' 'keine Microsoft-Gerätekennung gespeichert'
        } elseif ('NET009' -in @($state.AktiveEinstellungen)) {
            Write-OrcaWZeile 'kennung' "Gerätekennung vorhanden trotz Sperre ($($g.Orte -join ', '))" -Stufe ALARM
        } else {
            Write-OrcaWZeile 'kennung' "alte Gerätekennung gespeichert ($($g.Orte -join ', ')) - entfernen in OrcaShield, Seite Gerätekennung" -Stufe WARN
        }
    } catch { }
}

# --------------------------------------------------------------
#  6. HERUNTERFAHREN-WÄCHTER
# --------------------------------------------------------------
if ($state.BereinigungAktiv) {
    if ($null -eq $state.SchattenkopienLoeschen) {
        Write-OrcaWZeile 'herunterfahren' 'Schattenkopien werden seit 1.0.1 nur noch mit eigenem Schalter gelöscht (Überwachung & Automatik) - derzeit aus' -Stufe HINWEIS
        Set-OrcaStateFeld -Name 'SchattenkopienLoeschen' -Wert $false | Out-Null
    }
    if (Test-OrcaWBereich 'herunterfahren') {
        try {
            $stand = Get-OrcaShutdownRegistrierung
            if (-not $stand.Vollstaendig) {
                $r = Register-OrcaShutdownSkript -Quelle (Join-Path $Global:OrcaSkripte 'Orca-Waechter-Shutdown.ps1')
                if ($r.Erfolg -and $r.Uebernommen) {
                    Write-OrcaWZeile 'herunterfahren' 'neu eingetragen und von Windows übernommen - läuft ab dem nächsten Herunterfahren' -Stufe HINWEIS
                } else {
                    Write-OrcaWZeile 'herunterfahren' "NICHT einsatzbereit: $($r.Grund)" -Stufe ALARM
                }
            } else {
                $n = Get-OrcaShutdownNachweis -State $state
                Write-OrcaWZeile 'herunterfahren' $n.Text -Stufe $n.Stufe
                if ($state.LetzterShutdownErgebnis) { Write-OrcaWDetail "Bereinigung: $($state.LetzterShutdownErgebnis)" }
                if ($stand.ZuletztAusgefuehrt) { Write-OrcaWDetail "Windows bestätigt: $($stand.ZuletztAusgefuehrt.ToString('dd.MM. HH:mm'))" }
            }
        } catch {
            Write-OrcaWZeile 'herunterfahren' "Prüfung abgebrochen: $($_.Exception.Message)" -Stufe WARN
        }
    }

    # ----------------------------------------------------------
    #  7. TRIM - nur, wenn seit dem letzten Mal bereinigt wurde
    #  Gelöschte Dateien sind auf einer SSD erst nach TRIM und der
    #  Speicherbereinigung des Laufwerks wirklich weg.
    # ----------------------------------------------------------
    if (Test-OrcaWBereich 'trim') {
        try {
            $lauf = ConvertFrom-OrcaZeitstempel -Text $state.LetzterShutdownlauf -Ersatz ([datetime]::MinValue)
            $trim = ConvertFrom-OrcaZeitstempel -Text $state.LetzterTrim -Ersatz ([datetime]::MinValue)
            if ($lauf -gt $trim) {
                $abfrage = fsutil behavior query DisableDeleteNotify 2>&1 | Out-String
                if ($abfrage -match 'DisableDeleteNotify\D*=\s*1') {
                    Invoke-OrcaProgramm -Datei 'fsutil.exe' -Argumente 'behavior set DisableDeleteNotify 0' | Out-Null
                    Write-OrcaWDetail 'TRIM war abgeschaltet und wurde eingeschaltet' -Farbe Yellow
                }
                $rc = Invoke-OrcaProgramm -Datei 'defrag.exe' -Argumente 'C: /L'
                if ($rc -eq 0) {
                    Write-OrcaWZeile 'trim' 'Durchlauf auf C: nach der Bereinigung abgeschlossen'
                    Set-OrcaStateFeld -Name 'LetzterTrim' -Wert (ConvertTo-OrcaZeitstempel) | Out-Null
                } else {
                    Write-OrcaWZeile 'trim' "Durchlauf meldete Rückgabewert $rc" -Stufe WARN
                }
            }
        } catch {
            Write-OrcaWZeile 'trim' "abgebrochen: $($_.Exception.Message)" -Stufe WARN
        }
    }
}

# --------------------------------------------------------------
#  8. EIGENE AUFGABE UND SCHREIBRECHTE
# --------------------------------------------------------------
try {
    $aufg = Get-OrcaWaechterAufgabe
    if (-not ($aufg.Da -and $aufg.Aktiv -and $aufg.Erhoeht)) {
        $konto = if ($state.BenutzerName) { $state.BenutzerName } else { "$env:USERDOMAIN\$env:USERNAME" }
        $r = Register-OrcaWaechterAufgabe -Konto $konto
        Write-OrcaWZeile 'aufgabe' $(if ($r.Erfolg) { 'war beschädigt und wurde neu angelegt' } else { "nicht reparierbar: $($r.Grund)" }) -Stufe $(if ($r.Erfolg) { 'HINWEIS' } else { 'WARN' })
    }
    $alt = @(Remove-OrcaAlteAufgaben)
    if ($alt.Count -gt 0) { Write-OrcaWDetail "alte Aufgaben entfernt: $($alt -join ', ')" }

    if (Test-OrcaWBereich 'rechte') {
        $rechte = Test-OrcaOrdnerRechte
        if ($rechte.Sicher) {
            Write-OrcaWZeile 'rechte' 'nur Administratoren und SYSTEM dürfen schreiben'
        } else {
            $r = Set-OrcaOrdnerRechte
            if ($r.Erfolg) {
                Write-OrcaWZeile 'rechte' 'zu weit gefasst - korrigiert: nur Administratoren und SYSTEM' -Stufe HINWEIS
            } else {
                Write-OrcaWZeile 'rechte' 'andere Konten dürfen OrcaShield-Dateien ändern' -Stufe ALARM
                foreach ($b in @($rechte.Befund | Select-Object -First 5)) { Write-OrcaWDetail $b -Farbe Red }
            }
        }
    }
} catch {
    Write-OrcaWZeile 'aufgabe' "Prüfung abgebrochen: $($_.Exception.Message)" -Stufe WARN
}

# --------------------------------------------------------------
#  9. HYPERVISOR UND SUCHINDEX
# --------------------------------------------------------------
if ('LEI005' -in @($state.AktiveEinstellungen) -and (Test-OrcaWBereich 'hypervisor')) {
    try {
        # Ist LEI005 ausgenommen (Feld BenoetigtVon, z. B. Docker
        # Desktop), läuft der Hypervisor gewollt - keine Warnung.
        $lei005 = $Global:OrcaEinstellungen | Where-Object { $_.Id -eq 'LEI005' } | Select-Object -First 1
        $lei005bv = if ($lei005) { Get-OrcaBenoetigtVon -Setting $lei005 } else { @() }
        $h = Get-OrcaHypervisorUrsache
        if (@($lei005bv).Count -gt 0) {
            Write-OrcaWZeile 'hypervisor' "$(if ($h.Laeuft) { 'an' } else { 'aus' }) · für $(@($lei005bv) -join ', ') ausgenommen"
        } elseif ($h.Laeuft) {
            Write-OrcaWZeile 'hypervisor' 'läuft trotz Abschaltung' -Stufe WARN
            if (@($h.Ursachen).Count -gt 0) { Write-OrcaWDetail "eingeschaltet: $(@($h.Ursachen) -join ', ')" -Farbe Yellow }
            else { Write-OrcaWDetail 'keine bekannte Windows-Funktion eingeschaltet - Neustart abwarten' -Farbe Yellow }
        } else {
            Write-OrcaWZeile 'hypervisor' 'aus'
        }
    } catch { }
}

if ('SUCH010' -in @($state.AktiveEinstellungen) -and (Test-OrcaWBereich 'suchindex')) {
    try {
        $regeln = 'HKLM:\SOFTWARE\Microsoft\Windows Search\CrawlScopeManager\Windows\SystemIndex\WorkingSetRules'
        $drin = @()
        foreach ($k in @(Get-ChildItem -LiteralPath $regeln -ErrorAction Stop)) {
            $p = Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue
            if ($p.Include -eq 1 -and [string]$p.URL -match '^file:///([A-Za-z]):') { $drin += $matches[1].ToUpper() }
        }
        $drin = @($drin | Sort-Object -Unique)
        $fremd = @($drin | Where-Object { $_ -notin @('C','D') })
        if ($fremd.Count -gt 0) {
            Write-OrcaWZeile 'suchindex' "indiziert auch $(($fremd | ForEach-Object { "$($_):" }) -join ' ') - dort liegen womöglich entschlüsselte Inhalte" -Stufe WARN
        } else {
            $text = (($drin | ForEach-Object { "$($_):" }) -join ' ')
            if ('D' -notin $drin) { $text += ' · D: noch nicht im Index' }
            Write-OrcaWZeile 'suchindex' $text
        }
    } catch { }
}

$neuGesamt = 0
if (Test-OrcaWBereich 'telemetrie') {
    try {
        $h = Invoke-OrcaEigeneSperrenHalten
        if ($h.Zurueckgestellt.Count -gt 0) {
            Write-OrcaWZeile 'telemetrie' "$($h.Zurueckgestellt.Count) von OrcaShield abgeschaltete wieder eingeschaltet - erneut abgeschaltet" -Stufe HINWEIS
            foreach ($z in $h.Zurueckgestellt) { Write-OrcaWDetail "zurückgestellt: $z"; Write-OrcaLog -Level WARN -Source 'NEUES' -Message "Eigene Sperre zurückgestellt: $z" }
        }
        foreach ($f in $h.Fehler) { Write-OrcaWZeile 'telemetrie' "Sperre nicht haltbar: $f" -Stufe WARN }
    } catch {
        Write-OrcaWZeile 'telemetrie' "Sperren nicht geprüft: $($_.Exception.Message)" -Stufe WARN
    }
}
$artenAn = @($Global:OrcaNeuesArten | Where-Object { Test-OrcaWBereich $_.Name } | ForEach-Object { $_.Name })
if ($artenAn.Count -gt 0) {
    $funde = [ordered]@{}
    foreach ($n in (Get-OrcaNeues -State (Get-OrcaState) -Arten $artenAn)) {
        if ($n.fehler) { Write-OrcaWZeile $n.art "Prüfung abgebrochen: $($n.fehler)" -Stufe WARN; continue }
        if ($n.erstlauf) {
            $r = Add-OrcaBekannt -Art $n.art -Alle
            Write-OrcaWZeile $n.art "$($n.bestand) Einträge als bekannt übernommen - ab jetzt wird Neues gemeldet" -Stufe INFO
            continue
        }
        $anz = @($n.neu).Count
        if ($anz -eq 0) { Write-OrcaWZeile $n.art "nichts Neues ($($n.bestand) bekannt)"; continue }
        $neuGesamt += $anz
        $funde[$n.art] = @($n.neu | ForEach-Object { $_.anzeige })
        Write-OrcaWZeile $n.art "$anz neu - aufnehmen oder prüfen unter Überwachung & Automatik" -Stufe WARN
        foreach ($e in @($n.neu | Select-Object -First 8)) { Write-OrcaWDetail $e.anzeige -Farbe Yellow }
        if ($anz -gt 8) { Write-OrcaWDetail "… und $($anz - 8) weitere" -Farbe Yellow }
        foreach ($e in @($n.neu)) { Write-OrcaLog -Level WARN -Source 'NEUES' -Message "$($n.art): $($e.anzeige)" }
    }
    Set-OrcaStateFeld -Name 'NeuGefunden' -Wert ([pscustomobject]@{ Zeit = (ConvertTo-OrcaZeitstempel); Funde = [pscustomobject]$funde }) | Out-Null
}

if ($nachUpdate -and (Test-OrcaWBereich 'update')) {
    $zur  = @(if ($script:Abgleich) { $script:Abgleich.KorrigiertListe })
    $ohne = @(if ($script:Abgleich) { @($script:Abgleich.OffenListe) + @($script:Abgleich.FehlerListe) })
    $text = "Build $($state.WindowsBuild) → $($ed.Build): $($zur.Count) zurückgestellt, $($ohne.Count) ohne Wirkung, $neuGesamt neu gefunden"
    Write-OrcaWZeile 'update' $text -Stufe HINWEIS
    Write-OrcaLog -Level WARN -Source 'UPDATE' -Message $text
    foreach ($z in $zur)  { Write-OrcaLog -Level WARN -Source 'UPDATE' -Message "zurückgestellt: $z" }
    foreach ($o in $ohne) { Write-OrcaLog -Level WARN -Source 'UPDATE' -Message "ohne Wirkung: $o" }
    Set-OrcaStateFeld -Name 'UpdateBericht' -Wert ([pscustomobject]@{ Zeit = (ConvertTo-OrcaZeitstempel); Von = [int]$state.WindowsBuild; Nach = [int]$ed.Build
                                                                     Zurueckgestellt = $zur; OhneWirkung = $ohne; NeuGefunden = $neuGesamt }) | Out-Null
    $script:Laenger = $true
}

# --------------------------------------------------------------
#  ERSTER LAUF: VOLLSTÄNDIGE BESTANDSAUFNAHME
# --------------------------------------------------------------
if (-not $state.ErstlaufErledigt) {
    Write-Host ''
    Write-OrcaTipp -Text '  ── bestandsaufnahme ─────────────────────────────────────' -Farbe Cyan -ZeichenProSekunde 2000
    $letzte = ''
    $zahl = @{ Gut = 0; Offen = 0; Nicht = 0 }
    foreach ($s in $aktiv) {
        if ($s.Kategorie -ne $letzte) {
            Write-OrcaTipp -Text "  $($s.Kategorie.ToLower())" -Farbe Gray -ZeichenProSekunde 3000
            $letzte = $s.Kategorie
        }
        $p = Test-OrcaSetting -Setting $s
        switch ($p.Status) {
            'Erfuellt'       { $zahl.Gut++;   Write-OrcaTipp -Text "    ✓ $($s.Id)  $($s.Name)" -Farbe Green -ZeichenProSekunde 3000 }
            { $_ -in @('NichtAnwendbar','NichtVorhanden') } {
                               $zahl.Nicht++; Write-OrcaTipp -Text "    · $($s.Id)  $($s.Name) - $($p.Grund)" -Farbe DarkGray -ZeichenProSekunde 3000 }
            default          { $zahl.Offen++; Write-OrcaTipp -Text "    ✗ $($s.Id)  $($s.Name) - Ist: $($p.Ist)" -Farbe Yellow -ZeichenProSekunde 3000 }
        }
    }
    Write-OrcaTipp -Text "  $($zahl.Gut) aktiv · $($zahl.Offen) abweichend · $($zahl.Nicht) hier wirkungslos · Grundzustand: $((Get-OrcaBaselineStand).Tabelle.Count) Punkte gesichert" -Farbe White
    Write-OrcaLog -Level INFO -Source 'WAECHTER' -Message "Bestandsaufnahme: $($zahl.Gut) aktiv, $($zahl.Offen) abweichend, $($zahl.Nicht) wirkungslos"
    Set-OrcaStateFeld -Name 'ErstlaufErledigt' -Wert $true | Out-Null
    $script:Laenger = $true
    $warteBeginn = Get-Date
    Wait-OrcaTaste -Text 'Bestandsaufnahme - Taste drücken zum Fortfahren'
    $script:Wartezeit += ((Get-Date) - $warteBeginn)
}

# --------------------------------------------------------------
#  ABSCHLUSS
# --------------------------------------------------------------
Set-OrcaStateFeld -Name 'WindowsBuild' -Wert ([int]$ed.Build) | Out-Null
Set-OrcaStateFeld -Name 'LetzterWaechterlauf' -Wert (ConvertTo-OrcaZeitstempel) | Out-Null
Close-OrcaWaechter
exit 0
