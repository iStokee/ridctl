<#
    Provides functions for rendering the text user interface (TUI) used
    throughout the RiD menu system. Implements lightweight helpers
    to print a header and colorized status lines/cards.
#>

function Write-RiDHeader {
    [CmdletBinding()] param(
        [Parameter()] [string]$Title = 'RiD Control'
    )
    $version = ''
    try {
        $m = $ExecutionContext.SessionState.Module
        if ($m -and $m.Version) { $version = (' v{0}' -f $m.Version) }
    } catch { }
    $text = $Title + $version
    Write-Host ''
    Write-Host ("  {0}" -f $text) -ForegroundColor Cyan
    Write-Host ("  {0}" -f ('=' * $text.Length)) -ForegroundColor DarkCyan
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

function _Write-RiDCard {
    <#
        Renders one aligned status line: a colored badge, a fixed-width
        label, and the value text. Optional Detail prints dimmed after
        the value.
    #>
    param(
        [Parameter(Mandatory=$true)] [string]$Label,
        [Parameter(Mandatory=$true)] [string]$Text,
        [Parameter()] [string]$Color = 'White',
        [Parameter()] [string]$Detail
    )
    $badge = switch ($Color) {
        'Green'  { '[ OK ]' }
        'Red'    { '[FAIL]' }
        'Yellow' { '[WARN]' }
        default  { '[ -- ]' }
    }
    Write-Host ('  {0} ' -f $badge) -ForegroundColor $Color -NoNewline
    Write-Host ('{0,-16}' -f $Label) -ForegroundColor Gray -NoNewline
    Write-Host $Text -ForegroundColor $Color -NoNewline
    if ($Detail) { Write-Host ('  {0}' -f $Detail) -ForegroundColor DarkGray -NoNewline }
    Write-Host ''
}

function Write-RiDStatusCards {
    <#
    .SYNOPSIS
        Renders aligned, colorized status cards for key RiD environment facets.
    .PARAMETER Status
        The object returned by Get-RiDStatus / Get-RiDAggregateStatus.
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [psobject]$Status
    )
    $role = if ($Status.IsVM) { 'Guest' } else { 'Host' }
    Write-Host ("  Environment: {0}" -f $role) -ForegroundColor White
    Write-Host ''

    if (-not $Status.IsVM) {
        $virtText = 'Unknown'; $virtColor = 'Yellow'; $virtDetail = $null
        if ($Status.VirtualizationOk -eq $true) {
            $virtText = 'Ready'; $virtColor = 'Green'
        } elseif ($Status.VTReady -eq $true -and $Status.VirtualizationConflicted) {
            $virtText = 'Conflicted'; $virtColor = 'Yellow'
            if ($Status.VirtualizationConflicts -and $Status.VirtualizationConflicts.Count -gt 0) {
                $virtDetail = ($Status.VirtualizationConflicts -join ', ')
            }
        } elseif ($Status.VTReady -eq $false) {
            $virtText = 'Not Ready'; $virtColor = 'Red'; $virtDetail = 'Enable VT-x/AMD-V in BIOS/UEFI'
        }
        _Write-RiDCard -Label 'Virtualization' -Text $virtText -Color $virtColor -Detail $virtDetail

        $vmwText = if ($Status.VmwareInstalled -eq $true) { 'Installed' } elseif ($Status.VmwareInstalled -eq $false) { 'Missing' } else { 'Unknown' }
        $vmwColor = if ($Status.VmwareInstalled -eq $true) { 'Green' } elseif ($Status.VmwareInstalled -eq $false) { 'Red' } else { 'Yellow' }
        $vmwDetail = if ($Status.VmwareVersion) { ('v{0}' -f $Status.VmwareVersion) } else { $null }
        _Write-RiDCard -Label 'VMware' -Text $vmwText -Color $vmwColor -Detail $vmwDetail

        # Clone template: green when ready, yellow hint otherwise (vanilla
        # creation still works without one).
        if ($Status.PSObject.Properties.Name -contains 'TemplateReady') {
            if ($Status.TemplateReady) {
                $snap = if ($Status.TemplateSnapshot) { ('snapshot: {0}' -f $Status.TemplateSnapshot) } else { $null }
                _Write-RiDCard -Label 'Clone Template' -Text 'Configured' -Color 'Green' -Detail $snap
            } else {
                _Write-RiDCard -Label 'Clone Template' -Text 'Not Set' -Color 'Yellow' -Detail 'New VMs use fresh install; set in Options > Templates'
            }
        }
    }

    $isoText  = _Format-RiDStateText -State $Status.IsoAvailable -TrueText 'Available' -FalseText 'Missing'
    $isoColor = _Get-RiDLightColorForState -State $Status.IsoAvailable
    _Write-RiDCard -Label 'ISO' -Text $isoText -Color $isoColor

    $shareText  = _Format-RiDStateText -State $Status.SharedFolderOk -TrueText 'OK' -FalseText 'Needs Repair'
    $shareColor = _Get-RiDLightColorForState -State $Status.SharedFolderOk
    _Write-RiDCard -Label 'Shared Folder' -Text $shareText -Color $shareColor

    if (-not $Status.IsVM -and $Status.HyperVPresent -and -not $Status.WHPPresent) {
        Write-Host ''
        Write-Host "  Tip: enable 'Windows Hypervisor Platform' for best VMware/Hyper-V side-by-side compatibility." -ForegroundColor DarkYellow
    }

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

# Standard pause prompt for consistency across menus
function Pause-RiD {
    [CmdletBinding()] param()
    [void](Read-Host 'Press Enter to continue...')
}

# Consistent Yes/No reader with default handling and normalized parsing
function Read-RiDYesNo {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$Prompt,
        [Parameter()] [ValidateSet('Yes','No')] [string]$Default = 'No'
    )
    $suffix = if ($Default -eq 'Yes') { ' [Y/n]' } else { ' [y/N]' }
    $ans = Read-Host ($Prompt + $suffix)
    if ([string]::IsNullOrWhiteSpace($ans)) { return ($Default -eq 'Yes') }
    return ($ans -match '^[Yy]')
}
