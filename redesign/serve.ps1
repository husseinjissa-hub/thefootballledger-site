param([string]$Root = ".", [int]$Port = 8899, [int]$Threads = 12)
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path $Root).Path
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "serving $Root on http://localhost:$Port/  ($Threads workers)"

$worker = {
  param($listener, $Root)
  $mime = @{ ".html"="text/html; charset=utf-8"; ".css"="text/css"; ".js"="application/javascript"; ".json"="application/json"; ".png"="image/png"; ".jpg"="image/jpeg"; ".jpeg"="image/jpeg"; ".svg"="image/svg+xml"; ".webp"="image/webp"; ".ico"="image/x-icon"; ".woff2"="font/woff2"; ".xml"="application/xml"; ".txt"="text/plain" }
  while ($listener.IsListening) {
    try { $ctx = $listener.GetContext() } catch { break }
    try {
      $ctx.Response.KeepAlive = $false
      $p = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
      if ($p -eq "/") { $p = "/index.html" }
      $file = Join-Path $Root ($p.TrimStart("/"))
      if (-not [System.IO.Path]::HasExtension($file)) {
        if (Test-Path $file -PathType Container) {
          if (Test-Path (Join-Path $file "index.html")) { $file = Join-Path $file "index.html" }
        } elseif (-not (Test-Path $file)) {
          if (Test-Path "$file.html") { $file = "$file.html" }
          elseif (Test-Path (Join-Path $file "index.html")) { $file = Join-Path $file "index.html" }
        }
      }
      if (Test-Path $file -PathType Leaf) {
        $ext = [System.IO.Path]::GetExtension($file).ToLower()
        $ct = $mime[$ext]; if (-not $ct) { $ct = "application/octet-stream" }
        $bytes = [System.IO.File]::ReadAllBytes($file)
        $ctx.Response.ContentType = $ct
        $ctx.Response.ContentLength64 = $bytes.Length
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
      } else { $ctx.Response.StatusCode = 404 }
      $ctx.Response.Close()
    } catch { try { $ctx.Response.Abort() } catch { } }
  }
}

$pool = [runspacefactory]::CreateRunspacePool(1, $Threads); $pool.Open()
for ($i = 0; $i -lt $Threads; $i++) {
  $ps = [powershell]::Create(); $ps.RunspacePool = $pool
  [void]$ps.AddScript($worker).AddArgument($listener).AddArgument($Root)
  [void]$ps.BeginInvoke()
}
while ($listener.IsListening) { Start-Sleep -Seconds 2 }
