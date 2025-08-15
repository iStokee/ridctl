function Repair-RiDSharedFolder {
    <#
    .SYNOPSIS
        Configures or repairs a shared folder for a VMware guest.

    .DESCRIPTION
        Enables shared folders on a target virtual machine, adds the
        configured share if it does not already exist and verifies the
        folder is accessible from within the guest.  This stub
        implementation warns that the feature is not yet available.

    .PARAMETER VmxPath
        Path to the .vmx file for the target VM.

    .PARAMETER ShareName
        Name of the shared folder as it will appear inside the VM.

    .PARAMETER HostPath
        Host filesystem path to share with the guest.

    .EXAMPLE
        PS> Repair-RiDSharedFolder -VmxPath 'C:\VMs\RiDVM1\RiDVM1.vmx' -ShareName 'RiDShare' -HostPath 'C:\RiDShare'
        WARNING: Repair-RiDSharedFolder is not yet implemented.
    #>
    [CmdletBinding(SupportsShouldProcess=$true)] param(
        [Parameter(ParameterSetName='ByPath', Mandatory=$true)] [string]$VmxPath,
        [Parameter(ParameterSetName='ByName', Mandatory=$true)] [string]$Name,
        [Parameter(Mandatory=$true)] [string]$ShareName,
        [Parameter(Mandatory=$true)] [string]$HostPath
    )
    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $resolved = Resolve-RiDVmxFromName -Name $Name
        if (-not $resolved) { return }
        $VmxPath = $resolved
    }
    if (-not (Test-RiDVmxPath -VmxPath $VmxPath -RequireExists)) { Get-RiDVmxPathHelp | Write-Host -ForegroundColor Yellow; return }
    # Locate vmrun executable
    $tools = Get-RiDVmTools
    if (-not $tools.VmrunPath) {
        Write-Warning 'vmrun not found. Unable to configure shared folders.'
        return
    }
    $apply = $PSCmdlet.ShouldProcess($VmxPath, ("Configure shared folder '{0}'" -f $ShareName))
    Enable-RiDSharedFolder -VmxPath $VmxPath -ShareName $ShareName -HostPath $HostPath -VmrunPath $tools.VmrunPath -Apply:$apply
}
