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
    [CmdletBinding(SupportsShouldProcess=$true)] param(
        [Parameter(ParameterSetName='ByPath', Mandatory=$true)] [string]$VmxPath,
        [Parameter(ParameterSetName='ByName', Mandatory=$true)] [string]$Name,
        [Parameter(Mandatory=$true)] [string]$SnapshotName
    )
    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $resolved = Resolve-RiDVmxFromName -Name $Name
        if (-not $resolved) { return }
        $VmxPath = $resolved
    }
    $apply = $PSCmdlet.ShouldProcess($VmxPath, ("Create snapshot '{0}'" -f $SnapshotName))
    if (-not (Test-RiDVmxPath -VmxPath $VmxPath -RequireExists:$apply)) { Get-RiDVmxPathHelp | Write-Host -ForegroundColor Yellow; return }
    $tools = Get-RiDVmTools
    if (-not $tools.VmrunPath) {
        Write-Warning 'vmrun not found. Unable to create snapshot.'
        return
    }
    Invoke-RiDVmrun -VmrunPath $tools.VmrunPath -Command 'snapshot' -Arguments @('"{0}"' -f $VmxPath, '"{0}"' -f $SnapshotName) -Apply:$apply
}
