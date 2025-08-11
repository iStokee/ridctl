<#
    Provides helper functions for enabling and managing shared folders
    for VMware guest VMs.  These functions will call into vmrun or
    other tooling to enable shared folders, add and remove shares and
    verify their availability from the guest.  Currently unimplemented.
#>
function Enable-RiDSharedFolder {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$VmxPath,
        [Parameter(Mandatory=$true)] [string]$ShareName,
        [Parameter(Mandatory=$true)] [string]$HostPath
    )
    Write-Warning 'Enable-RiDSharedFolder is not yet implemented.'
}