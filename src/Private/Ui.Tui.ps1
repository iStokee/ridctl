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
