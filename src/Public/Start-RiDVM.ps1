function Start-RiDVM {
    <#
    .SYNOPSIS
        Powers on a virtual machine.

    .DESCRIPTION
        Thin wrapper over VMware vmrun, vmcli or vmrest to start a VM.
        Currently implemented as a stub which warns about missing
        functionality.

    .PARAMETER VmxPath
        Path to the .vmx file of the VM to power on.
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$VmxPath,
        [Parameter()] [switch]$Apply
    )
    $tools = Get-RiDVmTools
    if (-not $tools.VmrunPath) {
        Write-Warning 'vmrun not found. Unable to start VM.'
        return
    }
    Invoke-RiDVmrun -VmrunPath $tools.VmrunPath -Command 'start' -Arguments @('"{0}"' -f $VmxPath, 'nogui') -Apply:$Apply
}
