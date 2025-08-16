<#
    Compare two directories for sync planning.

    Default mode compares by LastWriteTimeUtc and file Length. Hash mode
    (SHA256) is available but slower; only compute when requested.

    Returns an array of entries describing per-file state for both sides.
    Consumers (Invoke-RiDSync) decide direction-specific actions.
#>
function Compare-RiDFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$SourcePath,
        [Parameter(Mandatory=$true)] [string]$DestPath,
        [ValidateSet('TimestampSize','Hash')]
        [string]$Mode = 'TimestampSize',
        [string[]]$Excludes
    )

    $src = Resolve-Path -LiteralPath $SourcePath -ErrorAction Stop | Select-Object -First 1 -ExpandProperty Path
    $dst = Resolve-Path -LiteralPath $DestPath -ErrorAction Stop | Select-Object -First 1 -ExpandProperty Path

    $excludePatterns = @($Excludes | Where-Object { $_ })

    function _ShouldExclude([string]$rel) {
        if (-not $excludePatterns -or $excludePatterns.Count -eq 0) { return $false }
        foreach ($pat in $excludePatterns) {
            # Support simple wildcard matching on relative paths
            if ($rel -like $pat) { return $true }
        }
        return $false
    }

    function _EnumerateFiles([string]$root) {
        if (-not (Test-Path -LiteralPath $root)) { return @{} }
        $map = @{}
        Get-ChildItem -LiteralPath $root -Recurse -File | ForEach-Object {
            $rel = [IO.Path]::GetRelativePath($root, $_.FullName)
            $rel = $rel -replace '\\','/'
            if (_ShouldExclude $rel) { return }
            $map[$rel] = [pscustomobject]@{
                FullPath = $_.FullName
                Length   = $_.Length
                MtimeUtc = $_.LastWriteTimeUtc
            }
        }
        return $map
    }

    function _GetHash([string]$path) {
        try { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash } catch { return $null }
    }

    $left  = _EnumerateFiles $src
    $right = _EnumerateFiles $dst
    $keys = @{}
    foreach ($k in $left.Keys)  { $keys[$k] = $true }
    foreach ($k in $right.Keys) { $keys[$k] = $true }

    $results = @()
    foreach ($rel in $keys.Keys | Sort-Object) {
        $l = $left[$rel]
        $r = $right[$rel]
        $existsL = $null -ne $l
        $existsR = $null -ne $r
        $same = $false
        $diffReason = ''

        if ($existsL -and $existsR) {
            if ($Mode -eq 'Hash') {
                $lh = _GetHash $l.FullPath
                $rh = _GetHash $r.FullPath
                $same = ($lh -and $rh -and $lh -eq $rh)
                if (-not $same) { $diffReason = 'HashDiff' }
            } else {
                $same = ($l.Length -eq $r.Length -and $l.MtimeUtc -eq $r.MtimeUtc)
                if (-not $same) {
                    if ($l.MtimeUtc -gt $r.MtimeUtc) { $diffReason = 'SourceNewer' }
                    elseif ($r.MtimeUtc -gt $l.MtimeUtc) { $diffReason = 'DestNewer' }
                    elseif ($l.Length -ne $r.Length) { $diffReason = 'SizeDiff' }
                    else { $diffReason = 'TimestampDiff' }
                }
            }
        }

        $results += [pscustomobject]@{
            RelativePath = $rel
            SourcePath   = if ($existsL) { $l.FullPath } else { $null }
            DestPath     = if ($existsR) { $r.FullPath } else { $null }
            SourceExists = $existsL
            DestExists   = $existsR
            SourceSize   = if ($existsL) { $l.Length } else { $null }
            DestSize     = if ($existsR) { $r.Length } else { $null }
            SourceMtime  = if ($existsL) { $l.MtimeUtc } else { $null }
            DestMtime    = if ($existsR) { $r.MtimeUtc } else { $null }
            Same         = $same
            DiffReason   = $diffReason
        }
    }
    return $results
}
