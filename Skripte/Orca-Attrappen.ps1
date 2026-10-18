
# --------------------------------------------------------------
#  AUFZEICHNUNG
# --------------------------------------------------------------
function Initialize-OrcaSimulation {
    $Global:PsimPhase     = 'start'
    $Global:PsimVorgaenge = New-Object System.Collections.ArrayList
    $Global:PsimRegistry  = @{}
    $Global:PsimDateien   = @{}
    $Global:PsimAufgaben  = @{}
    $Global:PsimProtokoll = New-Object System.Collections.ArrayList
    $Global:PsimZustand   = $null
    $Global:PsimGrundzustand = @{ Da = $false; Lesbar = $false; Tabelle = @{}; Grund = '' }
    $Global:PsimStufe     = 'Standard'
    $Global:PsimDebloat   = 'Standard'
    $Global:PsimAuswahl   = 1
    $Global:PsimDienste         = @{}   # Dienstname -> Startart
    $Global:PsimAufgabenZustand = @{}   # \Pfad\Name -> Ready / Disabled
    $Global:PsimSchluesselWeg   = @{}   # entfernter Registry-Schlüssel -> $true
    $Global:PsimFirewall        = @{}   # Anzeigename -> $true (angelegt) / $false (entfernt)
    $Global:PsimDoh             = @{}   # Serveradresse -> Eintrag / $null (entfernt)
    $Global:PsimCimWeg          = @{}   # ID gelöschter CIM-Objekte (Schattenkopien) -> $true
    $Global:PsimComputerschutz  = ''    # '' = echt messen, sonst 'an' / 'aus'
    $Global:PsimHypervisor      = ''    # '' = echt messen, sonst hypervisorlaunchtype (Auto / Off)
    $Global:PsimShutdown        = ''
    $Global:PsimAppsWeg         = @{}   # PackageFullName -> $true
    $Global:PsimBereitstellungWeg = @{} # PackageName (Systemabbild) -> $true
}

function Global:Add-PsimVorgang {
    # Global, damit die Attrappen sie in jedem Fall sehen -
    # unabhängig davon, aus welchem Geltungsbereich heraus sie
    # aufgerufen werden.
    param([string]$Art, [string]$Ziel, [string]$Wert = '', [string]$Zusatz = '')
    [void]$Global:PsimVorgaenge.Add([pscustomobject]@{
        Nr     = $Global:PsimVorgaenge.Count + 1
        Phase  = $Global:PsimPhase
        Art    = $Art
        Ziel   = $Ziel
        Wert   = $Wert
        Zusatz = $Zusatz
    })
}

# --------------------------------------------------------------
#  EXTERNE PROGRAMME: welche Aufrufe nur lesen
# --------------------------------------------------------------
$Global:PsimExterne = @('gpupdate','bcdedit','powercfg','fsutil','defrag','reg','icacls','netsh',
                        'vssadmin','schtasks','dism','sc','takeown','cipher','wevtutil','auditpol','secedit')

function Global:Test-PsimNurLesend {
    param([string]$Name, [string]$Text)
    switch ($Name) {
        'bcdedit'  { return ($Text -match '/enum') }
        'fsutil'   { return ($Text -match '\bquery\b') }
        'reg'      { return ($Text -match '^\s*(query|export)\b') }
        'powercfg' { return ($Text -match '^\s*[/-](a|q|query|l|list|getactivescheme)\b') }
        default    { return $false }
    }
}

# --------------------------------------------------------------
#  ATTRAPPEN SETZEN
# --------------------------------------------------------------
function Enable-OrcaAttrappen {
    # Module, die ihre Befehle als FUNKTIONEN statt als Cmdlets
    # bereitstellen, hier schon laden. Sonst lädt Windows sie später
    # beim ersten Aufruf nach - und überschreibt dabei die
    # gleichnamigen Attrappen. Genau daran ist der erste Lauf
    # gescheitert: Get-ScheduledTask in der Messung holte das Modul
    # ScheduledTasks herein, und Register-ScheduledTask war wieder das
    # Original.
    Import-Module ScheduledTasks -Global -ErrorAction SilentlyContinue
    Import-Module Appx          -Global -ErrorAction SilentlyContinue
    Import-Module DISM          -Global -ErrorAction SilentlyContinue
    Import-Module Defender      -Global -ErrorAction SilentlyContinue
    Import-Module CimCmdlets    -Global -ErrorAction SilentlyContinue
    Import-Module DnsClient     -Global -ErrorAction SilentlyContinue
    Import-Module NetAdapter    -Global -ErrorAction SilentlyContinue
    Import-Module NetSecurity   -Global -ErrorAction SilentlyContinue

    $Global:PsimEcht = @{}
    foreach ($n in @('Get-OrcaRegWertUndTyp','Get-OrcaRegWert','Test-OrcaRegSchluessel','Get-OrcaRegSchluessel',
                     'Get-OrcaHostsKennung','Read-OrcaHostsText','Get-OrcaComputerschutz',
                     'Get-OrcaShutdownRegistrierung','Register-OrcaShutdownSkript','Unregister-OrcaShutdownSkript')) {
        $c = Get-Command -Name $n -CommandType Function -ErrorAction SilentlyContinue
        if ($c) { $Global:PsimEcht[$n] = $c.ScriptBlock }
    }
    & $Global:PsimAttrappenBlock
}

# Alle Attrappen liegen in einem Block, der sich jederzeit erneut
# ausführen lässt. Geht eine verloren, weil ein Modul sie
# überschrieben hat, wird sie wieder gesetzt statt den Lauf
# abzubrechen.
$Global:PsimAttrappenBlock = {
    # --- Registry -------------------------------------------------
    function Global:Set-OrcaRegWert {
        # PSIM-ATTRAPPE
        param([string]$Pfad, [string]$Name, $Wert, [string]$Typ = 'DWord')
        Add-PsimVorgang -Art 'REG-SETZEN' -Ziel "$Pfad ! $Name" -Wert "$Wert" -Zusatz $Typ
        $Global:PsimRegistry["$Pfad|$Name"] = @{ Wert = $Wert; Typ = $Typ; Weg = $false }
        return @{ Erfolg = $true; Grund = '' }
    }

    function Global:Remove-OrcaRegWert {
        # PSIM-ATTRAPPE
        param([string]$Pfad, [string]$Name)
        Add-PsimVorgang -Art 'REG-LOESCHEN' -Ziel "$Pfad ! $Name"
        $Global:PsimRegistry["$Pfad|$Name"] = @{ Wert = $null; Typ = $null; Weg = $true }
        return @{ Erfolg = $true; Grund = '' }
    }

    function Global:Remove-OrcaRegSchluesselWennLeer {
        # PSIM-ATTRAPPE - nur aufzeichnen; ob der Schlüssel leer wäre, weiß die Simulation nicht
        param([string]$Pfad)
        Add-PsimVorgang -Art 'REG-SCHLUESSEL-LEER' -Ziel "$Pfad"
        return @{ Entfernt = $false; Grund = 'Simulation' }
    }

    function Global:Get-OrcaRegWertUndTyp {
        # PSIM-ATTRAPPE - erst der simulierte Stand, sonst der echte
        param([string]$Pfad, [string]$Name)
        $k = "$Pfad|$Name"
        if ($Global:PsimRegistry.ContainsKey($k)) {
            $e = $Global:PsimRegistry[$k]
            if ($e.Weg) { return @{ SchluesselDa = $true; WertDa = $false; Wert = $null; Typ = $null } }
            return @{ SchluesselDa = $true; WertDa = $true; Wert = $e.Wert; Typ = $e.Typ }
        }
        if ($Global:PsimEcht.ContainsKey('Get-OrcaRegWertUndTyp')) {
            return (& $Global:PsimEcht['Get-OrcaRegWertUndTyp'] -Pfad $Pfad -Name $Name)
        }
        return @{ SchluesselDa = $false; WertDa = $false; Wert = $null; Typ = $null }
    }

    function Global:Get-OrcaRegWert {
        # PSIM-ATTRAPPE
        param([string]$Pfad, [string]$Name)
        $r = Get-OrcaRegWertUndTyp -Pfad $Pfad -Name $Name
        if ($r.WertDa) { return $r.Wert }
        return $null
    }

    function Global:Get-OrcaRegSchluessel {
        param([string]$Pfad)
        if ($Global:PsimSchluesselWeg -and $Global:PsimSchluesselWeg.ContainsKey($Pfad)) { return @{ Da = $false; Werte = @{} } }
        $erg = @{ Da = $false; Werte = @{} }
        if ($Global:PsimEcht.ContainsKey('Get-OrcaRegSchluessel')) { $erg = & $Global:PsimEcht['Get-OrcaRegSchluessel'] -Pfad $Pfad }
        $werte = @{}; foreach ($n in $erg.Werte.Keys) { $werte[$n] = $erg.Werte[$n] }
        $da = [bool]$erg.Da
        foreach ($k in @($Global:PsimRegistry.Keys)) {
            if (-not $k.StartsWith("$Pfad|")) { continue }
            $name = $k.Substring($Pfad.Length + 1)
            $e = $Global:PsimRegistry[$k]
            if ($e.Weg) { $werte.Remove($name) } else { $werte[$name] = $e.Wert; $da = $true }
        }
        return @{ Da = $da; Werte = $werte }
    }

    function Global:Test-OrcaRegSchluessel {
        # PSIM-ATTRAPPE
        param([string]$Pfad)
        if ($Global:PsimSchluesselWeg -and $Global:PsimSchluesselWeg.ContainsKey($Pfad)) { return $false }
        foreach ($k in $Global:PsimRegistry.Keys) {
            if ($k.StartsWith("$Pfad|")) { return $true }
        }
        if ($Global:PsimEcht.ContainsKey('Test-OrcaRegSchluessel')) {
            return (& $Global:PsimEcht['Test-OrcaRegSchluessel'] -Pfad $Pfad)
        }
        return $false
    }

    # --- Zustand, Grundzustand, Protokoll -------------------------
    function Global:Save-OrcaState {
        # PSIM-ATTRAPPE
        param($State)
        $Global:PsimZustand = $State
        Add-PsimVorgang -Art 'ZUSTAND' -Ziel 'orca-state.json' -Wert 'geschrieben'
        return $true
    }

    function Global:Get-OrcaState {
        # PSIM-ATTRAPPE
        $Global:OrcaStateUnlesbar = $false
        return $Global:PsimZustand
    }

    function Global:Invoke-OrcaMitSperre {
        # PSIM-ATTRAPPE - keine Systemsperre in der Simulation
        param([Parameter(Mandatory)][scriptblock]$Aktion, [int]$Sekunden = 15)
        return (& $Aktion)
    }

    function Global:Move-OrcaDateiErsetzt {
        # PSIM-ATTRAPPE - Nebendatei aus der Simulationsablage übernehmen
        param([Parameter(Mandatory)][string]$Ziel)
        $inhalt = $Global:PsimDateien["$Ziel.neu"]
        $Global:PsimDateien[$Ziel] = $inhalt
        Add-PsimVorgang -Art 'DATEI-ERSETZEN' -Ziel $Ziel -Wert 'aus Nebendatei'
        if ($Ziel -eq $Global:OrcaBaseline) {
            try {
                $roh = $inhalt | ConvertFrom-Json
                $tab = @{}
                foreach ($p in $roh.PSObject.Properties) { $tab[$p.Name] = $p.Value }
                $Global:PsimGrundzustand = @{ Da = $true; Lesbar = $true; Tabelle = $tab; Grund = '' }
            } catch {
                Add-PsimVorgang -Art 'HINWEIS' -Ziel 'Grundzustand' -Wert "JSON nicht lesbar: $($_.Exception.Message)"
            }
        }
    }

    function Global:Get-OrcaBaselineStand {
        # PSIM-ATTRAPPE
        return $Global:PsimGrundzustand
    }

    function Global:Write-OrcaLog {
        # PSIM-ATTRAPPE
        param(
            [Parameter(Mandatory)][string]$Message,
            [string]$Level = 'INFO',
            [string]$Source = 'ALLGEMEIN'
        )
        [void]$Global:PsimProtokoll.Add(('{0,-6} {1,-12} {2}' -f $Level, $Source, $Message))
    }

    function Global:Write-OrcaBalken {
        # PSIM-ATTRAPPE - der Fortschrittsbalken kostet nur Zeit
        param($Aktuell, $Gesamt, $Text)
    }

    # --- Fragen, die sonst auf eine Eingabe warten ----------------
    function Global:Read-Host {
        # PSIM-ATTRAPPE
        param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
        return ''
    }

    function Global:Read-OrcaJaNein {
        # PSIM-ATTRAPPE - immer Ja, damit der Ablauf durchläuft
        param([string]$Frage, [string]$Zaehler, [switch]$StandardJa)
        Add-PsimVorgang -Art 'FRAGE' -Ziel $Frage -Wert 'Ja (automatisch)'
        return $true
    }

    function Global:Read-OrcaAuswahl {
        # PSIM-ATTRAPPE
        param([string]$Frage, [array]$Optionen)
        Add-PsimVorgang -Art 'FRAGE' -Ziel $Frage -Wert "Auswahl $Global:PsimAuswahl (automatisch)"
        return $Global:PsimAuswahl
    }

    function Global:Get-OrcaHaertungsstufe {
        # PSIM-ATTRAPPE
        return $Global:PsimStufe
    }

    function Global:Get-OrcaDebloatstufe {
        # PSIM-ATTRAPPE
        return $Global:PsimDebloat
    }

    function Global:Confirm-OrcaEntscheidungen {
        # PSIM-ATTRAPPE - keine der heiklen Punkte annehmen, das ist
        # auch die Vorgabe des Werkzeugs selbst
        param($Punkte)
        foreach ($p in @($Punkte)) { Add-PsimVorgang -Art 'ENTSCHEIDUNG' -Ziel $p.Id -Wert 'abgelehnt (Vorgabe)' }
        return @()
    }

    function Global:Confirm-OrcaEdgeEntfernung {
        # PSIM-ATTRAPPE
        return $false
    }

    function Global:Assert-OrcaAdmin {
        # PSIM-ATTRAPPE - das Original beendet die Sitzung mit exit 1
        Add-PsimVorgang -Art 'PRUEFUNG' -Ziel 'Assert-OrcaAdmin' -Wert 'uebersprungen'
    }

    function Global:Invoke-OrcaNeustart {
        # PSIM-ATTRAPPE
        param([int]$Sekunden = 5)
        Add-PsimVorgang -Art 'NEUSTART' -Ziel 'Restart-Computer' -Wert "nach $Sekunden Sekunden"
        return $false
    }

    # --- Schreibende Cmdlets --------------------------------------
    function Global:New-Item {
        # PSIM-ATTRAPPE
        param([string]$Path, [string]$ItemType, $Value, [switch]$Force,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'NEU-ANLEGEN' -Ziel $Path -Zusatz $ItemType
        if ($Global:PsimSchluesselWeg -and $Global:PsimSchluesselWeg.ContainsKey($Path)) { $Global:PsimSchluesselWeg.Remove($Path) }
        return [pscustomobject]@{ FullName = $Path; PSPath = $Path; Name = (Split-Path $Path -Leaf) }
    }

    function Global:Remove-Item {
        # PSIM-ATTRAPPE
        param([string]$Path, [string]$LiteralPath, [switch]$Recurse, [switch]$Force,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        $z = if ($LiteralPath) { $LiteralPath } else { $Path }
        Add-PsimVorgang -Art 'LOESCHEN' -Ziel $z -Zusatz $(if ($Recurse) { 'mit Unterobjekten' } else { '' })
        # Registry-Schlüssel als entfernt merken (Nachprüfung über Test-OrcaRegSchluessel)
        if ($Global:PsimSchluesselWeg -and $z -match '^(HKLM|HKCU|HKU|HKCR|Registry)::?') { $Global:PsimSchluesselWeg[$z] = $true }
    }

    function Global:Remove-OrcaEintragSicher {
        param([Parameter(Mandatory)][string]$Pfad)
        Add-PsimVorgang -Art 'LOESCHEN' -Ziel $Pfad -Zusatz 'über Handle'
        return 0
    }

    function Global:New-ItemProperty {
        # PSIM-ATTRAPPE
        param([string]$Path, [string]$LiteralPath, [string]$Name, $Value, [string]$PropertyType,
              [switch]$Force, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        $z = if ($LiteralPath) { $LiteralPath } else { $Path }
        Add-PsimVorgang -Art 'REG-SETZEN(roh)' -Ziel "$z ! $Name" -Wert "$Value" -Zusatz $PropertyType
        $Global:PsimRegistry["$z|$Name"] = @{ Wert = $Value; Typ = $PropertyType; Weg = $false }
    }

    function Global:Set-ItemProperty {
        # PSIM-ATTRAPPE
        param([string]$Path, [string]$LiteralPath, [string]$Name, $Value,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        $z = if ($LiteralPath) { $LiteralPath } else { $Path }
        Add-PsimVorgang -Art 'REG-SETZEN(roh)' -Ziel "$z ! $Name" -Wert "$Value"
        $Global:PsimRegistry["$z|$Name"] = @{ Wert = $Value; Typ = $null; Weg = $false }
    }

    function Global:Remove-ItemProperty {
        # PSIM-ATTRAPPE
        param([string]$Path, [string]$LiteralPath, [string]$Name, [switch]$Force,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        $z = if ($LiteralPath) { $LiteralPath } else { $Path }
        Add-PsimVorgang -Art 'REG-LOESCHEN(roh)' -Ziel "$z ! $Name"
        $Global:PsimRegistry["$z|$Name"] = @{ Wert = $null; Typ = $null; Weg = $true }
    }

    function Global:Set-Content {
        # PSIM-ATTRAPPE
        [CmdletBinding()]
        param([string]$Path, [string]$LiteralPath,
              [Parameter(ValueFromPipeline = $true)]$Value,
              $Encoding, [switch]$Force, [switch]$NoNewline,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        begin { $puffer = New-Object System.Collections.ArrayList }
        process { foreach ($v in @($Value)) { if ($null -ne $v) { [void]$puffer.Add([string]$v) } } }
        end {
            $z = if ($LiteralPath) { $LiteralPath } else { $Path }
            $inhalt = ($puffer -join "`r`n")
            $Global:PsimDateien[$z] = $inhalt
            Add-PsimVorgang -Art 'DATEI-SCHREIBEN' -Ziel $z -Wert ("{0} Zeichen" -f $inhalt.Length)
            if ($z -eq $Global:OrcaBaseline) {
                try {
                    $roh = $inhalt | ConvertFrom-Json
                    $tab = @{}
                    foreach ($p in $roh.PSObject.Properties) { $tab[$p.Name] = $p.Value }
                    $Global:PsimGrundzustand = @{ Da = $true; Lesbar = $true; Tabelle = $tab; Grund = '' }
                } catch {
                    Add-PsimVorgang -Art 'HINWEIS' -Ziel 'Grundzustand' -Wert "JSON nicht lesbar: $($_.Exception.Message)"
                }
            }
        }
    }

    function Global:Add-Content {
        # PSIM-ATTRAPPE
        [CmdletBinding()]
        param([string]$Path, [string]$LiteralPath,
              [Parameter(ValueFromPipeline = $true)]$Value,
              $Encoding, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        begin { $puffer = New-Object System.Collections.ArrayList }
        process { foreach ($v in @($Value)) { if ($null -ne $v) { [void]$puffer.Add([string]$v) } } }
        end {
            $z = if ($LiteralPath) { $LiteralPath } else { $Path }
            Add-PsimVorgang -Art 'DATEI-ANHAENGEN' -Ziel $z -Wert ("{0} Zeilen" -f $puffer.Count)
        }
    }

    function Global:Out-File {
        # PSIM-ATTRAPPE
        [CmdletBinding()]
        param([string]$FilePath, [Parameter(ValueFromPipeline = $true)]$InputObject,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        process { }
        end { Add-PsimVorgang -Art 'DATEI-SCHREIBEN' -Ziel $FilePath }
    }

    # --- Dienste, Aufgaben, Funktionen, Apps ----------------------
    function Global:Set-Service {
        # PSIM-ATTRAPPE
        param([string]$Name, [string]$StartupType,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'DIENST' -Ziel $Name -Wert "Startart $StartupType"
        if ($Global:PsimDienste -and $Name -and $StartupType) { $Global:PsimDienste[$Name] = $StartupType }
    }

    function Global:Get-CimInstance {
        [CmdletBinding()]
        param([string]$ClassName, [string]$Filter, [string]$Namespace, [string]$Query)
        $echt = CimCmdlets\Get-CimInstance @PSBoundParameters
        if ($ClassName -eq 'Win32_ShadowCopy' -and $Global:PsimCimWeg -and $Global:PsimCimWeg.Count -gt 0) {
            return @($echt | Where-Object { -not $Global:PsimCimWeg.ContainsKey([string]$_.ID) })
        }
        if ($ClassName -ne 'Win32_Service' -or -not $Global:PsimDienste -or $Global:PsimDienste.Count -eq 0) { return $echt }
        $modus = @{ Disabled = 'Disabled'; Manual = 'Manual'; Automatic = 'Auto'; AutomaticDelayedStart = 'Auto'; Boot = 'Boot'; System = 'System' }
        foreach ($d in @($echt)) {
            if ($d -and $Global:PsimDienste.ContainsKey($d.Name)) {
                $art = $Global:PsimDienste[$d.Name]
                [pscustomobject]@{ Name = $d.Name; DisplayName = $d.DisplayName; State = $d.State
                                   StartMode = $(if ($modus.ContainsKey($art)) { $modus[$art] } else { $art }) }
            } else { $d }
        }
    }

    function Global:Stop-Service {
        # PSIM-ATTRAPPE
        param([string]$Name, [switch]$Force, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'DIENST' -Ziel $Name -Wert 'anhalten'
    }

    function Global:Start-Service {
        # PSIM-ATTRAPPE
        param([string]$Name, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'DIENST' -Ziel $Name -Wert 'starten'
    }

    function Global:Register-ScheduledTask {
        # PSIM-ATTRAPPE
        param([string]$TaskName, [string]$TaskPath, $Action, $Trigger, $Principal, $Settings,
              [string]$Description, [switch]$Force,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        $was = ''
        try { $was = "$($Action.Execute) $($Action.Arguments)" } catch { }
        $wer = ''
        try { $wer = "$($Principal.UserId) / $($Principal.LogonType) / $($Principal.RunLevel)" } catch { }
        Add-PsimVorgang -Art 'AUFGABE-ANLEGEN' -Ziel $TaskName -Wert $was -Zusatz $wer
        $Global:PsimAufgaben[$TaskName] = [pscustomobject]@{
            TaskName = $TaskName; TaskPath = '\'; State = 'Ready'; Description = $Description
        }
        return $Global:PsimAufgaben[$TaskName]
    }

    function Global:Unregister-ScheduledTask {
        # PSIM-ATTRAPPE
        param([string]$TaskName, [string]$TaskPath, [switch]$Confirm,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'AUFGABE-ENTFERNEN' -Ziel $TaskName
        if ($Global:PsimAufgaben.ContainsKey($TaskName)) { $Global:PsimAufgaben.Remove($TaskName) }
    }

    function Global:Enable-ScheduledTask {
        # PSIM-ATTRAPPE
        param([string]$TaskName, [string]$TaskPath,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'AUFGABE-EIN' -Ziel "$TaskPath$TaskName"
        if ($Global:PsimAufgabenZustand) { $Global:PsimAufgabenZustand["$TaskPath$TaskName"] = 'Ready' }
        if ($Global:PsimAufgaben -and $Global:PsimAufgaben.ContainsKey($TaskName)) { $Global:PsimAufgaben[$TaskName].State = 'Ready' }
    }

    function Global:Disable-ScheduledTask {
        # PSIM-ATTRAPPE
        param([string]$TaskName, [string]$TaskPath,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'AUFGABE-AUS' -Ziel "$TaskPath$TaskName"
        if ($Global:PsimAufgabenZustand) { $Global:PsimAufgabenZustand["$TaskPath$TaskName"] = 'Disabled' }
        if ($Global:PsimAufgaben -and $Global:PsimAufgaben.ContainsKey($TaskName)) { $Global:PsimAufgaben[$TaskName].State = 'Disabled' }
    }

    function Global:Get-ScheduledTask {
        # PSIM-ATTRAPPE - erst die simuliert angelegten, sonst die echten.
        # HINWEIS für den Bericht: Diese Attrappe wirft nie, auch nicht
        # bei -ErrorAction Stop. Der Zweig "Ist-Zustand nicht abfragbar"
        # in Invoke-OrcaAbgleich wird hier also nicht durchlaufen.
        [CmdletBinding()]
        param([string]$TaskName, [string]$TaskPath)
        if ($TaskName -and $Global:PsimAufgaben.ContainsKey($TaskName)) {
            return $Global:PsimAufgaben[$TaskName]
        }
        $durch = @{}
        if ($TaskName) { $durch['TaskName'] = $TaskName }
        if ($TaskPath) { $durch['TaskPath'] = $TaskPath }
        $echt = $null
        try { $echt = ScheduledTasks\Get-ScheduledTask @durch -ErrorAction SilentlyContinue } catch { return $null }
        if (-not $echt -or -not $Global:PsimAufgabenZustand -or $Global:PsimAufgabenZustand.Count -eq 0) { return $echt }
        foreach ($t in @($echt)) {
            $k = "$($t.TaskPath)$($t.TaskName)"
            if ($Global:PsimAufgabenZustand.ContainsKey($k)) {
                [pscustomobject]@{ TaskName = $t.TaskName; TaskPath = $t.TaskPath; State = $Global:PsimAufgabenZustand[$k]
                                   Actions = $t.Actions; Principal = $t.Principal; Description = $t.Description }
            } else { $t }
        }
    }

    function Global:Remove-AppxPackage {
        # PSIM-ATTRAPPE
        param([string]$Package, [switch]$AllUsers,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'APP-ENTFERNEN' -Ziel $Package -Zusatz $(if ($AllUsers) { 'alle Benutzer' } else { '' })
        if ($Global:PsimAppsWeg -and $Package) { $Global:PsimAppsWeg[$Package] = $true }
    }

    function Global:Remove-AppxProvisionedPackage {
        # PSIM-ATTRAPPE
        param([switch]$Online, [string]$PackageName,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'APP-BEREITSTELLUNG' -Ziel $PackageName
        if ($Global:PsimBereitstellungWeg -and $PackageName) { $Global:PsimBereitstellungWeg[$PackageName] = $true }
    }

    function Global:Add-AppxPackage {
        param([switch]$RegisterByFamilyName, [string]$MainPackage,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'APP-REGISTRIEREN' -Ziel $MainPackage
    }

    function Global:Get-AppxPackage {
        [CmdletBinding()]
        param([Parameter(Position = 0)][string]$Name, [switch]$AllUsers, [string]$User)
        $echt = Appx\Get-AppxPackage @PSBoundParameters
        if (-not $Global:PsimAppsWeg -or $Global:PsimAppsWeg.Count -eq 0) { return $echt }
        return @($echt | Where-Object { -not $Global:PsimAppsWeg.ContainsKey([string]$_.PackageFullName) })
    }

    function Global:Get-AppxProvisionedPackage {
        [CmdletBinding()]
        param([switch]$Online)
        $echt = Dism\Get-AppxProvisionedPackage @PSBoundParameters
        if (-not $Global:PsimBereitstellungWeg -or $Global:PsimBereitstellungWeg.Count -eq 0) { return $echt }
        return @($echt | Where-Object { -not $Global:PsimBereitstellungWeg.ContainsKey([string]$_.PackageName) })
    }

    function Global:Disable-WindowsOptionalFeature {
        # PSIM-ATTRAPPE
        param([switch]$Online, [string]$FeatureName, [switch]$NoRestart,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'FUNKTION-AUS' -Ziel $FeatureName
        return [pscustomobject]@{ RestartNeeded = $false }
    }

    function Global:Enable-WindowsOptionalFeature {
        # PSIM-ATTRAPPE
        param([switch]$Online, [string]$FeatureName, [switch]$NoRestart,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'FUNKTION-EIN' -Ziel $FeatureName
        return [pscustomobject]@{ RestartNeeded = $false }
    }

    function Global:Checkpoint-Computer {
        # PSIM-ATTRAPPE
        param([string]$Description, [string]$RestorePointType,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'WIEDERHERSTELLUNGSPUNKT' -Ziel $Description
    }

    function Global:Delete-DeliveryOptimizationCache {
        # PSIM-ATTRAPPE
        param([switch]$Force, [switch]$IncludePinnedFiles,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'DO-ZWISCHENSPEICHER' -Ziel 'leeren'
    }

    function Global:Clear-RecycleBin {
        # PSIM-ATTRAPPE
        param([string]$DriveLetter, [switch]$Force, [switch]$Confirm,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'PAPIERKORB' -Ziel 'leeren'
    }

    function Global:Restart-Computer {
        # PSIM-ATTRAPPE
        param([switch]$Force, [switch]$Confirm,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'NEUSTART' -Ziel 'Restart-Computer' -Wert 'ABGEFANGEN'
    }

    function Global:Start-Process {
        # PSIM-ATTRAPPE - fängt bcdedit, reg.exe, gpupdate, powercfg
        param([string]$FilePath, $ArgumentList, [switch]$Wait, [switch]$PassThru,
              [string]$WindowStyle, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        $arg = ''
        try { $arg = (@($ArgumentList) -join ' ') } catch { }
        Add-PsimVorgang -Art 'PROGRAMM' -Ziel $FilePath -Wert $arg
        if ($FilePath -match 'bcdedit' -and $arg -match 'hypervisorlaunchtype\s+(\w+)') { $Global:PsimHypervisor = $matches[1] }
        return [pscustomobject]@{ ExitCode = 0; HasExited = $true }
    }

    function Global:Set-Acl {
        # PSIM-ATTRAPPE
        param([string]$Path, [string]$LiteralPath, $AclObject,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        $z = if ($LiteralPath) { $LiteralPath } else { $Path }
        Add-PsimVorgang -Art 'RECHTE' -Ziel $z
    }

    function Global:Copy-Item {
        # PSIM-ATTRAPPE
        param([string]$Path, [string]$LiteralPath, [string]$Destination,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        $z = if ($LiteralPath) { $LiteralPath } else { $Path }
        Add-PsimVorgang -Art 'KOPIEREN' -Ziel "$z -> $Destination"
        # Sicherung zurück auf die Hosts-Datei gelegt: wieder den echten Inhalt lesen
        if ($Global:OrcaHostsDatei -and $Destination -eq $Global:OrcaHostsDatei) { $Global:PsimDateien.Remove($Destination) }
    }

    function Global:Get-OrcaHostsKennung {
        # PSIM-ATTRAPPE
        if ($Global:PsimDateien.ContainsKey($Global:OrcaHostsDatei)) {
            $t = [string]$Global:PsimDateien[$Global:OrcaHostsDatei]
            return @{ Zeit = 'Simulation'; Laenge = $t.Length }
        }
        return (& $Global:PsimEcht['Get-OrcaHostsKennung'])
    }

    function Global:Write-OrcaHostsText {
        param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
        $Global:PsimDateien[$Global:OrcaHostsDatei] = $Text
        Add-PsimVorgang -Art 'DATEI-SCHREIBEN' -Ziel $Global:OrcaHostsDatei -Wert ("{0} Zeichen" -f $Text.Length)
    }

    function Global:Read-OrcaHostsText {
        # PSIM-ATTRAPPE
        if ($Global:PsimDateien.ContainsKey($Global:OrcaHostsDatei)) { return [string]$Global:PsimDateien[$Global:OrcaHostsDatei] }
        return (& $Global:PsimEcht['Read-OrcaHostsText'])
    }

    function Global:Get-OrcaShutdownRegistrierung {
        # PSIM-ATTRAPPE
        $r = & $Global:PsimEcht['Get-OrcaShutdownRegistrierung']
        if ($Global:PsimShutdown -eq 'ein') {
            $r.Datei = $true; $r.IniZeile = $true; $r.GptIni = $true; $r.Windows = $true; $r.Vollstaendig = $true
            if ($null -eq $r.Index) { $r.Index = 0 }
        } elseif ($Global:PsimShutdown -eq 'aus') {
            $r.Datei = $false; $r.IniZeile = $false; $r.Windows = $false; $r.Vollstaendig = $false; $r.Index = $null
        }
        return $r
    }

    function Global:Register-OrcaShutdownSkript {
        # PSIM-ATTRAPPE
        param([string]$Quelle)
        $vorher = $Global:PsimShutdown; $Global:PsimShutdown = 'ein'
        $r = & $Global:PsimEcht['Register-OrcaShutdownSkript'] -Quelle $Quelle
        if (-not $r.Erfolg) { $Global:PsimShutdown = $vorher }
        return $r
    }

    function Global:Unregister-OrcaShutdownSkript {
        # PSIM-ATTRAPPE
        $vorher = $Global:PsimShutdown; $Global:PsimShutdown = 'aus'
        $r = & $Global:PsimEcht['Unregister-OrcaShutdownSkript']
        if (-not $r.Erfolg) { $Global:PsimShutdown = $vorher }
        return $r
    }

    function Global:Get-OrcaComputerschutz {
        # PSIM-ATTRAPPE - echt gemessen, der Schalter kommt aus der Simulation
        $cs = & $Global:PsimEcht['Get-OrcaComputerschutz']
        if ($Global:PsimComputerschutz) {
            $cs.An = ($Global:PsimComputerschutz -eq 'an')
            $cs.Text = "$($Global:PsimComputerschutz) · $($cs.Kopien) $(if ($cs.Kopien -eq 1) { 'Schattenkopie' } else { 'Schattenkopien' }) auf $env:SystemDrive"
        }
        return $cs
    }

    function Global:Move-Item {
        # PSIM-ATTRAPPE
        param([string]$Path, [string]$LiteralPath, [string]$Destination,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        $z = if ($LiteralPath) { $LiteralPath } else { $Path }
        Add-PsimVorgang -Art 'VERSCHIEBEN' -Ziel "$z -> $Destination"
    }

    function Global:Set-DnsClientServerAddress {
        # PSIM-ATTRAPPE
        param($InterfaceIndex, [string]$InterfaceAlias, $ServerAddresses, [switch]$ResetServerAddresses,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        $wer = if ($InterfaceAlias) { $InterfaceAlias } else { "Schnittstelle $InterfaceIndex" }
        $was = if ($ResetServerAddresses) { 'zurücksetzen (DHCP)' } else { (@($ServerAddresses) -join ', ') }
        Add-PsimVorgang -Art 'DNS' -Ziel $wer -Wert $was
        $a = $null
        if ($InterfaceIndex) { $a = NetAdapter\Get-NetAdapter -InterfaceIndex $InterfaceIndex -ErrorAction SilentlyContinue }
        elseif ($InterfaceAlias) { $a = NetAdapter\Get-NetAdapter -Name $InterfaceAlias -ErrorAction SilentlyContinue }
        if ($a) {
            $guid = [string]$a.InterfaceGuid
            $l = @($ServerAddresses)
            $v4 = if ($ResetServerAddresses) { '' } else { (@($l | Where-Object { $_ -notmatch ':' }) -join ',') }
            $v6 = if ($ResetServerAddresses) { '' } else { (@($l | Where-Object { $_ -match ':' }) -join ',') }
            $Global:PsimRegistry["HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid|NameServer"]  = @{ Wert = $v4; Typ = 'String'; Weg = $false }
            $Global:PsimRegistry["HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\Interfaces\$guid|NameServer"] = @{ Wert = $v6; Typ = 'String'; Weg = $false }
        }
    }

    function Global:Set-DnsClientDohServerAddress {
        # PSIM-ATTRAPPE
        param([string]$ServerAddress, [string]$DohTemplate, $AllowFallbackToUdp, $AutoUpgrade,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'DNS-DOH' -Ziel $ServerAddress -Wert "AutoUpgrade=$AutoUpgrade Fallback=$AllowFallbackToUdp"
        if ($Global:PsimDoh) {
            $Global:PsimDoh[$ServerAddress] = [pscustomobject]@{ ServerAddress = $ServerAddress; DohTemplate = $DohTemplate
                                                                 AutoUpgrade = [bool]$AutoUpgrade; AllowFallbackToUdp = [bool]$AllowFallbackToUdp }
        }
    }

    function Global:Add-DnsClientDohServerAddress {
        # PSIM-ATTRAPPE
        param([string]$ServerAddress, [string]$DohTemplate, $AllowFallbackToUdp, $AutoUpgrade,
              [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'DNS-DOH' -Ziel $ServerAddress -Wert "neu: AutoUpgrade=$AutoUpgrade Fallback=$AllowFallbackToUdp"
        if ($Global:PsimDoh) {
            $Global:PsimDoh[$ServerAddress] = [pscustomobject]@{ ServerAddress = $ServerAddress; DohTemplate = $DohTemplate
                                                                 AutoUpgrade = [bool]$AutoUpgrade; AllowFallbackToUdp = [bool]$AllowFallbackToUdp }
        }
    }

    function Global:New-NetFirewallRule {
        # PSIM-ATTRAPPE
        param([string]$DisplayName, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'FIREWALL' -Ziel $DisplayName -Wert 'anlegen'
        if ($Global:PsimFirewall) { $Global:PsimFirewall[$DisplayName] = $true }
    }

    function Global:Remove-NetFirewallRule {
        # PSIM-ATTRAPPE
        param([string]$DisplayName, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'FIREWALL' -Ziel $DisplayName -Wert 'entfernen'
        if ($Global:PsimFirewall) { $Global:PsimFirewall[$DisplayName] = $false }
    }

    function Global:Get-NetFirewallRule {
        [CmdletBinding()]
        param([string]$DisplayName, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        if ($DisplayName -and $Global:PsimFirewall -and $Global:PsimFirewall.ContainsKey($DisplayName)) {
            if ($Global:PsimFirewall[$DisplayName]) {
                return [pscustomobject]@{ DisplayName = $DisplayName; Enabled = 'True'; Action = 'Block'; Direction = 'Outbound' }
            }
            return
        }
        $p = @{}; if ($DisplayName) { $p.DisplayName = $DisplayName }
        NetSecurity\Get-NetFirewallRule @p -ErrorAction SilentlyContinue
    }

    function Global:Remove-DnsClientDohServerAddress {
        # PSIM-ATTRAPPE
        param([string]$ServerAddress, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'DNS-DOH' -Ziel $ServerAddress -Wert 'entfernen'
        if ($Global:PsimDoh) { $Global:PsimDoh[$ServerAddress] = $null }
    }

    function Global:Get-DnsClientDohServerAddress {
        [CmdletBinding()]
        param([string]$ServerAddress, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        if ($ServerAddress -and $Global:PsimDoh -and $Global:PsimDoh.ContainsKey($ServerAddress)) { return $Global:PsimDoh[$ServerAddress] }
        $p = @{}; if ($ServerAddress) { $p.ServerAddress = $ServerAddress }
        DnsClient\Get-DnsClientDohServerAddress @p -ErrorAction SilentlyContinue
    }

    function Global:Disable-ComputerRestore {
        # PSIM-ATTRAPPE
        param([string[]]$Drive, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'COMPUTERSCHUTZ' -Ziel (@($Drive) -join ', ') -Wert 'aus'
        $Global:PsimComputerschutz = 'aus'
    }

    function Global:Enable-ComputerRestore {
        # PSIM-ATTRAPPE
        param([string[]]$Drive, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'COMPUTERSCHUTZ' -Ziel (@($Drive) -join ', ') -Wert 'an'
        $Global:PsimComputerschutz = 'an'
    }

    function Global:Remove-CimInstance {
        # PSIM-ATTRAPPE - löscht etwa Schattenkopien
        param($InputObject, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
        $was = if ($InputObject -and $InputObject.CimClass) { "$($InputObject.CimClass.CimClassName) $($InputObject.ID)" } else { [string]$InputObject }
        Add-PsimVorgang -Art 'CIM-LOESCHEN' -Ziel $was
        if ($Global:PsimCimWeg -and $InputObject -and $InputObject.ID) { $Global:PsimCimWeg[[string]$InputObject.ID] = $true }
    }

    function Global:Invoke-CimMethod {
        # PSIM-ATTRAPPE
        param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
        Add-PsimVorgang -Art 'CIM-METHODE' -Ziel (@($Rest) -join ' ')
    }

    function Global:Wait-OrcaCountdown {
        # PSIM-ATTRAPPE
        param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
    }

    function Global:Wait-OrcaTaste {
        # PSIM-ATTRAPPE - der Wächter wartet sonst auf eine Taste
        param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
    }

    function Global:Invoke-PsimExtern {
        # PSIM-ATTRAPPE
        param([string]$Name, $Argumente)
        $text = (@($Argumente) -join ' ')
        if (Test-PsimNurLesend -Name $Name -Text $text) {
            $exe = Get-Command "$Name.exe" -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $exe) { return }
            $aus = @(& $exe.Source @Argumente)
            if ($Name -eq 'bcdedit' -and $Global:PsimHypervisor) {
                $aus = @($aus | Where-Object { "$_" -notmatch '^\s*hypervisorlaunchtype\s' }) + ("hypervisorlaunchtype    " + $Global:PsimHypervisor)
            }
            return $aus
        }
        Add-PsimVorgang -Art 'PROGRAMM' -Ziel $Name -Wert $text -Zusatz 'direkter Aufruf abgefangen'
        $global:LASTEXITCODE = 0
    }
    function Global:gpupdate     { <# PSIM-ATTRAPPE #> param([Parameter(ValueFromRemainingArguments = $true)]$Rest) Invoke-PsimExtern -Name 'gpupdate' -Argumente $Rest }
    function Global:gpupdate.exe { <# PSIM-ATTRAPPE #> param([Parameter(ValueFromRemainingArguments = $true)]$Rest) Invoke-PsimExtern -Name 'gpupdate' -Argumente $Rest }
    function Global:bcdedit      { <# PSIM-ATTRAPPE #> param([Parameter(ValueFromRemainingArguments = $true)]$Rest) Invoke-PsimExtern -Name 'bcdedit' -Argumente $Rest }
    function Global:bcdedit.exe  { <# PSIM-ATTRAPPE #> param([Parameter(ValueFromRemainingArguments = $true)]$Rest) Invoke-PsimExtern -Name 'bcdedit' -Argumente $Rest }
    function Global:powercfg     { <# PSIM-ATTRAPPE #> param([Parameter(ValueFromRemainingArguments = $true)]$Rest) Invoke-PsimExtern -Name 'powercfg' -Argumente $Rest }
    function Global:powercfg.exe { <# PSIM-ATTRAPPE #> param([Parameter(ValueFromRemainingArguments = $true)]$Rest) Invoke-PsimExtern -Name 'powercfg' -Argumente $Rest }
    function Global:fsutil       { <# PSIM-ATTRAPPE #> param([Parameter(ValueFromRemainingArguments = $true)]$Rest) Invoke-PsimExtern -Name 'fsutil' -Argumente $Rest }
    function Global:fsutil.exe   { <# PSIM-ATTRAPPE #> param([Parameter(ValueFromRemainingArguments = $true)]$Rest) Invoke-PsimExtern -Name 'fsutil' -Argumente $Rest }
    function Global:defrag       { <# PSIM-ATTRAPPE #> param([Parameter(ValueFromRemainingArguments = $true)]$Rest) Invoke-PsimExtern -Name 'defrag' -Argumente $Rest }
    function Global:defrag.exe   { <# PSIM-ATTRAPPE #> param([Parameter(ValueFromRemainingArguments = $true)]$Rest) Invoke-PsimExtern -Name 'defrag' -Argumente $Rest }
    function Global:icacls       { <# PSIM-ATTRAPPE #> param([Parameter(ValueFromRemainingArguments = $true)]$Rest) Invoke-PsimExtern -Name 'icacls' -Argumente $Rest }
    function Global:icacls.exe   { <# PSIM-ATTRAPPE #> param([Parameter(ValueFromRemainingArguments = $true)]$Rest) Invoke-PsimExtern -Name 'icacls' -Argumente $Rest }
    function Global:netsh        { <# PSIM-ATTRAPPE #> param([Parameter(ValueFromRemainingArguments = $true)]$Rest) Invoke-PsimExtern -Name 'netsh' -Argumente $Rest }
    function Global:netsh.exe    { <# PSIM-ATTRAPPE #> param([Parameter(ValueFromRemainingArguments = $true)]$Rest) Invoke-PsimExtern -Name 'netsh' -Argumente $Rest }
    function Global:vssadmin     { <# PSIM-ATTRAPPE #> param([Parameter(ValueFromRemainingArguments = $true)]$Rest) Invoke-PsimExtern -Name 'vssadmin' -Argumente $Rest }
    function Global:vssadmin.exe { <# PSIM-ATTRAPPE #> param([Parameter(ValueFromRemainingArguments = $true)]$Rest) Invoke-PsimExtern -Name 'vssadmin' -Argumente $Rest }

}

# --- Selbsttest der Attrappen ---------------------------------
function Get-PsimAttrappenNamen {
    # Die Namen kommen aus dem Block selbst - so kann die Liste
    # nicht hinter den Attrappen zurückbleiben.
    $text = $Global:PsimAttrappenBlock.ToString()
    return @([regex]::Matches($text, '(?m)^\s*function\s+Global:([\w\-\.]+)') |
             ForEach-Object { $_.Groups[1].Value })
}

function Get-PsimVerlorene {
    $weg = @()
    foreach ($n in (Get-PsimAttrappenNamen)) {
        $c = Get-Command -Name $n -CommandType Function -ErrorAction SilentlyContinue
        if (-not $c -or $c.ScriptBlock.ToString() -notmatch 'PSIM-ATTRAPPE') { $weg += $n }
    }
    return $weg
}

