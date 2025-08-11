function Checkpoint-RiDVM {
    <#
    .SYNOPSIS
        Creates a snapshot (checkpoint) for a virtual machine.

    .DESCRIPTION
        Thin wrapper over VMware tooling to take a snapshot.  Currently
        implemented as a stub which warns about missing functionality.

    .PARAMETER VmxPath
        Path to the .vmx file of the VM to snapshot.

    .PARAMETER SnapshotName
        Name of the snapshot to create.
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$VmxPath,
        [Parameter(Mandatory=$true)] [string]$SnapshotName
    )
    Write-Warning 'Checkpoint-RiDVM is not yet implemented. This command currently performs no actions.'
}