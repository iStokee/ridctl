<#
    Detects the presence of VMware command line tools (vmcli, vmrun,
    vmrest).  These functions will be used by New-RiDVM and other
    operations to select the appropriate management interface.  The
    current implementation returns an empty result set.
#>
function Get-RiDVmTools {
    [CmdletBinding()] param()
    # TODO: Probe for vmcli, vmrun and vmrest executables and return their paths
    return [pscustomobject]@{
        VmCliPath  = $null
        VmrunPath  = $null
        VmrestPath = $null
    }
}