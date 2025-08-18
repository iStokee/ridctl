<#
    Aggregates multiple status checks into a single object used by
    Get-RiDStatus.  For now the aggregation simply calls stub helper
    functions and collates their results.
#>
function Get-RiDAggregateStatus {
    [CmdletBinding()] param()
    $isVm     = Get-RiDHostGuestInfo
    $virtInfo = Get-RiDVirtSupport
    $toolsOk  = Get-RiDVmwareToolsStatus
    $workInfo = $null
    if (-not $isVm) { try { $workInfo = Get-RiDWorkstationInfo } catch { } }

    # Determine virtualization readiness (host only)
    $vtReady = $null
    $virtOk  = $null
    $conflictNames = @()
    if (-not $isVm) {
        $vtReady = ($null -ne $virtInfo -and $virtInfo.VTEnabled)
        # Conflicts that typically block third‑party hypervisors
        $conflicts = @(
            $virtInfo.HyperVPresent,
            $virtInfo.VirtualMachinePlatformPresent,
            $virtInfo.WindowsHypervisorPlatformPresent,
            $virtInfo.HypervisorLaunchTypeActive,
            $virtInfo.MemoryIntegrityEnabled,
            $virtInfo.WindowsSandboxPresent,
            $virtInfo.DeviceGuardVBSRunning
        )
        $anyConflict = $false
        foreach ($c in $conflicts) { if ($c -eq $true) { $anyConflict = $true; break } }
        $virtOk = ($vtReady -eq $true -and -not $anyConflict)

        # Build conflict name list (for future surfacing)
        if ($virtInfo.HyperVPresent) { $conflictNames += 'Hyper-V' }
        if ($virtInfo.VirtualMachinePlatformPresent) { $conflictNames += 'Virtual Machine Platform' }
        if ($virtInfo.WindowsHypervisorPlatformPresent) { $conflictNames += 'Windows Hypervisor Platform' }
        if ($virtInfo.HypervisorLaunchTypeActive) { $conflictNames += 'Hyper-V hypervisor (active)' }
        if ($virtInfo.MemoryIntegrityEnabled) { $conflictNames += 'Core Isolation/Memory Integrity (HVCI)' }
        if ($virtInfo.WindowsSandboxPresent) { $conflictNames += 'Windows Sandbox' }
        if ($virtInfo.DeviceGuardVBSRunning) { $conflictNames += 'Device Guard / VBS (running)' }
    }

    # ISO availability: consider available if any *.iso exists in configured download dir
    $isoAvailable   = $false
    try {
        $cfgIsoDir = $null
        try { if ($cfg['Iso'] -and $cfg['Iso']['DefaultDownloadDir']) { $cfgIsoDir = [string]$cfg['Iso']['DefaultDownloadDir'] } } catch { }
        if (-not $cfgIsoDir) { $cfgIsoDir = 'C:\\ISO' }
        if ($cfgIsoDir -and (Test-Path -LiteralPath $cfgIsoDir)) {
            $anyIso = Get-ChildItem -LiteralPath $cfgIsoDir -Filter '*.iso' -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($anyIso) { $isoAvailable = $true }
        }
    } catch { }
    $sharedFolderOk = $false
    $syncStatus     = 'Unknown'

    # Shared folder status: if running in guest, check local UNC path using config Share.Name
    try {
        $cfg = Get-RiDConfig
        $shareName = $null
        if ($cfg['Share'] -and $cfg['Share']['Name']) { $shareName = [string]$cfg['Share']['Name'] }
        if (-not $shareName) { $shareName = 'rid' }
        if ($isVm) {
            $unc = ('\\\\vmware-host\\Shared Folders\\{0}' -f $shareName)
            $sharedFolderOk = Test-Path -Path $unc -ErrorAction SilentlyContinue
        } else {
            # On host: consider OK if configured HostPath exists
            $hostPath = $null
            if ($cfg['Share'] -and $cfg['Share']['HostPath']) { $hostPath = [string]$cfg['Share']['HostPath'] }
            if ($hostPath) { $sharedFolderOk = Test-Path -Path $hostPath -ErrorAction SilentlyContinue }
        }
    } catch { }

    $role = if ($isVm) { 'Guest' } else { 'Host' }

    return [pscustomobject]@{
        # Existing fields (preserve for tests/backcompat)
        IsVM                 = $isVm
        VTReady              = $vtReady
        VmwareToolsInstalled = $toolsOk
        SharedFolderOk       = $sharedFolderOk
        IsoAvailable         = $isoAvailable
        SyncNeeded           = $false

        # New M1 surfaces
        Role              = $role
        VirtualizationOk  = $virtOk
        VirtualizationConflicted = ($vtReady -eq $true -and $conflictNames.Count -gt 0)
        VirtualizationConflicts  = $conflictNames
        SyncStatus        = $syncStatus
        VmwareInstalled   = if ($workInfo) { [bool]$workInfo.Installed } else { $null }
        VmwareVersion     = if ($workInfo) { [string]$workInfo.Version } else { $null }
    }
}
