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
        [Parameter(Mandatory=$true)] [string]$VmxPath
    )
    Write-Warning 'Start-RiDVM is not yet implemented. This command currently performs no actions.'
}