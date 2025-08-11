function Stop-RiDVM {
    <#
    .SYNOPSIS
        Powers off a virtual machine.

    .DESCRIPTION
        Thin wrapper over VMware tooling to stop a VM.  Currently
        implemented as a stub which warns about missing functionality.

    .PARAMETER VmxPath
        Path to the .vmx file of the VM to power off.
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$VmxPath
    )
    Write-Warning 'Stop-RiDVM is not yet implemented. This command currently performs no actions.'
}