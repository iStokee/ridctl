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
        [Parameter(Mandatory=$true)] [string]$SnapshotName,
        [Parameter()] [switch]$Apply
    )
    $tools = Get-RiDVmTools
    if (-not $tools.VmrunPath) {
        Write-Warning 'vmrun not found. Unable to create snapshot.'
        return
    }
    Invoke-RiDVmrun -VmrunPath $tools.VmrunPath -Command 'snapshot' -Arguments @('"{0}"' -f $VmxPath, '"{0}"' -f $SnapshotName) -Apply:$Apply
}
