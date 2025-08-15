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
    [CmdletBinding(SupportsShouldProcess=$true)] param(
        [Parameter(ParameterSetName='ByPath', Mandatory=$true)] [string]$VmxPath,
        [Parameter(ParameterSetName='ByName', Mandatory=$true)] [string]$Name
    )
    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $resolved = Resolve-RiDVmxFromName -Name $Name
        if (-not $resolved) { return }
        $VmxPath = $resolved
    }
    if (-not (Test-RiDVmxPath -VmxPath $VmxPath -RequireExists)) { Get-RiDVmxPathHelp | Write-Host -ForegroundColor Yellow; return }
    $tools = Get-RiDVmTools
    if (-not $tools.VmrunPath) {
        Write-Warning 'vmrun not found. Unable to start VM.'
        return
    }
    $apply = $PSCmdlet.ShouldProcess($VmxPath, 'Start VM')
    Invoke-RiDVmrun -VmrunPath $tools.VmrunPath -Command 'start' -Arguments @('"{0}"' -f $VmxPath, 'nogui') -Apply:$apply
}
