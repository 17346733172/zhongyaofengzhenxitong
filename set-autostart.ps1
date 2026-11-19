param([switch]$Disable)

$ErrorActionPreference = 'Stop'
$startupPath = [Environment]::GetFolderPath('Startup')
if (-not $startupPath) { throw 'The current Windows user has no Startup folder.' }
$shortcutPath = Join-Path $startupPath 'DecoctionSimulation.lnk'

if ($Disable) {
    if (Test-Path -LiteralPath $shortcutPath) { Remove-Item -LiteralPath $shortcutPath }
    Write-Host 'Platform login startup disabled.'
    exit 0
}

New-Item -ItemType Directory -Path $startupPath -Force | Out-Null
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$shortcut.Arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -NoBrowser' -f (Join-Path $PSScriptRoot 'start.ps1')
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.WindowStyle = 7
$shortcut.Description = 'Start the local Decoction Simulation frontend at Windows login'
$shortcut.Save()
Write-Host 'Platform login startup enabled. Open http://127.0.0.1:5173 after login.'
