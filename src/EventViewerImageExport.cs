using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Diagnostics.Eventing.Reader;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

internal static class Program
{
    private const string OutputDirectoryDefault = @"C:\codex_artifacts";
    private const int LaunchDelayMsDefault = 5000;
    private static string _logPath;

    [STAThread]
    private static void Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        try
        {
            Run(args);
        }
        catch (Exception ex)
        {
            try
            {
                File.AppendAllText(
                    _logPath ?? Path.Combine(OutputDirectoryDefault, "EventViewerImageExport.log"),
                    DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff", CultureInfo.InvariantCulture) + " ERROR " + ex + Environment.NewLine);
            }
            catch
            {
            }
            MessageBox.Show(ex.Message, "Event Viewer Image Export", MessageBoxButtons.OK, MessageBoxIcon.Error);
            Environment.ExitCode = 1;
        }
    }

    private static void Run(string[] args)
    {
        ExportOptions options = ExportOptions.FromArgs(args) ?? ShowInputForm();
        _logPath = Path.Combine(options.OutputDirectory ?? OutputDirectoryDefault, "EventViewerImageExport.log");
        Log("Run started");
        Log(string.Format(
            CultureInfo.InvariantCulture,
            "Options start={0}, end={1}, mode={2}, output={3}, delay={4}, keep={5}",
            options.StartTime,
            options.EndTime,
            options.Mode,
            options.OutputDirectory,
            options.LaunchDelayMs,
            options.KeepExportedLog));
        if (options.EndTime <= options.StartTime)
        {
            throw new InvalidOperationException("EndTime must be later than StartTime.");
        }

        if (!Environment.UserInteractive)
        {
            throw new InvalidOperationException("This tool must run in an interactive Windows desktop session.");
        }

        Directory.CreateDirectory(options.OutputDirectory);
        Log("Output directory ensured");

        List<string> saved = new List<string>();
        List<string> missing = new List<string>();

        foreach (Mode mode in GetModes(options.Mode))
        {
            int eventId = mode == Mode.Logon ? 7001 : 7002;
            Log("Checking mode " + mode + " / event " + eventId);
            List<DateTime> matches = GetMatchingEventTimes(options.StartTime, options.EndTime, eventId);
            if (matches.Count == 0)
            {
                missing.Add(string.Format("{0} (ID {1})", mode, eventId));
                continue;
            }

            string stem = BuildFileStem(options.StartTime, options.EndTime, mode.ToString().ToLowerInvariant());
            string evtxPath = Path.Combine(options.OutputDirectory, stem + "_" + Guid.NewGuid().ToString("N") + ".evtx");
            string pngPath = Path.Combine(options.OutputDirectory, stem + ".png");

            Log("Exporting EVTX to " + evtxPath);
            ExportFilteredLog(options.StartTime, options.EndTime, eventId, evtxPath);
            Log("Capturing window to " + pngPath);
            CaptureEventViewerWindow(evtxPath, pngPath, options.LaunchDelayMs);

            if (!options.KeepExportedLog && File.Exists(evtxPath))
            {
                File.Delete(evtxPath);
            }

            saved.Add(pngPath);
        }

        if (saved.Count == 0)
        {
            throw new InvalidOperationException("No output file was created because no matching Winlogon event was found in the requested time range.");
        }

        string message = "Saved PNG file(s):" + Environment.NewLine + string.Join(Environment.NewLine, saved);
        if (missing.Count > 0)
        {
            message += Environment.NewLine + Environment.NewLine + "Not found:" + Environment.NewLine + string.Join(Environment.NewLine, missing);
        }

        MessageBox.Show(message, "Event Viewer Image Export", MessageBoxButtons.OK, MessageBoxIcon.Information);
    }

    private static void Log(string message)
    {
        try
        {
            string line = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff", CultureInfo.InvariantCulture) + " " + message + Environment.NewLine;
            File.AppendAllText(_logPath ?? Path.Combine(OutputDirectoryDefault, "EventViewerImageExport.log"), line);
        }
        catch
        {
        }
    }

    private static IEnumerable<Mode> GetModes(Mode mode)
    {
        if (mode == Mode.Both)
        {
            yield return Mode.Logon;
            yield return Mode.Logoff;
            yield break;
        }

        yield return mode;
    }

    private static string BuildFileStem(DateTime start, DateTime end, string suffix)
    {
        if (start.Date == end.Date)
        {
            return string.Format("{0}_{1}", start.ToString("yyyy-MM-dd"), suffix);
        }

        return string.Format(
            "{0}_to_{1}_{2}",
            start.ToString("yyyy-MM-dd_HHmmss"),
            end.ToString("yyyy-MM-dd_HHmmss"),
            suffix);
    }

    private static List<DateTime> GetMatchingEventTimes(DateTime start, DateTime end, int eventId)
    {
        string query = BuildQuery(start, end, eventId);
        EventLogQuery logQuery = new EventLogQuery("System", PathType.LogName, query)
        {
            ReverseDirection = true
        };

        List<DateTime> result = new List<DateTime>();
        using (EventLogReader reader = new EventLogReader(logQuery))
        {
            EventRecord record;
            while ((record = reader.ReadEvent()) != null)
            {
                using (record)
                {
                    if (record.TimeCreated.HasValue)
                    {
                        result.Add(record.TimeCreated.Value);
                    }
                }
            }
        }

        return result;
    }

    private static string BuildQuery(DateTime start, DateTime end, int eventId)
    {
        string startUtc = start.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ", CultureInfo.InvariantCulture);
        string endUtc = end.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ", CultureInfo.InvariantCulture);
        return string.Format(
            CultureInfo.InvariantCulture,
            "*[System[Provider[@Name='Microsoft-Windows-Winlogon'] and (EventID={0}) and TimeCreated[@SystemTime>='{1}' and @SystemTime<='{2}']]]",
            eventId,
            startUtc,
            endUtc);
    }

    private static void ExportFilteredLog(DateTime start, DateTime end, int eventId, string evtxPath)
    {
        string query = BuildQuery(start, end, eventId);
        string arguments = string.Format(
            CultureInfo.InvariantCulture,
            "epl System \"{0}\" /q:\"{1}\"",
            evtxPath,
            query);

        ProcessStartInfo psi = new ProcessStartInfo("wevtutil.exe", arguments)
        {
            UseShellExecute = false,
            CreateNoWindow = true
        };

        using (Process process = Process.Start(psi))
        {
            process.WaitForExit();
            Log("wevtutil exit code: " + process.ExitCode);
            if (process.ExitCode != 0 || !File.Exists(evtxPath))
            {
                throw new InvalidOperationException("Failed to export filtered event log.");
            }
        }
    }

    private static void CaptureEventViewerWindow(string evtxPath, string pngPath, int launchDelayMs)
    {
        DateTime launchMarker = DateTime.Now;
        HashSet<int> existingIds = new HashSet<int>(Process.GetProcessesByName("mmc").Select(p => p.Id));
        Log("Existing mmc count: " + existingIds.Count);

        Process.Start("eventvwr.exe", "/l:\"" + evtxPath + "\"");
        Thread.Sleep(launchDelayMs);

        Process windowProcess = WaitForEventViewerWindow(existingIds, launchMarker, 30);
        if (windowProcess == null)
        {
            throw new InvalidOperationException("Timed out waiting for the Event Viewer window.");
        }

        Log("Window process found: " + windowProcess.Id + " / " + windowProcess.MainWindowTitle);

        NativeMethods.ShowWindowAsync(windowProcess.MainWindowHandle, 5);
        Thread.Sleep(300);
        NativeMethods.MoveWindow(windowProcess.MainWindowHandle, 20, 20, 1600, 980, true);
        Thread.Sleep(500);
        NativeMethods.SetForegroundWindow(windowProcess.MainWindowHandle);
        Thread.Sleep(1200);

        CaptureWindow(windowProcess.MainWindowHandle, pngPath);
        Log("Window captured");

        try
        {
            if (!windowProcess.CloseMainWindow())
            {
                windowProcess.Kill();
            }
            else
            {
                if (!windowProcess.WaitForExit(2000))
                {
                    windowProcess.Kill();
                }
            }
        }
        catch
        {
        }
    }

    private static Process WaitForEventViewerWindow(HashSet<int> existingIds, DateTime launchMarker, int timeoutSeconds)
    {
        DateTime deadline = DateTime.Now.AddSeconds(timeoutSeconds);
        while (DateTime.Now < deadline)
        {
            Process process = Process.GetProcessesByName("mmc")
                .Where(p => p.MainWindowHandle != IntPtr.Zero)
                .OrderByDescending(p => p.StartTime)
                .FirstOrDefault(p => !existingIds.Contains(p.Id));

            if (process != null)
            {
                return process;
            }

            process = Process.GetProcessesByName("mmc")
                .Where(p => p.MainWindowHandle != IntPtr.Zero && p.StartTime >= launchMarker.AddSeconds(-2))
                .OrderByDescending(p => p.StartTime)
                .FirstOrDefault();

            if (process != null)
            {
                return process;
            }

            Thread.Sleep(500);
        }

        return null;
    }

    private static void CaptureWindow(IntPtr handle, string pngPath)
    {
        NativeMethods.RECT rect;
        if (!NativeMethods.GetWindowRect(handle, out rect))
        {
            throw new InvalidOperationException("Unable to read Event Viewer window bounds.");
        }

        int width = rect.Right - rect.Left;
        int height = rect.Bottom - rect.Top;
        if (width <= 0 || height <= 0)
        {
            throw new InvalidOperationException("Invalid Event Viewer window size.");
        }

        Log(string.Format(CultureInfo.InvariantCulture, "Capture rect: {0},{1},{2},{3}", rect.Left, rect.Top, rect.Right, rect.Bottom));

        using (Bitmap bitmap = new Bitmap(width, height))
        using (Graphics graphics = Graphics.FromImage(bitmap))
        {
            graphics.CopyFromScreen(rect.Left, rect.Top, 0, 0, bitmap.Size);
            bitmap.Save(pngPath, System.Drawing.Imaging.ImageFormat.Png);
        }
    }

    private static ExportOptions ShowInputForm()
    {
        using (Form form = new Form())
        using (Font font = new Font("Malgun Gothic", 10))
        {
            form.Text = "Event Viewer Image Export";
            form.StartPosition = FormStartPosition.CenterScreen;
            form.Size = new Size(440, 260);
            form.FormBorderStyle = FormBorderStyle.FixedDialog;
            form.MaximizeBox = false;
            form.MinimizeBox = false;
            form.TopMost = true;
            form.Font = font;

            Label labelStart = CreateLabel("StartTime", 20, 20);
            TextBox textStart = CreateTextBox(DateTime.Today.ToString("yyyy-MM-dd 00:00:00"), 150, 18);
            Label labelEnd = CreateLabel("EndTime", 20, 60);
            TextBox textEnd = CreateTextBox(DateTime.Today.AddDays(1).AddSeconds(-1).ToString("yyyy-MM-dd HH:mm:ss"), 150, 58);
            Label labelMode = CreateLabel("Mode", 20, 100);

            ComboBox combo = new ComboBox
            {
                Location = new Point(150, 98),
                Size = new Size(140, 24),
                DropDownStyle = ComboBoxStyle.DropDownList
            };
            combo.Items.AddRange(new object[] { "Logoff", "Logon", "Both" });
            combo.SelectedIndex = 0;

            Label help = new Label
            {
                Location = new Point(20, 135),
                Size = new Size(390, 36),
                Text = "Time format: yyyy-MM-dd HH:mm:ss"
            };

            Button ok = new Button
            {
                Location = new Point(220, 175),
                Size = new Size(80, 30),
                Text = "OK",
                DialogResult = DialogResult.OK
            };

            Button cancel = new Button
            {
                Location = new Point(310, 175),
                Size = new Size(80, 30),
                Text = "Cancel",
                DialogResult = DialogResult.Cancel
            };

            form.Controls.Add(labelStart);
            form.Controls.Add(textStart);
            form.Controls.Add(labelEnd);
            form.Controls.Add(textEnd);
            form.Controls.Add(labelMode);
            form.Controls.Add(combo);
            form.Controls.Add(help);
            form.Controls.Add(ok);
            form.Controls.Add(cancel);
            form.AcceptButton = ok;
            form.CancelButton = cancel;

            while (true)
            {
                if (form.ShowDialog() != DialogResult.OK)
                {
                    throw new InvalidOperationException("Cancelled by user.");
                }

                DateTime start;
                DateTime end;
                if (DateTime.TryParse(textStart.Text, out start) && DateTime.TryParse(textEnd.Text, out end))
                {
                    return new ExportOptions
                    {
                        StartTime = start,
                        EndTime = end,
                        Mode = (Mode)Enum.Parse(typeof(Mode), combo.SelectedItem.ToString(), true),
                        OutputDirectory = OutputDirectoryDefault,
                        LaunchDelayMs = LaunchDelayMsDefault,
                        KeepExportedLog = false
                    };
                }

                MessageBox.Show(
                    "StartTime / EndTime format is invalid. Use yyyy-MM-dd HH:mm:ss",
                    "Invalid Input",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
            }
        }
    }

    private static Label CreateLabel(string text, int x, int y)
    {
        return new Label
        {
            Location = new Point(x, y),
            Size = new Size(120, 24),
            Text = text
        };
    }

    private static TextBox CreateTextBox(string text, int x, int y)
    {
        return new TextBox
        {
            Location = new Point(x, y),
            Size = new Size(240, 24),
            Text = text
        };
    }

    private enum Mode
    {
        Logon,
        Logoff,
        Both
    }

    private sealed class ExportOptions
    {
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public Mode Mode { get; set; }
        public string OutputDirectory { get; set; }
        public int LaunchDelayMs { get; set; }
        public bool KeepExportedLog { get; set; }

        public static ExportOptions FromArgs(string[] args)
        {
            if (args == null || args.Length == 0)
            {
                return null;
            }

            Dictionary<string, string> values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            for (int i = 0; i < args.Length; i++)
            {
                string key = args[i];
                if (!key.StartsWith("--", StringComparison.Ordinal))
                {
                    continue;
                }

                List<string> parts = new List<string>();
                int j = i + 1;
                while (j < args.Length && !args[j].StartsWith("--", StringComparison.Ordinal))
                {
                    parts.Add(args[j]);
                    j++;
                }

                string value = string.Join(" ", parts);
                values[key] = value;
                i = j - 1;
            }

            DateTime start;
            DateTime end;
            if (!values.ContainsKey("--start") || !DateTime.TryParse(values["--start"], out start) ||
                !values.ContainsKey("--end") || !DateTime.TryParse(values["--end"], out end))
            {
                return null;
            }

            Mode mode = Mode.Both;
            if (values.ContainsKey("--mode"))
            {
                mode = (Mode)Enum.Parse(typeof(Mode), values["--mode"], true);
            }

            return new ExportOptions
            {
                StartTime = start,
                EndTime = end,
                Mode = mode,
                OutputDirectory = values.ContainsKey("--output") ? values["--output"] : OutputDirectoryDefault,
                LaunchDelayMs = values.ContainsKey("--delay") ? int.Parse(values["--delay"], CultureInfo.InvariantCulture) : LaunchDelayMsDefault,
                KeepExportedLog = values.ContainsKey("--keep-evtx")
            };
        }
    }

    private static class NativeMethods
    {
        [StructLayout(LayoutKind.Sequential)]
        internal struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        [DllImport("user32.dll")]
        internal static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        internal static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

        [DllImport("user32.dll")]
        internal static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

        [DllImport("user32.dll")]
        internal static extern bool MoveWindow(IntPtr hWnd, int x, int y, int nWidth, int nHeight, bool bRepaint);
    }
}
