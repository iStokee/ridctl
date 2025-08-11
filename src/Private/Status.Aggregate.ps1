<#
    Aggregates multiple status checks into a single object used by
    Get-RiDStatus.  For now the aggregation simply calls stub helper
    functions and collates their results.
#>
function Get-RiDAggregateStatus {
    [CmdletBinding()] param()
    $isVm        = Get-RiDHostGuestInfo
    $virtReady   = Get-RiDVirtSupport
    $toolsOk     = Get-RiDVmwareToolsStatus
    # Additional checks such as shared folder and ISO availability
    # would be added here in future milestones.
    
    return [pscustomobject]@{
        IsVM                = $isVm
        VTReady             = $virtReady
        VmwareToolsInstalled= $toolsOk
        SharedFolderOk      = $false
        IsoAvailable        = $false
        SyncNeeded          = $false
    }
}