# OrcaShield

**Privacy hardening for Windows 11 – measured, verified, reversible.**

[Deutsch](README.de.md) · Version **1.0.0 Public Beta** · Windows 11 (x64 and ARM64) · MIT License

OrcaShield turns off what Windows sends about you, keeps it turned off, cleans up traces at shutdown and protects you from the Microsoft device ID – with one rule above everything else: **measure first, then act, then verify.** Nothing is changed without your confirmation, every change can be undone, and OrcaShield itself sends nothing anywhere.

> **This is a beta.** Please try it on a PC where you can live with a problem, read the warnings in the app, and report anything odd via the GitHub issues of this project.

---

## Contents

- [Features](#features)
- [How OrcaShield works](#how-orcashield-works)
- [Installation](#installation)
- [SmartScreen and antivirus warnings](#smartscreen-and-antivirus-warnings)
- [Uninstalling](#uninstalling)
- [What OrcaShield does not do](#what-orcashield-does-not-do)
- [Privacy of OrcaShield itself](#privacy-of-orcashield-itself)
- [Building from source](#building-from-source)
- [License](#license)

---

## Features

### Settings catalog – 522 settings
Telemetry, advertising ID, Copilot and Recall, location, web search in the Start menu, speech and typing data, device inventory, Office cloud connections, account sync, cloud clipboard, error reporting, activity history, app permissions, network and TLS hardening, Windows Update behaviour, Defender options and more.

- **Every value is documented**: policies against the Windows policy definitions (ADMX: user or machine scope, supported versions, editions, whether a switch in Settings gets locked), all other values against the Windows program file that reads them. What cannot be documented is not in the catalog – it is listed under **"Not supported"** with the reason (145 known options).
- **Three protection levels**, cumulative, per area or for everything at once:
  - **Basic** (39 settings, green) – the essentials, no side effects.
  - **Extended** (237, yellow) – everything without noticeable drawbacks. Recommended.
  - **Maximum** (336, red) – highest privacy, including settings with noticeable consequences.
- **Extra** (178 settings, in no level): settings that cut off programs, lock a switch for all accounts or **lower your protection** (for example turning off automatic updates, SmartScreen or parts of Defender). They can only be switched on one by one, default No; security risks are marked red with ⚠ and a mandatory warning.
- **Experimental** (8 settings): performance values Windows demonstrably reads, each with the measured value before and after.
- For every setting: an explanation in plain language, the technical details (path, value, target/current state) and the **PowerShell command** to set or revert it yourself.

### Preview and double confirmation
Nothing is applied before you have checked the preview ("Review & apply"). Afterwards a separate window of the program names every single change and asks again – security risks separately, default No.

### Baseline, restore points, rollback
- Before the first change OrcaShield measures and saves the **original state** of every setting and backs up the affected registry branches. Every rollback returns to this measured state – not to an assumed Windows default.
- **Restore points** and **profiles** (export/import) are stored as files in the protected data folder.
- Reset single settings, everything at once, or – when uninstalling – optionally everything automatically.

### Watcher (optional, off by default)
Runs after every sign-in, visible, with administrator rights, and checks:
- that all active settings are still in place – Windows feature updates like to reset things; deviations are restored and logged,
- removed apps that came back,
- **Defender and firewall**: real-time protection, tamper protection, **new exclusions** (the most common trick of malware), other antivirus products registering, policies disabling Defender, outdated signatures, new detections,
- whether the shutdown cleanup actually ran (checked against the Windows event log),
- its own scheduled task and the write permissions of its folders,
- **what is new since the last run**: autostart entries, policies not set by OrcaShield, root certificates, proxy settings, inbound firewall rules, tasks and services with names of known data collectors. Nothing is changed – new items are reported until you accept them in the app.

The window is green and closes after a few seconds when everything is clean, yellow for notes, red for alarms (stays open).

### Cleanup at shutdown (optional, off by default)
Removes traces at every shutdown and restart: recycle bin, volume shadow copies, thumbnail cache, diagnostic logs, temporary files, crash dumps, prefetch files, recently used files, Explorer history and ShellBags; clears the page file at shutdown. After the next sign-in a TRIM pass follows so the SSD really discards the deleted data.

> ⚠ This **permanently deletes** data: the recycle bin is emptied and shadow copies (older versions of files) are removed at every shutdown. Only switch it on if that is what you want.

Registered exactly like a script set via the Group Policy editor; existing entries of other tools stay untouched. Switching it off also turns the page file clearing off again.

### Apps
Removes preinstalled apps you do not need (37 apps in the catalog) and their leftovers. A protection list (Start menu, Store, shell, App Installer, runtimes, Windows Security) is never touched. Microsoft Edge only with a separate double confirmation; WebView2, which many programs need, stays.

### Device ID protection
Windows receives a device ID (GDID) from Microsoft that is sent with every account request – a VPN does not help against it.
- Blocks the nine addresses through which it is issued and synced (hosts file), with Microsoft account sign-in still working.
- Optional: also block the account sign-in itself – only then is it certain that no new ID arrives (breaks Store, Xbox, OneDrive and Office sign-in, default No).
- A firewall rule takes network access away from the account sign-in service.
- Removes an already stored device ID on demand (deletes stored Microsoft credentials – therefore only on button press).

### Hosts file and DNS
- OrcaShield manages **only its own marked block** in the hosts file. Everything outside belongs to you. Before every write the whole file is backed up; if even one of your lines is missing afterwards, the backup is restored.
- About 100 Microsoft advertising and telemetry addresses as an additional safety net.
- Encrypted DNS: Quad9 with DNS over HTTPS without fallback to unencrypted DNS.

### Policies and greyed-out switches
OrcaShield shows which settings lock a switch in the Windows Settings app and why, offers a non-locking alternative where one exists, and finds **policies set by other programs** – it explains them and removes them on request (with backup and confirmation).

### Languages
German and English (under "Customize"). The setup follows the Windows language. Logs stay German.

---

## How OrcaShield works

**Measure, then act – and ask Windows.**

- **Before**: Does this registry key exist? Is the value already correct? Which data type? Does the service, the task, the Windows feature exist at all? Does this policy work on your Windows edition? Settings that would have no effect on your system are not offered.
- **After**: every write is read back. Success is only reported when the value is really there, with the correct data type.
- **Ask Windows**: where Windows itself says what is effective, that counts – not what OrcaShield wrote. For Defender via its status interface, for virtualization-based security via Device Guard, for the shutdown script via policy processing and its execution time.

A hardening tool never loosens anything on its own.

---

## Installation

1. Download `OrcaShield-Setup-1.0.0-Public-Beta.exe` from the **Releases** of this project. One file for normal PCs (x64) and ARM devices – the setup chooses.
2. Optional, recommended: compare the checksum with the one published in the release:
   ```powershell
   Get-FileHash .\OrcaShield-Setup-1.0.0-Public-Beta.exe -Algorithm SHA256
   ```
3. Start the setup and confirm the User Account Control prompt.
4. Start OrcaShield from the Start menu. On start it measures the state of the PC (inventory) and changes **nothing**.

**Requirements:** Windows 11, .NET Framework 4.8.1 and the WebView2 Runtime – all three are part of Windows 11. If something is missing, the setup says so and installs nothing. Administrator rights are required.

**Where things go:** the program to `C:\Program Files\OrcaShield`, its data (original state, backups, logs, restore points) to `C:\ProgramData\OrcaShield`. Both folders are protected against changes without administrator rights – otherwise any program running under your account could rewrite the scripts the watcher runs with administrator rights.

The watcher and the shutdown cleanup are **off** until you switch them on under "Monitoring & automation". Some settings only take effect after a restart; the app says so for each of them and never restarts on its own.

---

## SmartScreen and antivirus warnings

**SmartScreen:** The setup is not signed with a purchased certificate. Windows therefore shows "Windows protected your PC" on first start. That only means Microsoft does not know the file yet – not that it is harmful. To start: "More info", then "Run anyway". If you want to be sure, compare the SHA-256 checksum first (see above) – or build the setup yourself from the source.

**Antivirus false positives:** OrcaShield changes privacy settings, services and scheduled tasks – exactly what malware does too. Some antivirus programs may therefore report it. Microsoft Defender did not flag it in our tests. If your antivirus reports something, send the file to its vendor for analysis instead of turning your protection off.

**Do not run it from the desktop or a download folder as a portable copy** – install it with the setup. OrcaShield writes files (backups, logs, state) and needs its protected folders.

---

## Uninstalling

Settings → Apps → Installed apps → OrcaShield. The uninstaller asks

1. whether all settings OrcaShield made should first be reset to the state before the first change, and
2. whether its data (state, original state, backups, logs) should be deleted.

Default is No for both. The watcher and the shutdown cleanup are removed in any case.

Silent: `unins000.exe /VERYSILENT [/RUECKBAU=ja] [/DATENLOESCHEN=ja]` (reset / delete data).

Removed apps do not come back through the reset.

---

## What OrcaShield does not do

- It never turns off Microsoft Defender, SmartScreen, cloud protection or security updates on its own. Whoever wants that finds the settings under "Extra" – each one individually, marked red as a security risk, default No. They belong to no protection level.
- The protection levels set no policy that delays or disables updates.
- It installs no programs and runs no third-party scripts.
- It changes your hosts file only in its own marked block.
- It does not remove OneDrive, it only turns off its telemetry and autostart.
- It does not overwrite foreign entries in the local Group Policy script configuration.
- It does not use Windows restore points – it keeps its own original state, restore points and rollback.

**Limits, honestly:** Malware with administrator rights can also turn OrcaShield off. The Defender watch reports, it does not prevent. And a VPN encrypts traffic and hides your IP address – it does not protect against cookies, browser fingerprinting, signed-in accounts or device IDs.

---

## Privacy of OrcaShield itself

- **No telemetry, no account, no update check, no internet connection.** The interface is a local page in a WebView2 window; it loads nothing from the network, and the WebView2 functions that would contact Microsoft are switched off.
- Everything OrcaShield measures and writes stays on your PC, in its protected data folder.
- The only link to the outside (the project page on the "About" page) opens in your normal browser, only when you click it.
- Verifiable: `Werkzeuge\Netz-Pruefung.ps1` in the source watches the network connections of the running program.

---

## Building from source

The source code, comments and identifiers are mostly German.

Requirements: Windows 11, .NET SDK 8 (builds the .NET Framework 4.8.1 program), Inno Setup 6.

```powershell
winget install --id Microsoft.DotNet.SDK.8 -e
winget install --id JRSoftware.InnoSetup -e
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Werkzeuge\Setup-Bauen.ps1
```

The script builds both variants of `OrcaShield.exe` (x64 and ARM64) and then `Installer\Ausgabe\OrcaShield-Setup-<version>.exe`.

Layout:

| Folder | Content |
|---|---|
| `App\` | the program (C#, WinForms + WebView2), bridge to the engine |
| `Skripte\` | the engine in Windows PowerShell 5.1: catalog (`Orca-Settings.ps1`), measure/set/verify (`Orca-Engine.ps1`), watcher, shutdown cleanup, apps, uninstall cleanup |
| `Werkzeuge\Gui\` | the interface (`OrcaShield.html`) and its English texts |
| `Installer\` | the Inno Setup script |
| `Werkzeuge\` | build scripts and the network check |

---

## License

MIT – see [LICENSE.txt](LICENSE.txt). Everyone may use, change and pass on OrcaShield. It comes **without any warranty**: you use it at your own risk.

Made by **Seba5ti4n**.
