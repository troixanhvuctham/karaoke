# Chạy trang karaoke qua http://localhost để YouTube cho phép phát video ngay trong trang.
# Mở từ file (file://) thì YouTube chặn video nhúng.
# Người dùng không chạy file này trực tiếp mà nhấp đúp Karaoke.bat.
$port = 8765
$url = "http://localhost:$port/"
$page = Join-Path $PSScriptRoot "index.html"
# YouTube API key lưu ở đây (không đưa lên git, xem .gitignore).
$keyFile = Join-Path $PSScriptRoot "api-key.txt"
$keyHelp = @"
# Dán YouTube API key (bắt đầu bằng AIza...) vào dòng trống bên dưới,
# bấm Ctrl+S để lưu, rồi đóng Notepad. Trang karaoke sẽ tự mở.
# Không có key cũng được: cứ đóng Notepad, trang vẫn chạy (bấm tìm sẽ mở YouTube).

"@

# Key là dòng đầu tiên không trống và không bắt đầu bằng #.
function Read-Key {
    if (-not (Test-Path $keyFile)) { return "" }
    $line = Get-Content $keyFile -Encoding UTF8 | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") } | Select-Object -First 1
    if ($line) { $line } else { "" }
}
function Write-Key($key) {
    [System.IO.File]::WriteAllText($keyFile, $keyHelp + $key + "`r`n", (New-Object System.Text.UTF8Encoding $true))
}

# Mở bằng Brave; máy không có Brave thì dùng trình duyệt mặc định.
function Open-Page {
    $brave = @(
        "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe",
        "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser\Application\brave.exe",
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($brave) { Start-Process $brave $url } else { Start-Process $url }
}

# Tạo shortcut "Hát Karaoke" có icon micro ngoài Desktop (cập nhật lại nếu thư mục bị chuyển chỗ).
function Update-Shortcut {
    try {
        $lnkPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Hát Karaoke.lnk"
        $arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
        $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut($lnkPath)
        if ($lnk.Arguments -eq $arguments) { return }
        $lnk.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $lnk.Arguments = $arguments
        $lnk.WorkingDirectory = $PSScriptRoot
        $lnk.WindowStyle = 7
        $lnk.IconLocation = Join-Path $PSScriptRoot "karaoke.ico"
        $lnk.Description = "Hát Karaoke"
        $lnk.Save()
    } catch {}
}
Update-Shortcut

# Server đã chạy từ lần trước thì chỉ cần mở trình duyệt.
try {
    Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 2 | Out-Null
    Open-Page
    exit
} catch {}

# Lần chạy đầu tiên: tạo file key và mở Notepad cho người dùng dán key vào.
if (-not (Test-Path $keyFile)) {
    Write-Key ""
    Start-Process notepad $keyFile -Wait
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)
$listener.Start()
Open-Page

while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    $path = $req.Url.AbsolutePath
    if ($path -in @("/", "/index.html")) {
        $bytes = [System.IO.File]::ReadAllBytes($page)
        $res.ContentType = "text/html; charset=utf-8"
    } elseif ($path -eq "/api/key" -and $req.HttpMethod -eq "GET") {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes((Read-Key))
        $res.ContentType = "text/plain; charset=utf-8"
    } elseif ($path -eq "/api/key" -and $req.HttpMethod -eq "POST" -and $req.Headers["Origin"] -eq $url.TrimEnd("/")) {
        # Chỉ nhận ghi key từ chính trang karaoke, không cho trang web khác ghi đè.
        Write-Key (New-Object System.IO.StreamReader($req.InputStream)).ReadToEnd().Trim()
        $bytes = [System.Text.Encoding]::UTF8.GetBytes("ok")
    } else {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes("Not found")
        $res.StatusCode = 404
    }
    $res.ContentLength64 = $bytes.Length
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
    $res.Close()
}
