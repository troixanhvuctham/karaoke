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
# Không có key cũng được: cứ đóng Notepad, trang vẫn tìm bài bình thường.

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

# Mở thành cửa sổ riêng như một ứng dụng (không có thanh địa chỉ, không có tab) để người dùng
# không nhầm thanh địa chỉ với ô tìm bài. Ưu tiên Chrome, không có thì Edge (có sẵn trên Windows),
# cả hai đều hỗ trợ tìm bằng giọng nói. Không có cả hai thì dùng trình duyệt mặc định.
function Open-Page {
    $browser = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($browser) { Start-Process $browser "--app=$url --start-maximized" } else { Start-Process $url }
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

# Tìm cửa sổ karaoke đang mở (theo tiêu đề trang) để đưa lên trước thay vì mở thêm cửa sổ.
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class KaraokeWindow {
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    public static IntPtr Find(string title) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((h, l) => {
            if (!IsWindowVisible(h)) return true;
            var sb = new StringBuilder(256);
            GetWindowText(h, sb, 256);
            if (sb.ToString() != title) return true;
            found = h;
            return false;
        }, IntPtr.Zero);
        return found;
    }
    public static bool Focus(string title) {
        IntPtr found = Find(title);
        if (found == IntPtr.Zero) return false;
        if (IsIconic(found)) ShowWindow(found, 9);
        SetForegroundWindow(found);
        return true;
    }
}
"@
$windowTitle = "Hát Karaoke"

# Mở cửa sổ rồi chờ nó hiện ra (tối đa 30 giây), để các lần nhấp đúp tiếp theo thấy cửa sổ này.
function Open-PageAndWait {
    Open-Page
    for ($i = 0; $i -lt 100; $i++) {
        Start-Sleep -Milliseconds 300
        if ([KaraokeWindow]::Focus($windowTitle)) { return }
    }
}

# Nhấp đúp nhiều lần liên tiếp: các lần sau xếp hàng chờ lần đầu mở xong cửa sổ,
# rồi chỉ đưa cửa sổ đó lên trước. Chờ quá lâu (đang nhập key ở Notepad) thì bỏ qua.
$mutex = New-Object System.Threading.Mutex($false, "Local\HatKaraokeLauncher")
try { $owned = $mutex.WaitOne(60000) } catch [System.Threading.AbandonedMutexException] { $owned = $true }
if (-not $owned) { exit }
if ([KaraokeWindow]::Focus($windowTitle)) { $mutex.ReleaseMutex(); exit }

# Server đã chạy từ lần trước thì chỉ cần mở cửa sổ.
$tcp = New-Object System.Net.Sockets.TcpClient
$serverRunning = try { $tcp.ConnectAsync("127.0.0.1", $port).Wait(1000) } catch { $false }
$tcp.Close()
if ($serverRunning) {
    Open-PageAndWait
    $mutex.ReleaseMutex()
    exit
}

# Lần chạy đầu tiên: tạo file key và mở Notepad cho người dùng dán key vào.
if (-not (Test-Path $keyFile)) {
    Write-Key ""
    Start-Process notepad $keyFile -Wait
}

# Tìm video trên YouTube không cần API key (dùng khi không có key hoặc key hết lượt):
# tải trang kết quả tìm kiếm rồi đọc dữ liệu ytInitialData trong trang, giống app Android.
# Trả về JSON [{id, title, channel, thumb}], hoặc "null" nếu không đọc được.
Add-Type -ReferencedAssemblies System.Web.Extensions @"
using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Text;
using System.Web.Script.Serialization;
public static class KaraokeSearch {
    const int MaxResults = 24;
    public static string SearchJson(string query) {
        try {
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
            var req = (HttpWebRequest)WebRequest.Create(
                "https://www.youtube.com/results?hl=vi&gl=VN&search_query=" + Uri.EscapeDataString(query));
            req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36";
            req.Headers["Accept-Language"] = "vi-VN,vi;q=0.9";
            req.Headers["Cookie"] = "CONSENT=YES+";
            req.AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate;
            req.Timeout = 15000;
            string html;
            using (var resp = req.GetResponse())
            using (var reader = new StreamReader(resp.GetResponseStream(), Encoding.UTF8)) html = reader.ReadToEnd();
            const string marker = "var ytInitialData = ";
            int start = html.IndexOf(marker);
            if (start < 0) return "null";
            start += marker.Length;
            int end = html.IndexOf(";</script>", start);
            if (end < 0) return "null";
            var json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue, RecursionLimit = 1000 };
            var results = new List<Dictionary<string, string>>();
            Collect(json.DeserializeObject(html.Substring(start, end - start)), results);
            return json.Serialize(results);
        } catch {
            return "null";
        }
    }
    // Duyệt toàn bộ dữ liệu, lấy mọi "videoRenderer" (bỏ qua Shorts và quảng cáo).
    static void Collect(object node, List<Dictionary<string, string>> results) {
        if (results.Count >= MaxResults) return;
        var obj = node as Dictionary<string, object>;
        if (obj != null) {
            foreach (var kv in obj) {
                var video = kv.Value as Dictionary<string, object>;
                if (kv.Key == "videoRenderer" && video != null) {
                    var item = ToResult(video);
                    if (item != null && results.Count < MaxResults) results.Add(item);
                } else {
                    Collect(kv.Value, results);
                }
            }
            return;
        }
        var arr = node as object[];
        if (arr != null) foreach (var child in arr) Collect(child, results);
    }
    static Dictionary<string, string> ToResult(Dictionary<string, object> v) {
        object idValue;
        v.TryGetValue("videoId", out idValue);
        var id = idValue as string;
        var title = FirstRun(v, "title");
        if (string.IsNullOrEmpty(id) || title == "") return null;
        var channel = FirstRun(v, "ownerText");
        if (channel == "") channel = FirstRun(v, "longBylineText");
        return new Dictionary<string, string> {
            { "id", id }, { "title", title }, { "channel", channel },
            { "thumb", "https://i.ytimg.com/vi/" + id + "/hqdefault.jpg" }
        };
    }
    static string FirstRun(Dictionary<string, object> v, string key) {
        object value;
        if (!v.TryGetValue(key, out value)) return "";
        var text = value as Dictionary<string, object>;
        if (text == null) return "";
        object runs, simple;
        if (text.TryGetValue("runs", out runs)) {
            var list = runs as object[];
            var first = list != null && list.Length > 0 ? list[0] as Dictionary<string, object> : null;
            object t;
            if (first != null && first.TryGetValue("text", out t)) return t as string ?? "";
        }
        if (text.TryGetValue("simpleText", out simple)) return simple as string ?? "";
        return "";
    }
}
"@

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)
$listener.Start()
Open-Page

# Server phải trả trang ngay thì cửa sổ mới hiện được, nên vừa phục vụ vừa theo dõi:
# khi cửa sổ đã hiện (hoặc quá 30 giây) thì mới cho các lần nhấp đúp đang chờ chạy tiếp.
$released = $false
$deadline = (Get-Date).AddSeconds(30)
while ($listener.IsListening) {
    $next = $listener.GetContextAsync()
    while (-not $next.Wait(300)) {
        if (-not $released -and (([KaraokeWindow]::Find($windowTitle) -ne [IntPtr]::Zero) -or (Get-Date) -gt $deadline)) {
            $mutex.ReleaseMutex()
            $released = $true
        }
    }
    $ctx = $next.Result
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
    } elseif ($path -eq "/api/search") {
        # Tự giải mã tham số q theo UTF-8 (QueryString của HttpListener có thể giải mã sai tiếng Việt).
        $q = [regex]::Match($req.Url.Query, "[?&]q=([^&]*)").Groups[1].Value
        $q = [System.Uri]::UnescapeDataString($q.Replace("+", " "))
        $bytes = [System.Text.Encoding]::UTF8.GetBytes([KaraokeSearch]::SearchJson($q))
        $res.ContentType = "application/json; charset=utf-8"
    } else {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes("Not found")
        $res.StatusCode = 404
    }
    $res.ContentLength64 = $bytes.Length
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
    $res.Close()
}
