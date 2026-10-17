using System;
using System.Collections.Generic;
using System.Reflection;
using System.Runtime.InteropServices;
using Microsoft.Win32;

namespace OrcaShield
{
    internal static class Voraussetzungen
    {
        // .NET Framework 4.8.1: Release-Schlüssel ab 533320 (Microsoft-Dokumentation „How to: Determine which .NET Framework versions are installed“)
        private const int NetzRelease481 = 533320;
        // Windows 11: Build ab 22000
        private const int Windows11Build = 22000;

        /// <summary>Unverzichtbares, das fehlt – leer, wenn alles da ist.</summary>
        public static List<string> Fehlt()
        {
            var fehlt = new List<string>();
            int release = 0;
            try
            {
                using (var k = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry64)
                                          .OpenSubKey(@"SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"))
                    release = k?.GetValue("Release") is int r ? r : 0;
            }
            catch { }
            if (release < NetzRelease481)
                fehlt.Add(".NET Framework 4.8.1 (gefunden: " + (release > 0 ? "Release " + release : "nichts") + ")");

            // Windows PowerShell 5.1 – die Engine läuft darin. Fehlt sie (Windows-Funktion
            // abgeschaltet), lässt sich die Bibliothek nicht laden.
            try
            {
                var a = Assembly.Load("System.Management.Automation, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35");
                if (a.GetType("System.Management.Automation.PowerShell") == null) fehlt.Add("Windows PowerShell 5.1");
            }
            catch { fehlt.Add("Windows PowerShell 5.1"); }
            return fehlt;
        }

        /// <summary>Windows-Build aus der Registry (Environment.OSVersion kann je nach Manifest abweichen).</summary>
        public static int WindowsBuild()
        {
            try
            {
                using (var k = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion"))
                    return int.TryParse(k?.GetValue("CurrentBuildNumber") as string, out var b) ? b : 0;
            }
            catch { return 0; }
        }

        public static bool IstWindows11() => WindowsBuild() >= Windows11Build;

        /// <summary>Läuft die EXE in der Emulation (x64-Bau auf einem ARM64-Rechner)? Nur zur Auskunft im Protokoll.</summary>
        public static string Architektur() =>
            RuntimeInformation.ProcessArchitecture + " auf " + RuntimeInformation.OSArchitecture +
            (RuntimeInformation.ProcessArchitecture != RuntimeInformation.OSArchitecture ? " (emuliert)" : "");
    }
}
