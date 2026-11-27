using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

internal static class FilterLabLauncher
{
    private const string MatlabCommand = "try, if ~strcmpi(pwd,getenv('FILTERLAB_APP_DIR')), cd(getenv('FILTERLAB_APP_DIR')); end; FilterLabSession; exit(0); catch err, disp(getReport(err,'extended','hyperlinks','off')); exit(1); end";
    private static readonly Encoding Utf8 = new UTF8Encoding(false);

    [STAThread]
    private static int Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        string packageRoot = AppDomain.CurrentDomain.BaseDirectory;
        bool selfTest = Array.IndexOf(args, "--self-test") >= 0;
        bool uiTest = Array.IndexOf(args, "--ui-test") >= 0;
        bool dialogTest = Array.IndexOf(args, "--dialog-test") >= 0;
        bool interactiveLaunch = !selfTest && !uiTest && !dialogTest;
        string logDirectory = "";
        Mutex instanceMutex = null;
        EventWaitHandle activateEvent = null;
        EventWaitHandle activatedEvent = null;
        bool ownsMutex = false;
        try
        {
            // A bare double-click reuses this package's active session. Explicit
            // image opens and verification commands retain independent sessions.
            if (args.Length == 0)
            {
                string identity = InstanceIdentity(packageRoot);
                activateEvent = new EventWaitHandle(false, EventResetMode.AutoReset, "Local\\FilterLab.Activate." + identity);
                activatedEvent = new EventWaitHandle(false, EventResetMode.AutoReset, "Local\\FilterLab.Activated." + identity);
                instanceMutex = new Mutex(false, "Local\\FilterLab.Instance." + identity);
                while (!ownsMutex)
                {
                    try { ownsMutex = instanceMutex.WaitOne(0); }
                    catch (AbandonedMutexException) { ownsMutex = true; }
                    if (ownsMutex) break;
                    activateEvent.Set();
                    if (activatedEvent.WaitOne(500)) return 0;
                }
                // A pending activation from the previous, exiting owner belongs
                // to the cold start we are now fulfilling.
                activateEvent.Reset();
                activatedEvent.Reset();
            }

            string dataRoot = WritableDataRoot(packageRoot);
            logDirectory = Path.Combine(dataRoot, "logs", DateTime.Now.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture) + "-" + Guid.NewGuid().ToString("N").Substring(0, 6));
            Directory.CreateDirectory(logDirectory);
            if (IsLowIntegrity())
                throw new IOException("当前程序从受限制的低完整性工作区启动，Windows 会阻止 MATLAB 初始化。请将完整软件包放到普通用户文件夹后运行。");
            string appRoot = Path.Combine(packageRoot, "app");
            if (!File.Exists(Path.Combine(appRoot, "FilterLabApp.m")))
                throw new FileNotFoundException("找不到 app\\FilterLabApp.m。请完整解压分发包，勿单独移动 EXE。");
            string matlab = FindMatlab(packageRoot, dataRoot);
            if (matlab == null)
            {
                if (!interactiveLaunch)
                    throw new FileNotFoundException("自动测试未找到 MATLAB。请检查 matlab-path.txt 或 MATLAB_ROOT。");
                MessageBox.Show("请选择 MATLAB R2020b 或更新版本安装目录中的 bin\\matlab.exe。", "FilterLab · 选择 MATLAB", MessageBoxButtons.OK, MessageBoxIcon.Information);
                using (OpenFileDialog picker = new OpenFileDialog())
                {
                    picker.Title = "选择 MATLAB 的 bin\\matlab.exe";
                    picker.Filter = "MATLAB|matlab.exe";
                    if (picker.ShowDialog() == DialogResult.OK)
                    {
                        matlab = picker.FileName;
                        File.WriteAllText(Path.Combine(dataRoot, "matlab-path.txt"), matlab, Utf8);
                    }
                }
            }
            if (matlab == null)
                throw new FileNotFoundException("未找到已安装的 MATLAB。此启动封装版需要 MATLAB R2020b 或更新版本。");

            string testOutput = Path.Combine(logDirectory, "self-test");
            int outputIndex = Array.IndexOf(args, "--test-output");
            if (outputIndex >= 0)
            {
                if (outputIndex + 1 == args.Length)
                    throw new ArgumentException("--test-output 需要一个空目录路径。");
                testOutput = Path.GetFullPath(args[outputIndex + 1]);
            }
            string readyFile = Path.Combine(logDirectory, "ready.flag");
            string warmConfig = args.Length == 0 ? Path.Combine(dataRoot, "warm-reopen.flag") : "";
            ProcessStartInfo start = new ProcessStartInfo(matlab);
            start.Arguments = "-wait -nosplash -nodesktop -sd " + Quote(appRoot) + " -logfile " + Quote(Path.Combine(logDirectory, "matlab.log")) + " -r " + Quote(MatlabCommand);
            start.WorkingDirectory = appRoot;
            start.UseShellExecute = false;
            start.CreateNoWindow = true;
            start.RedirectStandardOutput = true;
            start.RedirectStandardError = true;
            start.RedirectStandardInput = true;
            start.EnvironmentVariables["FILTERLAB_APP_DIR"] = appRoot;
            start.EnvironmentVariables["FILTERLAB_PACKAGED"] = "1";
            start.EnvironmentVariables["FILTERLAB_USER_DATA"] = dataRoot;
            start.EnvironmentVariables["FILTERLAB_READY_FILE"] = readyFile;
            start.EnvironmentVariables["FILTERLAB_WARM_CONFIG"] = warmConfig;
            start.EnvironmentVariables["FILTERLAB_SELF_TEST"] = selfTest ? "1" : "0";
            start.EnvironmentVariables["FILTERLAB_UI_TEST"] = uiTest ? "1" : "0";
            start.EnvironmentVariables["FILTERLAB_DIALOG_TEST"] = dialogTest ? "1" : "0";
            start.EnvironmentVariables["FILTERLAB_TEST_OUTPUT"] = testOutput;
            start.EnvironmentVariables["FILTERLAB_OPEN_FILE"] = "";
            if (interactiveLaunch && args.Length == 1 && File.Exists(args[0]))
                start.EnvironmentVariables["FILTERLAB_OPEN_FILE"] = Path.GetFullPath(args[0]);
            File.WriteAllText(Path.Combine(logDirectory, "launcher.txt"),
                "Mode=MATLAB-dependent launcher\r\nMATLAB=" + matlab + "\r\nApp=" + appRoot +
                "\r\nData=" + dataRoot + "\r\nTestOutput=" + testOutput + "\r\nArguments=" + start.Arguments +
                "\r\nTEMP=" + start.EnvironmentVariables["TEMP"] + "\r\nTMP=" + start.EnvironmentVariables["TMP"] + "\r\n", Utf8);

            using (TextWriter output = TextWriter.Synchronized(new StreamWriter(Path.Combine(logDirectory, "stdout.log"), false, Utf8)))
            using (TextWriter error = TextWriter.Synchronized(new StreamWriter(Path.Combine(logDirectory, "stderr.log"), false, Utf8)))
            using (Process child = new Process())
            {
                child.StartInfo = start;
                child.OutputDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (e.Data != null) { output.WriteLine(e.Data); output.Flush(); } };
                child.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (e.Data != null) { error.WriteLine(e.Data); error.Flush(); } };
                child.Start();
                File.WriteAllText(Path.Combine(logDirectory, "launcher-child-pid.txt"), child.Id.ToString(CultureInfo.InvariantCulture), Utf8);
                child.BeginOutputReadLine();
                child.BeginErrorReadLine();
                child.StandardInput.Close();
                bool cancelled = false;
                bool everReady = false;
                if (!selfTest)
                {
                    using (StartupWindow window = new StartupWindow(child, logDirectory, activateEvent, activatedEvent, warmConfig, Path.Combine(packageRoot, "filterlab-neon.ico")))
                    {
                        Application.Run(window);
                        cancelled = window.Cancelled;
                        everReady = window.EverReady;
                    }
                }
                child.WaitForExit();
                int exitCode = child.ExitCode;
                if (!cancelled && (exitCode != 0 || (!selfTest && !everReady && !File.Exists(readyFile))))
                {
                    string message = exitCode == 0 ? "MATLAB 已退出，主界面尚未就绪。" : "MATLAB 启动或运行失败，退出码 " + exitCode + "。";
                    File.AppendAllText(Path.Combine(logDirectory, "launcher-state.log"), DateTime.Now.ToString("O") + " " + message + Environment.NewLine, Utf8);
                    if (interactiveLaunch)
                        MessageBox.Show(message + "\n日志目录\n" + logDirectory, "FilterLab", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return exitCode == 0 ? 1 : exitCode;
                }
                return cancelled ? 2 : exitCode;
            }
        }
        catch (Exception error)
        {
            Console.Error.WriteLine(error);
            if (logDirectory.Length > 0)
            {
                try { File.WriteAllText(Path.Combine(logDirectory, "launcher-error.txt"), error.ToString(), Utf8); }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
            if (interactiveLaunch)
                MessageBox.Show(error.Message + "\n日志目录\n" + logDirectory, "FilterLab", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
        finally
        {
            if (ownsMutex) instanceMutex.ReleaseMutex();
            if (instanceMutex != null) instanceMutex.Dispose();
            if (activateEvent != null) activateEvent.Dispose();
            if (activatedEvent != null) activatedEvent.Dispose();
        }
    }

    private static string InstanceIdentity(string packageRoot)
    {
        string value = Path.GetFullPath(packageRoot).TrimEnd(Path.DirectorySeparatorChar).ToUpperInvariant() + "|" +
            WindowsIdentity.GetCurrent().User.Value + "|" + Process.GetCurrentProcess().SessionId;
        using (SHA256 hash = SHA256.Create())
            return BitConverter.ToString(hash.ComputeHash(Encoding.UTF8.GetBytes(value))).Replace("-", "");
    }

    private static string WritableDataRoot(string packageRoot)
    {
        string portable = Path.Combine(packageRoot, "userdata");
        string local = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "FilterLab");
        string[] candidates = File.Exists(Path.Combine(packageRoot, "portable.flag")) ? new string[] { portable } : new string[] { local, portable };
        foreach (string directory in candidates)
        {
            try
            {
                Directory.CreateDirectory(directory);
                string probe = Path.Combine(directory, ".write-" + Guid.NewGuid().ToString("N"));
                using (FileStream stream = new FileStream(probe, FileMode.CreateNew, FileAccess.Write, FileShare.None, 1, FileOptions.DeleteOnClose))
                    stream.WriteByte(1);
                return directory;
            }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }
        throw new IOException("用户数据目录和程序旁的 userdata 目录均不可写。请将整个软件包放到自己可写的文件夹后运行。");
    }

    private static string FindMatlab(string packageRoot, string dataRoot)
    {
        List<string> candidates = new List<string>();
        foreach (string config in new string[] { Path.Combine(packageRoot, "matlab-path.txt"), Path.Combine(dataRoot, "matlab-path.txt") })
        {
            if (!File.Exists(config)) continue;
            string candidate = File.ReadAllText(config).Trim().Trim('"');
            if (File.Exists(candidate)) return Path.GetFullPath(candidate);
        }
        string environmentRoot = Environment.GetEnvironmentVariable("MATLAB_ROOT");
        if (!String.IsNullOrWhiteSpace(environmentRoot))
        {
            string candidate = Path.Combine(environmentRoot, "bin", "matlab.exe");
            if (File.Exists(candidate)) return Path.GetFullPath(candidate);
        }
        foreach (RegistryHive hive in new RegistryHive[] { RegistryHive.CurrentUser, RegistryHive.LocalMachine })
        foreach (RegistryView view in new RegistryView[] { RegistryView.Registry64, RegistryView.Registry32 })
        {
            try
            {
                using (RegistryKey root = RegistryKey.OpenBaseKey(hive, view))
                using (RegistryKey versions = root.OpenSubKey("SOFTWARE\\MathWorks\\MATLAB"))
                {
                    if (versions == null) continue;
                    string[] names = versions.GetSubKeyNames();
                    Array.Sort(names, StringComparer.OrdinalIgnoreCase);
                    Array.Reverse(names);
                    foreach (string name in names)
                    using (RegistryKey release = versions.OpenSubKey(name))
                    {
                        string install = release == null ? null : release.GetValue("MATLABROOT") as string;
                        if (!String.IsNullOrEmpty(install))
                        {
                            string candidate = Path.Combine(install, "bin", "matlab.exe");
                            if (File.Exists(candidate)) return Path.GetFullPath(candidate);
                        }
                    }
                }
            }
            catch (System.Security.SecurityException) { }
            catch (UnauthorizedAccessException) { }
            catch (IOException) { }
        }
        foreach (Environment.SpecialFolder folder in new Environment.SpecialFolder[] { Environment.SpecialFolder.ProgramFiles, Environment.SpecialFolder.ProgramFilesX86 })
        {
            string directory = Path.Combine(Environment.GetFolderPath(folder), "MATLAB");
            if (!Directory.Exists(directory)) continue;
            string[] releases = Directory.GetDirectories(directory, "R20*");
            Array.Sort(releases, StringComparer.OrdinalIgnoreCase);
            Array.Reverse(releases);
            foreach (string release in releases) candidates.Add(Path.Combine(release, "bin", "matlab.exe"));
        }
        candidates.Add(@"D:\MATLAB\bin\matlab.exe");
        foreach (string candidate in candidates)
            if (File.Exists(candidate)) return Path.GetFullPath(candidate);
        return null;
    }

    // Windows command-line quoting also handles a trailing backslash.
    private static string Quote(string value)
    {
        StringBuilder result = new StringBuilder("\"");
        int slashes = 0;
        foreach (char character in value)
        {
            if (character == '\\') { slashes++; continue; }
            result.Append('\\', character == '"' ? slashes * 2 + 1 : slashes);
            result.Append(character);
            slashes = 0;
        }
        result.Append('\\', slashes * 2);
        return result.Append('"').ToString();
    }

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool GetTokenInformation(IntPtr token, int informationClass, IntPtr information, int informationLength, out int returnLength);

    private static bool IsLowIntegrity()
    {
        using (WindowsIdentity identity = WindowsIdentity.GetCurrent())
        {
            int length;
            GetTokenInformation(identity.Token, 25, IntPtr.Zero, 0, out length);
            if (length == 0) return false;
            IntPtr information = Marshal.AllocHGlobal(length);
            try
            {
                if (!GetTokenInformation(identity.Token, 25, information, length, out length)) return false;
                string sid = new SecurityIdentifier(Marshal.ReadIntPtr(information)).Value;
                return UInt32.Parse(sid.Substring(sid.LastIndexOf('-') + 1), CultureInfo.InvariantCulture) < 8192;
            }
            finally { Marshal.FreeHGlobal(information); }
        }
    }

    private sealed class StartupWindow : Form
    {
        private readonly Process child;
        private readonly string logDirectory;
        private readonly string readyFile;
        private readonly EventWaitHandle activateEvent;
        private readonly EventWaitHandle activatedEvent;
        private readonly string warmConfig;
        private readonly Stopwatch elapsed = Stopwatch.StartNew();
        private readonly System.Windows.Forms.Timer poll = new System.Windows.Forms.Timer();
        private readonly Label stage = new Label();
        private readonly Label timing = new Label();
        private readonly Button cancel = new Button();
        private string lastStage = "";
        private bool ready;
        private bool warmOpening;
        private bool childFinished;
        private bool cancelling;
        internal bool Cancelled { get; private set; }
        internal bool EverReady { get; private set; }

        internal StartupWindow(Process childProcess, string directory, EventWaitHandle activation, EventWaitHandle acknowledgement, string preference, string iconPath)
        {
            child = childProcess;
            logDirectory = directory;
            readyFile = Path.Combine(directory, "ready.flag");
            activateEvent = activation;
            activatedEvent = acknowledgement;
            warmConfig = preference;
            Text = "FilterLab · 正在启动";
            ClientSize = new Size(550, 250);
            MinimumSize = Size;
            MaximumSize = Size;
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            BackColor = Color.FromArgb(25, 28, 40);
            ForeColor = Color.White;
            Font = new Font("Microsoft YaHei UI", 10);
            if (File.Exists(iconPath)) Icon = new Icon(iconPath);
            stage.SetBounds(24, 22, 502, 70);
            stage.Text = "正在启动 MATLAB 引擎…";
            timing.SetBounds(24, 96, 502, 54);
            timing.ForeColor = Color.LightGray;
            if (warmConfig.Length != 0)
            {
                CheckBox keepWarm = new CheckBox();
                keepWarm.Text = "快速重开：关闭后保留 MATLAB 两分钟";
                keepWarm.SetBounds(24, 150, 502, 30);
                keepWarm.Checked = File.Exists(warmConfig);
                keepWarm.Click += delegate { SaveWarmPreference(keepWarm); };
                Controls.Add(keepWarm);
            }
            Button logs = new Button();
            logs.Text = "查看本次日志";
            logs.SetBounds(24, 194, 150, 34);
            logs.Click += delegate { OpenLogs(); };
            cancel.Text = "取消启动";
            cancel.SetBounds(376, 194, 150, 34);
            cancel.Click += delegate { CancelStartup(); };
            Controls.AddRange(new Control[] { stage, timing, logs, cancel });
            FormClosing += ClosingStartup;
            poll.Interval = 250;
            poll.Tick += TickStartup;
            poll.Start();
            Record("Started child PID " + child.Id);
        }

        private void TickStartup(object sender, EventArgs args)
        {
            childFinished = child.HasExited;
            if (childFinished) { poll.Stop(); Close(); return; }
            if (!ready && IsReady())
            {
                ready = true;
                EverReady = true;
                Record((warmOpening ? "Warm ready in " : "Ready in ") + elapsed.Elapsed.TotalSeconds.ToString("F1", CultureInfo.InvariantCulture) + " s");
                warmOpening = false;
                Hide();
                poll.Interval = 400;
            }
            if (activateEvent != null && activateEvent.WaitOne(0))
            {
                bool handled = false;
                if (ready && TryClaimReopen())
                {
                    ready = false;
                    warmOpening = true;
                    elapsed.Restart();
                    lastStage = "";
                    poll.Interval = 250;
                    stage.Text = "正在重新打开照片工作室…";
                    FocusSplash();
                    Record("Claimed warm reopen");
                    handled = true;
                }
                else if (!ready && !cancelling && !Cancelled)
                {
                    FocusSplash();
                    handled = true;
                }
                else if (ready && !File.Exists(Path.Combine(logDirectory, "expired.flag")))
                    handled = FocusStudio();
                if (handled)
                {
                    Record("Duplicate launch activated existing session");
                    activatedEvent.Set();
                }
            }
            if (ready || cancelling) return;
            string text = ReadOptional(Path.Combine(logDirectory, "stage.txt"));
            if (text.Length == 0) text = warmOpening ? "正在重新打开照片工作室…" : "正在启动 MATLAB 引擎…";
            if (text != lastStage)
            {
                lastStage = text;
                stage.Text = text;
                Record("Stage " + text.Replace(Environment.NewLine, " "));
            }
            timing.Text = "已等待 " + ((int)elapsed.Elapsed.TotalSeconds).ToString(CultureInfo.InvariantCulture) + " 秒" +
                (elapsed.Elapsed.TotalSeconds >= 45 ? "\n可查看日志，或取消本次启动后重试。" : warmOpening ? "\n正在复用本次 MATLAB 引擎。" : "\nMATLAB 冷启动与首次界面加载需要一些时间。");
        }

        private bool IsReady()
        {
            return ReadOptional(warmOpening ? Path.Combine(logDirectory, "warm-ready.flag") : readyFile) == "READY";
        }

        private bool TryClaimReopen()
        {
            string idle = Path.Combine(logDirectory, "idle.flag");
            if (!File.Exists(idle)) return false;
            // MATLAB races this same move to expired.flag. Exactly one wins.
            try { File.Move(idle, Path.Combine(logDirectory, "reopen.flag")); return true; }
            catch (IOException) { return false; }
            catch (UnauthorizedAccessException) { return false; }
        }

        private void SaveWarmPreference(CheckBox checkbox)
        {
            try
            {
                if (checkbox.Checked) File.WriteAllText(warmConfig, "120", Utf8);
                else File.Delete(warmConfig);
            }
            catch (Exception error)
            {
                checkbox.Checked = File.Exists(warmConfig);
                MessageBox.Show(this, "无法保存快速重开设置。\n" + error.Message, "FilterLab", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void ClosingStartup(object sender, FormClosingEventArgs args)
        {
            if (ready || childFinished || Cancelled) return;
            args.Cancel = true;
            CancelStartup();
        }

        private void CancelStartup()
        {
            if (ready || childFinished || cancelling) return;
            cancelling = true;
            try
            {
                DialogResult answer = MessageBox.Show(this, "确定取消本次启动？将结束本次启动器创建的 MATLAB 进程。\n本次日志会保留，可重新双击 FilterLab 重试。", "FilterLab · 取消启动", MessageBoxButtons.YesNo, MessageBoxIcon.Question, MessageBoxDefaultButton.Button2);
                if (answer != DialogResult.Yes) return;
                // Readiness may arrive while the confirmation dialog is open.
                if (IsReady())
                {
                    ready = true;
                    EverReady = true;
                    Hide();
                    FocusStudio();
                    return;
                }
                if (child.HasExited) { childFinished = true; Close(); return; }
                ProcessStartInfo kill = new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "taskkill.exe"));
                kill.Arguments = "/PID " + child.Id.ToString(CultureInfo.InvariantCulture) + " /T /F";
                kill.UseShellExecute = false;
                kill.CreateNoWindow = true;
                using (Process stop = Process.Start(kill))
                {
                    stop.WaitForExit(10000);
                    if (!stop.HasExited || stop.ExitCode != 0)
                    {
                        if (!child.HasExited) throw new IOException("无法结束本次 MATLAB 进程。请查看本次日志。");
                    }
                }
                Cancelled = true;
                Record("Startup cancelled by user");
                cancel.Enabled = false;
                stage.Text = "正在结束本次 MATLAB 进程…";
            }
            catch (Exception error)
            {
                Record("Cancel failed " + error.Message);
                MessageBox.Show(this, error.Message, "FilterLab", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally { cancelling = false; }
        }

        private void OpenLogs()
        {
            try { Process.Start(new ProcessStartInfo(logDirectory) { UseShellExecute = true }); }
            catch (Exception error) { MessageBox.Show(this, error.Message, "FilterLab", MessageBoxButtons.OK, MessageBoxIcon.Error); }
        }

        private void FocusSplash()
        {
            if (WindowState == FormWindowState.Minimized) WindowState = FormWindowState.Normal;
            Show();
            Activate();
            SetForegroundWindow(Handle);
        }

        private bool FocusStudio()
        {
            int enginePid;
            if (!Int32.TryParse(ReadOptional(Path.Combine(logDirectory, "engine-pid.txt")), out enginePid)) return false;
            HashSet<int> processes = Descendants(enginePid);
            bool found = false;
            EnumWindows(delegate(IntPtr window, IntPtr state)
            {
                uint pid;
                GetWindowThreadProcessId(window, out pid);
                if (!processes.Contains((int)pid)) return true;
                StringBuilder caption = new StringBuilder(512);
                GetWindowText(window, caption, caption.Capacity);
                if (!IsWindowVisible(window) || caption.ToString().IndexOf("FilterLab", StringComparison.OrdinalIgnoreCase) < 0) return true;
                ShowWindow(window, 9);
                SetForegroundWindow(window);
                found = true;
                return false;
            }, IntPtr.Zero);
            return found;
        }

        private void Record(string text)
        {
            try { File.AppendAllText(Path.Combine(logDirectory, "launcher-state.log"), DateTime.Now.ToString("O") + " " + text + Environment.NewLine, Utf8); }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }

        private static string ReadOptional(string path)
        {
            try { return File.Exists(path) ? File.ReadAllText(path, Encoding.UTF8).Trim('\uFEFF', '\r', '\n', ' ') : ""; }
            catch (IOException) { return ""; }
            catch (UnauthorizedAccessException) { return ""; }
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) poll.Dispose();
            base.Dispose(disposing);
        }
    }

    private static HashSet<int> Descendants(int root)
    {
        HashSet<int> result = new HashSet<int>();
        result.Add(root);
        IntPtr snapshot = CreateToolhelp32Snapshot(2, 0);
        if (snapshot == new IntPtr(-1)) return result;
        try
        {
            List<ProcessEntry> entries = new List<ProcessEntry>();
            ProcessEntry entry = new ProcessEntry();
            entry.Size = (uint)Marshal.SizeOf(typeof(ProcessEntry));
            if (Process32First(snapshot, ref entry))
                do { entries.Add(entry); } while (Process32Next(snapshot, ref entry));
            bool added;
            do
            {
                added = false;
                foreach (ProcessEntry process in entries)
                    if (result.Contains((int)process.ParentId) && result.Add((int)process.Id)) added = true;
            } while (added);
        }
        finally { CloseHandle(snapshot); }
        return result;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    private struct ProcessEntry
    {
        internal uint Size, Usage, Id;
        internal IntPtr Heap;
        internal uint Module, Threads, ParentId;
        internal int Priority;
        internal uint Flags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] internal string Name;
    }
    private delegate bool WindowCallback(IntPtr window, IntPtr state);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern IntPtr CreateToolhelp32Snapshot(uint flags, uint processId);
    [DllImport("kernel32.dll", CharSet = CharSet.Auto)] private static extern bool Process32First(IntPtr snapshot, ref ProcessEntry entry);
    [DllImport("kernel32.dll", CharSet = CharSet.Auto)] private static extern bool Process32Next(IntPtr snapshot, ref ProcessEntry entry);
    [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr handle);
    [DllImport("user32.dll")] private static extern bool EnumWindows(WindowCallback callback, IntPtr state);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowText(IntPtr window, StringBuilder text, int maximum);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr window, int command);
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr window);
}
