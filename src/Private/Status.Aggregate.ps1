<#
    Aggregates multiple status checks into a single object used by
    Get-RiDStatus.  For now the aggregation simply calls stub helper
    functions and collates their results.
#>
function Get-RiDAggregateStatus {
    [CmdletBinding()] param()
    $isVm        = Get-RiDHostGuestInfo
    $virtInfo    = Get-RiDVirtSupport
    $toolsOk     = Get-RiDVmwareToolsStatus
    # Additional checks such as shared folder and ISO availability
    # would be added here in future milestones.

    # Determine virtualization readiness only for hosts; inside a VM we set null.
    $vtReady = $null
    if (-not $isVm) {
        if ($null -ne $virtInfo -and $virtInfo.VTEnabled) {
            $vtReady = $true
        } else {
            $vtReady = $false
        }
    }

    return [pscustomobject]@{
        IsVM                = $isVm
        VTReady             = $vtReady
        VmwareToolsInstalled= $toolsOk
        SharedFolderOk      = $false
        IsoAvailable        = $false
        SyncNeeded          = $false
    }
}