Set objShell = CreateObject("WScript.Shell")

' ユーザーのプロファイルディレクトリを取得
userProfile = CreateObject("WScript.Shell").ExpandEnvironmentStrings("%USERPROFILE%")

' PowerShellを実行して.ps1ファイルを隠れたウィンドウで実行
objShell.Run "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & userProfile & "\MyDownloadedFiles\a.ps1""", 0, False
