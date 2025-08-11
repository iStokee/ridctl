<#
    Wrapper functions around the traditional VMware Workstation vmrun
    tool.  These will support cloning from templates, powering on/off
    VMs, taking snapshots and managing shared folders.  Currently
    functions log a warning when called to indicate future work.
#>
function Invoke-RiDVmrun {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$Command,
        [Parameter()] [string[]]$Arguments
    )
    Write-Warning 'Invoke-RiDVmrun is not yet implemented.'
    return $null
}