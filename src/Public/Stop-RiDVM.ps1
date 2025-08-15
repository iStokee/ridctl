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
        [Parameter(Mandatory=$true)] [string]$VmxPath,
        [Parameter()] [switch]$Hard,
        [Parameter()] [switch]$Apply
    )
    if (-not (Test-RiDVmxPath -VmxPath $VmxPath -RequireExists)) { Get-RiDVmxPathHelp | Write-Host -ForegroundColor Yellow; return }
    $tools = Get-RiDVmTools
    if (-not $tools.VmrunPath) {
        Write-Warning 'vmrun not found. Unable to stop VM.'
        return
    }
    $mode = if ($Hard) { 'hard' } else { 'soft' }
    Invoke-RiDVmrun -VmrunPath $tools.VmrunPath -Command 'stop' -Arguments @('"{0}"' -f $VmxPath, $mode) -Apply:$Apply
}
