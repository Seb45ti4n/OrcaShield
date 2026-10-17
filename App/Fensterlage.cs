// ==============================================================
//  OrcaShield – Fensterlage.cs
//  Merkt sich Größe und Lage des Fensters je Benutzer
//  (%LOCALAPPDATA%\OrcaShield\fenster.txt). Liegt das gemerkte Fenster
//  nicht mehr auf einem Bildschirm (anderer Monitor), wird es mittig
//  auf dem Hauptbildschirm geöffnet.
// ==============================================================
using System;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Windows.Forms;

namespace OrcaShield
{
    internal static class Fensterlage
    {
        private const string Datei = "fenster.txt";

        public static void Wiederherstellen(Form f, string ordner)
        {
            var bereich = Screen.PrimaryScreen.WorkingArea;
            var vorgabe = new Size(Math.Min(1500, bereich.Width - 80), Math.Min(940, bereich.Height - 80));
            f.Size = vorgabe;
            f.Location = new Point(bereich.Left + (bereich.Width - vorgabe.Width) / 2,
                                   bereich.Top + (bereich.Height - vorgabe.Height) / 2);
            try
            {
                string pfad = Path.Combine(ordner, Datei);
                if (!File.Exists(pfad)) return;
                var t = File.ReadAllText(pfad).Trim().Split(';');
                if (t.Length < 5) return;
                var r = new Rectangle(Zahl(t[0]), Zahl(t[1]), Zahl(t[2]), Zahl(t[3]));
                bool sichtbar = false;
                foreach (var s in Screen.AllScreens) if (s.WorkingArea.IntersectsWith(r)) sichtbar = true;
                if (!sichtbar || r.Width < f.MinimumSize.Width || r.Height < f.MinimumSize.Height) return;
                f.Bounds = r;
                if (t[4] == "max") f.WindowState = FormWindowState.Maximized;
            }
            catch { }
        }

        public static void Merken(Form f, string ordner)
        {
            try
            {
                Directory.CreateDirectory(ordner);
                var r = f.WindowState == FormWindowState.Normal ? f.Bounds : f.RestoreBounds;
                string zustand = f.WindowState == FormWindowState.Maximized ? "max" : "normal";
                File.WriteAllText(Path.Combine(ordner, Datei),
                    string.Join(";", r.X, r.Y, r.Width, r.Height, zustand));
            }
            catch { }
        }

        private static int Zahl(string s) => int.Parse(s, CultureInfo.InvariantCulture);
    }
}
