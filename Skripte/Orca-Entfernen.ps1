param(
    [switch]$Rueckbau,
    [switch]$DatenLoeschen,
    [switch]$Simulation
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$skripte = $PSScriptRoot
# Aufruf aus einem Test, der die Simulation schon aufgebaut hat: nichts neu
# einlesen - eigene Funktionen in diesem Skript verdeckten sonst die Attrappen,
# und der simulierte Stand (etwa vorher Angewendetes) bliebe nicht erhalten.
$imTest = $Simulation -and $Global:OrcaSimulationAktiv
if (-not $imTest) {
    . (Join-Path $skripte 'Orca-Common.ps1')
    . (Join-Path $skripte 'Orca-Settings.ps1')
    . (Join-Path $skripte 'Orca-Engine.ps1')
    . (Join-Path $skripte 'Orca-Gui.ps1')
}

if ($imTest) {
    if (@(Get-PsimVerlorene).Count) { Write-Output 'ABBRUCH: Simulation nicht sicher'; exit 1 }
} elseif ($Simulation) {
    . (Join-Path $skripte 'Orca-Attrappen.ps1')
    Initialize-OrcaSimulation
    $Global:PsimZustand = Get-OrcaState
    $Global:PsimGrundzustand = Get-OrcaBaselineStand
    Enable-OrcaAttrappen
    $Global:OrcaSimulationAktiv = $true
    if (@(Get-PsimVerlorene).Count) { Write-Output 'ABBRUCH: Simulation nicht sicher'; exit 1 }
} elseif (-not (Test-OrcaAdmin)) {
    Write-Output 'Keine Administratorrechte.'
    exit 2
}

$offen = New-Object System.Collections.ArrayList
$melde = {
    param([string]$Stufe, [string]$Text)
    Write-Output "[$Stufe] $Text"
    # Nur in einen vorhandenen Datenordner schreiben - ihn anzulegen ist Sache der EXE (geschützt, App\Ordner.cs)
    if (Test-Path -LiteralPath $Global:OrcaDaten) { Write-OrcaLog -Level $Stufe -Source 'DEINSTALL' -Message $Text }
    if ($Stufe -eq 'FEHLER') { [void]$offen.Add($Text) }
}
& $melde 'INFO' "=== Deinstallation: Rückbau $([bool]$Rueckbau), Daten löschen $([bool]$DatenLoeschen)$(if ($Simulation) { ', Simulation' }) ==="

# --------------------------------------------------------------
#  1. RÜCKBAU (optional) - solange Wächter und Engine noch da sind
# --------------------------------------------------------------
if ($Rueckbau) {
    $st = Get-OrcaState
    $katalog = @($Global:OrcaEinstellungen | Where-Object { -not $_.Ausgemustert } | ForEach-Object { $_.Id })
    $ids = @(@($st.AktiveEinstellungen) | Where-Object { $_ -and $_ -in $katalog })
    if ($ids.Count -eq 0) {
        & $melde 'SKIP' 'Rückbau: OrcaShield hat keine Einstellungen gesetzt.'
    } elseif (-not (Get-OrcaBaselineStand).Lesbar) {
        & $melde 'FEHLER' 'Rückbau: Der Ausgangszustand fehlt oder ist nicht lesbar - es wurde nichts zurückgesetzt.'
    } else {
        $r = Invoke-OrcaGuiAnwenden -Ein @() -Aus $ids
        if ($r.abgebrochen) { & $melde 'FEHLER' "Rückbau abgebrochen: $($r.abgebrochen)" }
        else {
            $nok = @($r.punkte | Where-Object { -not $_.ok })
            & $melde $(if ($nok.Count) { 'WARN' } else { 'OK' }) "Rückbau: $($ids.Count - $nok.Count) von $($ids.Count) Einstellungen auf den Ausgangszustand zurückgesetzt."
            foreach ($p in $nok) { & $melde 'FEHLER' "Rückbau $($p.id): $($p.status) $($p.grund)" }
        }
    }
    foreach ($e in @(Get-OrcaEigeneSperren -State (Get-OrcaState))) {
        $r = Restore-OrcaNeuerSammler -Schluessel $e.Schluessel
        & $melde $(if ($r.Erfolg) { 'OK' } else { 'FEHLER' }) "Telemetrie-Eintrag $($e.Schluessel): $($r.Status) $($r.Grund)"
    }
    foreach ($e in @(Get-OrcaAufgehobeneRichtlinien -State (Get-OrcaState))) {
        $r = Restore-OrcaFremdeRichtlinie -Schluessel $e.Schluessel
        & $melde $(if ($r.Erfolg) { 'OK' } else { 'FEHLER' }) "Richtlinie $($e.Pfad)\$($e.Name): $($r.Status) $($r.Grund)"
    }
}

# --------------------------------------------------------------
#  2. AUTOMATIK AUSTRAGEN - nur, was zu dieser Installation gehört
# --------------------------------------------------------------
$a = Get-OrcaWaechterAufgabe
if (-not $a.Da) {
    & $melde 'SKIP' 'Wächter-Aufgabe war nicht eingetragen.'
} elseif ($Simulation -or $a.Ziel -like "*$($Global:OrcaSkripte)*") {
    try {
        Unregister-ScheduledTask -TaskPath '\' -TaskName $Global:OrcaAufgabeWaechter -Confirm:$false -ErrorAction Stop
        if ((Get-OrcaWaechterAufgabe).Da) { & $melde 'FEHLER' 'Wächter-Aufgabe ist nach dem Austragen noch vorhanden.' }
        else { & $melde 'OK' 'Wächter-Aufgabe ausgetragen.' }
    } catch { & $melde 'FEHLER' "Wächter-Aufgabe: $($_.Exception.Message)" }
} else {
    & $melde 'SKIP' "Wächter-Aufgabe gehört zu einer anderen OrcaShield-Fassung ($($a.Ziel)) - nicht angefasst."
}

$reg = Get-OrcaShutdownRegistrierung
if (-not ($reg.Datei -or $reg.IniZeile)) {
    & $melde 'SKIP' 'Herunterfahren-Skript war nicht eingetragen.'
} else {
    $eigen = $true
    if (-not $Simulation -and $reg.Datei) {
        $inhalt = Get-Content -LiteralPath $reg.Pfad -Raw -ErrorAction SilentlyContinue
        $eigen = ("$inhalt" -like "*$($Global:OrcaSkripte)*")
    }
    if (-not $eigen) {
        & $melde 'SKIP' 'Herunterfahren-Skript gehört zu einer anderen OrcaShield-Fassung - nicht angefasst.'
    } else {
        $r = Unregister-OrcaShutdownSkript
        $n = Get-OrcaShutdownRegistrierung
        if ($r.Erfolg -and -not $n.Datei -and -not $n.IniZeile) {
            & $melde 'OK' 'Herunterfahren-Skript ausgetragen (fremde Einträge blieben unangetastet).'
            # Die Auslagerungsdatei leert das Herunterfahren-Skript bei jedem Lauf;
            # beim Austragen schaltet Unregister-OrcaShutdownSkript den Schalter mit ab.
            if ($r.Auslagerung) { & $melde 'OK' 'Leeren der Auslagerungsdatei beim Herunterfahren abgeschaltet.' }
        } else {
            & $melde 'FEHLER' "Herunterfahren-Skript: $(if ($r.Grund) { $r.Grund } else { 'Eintrag nach dem Austragen noch vorhanden' })"
        }
    }
}

$reg = Get-OrcaShutdownRegistrierung
if (-not ($reg.Datei -or $reg.IniZeile)) {
    $mm = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    if ([int](Get-OrcaRegWert -Pfad $mm -Name 'ClearPageFileAtShutdown') -eq 1) {
        [void](Set-OrcaRegWert -Pfad $mm -Name 'ClearPageFileAtShutdown' -Wert 0)
        & $melde 'OK' 'Leeren der Auslagerungsdatei beim Herunterfahren abgeschaltet.'
    }
}

# --------------------------------------------------------------
#  3. DATENORDNER LÖSCHEN (optional) - nur, wenn alles gelang
# --------------------------------------------------------------
if ($DatenLoeschen) {
    $daten = $Global:OrcaDaten
    $pd = [Environment]::GetFolderPath('CommonApplicationData')
    if ($offen.Count) {
        & $melde 'WARN' "Datenordner bleibt erhalten, weil etwas offen ist: $daten"
    } elseif ($daten -ne (Join-Path $pd 'OrcaShield') -or $daten -eq $Global:OrcaRoot) {
        # Nur der Datenordner einer installierten EXE - nie der Programmordner einer
        # PowerShell-Fassung oder ein umgelenkter Pfad.
        & $melde 'FEHLER' "Datenordner nicht gelöscht: unerwarteter Pfad $daten"
    } elseif (-not (Test-Path -LiteralPath $daten)) {
        & $melde 'SKIP' 'Datenordner war nicht vorhanden.'
    } elseif ($Simulation) {
        & $melde 'OK' "Simulation: Datenordner würde gelöscht ($daten)."
    } else {
        try {
            if (Test-OrcaIstVerknuepfung -Pfad $daten) {
                # Nur die Verknüpfung, nie ihr Ziel
                [IO.Directory]::Delete($daten, $false)
            } else {
                Remove-Item -LiteralPath $daten -Recurse -Force -ErrorAction Stop
            }
            if (Test-Path -LiteralPath $daten) { Write-Output "[FEHLER] Datenordner noch vorhanden: $daten"; [void]$offen.Add('Datenordner') }
            else { Write-Output "[OK] Datenordner gelöscht: $daten" }
        } catch {
            Write-Output "[FEHLER] Datenordner: $($_.Exception.Message)"
            [void]$offen.Add('Datenordner')
        }
    }
}

if ((Test-Path -LiteralPath $Global:OrcaDaten) -and -not ($DatenLoeschen -and -not $offen.Count)) {
    Write-OrcaLog -Level INFO -Source 'DEINSTALL' -Message "=== Deinstallation beendet, offen: $($offen.Count) ==="
}
if ($offen.Count) { exit 1 }
exit 0
