
if (-not (Get-Command -Name Remove-OrcaApp -CommandType Function -ErrorAction SilentlyContinue)) {
    . (Join-Path $Global:OrcaSkripte 'Orca-Debloat.ps1')
}
if (-not $Global:OrcaTexteEN) {
    . (Join-Path $Global:OrcaSkripte 'Orca-Texte-EN.ps1')
}

function Get-OrcaGuiDaten {
    param(
        # Zustandsdatei, aus der aktive Punkte, Wächterläufe usw. gelesen
        # werden (nur gelesen). Vorgabe: die eigene des Programms.
        [string]$Zustand = $Global:OrcaState,
        # Fortschritt melden (Write-Progress) - die EXE zeigt ihn an
        [switch]$MitFortschritt
    )

    $aktiv = @()
    $st = $null
    if ($Global:OrcaSimulationAktiv -and $Global:PsimZustand) {
        # Simulationsmodus: der simulierte Zustand (Ausgangslage + simulierte Änderungen)
        $st = $Global:PsimZustand
        $aktiv = @($st.AktiveEinstellungen)
    } elseif ($Zustand -and (Test-Path -LiteralPath $Zustand)) {
        try {
            $st = Get-Content -LiteralPath $Zustand -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            $aktiv = @($st.AktiveEinstellungen)
        } catch { }
    }
    $zeit = { param($w) if ($w) { try { ([datetime]$w).ToString('dd.MM. HH:mm') } catch { "$w" } } else { '' } }

    $ed = Get-OrcaWindowsEdition

    # Gemessener Ausgangszustand (nur gelesen) - für die Rückgängig-Befehle
    $bl = @{}
    $blDatei = if ($Zustand) { Join-Path (Split-Path -Parent $Zustand) 'orca-baseline.json' } else { $null }
    if ($blDatei -and (Test-Path -LiteralPath $blDatei)) {
        try {
            $roh = Get-Content -LiteralPath $blDatei -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            foreach ($pr in $roh.PSObject.Properties) { $bl[$pr.Name] = $pr.Value }
        } catch { }
    }

    # Verlauf: die letzten Einträge der Monatsprotokolle (nur gelesen)
    $verlauf = @()
    $logDir = if ($Zustand) { Join-Path (Split-Path -Parent $Zustand) 'Logs' } else { $Global:OrcaLogs }
    $dateien = @(Get-ChildItem -LiteralPath $logDir -Recurse -Filter '*.txt' -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -notlike 'Trockenlauf_*' } | Sort-Object LastWriteTime | Select-Object -Last 2)
    foreach ($f in $dateien) {
        foreach ($z in @(Get-Content -LiteralPath $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue)) {
            if ($z -match '^(\d{2}\.\d{2}\.\d{4}) \| (\d{2}:\d{2}:\d{2}) \| (\S+)\s*\| (\S+)\s*\| (.*)$') {
                $verlauf += [ordered]@{ datum = $matches[1]; zeit = $matches[2]; quelle = $matches[3]; stufe = $matches[4]; text = $matches[5] }
            }
        }
    }
    $verlauf = @($verlauf | Select-Object -Last 400)

    $versionDatum = ''

    $alle = @($Global:OrcaEinstellungen)
    $nr = 0
    $punkte = foreach ($s in $alle) {
        $nr++
        if ($MitFortschritt -and ($nr -eq 1 -or $nr % 8 -eq 0 -or $nr -eq $alle.Count)) {
            Write-Progress -Activity 'Bestandsaufnahme' -Status $s.Kategorie -CurrentOperation $s.Id `
                -PercentComplete ([int](100 * $nr / [Math]::Max(1, $alle.Count)))
        }
        $p = $null
        if (-not $s.Ausgemustert) {
            try { $p = Test-OrcaSetting -Setting $s } catch { $p = @{ Status = 'Fehler'; Ist = ''; Grund = $_.Exception.Message } }
        }
        [ordered]@{
            id          = $s.Id
            name        = $s.Name
            kategorie   = $s.Kategorie
            stufe       = $s.Stufe
            eingriff    = $s.Eingriff
            regTyp      = $s.RegTyp
            basis       = $(if ($bl -and $bl.ContainsKey($s.Id)) { $e = $bl[$s.Id]; [ordered]@{ vorhanden = [bool]$e.Vorhanden; wert = $(if ($null -ne $e.Wert) { "$($e.Wert)" } else { $null }); regTyp = "$($e.RegTyp)"; text = "$($e.Text)" } } else { $null })
            typ         = $s.Typ
            bereich     = $s.Bereich
            erklaerung  = $s.Erklaerung
            hinweis     = $s.Hinweis
            warnung     = $s.Warnung
            grautAus    = [bool]$s.GrautAus
            ohneSperre  = $(if ($Global:OrcaOhneSperre -and $Global:OrcaOhneSperre.ContainsKey($s.Id)) { $Global:OrcaOhneSperre[$s.Id] } else { '' })
            senktSchutz = [bool]$s.SenktSchutz
            abwaegen    = [bool]$s.Abwaegen
            vorgabeNein = [bool]$s.VorgabeNein
            ausgemustert= [bool]$s.Ausgemustert
            pfad        = $s.Pfad
            wert        = $s.Wert
            soll        = "$($s.Soll)"
            aktiv       = ($aktiv -contains $s.Id)
            status      = $(if ($p) { $p.Status } else { 'Ausgemustert' })
            ist         = $(if ($p) { "$($p.Ist)" } else { '' })
            grund       = $(if ($p) { "$($p.Grund)" } else { '' })
            benoetigtVon= @($s.BenoetigtVon | ForEach-Object { $_.Anzeige })
        }
    }
    if ($MitFortschritt) { Write-Progress -Activity 'Bestandsaufnahme' -Completed }

    return [ordered]@{
        version  = $Global:OrcaVersion
        produkt  = $Global:OrcaProdukt
        versionDatum = $versionDatum
        aufgabe  = $Global:OrcaAufgabeWaechter
        bereinigungAktiv = $(if ($st) { [bool]$st.BereinigungAktiv } else { $false })
        schattenkopienAktiv = $(if ($st) { [bool]$st.SchattenkopienLoeschen } else { $false })
        bereinigungSchritte = @($Global:OrcaBereinigungsSchritte | ForEach-Object {
            $an = if ($_.Name -eq 'schattenkopien') { [bool]($st -and $st.SchattenkopienLoeschen) } else { -not ($st -and $_.Name -in @($st.BereinigungAus)) }
            [ordered]@{ name = $_.Name; anzeige = $_.Anzeige; erklaerung = $_.Erklaerung; folge = $_.Folge; an = $an } })
        waechterAktiv = [bool](Get-OrcaWaechterAufgabe).Aktiv
        gemessen = (Get-Date -Format 'dd.MM.yyyy HH:mm')
        system   = "$($ed.Anzeige) · $($ed.Kanon) · Build $($ed.Build)"
        installiert = $(if ($st) { if ($st.Version) { "$($st.Version)" } else { 'ja' } } else { '' })
        waechter    = $(if ($st) { & $zeit $st.LetzterWaechterlauf } else { '' })
        shutdown    = $(if ($st) { & $zeit $st.LetzterShutdownlauf } else { '' })
        shutdownErgebnis = $(if ($st) { "$($st.LetzterShutdownErgebnis)" } else { '' })
        trim        = $(if ($st) { & $zeit $st.LetzterTrim } else { '' })
        punkte   = @($punkte)
        kategorien = @($Global:OrcaKategorien | ForEach-Object { [ordered]@{ name = $_.Name; anzeige = $_.Anzeige; erklaerung = $_.Erklaerung } })
        verlauf  = @($verlauf)
        bekannt  = @($Global:OrcaBekannt | ForEach-Object { [ordered]@{ name = $_.Name; kategorie = $_.Kategorie; art = $_.Art; grund = $_.Grund } })
        bereiche = @($Global:OrcaWaechterBereiche | ForEach-Object { [ordered]@{ name = $_.Name; anzeige = $_.Anzeige; text = $_.Text } })
        waechterAus = @(if ($st) { @($st.WaechterAus | Where-Object { $_ }) })
        neues = @(Get-OrcaNeues -State $st | ForEach-Object {
            [ordered]@{ art = $_.art; anzeige = $_.anzeige; erstlauf = $_.erstlauf; bestand = $_.bestand; fehler = $_.fehler
                        neu = @($_.neu | Select-Object -First 300) ; anzahl = @($_.neu).Count } })
        eigeneSperren = @(Get-OrcaEigeneSperren -State $st | ForEach-Object {
            $jetzt = Get-OrcaSammlerStand -Schluessel $_.Schluessel
            [ordered]@{ schluessel = $_.Schluessel; art = $_.Art; ziel = $_.Ziel; vorher = $_.Vorher; seit = (& $zeit $_.Seit); stand = $jetzt.Stand; da = $jetzt.Da } })
        fremdeRichtlinien = @(Get-OrcaFremdeRichtlinienListe)
        aufgehobeneRichtlinien = @(Get-OrcaAufgehobeneRichtlinien -State $st | ForEach-Object {
            [ordered]@{ schluessel = $_.Schluessel; anzeige = "$($_.Pfad)\$($_.Name)"; seit = (& $zeit $_.Seit) } })
        geraetekennung = (Get-OrcaGuiGeraetekennung)
        apps = (Get-OrcaGuiApps)
        hosts = (Get-OrcaGuiHosts)
        # Katalogtexte deutsch -> englisch; die Oberfläche übersetzt damit, wenn Englisch gewählt ist
        texteEn = $Global:OrcaTexteEN
    }
}

function Get-OrcaGuiGeraetekennung {
    # Liest nur: wo eine echte Gerätekennung liegt und ob die Sperre der
    # Microsoft-Adressen (NET005) steht - ohne sie holt sich Windows sofort
    # eine neue, das Entfernen wäre dann wirkungslos.
    $g = Get-OrcaGdidStand
    $sperre = $false
    try { $sperre = [bool](Get-OrcaHostsAbschnitte)['GDID'].Intakt } catch { }
    return [ordered]@{ echt = [int]$g.Echt; orte = @($g.Orte); sperre = $sperre }
}

function Invoke-OrcaGuiGeraetekennung {
    param([string[]]$Orte = @($Global:OrcaGdidOrte | ForEach-Object { $_.Name }), [bool]$Zwischenspeicher = $true, [bool]$Zugangsdaten = $true)
    $sim = [bool]$Global:OrcaSimulationAktiv
    Write-Progress -Activity 'Gerätekennung' -Status 'Entfernen' -PercentComplete 30
    $r = $null
    try { $r = Invoke-OrcaGdidBereinigung -Orte $Orte -Zwischenspeicher $Zwischenspeicher -Zugangsdaten $Zugangsdaten }
    catch { $r = @{ Erfolg = $false; Grund = $_.Exception.Message; Schritte = @() } }
    Write-Progress -Activity 'Gerätekennung' -Completed
    $punkt = [ordered]@{ id = 'geraetekennung'; richtung = 'ein'; ok = [bool]$r.Erfolg
                         status = $(if ($r.Erfolg) { 'Gesetzt' } else { 'Fehler' }); grund = "$($r.Grund)"; schritte = @($r.Schritte) }
    return [ordered]@{ simulation = $sim; abgebrochen = ''; punkte = @($punkt); vorgaenge = @(Get-OrcaGuiVorgaenge) }
}

function Get-OrcaGuiHosts {
    # Liest nur. Je Abschnitt: Katalogpunkt, ob er steht, alle Namen; dazu die Ausnahmen
    # und wie viele Zeilen die Hosts-Datei mit allen Abschnitten bekäme (gezählt, nicht geschätzt).
    $stand = @{}
    try { $stand = Get-OrcaHostsAbschnitte } catch { }
    $aus = Get-OrcaHostsAusnahmen
    $abschnitte = @(foreach ($ab in $Global:OrcaHostsFolge) {
        $roh = Get-OrcaHostsListe -Abschnitt $ab -Roh
        if (-not $roh.Count) { continue }
        $punkt = @($Global:OrcaEinstellungen | Where-Object { $_.Typ -eq 'HostsBlock' -and [string]$_.Soll -eq $ab -and -not $_.Ausgemustert })[0]
        $doppelt = $ab -in $Global:OrcaHostsDoppelt
        $gesperrt = @($roh | Where-Object { $_ -notin $aus }).Count
        [ordered]@{ name = $ab; punkt = $(if ($punkt) { $punkt.Id } else { '' }); aktiv = [bool]($stand[$ab] -and $stand[$ab].Intakt)
                    doppelt = [bool]$doppelt; eintraege = @($roh); zeilen = $gesperrt * $(if ($doppelt) { 2 } else { 1 }) + 1 }
    })
    $zeilen = 0; foreach ($a in $abschnitte) { $zeilen += $a.zeilen }
    return [ordered]@{ abschnitte = $abschnitte; ausnahmen = @($aus); zeilenAlle = $zeilen + 2 }
}

function Invoke-OrcaGuiHosts {
    # Aktion "hosts": Einträge ausnehmen bzw. wieder sperren. Stehende Abschnitte werden
    # danach mit der neuen Liste neu geschrieben und nachgeprüft (Sicherung wie immer).
    param([string[]]$Ausnehmen = @(), [string[]]$Sperren = @())
    $sim = [bool]$Global:OrcaSimulationAktiv
    if (-not (Get-OrcaState)) {
        return [ordered]@{ simulation = $sim; abgebrochen = 'OrcaShield ist auf diesem Rechner noch nicht eingerichtet. Zuerst Einstellungen anwenden.'; punkte = @(); vorgaenge = @() }
    }
    $bekannt = Get-OrcaHostsAlleNamen
    $punkte = New-Object System.Collections.ArrayList
    foreach ($h in @(@($Ausnehmen) + @($Sperren) | Where-Object { $_ -and $_.ToLower() -notin $bekannt })) {
        [void]$punkte.Add([ordered]@{ id = "hosts:$h"; richtung = ''; ok = $false; status = 'Unbekannt'; grund = 'Steht nicht in der Hosts-Liste von OrcaShield - nicht angefasst' })
    }
    $stand = Get-OrcaHostsAbschnitte
    $aktiv = @($Global:OrcaHostsFolge | Where-Object { $stand[$_].Intakt })
    # Nicht @(Get-OrcaHostsAusnahmen): die Funktion gibt ihre Liste mit "return ," zurück, @() packte sie ein zweites Mal ein
    $bisher = Get-OrcaHostsAusnahmen
    $neu = @(@($bisher) + @($Ausnehmen | ForEach-Object { $_.ToLower() }) | Where-Object { $_ -notin @($Sperren | ForEach-Object { $_.ToLower() }) })
    $gespeichert = Set-OrcaHostsAusnahmen -Namen $neu
    $grund = ''
    if ($gespeichert -and $aktiv.Count) {
        $r = Write-OrcaHosts -Abschnitte $aktiv
        if (-not $r.Erfolg) { $grund = $r.Grund }
    }
    $nach = Get-OrcaHostsAbschnitte
    $alleIntakt = -not @($aktiv | Where-Object { -not $nach[$_].Intakt }).Count
    if (-not $gespeichert) { $grund = 'Zustandsdatei nicht geschrieben - nichts geändert' }
    elseif (-not $alleIntakt -and -not $grund) { $grund = 'Nachprüfung: Hosts-Block entspricht nicht der neuen Liste' }
    foreach ($h in @($Ausnehmen | Where-Object { $_ -and $_.ToLower() -in $bekannt })) { [void]$punkte.Add([ordered]@{ id = "hosts:$h"; richtung = 'aus'; ok = ($gespeichert -and $alleIntakt); status = $(if ($gespeichert -and $alleIntakt) { 'Gesetzt' } else { 'Fehler' }); grund = $grund }) }
    foreach ($h in @($Sperren | Where-Object { $_ -and $_.ToLower() -in $bekannt })) { [void]$punkte.Add([ordered]@{ id = "hosts:$h"; richtung = 'ein'; ok = ($gespeichert -and $alleIntakt); status = $(if ($gespeichert -and $alleIntakt) { 'Gesetzt' } else { 'Fehler' }); grund = $grund }) }
    Write-OrcaLog -Level $(if ($gespeichert -and $alleIntakt) { 'OK' } else { 'FEHLER' }) -Source 'GUI' -Message "Hosts: ausgenommen $($Ausnehmen -join ',') | wieder gesperrt $($Sperren -join ',') | neu geschrieben: $($aktiv -join ',') $grund"
    return [ordered]@{ simulation = $sim; abgebrochen = ''; punkte = @($punkte); vorgaenge = @(Get-OrcaGuiVorgaenge) }
}

function Get-OrcaGuiApps {
    # Ein einziger Paketabruf für alle Apps (Measure-OrcaApps fragt je Name
    # einzeln und braucht dafür ein Vielfaches). Gleiche Trefferregel wie
    # Remove-OrcaApp: Paketname enthält einen der Namen der App.
    $namen = @()
    try { $namen = @(Get-AppxPackage -AllUsers -ErrorAction Stop | ForEach-Object { $_.Name } | Sort-Object -Unique) }
    catch { return [ordered]@{ fehler = $_.Exception.Message; liste = @() } }
    $st = Get-OrcaState
    $entfernt = @(if ($st) { @($st.EntfernteApps) | Where-Object { $_ } })
    $liste = foreach ($app in $Global:OrcaApps) {
        $suche = @(Get-OrcaAppNamen -App $app)
        $treffer = @($namen | Where-Object { $n = $_; @($suche | Where-Object { $n -like "*$_*" }).Count -gt 0 })
        [ordered]@{
            id = $app.Id; anzeige = $app.Anzeige; stufe = $app.Stufe; erklaerung = $app.Erklaerung
            browser = ($app.Warnung -eq 'BROWSER-WARNUNG')
            warnung = $(if ($app.Warnung -and $app.Warnung -ne 'BROWSER-WARNUNG') { $app.Warnung } else { '' })
            installiert = ($treffer.Count -gt 0); pakete = @($treffer)
            entfernt = ($app.Id -in $entfernt); zurueck = ($app.Id -in $entfernt -and $treffer.Count -eq 0 -and $app.Id -ne 'M10')
        }
    }
    $katalogNamen = @($Global:OrcaApps | ForEach-Object { Get-OrcaAppNamen -App $_ })
    $weitere = @()
    try {
        $weitere = @(Get-AppxPackage -AllUsers -ErrorAction Stop | Where-Object { -not $_.IsFramework -and -not $_.IsResourcePackage -and "$($_.SignatureKind)" -in @('Store', 'System') } |
            Sort-Object Name -Unique | Where-Object { $n = $_.Name; -not @($katalogNamen | Where-Object { $n -like "*$_*" }).Count } |
            ForEach-Object { [ordered]@{ name = $_.Name; art = "$($_.SignatureKind)"; entfernbar = (-not $_.NonRemovable); schutz = [bool](Test-OrcaAppGeschuetzt $_.Name) } })
    } catch { }
    return [ordered]@{ fehler = ''; liste = @($liste); weitere = $weitere }
}

function Invoke-OrcaGuiAppsZurueck {
    param([string[]]$Ids = @())
    $sim = [bool]$Global:OrcaSimulationAktiv
    $st = Get-OrcaState
    $familien = @{}
    if ($st -and $st.AppFamilien) { foreach ($p in $st.AppFamilien.PSObject.Properties) { $familien[$p.Name] = @($p.Value) } }
    $punkte = New-Object System.Collections.ArrayList
    $zurueck = New-Object System.Collections.ArrayList
    foreach ($id in @($Ids)) {
        $app = @($Global:OrcaApps | Where-Object { $_.Id -eq $id })[0]
        if (-not $app -or $id -eq 'M10') {
            [void]$punkte.Add([ordered]@{ id = "app:$id"; richtung = 'ein'; ok = $false; status = 'Unbekannt'; grund = $(if ($id -eq 'M10') { 'Edge ist kein Store-Paket - von der Website von Microsoft neu installieren' } else { 'Nicht im App-Katalog - nicht angefasst' }) })
            continue
        }
        # Paketfamilie: beim Entfernen gemerkt, sonst Paketname mit dem Herausgeber von Microsoft
        $pfn = @($familien[$id])[0]
        if (-not $pfn) { $pfn = $(if ($app.Paket -eq 'Clipchamp.Clipchamp') { 'Clipchamp.Clipchamp_yxz26nhyzhsrt' } else { "$($app.Paket)_8wekyb3d8bbwe" }) }
        $ok = $false; $grund = ''
        try {
            Add-AppxPackage -RegisterByFamilyName -MainPackage $pfn -ErrorAction Stop
            $ok = [bool](@(Get-AppxPackage -Name $app.Paket -ErrorAction SilentlyContinue).Count) -or $sim
        } catch { $grund = $_.Exception.Message }
        if ($ok) {
            [void]$zurueck.Add($id)
            [void]$punkte.Add([ordered]@{ id = "app:$id"; richtung = 'ein'; ok = $true; status = 'Gesetzt'; grund = '' })
        } else {
            [void]$punkte.Add([ordered]@{ id = "app:$id"; richtung = 'ein'; ok = $false; status = 'Store'; grund = 'Die Dateien der App sind nicht mehr auf dem Rechner - über den Microsoft Store neu installieren'
                                          store = "ms-windows-store://pdp/?PFN=$pfn" })
        }
        Write-OrcaLog -Level $(if ($ok) { 'OK' } else { 'WARN' }) -Source 'GUI' -Message "App wieder installieren $id ($pfn): $(if ($ok) { 'registriert' } else { "nicht möglich, Store nötig - $grund" })"
    }
    # Nicht mehr als entfernt führen - sonst nähme der Wächter sie beim nächsten Lauf wieder weg
    if ($zurueck.Count -and $st) {
        [void](Set-OrcaStateFeld -Name 'EntfernteApps' -Wert @(@($st.EntfernteApps) | Where-Object { $_ -and $_ -notin $zurueck }))
    }
    return [ordered]@{ simulation = $sim; abgebrochen = ''; punkte = @($punkte); vorgaenge = @(Get-OrcaGuiVorgaenge) }
}

function Invoke-OrcaGuiApps {
    param([string[]]$Ids = @())
    $sim = [bool]$Global:OrcaSimulationAktiv
    $punkte = New-Object System.Collections.ArrayList
    $script:OrcaAppFamilienZuletzt = @{}
    $nr = 0
    foreach ($id in @($Ids)) {
        $nr++
        $app = @($Global:OrcaApps | Where-Object { $_.Id -eq $id })[0]
        if (-not $app) {
            [void]$punkte.Add([ordered]@{ id = "app:$id"; richtung = 'aus'; ok = $false; status = 'Unbekannt'; grund = 'Nicht im App-Katalog - nicht angefasst' })
            continue
        }
        Write-Progress -Activity 'Apps entfernen' -Status $app.Anzeige -PercentComplete ([int](100 * $nr / [Math]::Max(1, @($Ids).Count)))
        try {
            $r = Remove-OrcaApp -App $app
            if ($r.Familien) { $script:OrcaAppFamilienZuletzt[$id] = @($r.Familien) }
            $reste = 0
            if ($r.Entfernt) { $reste = @(Clear-OrcaAppReste -App $app).Count }
            [void]$punkte.Add([ordered]@{ id = "app:$id"; richtung = 'aus'; ok = [bool]$r.Erfolg
                status = $(if ($r.Entfernt) { 'Entfernt' } elseif ($r.Erfolg) { 'NichtVorhanden' } else { 'Fehler' })
                grund = "$($r.Grund)$(if ($reste) { " ($reste Reste entfernt)" })" })
        } catch {
            [void]$punkte.Add([ordered]@{ id = "app:$id"; richtung = 'aus'; ok = $false; status = 'Fehler'; grund = $_.Exception.Message })
            Write-OrcaLog -Level FEHLER -Source 'GUI' -Message "App ${id}: $($_.Exception.Message)"
        }
    }
    Write-Progress -Activity 'Apps entfernen' -Completed
    $neu = @($punkte | Where-Object { $_.status -eq 'Entfernt' } | ForEach-Object { $_.id.Substring(4) })
    $st = Get-OrcaState
    if ($neu.Count -and $st) {
        [void](Set-OrcaStateFeld -Name 'EntfernteApps' -Wert @(@(@($st.EntfernteApps) | Where-Object { $_ }) + $neu | Sort-Object -Unique))
        $fam = [ordered]@{}
        if ($st.AppFamilien) { foreach ($p in $st.AppFamilien.PSObject.Properties) { $fam[$p.Name] = @($p.Value) } }
        foreach ($id in $neu) { if ($script:OrcaAppFamilienZuletzt -and $script:OrcaAppFamilienZuletzt[$id]) { $fam[$id] = @($script:OrcaAppFamilienZuletzt[$id]) } }
        [void](Set-OrcaStateFeld -Name 'AppFamilien' -Wert ([pscustomobject]$fam))
    }
    return [ordered]@{ simulation = $sim; abgebrochen = ''; punkte = @($punkte); vorgaenge = @(Get-OrcaGuiVorgaenge) }
}

# Im Simulationsmodus: was geschrieben worden wäre (für den Abschluss), danach leeren
function Get-OrcaGuiVorgaenge {
    if (-not ($Global:OrcaSimulationAktiv -and $Global:PsimVorgaenge)) { return }
    $v = @($Global:PsimVorgaenge | Where-Object { $_.Art -notin @('ZUSTAND') } | Select-Object -Last 400 |
           ForEach-Object { [ordered]@{ art = $_.Art; ziel = $_.Ziel; wert = $_.Wert } })
    [void]$Global:PsimVorgaenge.Clear()
    $v
}

function Get-OrcaGuiBestaetigung {
    param(
        [string[]]$Ein = @(), [string[]]$Aus = @(),
        [string]$Waechter = '', [string]$Bereinigung = '', [string]$Schattenkopien = '',
        [string[]]$BereicheAus = @(), [string[]]$BereicheAn = @(),
        [string[]]$SchritteAus = @(), [string[]]$SchritteAn = @(),
        [string[]]$Sammler = @(), [string]$SammlerRichtung = '',
        [string[]]$Apps = @(), [switch]$Geraetekennung,
        [string[]]$GdidOrte = @(), [bool]$GdidZwischenspeicher = $true, [bool]$GdidZugangsdaten = $true,
        [string[]]$HostsAusnehmen = @(), [string[]]$HostsSperren = @(),
        [string[]]$AppsZurueck = @(),
        [string[]]$Richtlinien = @(), [string]$RichtlinienRichtung = '',
        [string]$AufnehmenArt = '', [int]$AufnehmenAnzahl = 0, [switch]$AufnehmenAlle,
        [ValidateSet('de', 'en')][string]$Sprache = 'de'
    )
    $zeilen = New-Object System.Collections.ArrayList
    $risiken = New-Object System.Collections.ArrayList
    $en = ($Sprache -eq 'en')
    # Text in der gewählten Sprache: erst deutsch, dann englisch; Katalogtexte über das Wörterbuch
    $sp = { param($de, $eng) if ($en) { $eng } else { $de } }
    $kt = { param($x) if ($en -and $Global:OrcaTexteEN -and $Global:OrcaTexteEN.ContainsKey("$x")) { $Global:OrcaTexteEN["$x"] } else { $x } }
    $katalog = @{}
    foreach ($s in $Global:OrcaEinstellungen) { $katalog[$s.Id] = $s }
    $name = { param($id) if ($katalog.ContainsKey($id)) { "$id  $(& $kt $katalog[$id].Name)" } else { "$id  $(& $sp '(nicht im Katalog, wird nicht angefasst)' '(not in the catalogue, left untouched)')" } }

    foreach ($id in @($Ein | Where-Object { $_ })) {
        [void]$zeilen.Add("$(& $name $id) - $(& $sp 'einschalten' 'turn on')")
        if ($katalog.ContainsKey($id) -and $katalog[$id].SenktSchutz) { [void]$risiken.Add("$(& $name $id) - $(& $sp 'senkt den Schutz des Rechners' 'reduces the protection of the PC')") }
    }
    foreach ($id in @($Aus | Where-Object { $_ })) { [void]$zeilen.Add("$(& $name $id) - $(& $sp 'auf den Ausgangszustand zurück' 'back to the original state')") }

    # Nicht $ein nennen: PowerShell unterscheidet keine Groß-/Kleinschreibung, das wäre der Parameter $Ein
    $umschalten = { param($w) if ($w -eq 'ein') { & $sp 'einschalten' 'turn on' } else { & $sp 'ausschalten' 'turn off' } }
    if ($Waechter)    { [void]$zeilen.Add("$(& $sp 'Wächter' 'Watcher') - $(& $umschalten $Waechter)") }
    if ($Bereinigung) { [void]$zeilen.Add("$(& $sp 'Bereinigung beim Herunterfahren' 'Cleanup at shutdown') - $(& $umschalten $Bereinigung)") }
    if ($Schattenkopien) {
        [void]$zeilen.Add("$(& $sp 'Schattenkopien beim Herunterfahren löschen' 'Delete shadow copies at shutdown') - $(& $umschalten $Schattenkopien)")
        if ($Schattenkopien -eq 'ein') { [void]$risiken.Add((& $sp 'Ältere Dateiversionen und Wiederherstellungspunkte werden bei jedem Herunterfahren endgültig gelöscht' 'Older file versions and restore points are permanently deleted at every shutdown')) }
    }
    $schritt = { param($n) @($Global:OrcaBereinigungsSchritte | Where-Object { $_.Name -eq $n })[0] }
    $endgueltig = @('papierkorb', 'schattenkopien')
    $folgeZeile = { param($s)
        $f = "$(& $kt $s.Anzeige): $(& $kt $s.Folge)"
        if ($s.Name -in $endgueltig) { [void]$risiken.Add($f) } else { [void]$zeilen.Add("   $(& $sp 'Folge' 'Consequence') - $f") } }
    foreach ($n in @($SchritteAus | Where-Object { $_ })) { $s = & $schritt $n; if ($s) { [void]$zeilen.Add("$(& $sp 'Bereinigung' 'Cleanup'): $(& $kt $s.Anzeige) - $(& $sp 'ausschalten' 'turn off')") } }
    foreach ($n in @($SchritteAn | Where-Object { $_ })) { $s = & $schritt $n; if ($s) { [void]$zeilen.Add("$(& $sp 'Bereinigung' 'Cleanup'): $(& $kt $s.Anzeige) - $(& $sp 'einschalten' 'turn on')"); & $folgeZeile $s } }
    if ($Bereinigung -eq 'ein') {
        $st = Get-OrcaState
        foreach ($s in $Global:OrcaBereinigungsSchritte) {
            if ($s.Name -eq 'schattenkopien') { continue }   # eigener Schalter, oben
            $laeuft = ($s.Name -notin @($st.BereinigungAus) -and $s.Name -notin $SchritteAus) -or $s.Name -in $SchritteAn
            if ($laeuft -and $s.Name -notin $SchritteAn) { & $folgeZeile $s }
        }
    }
    $bereich = { param($n) $b = @($Global:OrcaWaechterBereiche | Where-Object { $_.Name -eq $n })[0]; if ($b) { & $kt $b.Anzeige } else { $n } }
    foreach ($n in @($BereicheAus | Where-Object { $_ })) { [void]$zeilen.Add("$(& $sp 'Prüfbereich' 'Check area') $(& $bereich $n) - $(& $sp 'ausschalten' 'turn off')") }
    foreach ($n in @($BereicheAn  | Where-Object { $_ })) { [void]$zeilen.Add("$(& $sp 'Prüfbereich' 'Check area') $(& $bereich $n) - $(& $sp 'einschalten' 'turn on')") }

    foreach ($k in @($Sammler | Where-Object { $_ })) {
        $was = if ($k -like 'dienst:*') { (& $sp 'Dienst ' 'Service ') + $k.Substring(7) } elseif ($k -like 'aufgabe:*') { (& $sp 'Aufgabe ' 'Task ') + $k.Substring(8) } else { $k }
        [void]$zeilen.Add("$was - $(if ($SammlerRichtung -eq 'zurueck') { & $sp 'Abschaltung zurücknehmen' 'undo the switch-off' } else { & $sp 'abschalten' 'turn off' })")
    }

    foreach ($id in @($Apps | Where-Object { $_ })) {
        $app = @($Global:OrcaApps | Where-Object { $_.Id -eq $id })[0]
        if (-not $app) { [void]$zeilen.Add("App $id $(& $sp '(nicht im App-Katalog, wird nicht angefasst)' '(not in the app catalogue, left untouched)')"); continue }
        [void]$zeilen.Add("$(& $sp 'App entfernen' 'Remove app'): $(& $kt $app.Anzeige)")
        if ($app.Warnung -eq 'BROWSER-WARNUNG') { [void]$risiken.Add("$(& $kt $app.Anzeige) - $(& $sp 'ohne anderen Browser gibt es danach keinen Weg mehr ins Internet' 'without another browser there is no way left to go online afterwards')") }
    }
    if (@($Apps | Where-Object { $_ }).Count) { [void]$risiken.Add((& $sp 'Entfernte Apps kommen durch den Rückbau nicht zurück, nur über den Microsoft Store' 'Removed apps do not come back through the rollback, only via the Microsoft Store')) }

    foreach ($k in @($Richtlinien | Where-Object { $_ })) {
        $was = if ($k -like 'pol:*') { ($k.Substring(4) -replace '\|', '\' -replace '=.*$', '') } else { $k }
        [void]$zeilen.Add("$(& $sp 'Richtlinie' 'Policy') $was - $(if ($RichtlinienRichtung -eq 'zurueck') { & $sp 'wieder setzen' 'set again' } else { & $sp 'aufheben' 'lift' })")
    }
    if (@($Richtlinien | Where-Object { $_ }).Count -and $RichtlinienRichtung -ne 'zurueck') {
        [void]$risiken.Add((& $sp 'Aufgehobene Richtlinien können eine Firmenverwaltung oder ein anderes Programm betreffen; Zurücknehmen schreibt sie unverändert zurück' 'Lifted policies may belong to company management or another program; undoing writes them back unchanged'))
    }

    if ($AufnehmenAlle -or $AufnehmenAnzahl -gt 0) {
        $wo = if ($AufnehmenArt) { & $bereich $AufnehmenArt } else { & $sp 'alle Prüfbereiche' 'all check areas' }
        $wieviel = if ($AufnehmenAlle) { & $sp 'alles' 'everything' } else { "$AufnehmenAnzahl $(& $sp 'Einträge' 'entries')" }
        [void]$zeilen.Add("$(& $sp 'Neu Gefundenes als bekannt übernehmen' 'Accept newly found items as known'): $wo ($wieviel)")
        [void]$risiken.Add((& $sp 'Übernommenes meldet der Wächter danach nicht mehr - auch dann nicht, wenn es von Schadsoftware stammt. Übernimm nur, was du kennst.' 'The watcher no longer reports accepted items - not even if they come from malware. Only accept what you recognise.'))
    }

    if ($Geraetekennung) {
        $orte = if (@($GdidOrte | Where-Object { $_ }).Count) { @($GdidOrte | Where-Object { $_ }) } else { @($Global:OrcaGdidOrte | ForEach-Object { $_.Name }) }
        $ortEn = @{ 'dein Profil' = 'your profile'; 'Vorlageprofil' = 'template profile'; 'Systemkonto' = 'system account' }
        foreach ($o in $orte) { [void]$zeilen.Add("$(& $sp 'Gerätekennung entfernen' 'Remove device ID'): $(if ($en -and $ortEn.ContainsKey($o)) { $ortEn[$o] } else { $o })") }
        if ($GdidZwischenspeicher) { [void]$zeilen.Add((& $sp 'Token-Zwischenspeicher leeren' 'Clear the token cache')) }
        if ($GdidZugangsdaten) {
            [void]$zeilen.Add((& $sp 'Gespeicherte Microsoft-Konto-Zugangsdaten löschen' 'Delete stored Microsoft account credentials'))
            [void]$risiken.Add((& $sp 'Gespeicherte Microsoft-Konto-Zugangsdaten werden gelöscht - danach in Office, OneDrive und im Store neu anmelden' 'Stored Microsoft account credentials are deleted - sign in again in Office, OneDrive and the Store afterwards'))
        }
    }
    foreach ($h in @($HostsAusnehmen | Where-Object { $_ })) { [void]$zeilen.Add("Hosts: $h - $(& $sp 'nicht mehr sperren' 'no longer block')") }
    foreach ($h in @($HostsSperren | Where-Object { $_ })) { [void]$zeilen.Add("Hosts: $h - $(& $sp 'wieder sperren' 'block again')") }
    foreach ($id in @($AppsZurueck | Where-Object { $_ })) {
        $app = @($Global:OrcaApps | Where-Object { $_.Id -eq $id })[0]
        [void]$zeilen.Add("$(& $sp 'App wieder installieren' 'Reinstall app'): $(if ($app) { & $kt $app.Anzeige } else { $id })")
    }
    if (@($AppsZurueck | Where-Object { $_ }).Count) { [void]$risiken.Add((& $sp 'Gibt es die App nicht mehr auf dem Rechner, öffnet OrcaShield ihre Seite im Microsoft Store - das ist eine Verbindung zu Microsoft' 'If the app is no longer on the PC, OrcaShield opens its page in the Microsoft Store - that is a connection to Microsoft')) }
    return [ordered]@{ zeilen = @($zeilen); risiken = @($risiken) }
}

function Invoke-OrcaGuiSammler {
    param([Parameter(Mandatory)][string[]]$Schluessel, [ValidateSet('aus', 'zurueck')][string]$Richtung = 'aus')
    $sim = [bool]$Global:OrcaSimulationAktiv
    if (-not (Get-OrcaState)) {
        return [ordered]@{ simulation = $sim; abgebrochen = 'OrcaShield ist auf diesem Rechner noch nicht eingerichtet. Zuerst Einstellungen anwenden.'; punkte = @(); vorgaenge = @() }
    }
    $punkte = New-Object System.Collections.ArrayList
    foreach ($s in $Schluessel) {
        $r = if ($Richtung -eq 'aus') { Disable-OrcaNeuerSammler -Schluessel $s } else { Restore-OrcaNeuerSammler -Schluessel $s }
        [void]$punkte.Add([ordered]@{ id = "sammler:$s"; richtung = $Richtung; ok = [bool]$r.Erfolg; status = "$($r.Status)"; grund = "$($r.Grund)" })
    }
    $vorgaenge = @()
    if ($sim -and $Global:PsimVorgaenge) {
        $vorgaenge = @($Global:PsimVorgaenge | Where-Object { $_.Art -notin @('ZUSTAND') } | Select-Object -Last 400 |
                       ForEach-Object { [ordered]@{ art = $_.Art; ziel = $_.Ziel; wert = $_.Wert } })
        [void]$Global:PsimVorgaenge.Clear()
    }
    return [ordered]@{ simulation = $sim; abgebrochen = ''; punkte = @($punkte); vorgaenge = $vorgaenge }
}

function Invoke-OrcaGuiRichtlinie {
    param([Parameter(Mandatory)][string[]]$Schluessel, [ValidateSet('aus', 'zurueck')][string]$Richtung = 'aus')
    $sim = [bool]$Global:OrcaSimulationAktiv
    if (-not (Get-OrcaState)) {
        return [ordered]@{ simulation = $sim; abgebrochen = 'OrcaShield ist auf diesem Rechner noch nicht eingerichtet. Zuerst Einstellungen anwenden.'; punkte = @(); vorgaenge = @() }
    }
    $punkte = New-Object System.Collections.ArrayList
    foreach ($s in $Schluessel) {
        $r = if ($Richtung -eq 'aus') { Remove-OrcaFremdeRichtlinie -Schluessel $s } else { Restore-OrcaFremdeRichtlinie -Schluessel $s }
        [void]$punkte.Add([ordered]@{ id = "richtlinie:$s"; richtung = $Richtung; ok = [bool]$r.Erfolg; status = "$($r.Status)"; grund = "$($r.Grund)" })
    }
    return [ordered]@{ simulation = $sim; abgebrochen = ''; punkte = @($punkte); vorgaenge = @(Get-OrcaGuiVorgaenge) }
}

function Invoke-OrcaGuiAufnehmen {
    param([string]$Art = '', [string[]]$Schluessel = @(), [switch]$Alle)
    $sim = [bool]$Global:OrcaSimulationAktiv
    if (-not (Get-OrcaState)) {
        return [ordered]@{ simulation = $sim; abgebrochen = 'OrcaShield ist auf diesem Rechner noch nicht eingerichtet. Zuerst Einstellungen anwenden.'; punkte = @() }
    }
    $arten = if ($Art) { @($Art) } else { @($Global:OrcaNeuesArten | ForEach-Object { $_.Name }) }
    $punkte = New-Object System.Collections.ArrayList
    foreach ($a in $arten) {
        $r = if ($Alle) { Add-OrcaBekannt -Art $a -Alle } else { Add-OrcaBekannt -Art $a -Schluessel $Schluessel }
        [void]$punkte.Add([ordered]@{ id = "neues:$a"; richtung = 'ein'; ok = [bool]$r.Erfolg; status = $(if ($r.Erfolg) { 'Gesetzt' } else { 'Fehler' }); grund = "$($r.Grund)"; aufgenommen = [int]$r.Aufgenommen })
        Write-OrcaLog -Level $(if ($r.Erfolg) { 'OK' } else { 'FEHLER' }) -Source 'GUI' -Message "Neues aufgenommen ($a): $($r.Aufgenommen)$(if ($r.Grund) { ' - ' + $r.Grund })"
    }
    return [ordered]@{ simulation = $sim; abgebrochen = ''; punkte = @($punkte) }
}

function Invoke-OrcaGuiAutomatik {
    param(
        [ValidateSet('', 'ein', 'aus')][string]$Waechter = '',
        [ValidateSet('', 'ein', 'aus')][string]$Bereinigung = '',
        [ValidateSet('', 'ein', 'aus')][string]$Schattenkopien = '',
        [string[]]$BereicheAus = @(),
        [string[]]$BereicheAn = @(),
        [string[]]$SchritteAus = @(),
        [string[]]$SchritteAn = @()
    )
    $sim = [bool]$Global:OrcaSimulationAktiv
    $ergebnis = New-Object System.Collections.ArrayList
    $neu = { param($id, $richtung, $ok, $status, $grund) [void]$ergebnis.Add([ordered]@{ id = $id; richtung = $richtung; ok = [bool]$ok; status = $status; grund = "$grund" }) }

    $st = Get-OrcaState
    if (-not $st) {
        return [ordered]@{ simulation = $sim; abgebrochen = 'OrcaShield ist auf diesem Rechner noch nicht eingerichtet. Zuerst Einstellungen anwenden - dann lassen sich Wächter und Bereinigung einschalten.'; punkte = @() }
    }

    # --- Prüfbereiche
    $bekannt = @($Global:OrcaWaechterBereiche | ForEach-Object { $_.Name })
    $falsch = @(@($BereicheAus) + @($BereicheAn) | Where-Object { $_ -and $_ -notin $bekannt })
    foreach ($f in $falsch) { & $neu "bereich:$f" '' $false 'Unbekannt' 'Kein Prüfbereich des Wächters - nicht angefasst' }
    $aus = @($BereicheAus | Where-Object { $_ -in $bekannt }); $an = @($BereicheAn | Where-Object { $_ -in $bekannt })
    if ($aus.Count -or $an.Count) {
        Write-Progress -Activity 'Automatik' -Status 'Prüfbereiche des Wächters' -PercentComplete 10
        $bisher = @($st.WaechterAus | Where-Object { $_ })
        $soll = @(@($bisher) + $aus | Where-Object { $_ -notin $an } | Sort-Object -Unique)
        $gespeichert = Set-OrcaStateFeld -Name 'WaechterAus' -Wert $soll
        $jetzt = @((Get-OrcaState).WaechterAus | Where-Object { $_ })
        foreach ($n in $aus) { $ok = ($gespeichert -and $n -in $jetzt); & $neu "bereich:$n" 'aus' $ok $(if ($ok) { 'Gesetzt' } else { 'Fehler' }) $(if ($ok) { '' } else { 'Zustandsdatei nicht geschrieben' }) }
        foreach ($n in $an)  { $ok = ($gespeichert -and $n -notin $jetzt); & $neu "bereich:$n" 'ein' $ok $(if ($ok) { 'Gesetzt' } else { 'Fehler' }) $(if ($ok) { '' } else { 'Zustandsdatei nicht geschrieben' }) }
        Write-OrcaLog -Level OK -Source 'GUI' -Message "Wächter-Bereiche: aus $($aus -join ',') | ein $($an -join ',') -> abgeschaltet: $($jetzt -join ',')"
    }

    # --- Wächter (Anmelde-Aufgabe)
    if ($Waechter) {
        Write-Progress -Activity 'Automatik' -Status 'Wächter' -PercentComplete 40
        try {
            $a = Get-OrcaWaechterAufgabe
            if ($Waechter -eq 'ein') {
                if ($a.Da) { Enable-ScheduledTask -TaskPath '\' -TaskName $Global:OrcaAufgabeWaechter -ErrorAction Stop | Out-Null }
                else {
                    $r = Register-OrcaWaechterAufgabe -Konto "$env:USERDOMAIN\$env:USERNAME"
                    if (-not $r.Erfolg) { throw $r.Grund }
                }
            } elseif ($a.Da) {
                Disable-ScheduledTask -TaskPath '\' -TaskName $Global:OrcaAufgabeWaechter -ErrorAction Stop | Out-Null
            }
            $n = Get-OrcaWaechterAufgabe
            $ok = if ($Waechter -eq 'ein') { $n.Da -and $n.Aktiv } else { -not $n.Aktiv }
            & $neu 'waechter' $Waechter $ok $(if ($ok) { 'Gesetzt' } else { 'Offen' }) $(if ($ok) { '' } else { 'Nachprüfung: Aufgabe ' + $(if ($n.Da) { if ($n.Aktiv) { 'weiterhin eingeschaltet' } else { 'weiterhin ausgeschaltet' } } else { 'nicht vorhanden' }) })
            Write-OrcaLog -Level $(if ($ok) { 'OK' } else { 'FEHLER' }) -Source 'GUI' -Message "Wächter $Waechter - $(if ($ok) { 'nachgeprüft' } else { 'Nachprüfung fehlgeschlagen' })"
        } catch {
            & $neu 'waechter' $Waechter $false 'Fehler' $_.Exception.Message
            Write-OrcaLog -Level FEHLER -Source 'GUI' -Message "Wächter $Waechter fehlgeschlagen: $($_.Exception.Message)"
        }
    }

    # --- Bereinigung beim Herunterfahren
    if ($Bereinigung) {
        Write-Progress -Activity 'Automatik' -Status 'Bereinigung beim Herunterfahren' -PercentComplete 70
        try {
            if ($Bereinigung -eq 'ein') {
                [void](Set-OrcaStateFeld -Name 'BereinigungAktiv' -Wert $true)
                $r = Register-OrcaShutdownSkript -Quelle (Join-Path $Global:OrcaSkripte 'Orca-Waechter-Shutdown.ps1')
                if (-not $r.Erfolg) { throw $r.Grund }
                $ok = [bool]$r.Uebernommen
                & $neu 'herunterfahren' 'ein' $ok $(if ($ok) { 'Gesetzt' } else { 'Offen' }) $(if ($ok) { '' } else { "eingetragen, aber von Windows noch nicht übernommen: $($r.Grund)" })
            } else {
                $r = Unregister-OrcaShutdownSkript
                if (-not $r.Erfolg) { throw $r.Grund }
                [void](Set-OrcaStateFeld -Name 'BereinigungAktiv' -Wert $false)
                $reg = Get-OrcaShutdownRegistrierung
                $ok = -not $reg.Datei -and -not $reg.IniZeile
                & $neu 'herunterfahren' 'aus' $ok $(if ($ok) { 'Gesetzt' } else { 'Offen' }) $(if ($ok) { '' } else { 'Nachprüfung: Eintrag noch vorhanden' })
            }
            Write-OrcaLog -Level OK -Source 'GUI' -Message "Bereinigung beim Herunterfahren $Bereinigung"
        } catch {
            & $neu 'herunterfahren' $Bereinigung $false 'Fehler' $_.Exception.Message
            Write-OrcaLog -Level FEHLER -Source 'GUI' -Message "Bereinigung $Bereinigung fehlgeschlagen: $($_.Exception.Message)"
        }
    }

    $schrittNamen = @($Global:OrcaBereinigungsSchritte | Where-Object { $_.Name -ne 'schattenkopien' } | ForEach-Object { $_.Name })
    foreach ($f in @(@($SchritteAus) + @($SchritteAn) | Where-Object { $_ -and $_ -notin $schrittNamen })) { & $neu "schritt:$f" '' $false 'Unbekannt' 'Kein Schritt der Bereinigung - nicht angefasst' }
    $sAus = @($SchritteAus | Where-Object { $_ -in $schrittNamen }); $sAn = @($SchritteAn | Where-Object { $_ -in $schrittNamen })
    if ($sAus.Count -or $sAn.Count) {
        $bisher = @((Get-OrcaState).BereinigungAus | Where-Object { $_ })
        $soll = @(@($bisher) + $sAus | Where-Object { $_ -notin $sAn } | Sort-Object -Unique)
        $gespeichert = Set-OrcaStateFeld -Name 'BereinigungAus' -Wert $soll
        $jetzt = @((Get-OrcaState).BereinigungAus | Where-Object { $_ })
        foreach ($n in $sAus) { $ok = ($gespeichert -and $n -in $jetzt); & $neu "schritt:$n" 'aus' $ok $(if ($ok) { 'Gesetzt' } else { 'Fehler' }) $(if ($ok) { '' } else { 'Zustandsdatei nicht geschrieben' }) }
        foreach ($n in $sAn)  { $ok = ($gespeichert -and $n -notin $jetzt); & $neu "schritt:$n" 'ein' $ok $(if ($ok) { 'Gesetzt' } else { 'Fehler' }) $(if ($ok) { '' } else { 'Zustandsdatei nicht geschrieben' }) }
        if ('auslagerung' -in $sAus) {
            $mm = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
            if ([int](Get-OrcaRegWert -Pfad $mm -Name 'ClearPageFileAtShutdown') -eq 1) { [void](Set-OrcaRegWert -Pfad $mm -Name 'ClearPageFileAtShutdown' -Wert 0) }
        }
        Write-OrcaLog -Level OK -Source 'GUI' -Message "Bereinigung, Schritte aus: $($sAus -join ',') | ein: $($sAn -join ',') -> abgeschaltet: $($jetzt -join ',')"
    }

    if ($Schattenkopien) {
        $gespeichert = Set-OrcaStateFeld -Name 'SchattenkopienLoeschen' -Wert ($Schattenkopien -eq 'ein')
        $ok = $gespeichert -and ([bool](Get-OrcaState).SchattenkopienLoeschen -eq ($Schattenkopien -eq 'ein'))
        & $neu 'schattenkopien' $Schattenkopien $ok $(if ($ok) { 'Gesetzt' } else { 'Fehler' }) $(if ($ok) { '' } else { 'Zustandsdatei nicht geschrieben' })
        Write-OrcaLog -Level $(if ($ok) { 'OK' } else { 'FEHLER' }) -Source 'GUI' -Message "Schattenkopien beim Herunterfahren löschen: $Schattenkopien"
    }
    Write-Progress -Activity 'Automatik' -Completed

    $vorgaenge = @()
    if ($sim -and $Global:PsimVorgaenge) {
        $vorgaenge = @($Global:PsimVorgaenge | Where-Object { $_.Art -notin @('ZUSTAND') } | Select-Object -Last 400 |
                       ForEach-Object { [ordered]@{ art = $_.Art; ziel = $_.Ziel; wert = $_.Wert } })
        [void]$Global:PsimVorgaenge.Clear()
    }
    return [ordered]@{ simulation = $sim; abgebrochen = ''; punkte = @($ergebnis); vorgaenge = $vorgaenge }
}

function ConvertTo-OrcaGuiJson {
    # Kompaktes JSON für die Oberfläche (Tiefe reicht für basis/benoetigtVon)
    param([Parameter(Mandatory)]$Daten)
    return ($Daten | ConvertTo-Json -Depth 6 -Compress)
}

function Invoke-OrcaGuiAnwenden {
    param(
        [string[]]$Ein = @(),
        [string[]]$Aus = @()
    )
    $katalog = @{}
    foreach ($s in $Global:OrcaEinstellungen) { if (-not $s.Ausgemustert) { $katalog[$s.Id] = $s } }

    $auftrag = New-Object System.Collections.ArrayList
    foreach ($id in @($Ein)) { if ($id) { [void]$auftrag.Add(@{ Id = [string]$id; Richtung = 'ein' }) } }
    foreach ($id in @($Aus)) { if ($id) { [void]$auftrag.Add(@{ Id = [string]$id; Richtung = 'aus' }) } }
    $ergebnis = New-Object System.Collections.ArrayList

    # Ausgangszustand bereichsweise sichern, damit der Fortschritt sichtbar ist
    # (beim ersten Mal wird jeder Punkt einmal gemessen; danach nur neue Punkte).
    $gruppen = @($katalog.Values | Group-Object Kategorie)
    $g = 0
    $bl = @{ Erfolg = $true; Grund = '' }
    foreach ($gr in $gruppen) {
        $g++
        $anzeige = @($Global:OrcaKategorien | Where-Object { $_.Name -eq $gr.Name } | ForEach-Object { $_.Anzeige })[0]
        if (-not $anzeige) { $anzeige = $gr.Name }
        Write-Progress -Activity 'Anwenden' -Status "Ausgangszustand sichern: $anzeige" `
            -PercentComplete ([int](40 * $g / [Math]::Max(1, $gruppen.Count)))
        $bl = Save-OrcaBaseline -Settings @($gr.Group) -Leise
        if (-not $bl.Erfolg) { break }
    }
    if (-not $bl.Erfolg) {
        Write-OrcaLog -Level FEHLER -Source 'GUI' -Message "Anwenden abgebrochen: Ausgangszustand nicht gesichert ($($bl.Grund))"
        return [ordered]@{ simulation = [bool]$Global:OrcaSimulationAktiv; abgebrochen = "Der Ausgangszustand ließ sich nicht sichern: $($bl.Grund). Es wurde nichts geändert."; punkte = @(); vorgaenge = @() }
    }

    Write-Progress -Activity 'Anwenden' -Status 'Registry-Sicherung' -PercentComplete 42
    $vorhanden = @(Get-ChildItem -LiteralPath $Global:OrcaBackup -Directory -Filter 'Registry-Sicherung_*' -ErrorAction SilentlyContinue)
    if ($vorhanden.Count -eq 0) {
        $sich = New-OrcaRegistryBackup
        if (-not $sich.Erfolg) {
            Write-OrcaLog -Level FEHLER -Source 'GUI' -Message "Anwenden abgebrochen: Registry-Sicherung unvollständig ($($sich.Ok) gesichert, $($sich.Fehler) fehlgeschlagen) $($sich.Grund)"
            if ($sich.Pfad -and (Test-Path -LiteralPath $sich.Pfad)) {
                Move-Item -LiteralPath $sich.Pfad -Destination (Join-Path $Global:OrcaBackup ('Unvollstaendig_' + (Split-Path $sich.Pfad -Leaf))) -ErrorAction SilentlyContinue
            }
            return [ordered]@{ simulation = [bool]$Global:OrcaSimulationAktiv; abgebrochen = "Die Registry-Sicherung vor dem ersten Anwenden ist unvollständig ($($sich.Fehler) Zweige nicht gesichert). Es wurde nichts geändert."; punkte = @(); vorgaenge = @() }
        }
    }

    $nr = 0
    foreach ($a in $auftrag) {
        $nr++
        $s = $katalog[$a.Id]
        $name = if ($s) { $s.Name } else { $a.Id }
        Write-Progress -Activity 'Anwenden' -Status $name -CurrentOperation $a.Id -PercentComplete ([int](45 + 55 * $nr / [Math]::Max(1, $auftrag.Count)))
        if (-not $s -or $a.Id -notmatch '^[A-Z]{2,4}\d{3}$') {
            [void]$ergebnis.Add([ordered]@{ id = $a.Id; richtung = $a.Richtung; ok = $false; status = 'Unbekannt'; grund = 'Nicht im Katalog - nicht angefasst' })
            Write-OrcaLog -Level WARN -Source 'GUI' -Message "Unbekannte Kennung abgewiesen: $($a.Id)"
            continue
        }
        try {
            $r = if ($a.Richtung -eq 'ein') { Set-OrcaPunktAktiv -Setting $s } else { Reset-OrcaPunkt -Setting $s }
            [void]$ergebnis.Add([ordered]@{ id = $s.Id; richtung = $a.Richtung; ok = [bool]$r.Erfolg; status = "$($r.Status)"; grund = "$($r.Grund)" })
            $stufe = if ($r.Erfolg) { 'OK' } else { 'FEHLER' }
            Write-OrcaLog -Level $stufe -Source 'GUI' -Message ("{0} {1}: {2} {3}" -f $s.Id, $(if ($a.Richtung -eq 'ein') { 'aktiviert' } else { 'zurückgesetzt' }), $r.Status, $r.Grund)
        } catch {
            [void]$ergebnis.Add([ordered]@{ id = $s.Id; richtung = $a.Richtung; ok = $false; status = 'Fehler'; grund = $_.Exception.Message })
            Write-OrcaLog -Level FEHLER -Source 'GUI' -Message "$($s.Id): $($_.Exception.Message)"
        }
    }
    Write-Progress -Activity 'Anwenden' -Completed

    $vorgaenge = @()
    if ($Global:OrcaSimulationAktiv -and $Global:PsimVorgaenge) {
        $vorgaenge = @($Global:PsimVorgaenge | Where-Object { $_.Art -notin @('ZUSTAND') } | Select-Object -Last 400 |
                       ForEach-Object { [ordered]@{ art = $_.Art; ziel = $_.Ziel; wert = $_.Wert } })
        [void]$Global:PsimVorgaenge.Clear()
    }
    return [ordered]@{ simulation = [bool]$Global:OrcaSimulationAktiv; abgebrochen = ''; punkte = @($ergebnis); vorgaenge = $vorgaenge }
}
