# OrcaShield

**Datenschutz-Härtung für Windows 11 – gemessen, nachgeprüft, umkehrbar.**

[English](README.md) · Version **1.1.2 Public Beta** · Windows 11 (x64 und ARM64) · MIT-Lizenz

OrcaShield schaltet ab, was Windows über dich sendet, hält es abgeschaltet, beseitigt beim Herunterfahren Spuren und schützt vor der Microsoft-Gerätekennung – nach einer Regel über allem: **erst messen, dann handeln, dann nachprüfen.** Nichts wird ohne deine Bestätigung geändert – schaltest du den Wächter oder die Bereinigung ein, handeln sie danach bei jeder Anmeldung bzw. jedem Herunterfahren selbst. Jede Änderung lässt sich zurücknehmen, und OrcaShield selbst sendet nichts.

> **Das ist eine Beta.** Probiere sie bitte auf einem Rechner aus, auf dem du mit einem Problem leben kannst, lies die Warnungen in der App und melde Auffälligkeiten über die Issues dieses Projekts.

---

## Funktionen

### Katalog – 521 Einstellungen
Telemetrie, Werbe-ID, Copilot und Recall, Standort, Websuche im Startmenü, Sprach- und Tippdaten, Geräteinventur, Office-Cloudanbindung, Kontosynchronisierung, Cloud-Zwischenablage, Fehlerberichte, Aktivitätsverlauf, App-Berechtigungen, Netzwerk- und TLS-Härtung, Verhalten von Windows Update, Defender-Optionen und mehr.

- **Jeder Wert ist belegt:** Richtlinien an den Richtliniendefinitionen von Windows (ADMX: Benutzer oder Computer, unterstützte Versionen, Editionen, ob ein Schalter in den Einstellungen gesperrt wird), alle anderen Werte an der Programmdatei von Windows, die sie liest. Was sich nicht belegen lässt, steht nicht im Katalog, sondern unter **„Nicht unterstützt“** mit Begründung (147 bekannte Optionen).
- **Drei Schutzstufen**, aufeinander aufbauend, je Bereich oder für alles:
  - **Basis** (39 Einstellungen, grün) – das Wichtigste, ohne Nebenwirkungen.
  - **Erweitert** (237, gelb) – alles ohne spürbare Nachteile. Empfohlen.
  - **Maximal** (328, rot) – höchster Datenschutz, auch mit spürbarer Folge.
- **Zusatz** (186 Einstellungen, in keiner Stufe): Punkte, die Programme abschneiden, einen Schalter für alle Konten sperren oder **den Schutz senken** (etwa automatische Updates, SmartScreen, Teile von Defender oder die virtualisierungsbasierte Sicherheit aus). Nur einzeln einschaltbar, Vorgabe Nein; Sicherheitsrisiken rot mit ⚠ und Pflichtwarnung.
- **Experimentell** (7 Einstellungen): Leistungswerte, die Windows nachweislich liest, jeweils mit gemessenem Wert vorher und nachher.
- Zusammen: 521 = 328 in den Stufen + 186 Zusatz + 7 Experimentell. Die 147 Optionen unter „Nicht unterstützt“ zählen nicht dazu – OrcaShield setzt sie nicht.
- Zu jeder Einstellung: Erklärung in Alltagssprache, technische Angaben (Pfad, Wert, Soll/Ist) und der **PowerShell-Befehl**, mit dem du sie selbst setzt oder zurücknimmst.

### Vorschau und doppelte Bestätigung
Nichts wird gesetzt, bevor du die Vorschau („Prüfen & anwenden“) bestätigt hast. Danach nennt ein eigenes Fenster des Programms jede einzelne Änderung und fragt noch einmal – Sicherheitsrisiken gesondert, Vorgabe Nein.

### Ausgangszustand, Sicherungspunkte, Rückbau
- Vor der ersten Änderung misst und sichert OrcaShield den **Ausgangszustand** jeder Einstellung und eine Kopie der betroffenen Registry-Zweige. Jeder Rückbau führt auf diesen gemessenen Stand zurück – nicht auf einen angenommenen Windows-Standardwert.
- **Sicherungspunkte** und **Profile** (Export/Import) liegen als Dateien im geschützten Datenordner. Vor jedem Anwenden entsteht automatisch ein Sicherungspunkt; höchstens 30 bleiben (der älteste fällt weg), der Ausgangszustand zählt nicht dazu und ist nie löschbar. Sicherungspunkte lassen sich umbenennen.
- Einzelne Einstellungen, alles auf einmal oder – beim Deinstallieren – auf Wunsch alles automatisch zurücksetzen.

### Wächter (optional, anfangs aus)
Läuft nach jeder Anmeldung, sichtbar, mit Administratorrechten, und prüft:
- ob alle aktiven Einstellungen noch stehen – Funktionsupdates stellen gern zurück; Abweichungen werden zurückgestellt und protokolliert,
- entfernte Apps, die zurückgekommen sind – sie werden erneut entfernt, Microsoft Edge auch, wenn du Edge entfernt hast,
- **Defender und Firewall**: Echtzeitschutz, Manipulationsschutz, **neue Ausnahmen** (der häufigste Trick von Schadsoftware), weitere Virenschutzprogramme, Richtlinien gegen Defender, veraltete Signaturen, neue Funde,
- ob die Bereinigung beim Herunterfahren wirklich gelaufen ist (gegen das Ereignisprotokoll),
- die eigene Aufgabe und die Schreibrechte seiner Ordner,
- **was seit dem letzten Lauf neu ist**: Autostart-Einträge, fremde Richtlinien, Stammzertifikate, Proxy, eingehende Firewallregeln, Aufgaben und Dienste mit Namen bekannter Datensammler. Geändert wird dabei nichts – Neues wird gemeldet, bis du es in der App aufnimmst.

Das Fenster ist grün und schließt nach wenigen Sekunden, wenn alles sauber ist, gelb bei Hinweisen, rot bei Alarm (bleibt offen).

Der Wächter arbeitet für das Konto, mit dem OrcaShield eingerichtet wurde. Einstellungen anderer Konten auf demselben Rechner hält er nicht; die Bereinigung beim Herunterfahren läuft dagegen für alle Profile.

### Bereinigung beim Herunterfahren (optional, anfangs aus)
Beseitigt bei jedem Herunterfahren und Neustart Spuren: Papierkorb, Miniaturansichten, Diagnoseprotokolle, temporäre Dateien, Absturzabbilder, Prefetch, zuletzt verwendete Dateien, Explorer-Verläufe und ShellBags; die Auslagerungsdatei wird beim Herunterfahren geleert. Nach der nächsten Anmeldung folgt auf C: ein TRIM-Durchlauf: Die SSD erfährt, welche Bereiche frei sind – wann sie die Daten dort tatsächlich löscht, entscheidet das Laufwerk.

Jeder Schritt lässt sich unter „Überwachung & Automatik“ einzeln ein- und ausschalten; zu jedem steht, was er löscht und was du davon merkst. Schattenkopien (ältere Fassungen von Dateien, Wiederherstellungspunkte) werden nur mit ihrem eigenen Schalter gelöscht, Vorgabe aus.

> ⚠ Das **löscht endgültig**: Bei jedem Herunterfahren wird der Papierkorb geleert, mit dem eigenen Schalter auch die Schattenkopien. Nur einschalten, wenn du das willst.

Eingetragen genau so, wie es der Gruppenrichtlinien-Editor tut; Einträge anderer Werkzeuge bleiben unangetastet. Wer sie ausschaltet, schaltet auch das Leeren der Auslagerungsdatei wieder aus.

### Apps
Entfernt vorinstallierte Apps, die du nicht brauchst (42 Apps im Katalog), samt Rückständen. Eine Schutzliste (Startmenü, Store, Shell, App-Installer, Laufzeiten, Windows-Sicherheit) wird nie angefasst. Microsoft Edge nur mit eigener doppelter Bestätigung; WebView2, das viele Programme brauchen, bleibt.
- Von OrcaShield entfernte Apps lassen sich mit einem Klick wieder installieren – aus Windows neu registriert, solange die Dateien noch da sind, sonst über ihre Seite im Microsoft Store (das ist eine Verbindung zu Microsoft, nur auf deinen Klick).
- Zeigt alle übrigen Store- und System-Apps des Rechners (nur zur Ansicht) und einige empfohlene kostenlose Programme (Link zur Website des Herausgebers).

### Schutz vor der Gerätekennung
Windows bekommt von Microsoft eine Gerätekennung (GDID), die bei jeder Kontoanfrage mitgeschickt wird – ein VPN hilft dagegen nicht.
- Sperrt die neun Adressen, über die sie ausgestellt und abgeglichen wird (Hosts-Datei); die Anmeldung mit dem Microsoft-Konto bleibt möglich.
- Optional zusätzlich die Kontoanmeldung selbst – erst dann kommt sicher keine neue Kennung (Store, Xbox, OneDrive und Office-Anmeldung gehen dann nicht mehr, Vorgabe Nein).
- Eine Firewallregel nimmt dem Dienst der Kontoanmeldung den Netzzugang.
- Entfernt eine schon gespeicherte Kennung auf Knopfdruck – je Ort (dein Profil, Vorlageprofil, Systemkonto), wahlweise mit Token-Zwischenspeicher und gespeicherten Microsoft-Zugangsdaten (Letzteres heißt neu anmelden, deshalb nur auf Knopfdruck).

### Hosts-Datei und DNS
- OrcaShield verwaltet **nur seinen eigenen markierten Block** in der Hosts-Datei. Alles außerhalb gehört dir. Vor jedem Schreiben wird die ganze Datei gesichert; fehlt danach auch nur eine deiner Zeilen, wird die Sicherung zurückgelegt.
- Rund 100 Adressen für Werbung und Telemetrie von Microsoft als zweite Sicherung.
- Jeder einzelne Eintrag lässt sich auf der Seite „Hosts“ ausnehmen – etwa um OneDrive oder Office zu erlauben. Der Wächter hält genau diese Liste.
- Verschlüsseltes DNS: Quad9 mit DNS-over-HTTPS ohne Rückfall auf unverschlüsseltes DNS.

### Richtlinien und ausgegraute Schalter
OrcaShield zeigt, welche Einstellungen einen Schalter in den Windows-Einstellungen sperren und warum, nennt eine Alternative ohne Sperre, wo es eine gibt, und findet **Richtlinien anderer Programme** – erklärt sie und entfernt sie auf Wunsch (mit Sicherung und Rückfrage).

### Sprachen
Deutsch und Englisch (unter „Anpassen“). Das Setup folgt der Sprache von Windows. Protokolle bleiben deutsch.

---

## Installation

1. `OrcaShield-Setup-1.1.2-Public-Beta.exe` unter **Releases** dieses Projekts herunterladen. Eine Datei für normale PCs (x64) und ARM-Geräte – das Setup wählt selbst.
2. Empfohlen: Prüfsumme mit der im Release angegebenen vergleichen:
   ```powershell
   Get-FileHash .\OrcaShield-Setup-1.1.2-Public-Beta.exe -Algorithm SHA256
   ```
3. Setup starten, die Benutzerkontensteuerung mit Ja bestätigen.
4. OrcaShield über das Startmenü starten. Beim Start misst es den Zustand des Rechners (Bestandsaufnahme) und ändert **nichts**.

**Voraussetzungen:** Windows 11, .NET Framework 4.8.1 und die WebView2-Laufzeit – alle drei sind in Windows 11 enthalten. Fehlt etwas, sagt das Setup es und installiert nichts. Administratorrechte sind nötig.

**Wohin:** Programm nach `C:\Program Files\OrcaShield`, Daten (Ausgangszustand, Sicherungen, Protokolle, Sicherungspunkte) nach `C:\ProgramData\OrcaShield`. Beide Ordner sind vor Änderungen ohne Administratorrechte geschützt – sonst könnte jedes Programm unter deinem Konto die Skripte umschreiben, die der Wächter mit Administratorrechten ausführt.

Wächter und Bereinigung sind **aus**, bis du sie unter „Überwachung & Automatik“ einschaltest. Einige Einstellungen wirken erst nach einem Neustart; die App sagt das bei jeder und startet nie selbst neu.

---

## Warnungen von SmartScreen und Virenschutz

**SmartScreen:** Das Setup ist nicht mit einem gekauften Zertifikat signiert. Windows zeigt deshalb beim ersten Start „Der Computer wurde durch Windows geschützt“. Das heißt nur: Microsoft kennt die Datei noch nicht – nicht, dass sie schädlich ist. Zum Starten: „Weitere Informationen“, dann „Trotzdem ausführen“. Wer sichergehen will, vergleicht vorher die Prüfsumme – oder baut das Setup selbst aus dem Quelltext.

**Fehlalarme:** OrcaShield ändert Datenschutz-Einstellungen, Dienste und geplante Aufgaben – genau das, was auch Schadsoftware tut. Manche Virenschutzprogramme melden es deshalb. Microsoft Defender hat es in unseren Tests nicht gemeldet. Meldet dein Virenschutz etwas, schick die Datei dem Hersteller zur Prüfung, statt den Schutz abzuschalten.

**Nicht als lose Kopie vom Desktop oder aus dem Download-Ordner betreiben** – mit dem Setup installieren. OrcaShield schreibt Dateien (Sicherungen, Protokolle, Zustand) und braucht seine geschützten Ordner.

---

## Deinstallieren

Einstellungen → Apps → Installierte Apps → OrcaShield. Die Deinstallation fragt,

1. ob vorher alle Einstellungen, die OrcaShield gesetzt hat, auf den Zustand vor der ersten Änderung zurückgesetzt werden sollen, und
2. ob seine Daten (Zustand, Ausgangszustand, Sicherungen, Protokolle) gelöscht werden sollen.

Vorgabe beide Male Nein. Wächter und Bereinigung werden in jedem Fall ausgetragen.

Still: `unins000.exe /VERYSILENT [/RUECKBAU=ja] [/DATENLOESCHEN=ja]`.

Entfernte Apps kommen durch den Rückbau nicht zurück.

---

## Was OrcaShield nicht macht

- Es schaltet nie von sich aus Microsoft Defender, SmartScreen, den Cloud-Schutz oder Sicherheitsupdates ab. Wer das will, findet die Punkte unter „Zusatz“ – jeder einzeln, rot als Sicherheitsrisiko, Vorgabe Nein. Sie gehören zu keiner Schutzstufe.
- Die Schutzstufen setzen keine Richtlinie, die Updates verzögert oder abschaltet.
- Es installiert keine Programme und führt keine fremden Skripte aus.
- Es ändert deine Hosts-Datei nur im eigenen, markierten Block.
- Es entfernt kein OneDrive, sondern schaltet nur dessen Telemetrie und Autostart ab.
- Es überschreibt keine fremden Einträge in der Skript-Konfiguration der lokalen Gruppenrichtlinie.
- Es nutzt keine Windows-Wiederherstellungspunkte – es hat eigenen Ausgangszustand, eigene Sicherungspunkte und eigenen Rückbau.

**Grenzen, ehrlich:** Schadsoftware mit Administratorrechten kann auch OrcaShield abschalten. Die Defender-Wache meldet, sie verhindert nicht. Und ein VPN verschlüsselt den Verkehr und verbirgt deine IP-Adresse – gegen Cookies, Browser-Fingerprinting, angemeldete Konten und Gerätekennungen hilft es nicht.

---

## Datenschutz von OrcaShield selbst

- **Keine Telemetrie, kein Konto, keine Updateprüfung, keine Verbindung ins Internet.** Die Oberfläche ist eine lokale Seite in einem WebView2-Fenster; sie lädt nichts aus dem Netz, und die Funktionen von WebView2, die Microsoft kontaktieren würden, sind abgeschaltet.
- Alles, was OrcaShield misst und schreibt, bleibt auf deinem Rechner, im geschützten Datenordner.
- Der einzige Link nach außen (die Projektseite auf der Seite „Über“) öffnet sich in deinem normalen Browser, nur wenn du klickst.
- Nachprüfbar: `Werkzeuge\Netz-Pruefung.ps1` im Quelltext beobachtet die Netzverbindungen des laufenden Programms.

---

## Aus dem Quelltext bauen

Voraussetzungen: Windows 11, .NET SDK 8 (baut das Programm für .NET Framework 4.8.1), Inno Setup 6.

```powershell
winget install --id Microsoft.DotNet.SDK.8 -e
winget install --id JRSoftware.InnoSetup -e
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Werkzeuge\Setup-Bauen.ps1
```

Das Skript baut beide Fassungen von `OrcaShield.exe` (x64 und ARM64) und danach `Installer\Ausgabe\OrcaShield-Setup-<Version>.exe`.

| Ordner | Inhalt |
|---|---|
| `App\` | das Programm (C#, WinForms + WebView2), Brücke zur Engine |
| `Skripte\` | die Engine in Windows PowerShell 5.1: Katalog (`Orca-Settings.ps1`), Messen/Setzen/Nachprüfen (`Orca-Engine.ps1`), Wächter, Bereinigung, Apps, Aufräumen bei der Deinstallation |
| `Werkzeuge\Gui\` | die Oberfläche (`OrcaShield.html`) und ihre englischen Texte |
| `Installer\` | das Inno-Setup-Skript |
| `Werkzeuge\` | Bauskripte und die Netzprüfung |

---

## Lizenz

MIT – siehe [LICENSE.txt](LICENSE.txt). Jeder darf OrcaShield nutzen, verändern und weitergeben. Es kommt **ohne jede Gewähr**: Die Nutzung erfolgt auf eigenes Risiko.

Gemacht von **Seba5ti4n**.
