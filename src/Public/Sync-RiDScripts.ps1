function Sync-RiDScripts {
    <#
    .SYNOPSIS
        Synchronises scripts between a local folder and the VMware shared folder.

    .DESCRIPTION
        Copies newer/different files according to the selected direction. Defaults to
        bidirectional in dry-run unless confirmed. Uses timestamp+size by default.

    .PARAMETER FromShare
        Copy files from the VM shared folder to the local folder.

    .PARAMETER ToShare
        Copy files from the local folder to the VM shared folder.

    .PARAMETER Bidirectional
        Perform a bidirectional sync. Use -ResolveConflicts to auto-pick newer.

    .PARAMETER LocalPath
        The local working directory to sync. Defaults to current location if omitted.

    .PARAMETER ShareHostPath
        The host path backing the VMware shared folder (from config Share.HostPath if omitted).

    .PARAMETER Excludes
        Wildcard patterns (relative to root) to exclude, e.g. '**/*.log','tmp/*'.

    .PARAMETER DryRun
        Show what would change without copying any files.

    .PARAMETER LogPath
        Optional path to write a summary log of planned/applied actions.

    .PARAMETER ResolveConflicts
        When bidirectional and both sides changed, prefer the newer file (else skip with Conflict).

    .EXAMPLE
        PS> Sync-RiDScripts -ToShare -DryRun
        Shows planned copies from LocalPath -> ShareHostPath without applying.
    #>
    [CmdletBinding(DefaultParameterSetName='Bidirectional', SupportsShouldProcess=$true)]
    param(
        [Parameter(ParameterSetName='FromShare')]
        [switch]$FromShare,

        [Parameter(ParameterSetName='ToShare')]
        [switch]$ToShare,

        [Parameter(ParameterSetName='Bidirectional')]
        [switch]$Bidirectional,

        [string]$LocalPath,
        [string]$ShareHostPath,
        # Hyper-V provider parameters
        [string]$Name,
        [string]$GuestPath,
        [string[]]$Excludes,
        [switch]$DryRun,
        [string]$LogPath,
        [switch]$ResolveConflicts
    )

    $mode = if ($PSCmdlet.ParameterSetName -eq 'FromShare') { 'FromShare' }
            elseif ($PSCmdlet.ParameterSetName -eq 'ToShare') { 'ToShare' }
            else { 'Bidirectional' }

    if (-not $LocalPath -or -not $LocalPath.Trim()) {
        $LocalPath = (Get-Location).Path
    }

    $cfg = Get-RiDConfig
    if (-not $ShareHostPath -or -not $ShareHostPath.Trim()) {
        $ShareHostPath = $cfg['Share']['HostPath']
    }
    if (-not $ShareHostPath) {
        Write-Error 'ShareHostPath is not set. Provide -ShareHostPath or configure Share.HostPath via Options.'
        return
    }

    if (-not (Test-Path -LiteralPath $LocalPath)) { Write-Error "LocalPath not found: $LocalPath"; return }

    # Determine provider
    $provider = Get-RiDProviderPreference -Config $cfg

    if ($provider -eq 'hyperv') {
        if (-not $Name -or -not $GuestPath) {
            Write-Warning 'For Hyper-V provider, please specify -Name (VM) and -GuestPath (destination in guest).'
            return
        }
        $target = "$mode sync (Hyper-V) between `"$LocalPath`" and guest:`"$GuestPath`" on VM:`"$Name`""
        $apply = $PSCmdlet.ShouldProcess($target, 'Apply Hyper-V GSI copy')
        # For now, support ToShare only (push to guest)
        if ($mode -eq 'Bidirectional') {
            Write-Warning 'Bidirectional sync is not supported with Hyper-V GSI. Use -ToShare or -FromShare with SMB/ESEM.'
            return
        }
        if ($mode -eq 'FromShare') {
            Write-Warning 'Pulling from guest via GSI is limited; consider SMB/ESEM. Skipping.'
            return
        }
        # Push local -> guest recursively
        $root = Resolve-Path -LiteralPath $LocalPath | Select-Object -ExpandPath
        $files = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue
        # Apply excludes
        $effectiveExcludes = $Excludes
        if (-not $effectiveExcludes -or $effectiveExcludes.Count -eq 0) {
            try { $effectiveExcludes = $cfg['Sync']['Excludes'] } catch { $effectiveExcludes = @() }
        }
        if ($effectiveExcludes -and $effectiveExcludes.Count -gt 0) {
            $files = $files | Where-Object {
                $rel = $_.FullName.Substring($root.Length).TrimStart('\\','/')
                -not ($effectiveExcludes | Where-Object { $rel -like $_ } )
            }
        }
        $copied = 0; $skipped = 0
        foreach ($f in $files) {
            $rel = $f.FullName.Substring($root.Length).TrimStart('\\','/')
            $dest = (Join-Path -Path $GuestPath -ChildPath $rel)
            if ($apply -and -not $DryRun) {
                try { Copy-RiDHvToGuest -Name $Name -Source $f.FullName -Destination $dest; $copied++ } catch { Write-Verbose $_; $skipped++ }
            } else {
                Write-Host ("[DryRun] Copy {0} -> {1}" -f $f.FullName, $dest) -ForegroundColor DarkCyan; $skipped++
            }
        }
        Write-Host ("{0}: {1} file(s) processed (copied={2}, skipped={3})" -f (if ($apply -and -not $DryRun) { 'Applied' } else { 'Planned' }), ($files | Measure-Object).Count, $copied, $skipped)
        return
    }

    if (-not (Test-Path -LiteralPath $ShareHostPath)) { Write-Error "ShareHostPath not found: $ShareHostPath"; return }
    $target = "$mode sync between `"$LocalPath`" and `"$ShareHostPath`""
    $apply = $PSCmdlet.ShouldProcess($target, 'Apply file synchronization')

    # Determine excludes: param takes precedence, else config
    $effectiveExcludes = $Excludes
    if (-not $effectiveExcludes -or $effectiveExcludes.Count -eq 0) {
        try { $effectiveExcludes = $cfg['Sync']['Excludes'] } catch { $effectiveExcludes = @() }
    }
    $summary = Invoke-RiDSync -LocalPath $LocalPath -SharePath $ShareHostPath -Mode $mode -Excludes $effectiveExcludes -DryRun:(!$apply -or $DryRun) -LogPath $LogPath -ResolveConflicts:$ResolveConflicts -Apply:$apply

    # Print concise summary
    $copies = $summary.Copies
    $skips  = $summary.Skips
    $applied= $summary.Applied
    if (-not $apply) {
        Write-Host ("[DryRun] Plan: {0} actions ({1} copies, {2} skips)" -f $summary.Total, $copies, $skips)
    } else {
        Write-Host ("Applied: copied {0} files ({1} planned, {2} skips)" -f $applied, $copies, $skips)
    }
}
