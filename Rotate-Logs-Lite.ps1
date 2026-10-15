# Rotate-Logs-Lite.ps1 - compress big log files to .gz and expire old archives.
# Dry-run by default. Only touches files directly inside the given folder.
# No network. Windows PowerShell 5.1 or PowerShell 7.
#
# Usage: .\Rotate-Logs-Lite.ps1 -Path C:\Logs [-Filter *.log] [-MinKB 1024]
#                               [-KeepDays 30] [-Apply]
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$Filter = '*.log',
    [int]$MinKB = 1024,
    [int]$KeepDays = 30,
    [switch]$Apply
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Path -PathType Container)) { Write-Error "Not a folder: $Path"; exit 2 }
if ($Filter -match '[\\/]') { Write-Error "-Filter must be a file name pattern, not a path"; exit 2 }
if ($MinKB -lt 0 -or $KeepDays -lt 0) { Write-Error "-MinKB and -KeepDays must be >= 0"; exit 2 }

$dir = (Resolve-Path -LiteralPath $Path).ProviderPath
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$rot = 0; $del = 0; $err = 0
function Say($lvl, $msg) { Write-Host ("{0} [{1}] {2}" -f (Get-Date -Format 'HH:mm:ss'), $lvl, $msg) }

if (-not $Apply) { Say 'INFO' 'DRY RUN - nothing is changed. Add -Apply to do it.' }
Say 'INFO' "Folder: $dir  filter: $Filter  min: $MinKB KB  keep-days: $KeepDays"

$files = Get-ChildItem -LiteralPath $dir -Filter $Filter -File | Where-Object { $_.Extension -ne '.gz' -and $_.Length -gt 0 -and $_.Length -ge ($MinKB * 1KB) }
foreach ($f in $files) {
    $gzPath = "$($f.FullName).$stamp.gz"
    if (Test-Path -LiteralPath $gzPath) { Say 'WARN' "Exists, skipped: $gzPath"; $err++; continue }
    if (-not $Apply) { Say 'INFO' "Would rotate: $($f.Name) ($($f.Length) bytes)"; $rot++; continue }
    try {
        $in = [System.IO.File]::Open($f.FullName, 'Open', 'Read', 'ReadWrite')
        try {
            $out = [System.IO.File]::Create($gzPath)
            try {
                $gz = New-Object System.IO.Compression.GZipStream($out, [System.IO.Compression.CompressionMode]::Compress)
                $in.CopyTo($gz); $gz.Dispose()
            } finally { $out.Dispose() }
        } finally { $in.Dispose() }
        # empty the original (copy-truncate)
        $fs = [System.IO.File]::Open($f.FullName, 'Truncate', 'Write', 'ReadWrite'); $fs.Dispose()
        Say 'INFO' "Rotated: $($f.Name) -> $([System.IO.Path]::GetFileName($gzPath))"; $rot++
    } catch {
        Say 'WARN' "Failed, original kept: $($f.Name) - $($_.Exception.Message)"
        if (Test-Path -LiteralPath $gzPath) { Remove-Item -LiteralPath $gzPath -Force }
        $err++
    }
}

if ($KeepDays -gt 0) {
    $cutoff = (Get-Date).AddDays(-$KeepDays)
    $base = $Filter
    Get-ChildItem -LiteralPath $dir -Filter '*.gz' -File | Where-Object {
        $_.LastWriteTime -lt $cutoff -and $_.Name -match '^(.+)\.\d{8}-\d{6}\.gz$' -and ($Matches[1] -like $base)
    } | ForEach-Object {
        if (-not $Apply) { Say 'INFO' "Would delete old archive: $($_.Name)"; $del++ }
        else {
            try { Remove-Item -LiteralPath $_.FullName -Force; Say 'INFO' "Deleted old archive: $($_.Name)"; $del++ }
            catch { Say 'WARN' "Could not delete $($_.Name)"; $err++ }
        }
    }
}
Say 'INFO' "Rotated: $rot   Old archives removed: $del   Errors: $err"
if ($err -gt 0) { exit 1 }
exit 0
