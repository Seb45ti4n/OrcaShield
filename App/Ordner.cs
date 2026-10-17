using System;
using System.IO;
using System.Security.AccessControl;
using System.Security.Principal;

namespace OrcaShield
{
    internal static class Ordner
    {
        private static readonly SecurityIdentifier Admins = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);
        private static readonly SecurityIdentifier SystemKonto = new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null);
        private static readonly SecurityIdentifier Benutzer = new SecurityIdentifier(WellKnownSidType.BuiltinUsersSid, null);
        private static string _basis;
        private static readonly object Sperre = new object();

        public static bool Testprofil { get; set; }

        /// <summary>Wurzel für alles, was die EXE schreibt. Installiert: geschützt und geprüft.</summary>
        public static string Basis()
        {
            lock (Sperre)
            {
                if (_basis != null) return _basis;
                if (!Programm.IstInstalliert())
                {
                    _basis = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), Testprofil ? "OrcaShield-Test" : "OrcaShield");
                    Directory.CreateDirectory(_basis);
                    return _basis;
                }
                string daten = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "OrcaShield");
                // Eine vorab angelegte Verzeichnisverknüpfung (ProgramData lässt jedes Konto Ordner
                // anlegen) wird entfernt – nur die Verknüpfung, nie ihr Ziel.
                if (Directory.Exists(daten) && IstVerknuepfung(daten)) Directory.Delete(daten, false);
                if (Directory.Exists(daten) && !Sicher(daten))
                    Directory.Move(daten, daten + ".unsicher-" + DateTime.Now.ToString("yyyyMMdd-HHmmss"));
                if (!Directory.Exists(daten)) Directory.CreateDirectory(daten, OrcaRechte());
                if (!Sicher(daten)) throw new UnauthorizedAccessException("Der Datenordner von OrcaShield lässt sich nicht schützen: " + daten);
                return _basis = daten;
            }
        }

        /// <summary>Unterordner der Basis. Installiert: ist er keine echte, geschützte Ordner (sondern
        /// etwa eine Verzeichnisverknüpfung oder mit fremden Rechten), wird er verworfen und neu angelegt –
        /// nur für Ordner, deren Inhalt entbehrlich ist (Protokolle, Zwischenspeicher).</summary>
        public static string Unterordner(string name, bool entbehrlich)
        {
            string o = Path.Combine(Basis(), name);
            if (!Programm.IstInstalliert()) { Directory.CreateDirectory(o); return o; }
            if (Directory.Exists(o) && (IstVerknuepfung(o) || !Sicher(o)))
            {
                if (IstVerknuepfung(o)) Directory.Delete(o, false);          // nur die Verknüpfung, nie ihr Ziel
                else if (entbehrlich) Directory.Delete(o, true);
                else Directory.SetAccessControl(o, OrcaRechte());
            }
            if (!Directory.Exists(o)) Directory.CreateDirectory(o, OrcaRechte());
            if (IstVerknuepfung(o) || !Sicher(o)) throw new UnauthorizedAccessException("Ordner lässt sich nicht schützen: " + o);
            return o;
        }

        private static bool IstVerknuepfung(string pfad)
        {
            try { return (File.GetAttributes(pfad) & FileAttributes.ReparsePoint) != 0; } catch { return true; }
        }

        // Administratoren und SYSTEM Vollzugriff, Benutzer lesen; nichts geerbt; Besitzer Administratoren
        internal static DirectorySecurity OrcaRechte()
        {
            var r = new DirectorySecurity();
            r.SetAccessRuleProtection(true, false);
            var erben = InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit;
            var wer = new[] { Admins, SystemKonto, Benutzer };
            var recht = new[] { FileSystemRights.FullControl, FileSystemRights.FullControl, FileSystemRights.ReadAndExecute };
            for (int i = 0; i < wer.Length; i++)
                r.AddAccessRule(new FileSystemAccessRule(wer[i], recht[i], erben, PropagationFlags.None, AccessControlType.Allow));
            r.SetOwner(Admins);
            return r;
        }

        // Sicher = Besitzer Administratoren oder SYSTEM, und niemand sonst darf schreiben, löschen oder Rechte ändern.
        internal static bool Sicher(string ordner)
        {
            const FileSystemRights schreiben = FileSystemRights.WriteData | FileSystemRights.AppendData |
                FileSystemRights.WriteExtendedAttributes | FileSystemRights.WriteAttributes | FileSystemRights.Delete |
                FileSystemRights.DeleteSubdirectoriesAndFiles | FileSystemRights.ChangePermissions | FileSystemRights.TakeOwnership;
            try
            {
                var acl = Directory.GetAccessControl(ordner);
                var besitzer = acl.GetOwner(typeof(SecurityIdentifier));
                if (!Admins.Equals(besitzer) && !SystemKonto.Equals(besitzer)) return false;
                foreach (FileSystemAccessRule r in acl.GetAccessRules(true, true, typeof(SecurityIdentifier)))
                    if (r.AccessControlType == AccessControlType.Allow && (r.FileSystemRights & schreiben) != 0
                        && !Admins.Equals(r.IdentityReference) && !SystemKonto.Equals(r.IdentityReference)) return false;
                return true;
            }
            catch { return false; }
        }
    }
}
