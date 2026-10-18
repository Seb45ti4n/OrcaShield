# ==============================================================
#  OrcaShield - Orca-Engine.ps1
#  Ausführungs-Engine: misst, setzt, prüft nach.
#  Wird vom Installer, von beiden Wächtern und vom Rückbau
#  verwendet.
#
#  DAS PRINZIP DIESER DATEI
#  ------------------------
#  Messen, dann handeln. Drei Zeitpunkte:
#
#   VORHER   Get-OrcaIstRoh liest den tatsächlichen Zustand.
#            Das Ergebnis geht in orca-baseline.json, bevor der
#            erste Wert geschrieben wird. Der Rückbau nimmt
#            später diese Messung - nicht den im Katalog
#            vermuteten Standardwert.
#
#   NACHHER  Set-OrcaSetting liest nach dem Schreiben erneut und
#            meldet Erfolg nur, wenn der Wert wirklich dort steht
#            - mit dem richtigen Datentyp.
#
#   DAUERND  Wo Windows den WIRKSAMEN Zustand preisgibt statt nur
#            den gewünschten Wert, wird der gelesen: Defender
#            über Get-MpComputerStatus, VBS über
#            Win32_DeviceGuard.
#
#  BENUTZERKONTEXT
#  ---------------
#  Alle Funktionen nehmen einen optionalen Parameter -Sid.
#  Ist er gesetzt, werden HKCU-Pfade auf HKEY_USERS\<SID>
#  umgerechnet. Das braucht ein SYSTEM-Prozess, der an das
#  Profil eines echten Benutzers muss.
# ==============================================================

# ==============================================================
#  TEIL 1 - MESSEN
# ==============================================================

function Get-OrcaIstRoh {
    param(
        [Parameter(Mandatory)]$Setting,
        [string]$Sid = ''
    )

    $roh = @{
        Typ = $Setting.Typ; Vorhanden = $false; SchluesselDa = $false
        Wert = $null; RegTyp = $null; Text = ''; Fehler = ''
    }

    try {
        switch ($Setting.Typ) {

            { $_ -in @('Registry','Autologger','Autostart','StartupApproved') } {
                $pfad = Resolve-OrcaRegPfad -Pfad $Setting.Pfad -Sid $Sid
                $r = Get-OrcaRegWertUndTyp -Pfad $pfad -Name $Setting.Wert
                $roh.SchluesselDa = $r.SchluesselDa
                $roh.Vorhanden    = $r.WertDa
                $roh.Wert         = $r.Wert
                $roh.RegTyp       = $r.Typ
                $roh.Text         = if ($r.WertDa -and $Setting.Typ -eq 'StartupApproved') {
                                        if (Test-OrcaAutostartAus -Wert $r.Wert) { 'im Autostart abgeschaltet' } else { 'im Autostart eingeschaltet' }
                                    }
                                    elseif ($r.WertDa) { "$($r.Wert) ($($r.Typ))" }
                                    elseif ($r.SchluesselDa) { '(Wert nicht gesetzt)' }
                                    else { '(Schlüssel nicht vorhanden)' }
                return $roh
            }

            'Dns' {
                $stand = Get-OrcaDnsStand -Soll $Setting.Soll
                $roh.Vorhanden = ($stand.Adapter.Count -gt 0)
                $roh.Wert = $stand
                $roh.Text = $stand.Text
                return $roh
            }

            'HostsBlock' {
                $ab = (Get-OrcaHostsAbschnitte)[[string]$Setting.Soll]
                $roh.Vorhanden = $true
                $roh.Wert = @{ Intakt = $ab.Intakt; Anzahl = $ab.Anzahl }
                $roh.Text = if ($ab.Intakt) { "im OrcaShield-Block ($($ab.Soll) Adressen)" } elseif ($ab.Anzahl -gt 0) { "unvollständig ($($ab.Anzahl) von $($ab.Soll))" } else { 'nicht im OrcaShield-Block' }
                return $roh
            }

            'Firewallregel' {
                $r = Get-NetFirewallRule -DisplayName $Setting.Wert -ErrorAction SilentlyContinue | Select-Object -First 1
                $roh.Vorhanden = [bool]$r
                $aktiv = ($r -and [string]$r.Enabled -eq 'True' -and [string]$r.Action -eq 'Block' -and [string]$r.Direction -eq 'Outbound')
                $roh.Wert = $aktiv
                $roh.Text = if ($aktiv) { 'Regel aktiv' } elseif ($r) { 'Regel vorhanden, aber nicht wirksam' } else { 'keine Regel' }
                return $roh
            }

            'Computerschutz' {
                $cs = Get-OrcaComputerschutz
                $roh.Vorhanden = $true
                $roh.Wert = @{ An = $cs.An; Kopien = $cs.Kopien }
                $roh.Text = $cs.Text
                return $roh
            }

            'SchluesselWeg' {
                # Soll: Liste von Schluesseln, die NICHT existieren sollen
                $roh.Vorhanden = $true
                $roh.Wert = @(@($Setting.Soll) | Where-Object { Test-OrcaRegSchluessel -Pfad $_ })
                $roh.Text = if (@($roh.Wert).Count -gt 0) { "vorhanden: $(@($roh.Wert).Count) von $(@($Setting.Soll).Count)" } else { 'entfernt' }
                return $roh
            }

            'Indexsperre' {
                $k = Get-OrcaRegSchluessel -Pfad $Setting.Pfad
                $roh.SchluesselDa = $k.Da
                $roh.Vorhanden = $true
                $gesperrt = @()
                foreach ($n in $k.Werte.Keys) {
                    if ($n -match '^file:///([A-Za-z]):\\\*$') { $gesperrt += $matches[1].ToUpper() }
                }
                $roh.Wert = @($gesperrt | Sort-Object -Unique)
                $roh.Text = if ($gesperrt.Count -gt 0) { "gesperrt: $(@($roh.Wert) -join ' ')" } else { 'keine Laufwerke gesperrt' }
                return $roh
            }

            'Dienst' {
                $svc = Get-Service -Name $Setting.Wert -ErrorAction SilentlyContinue
                if (-not $svc) { $roh.Text = 'nicht vorhanden'; return $roh }
                $roh.Vorhanden = $true
                $start = (Get-CimInstance -ClassName Win32_Service -Filter "Name='$($Setting.Wert)'" -ErrorAction SilentlyContinue).StartMode
                $roh.Wert = $start
                $roh.Text = "Startmodus $start"
                return $roh
            }

            'Aufgabe' {
                $pfad = Split-Path $Setting.Wert -Parent
                $name = Split-Path $Setting.Wert -Leaf
                if (-not $pfad.EndsWith('\')) { $pfad += '\' }
                $task = Get-ScheduledTask -TaskPath $pfad -TaskName $name -ErrorAction SilentlyContinue
                if (-not $task) { $roh.Text = 'nicht vorhanden'; return $roh }
                $roh.Vorhanden = $true
                $roh.Wert = [string]$task.State
                $roh.Text = "Zustand $($task.State)"
                return $roh
            }

            'Feature' {
                $f = Get-WindowsOptionalFeature -Online -FeatureName $Setting.Wert -ErrorAction SilentlyContinue
                if (-not $f) { $roh.Text = 'nicht vorhanden'; return $roh }
                $roh.Vorhanden = $true
                $roh.Wert = [string]$f.State
                $roh.Text = "Funktion $($f.State)"
                return $roh
            }

            'NetBios' {
                $basis = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces'
                if (-not (Test-Path $basis)) { $roh.Text = 'keine Schnittstellen'; return $roh }
                $roh.Vorhanden = $true
                $offen = 0; $gesamt = 0; $offenGuids = @()
                foreach ($k in (Get-ChildItem -Path $basis -ErrorAction SilentlyContinue)) {
                    $gesamt++
                    $v = Get-OrcaRegWert -Pfad $k.PSPath -Name 'NetbiosOptions'
                    if ($v -ne 2) { $offen++; $offenGuids += ($k.PSChildName -replace '^Tcpip_','') }
                }
                $namen = @()
                if ($offenGuids.Count -gt 0) {
                    $karten = @{}
                    try {
                        foreach ($a in @(Get-NetAdapter -IncludeHidden -ErrorAction Stop)) { $karten[[string]$a.InterfaceGuid] = [string]$a.Name }
                    } catch { }
                    foreach ($g in $offenGuids) { $namen += $(if ($karten.ContainsKey($g)) { $karten[$g] } else { $g }) }
                }
                $roh.Wert = @{ Offen = $offen; Gesamt = $gesamt }
                $roh.Text = "$offen von $gesamt Schnittstellen offen" + $(if ($namen.Count -gt 0) { " ($($namen -join ', '))" } else { '' })
                return $roh
            }

            'Hypervisor' {
                $aus = (bcdedit /enum '{current}' 2>&1 | Out-String)
                $m = [regex]::Match($aus, '(?im)^\s*hypervisorlaunchtype\s+(\S+)')
                if ($m.Success) {
                    $roh.Vorhanden = $true
                    $roh.Wert = $m.Groups[1].Value
                    $roh.Text = $m.Groups[1].Value
                } else {
                    $roh.Vorhanden = $false
                    $roh.Wert = 'Auto'
                    $roh.Text = 'Auto (nicht ausdrücklich gesetzt)'
                }
                return $roh
            }

            'DeviceGuard' {
                try {
                    $dg = Get-CimInstance -ClassName Win32_DeviceGuard `
                            -Namespace 'root\Microsoft\Windows\DeviceGuard' -ErrorAction Stop
                } catch {
                    $roh.Text = 'nicht vorhanden'; return $roh
                }
                if (-not $dg) { $roh.Text = 'nicht vorhanden'; return $roh }
                $roh.Vorhanden = $true
                $status = [int]$dg.VirtualizationBasedSecurityStatus
                $roh.Wert = $status
                $roh.Text = switch ($status) {
                    0 { 'aus' }
                    1 { 'eingerichtet, läuft nicht' }
                    2 { 'laeuft' }
                    default { "unbekannt ($status)" }
                }
                return $roh
            }

            default {
                $roh.Fehler = "Unbekannter Typ: $($Setting.Typ)"
                return $roh
            }
        }
    }
    catch {
        $roh.Fehler = $_.Exception.Message
        return $roh
    }
}

# --------------------------------------------------------------
#  WIRKUNGSPRÜFUNG
#  Für die Handvoll Punkte, bei denen der Registrywert und die
#  Realität auseinanderfallen können. Rückgabe:
#    @{ Ermittelbar; Erfüllt; Text }
# --------------------------------------------------------------
function Get-OrcaWirkung {
    param([Parameter(Mandatory)]$Setting)

    $leer = @{ Ermittelbar = $false; Erfuellt = $false; Text = 'nicht ermittelbar' }
    if ([string]::IsNullOrWhiteSpace($Setting.Wirkung)) { return $leer }

    try {
        switch ($Setting.Wirkung) {

            'Defender-MAPS' {
                $st = Get-MpComputerStatus -ErrorAction Stop
                # MAPSReporting: 0 = aus, 1 = einfach, 2 = erweitert
                $ist = [int]$st.MAPSReporting
                return @{ Ermittelbar = $true; Erfuellt = ($ist -eq 0)
                          Text = "MAPS-Meldungen: $ist" }
            }

            'Defender-Samples' {
                $st = Get-MpComputerStatus -ErrorAction Stop
                # SubmitSamplesConsent: 2 = niemals senden
                $ist = [int]$st.SubmitSamplesConsent
                return @{ Ermittelbar = $true; Erfuellt = ($ist -eq 2)
                          Text = "Dateiübermittlung: $ist" }
            }

            'DeviceGuard' {
                $roh = Get-OrcaIstRoh -Setting $Setting
                if (-not $roh.Vorhanden) { return $leer }
                $laeuft = ([int]$roh.Wert -eq 2)
                $sollLaeuft = ([int]$Setting.Soll -eq 2)
                return @{ Ermittelbar = $true; Erfuellt = ($laeuft -eq $sollLaeuft)
                          Text = $roh.Text }
            }

            default { return $leer }
        }
    }
    catch {
        return @{ Ermittelbar = $false; Erfuellt = $false; Text = "nicht ermittelbar: $($_.Exception.Message)" }
    }
}

function Test-OrcaSetting {
    param(
        [Parameter(Mandatory)]$Setting,
        [string]$Sid = ''
    )

    $anw = Test-OrcaAnwendbar -Setting $Setting -Sid $Sid
    if (-not $anw.Anwendbar) {
        return @{ Status = 'NichtAnwendbar'; Erfuellt = $true
                  Ist = 'nicht anwendbar'; Grund = $anw.Grund }
    }

    $roh = Get-OrcaIstRoh -Setting $Setting -Sid $Sid
    if ($roh.Fehler) {
        return @{ Status = 'Fehler'; Erfuellt = $false; Ist = $null; Grund = $roh.Fehler }
    }

    # Wo es eine Wirkungsprüfung gibt, hat sie Vorrang vor dem
    # bloßen Registrywert.
    if ($Setting.Wirkung) {
        $w = Get-OrcaWirkung -Setting $Setting
        if ($w.Ermittelbar) {
            return @{ Status = $(if ($w.Erfuellt) { 'Erfuellt' } else { 'Abweichend' })
                      Erfuellt = $w.Erfuellt; Ist = $w.Text; Grund = '' }
        }
    }

    switch ($Setting.Typ) {

        { $_ -in @('Registry','Autologger') } {
            if (-not $roh.SchluesselDa -and $Setting.NurWennVorhanden) {
                return @{ Status = 'NichtVorhanden'; Erfuellt = $true
                          Ist = $roh.Text; Grund = 'Registrierungsschlüssel auf diesem System nicht vorhanden' }
            }
            if (-not $roh.Vorhanden) {
                return @{ Status = 'Abweichend'; Erfuellt = $false; Ist = $roh.Text; Grund = '' }
            }
            $passt = Test-OrcaWertGleich -Ist $roh.Wert -IstTyp $roh.RegTyp `
                        -Soll $Setting.Soll -SollTyp $Setting.RegTyp

            # Manche Punkte haben mehr als einen zulässigen Wert,
            # weil ein anderer Stand strenger ist als der eigene
            # Sollwert. Ihn zu überschreiben hieße lockern - genau
            # das darf ein Härtungswerkzeug nicht tun.
            $grund = ''
            if (-not $passt -and @($Setting.AuchErfuellt).Count -gt 0) {
                foreach ($a in @($Setting.AuchErfuellt)) {
                    if (Test-OrcaWertGleich -Ist $roh.Wert -IstTyp $roh.RegTyp `
                            -Soll $a -SollTyp $Setting.RegTyp) {
                        $passt = $true
                        $grund = "steht auf $a und damit strenger als der Sollwert $($Setting.Soll) - bleibt unangetastet"
                        break
                    }
                }
            }

            return @{ Status = $(if ($passt) { 'Erfuellt' } else { 'Abweichend' })
                      Erfuellt = $passt; Ist = $roh.Text; Grund = $grund }
        }

        'Autostart' {
            # Erfüllt, wenn der Autostart-Eintrag NICHT existiert
            return @{ Status = $(if (-not $roh.Vorhanden) { 'Erfuellt' } else { 'Abweichend' })
                      Erfuellt = (-not $roh.Vorhanden); Ist = $roh.Text; Grund = '' }
        }

        'StartupApproved' {
            # Gibt es weder den Autostart-Eintrag noch einen Schalter
            # dafür, startet das Programm ohnehin nicht automatisch -
            # dann wird nichts angelegt.
            $runPfad = Resolve-OrcaRegPfad -Pfad 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Sid $Sid
            $run = Get-OrcaRegWert -Pfad $runPfad -Name $Setting.Wert
            if (-not $roh.Vorhanden -and -not $run) {
                return @{ Status = 'NichtVorhanden'; Erfuellt = $true
                          Ist = 'kein Autostart-Eintrag'; Grund = 'Das Programm hat keinen Autostart-Eintrag' }
            }
            $aus = ($roh.Vorhanden -and (Test-OrcaAutostartAus -Wert $roh.Wert))
            return @{ Status = $(if ($aus) { 'Erfuellt' } else { 'Abweichend' })
                      Erfuellt = $aus; Ist = $(if ($roh.Vorhanden) { $roh.Text } else { 'im Autostart eingeschaltet' }); Grund = '' }
        }

        'Dns' {
            if (-not $roh.Vorhanden) {
                return @{ Status = 'NichtVorhanden'; Erfuellt = $true
                          Ist = $roh.Text; Grund = 'keine echte Netzwerkkarte gefunden' }
            }
            return @{ Status = $(if ($roh.Wert.Erfuellt) { 'Erfuellt' } else { 'Abweichend' })
                      Erfuellt = [bool]$roh.Wert.Erfuellt; Ist = $roh.Text; Grund = '' }
        }

        { $_ -in @('HostsBlock','Firewallregel') } {
            $ok = if ($Setting.Typ -eq 'HostsBlock') { [bool]$roh.Wert.Intakt } else { [bool]$roh.Wert }
            return @{ Status = $(if ($ok) { 'Erfuellt' } else { 'Abweichend' })
                      Erfuellt = $ok; Ist = $roh.Text; Grund = '' }
        }

        'Computerschutz' {
            $ok = (-not $roh.Wert.An -and [int]$roh.Wert.Kopien -eq 0)
            return @{ Status = $(if ($ok) { 'Erfuellt' } else { 'Abweichend' })
                      Erfuellt = $ok; Ist = $roh.Text; Grund = '' }
        }

        'SchluesselWeg' {
            $weg = (@($roh.Wert).Count -eq 0)
            return @{ Status = $(if ($weg) { 'Erfuellt' } else { 'Abweichend' })
                      Erfuellt = $weg; Ist = $roh.Text; Grund = '' }
        }

        'Indexsperre' {
            $fehlt = @(@($Setting.Soll) | Where-Object { $_ -notin @($roh.Wert) })
            return @{ Status = $(if ($fehlt.Count -eq 0) { 'Erfuellt' } else { 'Abweichend' })
                      Erfuellt = ($fehlt.Count -eq 0); Ist = $roh.Text; Grund = '' }
        }

        'Dienst' {
            if (-not $roh.Vorhanden) {
                return @{ Status = 'NichtVorhanden'; Erfuellt = $true
                          Ist = 'nicht vorhanden'; Grund = 'Dienst auf diesem System nicht vorhanden' }
            }
            $passt = ([string]$roh.Wert -eq [string]$Setting.Soll)
            return @{ Status = $(if ($passt) { 'Erfuellt' } else { 'Abweichend' })
                      Erfuellt = $passt; Ist = $roh.Text; Grund = '' }
        }

        'Aufgabe' {
            if (-not $roh.Vorhanden) {
                return @{ Status = 'NichtVorhanden'; Erfuellt = $true
                          Ist = 'nicht vorhanden'; Grund = 'Aufgabe auf diesem System nicht vorhanden' }
            }
            $passt = ([string]$roh.Wert -eq 'Disabled')
            return @{ Status = $(if ($passt) { 'Erfuellt' } else { 'Abweichend' })
                      Erfuellt = $passt; Ist = $roh.Text; Grund = '' }
        }

        'Feature' {
            if (-not $roh.Vorhanden) {
                return @{ Status = 'NichtVorhanden'; Erfuellt = $true
                          Ist = 'nicht vorhanden'; Grund = 'Windows-Funktion auf diesem System nicht vorhanden' }
            }
            $passt = ([string]$roh.Wert -eq [string]$Setting.Soll)
            return @{ Status = $(if ($passt) { 'Erfuellt' } else { 'Abweichend' })
                      Erfuellt = $passt; Ist = $roh.Text; Grund = '' }
        }

        'NetBios' {
            if (-not $roh.Vorhanden) {
                return @{ Status = 'NichtVorhanden'; Erfuellt = $true
                          Ist = $roh.Text; Grund = 'keine Netzwerkschnittstellen gefunden' }
            }
            $passt = ($roh.Wert.Offen -eq 0)
            return @{ Status = $(if ($passt) { 'Erfuellt' } else { 'Abweichend' })
                      Erfuellt = $passt; Ist = $roh.Text; Grund = '' }
        }

        'Hypervisor' {
            $istAus  = ($roh.Vorhanden -and ([string]$roh.Wert -match '^Off$'))
            $sollAus = ([string]$Setting.Soll -match '^Off$')
            $passt = ($istAus -eq $sollAus)
            return @{ Status = $(if ($passt) { 'Erfuellt' } else { 'Abweichend' })
                      Erfuellt = $passt; Ist = $roh.Text; Grund = '' }
        }

        'DeviceGuard' {
            if (-not $roh.Vorhanden) {
                return @{ Status = 'NichtVorhanden'; Erfuellt = $true
                          Ist = 'nicht vorhanden'; Grund = 'Device-Guard-Schnittstelle auf diesem System nicht vorhanden' }
            }
            $laeuft = ([int]$roh.Wert -eq 2)
            $sollLaeuft = ([int]$Setting.Soll -eq 2)
            $passt = ($laeuft -eq $sollLaeuft)
            return @{ Status = $(if ($passt) { 'Erfuellt' } else { 'Abweichend' })
                      Erfuellt = $passt; Ist = $roh.Text; Grund = '' }
        }

        default {
            return @{ Status = 'Fehler'; Erfuellt = $false; Ist = $null
                      Grund = "Unbekannter Typ: $($Setting.Typ)" }
        }
    }
}

# --------------------------------------------------------------
#  WERTVERGLEICH MIT DATENTYP
#  PowerShell wandelt beim Vergleich die rechte Seite in den Typ
#  der linken. Ein REG_SZ "0" würde damit als korrektes
#  REG_DWORD 0 durchgehen - und Windows ignoriert einen
#  Richtlinienwert mit falschem Datentyp stillschweigend.
#  Deshalb wird der Typ mitgeprüft.
# --------------------------------------------------------------
function Test-OrcaWertGleich {
    param($Ist, [string]$IstTyp, $Soll, [string]$SollTyp)

    $erwartet = switch ($SollTyp) {
        'String'       { 'String' }
        'ExpandString' { 'ExpandString' }
        'QWord'        { 'QWord' }
        'MultiString'  { 'MultiString' }
        'Binary'       { 'Binary' }
        default        { 'DWord' }
    }
    if ($IstTyp -and $IstTyp -ne $erwartet) { return $false }

    if ($erwartet -in @('String','ExpandString')) {
        return ([string]$Ist -eq [string]$Soll)
    }
    try {
        return ([int64]$Ist -eq [int64]$Soll)
    } catch {
        return ([string]$Ist -eq [string]$Soll)
    }
}

# ==============================================================
#  TEIL 2 - GRUNDZUSTAND SICHERN
# ==============================================================

# --------------------------------------------------------------
#  Die Messung VOR dem ersten Eingriff. Sie ist die Grundlage
#  des Rückbaus: wiederhergestellt wird, was gemessen wurde -
#  nicht, was im Katalog vermutet wird.
#
#  Bereits erfasste Punkte werden NIE überschrieben. Eine
#  zweite Einrichtung würde sonst den von OrcaShield gesetzten
#  Zustand als Ausgangszustand festhalten.
# --------------------------------------------------------------
function Get-OrcaBaselineStand {
    # Drei Fälle, die man nicht verwechseln darf:
    #   Da = $false        - es gab noch nie eine Messung (Erstlauf)
    #   Da und Lesbar      - alles in Ordnung
    #   Da, nicht Lesbar   - die Datei ist beschädigt
    #
    # Der dritte Fall ist der gefährliche. Wer ihn wie den ersten
    # behandelt, misst den JETZIGEN - also bereits gehärteten -
    # Zustand und legt ihn als "Grundzustand" ab. Der Rückbau
    # stellt danach die Härtung wieder her und meldet dabei
    # Erfolg. Deshalb wird hier unterschieden.
    $erg = @{ Da = $false; Lesbar = $false; Tabelle = @{}; Grund = '' }
    if (-not (Test-Path $Global:OrcaBaseline)) { return $erg }
    $erg.Da = $true
    try {
        $roh = Get-Content $Global:OrcaBaseline -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $tab = @{}
        foreach ($p in $roh.PSObject.Properties) { $tab[$p.Name] = $p.Value }
        $erg.Tabelle = $tab
        $erg.Lesbar  = $true
    }
    catch {
        $erg.Grund = $_.Exception.Message
    }
    return $erg
}

function Clear-OrcaBaselineCache {
    $Global:OrcaBaselineCache = $null
}

function Get-OrcaBaseline {
    # Zwischengespeichert, weil der Rückbau sonst für jeden
    # einzelnen Punkt die ganze Datei erneut liest und auswertet.
    if ($null -ne $Global:OrcaBaselineCache) { return $Global:OrcaBaselineCache }
    $stand = Get-OrcaBaselineStand
    $Global:OrcaBaselineCache = $stand.Tabelle
    return $stand.Tabelle
}

function Get-OrcaBaselineEintrag {
    param([string]$Id)
    $b = Get-OrcaBaseline
    if ($b.ContainsKey($Id)) { return $b[$Id] }
    return $null
}

function Save-OrcaBaseline {
    param(
        [Parameter(Mandatory)][array]$Settings,
        [string]$Sid = '',
        [switch]$Leise
    )

    $stand = Get-OrcaBaselineStand
    if ($stand.Da -and -not $stand.Lesbar) {
        # Lieber gar nichts schreiben als den gehärteten Zustand
        # als Ausgangszustand festschreiben. Die beschädigte Datei
        # bleibt absichtlich liegen: sie ist der einzige Hinweis
        # darauf, dass hier ein Mensch entscheiden muss.
        Write-OrcaLog -Level FEHLER -Source 'BASELINE' `
            -Message "Die Datei mit dem Grundzustand ist vorhanden, aber nicht lesbar ($($stand.Grund)). Es wird NICHTS neu gemessen - der jetzige Zustand ist bereits der gehärtete, und als Grundzustand abgelegt würde er den Rückbau wertlos machen. Abhilfe: '$($Global:OrcaBaseline)' aus einer Sicherung zurücklegen, oder die Datei bewusst löschen und hinnehmen, dass der Rückbau danach auf Katalogwerte zurückfällt."
        return @{ Erfolg = $false; Neu = 0; Gesamt = 0
                  Grund = 'Datei mit dem Grundzustand ist beschädigt' }
    }

    $tab = $stand.Tabelle
    $neu = 0
    $i = 0
    $n = $Settings.Count

    foreach ($s in $Settings) {
        $i++
        if (-not $Leise) { Write-OrcaBalken -Aktuell $i -Gesamt $n -Text "messe $($s.Name)" }
        if ($tab.ContainsKey($s.Id)) { continue }

        $roh = Get-OrcaIstRoh -Setting $s -Sid $Sid
        $wert = $roh.Wert
        if ($s.Typ -eq 'NetBios' -and $roh.Vorhanden) {
            # Je Schnittstelle sichern, damit der Rückbau genau
            # zurückstellen kann, was vorher stand.
            $wert = @{}
            $basis = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces'
            foreach ($k in (Get-ChildItem -Path $basis -ErrorAction SilentlyContinue)) {
                $v = Get-OrcaRegWert -Pfad $k.PSPath -Name 'NetbiosOptions'
                $wert[(Split-Path $k.Name -Leaf)] = $v
            }
        }

        $tab[$s.Id] = @{
            Id        = $s.Id
            Typ       = $s.Typ
            Vorhanden = $roh.Vorhanden
            SchluesselDa = $roh.SchluesselDa
            Wert      = $wert
            RegTyp    = $roh.RegTyp
            Text      = $roh.Text
            Zeit      = (ConvertTo-OrcaZeitstempel)
        }
        $neu++
    }

    try {
        Invoke-OrcaMitSperre { Write-OrcaJsonDatei -Ziel $Global:OrcaBaseline -Inhalt $tab } | Out-Null
        Clear-OrcaBaselineCache
        Write-OrcaLog -Level OK -Source 'BASELINE' `
            -Message "Grundzustand gemessen: $neu neue Einträge, $($tab.Count) insgesamt"
        return @{ Erfolg = $true; Neu = $neu; Gesamt = $tab.Count; Grund = '' }
    } catch {
        Write-OrcaLog -Level FEHLER -Source 'BASELINE' `
            -Message "Grundzustand konnte nicht gesichert werden. Grund: $($_.Exception.Message)"
        return @{ Erfolg = $false; Neu = 0; Gesamt = 0; Grund = $_.Exception.Message }
    }
}

# ==============================================================
#  TEIL 3 - SETZEN UND NACHPRÜFEN
# ==============================================================

# --------------------------------------------------------------
#  EINSTELLUNG ANWENDEN
#  Rückgabe: @{ Erfolg; Geaendert; Status; Grund }
#
#  Status:
#    Gesetzt        geschrieben und nachgelesen, steht korrekt
#    Unveraendert   stand bereits korrekt
#    NeustartNoetig geschrieben, wirkt erst nach dem Neustart
#    NichtVorhanden gibt es auf diesem System nicht
#    NichtAnwendbar wirkt auf diesem System nicht
#    Offen          geschrieben, wirkt aber nicht (Wirkungsprüfung)
#    Fehler         Schreibvorgang gescheitert
# --------------------------------------------------------------
# --------------------------------------------------------------
#  Einmalige Folgeaktion nach dem Setzen (Feld NachDemSetzen).
#  Läuft nur, wenn ein Punkt gerade wirklich neu gesetzt wurde -
#  nicht bei jedem Wächterlauf. Ein Fehler hier macht das Setzen
#  nicht ungültig, er wird nur gemeldet.
# --------------------------------------------------------------
function Invoke-OrcaNachDemSetzen {
    param([Parameter(Mandatory)]$Setting)

    switch ($Setting.NachDemSetzen) {
        'DoZwischenspeicherLeeren' {
            # Mit Modus Einfach (99) gibt die Übermittlungsoptimierung
            # nichts mehr weiter; der Zwischenspeicher dient nur dem
            # Weitergeben. Windows lädt bei Bedarf neu.
            try {
                Delete-DeliveryOptimizationCache -Force -ErrorAction Stop
                Write-OrcaLog -Level OK -Source 'UPDATES' `
                    -Message 'Zwischenspeicher der Übermittlungsoptimierung geleert'
            }
            catch {
                Write-OrcaLog -Level WARN -Source 'UPDATES' `
                    -Message "Zwischenspeicher der Übermittlungsoptimierung nicht geleert: $($_.Exception.Message)"
            }
        }
        default {
            Write-OrcaLog -Level WARN -Source 'ENGINE' `
                -Message "$($Setting.Id): unbekannte Folgeaktion '$($Setting.NachDemSetzen)'"
        }
    }
}

function Set-OrcaSetting {
    param(
        [Parameter(Mandatory)]$Setting,
        [string]$Sid = '',
        [switch]$NurWennAbweichend
    )

    $vorher = Test-OrcaSetting -Setting $Setting -Sid $Sid

    switch ($vorher.Status) {
        'NichtAnwendbar' { return @{ Erfolg = $true; Geaendert = $false; Status = 'NichtAnwendbar'; Grund = $vorher.Grund } }
        'NichtVorhanden' { return @{ Erfolg = $true; Geaendert = $false; Status = 'NichtVorhanden'; Grund = $vorher.Grund } }
        'Fehler'         { return @{ Erfolg = $false; Geaendert = $false; Status = 'Fehler'; Grund = $vorher.Grund } }
    }

    if ($vorher.Status -eq 'Erfuellt') {
        return @{ Erfolg = $true; Geaendert = $false; Status = 'Unveraendert'; Grund = 'stand bereits korrekt' }
    }

    # Reine Prüfpunkte ändern nichts.
    if ($Setting.Typ -eq 'DeviceGuard') {
        $u = Get-OrcaHypervisorUrsache
        $ursache = if (@($u.Ursachen).Count -gt 0) { "eingeschaltet: $(@($u.Ursachen) -join ', ')" }
                   else { 'keine Windows-Funktion als Ursache gefunden - dann UEFI-Sperre oder Neustart ausstehend' }
        Write-OrcaLog -Level WARN -Source 'DEVICEGUARD' `
            -Message "Virtualisierungsbasierte Sicherheit ist weiterhin aktiv (Zustand: $($vorher.Ist)), obwohl alle Werte auf Abschaltung stehen. $ursache"
        return @{ Erfolg = $true; Geaendert = $false; Status = 'Offen'
                  Grund = "läuft weiterhin ($($vorher.Ist)) - $ursache" }
    }

    # --- Schreiben ---
    $schreibfehler = ''
    $neustart = $false
    try {
        switch ($Setting.Typ) {

            { $_ -in @('Registry','Autologger') } {
                $pfad = Resolve-OrcaRegPfad -Pfad $Setting.Pfad -Sid $Sid
                $r = Set-OrcaRegWert -Pfad $pfad -Name $Setting.Wert -Wert $Setting.Soll -Typ $Setting.RegTyp
                if (-not $r.Erfolg) { $schreibfehler = $r.Grund }
            }

            'Autostart' {
                $pfad = Resolve-OrcaRegPfad -Pfad $Setting.Pfad -Sid $Sid
                $r = Remove-OrcaRegWert -Pfad $pfad -Name $Setting.Wert
                if (-not $r.Erfolg) { $schreibfehler = $r.Grund }
            }

            'StartupApproved' {
                # 03 00 00 00 + Zeitpunkt: so schreibt es der Task-
                # Manager, wenn man dort "Deaktivieren" wählt.
                $pfad = Resolve-OrcaRegPfad -Pfad $Setting.Pfad -Sid $Sid
                [byte[]]$bytes = @(3, 0, 0, 0) + [BitConverter]::GetBytes((Get-Date).ToFileTime())
                $r = Set-OrcaRegWert -Pfad $pfad -Name $Setting.Wert -Wert $bytes -Typ 'Binary'
                if (-not $r.Erfolg) { $schreibfehler = $r.Grund }
            }

            'Dns' {
                $r = Set-OrcaDns -Soll $Setting.Soll
                if (-not $r.Erfolg) { $schreibfehler = $r.Grund }
            }

            'HostsBlock' {
                $stand = Get-OrcaHostsAbschnitte
                $soll = @($Global:OrcaHostsFolge | Where-Object { $stand[$_].Intakt -or $_ -eq [string]$Setting.Soll })
                $r = Write-OrcaHosts -Abschnitte $soll
                if (-not $r.Erfolg) { $schreibfehler = $r.Grund }
            }

            'Firewallregel' {
                if (Get-NetFirewallRule -DisplayName $Setting.Wert -ErrorAction SilentlyContinue) {
                    Remove-NetFirewallRule -DisplayName $Setting.Wert -ErrorAction Stop
                }
                New-NetFirewallRule -DisplayName $Setting.Wert -Direction Outbound -Action Block `
                    -Program "$env:SystemRoot\System32\svchost.exe" -Service ([string]$Setting.Soll) -Profile Any `
                    -Description 'OrcaShield: kein Netzzugang fuer diesen Dienst (Katalogpunkt).' -ErrorAction Stop | Out-Null
            }

            'SchluesselWeg' {
                foreach ($k in @($Setting.Soll)) {
                    if (Test-OrcaRegSchluessel -Pfad $k) { Remove-Item -LiteralPath $k -Recurse -Force -ErrorAction Stop }
                }
            }

            'Computerschutz' {
                # Erst abschalten, sonst legt Windows sofort die nächste
                # Kopie an. Dann die vorhandenen Kopien von C: löschen -
                # über die Windows-Schnittstelle, nicht über vssadmin
                # (siehe Remove-OrcaSchattenkopien in Orca-Common.ps1).
                if ((Get-OrcaComputerschutz).An) {
                    Disable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
                }
                $r = Remove-OrcaSchattenkopien -Laufwerk $env:SystemDrive
                if ($r.Nachher -gt 0) {
                    $schreibfehler = "$($r.Nachher) von $($r.Vorher) Schattenkopien nicht löschbar: $($r.Grund)"
                }
            }

            'Indexsperre' {
                foreach ($l in @($Setting.Soll)) {
                    $name = "file:///$($l):\*"
                    $r = Set-OrcaRegWert -Pfad $Setting.Pfad -Name $name -Wert $name -Typ 'String'
                    if (-not $r.Erfolg) { $schreibfehler = $r.Grund; break }
                }
            }

            'Dienst' {
                Stop-Service -Name $Setting.Wert -Force -ErrorAction SilentlyContinue
                Set-Service  -Name $Setting.Wert -StartupType $Setting.Soll -ErrorAction Stop
            }

            'Aufgabe' {
                $pfad = Split-Path $Setting.Wert -Parent
                $name = Split-Path $Setting.Wert -Leaf
                if (-not $pfad.EndsWith('\')) { $pfad += '\' }
                Disable-ScheduledTask -TaskPath $pfad -TaskName $name -ErrorAction Stop | Out-Null
            }

            'Feature' {
                $r = Disable-WindowsOptionalFeature -Online -FeatureName $Setting.Wert -NoRestart -ErrorAction Stop
                if ($r.RestartNeeded) { $neustart = $true }
            }

            'NetBios' {
                $basis = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces'
                $ok = 0; $gesamt = 0; $fehlgeschlagen = @()
                foreach ($k in (Get-ChildItem -Path $basis -ErrorAction Stop)) {
                    $gesamt++
                    $r = Set-OrcaRegWert -Pfad $k.PSPath -Name 'NetbiosOptions' -Wert $Setting.Soll
                    if ($r.Erfolg) { $ok++ } else { $fehlgeschlagen += (Split-Path $k.Name -Leaf) }
                }
                if ($ok -lt $gesamt) {
                    $schreibfehler = "$($gesamt - $ok) von $gesamt Schnittstellen nicht änderbar ($($fehlgeschlagen -join ', '))"
                }
            }

            'Hypervisor' {
                $ziel = if ([string]$Setting.Soll -match '^(Auto|On)$') { 'Auto' } else { 'Off' }
                $p = Start-Process -FilePath 'bcdedit.exe' `
                        -ArgumentList "/set {current} hypervisorlaunchtype $ziel" `
                        -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
                if ($p.ExitCode -ne 0) { $schreibfehler = "bcdedit meldete Rückgabewert $($p.ExitCode)" }
                else { $neustart = $true }
            }

            default {
                return @{ Erfolg = $false; Geaendert = $false; Status = 'Fehler'
                          Grund = "Unbekannter Typ: $($Setting.Typ)" }
            }
        }
    }
    catch {
        $schreibfehler = $_.Exception.Message
    }

    if ($schreibfehler) {
        return @{ Erfolg = $false; Geaendert = $false; Status = 'Fehler'; Grund = $schreibfehler }
    }

    # --- Nachlesen ---
    # Erfolg wird erst gemeldet, wenn der Wert wirklich dort steht.
    if ($neustart) {
        return @{ Erfolg = $true; Geaendert = $true; Status = 'NeustartNoetig'
                  Grund = 'geschrieben, wirkt nach dem Neustart' }
    }

    $nachher = Test-OrcaSetting -Setting $Setting -Sid $Sid
    if ($nachher.Status -eq 'Erfuellt') {
        if ($Setting.NachDemSetzen) { Invoke-OrcaNachDemSetzen -Setting $Setting }
        return @{ Erfolg = $true; Geaendert = $true; Status = 'Gesetzt'; Grund = '' }
    }

    return @{ Erfolg = $false; Geaendert = $false; Status = 'Offen'
              Grund = "geschrieben, aber die Nachprüfung ergibt weiterhin '$($nachher.Ist)'" }
}

# ==============================================================
#  TEIL 4 - ZURÜCKSETZEN
# ==============================================================

# --------------------------------------------------------------
#  EINSTELLUNG ZURÜCKSETZEN (für den Uninstaller)
#  Grundlage ist der gemessene Grundzustand. Nur wenn es zu
#  einem Punkt keine Messung gibt, wird auf den im Katalog
#  hinterlegten 'Standard' zurückgefallen - und das wird
#  ausdrücklich protokolliert.
# --------------------------------------------------------------
function Reset-OrcaSetting {
    param(
        [Parameter(Mandatory)]$Setting,
        [string]$Sid = '',
        $BaselineEintrag = $null
    )

    if ($null -eq $BaselineEintrag) {
        $BaselineEintrag = Get-OrcaBaselineEintrag -Id $Setting.Id
    }
    $ausMessung = ($null -ne $BaselineEintrag)

    try {
        switch ($Setting.Typ) {

            'Dns' {
                if (-not $ausMessung) { return @{ Erfolg = $true; Grund = 'keine Messung vorhanden - DNS unverändert gelassen' } }
                return (Reset-OrcaDns -Baseline $BaselineEintrag.Wert)
            }

            'HostsBlock' {
                $stand = Get-OrcaHostsAbschnitte
                $soll = @($Global:OrcaHostsFolge | Where-Object { $stand[$_].Intakt -and $_ -ne [string]$Setting.Soll })
                $r = Write-OrcaHosts -Abschnitte $soll -Zurueck ([string]$Setting.Soll)
                if ($r.Erfolg) { return @{ Erfolg = $true; Grund = 'Abschnitt aus dem OrcaShield-Block entfernt, übernommene Einträge zurückgegeben' } }
                return @{ Erfolg = $false; Grund = $r.Grund }
            }

            'Firewallregel' {
                if ($ausMessung -and $BaselineEintrag.Vorhanden) { return @{ Erfolg = $true; Grund = 'Regel bestand schon vorher - belassen' } }
                Remove-NetFirewallRule -DisplayName $Setting.Wert -ErrorAction SilentlyContinue
                return @{ Erfolg = $true; Grund = 'Regel entfernt' }
            }

            'SchluesselWeg' {
                # Wiederhergestellt wird nur, was vor der Einrichtung da war -
                # mit dem Standardwert, den Windows dort fuehrt.
                $vorher = if ($ausMessung) { @($BaselineEintrag.Wert) } else { @($Setting.Soll) }
                foreach ($k in $vorher) {
                    if (-not $k -or (Test-OrcaRegSchluessel -Pfad $k)) { continue }
                    New-Item -Path $k -Value ([string]$Setting.Standard) -Force -ErrorAction Stop | Out-Null
                }
                return @{ Erfolg = $true; Grund = 'Schluessel wiederhergestellt, wie vor der Einrichtung' }
            }

            'Indexsperre' {
                $vorher = @()
                if ($ausMessung) { $vorher = @($BaselineEintrag.Wert) }
                foreach ($l in @($Setting.Soll)) {
                    if ($l -in $vorher) { continue }
                    Remove-OrcaRegWert -Pfad $Setting.Pfad -Name "file:///$($l):\*" | Out-Null
                }
                return @{ Erfolg = $true; Grund = 'eigene Sperren entfernt, vorher vorhandene belassen' }
            }

            'StartupApproved' {
                $pfad = Resolve-OrcaRegPfad -Pfad $Setting.Pfad -Sid $Sid
                if ($ausMessung -and $BaselineEintrag.Vorhanden) {
                    [byte[]]$bytes = @($BaselineEintrag.Wert | ForEach-Object { [byte]$_ })
                    $r = Set-OrcaRegWert -Pfad $pfad -Name $Setting.Wert -Wert $bytes -Typ 'Binary'
                    if ($r.Erfolg) { return @{ Erfolg = $true; Grund = 'auf den gemessenen Ausgangswert zurückgestellt' } }
                    return @{ Erfolg = $false; Grund = $r.Grund }
                }
                $r = Remove-OrcaRegWert -Pfad $pfad -Name $Setting.Wert
                if ($r.Erfolg) { return @{ Erfolg = $true; Grund = 'Schalter entfernt - er existierte vor der Einrichtung nicht' } }
                return @{ Erfolg = $false; Grund = $r.Grund }
            }

            { $_ -in @('Registry','Autologger','Autostart') } {
                $pfad = Resolve-OrcaRegPfad -Pfad $Setting.Pfad -Sid $Sid

                if ($ausMessung) {
                    if (-not $BaselineEintrag.Vorhanden) {
                        $r = Remove-OrcaRegWert -Pfad $pfad -Name $Setting.Wert
                        if (-not $r.Erfolg) { return @{ Erfolg = $false; Grund = $r.Grund } }
                        if ($BaselineEintrag.SchluesselDa -eq $false) {
                            $k = Remove-OrcaRegSchluesselWennLeer -Pfad $pfad
                            if ($k.Entfernt) { return @{ Erfolg = $true; Grund = 'Wert und leerer Schlüssel entfernt - beide gab es vor der Einrichtung nicht' } }
                        }
                        return @{ Erfolg = $true; Grund = 'Wert entfernt - er existierte vor der Einrichtung nicht' }
                    }
                    $typ = if ($BaselineEintrag.RegTyp) { $BaselineEintrag.RegTyp } else { $Setting.RegTyp }
                    $r = Set-OrcaRegWert -Pfad $pfad -Name $Setting.Wert -Wert $BaselineEintrag.Wert -Typ $typ
                    if ($r.Erfolg) { return @{ Erfolg = $true; Grund = "auf den gemessenen Ausgangswert zurückgestellt ($($BaselineEintrag.Wert))" } }
                    return @{ Erfolg = $false; Grund = $r.Grund }
                }

                # Rückfall ohne Messung
                if ($null -eq $Setting.Standard) {
                    $r = Remove-OrcaRegWert -Pfad $pfad -Name $Setting.Wert
                } else {
                    $r = Set-OrcaRegWert -Pfad $pfad -Name $Setting.Wert -Wert $Setting.Standard -Typ $Setting.RegTyp
                }
                if ($r.Erfolg) { return @{ Erfolg = $true; Grund = 'keine Messung vorhanden - Katalogwert verwendet' } }
                return @{ Erfolg = $false; Grund = $r.Grund }
            }

            'Dienst' {
                $svc = Get-Service -Name $Setting.Wert -ErrorAction SilentlyContinue
                if (-not $svc) { return @{ Erfolg = $true; Grund = 'Dienst nicht vorhanden' } }

                $modus = $null
                if ($ausMessung -and $BaselineEintrag.Vorhanden -and $BaselineEintrag.Wert) {
                    $modus = [string]$BaselineEintrag.Wert
                } elseif ($Setting.Standard) {
                    $modus = [string]$Setting.Standard
                }
                if (-not $modus) { return @{ Erfolg = $true; Grund = 'kein Ausgangszustand bekannt - Dienst unverändert gelassen' } }

                # 'Auto' aus Win32_Service entspricht 'Automatic' für Set-Service
                if ($modus -eq 'Auto') { $modus = 'Automatic' }
                if ($modus -notin @('Automatic','Manual','Disabled','Boot','System')) {
                    return @{ Erfolg = $true; Grund = "unbekannter Startmodus '$modus' - Dienst unverändert gelassen" }
                }
                Set-Service -Name $Setting.Wert -StartupType $modus -ErrorAction Stop
                if ($modus -eq 'Automatic') {
                    Start-Service -Name $Setting.Wert -ErrorAction SilentlyContinue
                    return @{ Erfolg = $true; Grund = "Startmodus auf $modus zurückgestellt und Dienst gestartet" }
                }
                return @{ Erfolg = $true; Grund = "Startmodus auf $modus zurückgestellt" }
            }

            'Aufgabe' {
                $pfad = Split-Path $Setting.Wert -Parent
                $name = Split-Path $Setting.Wert -Leaf
                if (-not $pfad.EndsWith('\')) { $pfad += '\' }
                $t = Get-ScheduledTask -TaskPath $pfad -TaskName $name -ErrorAction SilentlyContinue
                if (-not $t) { return @{ Erfolg = $true; Grund = 'Aufgabe nicht vorhanden' } }

                if ($ausMessung -and $BaselineEintrag.Vorhanden -and ([string]$BaselineEintrag.Wert -eq 'Disabled')) {
                    return @{ Erfolg = $true; Grund = 'war vor der Einrichtung bereits deaktiviert - unverändert gelassen' }
                }
                Enable-ScheduledTask -TaskPath $pfad -TaskName $name -ErrorAction Stop | Out-Null
                return @{ Erfolg = $true; Grund = 'wieder aktiviert' }
            }

            'Feature' {
                $f = Get-WindowsOptionalFeature -Online -FeatureName $Setting.Wert -ErrorAction SilentlyContinue
                if (-not $f) { return @{ Erfolg = $true; Grund = 'Funktion nicht vorhanden' } }

                $warAktiv = $false
                if ($ausMessung -and $BaselineEintrag.Vorhanden) {
                    $warAktiv = ([string]$BaselineEintrag.Wert -match '^Enabled')
                } elseif ($Setting.Standard) {
                    $warAktiv = ([string]$Setting.Standard -match '^Enabled')
                }

                if (-not $warAktiv) {
                    return @{ Erfolg = $true
                              Grund = 'war vor der Einrichtung nicht aktiviert - wird NICHT wieder installiert' }
                }
                Enable-WindowsOptionalFeature -Online -FeatureName $Setting.Wert -NoRestart -ErrorAction Stop | Out-Null
                return @{ Erfolg = $true; Grund = 'war vorher aktiv und wurde wieder aktiviert - Neustart erforderlich' }
            }

            'NetBios' {
                $basis = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces'
                if (-not (Test-Path $basis)) { return @{ Erfolg = $true; Grund = 'keine Schnittstellen vorhanden' } }

                $gemessen = $null
                if ($ausMessung -and $BaselineEintrag.Wert) {
                    $gemessen = @{}
                    foreach ($p in $BaselineEintrag.Wert.PSObject.Properties) { $gemessen[$p.Name] = $p.Value }
                }

                foreach ($k in (Get-ChildItem -Path $basis -ErrorAction SilentlyContinue)) {
                    $name = Split-Path $k.Name -Leaf
                    $wert = 0
                    if ($gemessen -and $gemessen.ContainsKey($name) -and $null -ne $gemessen[$name]) {
                        $wert = $gemessen[$name]
                    }
                    Set-OrcaRegWert -Pfad $k.PSPath -Name 'NetbiosOptions' -Wert $wert | Out-Null
                }
                return @{ Erfolg = $true; Grund = $(if ($gemessen) { 'je Schnittstelle auf den gemessenen Wert zurückgestellt' } else { 'auf den Windows-Vorgabewert 0 zurückgestellt' }) }
            }

            'Hypervisor' {
                $ziel = 'Auto'
                if ($ausMessung -and $BaselineEintrag.Vorhanden) { $ziel = [string]$BaselineEintrag.Wert }
                elseif ($Setting.Standard) { $ziel = [string]$Setting.Standard }
                if ($ziel -notmatch '^(Auto|Off|On)$') { $ziel = 'Auto' }

                $p = Start-Process -FilePath 'bcdedit.exe' `
                        -ArgumentList "/set {current} hypervisorlaunchtype $ziel" `
                        -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
                return @{ Erfolg = ($p.ExitCode -eq 0)
                          Grund = $(if ($p.ExitCode -eq 0) { "auf $ziel zurückgestellt - Neustart erforderlich" }
                                    else { "bcdedit meldete Rückgabewert $($p.ExitCode)" }) }
            }

            'DeviceGuard' {
                return @{ Erfolg = $true; Grund = 'reiner Prüfpunkt - nichts zurückzusetzen' }
            }

            'Computerschutz' {
                if (-not $ausMessung) { return @{ Erfolg = $true; Grund = 'keine Messung vorhanden - Computerschutz unverändert gelassen' } }
                if (-not $BaselineEintrag.Wert.An) { return @{ Erfolg = $true; Grund = 'war vor der Einrichtung schon aus - belassen' } }
                Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
                if ((Get-OrcaComputerschutz).An) {
                    return @{ Erfolg = $true; Grund = 'wieder eingeschaltet - gelöschte Schattenkopien kommen nicht zurück' }
                }
                return @{ Erfolg = $false; Grund = 'Einschalten ohne Fehler, die Nachprüfung zeigt den Computerschutz aber weiterhin aus' }
            }

            default {
                return @{ Erfolg = $false; Grund = "Unbekannter Typ: $($Setting.Typ)" }
            }
        }
    }
    catch {
        return @{ Erfolg = $false; Grund = $_.Exception.Message }
    }
}

# ==============================================================
#  TEIL 5 - STAPELVERARBEITUNG
# ==============================================================

function Invoke-OrcaSettingsBatch {
    param(
        [Parameter(Mandatory)][array]$Settings,
        [string]$Quelle = 'INSTALL',
        [string]$Sid = '',
        [switch]$Leise
    )

    $ergebnis = @{ Gesetzt = 0; Unveraendert = 0; Neustart = 0; Offen = 0
                   Fehler = 0; NichtAnwendbar = 0; NichtVorhanden = 0
                   FehlerListe = @(); OffenListe = @() }
    $i = 0
    $n = $Settings.Count

    foreach ($s in $Settings) {
        $i++
        if (-not $Leise) { Write-OrcaBalken -Aktuell $i -Gesamt $n -Text $s.Name }

        $r = Set-OrcaSetting -Setting $s -Sid $Sid

        switch ($r.Status) {
            'Gesetzt' {
                $ergebnis.Gesetzt++
                Write-OrcaLog -Level OK -Source $Quelle -Message "$($s.Id) $($s.Name) - gesetzt und nachgeprüft"
            }
            'NeustartNoetig' {
                $ergebnis.Neustart++
                Write-OrcaLog -Level OK -Source $Quelle -Message "$($s.Id) $($s.Name) - gesetzt, wirkt nach dem Neustart"
            }
            'Unveraendert' {
                $ergebnis.Unveraendert++
            }
            'NichtAnwendbar' {
                $ergebnis.NichtAnwendbar++
                Write-OrcaLog -Level SKIP -Source $Quelle -Message "$($s.Id) $($s.Name) - nicht anwendbar: $($r.Grund)"
            }
            'NichtVorhanden' {
                $ergebnis.NichtVorhanden++
                Write-OrcaLog -Level SKIP -Source $Quelle -Message "$($s.Id) $($s.Name) - $($r.Grund)"
            }
            'Offen' {
                $ergebnis.Offen++
                $ergebnis.OffenListe += "$($s.Id) $($s.Name): $($r.Grund)"
                Write-OrcaLog -Level WARN -Source $Quelle -Message "$($s.Id) $($s.Name) - OHNE WIRKUNG. $($r.Grund)"
            }
            default {
                $ergebnis.Fehler++
                $ergebnis.FehlerListe += "$($s.Id) $($s.Name): $($r.Grund)"
                Write-OrcaLog -Level FEHLER -Source $Quelle -Message "$($s.Id) $($s.Name) - FEHLGESCHLAGEN. Grund: $($r.Grund)"
            }
        }
    }

    return $ergebnis
}

# ==============================================================
#  TEIL 6 - SOLL-IST-ABGLEICH FÜR DEN WÄCHTER
#  Alle Werte eines Schlüssels werden in einem Zug gelesen,
#  Dienste und Aufgaben in je einem Sammelabruf.
# ==============================================================
function Get-OrcaIstZustand {
    param(
        [Parameter(Mandatory)][array]$Settings,
        [string]$Sid = ''
    )

    $ist = @{}

    # --- Registrierung: nach Schlüssel gruppiert ---
    $regPunkte = $Settings | Where-Object { $_.Typ -in @('Registry','Autologger','Autostart') }
    foreach ($g in ($regPunkte | Group-Object -Property Pfad)) {
        $pfad = Resolve-OrcaRegPfad -Pfad $g.Name -Sid $Sid
        $k = Get-OrcaRegSchluessel -Pfad $pfad
        foreach ($s in $g.Group) {
            $ist[$s.Id] = @{
                SchluesselDa = $k.Da
                WertDa       = ($k.Da -and $k.Werte.ContainsKey($s.Wert))
                Wert         = $(if ($k.Da -and $k.Werte.ContainsKey($s.Wert)) { $k.Werte[$s.Wert] } else { $null })
            }
        }
    }

    # --- Dienste: ein einziger Abruf für alle ---
    $dienstPunkte = $Settings | Where-Object { $_.Typ -eq 'Dienst' }
    if ($dienstPunkte) {
        $alle = @{}
        # Scheitert der Sammelabruf, darf das NICHT als "Dienst nicht
        # vorhanden" durchgehen - sonst meldet der Wächter lauter
        # übersprungene Punkte und sieht dabei aus wie Erfolg.
        $abfragefehler = ''
        try {
            foreach ($d in (Get-CimInstance -ClassName Win32_Service -ErrorAction Stop)) {
                $alle[$d.Name] = $d.StartMode
            }
        } catch { $abfragefehler = $_.Exception.Message }
        foreach ($s in $dienstPunkte) {
            $ist[$s.Id] = @{
                Vorhanden     = $alle.ContainsKey($s.Wert)
                Wert          = $(if ($alle.ContainsKey($s.Wert)) { $alle[$s.Wert] } else { $null })
                Abfragefehler = $abfragefehler
            }
        }
    }

    # --- Geplante Aufgaben: ein einziger Abruf für alle ---
    $aufgabenPunkte = $Settings | Where-Object { $_.Typ -eq 'Aufgabe' }
    if ($aufgabenPunkte) {
        $alle = @{}
        $abfragefehler = ''
        try {
            foreach ($t in (Get-ScheduledTask -ErrorAction Stop)) {
                $alle[($t.TaskPath + $t.TaskName)] = [string]$t.State
            }
        } catch { $abfragefehler = $_.Exception.Message }
        foreach ($s in $aufgabenPunkte) {
            $schluessel = $s.Wert
            if (-not $schluessel.StartsWith('\')) { $schluessel = '\' + $schluessel }
            $ist[$s.Id] = @{
                Vorhanden     = $alle.ContainsKey($schluessel)
                Wert          = $(if ($alle.ContainsKey($schluessel)) { $alle[$schluessel] } else { $null })
                Abfragefehler = $abfragefehler
            }
        }
    }

    return $ist
}

function Invoke-OrcaAbgleich {
    param(
        [Parameter(Mandatory)][array]$Settings,
        [string]$Quelle = 'ABGLEICH',
        [string]$Sid = ''
    )

    $erg = @{ Geprueft = 0; Korrigiert = 0; Fehler = 0; Offen = 0; Uebersprungen = 0; Ausgenommen = 0
              FehlerListe = @(); OffenListe = @(); KorrigiertListe = @(); KorrigiertIds = @(); AusgenommenListe = @() }
    if ($Settings.Count -eq 0) { return $erg }

    # Punkte, die ein installiertes Programm nachweislich braucht und
    # selbst wieder umstellt (Feld BenoetigtVon), werden gar nicht erst
    # verglichen. Zurückstellen hieße Wettlauf bei jedem Start - bei
    # LLMNR und Meta Horizon gewann das Programm 15 Sekunden später.
    $geprueftSettings = @()
    foreach ($s in $Settings) {
        $bv = Get-OrcaBenoetigtVon -Setting $s
        if ($bv.Count -gt 0) {
            $erg.Ausgenommen++
            $erg.AusgenommenListe += "$($s.Id) $($s.Name): von $($bv -join ', ') benötigt"
        } else {
            $geprueftSettings += $s
        }
    }
    $Settings = $geprueftSettings
    if ($Settings.Count -eq 0) { return $erg }

    $schnellTypen = @('Registry','Autologger','Autostart','Dienst','Aufgabe')
    $schnell = @($Settings | Where-Object { $_.Typ -in $schnellTypen -and -not $_.Wirkung })
    $langsam = @($Settings | Where-Object { $_.Typ -notin $schnellTypen -or $_.Wirkung })

    $ist = Get-OrcaIstZustand -Settings $schnell -Sid $Sid

    foreach ($s in $schnell) {
        $anw = Test-OrcaAnwendbar -Setting $s -Sid $Sid
        if (-not $anw.Anwendbar) { $erg.Uebersprungen++; continue }

        $m = $ist[$s.Id]

        # Ein gescheiterter Sammelabruf ist ein Fehler, keine
        # Abwesenheit. Ohne diese Abfrage würden bei kaputtem WMI
        # oder Aufgabendienst alle betroffenen Punkte stillschweigend
        # als "nicht vorhanden" übersprungen.
        if ($m.Abfragefehler) {
            $erg.Fehler++
            $erg.FehlerListe += "$($s.Id) $($s.Name): Ist-Zustand nicht abfragbar ($($m.Abfragefehler))"
            Write-OrcaLog -Level FEHLER -Source $Quelle `
                -Message "$($s.Id) $($s.Name): Ist-Zustand nicht abfragbar, Punkt ungeprüft. Grund: $($m.Abfragefehler)"
            continue
        }

        $passt = $false
        $ueberspringen = $false
        $istText = ''

        switch ($s.Typ) {
            'Autostart' {
                $passt = (-not $m.WertDa)
                $istText = $(if ($m.WertDa) { [string]$m.Wert } else { '(nicht gesetzt)' })
            }
            'Dienst' {
                if (-not $m.Vorhanden) { $ueberspringen = $true }
                else { $passt = ([string]$m.Wert -eq [string]$s.Soll); $istText = [string]$m.Wert }
            }
            'Aufgabe' {
                if (-not $m.Vorhanden) { $ueberspringen = $true }
                else { $passt = ([string]$m.Wert -eq 'Disabled'); $istText = [string]$m.Wert }
            }
            default {
                if (-not $m.SchluesselDa -and $s.NurWennVorhanden) { $ueberspringen = $true }
                elseif (-not $m.WertDa) { $passt = $false; $istText = '(nicht gesetzt)' }
                else {
                    # Der Sammelabruf liefert keinen Datentyp. Wer
                    # dem Wert allein traut, übersieht ein falsch
                    # typisiertes REG_SZ - deshalb wird bei einem
                    # scheinbaren Treffer einmal genau nachgesehen.
                    $grob = if ($s.RegTyp -in @('String','ExpandString')) {
                                ([string]$m.Wert -eq [string]$s.Soll)
                            } else {
                                try { ([int64]$m.Wert -eq [int64]$s.Soll) } catch { $false }
                            }
                    if ($grob) {
                        $genau = Test-OrcaSetting -Setting $s -Sid $Sid
                        $passt = $genau.Erfuellt
                        $istText = $genau.Ist
                    } else {
                        $passt = $false
                        $istText = [string]$m.Wert
                    }
                }
            }
        }

        if ($ueberspringen) { $erg.Uebersprungen++; continue }
        $erg.Geprueft++
        if ($passt) { continue }

        $r = Set-OrcaSetting -Setting $s -Sid $Sid
        Add-OrcaAbgleichErgebnis -Erg $erg -Setting $s -Ergebnis $r -IstText $istText -Quelle $Quelle
    }

    # Punkte ohne Sammelabruf einzeln prüfen
    foreach ($s in $langsam) {
        $pruef = Test-OrcaSetting -Setting $s -Sid $Sid
        if ($pruef.Status -in @('NichtAnwendbar','NichtVorhanden')) { $erg.Uebersprungen++; continue }
        $erg.Geprueft++
        if ($pruef.Status -eq 'Erfuellt') { continue }

        $r = Set-OrcaSetting -Setting $s -Sid $Sid
        Add-OrcaAbgleichErgebnis -Erg $erg -Setting $s -Ergebnis $r -IstText $pruef.Ist -Quelle $Quelle
    }

    return $erg
}

function Add-OrcaAbgleichErgebnis {
    param($Erg, $Setting, $Ergebnis, [string]$IstText, [string]$Quelle)

    switch ($Ergebnis.Status) {
        { $_ -in @('Gesetzt','NeustartNoetig') } {
            $Erg.Korrigiert++
            $zusatz = if ($Ergebnis.Status -eq 'NeustartNoetig') { ' (wirkt nach dem Neustart)' } else { '' }
            $Erg.KorrigiertListe += "$($Setting.Id) $($Setting.Name)$zusatz"
            $Erg.KorrigiertIds += $Setting.Id
            Write-OrcaLog -Level OK -Source $Quelle `
                -Message "$($Setting.Id) $($Setting.Name) wich ab (Ist: $IstText) und wurde zurückgestellt$zusatz"
        }
        'Unveraendert' { }
        { $_ -in @('NichtAnwendbar','NichtVorhanden') } { $Erg.Uebersprungen++ }
        'Offen' {
            $Erg.Offen++
            $Erg.OffenListe += "$($Setting.Id) $($Setting.Name): $($Ergebnis.Grund)"
            Write-OrcaLog -Level WARN -Source $Quelle `
                -Message "$($Setting.Id) $($Setting.Name) weicht ab (Ist: $IstText) und lässt sich NICHT zurückstellen. $($Ergebnis.Grund)"
        }
        default {
            $Erg.Fehler++
            $Erg.FehlerListe += "$($Setting.Id) $($Setting.Name): $($Ergebnis.Grund)"
            Write-OrcaLog -Level FEHLER -Source $Quelle `
                -Message "$($Setting.Id) $($Setting.Name) konnte nicht zurückgestellt werden. Grund: $($Ergebnis.Grund)"
        }
    }
}

# ==============================================================
#  TEIL 7 - REGISTRY-SICHERUNG
# ==============================================================

$Global:OrcaSicherungsZweige = @(
    @{ Name = 'HKLM-Software-Policies';       Key = 'HKLM\SOFTWARE\Policies' }
    @{ Name = 'HKCU-Software-Policies';       Key = 'HKCU\SOFTWARE\Policies' }
    @{ Name = 'HKLM-CurrentVersion-Policies'; Key = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies' }
    @{ Name = 'HKLM-CapabilityAccessManager'; Key = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager' }
    @{ Name = 'HKLM-DeliveryOptimization';    Key = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization' }
    @{ Name = 'HKLM-FindMyDevice';            Key = 'HKLM\SOFTWARE\Microsoft\Settings\FindMyDevice' }
    @{ Name = 'HKLM-Sensor';                  Key = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor' }
    @{ Name = 'HKLM-SpeechOneCore';           Key = 'HKLM\SOFTWARE\Microsoft\Speech_OneCore' }
    @{ Name = 'HKLM-Lsa';                     Key = 'HKLM\SYSTEM\CurrentControlSet\Control\Lsa' }
    @{ Name = 'HKLM-DeviceGuard';             Key = 'HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard' }
    @{ Name = 'HKLM-TerminalServer';          Key = 'HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server' }
    @{ Name = 'HKLM-RemoteAssistance';        Key = 'HKLM\SYSTEM\CurrentControlSet\Control\Remote Assistance' }
    @{ Name = 'HKLM-WMI-Autologger';          Key = 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger' }
    @{ Name = 'HKLM-NetBT';                   Key = 'HKLM\SYSTEM\CurrentControlSet\Services\NetBT\Parameters' }
    @{ Name = 'HKLM-LanmanServer';            Key = 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' }
    @{ Name = 'HKLM-LanmanWorkstation';       Key = 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' }
    @{ Name = 'HKLM-Maps';                    Key = 'HKLM\SYSTEM\Maps' }
    @{ Name = 'HKCU-CurrentVersion';          Key = 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion' }
    @{ Name = 'HKCU-InputPersonalization';    Key = 'HKCU\SOFTWARE\Microsoft\InputPersonalization' }
    @{ Name = 'HKCU-Personalization';         Key = 'HKCU\SOFTWARE\Microsoft\Personalization' }
    @{ Name = 'HKCU-Input';                   Key = 'HKCU\SOFTWARE\Microsoft\Input' }
    @{ Name = 'HKCU-Clipboard';               Key = 'HKCU\SOFTWARE\Microsoft\Clipboard' }
    @{ Name = 'HKCU-Siuf';                    Key = 'HKCU\SOFTWARE\Microsoft\Siuf' }
    @{ Name = 'HKCU-SpeechOneCore';           Key = 'HKCU\SOFTWARE\Microsoft\Speech_OneCore' }
    @{ Name = 'HKCU-UserProfileEngagement';   Key = 'HKCU\SOFTWARE\Microsoft\UserProfileEngagement' }
    @{ Name = 'HKCU-GameConfigStore';         Key = 'HKCU\System\GameConfigStore' }
    @{ Name = 'HKCU-International';           Key = 'HKCU\Control Panel\International' }
    @{ Name = 'HKLM-Explorer-DelegateFolders'; Key = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders' }
    @{ Name = 'HKCU-Classes-CLSID-OneDrive';  Key = 'HKCU\SOFTWARE\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' }
)

function Test-OrcaBackupAbdeckung {
    $zweige = @($Global:OrcaSicherungsZweige | ForEach-Object { $_.Key.ToLower() })
    $fehlend = @()
    foreach ($s in $Global:OrcaEinstellungen) {
        if ($s.Typ -notin @('Registry','Autologger','Autostart')) { continue }
        if (-not $s.Pfad) { continue }
        $p = ($s.Pfad -replace '^HKLM:\\','HKLM\' -replace '^HKCU:\\','HKCU\').ToLower()
        $treffer = $false
        foreach ($z in $zweige) { if ($p.StartsWith($z)) { $treffer = $true; break } }
        if (-not $treffer) { $fehlend += "$($s.Id) -> $($s.Pfad)" }
    }
    return $fehlend
}

function New-OrcaRegistryBackup {
    $zeit  = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    $ziel  = Join-Path $Global:OrcaBackup "Registry-Sicherung_$zeit"
    try {
        New-Item -Path $ziel -ItemType Directory -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-OrcaLog -Level FEHLER -Source 'BACKUP' -Message "Sicherungsordner nicht anlegbar: $($_.Exception.Message)"
        return @{ Erfolg = $false; Pfad = $null; Ok = 0; Fehler = 0; Grund = $_.Exception.Message }
    }

    $ok = 0; $fehler = 0; $leer = 0
    foreach ($z in $Global:OrcaSicherungsZweige) {
        $datei = Join-Path $ziel "$($z.Name).reg"
        $p = Start-Process -FilePath 'reg.exe' -ArgumentList "export `"$($z.Key)`" `"$datei`" /y" `
                           -Wait -PassThru -WindowStyle Hidden
        if ($p.ExitCode -eq 0) { $ok++ }
        elseif (-not (Test-Path "Registry::$($z.Key -replace '^HKLM','HKEY_LOCAL_MACHINE' -replace '^HKCU','HKEY_CURRENT_USER')")) { $leer++ }
        else { $fehler++ }
    }

    # Ein gescheitertes Backup wird nicht mehr als OK protokolliert.
    $stufe = if ($ok -eq 0) { 'FEHLER' } elseif ($fehler -gt 0) { 'WARN' } else { 'OK' }
    Write-OrcaLog -Level $stufe -Source 'BACKUP' `
        -Message "Registry-Sicherung: $ok Zweige gesichert, $leer nicht vorhanden, $fehler fehlgeschlagen. Ort: $ziel"

    return @{ Erfolg = ($ok -gt 0 -and $fehler -eq 0); Pfad = $ziel; Ok = $ok; Fehler = $fehler; Grund = '' }
}


$Global:OrcaShutdownCmd   = 'OrcaShield-Shutdown.cmd'
$Global:OrcaGpWurzel      = "$env:SystemRoot\System32\GroupPolicy"
$Global:OrcaGptIni        = Join-Path $Global:OrcaGpWurzel 'gpt.ini'
$Global:OrcaGpScripts     = Join-Path $Global:OrcaGpWurzel 'Machine\Scripts'
$Global:OrcaGpRegWindows  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown'
$Global:OrcaGpRegBasis    = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Shutdown'

# Kennung der Skript-Erweiterung der Gruppenrichtlinie und des
# zugehörigen Bearbeitungswerkzeugs - dasselbe Paar, das gpedit
# beim Eintragen eines Skripts in gpt.ini schreibt.
$Global:OrcaGpSkriptPaar  = '[{42B5FAAE-6536-11D2-AE5A-0000F87571E3}{40B6664F-4972-11D1-A7CA-0000F87571E3}]'

function Read-OrcaScriptsIni {
    param([string]$Pfad)
    # Rückgabe: geordnete Liste von @{ Abschnitt; Zeilen = @() }
    $abschnitte = New-Object System.Collections.ArrayList

    # Das Komma ist nicht schmückendes Beiwerk: PowerShell rollt
    # Sammlungen bei der Rückgabe aus, eine leere Liste wird damit
    # zu $null. Der Aufrufer ruft dann .Add() auf nichts auf und
    # bricht ab - auf jedem System, das noch keine eigene
    # scripts.ini hat, also auf so gut wie jedem.
    if (-not (Test-Path $Pfad)) { return ,$abschnitte }
    $aktuell = $null
    foreach ($z in (Get-Content -LiteralPath $Pfad -Force -ErrorAction SilentlyContinue)) {
        $t = $z.Trim()
        if ($t -match '^\[(.+)\]$') {
            $aktuell = @{ Abschnitt = $matches[1]; Zeilen = New-Object System.Collections.ArrayList }
            [void]$abschnitte.Add($aktuell)
        }
        elseif ($aktuell -and $t) {
            [void]$aktuell.Zeilen.Add($t)
        }
    }
    return ,$abschnitte
}

function Write-OrcaScriptsIni {
    param([string]$Pfad, $Abschnitte)
    $zeilen = @()
    foreach ($a in $Abschnitte) {
        if ($a.Zeilen.Count -eq 0) { continue }
        $zeilen += "[$($a.Abschnitt)]"
        $zeilen += @($a.Zeilen)
    }
    if ($zeilen.Count -eq 0) {
        if (Test-Path $Pfad) { Remove-Item -LiteralPath $Pfad -Force -ErrorAction SilentlyContinue }
        return
    }
    # Die Datei ist versteckt. Set-Content verweigert das
    # Überschreiben versteckter Dateien ohne -Force.
    # scripts.ini erwartet UTF-16LE mit Signatur.
    Set-Content -LiteralPath $Pfad -Value $zeilen -Encoding Unicode -Force -ErrorAction Stop
    # -ErrorAction Stop ist hier tragend: ohne das meldet Get-Item
    # einen NICHT abbrechenden Fehler, der am try/catch vorbeiläuft
    # und rot im Fenster landet, obwohl er niemanden stört.
    try {
        Set-ItemProperty -LiteralPath $Pfad -Name Attributes -Value 'Hidden' -Force -ErrorAction Stop
    } catch { }
}

# --------------------------------------------------------------
#  gpt.ini LESEN UND SCHREIBEN
#  Version: oberes 16-Bit-Wort = Benutzerteil, unteres =
#  Maschinenteil. Ist der Maschinenteil 0, gilt die lokale
#  Richtlinie für den Rechner als leer.
# --------------------------------------------------------------
function Read-OrcaGptIni {
    $erg = @{ Da = $false; Zeilen = (New-Object System.Collections.ArrayList); Version = 0; Erweiterungen = '' }
    if (-not (Test-Path -LiteralPath $Global:OrcaGptIni)) { return $erg }
    $erg.Da = $true
    foreach ($z in (Get-Content -LiteralPath $Global:OrcaGptIni -Force -ErrorAction SilentlyContinue)) {
        [void]$erg.Zeilen.Add($z)
        if ($z -match '^\s*Version\s*=\s*(\d+)\s*$') { $erg.Version = [int64]$matches[1] }
        if ($z -match '^\s*gPCMachineExtensionNames\s*=\s*(.*)$') { $erg.Erweiterungen = $matches[1].Trim() }
    }
    return $erg
}

function Get-OrcaGptPaare {
    # "[{A}{B}][{C}{D}]" -> @('[{A}{B}]', '[{C}{D}]')
    param([string]$Text)
    return @([regex]::Matches([string]$Text, '\[[^\]]*\]') | ForEach-Object { $_.Value.ToUpper() })
}

function Join-OrcaGptPaare {
    # gpedit führt die Paare nach der ersten Kennung sortiert.
    param([string[]]$Paare)
    return ((@($Paare) | Where-Object { $_ } | Select-Object -Unique | Sort-Object) -join '')
}

function Write-OrcaGptIni {
    param([Parameter(Mandatory)][int64]$Version, [string]$Erweiterungen)
    $alt = Read-OrcaGptIni
    $neu = New-Object System.Collections.ArrayList
    $hatVersion = $false; $hatErw = $false; $hatGeneral = $false

    foreach ($z in $alt.Zeilen) {
        if ($z -match '^\s*\[General\]\s*$') { $hatGeneral = $true; [void]$neu.Add('[General]'); continue }
        if ($z -match '^\s*Version\s*=') { [void]$neu.Add("Version=$Version"); $hatVersion = $true; continue }
        if ($z -match '^\s*gPCMachineExtensionNames\s*=') {
            if ($Erweiterungen) { [void]$neu.Add("gPCMachineExtensionNames=$Erweiterungen") }
            $hatErw = $true; continue
        }
        [void]$neu.Add($z)
    }
    if (-not $hatGeneral) {
        $neu.Insert(0, '[General]')
        $neu.Insert(1, 'gPCFunctionalityVersion=2')
    }
    if (-not $hatErw -and $Erweiterungen) { [void]$neu.Add("gPCMachineExtensionNames=$Erweiterungen") }
    if (-not $hatVersion) { [void]$neu.Add("Version=$Version") }

    Set-Content -LiteralPath $Global:OrcaGptIni -Value $neu -Encoding ASCII -Force -ErrorAction Stop
}

function Get-OrcaNeueGptVersion {
    # Maschinenteil um eins erhöhen, Benutzerteil unverändert.
    param([int64]$Alt)
    $benutzer = $Alt -band 0xFFFF0000
    $maschine = (($Alt -band 0xFFFF) + 1) -band 0xFFFF
    if ($maschine -eq 0) { $maschine = 1 }
    return ($benutzer -bor $maschine)
}

# --------------------------------------------------------------
#  STAND DER REGISTRIERUNG MESSEN
#  Vier Teile, und nur alle vier zusammen bedeuten "läuft beim
#  Herunterfahren":
#    Datei     die .cmd liegt im Skriptordner der Richtlinie
#    IniZeile  scripts.ini nennt sie im Abschnitt [Shutdown]
#    GptIni    gpt.ini führt die Skript-Erweiterung, Maschinen-
#              version größer 0 - sonst gilt die Richtlinie als leer
#    Windows   die Richtlinienverarbeitung hat das Skript in ihren
#              eigenen Zweig übernommen. Diesen Zweig schreibt nur
#              Windows; OrcaShield liest ihn ausschließlich.
#  Dazu, rein informativ, wann Windows das Skript zuletzt
#  ausgeführt hat (ExecTime, von Windows selbst gepflegt).
# --------------------------------------------------------------
function Get-OrcaShutdownRegistrierung {
    $erg = @{
        Datei = $false; IniZeile = $false; GptIni = $false; Windows = $false
        Index = $null;  Vollstaendig = $false; Pfad = ''; ZuletztAusgefuehrt = $null
    }

    try {
        $shutPfad  = Join-Path $Global:OrcaGpScripts 'Shutdown'
        $erg.Pfad  = Join-Path $shutPfad $Global:OrcaShutdownCmd
        $erg.Datei = Test-Path -LiteralPath $erg.Pfad

        $ini = Join-Path $Global:OrcaGpScripts 'scripts.ini'
        $abschnitte = Read-OrcaScriptsIni -Pfad $ini
        if ($null -eq $abschnitte) { $abschnitte = New-Object System.Collections.ArrayList }
        $shutdown = $abschnitte | Where-Object { $_.Abschnitt -eq 'Shutdown' } | Select-Object -First 1
        if ($shutdown) {
            foreach ($z in @($shutdown.Zeilen)) {
                if ($z -match '^(\d+)CmdLine\s*=\s*(.*)$' -and
                    $matches[2].Trim() -like "*$($Global:OrcaShutdownCmd)") {
                    $erg.Index = [int]$matches[1]
                    $erg.IniZeile = $true
                }
            }
        }

        $gpt = Read-OrcaGptIni
        $erg.GptIni = ($gpt.Da -and ($gpt.Version -band 0xFFFF) -gt 0 -and
                       ((Get-OrcaGptPaare -Text $gpt.Erweiterungen) -contains $Global:OrcaGpSkriptPaar.ToUpper()))

        foreach ($basis in @($Global:OrcaGpRegWindows, $Global:OrcaGpRegBasis)) {
            if (-not (Test-Path -LiteralPath $basis)) { continue }
            foreach ($gpo in @(Get-ChildItem -LiteralPath $basis -ErrorAction SilentlyContinue)) {
                foreach ($k in @(Get-ChildItem -LiteralPath $gpo.PSPath -ErrorAction SilentlyContinue)) {
                    $s = Get-OrcaRegWert -Pfad $k.PSPath -Name 'Script'
                    if (-not ($s -and ([string]$s -like "*$($Global:OrcaShutdownCmd)"))) { continue }
                    if ($basis -eq $Global:OrcaGpRegWindows) {
                        $erg.Windows = $true
                    } else {
                        $t = Get-OrcaRegWert -Pfad $k.PSPath -Name 'ExecTime'
                        if ($t -and [int64]$t -gt 0) {
                            try { $erg.ZuletztAusgefuehrt = [datetime]::FromFileTime([int64]$t) } catch { }
                        }
                    }
                }
            }
        }
    }
    catch { }

    $erg.Vollstaendig = ($erg.Datei -and $erg.IniZeile -and $erg.GptIni -and $erg.Windows)
    return $erg
}

function Get-OrcaShutdownFehlteil {
    # Klartext für die Ausgabe: was genau fehlt.
    param([Parameter(Mandatory)]$Stand)
    $fehlt = @()
    if (-not $Stand.Datei)    { $fehlt += 'die Startdatei' }
    if (-not $Stand.IniZeile) { $fehlt += 'der Eintrag in scripts.ini' }
    if (-not $Stand.GptIni)   { $fehlt += 'der Eintrag im Inhaltsverzeichnis gpt.ini' }
    if (-not $Stand.Windows)  { $fehlt += 'die Übernahme durch Windows' }
    if ($fehlt.Count -eq 0) { return '' }
    if ($fehlt.Count -eq 1) { return $fehlt[0] }
    return (($fehlt[0..($fehlt.Count - 2)] -join ', ') + ' und ' + $fehlt[-1])
}

# --------------------------------------------------------------
#  EINTRAGEN
#  Rückgabe: @{ Erfolg; Übernommen; Index; Pfad; Grund }
#    Erfolg       alle Dateien geschrieben
#    Übernommen  Windows hat das Skript in seine Verarbeitung
#                 aufgenommen - erst dann läuft es wirklich
# --------------------------------------------------------------
function Register-OrcaShutdownSkript {
    param([Parameter(Mandatory)][string]$Quelle)

    try {
        $shutPfad = Join-Path $Global:OrcaGpScripts 'Shutdown'
        foreach ($p in @($Global:OrcaGpScripts, $shutPfad)) {
            if (-not (Test-Path $p)) { New-Item -Path $p -ItemType Directory -Force -ErrorAction Stop | Out-Null }
        }

        $starter = Join-Path $shutPfad $Global:OrcaShutdownCmd
        $cmdInhalt = "@echo off`r`npowershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Quelle`"`r`n"
        Set-Content -LiteralPath $starter -Value $cmdInhalt -Encoding ASCII -ErrorAction Stop

        # --- scripts.ini ergänzen statt ersetzen ---
        $ini = Join-Path $Global:OrcaGpScripts 'scripts.ini'
        $abschnitte = Read-OrcaScriptsIni -Pfad $ini
        if ($null -eq $abschnitte) { $abschnitte = New-Object System.Collections.ArrayList }
        $shutdown = $abschnitte | Where-Object { $_.Abschnitt -eq 'Shutdown' } | Select-Object -First 1
        if (-not $shutdown) {
            $shutdown = @{ Abschnitt = 'Shutdown'; Zeilen = New-Object System.Collections.ArrayList }
            [void]$abschnitte.Add($shutdown)
        }

        # Eigenen Eintrag suchen; sonst nächsten freien Index nehmen.
        $index = $null
        $belegt = @()
        foreach ($z in @($shutdown.Zeilen)) {
            if ($z -match '^(\d+)CmdLine\s*=\s*(.*)$') {
                $belegt += [int]$matches[1]
                if ($matches[2].Trim() -like "*$($Global:OrcaShutdownCmd)") { $index = [int]$matches[1] }
            }
        }
        if ($null -eq $index) {
            $index = 0
            while ($belegt -contains $index) { $index++ }
        }

        # Eigene Zeilen neu schreiben, fremde unangetastet lassen
        $neu = New-Object System.Collections.ArrayList
        foreach ($z in @($shutdown.Zeilen)) {
            if ($z -match "^$index(CmdLine|Parameters)\s*=") { continue }
            [void]$neu.Add($z)
        }
        [void]$neu.Add("${index}CmdLine=$starter")
        [void]$neu.Add("${index}Parameters=")
        $shutdown.Zeilen = $neu

        Write-OrcaScriptsIni -Pfad $ini -Abschnitte $abschnitte

        # --- gpt.ini: Version hoch, Skript-Erweiterung eintragen ---
        $gpt = Read-OrcaGptIni
        $paare = @(Get-OrcaGptPaare -Text $gpt.Erweiterungen) + @($Global:OrcaGpSkriptPaar.ToUpper())
        Write-OrcaGptIni -Version (Get-OrcaNeueGptVersion -Alt $gpt.Version) -Erweiterungen (Join-OrcaGptPaare -Paare $paare)

        # --- Windows übernehmen lassen ---
        $rc = Invoke-OrcaProgramm -Datei 'gpupdate.exe' -Argumente '/force /target:computer'

        $stand = Get-OrcaShutdownRegistrierung
        $grund = ''
        if (-not $stand.Vollstaendig) {
            $grund = "es fehlt $(Get-OrcaShutdownFehlteil -Stand $stand) (gpupdate meldete $rc)"
        }
        return @{ Erfolg = $true; Uebernommen = $stand.Vollstaendig; Index = $index; Pfad = $starter; Grund = $grund }
    }
    catch {
        return @{ Erfolg = $false; Uebernommen = $false; Index = $null; Pfad = $null; Grund = $_.Exception.Message }
    }
}

# --------------------------------------------------------------
#  AUSTRAGEN
#  Nur die eigene Zeile. Die Skript-Erweiterung verschwindet aus
#  gpt.ini nur dann, wenn danach weder ein Start- noch ein
#  Herunterfahren-Skript mehr eingetragen ist - sonst liefe ein
#  fremdes Skript nicht mehr.
# --------------------------------------------------------------
function Unregister-OrcaShutdownSkript {
    try {
        $shutPfad = Join-Path $Global:OrcaGpScripts 'Shutdown'
        $starter  = Join-Path $shutPfad $Global:OrcaShutdownCmd
        $ini      = Join-Path $Global:OrcaGpScripts 'scripts.ini'

        $abschnitte = Read-OrcaScriptsIni -Pfad $ini
        if ($null -eq $abschnitte) { $abschnitte = New-Object System.Collections.ArrayList }
        $shutdown = $abschnitte | Where-Object { $_.Abschnitt -eq 'Shutdown' } | Select-Object -First 1
        if ($shutdown) {
            $index = $null
            foreach ($z in @($shutdown.Zeilen)) {
                if ($z -match '^(\d+)CmdLine\s*=\s*(.*)$' -and $matches[2].Trim() -like "*$($Global:OrcaShutdownCmd)") {
                    $index = [int]$matches[1]
                }
            }
            if ($null -ne $index) {
                $neu = New-Object System.Collections.ArrayList
                foreach ($z in @($shutdown.Zeilen)) {
                    if ($z -match "^$index(CmdLine|Parameters)\s*=") { continue }
                    [void]$neu.Add($z)
                }
                $shutdown.Zeilen = $neu
                Write-OrcaScriptsIni -Pfad $ini -Abschnitte $abschnitte
            }
        }

        if (Test-Path $starter) { Remove-Item -LiteralPath $starter -Force -ErrorAction SilentlyContinue }

        # Bleibt irgendein Skript eingetragen, bleibt auch die Erweiterung.
        $nochSkripte = $false
        foreach ($a in $abschnitte) {
            if ($a.Abschnitt -in @('Shutdown','Startup') -and
                @($a.Zeilen | Where-Object { $_ -match '^\d+CmdLine\s*=' }).Count -gt 0) { $nochSkripte = $true }
        }
        $gpt = Read-OrcaGptIni
        if ($gpt.Da) {
            $paare = @(Get-OrcaGptPaare -Text $gpt.Erweiterungen)
            if (-not $nochSkripte) { $paare = @($paare | Where-Object { $_ -ne $Global:OrcaGpSkriptPaar.ToUpper() }) }
            Write-OrcaGptIni -Version (Get-OrcaNeueGptVersion -Alt $gpt.Version) -Erweiterungen (Join-OrcaGptPaare -Paare $paare)
        }

        $auslagerung = $false
        $mm = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
        if ([int](Get-OrcaRegWert -Pfad $mm -Name 'ClearPageFileAtShutdown') -eq 1) {
            [void](Set-OrcaRegWert -Pfad $mm -Name 'ClearPageFileAtShutdown' -Wert 0)
            $auslagerung = $true
        }

        Invoke-OrcaProgramm -Datei 'gpupdate.exe' -Argumente '/force /target:computer' | Out-Null
        return @{ Erfolg = $true; Grund = ''; Auslagerung = $auslagerung }
    }
    catch {
        return @{ Erfolg = $false; Grund = $_.Exception.Message }
    }
}

$Global:OrcaAufgabeWaechter = 'OrcaShield-Waechter'
$Global:OrcaAlteAufgaben    = @('OrcaShield-Waechter-Start', 'OrcaShield-Waechter-Benutzer', 'OrcaShield-Erstpruefung')

function Register-OrcaWaechterAufgabe {
    param([Parameter(Mandatory)][string]$Konto)
    try {
        $pfad = Join-Path $Global:OrcaSkripte 'Orca-Waechter.ps1'
        $aktion = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\conhost.exe" `
                    -Argument "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$pfad`""
        $ausloeser = New-ScheduledTaskTrigger -AtLogOn -User $Konto
        $ausloeser.Delay = 'PT10S'
        $prinzipal = New-ScheduledTaskPrincipal -UserId $Konto -LogonType Interactive -RunLevel Highest
        $optionen  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                        -StartWhenAvailable -MultipleInstances IgnoreNew `
                        -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

        Register-ScheduledTask -TaskName $Global:OrcaAufgabeWaechter `
            -Action $aktion -Trigger $ausloeser -Principal $prinzipal -Settings $optionen `
            -Description 'OrcaShield: prüft nach jeder Anmeldung Datenschutzeinstellungen, Defender, Herunterfahren-Wächter und Schreibrechte und zeigt das Ergebnis.' `
            -Force -ErrorAction Stop | Out-Null
        return @{ Erfolg = $true; Grund = '' }
    }
    catch {
        return @{ Erfolg = $false; Grund = $_.Exception.Message }
    }
}

function Get-OrcaWaechterAufgabe {
    # Rückgabe: @{ Da; Aktiv; Konto; Erhoeht; Ziel }
    $erg = @{ Da = $false; Aktiv = $false; Konto = ''; Erhoeht = $false; Ziel = '' }
    $t = Get-ScheduledTask -TaskName $Global:OrcaAufgabeWaechter -ErrorAction SilentlyContinue
    if (-not $t) { return $erg }
    $erg.Da      = $true
    $erg.Aktiv   = ($t.State -ne 'Disabled')
    $erg.Konto   = [string]$t.Principal.UserId
    $erg.Erhoeht = ([string]$t.Principal.RunLevel -eq 'Highest')
    $erg.Ziel    = (@($t.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' ; ')
    return $erg
}

function Remove-OrcaAlteAufgaben {
    # Rückgabe: Liste der entfernten Aufgaben
    $weg = @()
    foreach ($name in $Global:OrcaAlteAufgaben) {
        $t = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
        if (-not $t) { continue }
        try {
            Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction Stop
            $weg += $name
        } catch {
            Write-OrcaLog -Level FEHLER -Source 'INFRA' -Message "Alte Aufgabe $name nicht entfernbar. Grund: $($_.Exception.Message)"
        }
    }
    return $weg
}

# --------------------------------------------------------------
#  COMPUTERSCHUTZ (SYSTEMWIEDERHERSTELLUNG) FÜR DAS SYSTEMLAUFWERK
#  Windows führt die geschützten Laufwerke unter SPP\Clients im
#  Wert {09F7EDC5-...}: je Laufwerk eine Zeile mit Volume-Kennung
#  und Laufwerksbuchstaben, etwa "\\?\Volume{...}\:(C%3A)". Steht C:
#  dort nicht, ist der Schutz für C: aus. Eine Richtlinie
#  (DisableSR) schaltet ihn unabhängig davon ab.
#  Rückgabe: @{ An; Kopien; Text } - wirft, wenn nicht lesbar.
# --------------------------------------------------------------
function Get-OrcaComputerschutz {
    $lw = $env:SystemDrive
    $vol = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter='$lw'" -ErrorAction Stop | Select-Object -First 1
    $guid = if ($vol -and $vol.DeviceID -match '\{[0-9A-Fa-f-]+\}') { $matches[0] } else { '' }

    $an = $false
    $clients = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SPP\Clients'
    if (Test-Path -LiteralPath $clients) {
        $k = Get-ItemProperty -LiteralPath $clients -ErrorAction Stop
        $zeilen = @($k.'{09F7EDC5-294E-4180-AF6A-FB0E6A0E9513}' | Where-Object { $_ })
        $an = @($zeilen | Where-Object { ($guid -and $_ -like "*$guid*") -or $_ -like "*($($lw.Substring(0,1))%3A)*" }).Count -gt 0
    }
    $pol = Get-OrcaRegWert -Pfad 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore' -Name 'DisableSR'
    if ([int]$pol -eq 1) { $an = $false }

    $kopien = @(Get-OrcaSchattenkopien -Laufwerk $lw).Count
    $text = "$(if ($an) { 'an' } else { 'aus' }) · $kopien $(if ($kopien -eq 1) { 'Schattenkopie' } else { 'Schattenkopien' }) auf $lw"
    return @{ An = $an; Kopien = $kopien; Text = $text }
}

function Get-OrcaDefenderLage {
    param($BekannteAusnahmen = $null, $FundeSeit = $null)
    $b = New-Object System.Collections.ArrayList
    $neueAusnahmen = @()
    $alleAusnahmen = @()
    $fundeBis = Get-Date

    try {
        $st = Get-MpComputerStatus -ErrorAction Stop
    } catch {
        [void]$b.Add(@{ Stufe = 'ALARM'; Text = "Defender-Status nicht abrufbar: $($_.Exception.Message)" })
        return @{ Befunde = $b; Ausnahmen = @(); Neu = @(); FundeBis = $null }
    }

    $aus = @()
    if (-not $st.AMServiceEnabled)          { $aus += 'Dienst' }
    if (-not $st.AntivirusEnabled)          { $aus += 'Virenschutz' }
    if (-not $st.RealTimeProtectionEnabled) { $aus += 'Echtzeitschutz' }
    if (-not $st.BehaviorMonitorEnabled)    { $aus += 'Verhaltensüberwachung' }
    if (-not $st.IoavProtectionEnabled)     { $aus += 'Download-Prüfung' }
    if (-not $st.OnAccessProtectionEnabled) { $aus += 'Prüfung beim Zugriff' }
    if ($aus.Count -gt 0) {
        [void]$b.Add(@{ Stufe = 'ALARM'; Text = "Defender teilweise AUS: $($aus -join ', ')" })
    } else {
        [void]$b.Add(@{ Stufe = 'OK'; Text = 'Echtzeit, Verhalten, Zugriff, Downloads aktiv' })
    }

    if ($st.IsTamperProtected -ne $true) {
        [void]$b.Add(@{ Stufe = 'ALARM'; Text = 'Manipulationsschutz ist AUS' })
    } else {
        [void]$b.Add(@{ Stufe = 'OK'; Text = 'Manipulationsschutz an' })
    }

    if ($st.AntivirusSignatureAge -gt 3) {
        [void]$b.Add(@{ Stufe = 'WARN'; Text = "Virensignaturen $($st.AntivirusSignatureAge) Tage alt" })
    }

    # Richtlinien, die Teile von Defender abschalten
    $pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
    $gesetzt = @()
    foreach ($w in @('DisableAntiSpyware', 'DisableAntiVirus')) {
        if ([int](Get-OrcaRegWert -Pfad $pol -Name $w) -eq 1) { $gesetzt += $w }
    }
    foreach ($w in @('DisableRealtimeMonitoring', 'DisableBehaviorMonitoring', 'DisableOnAccessProtection',
                     'DisableIOAVProtection', 'DisableScanOnRealtimeEnable')) {
        if ([int](Get-OrcaRegWert -Pfad "$pol\Real-Time Protection" -Name $w) -eq 1) { $gesetzt += $w }
    }
    if ($gesetzt.Count -gt 0) {
        [void]$b.Add(@{ Stufe = 'ALARM'; Text = "Richtlinie schaltet Defender-Teile ab: $($gesetzt -join ', ')" })
    }

    # Ausnahmen
    try {
        $p = Get-MpPreference -ErrorAction Stop
        $roh = @()
        foreach ($e in @($p.ExclusionPath))      { if ($e) { $roh += "Ordner: $e" } }
        foreach ($e in @($p.ExclusionProcess))   { if ($e) { $roh += "Programm: $e" } }
        foreach ($e in @($p.ExclusionExtension)) { if ($e) { $roh += "Endung: $e" } }
        foreach ($e in @($p.ExclusionIpAddress)) { if ($e) { $roh += "Adresse: $e" } }
        if (@($roh | Where-Object { $_ -match ': N/A' }).Count -gt 0) {
            [void]$b.Add(@{ Stufe = 'WARN'; Text = 'Ausnahmen nicht lesbar (keine Administratorrechte)' })
        } else {
            $alleAusnahmen = @($roh | Sort-Object)
            if ($null -ne $BekannteAusnahmen) {
                $neueAusnahmen = @($alleAusnahmen | Where-Object { $_ -notin @($BekannteAusnahmen) })
            }
            if ($neueAusnahmen.Count -gt 0) {
                [void]$b.Add(@{ Stufe = 'ALARM'; Text = "NEUE Defender-Ausnahme: $($neueAusnahmen -join ' | ')" })
            } else {
                [void]$b.Add(@{ Stufe = 'OK'; Text = "$($alleAusnahmen.Count) Ausnahmen, keine neue" })
            }
        }
    } catch {
        [void]$b.Add(@{ Stufe = 'WARN'; Text = "Ausnahmen nicht lesbar: $($_.Exception.Message)" })
    }

    # Funde
    try {
        $funde = @(Get-MpThreatDetection -ErrorAction Stop)
        $namen = @{}
        foreach ($t in @(Get-MpThreat -ErrorAction SilentlyContinue)) { $namen[[string]$t.ThreatID] = $t.ThreatName }
        if ($null -eq $FundeSeit) {
            if ($funde.Count -gt 0) {
                $letzter = $funde | Sort-Object InitialDetectionTime | Select-Object -Last 1
                [void]$b.Add(@{ Stufe = 'INFO'; Text = "$($funde.Count) frühere Funde, zuletzt $($namen[[string]$letzter.ThreatID]) am $($letzter.InitialDetectionTime.ToString('dd.MM. HH:mm')) - ab jetzt wird jeder neue gemeldet" })
            }
        } else {
            $neu = @($funde | Where-Object { $_.InitialDetectionTime -gt $FundeSeit } | Sort-Object InitialDetectionTime)
            foreach ($f in $neu) {
                $name = if ($namen.ContainsKey([string]$f.ThreatID)) { $namen[[string]$f.ThreatID] } else { "Kennung $($f.ThreatID)" }
                $wo = (@($f.Resources) | Select-Object -First 1) -replace '^\w+:_', ''
                $erg = if ($f.ActionSuccess) { 'unschädlich gemacht' } else { 'NICHT unschädlich gemacht' }
                [void]$b.Add(@{ Stufe = 'ALARM'; Text = "Fund am $($f.InitialDetectionTime.ToString('dd.MM. HH:mm')): $name ($erg) - $wo" })
            }
            if ($neu.Count -eq 0) { [void]$b.Add(@{ Stufe = 'OK'; Text = 'keine neuen Funde' }) }
        }
    } catch {
        [void]$b.Add(@{ Stufe = 'WARN'; Text = "Funde nicht lesbar: $($_.Exception.Message)" })
        $fundeBis = $null
    }

    # Fremder Virenschutz
    try {
        $av = @(Get-CimInstance -Namespace 'root\SecurityCenter2' -ClassName AntiVirusProduct -ErrorAction Stop)
        $fremd = @($av | Where-Object { $_.displayName -notmatch 'Defender' } | ForEach-Object { $_.displayName })
        if ($fremd.Count -gt 0) {
            [void]$b.Add(@{ Stufe = 'ALARM'; Text = "Weiteres Virenschutzprogramm angemeldet: $($fremd -join ', ')" })
        }
    } catch { }

    # Firewall
    try {
        $fw = @(Get-NetFirewallProfile -ErrorAction Stop)
        $zu = @($fw | Where-Object { -not $_.Enabled } | ForEach-Object { $_.Name })
        if ($zu.Count -gt 0) {
            [void]$b.Add(@{ Stufe = 'ALARM'; Text = "Firewall AUS im Profil: $($zu -join ', ')" })
        } else {
            [void]$b.Add(@{ Stufe = 'OK'; Text = 'Firewall in allen Profilen an' })
        }
    } catch {
        [void]$b.Add(@{ Stufe = 'WARN'; Text = "Firewall-Zustand nicht lesbar: $($_.Exception.Message)" })
    }

    return @{ Befunde = $b; Ausnahmen = $alleAusnahmen; Neu = $neueAusnahmen; FundeBis = $fundeBis }
}

# --------------------------------------------------------------
#  LIEF DER HERUNTERFAHREN-WAECHTER BEIM LETZTEN HERUNTERFAHREN?
#  Zwei unabhängige Quellen: der Zeitstempel, den der Wächter
#  selbst schreibt, und das Systemprotokoll (Ereignis 13 von
#  Kernel-General: "Das Betriebssystem wird heruntergefahren").
#  Fehlt das Ereignis vor dem letzten Start, wurde der Rechner
#  nicht sauber heruntergefahren - Stromausfall, Absturz,
#  Ausschalter. Dann konnte auch kein Skript laufen.
#  Rückgabe: @{ Stufe; Text }
# --------------------------------------------------------------
function Get-OrcaShutdownNachweis {
    param($State)
    $letzterLauf = ConvertFrom-OrcaZeitstempel -Text $State.LetzterShutdownlauf -Ersatz ([datetime]::MinValue)
    try {
        $start = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime
        $ev = Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-General'; Id = 13 } `
                -MaxEvents 10 -ErrorAction Stop |
              Where-Object { $_.TimeCreated -lt $start } | Select-Object -First 1
    } catch {
        $ev = $null; $start = $null
    }

    if ($letzterLauf -eq [datetime]::MinValue) {
        return @{ Stufe = 'WARN'; Text = 'noch nie gelaufen' }
    }
    if (-not $ev) {
        return @{ Stufe = 'WARN'; Text = "letzter Lauf $($letzterLauf.ToString('dd.MM. HH:mm')) - zuletzt nicht sauber heruntergefahren" }
    }
    $herunter = $ev.TimeCreated
    # Das Skript läuft VOR dem Ereignis 13, wenige Sekunden bis
    # Minuten davor (Papierkorb, Schattenkopien, Auslagerungsdatei).
    if ($letzterLauf -le $herunter -and $letzterLauf -ge $herunter.AddMinutes(-20)) {
        return @{ Stufe = 'OK'; Text = "lief beim Herunterfahren am $($herunter.ToString('dd.MM. HH:mm'))" }
    }
    return @{ Stufe = 'WARN'; Text = "lief beim Herunterfahren am $($herunter.ToString('dd.MM. HH:mm')) NICHT (zuletzt $($letzterLauf.ToString('dd.MM. HH:mm')))" }
}

function Get-OrcaEdgePfad {
    foreach ($basis in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
        if (-not $basis) { continue }
        $p = Join-Path $basis 'Microsoft\Edge\Application\msedge.exe'
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

function Remove-OrcaEdge {
    $exe = Get-OrcaEdgePfad
    if (-not $exe) { return @{ Erfolg = $true; Grund = 'nicht vorhanden' } }
    $app = Split-Path $exe -Parent
    $setup = Get-ChildItem -Path (Join-Path $app '*\Installer\setup.exe') -ErrorAction SilentlyContinue |
             Sort-Object FullName -Descending | Select-Object -First 1
    if (-not $setup) { return @{ Erfolg = $false; Grund = 'Deinstallationsprogramm von Edge nicht gefunden' } }
    $rc = Invoke-OrcaProgramm -Datei $setup.FullName -Argumente '--uninstall --system-level --force-uninstall'
    Start-Sleep -Seconds 2
    if (Get-OrcaEdgePfad) {
        return @{ Erfolg = $false; Grund = "Edge ist nach der Deinstallation noch da (Rückgabewert $rc)" }
    }
    Write-OrcaLog -Level OK -Source 'APPS' -Message 'Microsoft Edge erneut deinstalliert'
    return @{ Erfolg = $true; Grund = '' }
}

# --------------------------------------------------------------
#  WARUM LÄUFT DER HYPERVISOR?
#  Steht hypervisorlaunchtype auf Off und läuft er trotzdem,
#  startet ihn eine eingeschaltete Windows-Funktion. Rein lesend.
# --------------------------------------------------------------
function Get-OrcaHypervisorUrsache {
    $laeuft = $false
    try { $laeuft = [bool](Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).HypervisorPresent } catch { }
    if (-not $laeuft) { return @{ Laeuft = $false; Ursachen = @() } }
    $ursachen = @()
    foreach ($f in @('Microsoft-Hyper-V-All', 'Microsoft-Hyper-V-Hypervisor', 'VirtualMachinePlatform',
                     'HypervisorPlatform', 'Microsoft-Windows-Subsystem-Linux', 'Containers-DisposableClientVM')) {
        try {
            $x = Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction Stop
            if ($x -and [string]$x.State -eq 'Enabled') { $ursachen += $f }
        } catch { }
    }
    if ([int](Get-OrcaRegWert -Pfad 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello' -Name 'Enabled') -eq 1) {
        $ursachen += 'Windows Hello: erweiterte Anmeldesicherheit'
    }
    try {
        $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace 'root\Microsoft\Windows\DeviceGuard' -ErrorAction Stop
        if ([int]$dg.VirtualizationBasedSecurityStatus -eq 2 -and $ursachen.Count -eq 0) { $ursachen += 'VBS läuft (Device Guard), Ursache unbekannt' }
    } catch { }
    return @{ Laeuft = $true; Ursachen = $ursachen }
}

function Invoke-OrcaKatalogMigration {
    param([Parameter(Mandatory)]$State)

    $meldungen = New-Object System.Collections.ArrayList
    $alt = @($State.AktiveEinstellungen)
    $neu = New-Object System.Collections.ArrayList
    $apps = New-Object System.Collections.ArrayList
    foreach ($a in @($State.EntfernteApps)) { if ($a) { [void]$apps.Add([string]$a) } }
    $appsGeaendert = $false

    foreach ($id in $alt) {
        $s = Get-OrcaSettingById -Id $id
        if (-not $s) {
            [void]$meldungen.Add("$id gibt es im Katalog nicht mehr - aus der Liste genommen")
            continue
        }
        if (-not $s.Ausgemustert) {
            if (-not $neu.Contains($id)) { [void]$neu.Add($id) }
            continue
        }

        if (@($s.ErsetztDurch).Count -eq 0) {
            $r = Reset-OrcaSetting -Setting $s
            $was = if ($r.Erfolg) { "zurückgenommen ($($r.Grund))" } else { "Zurücknehmen FEHLGESCHLAGEN: $($r.Grund)" }
            [void]$meldungen.Add("$id $($s.Name): $was")
            Write-OrcaLog -Level $(if ($r.Erfolg) { 'OK' } else { 'FEHLER' }) -Source 'MIGRATION' -Message "$id $($s.Name): $was"
            continue
        }

        foreach ($n in @($s.ErsetztDurch)) {
            if ($n -like 'APP:*') {
                $appId = $n.Substring(4)
                $app = $Global:OrcaApps | Where-Object { $_.Id -eq $appId } | Select-Object -First 1
                if (-not $app) { continue }
                $r = Remove-OrcaApp -App $app
                if ($r.Erfolg -and -not $apps.Contains($appId)) { [void]$apps.Add($appId); $appsGeaendert = $true }
                $was = if ($r.Erfolg) { "ersetzt durch Entfernen von $($app.Anzeige)" } else { "Entfernen von $($app.Anzeige) FEHLGESCHLAGEN: $($r.Grund)" }
                [void]$meldungen.Add("$id $($s.Name): $was")
                Write-OrcaLog -Level $(if ($r.Erfolg) { 'OK' } else { 'FEHLER' }) -Source 'MIGRATION' -Message "$id $($s.Name): $was"
            } else {
                $nach = Get-OrcaSettingById -Id $n
                if (-not $nach) { continue }
                Save-OrcaBaseline -Settings @($nach) -Leise | Out-Null
                $r = Set-OrcaSetting -Setting $nach
                if (-not $neu.Contains($n)) { [void]$neu.Add($n) }
                $was = "ersetzt durch $n $($nach.Name) ($($r.Status))"
                [void]$meldungen.Add("$id $($s.Name): $was")
                Write-OrcaLog -Level $(if ($r.Erfolg) { 'OK' } else { 'FEHLER' }) -Source 'MIGRATION' -Message "$id $($s.Name): $was"
            }
        }
    }

    $vorher = ($alt | Sort-Object) -join ','
    $nachher = (@($neu) | Sort-Object) -join ','
    if ($vorher -ne $nachher) {
        Set-OrcaStateFeld -Name 'AktiveEinstellungen' -Wert @($neu) | Out-Null
    }
    if ($appsGeaendert) {
        Set-OrcaStateFeld -Name 'EntfernteApps' -Wert @($apps) | Out-Null
    }
    return ,$meldungen
}

# ==============================================================
#  TEIL 11 - HILFEN FÜR DIE NEUEN PUNKTTYPEN
# ==============================================================

# --------------------------------------------------------------
#  BENÖTIGT VON
#  Liefert die Klartextnamen der Abhängigkeiten eines Punktes,
#  die auf diesem Rechner vorhanden sind (Feld BenoetigtVon im
#  Katalog). Leer = keine. Vorhanden heißt installiert, nicht
#  laufend: Meta Horizon stellt LLMNR auch um, wenn die Brille
#  gerade nicht angeschlossen ist.
# --------------------------------------------------------------
function Get-OrcaBenoetigtVon {
    param([Parameter(Mandatory)]$Setting)
    $treffer = New-Object System.Collections.ArrayList
    foreach ($b in @($Setting.BenoetigtVon)) {
        if (-not $b) { continue }
        $da = $false
        try {
            switch ($b.Art) {
                'Dienst'   { $da = [bool](Get-Service -Name $b.Name -ErrorAction SilentlyContinue) }
                'Programm' { $da = Test-Path -LiteralPath ([Environment]::ExpandEnvironmentVariables($b.Name)) }
                'Geraet'   {
                    $da = [bool](Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction Stop |
                                 Where-Object { $_.Name -like "*$($b.Name)*" } | Select-Object -First 1)
                }
            }
        } catch { $da = $false }
        if ($da -and -not $treffer.Contains([string]$b.Anzeige)) { [void]$treffer.Add([string]$b.Anzeige) }
    }
    return ,$treffer
}

# StartupApproved: erstes Byte ungerade = im Autostart abgeschaltet
# (02 = an, 03 = vom Benutzer abgeschaltet, 06/07 entsprechend).
function Test-OrcaAutostartAus {
    param($Wert)
    try {
        [byte[]]$b = @($Wert | ForEach-Object { [byte]$_ })
        return ($b.Count -gt 0 -and ($b[0] -band 1) -eq 1)
    } catch { return $false }
}

# --------------------------------------------------------------
#  DNS
#  Gesetzt wird nur auf echten Netzwerkkarten, nicht auf den
#  virtuellen Adaptern von VPN oder VirtualBox - deren DNS soll
#  bleiben, wie das jeweilige Programm es will.
#  Verschlüsselung: Windows führt eine Tabelle bekannter
#  DNS-over-HTTPS-Server, Quad9 steht schon darin. Für diese vier
#  Adressen wird "automatisch verschlüsseln" an- und der Rückfall
#  auf unverschlüsseltes DNS abgeschaltet. Das ist derselbe Weg
#  wie in den Einstellungen und sperrt dort nichts.
# --------------------------------------------------------------
$Global:OrcaDohVorlage = 'https://dns.quad9.net/dns-query'

function Get-OrcaDnsAdapter {
    return @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
             Where-Object { $_.InterfaceDescription -notmatch 'Bluetooth' } | Sort-Object Name)
}

function Get-OrcaDnsStand {
    param($Soll = @())
    $soll4 = @(@($Soll) | Where-Object { $_ -notmatch ':' })
    $soll6 = @(@($Soll) | Where-Object { $_ -match ':' })
    $adapter = @{}
    $erfuellt = $true
    $texte = @()
    foreach ($a in (Get-OrcaDnsAdapter)) {
        $guid = [string]$a.InterfaceGuid
        $v4 = [string](Get-OrcaRegWert -Pfad "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid" -Name 'NameServer')
        $v6 = [string](Get-OrcaRegWert -Pfad "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\Interfaces\$guid" -Name 'NameServer')
        # Windows haengt an NameServer teils Nullzeichen an - mit abtrennen.
        $l4 = @($v4 -split '[,\s\x00]+' | Where-Object { $_ })
        $l6 = @($v6 -split '[,\s\x00]+' | Where-Object { $_ })
        $adapter[$guid] = @{ Name = [string]$a.Name; Index = [int]$a.ifIndex; V4 = $l4; V6 = $l6 }
        $v6an = $true
        try { $v6an = [bool](Get-NetAdapterBinding -Name $a.Name -ComponentID 'ms_tcpip6' -ErrorAction Stop).Enabled } catch { }
        $ok = ((($l4 -join ',') -eq ($soll4 -join ',')) -and (-not $v6an -or (($l6 -join ',') -eq ($soll6 -join ','))))
        if (-not $ok) { $erfuellt = $false }
        $texte += "$($a.Name): $(if ($l4.Count) { $l4 -join ', ' } else { 'automatisch' })"
    }
    $doh = @{}
    foreach ($s in @($Soll)) {
        $e = Get-DnsClientDohServerAddress -ServerAddress $s -ErrorAction SilentlyContinue
        if ($e) {
            $doh[$s] = @{ Da = $true; Vorlage = [string]$e.DohTemplate; Auto = [bool]$e.AutoUpgrade; Rueckfall = [bool]$e.AllowFallbackToUdp }
            if (-not $e.AutoUpgrade -or $e.AllowFallbackToUdp) { $erfuellt = $false }
        } else {
            $doh[$s] = @{ Da = $false }
            $erfuellt = $false
        }
    }
    $verschl = @($doh.Values | Where-Object { $_.Da -and $_.Auto -and -not $_.Rueckfall }).Count
    $texte += "verschlüsselt: $verschl von $(@($Soll).Count)"
    return @{ Adapter = $adapter; Doh = $doh; Erfuellt = ($erfuellt -and $adapter.Count -gt 0); Text = ($texte -join ' | ') }
}

function Set-OrcaDns {
    param([Parameter(Mandatory)]$Soll)
    try {
        foreach ($a in (Get-OrcaDnsAdapter)) {
            Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses @($Soll) -ErrorAction Stop
        }
        foreach ($s in @($Soll)) {
            $e = Get-DnsClientDohServerAddress -ServerAddress $s -ErrorAction SilentlyContinue
            if ($e) {
                Set-DnsClientDohServerAddress -ServerAddress $s -DohTemplate $Global:OrcaDohVorlage `
                    -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction Stop | Out-Null
            } else {
                Add-DnsClientDohServerAddress -ServerAddress $s -DohTemplate $Global:OrcaDohVorlage `
                    -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction Stop | Out-Null
            }
        }
        return @{ Erfolg = $true; Grund = '' }
    } catch {
        return @{ Erfolg = $false; Grund = $_.Exception.Message }
    }
}

function Reset-OrcaDns {
    param($Baseline)
    try {
        $gemessen = @{}
        if ($Baseline -and $Baseline.Adapter) {
            foreach ($p in $Baseline.Adapter.PSObject.Properties) { $gemessen[$p.Name] = $p.Value }
        }
        foreach ($a in (Get-OrcaDnsAdapter)) {
            $g = $gemessen[[string]$a.InterfaceGuid]
            $liste = @()
            if ($g) { $liste = @(@($g.V4) + @($g.V6) | Where-Object { $_ }) }
            if ($liste.Count -eq 0) {
                Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses -ErrorAction Stop
            } else {
                Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses $liste -ErrorAction Stop
            }
        }
        if ($Baseline -and $Baseline.Doh) {
            foreach ($p in $Baseline.Doh.PSObject.Properties) {
                $v = $p.Value
                if ($v.Da) {
                    Set-DnsClientDohServerAddress -ServerAddress $p.Name -DohTemplate $v.Vorlage `
                        -AllowFallbackToUdp ([bool]$v.Rueckfall) -AutoUpgrade ([bool]$v.Auto) -ErrorAction Stop | Out-Null
                } else {
                    Remove-DnsClientDohServerAddress -ServerAddress $p.Name -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }
        return @{ Erfolg = $true; Grund = 'DNS je Netzwerkkarte und Verschlüsselung auf den gemessenen Stand zurückgestellt' }
    } catch {
        return @{ Erfolg = $false; Grund = $_.Exception.Message }
    }
}

function Set-OrcaPunktAktiv {
    param([Parameter(Mandatory)]$Setting)
    Save-OrcaBaseline -Settings @($Setting) -Leise | Out-Null
    $r = Set-OrcaSetting -Setting $Setting
    if ($r.Erfolg -and $r.Status -notin @('NichtAnwendbar','NichtVorhanden')) {
        $state = Get-OrcaState
        $liste = @($state.AktiveEinstellungen | Where-Object { $_ })
        if ($Setting.Id -notin $liste) { Set-OrcaStateFeld -Name 'AktiveEinstellungen' -Wert (@($liste) + $Setting.Id) | Out-Null }
    }
    return $r
}

function Reset-OrcaPunkt {
    param([Parameter(Mandatory)]$Setting)
    $r = Reset-OrcaSetting -Setting $Setting
    if ($r.Erfolg) {
        $state = Get-OrcaState
        $liste = @($state.AktiveEinstellungen | Where-Object { $_ -and $_ -ne $Setting.Id })
        Set-OrcaStateFeld -Name 'AktiveEinstellungen' -Wert $liste | Out-Null
    }
    return $r
}

# ==============================================================
#  TEIL 12 - HOSTS-DATEI
#
#  OrcaShield verwaltet genau EINEN markierten Block am Ende der
#  Hosts-Datei. Alles außerhalb gehört dir und bleibt, wie es ist -
#  bis auf eine Ausnahme: Einträge, die OrcaShield in seinen Block
#  übernimmt, werden aus deinem Teil herausgenommen, damit nichts
#  doppelt steht. Was herausgenommen wurde, landet in
#  Backup\Hosts-uebernommen.txt; der Rückbau gibt es zurück.
#
#  Die Listen stehen in Skripte\Orca-Hosts.txt, getrennt nach
#  Abschnitten. Jeder Abschnitt gehört zu einem Katalogpunkt.
#
#  Geschrieben wird vorsichtig: vollständige Sicherung, schreiben,
#  nachlesen. Fehlt danach auch nur eine deiner eigenen Zeilen,
#  wird die Sicherung zurückgelegt.
# ==============================================================
$Global:OrcaHostsDatei   = "$env:SystemRoot\System32\drivers\etc\hosts"
$Global:OrcaHostsListen  = Join-Path $Global:OrcaSkripte 'Orca-Hosts.txt'
$Global:OrcaHostsBeginn  = '# BEGIN OrcaShield - von OrcaShield verwaltet, Aenderungen in diesem Block gehen beim naechsten Waechterlauf verloren'
$Global:OrcaHostsEnde    = '# END OrcaShield'
$Global:OrcaHostsFolge   = @('GDID', 'Konto', 'Microsoft', 'Listen')
$Global:OrcaHostsDoppelt = @('GDID', 'Konto')
# Diese Namen nimmt OrcaShield nie aus deinem Teil heraus.
$Global:OrcaHostsGeschuetzt = @('localhost', 'localhost.localdomain', 'local', 'broadcasthost',
                                'ip6-localhost', 'ip6-loopback', 'ip6-localnet', 'ip6-mcastprefix',
                                'ip6-allnodes', 'ip6-allrouters', 'ip6-allhosts', '0.0.0.0')
$Global:OrcaHostsZeile   = '^\s*(0\.0\.0\.0|127\.0\.0\.1|::|0:0:0:0:0:0:0:0)\s+(\S+)\s*$'

function Get-OrcaHostsListe {
    param([Parameter(Mandatory)][string]$Abschnitt)
    if (-not $Global:OrcaHostsCache) {
        $tab = @{}
        $aktuell = $null
        foreach ($z in (Get-Content -LiteralPath $Global:OrcaHostsListen -Encoding UTF8 -ErrorAction Stop)) {
            $t = $z.Trim()
            if (-not $t -or $t.StartsWith('#')) { continue }
            if ($t -match '^\[(.+)\]$') { $aktuell = $matches[1]; $tab[$aktuell] = New-Object System.Collections.ArrayList; continue }
            if ($aktuell) { [void]$tab[$aktuell].Add($t.ToLower()) }
        }
        $Global:OrcaHostsCache = $tab
    }
    if ($Global:OrcaHostsCache.ContainsKey($Abschnitt)) { return ,@($Global:OrcaHostsCache[$Abschnitt]) }
    return ,@()
}

function Get-OrcaHostsKennung {
    $info = Get-Item -LiteralPath $Global:OrcaHostsDatei -Force -ErrorAction Stop
    return @{ Zeit = $info.LastWriteTimeUtc; Laenge = $info.Length }
}

function Read-OrcaHostsText {
    $bytes = [IO.File]::ReadAllBytes($Global:OrcaHostsDatei)
    try {
        $text = (New-Object System.Text.UTF8Encoding($false, $true)).GetString($bytes)
        $Global:OrcaHostsKodierung = 'UTF8'
        if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1); $Global:OrcaHostsKodierung = 'UTF8BOM' }
        return $text
    } catch {
        $Global:OrcaHostsKodierung = 'ANSI'
        return [Text.Encoding]::Default.GetString($bytes)
    }
}

function Write-OrcaHostsText {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $kod = switch ($Global:OrcaHostsKodierung) {
        'ANSI'    { [Text.Encoding]::Default }
        'UTF8BOM' { New-Object System.Text.UTF8Encoding $true }
        default   { New-Object System.Text.UTF8Encoding $false }
    }
    [IO.File]::WriteAllText($Global:OrcaHostsDatei, $Text, $kod)
}

function Read-OrcaHosts {
    # Zwischengespeichert, solange sich die Datei nicht ändert - der
    # Wächter fragt sie für mehrere Punkte nacheinander ab.
    $info = Get-OrcaHostsKennung
    $c = $Global:OrcaHostsLeseCache
    if ($c -and $c.Zeit -eq $info.Zeit -and $c.Laenge -eq $info.Laenge) { return $c.Daten }

    $roh = Read-OrcaHostsText
    $nl  = if ($roh.Contains("`r`n")) { "`r`n" } else { "`n" }
    $zeilen = $roh -split "`r?`n"
    if ($zeilen.Count -gt 0 -and $zeilen[-1] -eq '') { $zeilen = $zeilen[0..($zeilen.Count - 2)] }

    $a = -1; $e = -1
    for ($i = 0; $i -lt $zeilen.Count; $i++) {
        if ($a -lt 0 -and $zeilen[$i].StartsWith('# BEGIN OrcaShield')) { $a = $i; continue }
        if ($a -ge 0 -and $zeilen[$i].Trim() -eq $Global:OrcaHostsEnde) { $e = $i; break }
    }
    $d = @{ Nl = $nl; Da = ($a -ge 0 -and $e -gt $a); Vor = @(); Block = @(); Nach = @() }
    if ($d.Da) {
        if ($a -gt 0) { $d.Vor = @($zeilen[0..($a - 1)]) }
        if ($e - $a -gt 1) { $d.Block = @($zeilen[($a + 1)..($e - 1)]) }
        if ($e -lt $zeilen.Count - 1) { $d.Nach = @($zeilen[($e + 1)..($zeilen.Count - 1)]) }
    } else {
        $d.Vor = @($zeilen)
    }
    $Global:OrcaHostsLeseCache = @{ Zeit = $info.Zeit; Laenge = $info.Laenge; Daten = $d }
    return $d
}

function Get-OrcaHostsAbschnitte {
    $h = Read-OrcaHosts
    $c = $Global:OrcaHostsAbschnitteCache
    if ($c -and [object]::ReferenceEquals($c.Daten, $h)) { return $c.Ergebnis }
    # IgnoreCase wie bei -match, damit das Ergebnis gleich bleibt
    $opt = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    $kopf = New-Object System.Text.RegularExpressions.Regex('^#\s*---\s*OrcaShield:\s*(\S+)\s*---', $opt)
    $zeile = New-Object System.Text.RegularExpressions.Regex($Global:OrcaHostsZeile, $opt)
    $gefunden = @{}
    $aktuell = $null
    foreach ($z in $h.Block) {
        $m = $kopf.Match($z)
        if ($m.Success) { $aktuell = $m.Groups[1].Value; $gefunden[$aktuell] = New-Object 'System.Collections.Generic.HashSet[string]'; continue }
        if ($aktuell) { $m = $zeile.Match($z); if ($m.Success) { [void]$gefunden[$aktuell].Add($m.Groups[2].Value.ToLower()) } }
    }
    $erg = @{}
    foreach ($ab in $Global:OrcaHostsFolge) {
        $soll = Get-OrcaHostsListe -Abschnitt $ab
        # Nicht "$ist = if (...) { ... }": Die Zuweisung aus einem if packt die Menge in eine
        # Liste aus - danach war jedes Contains eine lineare Suche (80.000 x 80.000, die 14 s).
        $ist = $null
        if ($gefunden.ContainsKey($ab)) { $ist = $gefunden[$ab] }
        $intakt = $false
        if ($ist) {
            $intakt = ($ist.Count -eq $soll.Count) -and $ist.SetEquals([string[]]$soll)
        }
        $erg[$ab] = @{ Intakt = $intakt; Anzahl = $(if ($ist) { $ist.Count } else { 0 }); Soll = $soll.Count }
    }
    $Global:OrcaHostsAbschnitteCache = @{ Daten = $h; Ergebnis = $erg }
    return $erg
}

function Format-OrcaHostsBlock {
    param([string[]]$Abschnitte)
    $z = New-Object System.Collections.ArrayList
    if (@($Abschnitte).Count -eq 0) { return ,@() }
    [void]$z.Add($Global:OrcaHostsBeginn)
    foreach ($ab in $Global:OrcaHostsFolge) {
        if ($ab -notin $Abschnitte) { continue }
        [void]$z.Add("# --- OrcaShield: $ab ---")
        foreach ($n in (Get-OrcaHostsListe -Abschnitt $ab)) {
            [void]$z.Add("0.0.0.0 $n")
            if ($ab -in $Global:OrcaHostsDoppelt) { [void]$z.Add(":: $n") }
        }
    }
    [void]$z.Add($Global:OrcaHostsEnde)
    return ,@($z)
}

function Optimize-OrcaHostsEigen {
    param([string[]]$Zeilen)
    $z = @($Zeilen)
    # Überschriften "# ===== ... =====" ohne Einträge bis zur nächsten Überschrift
    $raus = @{}
    # Eine Überschrift bleibt nur, wenn bis zur nächsten Überschrift
    # mindestens ein Hosts-Eintrag folgt. Andere Zeilen (etwa eigene
    # Notizen wie "Test:") zählen nicht als Inhalt der Überschrift.
    for ($i = 0; $i -lt $z.Count; $i++) {
        if ($z[$i] -match '^#\s*=====.*=====\s*$') {
            $j = $i + 1; $eintrag = $false
            while ($j -lt $z.Count -and $z[$j] -notmatch '^#\s*=====.*=====\s*$') {
                if ($z[$j] -match '^\s*[0-9a-fA-F:\.%]+\s+\S') { $eintrag = $true; break }
                if ($z[$j].Trim() -and -not $z[$j].TrimStart().StartsWith('#')) { break }
                $j++
            }
            if (-not $eintrag) { $raus[$i] = $true }
        }
    }
    $z = @(for ($i = 0; $i -lt $z.Count; $i++) { if (-not $raus.ContainsKey($i)) { $z[$i] } })
    # höchstens eine Leerzeile am Stück, keine am Ende
    $aus = New-Object System.Collections.ArrayList
    foreach ($l in $z) {
        if (-not $l.Trim() -and $aus.Count -gt 0 -and -not ([string]$aus[$aus.Count - 1]).Trim()) { continue }
        [void]$aus.Add($l)
    }
    while ($aus.Count -gt 0 -and -not ([string]$aus[$aus.Count - 1]).Trim()) { $aus.RemoveAt($aus.Count - 1) }
    return ,@($aus)
}

function Write-OrcaHosts {
    param([string[]]$Abschnitte = @(), [string]$Zurueck = '')

    $h = Read-OrcaHosts
    $eigen = @($h.Vor) + @($h.Nach)

    # --- übernehmen: was jetzt im Block steht, aus deinem Teil nehmen
    $menge = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($ab in $Abschnitte) { foreach ($n in (Get-OrcaHostsListe -Abschnitt $ab)) { [void]$menge.Add($n) } }
    $behalten = New-Object System.Collections.ArrayList
    $genommen = New-Object System.Collections.ArrayList
    foreach ($l in $eigen) {
        if ($l -match $Global:OrcaHostsZeile) {
            $name = $matches[2].ToLower()
            if ($menge.Contains($name) -and $name -notin $Global:OrcaHostsGeschuetzt) { [void]$genommen.Add($l); continue }
        }
        [void]$behalten.Add($l)
    }

    # --- zurückgeben (Rückbau eines Abschnitts)
    $ablage = Join-Path $Global:OrcaBackup 'Hosts-uebernommen.txt'
    if ($Zurueck -and (Test-Path -LiteralPath $ablage)) {
        $liste = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($n in (Get-OrcaHostsListe -Abschnitt $Zurueck)) { [void]$liste.Add($n) }
        $vorhanden = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($l in $behalten) { [void]$vorhanden.Add($l.Trim()) }
        $rueck = @(Get-Content -LiteralPath $ablage -Encoding UTF8 | Where-Object {
            $_ -match $Global:OrcaHostsZeile -and $liste.Contains($matches[2].ToLower()) -and -not $vorhanden.Contains($_.Trim())
        } | Select-Object -Unique)
        if ($rueck.Count -gt 0) {
            [void]$behalten.Add('')
            [void]$behalten.Add('# ===== Von OrcaShield zurueckgegeben =====')
            foreach ($l in $rueck) { [void]$behalten.Add($l) }
        }
    }

    $eigenNeu = Optimize-OrcaHostsEigen -Zeilen @($behalten)
    $block = Format-OrcaHostsBlock -Abschnitte $Abschnitte
    $alle = @($eigenNeu)
    if ($block.Count -gt 0) { $alle += ''; $alle += $block }
    $text = ($alle -join $h.Nl) + $h.Nl

    # --- sichern, schreiben, nachprüfen
    try {
        if (-not (Test-Path $Global:OrcaBackup)) { New-Item -Path $Global:OrcaBackup -ItemType Directory -Force -ErrorAction Stop | Out-Null }
        $sicherung = Get-OrcaHostsSicherungGleich
        if (-not $sicherung) {
            $sicherung = Join-Path $Global:OrcaBackup ("Hosts_{0}.txt" -f (Get-Date -Format 'yyyy-MM-dd_HHmmss'))
            Copy-Item -LiteralPath $Global:OrcaHostsDatei -Destination $sicherung -Force -ErrorAction Stop
        }
        $geschrieben = $false; $letzterFehler = ''
        for ($versuch = 1; $versuch -le 30 -and -not $geschrieben; $versuch++) {
            try {
                Write-OrcaHostsText -Text $text
                $geschrieben = $true
            } catch {
                $letzterFehler = $_.Exception.Message
                Start-Sleep -Seconds 3
            }
        }
        if (-not $geschrieben) {
            return @{ Erfolg = $false; Uebernommen = 0
                      Grund = "Hosts-Datei 90 Sekunden lang nicht schreibbar: $letzterFehler. Der DNS-Client (Dnscache) hielt sie offen - beim nächsten Wächterlauf wird es erneut versucht." }
        }
        $Global:OrcaHostsLeseCache = $null
        if ($genommen.Count -gt 0) {
            $bisher = @()
            if (Test-Path -LiteralPath $ablage) { $bisher = @(Get-Content -LiteralPath $ablage -Encoding UTF8 -ErrorAction Stop) }
            $da = New-Object 'System.Collections.Generic.HashSet[string]'
            foreach ($l in $bisher) { if ($l -notmatch '^#') { [void]$da.Add($l.Trim()) } }
            $doppelt = ($da.Count -lt @($bisher | Where-Object { $_ -notmatch '^#' }).Count)
            $neu = @($genommen | Where-Object { $da.Add($_.Trim()) })
            if ($doppelt) {
                # Altbestand einmal bereinigen: erste Fundstelle bleibt, Reihenfolge auch.
                $sauber = @($bisher | Select-Object -Unique)
                Set-Content -LiteralPath $ablage -Value $sauber -Encoding UTF8 -ErrorAction Stop
            }
            if ($neu.Count -gt 0) {
                Add-Content -LiteralPath $ablage -Value (@("# übernommen am $(Get-Date -Format 'dd.MM.yyyy HH:mm')") + $neu) -Encoding UTF8 -ErrorAction Stop
            }
        }

        # Nachprüfen: Abschnitte intakt, und jede deiner verbliebenen
        # Zeilen ist noch da.
        $neu = Read-OrcaHosts
        $stand = Get-OrcaHostsAbschnitte
        $fehlt = @($Abschnitte | Where-Object { -not $stand[$_].Intakt })
        $eigenJetzt = @($neu.Vor) + @($neu.Nach)
        $mengeJetzt = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($l in $eigenJetzt) { [void]$mengeJetzt.Add($l) }
        $verloren = @($eigenNeu | Where-Object { $_.Trim() -and -not $mengeJetzt.Contains($_) })
        if ($fehlt.Count -gt 0 -or $verloren.Count -gt 0) {
            Copy-Item -LiteralPath $sicherung -Destination $Global:OrcaHostsDatei -Force -ErrorAction SilentlyContinue
            $Global:OrcaHostsLeseCache = $null
            return @{ Erfolg = $false; Uebernommen = 0
                      Grund = "Nachprüfung fehlgeschlagen ($($fehlt.Count) Abschnitte, $($verloren.Count) eigene Zeilen) - Sicherung zurückgelegt" }
        }
        Clear-OrcaHostsSicherungen
        return @{ Erfolg = $true; Uebernommen = $genommen.Count; Grund = '' }
    }
    catch {
        return @{ Erfolg = $false; Uebernommen = 0; Grund = $_.Exception.Message }
    }
}

# Liegt schon eine Sicherung mit genau diesem Inhalt? Dann deren Pfad.
function Get-OrcaHostsSicherungGleich {
    $letzte = Get-ChildItem -LiteralPath $Global:OrcaBackup -Filter 'Hosts_*.txt' -File -ErrorAction SilentlyContinue |
              Sort-Object Name | Select-Object -Last 1
    if (-not $letzte) { return $null }
    try {
        $a = (Get-FileHash -LiteralPath $Global:OrcaHostsDatei -Algorithm SHA256 -ErrorAction Stop).Hash
        $b = (Get-FileHash -LiteralPath $letzte.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
        if ($a -eq $b) { return $letzte.FullName }
    } catch { }
    return $null
}

# Behalten werden die älteste Sicherung - die Hosts-Datei, bevor
# OrcaShield sie zum ersten Mal geschrieben hat - und die drei
# neuesten. Alles dazwischen ist durch beide abgedeckt.
function Clear-OrcaHostsSicherungen {
    $alle = @(Get-ChildItem -LiteralPath $Global:OrcaBackup -Filter 'Hosts_*.txt' -File -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($alle.Count -le 4) { return }
    foreach ($d in @($alle[1..($alle.Count - 4)])) {
        try { Remove-Item -LiteralPath $d.FullName -Force -ErrorAction Stop }
        catch { Write-OrcaLog -Level WARN -Source 'HOSTS' -Message "Alte Sicherung $($d.Name) nicht löschbar: $($_.Exception.Message)" }
    }
}

$Global:OrcaGdidOrte = @(
    @{ Name = 'dein Profil';   Pfad = 'HKCU:\Software\Microsoft\IdentityCRL' }
    @{ Name = 'Vorlageprofil'; Pfad = 'Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\IdentityCRL' }
    @{ Name = 'Systemkonto';   Pfad = 'Registry::HKEY_USERS\S-1-5-18\Software\Microsoft\IdentityCRL' }
)
$Global:OrcaGdidMuster = '^0018[0-9A-Fa-f]{12}$'

function Get-OrcaGdidStand {
    $orte = @()
    foreach ($o in $Global:OrcaGdidOrte) {
        $lid = [string](Get-OrcaRegWert -Pfad "$($o.Pfad)\ExtendedProperties" -Name 'LID')
        if ($lid -match $Global:OrcaGdidMuster) { $orte += $o.Name }
    }
    return @{ Echt = $orte.Count; Orte = $orte }
}

function Invoke-OrcaGdidBereinigung {
    # Rückgabe: @{ Erfolg; Grund; Schritte = @() }
    $schritte = @()
    $netz = (Get-OrcaHostsAbschnitte)['GDID']
    if (-not $netz.Intakt) {
        return @{ Erfolg = $false; Schritte = @()
                  Grund = 'Die Sperre der Microsoft-Adressen (NET005) steht nicht. Ohne sie holt sich Windows sofort eine neue Kennung - erst NET005 setzen.' }
    }

    # Beteiligte Dienste anhalten, Ausgangszustand merken
    $dienste = @(Get-Service -Name 'wlidsvc', 'TokenBroker', 'CDPSvc' -ErrorAction SilentlyContinue) +
               @(Get-Service -Name 'CDPUserSvc*' -ErrorAction SilentlyContinue)
    $liefen = @($dienste | Where-Object { $_.Status -eq 'Running' } | ForEach-Object { $_.Name })
    foreach ($d in $dienste) { Stop-Service -Name $d.Name -Force -ErrorAction SilentlyContinue }
    $schritte += "Dienste angehalten: $(@($dienste | ForEach-Object { $_.Name }) -join ', ')"

    try {
        foreach ($o in $Global:OrcaGdidOrte) {
            Remove-OrcaRegWert -Pfad "$($o.Pfad)\ExtendedProperties" -Name 'LID' | Out-Null
            $prop = "$($o.Pfad)\Immersive\production\Property"
            $k = Get-OrcaRegSchluessel -Pfad $prop
            foreach ($n in @($k.Werte.Keys)) { Remove-OrcaRegWert -Pfad $prop -Name $n | Out-Null }
            foreach ($n in @('DeviceId', 'DeviceTicket')) { Remove-OrcaRegWert -Pfad "$($o.Pfad)\Immersive\production\Token" -Name $n | Out-Null }
        }
        $schritte += 'Kennung und Gerätetoken aus Registry entfernt (Benutzer, Vorlage, Systemkonto)'

        $neg = 'HKLM:\SOFTWARE\Microsoft\IdentityCRL\NegativeCache'
        foreach ($k in @(Get-ChildItem -LiteralPath $neg -ErrorAction SilentlyContinue)) {
            if ($k.PSChildName -match '0018[0-9A-Fa-f]{12}') { Remove-Item -LiteralPath $k.PSPath -Recurse -Force -ErrorAction SilentlyContinue }
        }
        foreach ($rel in @('Microsoft\TokenBroker\Cache', 'ConnectedDevicesPlatform')) {
            $p = Join-Path $env:LOCALAPPDATA $rel
            if ((Test-Path -LiteralPath $p) -and (Test-OrcaWegSicher -Wurzel $env:LOCALAPPDATA -Pfad $p)) {
                foreach ($x in @(Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue)) {
                    [void](Remove-OrcaPfadSicher -Wurzel $p -Pfad $x.FullName)
                }
            }
        }
        $schritte += 'Token-Zwischenspeicher geleert'

        # Gespeicherte Microsoft-Konto-Zugangsdaten
        $liste = cmdkey /list 2>&1 | Out-String
        $ziele = @([regex]::Matches($liste, '(?im)^\s*(?:Ziel|Target):\s*(?:LegacyGeneric:target=)?(\S*MicrosoftAccount\S*)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
        foreach ($z in $ziele) { Invoke-OrcaProgramm -Datei 'cmdkey.exe' -Argumente "/delete:$z" | Out-Null }
        $schritte += "Microsoft-Konto-Zugangsdaten entfernt: $($ziele.Count)"
    }
    finally {
        foreach ($n in $liefen) { Start-Service -Name $n -ErrorAction SilentlyContinue }
    }

    $nachher = Get-OrcaGdidStand
    $ok = ($nachher.Echt -eq 0)
    $grund = if ($ok) { '' } else { "weiterhin vorhanden: $($nachher.Orte -join ', ')" }
    Write-OrcaLog -Level $(if ($ok) { 'OK' } else { 'FEHLER' }) -Source 'GDID' `
        -Message "Bereinigung der Gerätekennung: $(if ($ok) { 'keine echte Kennung mehr vorhanden' } else { $grund })"
    return @{ Erfolg = $ok; Grund = $grund; Schritte = $schritte }
}

. (Join-Path $Global:OrcaSkripte 'Orca-Neues.ps1')
