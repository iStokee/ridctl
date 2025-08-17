<#
    Provides functions for rendering the text user interface (TUI) used
    throughout the RiD menu system. Implements lightweight helpers
    to print a header and colorized status lines/cards.
#>

function Write-RiDHeader {
    [CmdletBinding()] param(
        [Parameter()] [string]$Title = 'RiD Control'
    )
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ('=' * $Title.Length) -ForegroundColor Cyan
}

function _Get-RiDLightColorForState {
    param(
        [Parameter()] $State
    )
    if ($State -is [bool]) {
        if ($State) { return 'Green' } else { return 'Red' }
    }
    if ($null -eq $State) { return 'Yellow' }
    # String or other -> default to White
    return 'White'
}

function _Format-RiDStateText {
    param(
        [Parameter()] $State,
        [Parameter()] [string]$TrueText = 'OK',
        [Parameter()] [string]$FalseText = 'Not Ready',
        [Parameter()] [string]$NullText = 'Unknown'
    )
    if ($State -is [bool]) { if ($State) { return $TrueText } else { return $FalseText } }
    if ($null -eq $State) { return $NullText }
    return [string]$State
}

function Write-RiDStatusCards {
    <#
    .SYNOPSIS
        Renders simple colorized status lines for key RiD environment facets.
    .PARAMETER Status
        The object returned by Get-RiDStatus / Get-RiDAggregateStatus.
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [psobject]$Status
    )
    $role = if ($Status.IsVM) { 'Guest' } else { 'Host' }
    Write-Host ("Role: {0}" -f $role) -ForegroundColor White

    if (-not $Status.IsVM) {
        $virtText = 'Unknown'
        $virtColor = 'Yellow'
        if ($Status.VirtualizationOk -eq $true) {
            $virtText = 'Ready'; $virtColor = 'Green'
        } elseif ($Status.VTReady -eq $true -and $Status.VirtualizationConflicted) {
            $virtText = 'Conflicted'; $virtColor = 'Yellow'
        } elseif ($Status.VTReady -eq $false) {
            $virtText = 'Not Ready'; $virtColor = 'Red'
        }
        Write-Host ("Virtualization: {0}" -f $virtText) -ForegroundColor $virtColor
        # VMware Workstation presence is a fatal readiness item for VMware flows
        $vmwText = if ($Status.VmwareInstalled -eq $true) { 'Installed' } elseif ($Status.VmwareInstalled -eq $false) { 'Missing' } else { 'Unknown' }
        $vmwColor = if ($Status.VmwareInstalled -eq $true) { 'Green' } elseif ($Status.VmwareInstalled -eq $false) { 'Red' } else { 'Yellow' }
        $vmwLabel = if ($Status.VmwareVersion) { "VMware Workstation: {0} (v{1})" -f $vmwText, $Status.VmwareVersion } else { "VMware Workstation: {0}" -f $vmwText }
        Write-Host $vmwLabel -ForegroundColor $vmwColor
    }

    $isoText  = _Format-RiDStateText -State $Status.IsoAvailable -TrueText 'Available' -FalseText 'Missing'
    $isoColor = _Get-RiDLightColorForState -State $Status.IsoAvailable
    Write-Host ("ISO: {0}" -f $isoText) -ForegroundColor $isoColor

    $shareText  = _Format-RiDStateText -State $Status.SharedFolderOk -TrueText 'OK' -FalseText 'Needs Repair'
    $shareColor = _Get-RiDLightColorForState -State $Status.SharedFolderOk
    Write-Host ("Shared Folder: {0}" -f $shareText) -ForegroundColor $shareColor

    $syncText  = _Format-RiDStateText -State $Status.SyncStatus -TrueText 'OK' -FalseText 'Issues'
    $syncColor = _Get-RiDLightColorForState -State $Status.SyncStatus
    Write-Host ("Sync: {0}" -f $syncText) -ForegroundColor $syncColor

    Write-Host ''
}

function Initialize-RiDTui {
    [CmdletBinding()] param()
    # Placeholder for future TUI initialisation (key handling, layout, etc.)
    return
}

function Write-RiDReadinessBanner {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [psobject]$Status
    )
    $isHost = -not $Status.IsVM
    if (-not $isHost) { return }
    $parts = @()
    $color = 'Green'
    $virtOk = $Status.VirtualizationOk -eq $true
    $vmwOk  = $Status.VmwareInstalled -eq $true
    if ($virtOk -and $vmwOk) {
        $parts += 'Ready: VMware installed; virtualization OK.'
        if ($Status.VmwareVersion) { $parts[-1] += (' (v{0})' -f $Status.VmwareVersion) }
        $color = 'Green'
    } else {
        if (-not $vmwOk) {
            $parts += 'VMware Workstation missing - install to continue.'
            $color = 'Red'
        }
        if (-not $virtOk) {
            if ($Status.VTReady -eq $false) {
                $parts += 'Virtualization disabled in BIOS/UEFI.'
                $color = 'Red'
            } elseif ($Status.VirtualizationConflicted) {
                $conf = if ($Status.VirtualizationConflicts -and $Status.VirtualizationConflicts.Count -gt 0) { ($Status.VirtualizationConflicts -join ', ') } else { 'Conflicts present' }
                $parts += ('Conflicted: ' + $conf)
                if ($color -ne 'Red') { $color = 'Yellow' }
            } else {
                $parts += 'Virtualization status unknown.'
                if ($color -ne 'Red') { $color = 'Yellow' }
            }
        }
        $parts += 'See Test-RiDVirtualization for details.'
    }
    Write-Host ($parts -join ' ') -ForegroundColor $color
    Write-Host ''
}
