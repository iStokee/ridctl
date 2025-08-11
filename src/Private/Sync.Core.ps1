<#
    Core synchronisation functions used by Sync-RiDScripts.  These
    functions will perform the actual file operations to copy files
    from host to guest and vice versa, taking into account excludes
    and conflict resolution.  Not yet implemented.
#>
function Invoke-RiDSync {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)][ValidateSet('FromShare','ToShare','Bidirectional')][string]$Mode,
        [Parameter()][switch]$DryRun,
        [Parameter()][string]$LogPath,
        [Parameter()][switch]$ResolveConflicts
    )
    Write-Warning 'Invoke-RiDSync is not yet implemented.'
    return $null
}