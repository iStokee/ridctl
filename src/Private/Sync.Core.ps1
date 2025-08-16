<#
    Core synchronisation functions used by Sync-RiDScripts.

    Invoke-RiDSync produces and (optionally) applies a sync plan between a
    LocalPath and a SharePath. It honors excludes and supports three modes:
    - FromShare: only copy Share -> Local
    - ToShare: only copy Local -> Share
    - Bidirectional: copy newest both ways; conflicts optionally resolved

    Public cmdlet should call this with -Apply:$PSCmdlet.ShouldProcess(...)
#>
function Invoke-RiDSync {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$LocalPath,
        [Parameter(Mandatory=$true)] [string]$SharePath,
        [Parameter(Mandatory=$true)] [ValidateSet('FromShare','ToShare','Bidirectional')] [string]$Mode,
        [string[]]$Excludes,
        [switch]$DryRun,
        [string]$LogPath,
        [switch]$ResolveConflicts,
        [switch]$Apply
    )

    if (-not (Test-Path -LiteralPath $LocalPath))  { throw "LocalPath not found: $LocalPath" }
    if (-not (Test-Path -LiteralPath $SharePath))  { throw "SharePath not found: $SharePath" }

    $plan = @()
    $cmp = Compare-RiDFiles -SourcePath $LocalPath -DestPath $SharePath -Mode 'TimestampSize' -Excludes $Excludes

    foreach ($e in $cmp) {
        if ($e.Same) { continue }
        $action = 'None'
        $direction = ''
        $reason = $e.DiffReason
        $conflict = $false

        if (-not $e.SourceExists -and $e.DestExists) {
            # Only in share
            if ($Mode -in @('FromShare','Bidirectional')) { $action = 'Copy'; $direction='ShareToLocal' } else { $action='Skip' }
        } elseif ($e.SourceExists -and -not $e.DestExists) {
            # Only in local
            if ($Mode -in @('ToShare','Bidirectional')) { $action = 'Copy'; $direction='LocalToShare' } else { $action='Skip' }
        } elseif ($e.SourceExists -and $e.DestExists) {
            switch ($e.DiffReason) {
                'SourceNewer' { if ($Mode -in @('ToShare','Bidirectional')) { $action='Copy'; $direction='LocalToShare' } else { $action='Skip' } }
                'DestNewer'   { if ($Mode -in @('FromShare','Bidirectional')) { $action='Copy'; $direction='ShareToLocal' } else { $action='Skip' } }
                default {
                    # SizeDiff or TimestampDiff with equal mtimes, treat as conflict
                    if ($Mode -eq 'FromShare') {
                        $action='Copy'; $direction='ShareToLocal'
                    } elseif ($Mode -eq 'ToShare') {
                        $action='Copy'; $direction='LocalToShare'
                    } else {
                        $conflict = $true
                        if ($ResolveConflicts) {
                            # prefer newer by mtime; if equal, prefer Local -> Share
                            if ($e.SourceMtime -gt $e.DestMtime) { $action='Copy'; $direction='LocalToShare' }
                            elseif ($e.DestMtime -gt $e.SourceMtime) { $action='Copy'; $direction='ShareToLocal' }
                            else { $action='Copy'; $direction='LocalToShare' }
                            $conflict = $false
                            $reason = 'ResolvedConflict'
                        } else {
                            $action='Skip'; $reason='Conflict'
                        }
                    }
                }
            }
        }

        if ($action -eq 'Copy') {
            if ($direction -eq 'LocalToShare') {
                $src = Join-Path -Path $LocalPath -ChildPath $e.RelativePath
                $dst = Join-Path -Path $SharePath -ChildPath $e.RelativePath
            } else {
                $src = Join-Path -Path $SharePath -ChildPath $e.RelativePath
                $dst = Join-Path -Path $LocalPath -ChildPath $e.RelativePath
            }
            $plan += [pscustomobject]@{
                Action = 'Copy'
                Direction = $direction
                Source = $src
                Destination = $dst
                RelativePath = $e.RelativePath
                Reason = $reason
            }
        } elseif ($action -eq 'Skip') {
            $plan += [pscustomobject]@{
                Action = 'Skip'
                Direction = ''
                Source = $e.SourcePath
                Destination = $e.DestPath
                RelativePath = $e.RelativePath
                Reason = $reason
            }
        }
    }

    # Apply if requested
    $copied = 0
    if ($Apply) {
        foreach ($p in $plan | Where-Object { $_.Action -eq 'Copy' }) {
            $dir = Split-Path -Path $p.Destination -Parent
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Copy-Item -LiteralPath $p.Source -Destination $p.Destination -Force
            $copied++
        }
    }

    # Logging
    if ($LogPath) {
        try {
            $lines = @()
            foreach ($p in $plan) {
                $lines += ("{0}: {1} -> {2} ({3})" -f $p.Action, $p.Source, $p.Destination, $p.Reason)
            }
            $lines | Out-File -LiteralPath $LogPath -Encoding UTF8 -Force
        } catch { Write-Verbose "Failed to write log: $_" }
    }

    $summary = [pscustomobject]@{
        Total      = $plan.Count
        Copies     = ($plan | Where-Object { $_.Action -eq 'Copy' }).Count
        Skips      = ($plan | Where-Object { $_.Action -eq 'Skip' }).Count
        Applied    = [int]$copied
        Plan       = $plan
    }
    return $summary
}
