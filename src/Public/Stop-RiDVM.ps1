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
    [CmdletBinding(SupportsShouldProcess=$true)] param(
        [Parameter(ParameterSetName='ByPath', Mandatory=$true)] [string]$VmxPath,
        [Parameter(ParameterSetName='ByName', Mandatory=$true)] [string]$Name,
        [Parameter()] [switch]$Hard
    )
    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $resolved = Resolve-RiDVmxFromName -Name $Name
        if (-not $resolved) { return }
        $VmxPath = $resolved
    }
    $mode = if ($Hard) { 'hard' } else { 'soft' }
    $apply = $PSCmdlet.ShouldProcess($VmxPath, ("Stop VM ({0})" -f $mode))
    if (-not (Test-RiDVmxPath -VmxPath $VmxPath -RequireExists:$apply)) { Get-RiDVmxPathHelp | Write-Host -ForegroundColor Yellow; return }
    $tools = Get-RiDVmTools
    if (-not $tools.VmrunPath) {
        Write-Warning 'vmrun not found. Unable to stop VM.'
        return
    }
    Invoke-RiDVmrun -VmrunPath $tools.VmrunPath -Command 'stop' -Arguments @('"{0}"' -f $VmxPath, $mode) -Apply:$apply
}
