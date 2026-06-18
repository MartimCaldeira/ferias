# serve.ps1 — minimal static file server for local preview/testing (zero dependencies).
# Usage: powershell -ExecutionPolicy Bypass -NoProfile -File serve.ps1 [port]
param([int]$Port = 8777)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }

$types = @{
  ".html" = "text/html; charset=utf-8";
  ".css"  = "text/css; charset=utf-8";
  ".js"   = "application/javascript; charset=utf-8";
  ".svg"  = "image/svg+xml";
  ".json" = "application/json; charset=utf-8";
  ".ico"  = "image/x-icon";
  ".png"  = "image/png";
  ".webmanifest" = "application/manifest+json";
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Bancada a servir em http://localhost:$Port/  (raiz: $root)"

while ($listener.IsListening) {
  try {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    $res.KeepAlive = $false
    $res.Headers.Add("Connection", "close")
    $res.Headers.Add("Cache-Control", "no-cache")
    $path = [System.Uri]::UnescapeDataString($req.Url.AbsolutePath).TrimStart("/")
    if ([string]::IsNullOrWhiteSpace($path)) { $path = "index.html" }
    $full = Join-Path $root $path
    if ((Test-Path $full) -and -not (Get-Item $full).PSIsContainer) {
      $ext = [System.IO.Path]::GetExtension($full).ToLower()
      $ct = $types[$ext]; if (-not $ct) { $ct = "application/octet-stream" }
      $bytes = [System.IO.File]::ReadAllBytes($full)
      $res.ContentType = $ct
      $res.ContentLength64 = $bytes.Length
      $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $res.StatusCode = 404
      $msg = [System.Text.Encoding]::UTF8.GetBytes("404: $path")
      $res.OutputStream.Write($msg, 0, $msg.Length)
    }
    $res.OutputStream.Close()
  } catch {
    try { $ctx.Response.StatusCode = 500; $ctx.Response.OutputStream.Close() } catch {}
  }
}
