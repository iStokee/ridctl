<#
    Wrapper functions around the VMware Workstation CLI tool (vmcli)
    introduced with Workstation 17.  These functions will handle
    creating new VMs, configuring hardware, attaching ISOs and
    performing other operations.  At this stage they simply raise
    a warning when called to indicate missing functionality.
#>
function Invoke-RiDVmCliCommand {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$Arguments
    )
    Write-Warning 'Invoke-RiDVmCliCommand is not yet implemented.'
    return $null
}