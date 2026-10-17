
#ifndef Version
  #error "Version fehlt - bitte Werkzeuge\Setup-Bauen.ps1 benutzen"
#endif
#ifndef DateiVersion
  #error "DateiVersion fehlt - bitte Werkzeuge\Setup-Bauen.ps1 benutzen"
#endif
#ifndef DateiName
  #error "DateiName fehlt - bitte Werkzeuge\Setup-Bauen.ps1 benutzen"
#endif

#define Wurzel ".."
#define Bau "..\App\Ausgabe"

[Setup]
; Kennung der Installation – nie ändern, sonst gilt jede neue Fassung als anderes Programm
AppId={{6C2E7B1A-4F0D-4E8B-9A57-0F3C1D2B8E64}
AppName=OrcaShield
AppVersion={#Version}
AppVerName=OrcaShield {#Version}
AppPublisher=Seba5ti4n
VersionInfoVersion={#DateiVersion}
VersionInfoProductTextVersion={#Version}
VersionInfoDescription=OrcaShield Setup
DefaultDirName={autopf}\OrcaShield
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableWelcomePage=no
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible or arm64
ArchitecturesInstallIn64BitMode=x64compatible or arm64
; Windows 11
MinVersion=10.0.22000
; Ein offenes OrcaShield (installiert) hält diese Sperre, Programm.cs
AppMutex=Global\OrcaShield.Programm
SetupMutex=OrcaShield.Setup
CloseApplications=no
OutputDir=Ausgabe
OutputBaseFilename=OrcaShield-Setup-{#DateiName}
SetupIconFile={#Wurzel}\App\Orca.ico
UninstallDisplayIcon={app}\OrcaShield.exe
UninstallDisplayName=OrcaShield
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
ShowLanguageDialog=auto

[Languages]
Name: "de"; MessagesFile: "compiler:Languages\German.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
de.PsFassung=Auf diesem Rechner ist bereits OrcaShield als PowerShell-Fassung eingerichtet (%1).%n%nDie Übernahme in dieses Programm ist noch nicht fertig. Es wurde nichts installiert.
en.PsFassung=OrcaShield is already set up on this PC as the PowerShell edition (%1).%n%nTaking it over into this program is not finished yet. Nothing was installed.
de.NetFehlt=OrcaShield benötigt .NET Framework 4.8.1. Es ist in Windows 11 enthalten und lässt sich über Windows Update nachinstallieren.%n%nEs wurde nichts installiert.
en.NetFehlt=OrcaShield needs .NET Framework 4.8.1. It is part of Windows 11 and can be installed via Windows Update.%n%nNothing was installed.
de.WebView2Fehlt=OrcaShield benötigt die Microsoft-Edge-WebView2-Laufzeit. Sie ist in Windows 11 enthalten und lässt sich bei Microsoft herunterladen.%n%nEs wurde nichts installiert.
en.WebView2Fehlt=OrcaShield needs the Microsoft Edge WebView2 Runtime. It is part of Windows 11 and can be downloaded from Microsoft.%n%nNothing was installed.
de.DatenordnerFehler=Der Datenordner %1 ließ sich nicht anlegen oder nicht schützen (Rückgabe %2). OrcaShield startet erst, wenn das gelingt.
en.DatenordnerFehler=The data folder %1 could not be created or protected (return code %2). OrcaShield only starts once this succeeds.
de.FrageRueckbau=Sollen vorher alle Einstellungen, die OrcaShield gesetzt hat, auf den Zustand vor der ersten Änderung zurückgesetzt werden?%n%nNein: Die Einstellungen bleiben, wie sie sind. Wächter und Bereinigung beim Herunterfahren werden in jedem Fall entfernt.
en.FrageRueckbau=Should all settings made by OrcaShield first be reset to the state before the first change?%n%nNo: the settings stay as they are. The watcher and the cleanup at shutdown are removed in any case.
de.FrageDaten=Sollen auch Zustand, Ausgangszustand, Sicherungen und Protokolle gelöscht werden?%n%nNein: Sie bleiben in %1 erhalten, und eine spätere Installation übernimmt sie. Der Ausgangszustand lässt sich nach dem Löschen nicht neu messen.
en.FrageDaten=Should the state, original state, backups and logs be deleted as well?%n%nNo: they stay in %1, and a later installation takes them over. The original state cannot be measured again after deletion.
de.RaeumtAuf=OrcaShield räumt auf …
en.RaeumtAuf=OrcaShield is cleaning up …
de.AufraeumFehler=Beim Aufräumen ist nicht alles gelungen (Rückgabe %1). Einzelheiten stehen im Protokoll unter %2.
en.AufraeumFehler=Not everything worked during cleanup (return code %1). Details are in the log under %2.

[Tasks]
Name: "desktop"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Programm – je Bauart ausdrücklich aufgezählt, damit keine alten Dateien
; aus App\Ausgabe mitkommen
Source: "{#Bau}\arm64\OrcaShield.exe"; DestDir: "{app}"; Flags: ignoreversion; Check: IsArm64
Source: "{#Bau}\arm64\OrcaShield.exe.config"; DestDir: "{app}"; Flags: ignoreversion; Check: IsArm64
Source: "{#Bau}\arm64\Microsoft.Web.WebView2.Core.dll"; DestDir: "{app}"; Flags: ignoreversion; Check: IsArm64
Source: "{#Bau}\arm64\Microsoft.Web.WebView2.WinForms.dll"; DestDir: "{app}"; Flags: ignoreversion; Check: IsArm64
Source: "{#Bau}\arm64\runtimes\win-arm64\native\WebView2Loader.dll"; DestDir: "{app}\runtimes\win-arm64\native"; Flags: ignoreversion; Check: IsArm64
Source: "{#Bau}\x64\OrcaShield.exe"; DestDir: "{app}"; Flags: ignoreversion; Check: not IsArm64
Source: "{#Bau}\x64\OrcaShield.exe.config"; DestDir: "{app}"; Flags: ignoreversion; Check: not IsArm64
Source: "{#Bau}\x64\Microsoft.Web.WebView2.Core.dll"; DestDir: "{app}"; Flags: ignoreversion; Check: not IsArm64
Source: "{#Bau}\x64\Microsoft.Web.WebView2.WinForms.dll"; DestDir: "{app}"; Flags: ignoreversion; Check: not IsArm64
Source: "{#Bau}\x64\WebView2Loader.dll"; DestDir: "{app}"; Flags: ignoreversion; Check: not IsArm64
Source: "{#Bau}\x64\runtimes\win-x64\native\WebView2Loader.dll"; DestDir: "{app}\runtimes\win-x64\native"; Flags: ignoreversion; Check: not IsArm64
; Oberfläche, Engine, Texte – direkt aus den Quellen (für beide Bauarten gleich)
Source: "{#Wurzel}\Werkzeuge\Gui\OrcaShield.html"; DestDir: "{app}\Gui"; Flags: ignoreversion
Source: "{#Wurzel}\Werkzeuge\Gui\orca-texte-en.js"; DestDir: "{app}\Gui"; Flags: ignoreversion
Source: "{#Wurzel}\Skripte\*.ps1"; DestDir: "{app}\Skripte"; Flags: ignoreversion
Source: "{#Wurzel}\Skripte\Orca-Hosts.txt"; DestDir: "{app}\Skripte"; Flags: ignoreversion
Source: "{#Wurzel}\Readme.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Wurzel}\LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion
; Wo die Engine Zustand, Ausgangszustand, Sicherungen und Protokolle ablegt (Orca-Common.ps1)
Source: "orca-datenordner.txt"; DestDir: "{app}"; Flags: ignoreversion


[Icons]
Name: "{autoprograms}\OrcaShield"; Filename: "{app}\OrcaShield.exe"
Name: "{autodesktop}\OrcaShield"; Filename: "{app}\OrcaShield.exe"; Tasks: desktop

[Run]
; shellexec: die EXE verlangt Administratorrechte – so fragt Windows wie bei jedem Start
Filename: "{app}\OrcaShield.exe"; Description: "{cm:LaunchProgram,OrcaShield}"; Flags: nowait postinstall skipifsilent shellexec

[Code]
const
  WebView2Kennung = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}';
  NetZiel = 533320;  // .NET Framework 4.8.1

var
  Rueckbau, DatenLoeschen: Boolean;

function WebView2Da(): Boolean;
var
  V: String;
begin
  Result := False;
  if RegQueryStringValue(HKLM32, 'SOFTWARE\Microsoft\EdgeUpdate\Clients\' + WebView2Kennung, 'pv', V) and (V <> '') and (V <> '0.0.0.0') then Result := True
  else if RegQueryStringValue(HKLM64, 'SOFTWARE\Microsoft\EdgeUpdate\Clients\' + WebView2Kennung, 'pv', V) and (V <> '') and (V <> '0.0.0.0') then Result := True
  else if RegQueryStringValue(HKCU, 'SOFTWARE\Microsoft\EdgeUpdate\Clients\' + WebView2Kennung, 'pv', V) and (V <> '') and (V <> '0.0.0.0') then Result := True;
end;

function NetDa(): Boolean;
var
  R: Cardinal;
begin
  Result := RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', 'Release', R) and (R >= NetZiel);
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
  if not NetDa() then
  begin
    SuppressibleMsgBox(CustomMessage('NetFehlt'), mbError, MB_OK, IDOK);
    Result := False;
    Exit;
  end;
  if not WebView2Da() then
  begin
    SuppressibleMsgBox(CustomMessage('WebView2Fehlt'), mbError, MB_OK, IDOK);
    Result := False;
    Exit;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Rc: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    // Datenordner mit derselben Logik anlegen und schützen wie beim Programmstart
    if not Exec(ExpandConstant('{app}\OrcaShield.exe'), '/datenordner', '', SW_HIDE, ewWaitUntilTerminated, Rc) or (Rc <> 0) then
      SuppressibleMsgBox(FmtMessage(CustomMessage('DatenordnerFehler'), [ExpandConstant('{commonappdata}\OrcaShield'), IntToStr(Rc)]), mbError, MB_OK, IDOK);
  end;
end;

function InitializeUninstall(): Boolean;
begin
  Result := True;
  Rueckbau := Lowercase(ExpandConstant('{param:RUECKBAU|nein}')) = 'ja';
  DatenLoeschen := Lowercase(ExpandConstant('{param:DATENLOESCHEN|nein}')) = 'ja';
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Rc: Integer;
  Befehl: String;
begin
  if CurUninstallStep = usUninstall then
  begin
    if not UninstallSilent() then
    begin
      Rueckbau := MsgBox(CustomMessage('FrageRueckbau'), mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES;
      DatenLoeschen := MsgBox(FmtMessage(CustomMessage('FrageDaten'), [ExpandConstant('{commonappdata}\OrcaShield')]),
        mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES;
    end;
    // Solange Engine und Skripte noch da sind: austragen, optional zurücksetzen und Daten löschen
    UninstallProgressForm.StatusLabel.Caption := CustomMessage('RaeumtAuf');
    Befehl := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\Skripte\Orca-Entfernen.ps1') + '"';
    if Rueckbau then Befehl := Befehl + ' -Rueckbau';
    if DatenLoeschen then Befehl := Befehl + ' -DatenLoeschen';
    if not Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'), Befehl, '', SW_HIDE, ewWaitUntilTerminated, Rc) or (Rc <> 0) then
      SuppressibleMsgBox(FmtMessage(CustomMessage('AufraeumFehler'), [IntToStr(Rc), ExpandConstant('{commonappdata}\OrcaShield\Logs')]), mbError, MB_OK, IDOK);
  end;
end;
