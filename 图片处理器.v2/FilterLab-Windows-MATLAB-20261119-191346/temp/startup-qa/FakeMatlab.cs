using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;

internal static class FakeMatlab
{
    private static int Main(string[] args)
    {
        string ready = Environment.GetEnvironmentVariable("FILTERLAB_READY_FILE");
        string logs = Path.GetDirectoryName(ready);
        File.WriteAllText(Path.Combine(logs, "fake-arguments.txt"), String.Join("\n", args), Encoding.UTF8);
        File.WriteAllText(Path.Combine(logs, "fake-environment.txt"),
            "Packaged=" + Environment.GetEnvironmentVariable("FILTERLAB_PACKAGED") +
            "\nApp=" + Environment.GetEnvironmentVariable("FILTERLAB_APP_DIR") +
            "\nData=" + Environment.GetEnvironmentVariable("FILTERLAB_USER_DATA") +
            "\nTestOutput=" + Environment.GetEnvironmentVariable("FILTERLAB_TEST_OUTPUT") +
            "\nSelfTest=" + Environment.GetEnvironmentVariable("FILTERLAB_SELF_TEST") +
            "\nUiTest=" + Environment.GetEnvironmentVariable("FILTERLAB_UI_TEST") +
            "\nDialogTest=" + Environment.GetEnvironmentVariable("FILTERLAB_DIALOG_TEST") +
            "\nPhoto=" + Environment.GetEnvironmentVariable("FILTERLAB_OPEN_FILE"), Encoding.UTF8);
        File.WriteAllText(Path.Combine(logs, "engine-pid.txt"), Process.GetCurrentProcess().Id.ToString());
        File.WriteAllText(Path.Combine(logs, "stage.txt"), "模拟 MATLAB 初始化阶段", Encoding.UTF8);
        Console.WriteLine("FAKE_ENGINE_STDOUT");
        Console.Error.WriteLine("FAKE_ENGINE_STDERR");
        Thread.Sleep(600);
        if (Environment.GetEnvironmentVariable("FILTERLAB_SELF_TEST") != "1" && Environment.GetEnvironmentVariable("FAKE_NO_READY") != "1")
            File.WriteAllText(ready, "READY");
        if (Environment.GetEnvironmentVariable("FAKE_HOLD") == "1")
            while (!File.Exists(Path.Combine(logs, "release.flag"))) Thread.Sleep(100);
        Thread.Sleep(300);
        int exitCode;
        Int32.TryParse(Environment.GetEnvironmentVariable("FAKE_EXIT"), out exitCode);
        return exitCode;
    }
}
