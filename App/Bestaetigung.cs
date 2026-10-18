using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Windows.Forms;

namespace OrcaShield
{
    internal static class Bestaetigung
    {
        private const int HoechstensZeilen = 15;

        /// <summary>Fragt im eigenen Fenster nach. true = bestätigt.
        /// Mit Punkten unter „risiken“ (Sicherheitsrisiko, nicht umkehrbar): Warnsymbol, Vorgabeknopf „Nein“.</summary>
        public static bool Fragen(Control ui, bool simulation, string kopf, IList<string> zeilen, IList<string> risiken, bool englisch = false)
        {
            if (ui.IsDisposed) return false;
            if (ui.InvokeRequired)
                return (bool)ui.Invoke(new Func<bool>(() => Fragen(ui, simulation, kopf, zeilen, risiken, englisch)));

            string weitere(int n) => englisch ? "…  and " + n + " more" : "…  und " + n + " weitere";
            var sb = new StringBuilder();
            sb.AppendLine(kopf);
            sb.AppendLine();
            foreach (var z in zeilen.Take(HoechstensZeilen)) sb.AppendLine("•  " + z);
            if (zeilen.Count > HoechstensZeilen) sb.AppendLine(weitere(zeilen.Count - HoechstensZeilen));
            bool risiko = risiken != null && risiken.Count > 0;
            if (risiko)
            {
                sb.AppendLine();
                sb.AppendLine(englisch ? "⚠ Please check carefully:" : "⚠ Bitte genau prüfen:");
                if (risiken.Count <= HoechstensZeilen) foreach (var r in risiken) sb.AppendLine("•  " + r);
                else sb.AppendLine(string.Join("   ·   ", risiken));
            }
            sb.AppendLine();
            if (englisch) sb.Append(simulation ? "Simulation: nothing is written. Continue?" : "Continue?");
            else sb.Append(simulation ? "Simulation: Es wird nichts geschrieben. Fortfahren?" : "Fortfahren?");

            var besitzer = ui.FindForm();
            if (besitzer != null && besitzer.WindowState == FormWindowState.Minimized) besitzer.WindowState = FormWindowState.Normal;
            besitzer?.Activate();
            var antwort = MessageBox.Show(besitzer, sb.ToString(), englisch ? "OrcaShield – please confirm" : "OrcaShield – bitte bestätigen",
                MessageBoxButtons.YesNo,
                risiko ? MessageBoxIcon.Warning : MessageBoxIcon.Question,
                risiko ? MessageBoxDefaultButton.Button2 : MessageBoxDefaultButton.Button1);
            return antwort == DialogResult.Yes;
        }
    }
}
