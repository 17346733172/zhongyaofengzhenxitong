param([switch]$NoBrowser)

$ErrorActionPreference = 'Stop'
$frontendPath = Join-Path $PSScriptRoot 'frontend'
$vitePath = Join-Path $frontendPath 'node_modules\vite\bin\vite.js'
$cachePath = Join-Path $PSScriptRoot 'cache'
$siteUrl = 'http://127.0.0.1:5173'

function Test-Platform {
    try {
        $package = Invoke-WebRequest -Uri "$siteUrl/package.json" -UseBasicParsing -TimeoutSec 2
        $page = Invoke-WebRequest -Uri $siteUrl -UseBasicParsing -TimeoutSec 2
        return (($package.Content | ConvertFrom-Json).name -eq 'decoction-sim-frontend' -and
                $page.Content -match '/src/main.jsx')
    } catch {
        return $false
    }
}

function Test-FrontendPort {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        return $client.ConnectAsync('127.0.0.1', 5173).Wait(500)
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
}

New-Item -ItemType Directory -Path $cachePath -Force | Out-Null
# Serialize simultaneous double-clicks and the Windows login shortcut.
$hash = [System.Security.Cryptography.SHA256]::Create()
try {
    $projectId = [BitConverter]::ToString($hash.ComputeHash(
        [Text.Encoding]::UTF8.GetBytes($PSScriptRoot.ToLowerInvariant()))).Replace('-', '')
} finally {
    $hash.Dispose()
}
$mutex = New-Object System.Threading.Mutex($false, "Local\DecoctionLauncher-$projectId")
$locked = $false
try {
    try { $locked = $mutex.WaitOne(60000) } catch [System.Threading.AbandonedMutexException] { $locked = $true }
    if (-not $locked) { throw 'Another platform launcher is still starting. Please try again shortly.' }

    if (-not (Test-Platform)) {
        if (Test-FrontendPort) {
            throw 'Port 5173 belongs to another application. Close that application, then try again.'
        }
        $node = Get-Command node.exe -ErrorAction SilentlyContinue
        if (-not $node) { throw 'Node.js is missing. Install Node.js, then run this launcher again.' }
        if (-not (Test-Path -LiteralPath $vitePath)) {
            Write-Host 'Installing frontend dependencies...'
            Push-Location -LiteralPath $frontendPath
            try {
                & npm.cmd ci
                if ($LASTEXITCODE -ne 0) { throw 'npm ci failed. Check the network and retry.' }
            } finally {
                Pop-Location
            }
        }

        Write-Host 'Starting the platform in the background...'
        $devProcess = Start-Process -FilePath $node.Source -WorkingDirectory $frontendPath `
            -ArgumentList ('"{0}" --host 127.0.0.1 --port 5173 --strictPort' -f $vitePath) `
            -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $cachePath 'frontend.stdout.log') `
            -RedirectStandardError (Join-Path $cachePath 'frontend.stderr.log')
        $timer = [Diagnostics.Stopwatch]::StartNew()
        while (-not (Test-Platform)) {
            $devProcess.Refresh()
            if ($devProcess.HasExited -or $timer.Elapsed.TotalSeconds -ge 40) {
                throw 'Frontend startup failed. See cache/frontend.stderr.log and cache/frontend.stdout.log.'
            }
            Start-Sleep -Milliseconds 250
        }
    }
    Write-Host "Platform ready: $siteUrl"
    # Read through the existing proxy; never start a second backend scheduler.
    try {
        $snapshot = Invoke-WebRequest -Uri "$siteUrl/api/v1/simulation" -UseBasicParsing -TimeoutSec 10
        if (-not ($snapshot.Content | ConvertFrom-Json).clock) { throw 'Invalid simulation response' }
        Write-Host 'Backend connection OK.'
    } catch {
        Write-Warning 'The page is running, but the backend check failed. Check the network and frontend/.env.local; refresh the page when the backend is available.'
    }
    if (-not $NoBrowser) { Start-Process $siteUrl }
} catch {
    $_.Exception.Message | Set-Content -LiteralPath (Join-Path $cachePath 'launcher-error.log') -Encoding UTF8
    Write-Error $_.Exception.Message
    exit 1
} finally {
    if ($locked) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
