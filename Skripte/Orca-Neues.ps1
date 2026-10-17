
$Global:OrcaNeuesArten = @(
    @{ Name = 'autostart';   Anzeige = 'Autostart' }
    @{ Name = 'richtlinien'; Anzeige = 'Fremde Richtlinien' }
    @{ Name = 'zertifikate'; Anzeige = 'Stammzertifikate' }
    @{ Name = 'proxy';       Anzeige = 'Proxy' }
    @{ Name = 'firewall';    Anzeige = 'Firewall eingehend' }
    @{ Name = 'telemetrie';  Anzeige = 'Neue Telemetrie' }
)

$Global:OrcaTelemetrieMuster = 'Telemetr|DiagTrack|Diagnos|CEIP|Customer Experience|Consolidator|Compatibility Appraiser|Appraiser|Census|Flighting|Inventory|Sqm|UsageData|Feedback|Siuf|dmwappush'

function ConvertTo-OrcaNeuesText {
    # Ein Wert als kurzer, lesbarer Text (Listen verbunden, Binärdaten als Hex, gekürzt)
    param($Wert)
    if ($null -eq $Wert) { return '' }
    if ($Wert -is [byte[]]) { $t = (($Wert | Select-Object -Last 64 | ForEach-Object { $_.ToString('x2') }) -join '') }
    elseif ($Wert -is [array]) { $t = (@($Wert) -join ' | ') }
    else { $t = [string]$Wert }
    $t = ($t -replace '[\x00-\x1f]', ' ').Trim()
    if ($t.Length -gt 200) { $t = $t.Substring(0, 200) + ' …' }
    return $t
}

function New-OrcaNeuesEintrag {
    param([string]$Schluessel, [string]$Anzeige)
    return [ordered]@{ schluessel = $Schluessel; anzeige = $Anzeige }
}

# --------------------------------------------------------------
#  BESTANDSLISTEN (nur lesend)
# --------------------------------------------------------------
function Get-OrcaBestandAutostart {
    $liste = New-Object System.Collections.ArrayList
    $orte = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    )
    foreach ($o in $orte) {
        $k = Get-OrcaRegSchluessel -Pfad $o
        foreach ($n in @($k.Werte.Keys | Sort-Object)) {
            $w = ConvertTo-OrcaNeuesText $k.Werte[$n]
            [void]$liste.Add((New-OrcaNeuesEintrag -Schluessel "run:$o|$n=$w" -Anzeige "$n → $w ($(Split-Path $o -Leaf), $($o.Substring(0,4)))"))
        }
    }
    foreach ($ordner in @([Environment]::GetFolderPath('Startup'), [Environment]::GetFolderPath('CommonStartup'))) {
        if (-not $ordner -or -not (Test-Path -LiteralPath $ordner)) { continue }
        foreach ($f in @(Get-ChildItem -LiteralPath $ordner -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' })) {
            [void]$liste.Add((New-OrcaNeuesEintrag -Schluessel "ordner:$($f.FullName)" -Anzeige "$($f.Name) (Autostart-Ordner)"))
        }
    }
    # Geplante Aufgaben, die bei der Anmeldung oder beim Start laufen
    foreach ($t in @(Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        if (-not $t -or "$($t.TaskName)" -like 'OrcaShield*') { continue }
        $ausl = @($t.Triggers | Where-Object { $_ -and $_.CimClass -and $_.CimClass.CimClassName -in @('MSFT_TaskLogonTrigger', 'MSFT_TaskBootTrigger') })
        if ($ausl.Count -eq 0) { continue }
        $was = ConvertTo-OrcaNeuesText (@($t.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)".Trim() }) -join ' ; ')
        [void]$liste.Add((New-OrcaNeuesEintrag -Schluessel "aufgabe:$($t.TaskPath)$($t.TaskName)" -Anzeige "$($t.TaskPath)$($t.TaskName) → $was"))
    }
    return ,$liste
}

function Get-OrcaBestandRichtlinien {
    # Alle Werte unter den Richtlinienzweigen, die nicht aus dem Katalog
    # stammen. Der Wert gehört zum Schlüssel: Wird eine fremde Richtlinie
    # geändert, ist das ein neuer Eintrag.
    $eigen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($s in $Global:OrcaEinstellungen) { if ($s.Pfad -and $s.Wert) { [void]$eigen.Add("$($s.Pfad)|$($s.Wert)") } }
    $liste = New-Object System.Collections.ArrayList
    foreach ($wurzel in @('HKLM:\SOFTWARE\Policies', 'HKCU:\SOFTWARE\Policies')) {
        if (-not (Test-Path -LiteralPath $wurzel)) { continue }
        $schluessel = @(Get-Item -LiteralPath $wurzel -ErrorAction SilentlyContinue) + @(Get-ChildItem -LiteralPath $wurzel -Recurse -ErrorAction SilentlyContinue)
        foreach ($k in $schluessel) {
            if (-not $k) { continue }
            $pfad = $wurzel.Substring(0, 5) + ($k.Name -replace '^HKEY_[A-Z_]+', '')
            foreach ($n in @($k.GetValueNames())) {
                $name = if ($n) { $n } else { '(Standard)' }
                if ($eigen.Contains("$pfad|$name")) { continue }
                $w = ConvertTo-OrcaNeuesText ($k.GetValue($n))
                [void]$liste.Add((New-OrcaNeuesEintrag -Schluessel "pol:$pfad|$name=$w" -Anzeige "$pfad\$name = $w"))
                if ($liste.Count -ge 5000) { return ,$liste }
            }
        }
    }
    return ,$liste
}

function Get-OrcaBestandZertifikate {
    $liste = New-Object System.Collections.ArrayList
    $gesehen = @{}
    foreach ($ort in @('Cert:\LocalMachine\Root', 'Cert:\CurrentUser\Root')) {
        foreach ($z in @(Get-ChildItem -LiteralPath $ort -ErrorAction SilentlyContinue)) {
            if (-not $z.Thumbprint -or $gesehen.ContainsKey($z.Thumbprint)) { continue }
            $gesehen[$z.Thumbprint] = $true
            $name = if ($z.Subject -match 'CN=([^,]+)') { $matches[1] } else { $z.Subject }
            [void]$liste.Add((New-OrcaNeuesEintrag -Schluessel "zert:$($z.Thumbprint)" -Anzeige "$name (gültig bis $($z.NotAfter.ToString('dd.MM.yyyy')), $($ort.Split('\')[1]))"))
        }
    }
    return ,$liste
}

function Get-OrcaWinHttpProxy {
    # WinHttpSettings: DWORD Größe, DWORD Zähler, DWORD Art (1 = direkt),
    # dann Länge + Proxy, Länge + Ausnahmen (ASCII)
    $roh = Get-OrcaRegWert -Pfad 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections' -Name 'WinHttpSettings'
    if (-not ($roh -is [byte[]]) -or $roh.Length -lt 16) { return 'direkt' }
    try {
        $art = [BitConverter]::ToInt32($roh, 8)
        $len = [BitConverter]::ToInt32($roh, 12)
        $proxy = if ($len -gt 0 -and 16 + $len -le $roh.Length) { [Text.Encoding]::ASCII.GetString($roh, 16, $len) } else { '' }
        if (($art -band 2) -and $proxy) { return "Proxy $proxy" }
        return 'direkt'
    } catch { return 'nicht lesbar' }
}

function Get-OrcaBestandProxy {
    # Ein Eintrag je Quelle, auch "direkt" - so ist jede Änderung ein neuer Schlüssel.
    $liste = New-Object System.Collections.ArrayList
    $is = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings'
    $an = [int](Get-OrcaRegWert -Pfad $is -Name 'ProxyEnable')
    $srv = ConvertTo-OrcaNeuesText (Get-OrcaRegWert -Pfad $is -Name 'ProxyServer')
    $pac = ConvertTo-OrcaNeuesText (Get-OrcaRegWert -Pfad $is -Name 'AutoConfigURL')
    $b = if ($an -eq 1 -and $srv) { "Proxy $srv" } else { 'direkt' }
    if ($pac) { $b += " · Skript $pac" }
    [void]$liste.Add((New-OrcaNeuesEintrag -Schluessel "proxy:benutzer=$b" -Anzeige "Benutzer: $b"))
    $wh = Get-OrcaWinHttpProxy
    [void]$liste.Add((New-OrcaNeuesEintrag -Schluessel "proxy:winhttp=$wh" -Anzeige "System (WinHTTP): $wh"))
    foreach ($ort in @(@{ P = 'HKCU:\Environment'; N = 'Benutzer' }, @{ P = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'; N = 'System' })) {
        foreach ($v in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY')) {
            $w = ConvertTo-OrcaNeuesText (Get-OrcaRegWert -Pfad $ort.P -Name $v)
            if ($w) { [void]$liste.Add((New-OrcaNeuesEintrag -Schluessel "proxy:umgebung:$($ort.N):$v=$w" -Anzeige "Umgebungsvariable $v ($($ort.N)) = $w")) }
        }
    }
    return ,$liste
}

function Get-OrcaBestandFirewall {
    # Eingeschaltete Regeln, die eingehende Verbindungen erlauben.
    # Modulgenau: OrcaShield legt selbst nur ausgehende Sperren an.
    $liste = New-Object System.Collections.ArrayList
    foreach ($r in @(NetSecurity\Get-NetFirewallRule -Direction Inbound -Action Allow -Enabled True -ErrorAction SilentlyContinue)) {
        if (-not $r) { continue }
        [void]$liste.Add((New-OrcaNeuesEintrag -Schluessel "fw:$($r.Name)" -Anzeige "$($r.DisplayName) ($($r.Profile))"))
    }
    return ,$liste
}

function Get-OrcaBestandTelemetrie {
    # Aufgaben und Dienste mit den Namen bekannter Sammler, die nicht im
    # Katalog stehen - damit ein neuer Sammler auffällt, bevor er dort steht.
    $katalog = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($s in $Global:OrcaEinstellungen) { if ($s.Typ -in @('Aufgabe', 'Dienst') -and $s.Wert) { [void]$katalog.Add([string]$s.Wert) } }
    $liste = New-Object System.Collections.ArrayList
    foreach ($t in @(Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        if (-not $t) { continue }
        $voll = "$($t.TaskPath)$($t.TaskName)"
        if ($voll -notmatch $Global:OrcaTelemetrieMuster -or $katalog.Contains($voll)) { continue }
        [void]$liste.Add((New-OrcaNeuesEintrag -Schluessel "aufgabe:$voll" -Anzeige "Aufgabe $voll ($($t.State))"))
    }
    foreach ($d in @(Get-CimInstance -ClassName Win32_Service -ErrorAction SilentlyContinue)) {
        if (-not $d) { continue }
        if ("$($d.Name) $($d.DisplayName)" -notmatch $Global:OrcaTelemetrieMuster -or $katalog.Contains([string]$d.Name)) { continue }
        [void]$liste.Add((New-OrcaNeuesEintrag -Schluessel "dienst:$($d.Name)" -Anzeige "Dienst $($d.Name) - $($d.DisplayName) ($($d.StartMode))"))
    }
    return ,$liste
}

function Get-OrcaBestand {
    param([Parameter(Mandatory)][string]$Art)
    switch ($Art) {
        'autostart'   { return ,(Get-OrcaBestandAutostart) }
        'richtlinien' { return ,(Get-OrcaBestandRichtlinien) }
        'zertifikate' { return ,(Get-OrcaBestandZertifikate) }
        'proxy'       { return ,(Get-OrcaBestandProxy) }
        'firewall'    { return ,(Get-OrcaBestandFirewall) }
        'telemetrie'  { return ,(Get-OrcaBestandTelemetrie) }
        default       { throw "Unbekannte Art: $Art" }
    }
}

# --------------------------------------------------------------
#  VERGLEICH UND AUFNEHMEN
# --------------------------------------------------------------
function Get-OrcaBekannt {
    # Rückgabe: Tabelle Art -> HashSet der bekannten Schlüssel; fehlt eine
    # Art, gibt es für sie noch keine Ausgangsliste.
    param($State)
    $tab = @{}
    if ($State -and $State.Bekannt) {
        foreach ($p in $State.Bekannt.PSObject.Properties) {
            $menge = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
            foreach ($s in @($p.Value)) { if ($s) { [void]$menge.Add([string]$s) } }
            $tab[$p.Name] = $menge
        }
    }
    return $tab
}

function Get-OrcaNeues {
    # Rückgabe je Art: @{ art; anzeige; erstlauf; bestand; neu = @(Einträge) }
    param($State, [string[]]$Arten = @($Global:OrcaNeuesArten | ForEach-Object { $_.Name }))
    $bekannt = Get-OrcaBekannt -State $State
    $aus = New-Object System.Collections.ArrayList
    foreach ($a in $Global:OrcaNeuesArten) {
        if ($a.Name -notin $Arten) { continue }
        $e = [ordered]@{ art = $a.Name; anzeige = $a.Anzeige; erstlauf = $false; bestand = 0; neu = @(); fehler = '' }
        try {
            $liste = Get-OrcaBestand -Art $a.Name
            $e.bestand = $liste.Count
            if (-not $bekannt.ContainsKey($a.Name)) { $e.erstlauf = $true }
            else { $e.neu = @($liste | Where-Object { -not $bekannt[$a.Name].Contains($_.schluessel) }) }
        } catch { $e.fehler = $_.Exception.Message }
        [void]$aus.Add($e)
    }
    # Ohne Komma: Die Einträge sollen einzeln in die Pipeline (ForEach-Object).
    return $aus.ToArray()
}

function Get-OrcaSammlerStand {
    # Rückgabe: @{ Da; Art; Ziel; Stand } - Stand: Aufgabe 'Ready'/'Disabled'…,
    # Dienst 'Automatic'/'AutomaticDelayed'/'Manual'/'Disabled'
    param([Parameter(Mandatory)][string]$Schluessel)
    if ($Schluessel -match '^aufgabe:(.+)$') {
        $voll = $matches[1]; $pfad = $voll.Substring(0, $voll.LastIndexOf('\') + 1); $name = $voll.Substring($voll.LastIndexOf('\') + 1)
        $t = Get-ScheduledTask -TaskPath $pfad -TaskName $name -ErrorAction SilentlyContinue | Select-Object -Last 1
        return @{ Da = [bool]$t; Art = 'aufgabe'; Ziel = $voll; Pfad = $pfad; Name = $name; Stand = $(if ($t) { [string]$t.State } else { '' }) }
    }
    if ($Schluessel -match '^dienst:(.+)$') {
        $n = $matches[1]
        $d = @(Get-CimInstance -ClassName Win32_Service -Filter "Name='$($n -replace "'", "''")'" -ErrorAction SilentlyContinue) | Select-Object -Last 1
        $stand = ''
        if ($d) {
            $stand = switch ([string]$d.StartMode) { 'Auto' { 'Automatic' } 'Manual' { 'Manual' } 'Disabled' { 'Disabled' } default { [string]$d.StartMode } }
            if ($stand -eq 'Automatic' -and [int](Get-OrcaRegWert -Pfad "HKLM:\SYSTEM\CurrentControlSet\Services\$n" -Name 'DelayedAutostart') -eq 1) { $stand = 'AutomaticDelayed' }
        }
        return @{ Da = [bool]$d; Art = 'dienst'; Ziel = $n; Stand = $stand }
    }
    return @{ Da = $false; Art = ''; Ziel = ''; Stand = '' }
}

function Get-OrcaEigeneSperren {
    param($State = (Get-OrcaState))
    return @(if ($State -and $State.EigeneSperren) { @($State.EigeneSperren | Where-Object { $_ -and $_.Schluessel }) })
}

function Set-OrcaSammlerAus {
    # Schaltet einen Eintrag ab (ohne Buchführung). Rückgabe: @{ Erfolg; Grund }
    param([Parameter(Mandatory)]$Stand)
    try {
        if ($Stand.Art -eq 'aufgabe') { Disable-ScheduledTask -TaskPath $Stand.Pfad -TaskName $Stand.Name -ErrorAction Stop | Out-Null }
        else {
            Stop-Service -Name $Stand.Ziel -Force -ErrorAction SilentlyContinue
            Set-Service -Name $Stand.Ziel -StartupType Disabled -ErrorAction Stop
        }
        return @{ Erfolg = $true; Grund = '' }
    } catch { return @{ Erfolg = $false; Grund = $_.Exception.Message } }
}

function Disable-OrcaNeuerSammler {
    # Rückgabe: @{ Erfolg; Status; Grund }
    param([Parameter(Mandatory)][string]$Schluessel)
    $st = Get-OrcaState
    if (-not $st) { return @{ Erfolg = $false; Status = 'Fehler'; Grund = 'keine Zustandsdatei' } }
    $bestand = @(Get-OrcaBestandTelemetrie | ForEach-Object { $_.schluessel })
    if ($Schluessel -notin $bestand) { return @{ Erfolg = $false; Status = 'Unbekannt'; Grund = 'nicht in der Liste neuer Telemetrie - nicht angefasst' } }
    $sperren = @(Get-OrcaEigeneSperren -State $st)
    if (@($sperren | Where-Object { $_.Schluessel -eq $Schluessel }).Count) { return @{ Erfolg = $true; Status = 'Unveraendert'; Grund = 'schon abgeschaltet' } }
    $vorher = Get-OrcaSammlerStand -Schluessel $Schluessel
    if (-not $vorher.Da) { return @{ Erfolg = $false; Status = 'NichtVorhanden'; Grund = 'nicht mehr vorhanden' } }
    # Erst festhalten, dann schalten - ein Abbruch dazwischen hinterlässt einen bekannten Zustand
    $eintrag = [pscustomobject]@{ Schluessel = $Schluessel; Art = $vorher.Art; Ziel = $vorher.Ziel; Vorher = $vorher.Stand; Seit = (ConvertTo-OrcaZeitstempel) }
    if (-not (Set-OrcaStateFeld -Name 'EigeneSperren' -Wert @(@($sperren) + $eintrag))) { return @{ Erfolg = $false; Status = 'Fehler'; Grund = 'Zustandsdatei nicht geschrieben - nichts geändert' } }
    $r = Set-OrcaSammlerAus -Stand $vorher
    $nach = Get-OrcaSammlerStand -Schluessel $Schluessel
    $ok = $r.Erfolg -and $nach.Stand -eq 'Disabled'
    Write-OrcaLog -Level $(if ($ok) { 'OK' } else { 'FEHLER' }) -Source 'NEUES' -Message "Abgeschaltet: $Schluessel (vorher $($vorher.Stand), jetzt $($nach.Stand))$(if ($r.Grund) { ' - ' + $r.Grund })"
    if ($ok) { [void](Add-OrcaBekannt -Art 'telemetrie' -Schluessel @($Schluessel)) }
    return @{ Erfolg = $ok; Status = $(if ($ok) { 'Gesetzt' } elseif ($r.Erfolg) { 'Offen' } else { 'Fehler' }); Grund = $(if ($ok) { '' } elseif ($r.Grund) { $r.Grund } else { "Nachprüfung: $($nach.Stand)" }) }
}

function Restore-OrcaNeuerSammler {
    # Stellt den festgehaltenen Vorher-Zustand her. Rückgabe: @{ Erfolg; Status; Grund }
    param([Parameter(Mandatory)][string]$Schluessel)
    $st = Get-OrcaState
    $sperren = @(Get-OrcaEigeneSperren -State $st)
    $e = @($sperren | Where-Object { $_.Schluessel -eq $Schluessel }) | Select-Object -Last 1
    if (-not $e) { return @{ Erfolg = $false; Status = 'Unbekannt'; Grund = 'nicht von OrcaShield abgeschaltet' } }
    $stand = Get-OrcaSammlerStand -Schluessel $Schluessel
    $grund = ''
    try {
        if ($stand.Da) {
            if ($e.Art -eq 'aufgabe') {
                if ($e.Vorher -ne 'Disabled') { Enable-ScheduledTask -TaskPath $stand.Pfad -TaskName $stand.Name -ErrorAction Stop | Out-Null }
            } else {
                $art = if ($e.Vorher -eq 'AutomaticDelayed') { 'Automatic' } elseif ($e.Vorher -in @('Automatic', 'Manual', 'Disabled')) { $e.Vorher } else { 'Manual' }
                Set-Service -Name $e.Ziel -StartupType $art -ErrorAction Stop
                if ($e.Vorher -eq 'AutomaticDelayed') { [void](Set-OrcaRegWert -Pfad "HKLM:\SYSTEM\CurrentControlSet\Services\$($e.Ziel)" -Name 'DelayedAutostart' -Wert 1) }
            }
        } else { $grund = 'gibt es nicht mehr - nur aus der Liste genommen' }
    } catch {
        return @{ Erfolg = $false; Status = 'Fehler'; Grund = $_.Exception.Message }
    }
    $nach = Get-OrcaSammlerStand -Schluessel $Schluessel
    $erwartet = if ($e.Art -eq 'aufgabe') { if ($e.Vorher -eq 'Disabled') { 'Disabled' } else { $null } } else { $e.Vorher }
    $ok = (-not $stand.Da) -or ($(if ($null -eq $erwartet) { $nach.Stand -ne 'Disabled' } else { $nach.Stand -eq $erwartet }))
    if ($ok) { [void](Set-OrcaStateFeld -Name 'EigeneSperren' -Wert @($sperren | Where-Object { $_.Schluessel -ne $Schluessel })) }
    Write-OrcaLog -Level $(if ($ok) { 'OK' } else { 'FEHLER' }) -Source 'NEUES' -Message "Zurückgenommen: $Schluessel (vorher $($e.Vorher), jetzt $($nach.Stand))"
    return @{ Erfolg = $ok; Status = $(if ($ok) { 'Zurueckgesetzt' } else { 'Offen' }); Grund = $(if ($ok) { $grund } else { "Nachprüfung: $($nach.Stand)" }) }
}

function Invoke-OrcaEigeneSperrenHalten {
    # Für den Wächter: jede eigene Sperre nachsehen und bei Bedarf erneut abschalten.
    # Rückgabe: @{ Geprueft; Zurueckgestellt = @(Ziele); Fehler = @(Texte) }
    $erg = @{ Geprueft = 0; Zurueckgestellt = @(); Fehler = @() }
    foreach ($e in (Get-OrcaEigeneSperren)) {
        $erg.Geprueft++
        $s = Get-OrcaSammlerStand -Schluessel $e.Schluessel
        if (-not $s.Da -or $s.Stand -eq 'Disabled') { continue }
        $r = Set-OrcaSammlerAus -Stand $s
        if ($r.Erfolg) { $erg.Zurueckgestellt += $e.Ziel } else { $erg.Fehler += "$($e.Ziel): $($r.Grund)" }
    }
    return $erg
}

function ConvertTo-OrcaRegDaten {
    # Registrywert als speicherbarer Text (JSON-tauglich)
    param($Wert, [string]$Typ)
    switch ($Typ) {
        'Binary'      { return [Convert]::ToBase64String([byte[]]$Wert) }
        'MultiString' { return @($Wert | ForEach-Object { [string]$_ }) }
        'DWord'       { return [string][uint32]([int64]$Wert -band 0xFFFFFFFF) }
        'QWord'       { return [string]$Wert }
        default       { return [string]$Wert }
    }
}

function ConvertFrom-OrcaRegDaten {
    param($Daten, [string]$Typ)
    switch ($Typ) {
        'Binary'      { return [byte[]][Convert]::FromBase64String([string]$Daten) }
        'MultiString' { return [string[]]@($Daten) }
        'DWord'       { $u = [uint32][string]$Daten; return [int32][BitConverter]::ToInt32([BitConverter]::GetBytes($u), 0) }
        'QWord'       { return [int64][string]$Daten }
        default       { return [string]$Daten }
    }
}

function Get-OrcaAufgehobeneRichtlinien {
    param($State = (Get-OrcaState))
    return @(if ($State -and $State.AufgehobeneRichtlinien) { @($State.AufgehobeneRichtlinien | Where-Object { $_ -and $_.Schluessel }) })
}

function Get-OrcaRichtlinienTitel {
    # Titel der Richtlinien aus den Vorlagen (ADMX/ADML), Schlüssel "pfad|wert" klein.
    # Einmal je Sitzung aufgebaut - nur für die Anzeige.
    if ($Global:OrcaRichtlinienTitel) { return $Global:OrcaRichtlinienTitel }
    $tab = @{}
    $pd = Join-Path $env:windir 'PolicyDefinitions'
    $sprache = if (Test-Path -LiteralPath (Join-Path $pd 'de-DE')) { 'de-DE' } else { 'en-US' }
    foreach ($f in @(Get-ChildItem -LiteralPath $pd -Filter '*.admx' -ErrorAction SilentlyContinue)) {
        try {
            [xml]$x = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 -ErrorAction Stop
            $adml = Join-Path (Join-Path $pd $sprache) ($f.BaseName + '.adml')
            if (-not (Test-Path -LiteralPath $adml)) { $adml = Join-Path (Join-Path $pd 'en-US') ($f.BaseName + '.adml') }
            $texte = @{}
            if (Test-Path -LiteralPath $adml) {
                [xml]$a = Get-Content -LiteralPath $adml -Raw -Encoding UTF8 -ErrorAction Stop
                foreach ($s in @($a.policyDefinitionResources.resources.stringTable.string)) { if ($s) { $texte[$s.id] = $s.'#text' } }
            }
            foreach ($p in @($x.policyDefinitions.policies.policy)) {
                if (-not $p) { continue }
                $titel = $texte[($p.displayName -replace '^\$\(string\.(.+)\)$', '$1')]
                if (-not $titel) { continue }
                $paare = @()
                if ($p.valueName) { $paare += ,@($p.key, $p.valueName) }
                foreach ($el in @($p.elements.ChildNodes)) { if ($el -and $el.valueName) { $paare += ,@($(if ($el.key) { $el.key } else { $p.key }), $el.valueName) } }
                foreach ($pr in $paare) { $tab[("$($pr[0])|$($pr[1])").ToLower()] = $titel }
            }
        } catch { }
    }
    $Global:OrcaRichtlinienTitel = $tab
    return $tab
}

function Get-OrcaFremdeRichtlinienListe {
    # Alle fremden Richtlinienwerte mit Titel aus den Vorlagen (für die Oberfläche)
    $titel = $null
    $aus = New-Object System.Collections.ArrayList
    foreach ($e in (Get-OrcaBestandRichtlinien)) {
        if ($null -eq $titel) { $titel = Get-OrcaRichtlinienTitel }
        $roh = $e.schluessel.Substring(4)
        $trenn = $roh.IndexOf('|'); $pfad = $roh.Substring(0, $trenn); $rest = $roh.Substring($trenn + 1)
        $name = $rest.Substring(0, $rest.IndexOf('='))
        $relativ = ($pfad -replace '^HK(LM|CU):\\', '')
        [void]$aus.Add([ordered]@{ schluessel = $e.schluessel; anzeige = $e.anzeige; titel = "$($titel[("$relativ|$name").ToLower()])"; bereich = $(if ($pfad -like 'HKCU:*') { 'Benutzer' } else { 'Maschine' }) })
        if ($aus.Count -ge 500) { break }
    }
    return ,$aus
}

function Remove-OrcaFremdeRichtlinie {
    # Rückgabe: @{ Erfolg; Status; Grund }
    param([Parameter(Mandatory)][string]$Schluessel)
    $st = Get-OrcaState
    if (-not $st) { return @{ Erfolg = $false; Status = 'Fehler'; Grund = 'keine Zustandsdatei' } }
    if (@(Get-OrcaBestandRichtlinien | Where-Object { $_.schluessel -eq $Schluessel }).Count -eq 0) {
        return @{ Erfolg = $false; Status = 'Unbekannt'; Grund = 'nicht in der Liste fremder Richtlinien - nicht angefasst' }
    }
    $roh = $Schluessel.Substring(4); $trenn = $roh.IndexOf('|')
    $pfad = $roh.Substring(0, $trenn); $rest = $roh.Substring($trenn + 1); $name = $rest.Substring(0, $rest.IndexOf('='))
    $regName = if ($name -eq '(Standard)') { '' } else { $name }
    $vorher = Get-OrcaRegWertUndTyp -Pfad $pfad -Name $regName
    if (-not $vorher.WertDa) { return @{ Erfolg = $false; Status = 'NichtVorhanden'; Grund = 'nicht mehr vorhanden' } }
    $liste = @(Get-OrcaAufgehobeneRichtlinien -State $st | Where-Object { $_.Pfad -ne $pfad -or $_.Name -ne $name })
    # Erst festhalten, dann löschen - ein Abbruch dazwischen hinterlässt einen bekannten Zustand
    $eintrag = [pscustomobject]@{ Schluessel = $Schluessel; Pfad = $pfad; Name = $name; Typ = "$($vorher.Typ)"; Daten = (ConvertTo-OrcaRegDaten -Wert $vorher.Wert -Typ "$($vorher.Typ)"); Seit = (ConvertTo-OrcaZeitstempel) }
    if (-not (Set-OrcaStateFeld -Name 'AufgehobeneRichtlinien' -Wert @(@($liste) + $eintrag))) { return @{ Erfolg = $false; Status = 'Fehler'; Grund = 'Zustandsdatei nicht geschrieben - nichts geändert' } }
    $r = Remove-OrcaRegWert -Pfad $pfad -Name $regName
    $nach = Get-OrcaRegWertUndTyp -Pfad $pfad -Name $regName
    $ok = $r.Erfolg -and -not $nach.WertDa
    Write-OrcaLog -Level $(if ($ok) { 'OK' } else { 'FEHLER' }) -Source 'RICHTLINIE' -Message "Fremde Richtlinie aufgehoben: $pfad\$name (vorher $($vorher.Typ) $(ConvertTo-OrcaNeuesText $vorher.Wert))$(if ($r.Grund) { ' - ' + $r.Grund })"
    return @{ Erfolg = $ok; Status = $(if ($ok) { 'Gesetzt' } else { 'Fehler' }); Grund = $(if ($ok) { '' } elseif ($r.Grund) { $r.Grund } else { 'Wert steht nach dem Löschen noch da' }) }
}

function Restore-OrcaFremdeRichtlinie {
    # Schreibt den festgehaltenen Wert zurück. Rückgabe: @{ Erfolg; Status; Grund }
    param([Parameter(Mandatory)][string]$Schluessel)
    $st = Get-OrcaState
    $liste = @(Get-OrcaAufgehobeneRichtlinien -State $st)
    $e = @($liste | Where-Object { $_.Schluessel -eq $Schluessel }) | Select-Object -Last 1
    if (-not $e) { return @{ Erfolg = $false; Status = 'Unbekannt'; Grund = 'nicht von OrcaShield aufgehoben' } }
    if ($e.Typ -notin @('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord')) { return @{ Erfolg = $false; Status = 'Fehler'; Grund = "Datentyp $($e.Typ) wird nicht zurückgeschrieben" } }
    $regName = if ($e.Name -eq '(Standard)') { '' } else { [string]$e.Name }
    $wert = ConvertFrom-OrcaRegDaten -Daten $e.Daten -Typ $e.Typ
    $r = Set-OrcaRegWert -Pfad $e.Pfad -Name $regName -Wert $wert -Typ $e.Typ
    $nach = Get-OrcaRegWertUndTyp -Pfad $e.Pfad -Name $regName
    $ok = $r.Erfolg -and $nach.WertDa -and "$($nach.Typ)" -eq $e.Typ
    if ($ok) { [void](Set-OrcaStateFeld -Name 'AufgehobeneRichtlinien' -Wert @($liste | Where-Object { $_.Schluessel -ne $Schluessel })) }
    Write-OrcaLog -Level $(if ($ok) { 'OK' } else { 'FEHLER' }) -Source 'RICHTLINIE' -Message "Fremde Richtlinie zurückgeschrieben: $($e.Pfad)\$($e.Name)$(if ($r.Grund) { ' - ' + $r.Grund })"
    return @{ Erfolg = $ok; Status = $(if ($ok) { 'Zurueckgesetzt' } else { 'Fehler' }); Grund = $(if ($ok) { '' } elseif ($r.Grund) { $r.Grund } else { 'Nachprüfung fehlgeschlagen' }) }
}

function Add-OrcaBekannt {
    # Nimmt Einträge in die bekannte Liste auf. Nur Schlüssel, die es gerade
    # wirklich gibt - von außen kommt so nichts Fremdes in die Zustandsdatei.
    #   -Alle: alles, was jetzt da ist (legt fehlende Ausgangslisten an)
    #   -Schluessel: einzelne Einträge
    # Rückgabe: @{ Erfolg; Aufgenommen; Grund }
    param([string]$Art, [string[]]$Schluessel = @(), [switch]$Alle)
    if ($Art -notin @($Global:OrcaNeuesArten | ForEach-Object { $_.Name })) { return @{ Erfolg = $false; Aufgenommen = 0; Grund = "Unbekannte Art: $Art" } }
    $st = Get-OrcaState
    if (-not $st) { return @{ Erfolg = $false; Aufgenommen = 0; Grund = 'keine Zustandsdatei' } }
    $bekannt = Get-OrcaBekannt -State $st
    $liste = Get-OrcaBestand -Art $Art
    $jetzt = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($e in $liste) { [void]$jetzt.Add([string]$e.schluessel) }
    # Nicht "$menge = if (...) { ... }" - die Zuweisung aus einem if packt die Menge aus (feste Liste).
    $menge = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    if ($bekannt.ContainsKey($Art)) { $menge.UnionWith($bekannt[$Art]) }
    $neu = 0
    # Ohne Ausgangsliste wird sie zuerst angelegt (wie beim ersten Wächterlauf) - sonst
    # gälte nach dem Aufnehmen eines einzelnen Eintrags alles andere als neu.
    if (-not $bekannt.ContainsKey($Art)) { $Alle = [switch]$true }
    $wahl = if ($Alle) { @($jetzt) } else { @($Schluessel | Where-Object { $_ -and $jetzt.Contains([string]$_) }) }
    foreach ($s in $wahl) { if ($menge.Add($s)) { $neu++ } }
    # Nicht mehr vorhandene Einträge fallen aus der Liste - sie wächst nicht endlos.
    $behalten = @($menge | Where-Object { $jetzt.Contains($_) })
    $tab = [ordered]@{}
    foreach ($k in $bekannt.Keys) { if ($k -ne $Art) { $tab[$k] = @($bekannt[$k]) } }
    $tab[$Art] = $behalten
    $ok = Set-OrcaStateFeld -Name 'Bekannt' -Wert ([pscustomobject]$tab)
    return @{ Erfolg = [bool]$ok; Aufgenommen = $neu; Grund = $(if ($ok) { '' } else { 'Zustandsdatei nicht geschrieben' }) }
}
