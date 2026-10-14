// One-step launcher for the Playback Helper Windows helper (UNVERIFIED build).
// The helper script (playback-helper.ps1) is embedded in this .exe as a resource.
// On start, the launcher writes it to %LOCALAPPDATA%\PlaybackHelper and runs it with
// the Windows PowerShell 5.1 that ships with Windows, in this same console window.
//
// Written for the C# 5 compiler included with .NET Framework 4.x (csc.exe), so no
// SDK has to be installed. Build with Build-Exe.cmd.
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;

internal static class PlaybackHelperLauncher
{
    private const string ResourceName = "playback-helper.ps1";

    private static int Main(string[] args)
    {
        // Ctrl+C reaches PowerShell too and stops the helper; the launcher stays alive
        // so the window remains open and the outcome can be read.
        Console.CancelKeyPress += delegate(object sender, ConsoleCancelEventArgs e) { e.Cancel = true; };
        int code;
        try
        {
            code = Run(args);
        }
        catch (Exception ex)
        {
            Console.WriteLine("ERROR: " + ex.Message);
            code = 1;
        }
        Console.WriteLine();
        if (code == -1073741510)   // 0xC000013A: STATUS_CONTROL_C_EXIT
        {
            Console.WriteLine("Stopped with Ctrl+C.");
        }
        else if (code != 0)
        {
            Console.WriteLine("The helper exited with an error (code " + code + "). Read the messages above.");
        }
        Console.WriteLine("Press Enter to close this window...");
        try { Console.ReadLine(); } catch (Exception) { }
        return code;
    }

    private static int Run(string[] args)
    {
        byte[] script = ReadEmbeddedScript();

        // A content hash in the file name means a newer .exe never reuses an older script.
        string folder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PlaybackHelper");
        Directory.CreateDirectory(folder);
        string scriptPath = Path.Combine(folder, "playback-helper-" + ShortHash(script) + ".ps1");
        if (!File.Exists(scriptPath) || !SameBytes(File.ReadAllBytes(scriptPath), script))
        {
            File.WriteAllBytes(scriptPath, script);   // Exact bytes, keeping the UTF-8 BOM.
        }

        string powershell = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe");
        if (!File.Exists(powershell))
        {
            Console.WriteLine("ERROR: Windows PowerShell 5.1 was not found at:");
            Console.WriteLine("  " + powershell);
            Console.WriteLine("It is included with Windows 10 and 11. Check that it has not been removed or blocked.");
            return 1;
        }

        // -ExecutionPolicy Bypass applies only to this one PowerShell process; it does
        // not change any system or user setting. Group Policy still takes precedence.
        StringBuilder arguments = new StringBuilder();
        arguments.Append("-NoLogo -NoProfile -ExecutionPolicy Bypass -File ");
        arguments.Append(Quote(scriptPath));
        foreach (string arg in args)
        {
            arguments.Append(' ').Append(Quote(arg));
        }

        ProcessStartInfo info = new ProcessStartInfo(powershell, arguments.ToString());
        info.UseShellExecute = false;   // Share this console window.
        info.WorkingDirectory = folder;
        using (Process process = Process.Start(info))
        {
            process.WaitForExit();
            return process.ExitCode;
        }
    }

    private static byte[] ReadEmbeddedScript()
    {
        using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(ResourceName))
        {
            if (stream == null)
            {
                throw new InvalidOperationException(
                    "The helper script is missing from this .exe. Rebuild it with Build-Exe.cmd.");
            }
            using (MemoryStream memory = new MemoryStream())
            {
                stream.CopyTo(memory);
                return memory.ToArray();
            }
        }
    }

    private static string ShortHash(byte[] data)
    {
        using (SHA256 sha = SHA256.Create())
        {
            byte[] hash = sha.ComputeHash(data);
            StringBuilder text = new StringBuilder();
            for (int i = 0; i < 6; i++) { text.Append(hash[i].ToString("x2")); }
            return text.ToString();
        }
    }

    private static bool SameBytes(byte[] a, byte[] b)
    {
        if (a.Length != b.Length) { return false; }
        for (int i = 0; i < a.Length; i++) { if (a[i] != b[i]) { return false; } }
        return true;
    }

    // Quote one argument using the Windows command-line rules (CommandLineToArgvW).
    private static string Quote(string arg)
    {
        if (arg.Length > 0 && arg.IndexOfAny(new char[] { ' ', '\t', '"' }) < 0) { return arg; }
        StringBuilder result = new StringBuilder("\"");
        int backslashes = 0;
        foreach (char c in arg)
        {
            if (c == '\\') { backslashes++; continue; }
            if (c == '"') { result.Append('\\', backslashes * 2 + 1); }
            else { result.Append('\\', backslashes); }
            backslashes = 0;
            result.Append(c);
        }
        result.Append('\\', backslashes * 2);
        result.Append('"');
        return result.ToString();
    }
}
