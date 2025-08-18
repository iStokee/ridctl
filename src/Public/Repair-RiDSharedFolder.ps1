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
    # Branch by provider
    $cfg = Get-RiDConfig
    $provider = Get-RiDProviderPreference -Config $cfg
    if ($provider -eq 'hyperv') {
        Write-Warning 'Repair-RiDSharedFolder is not applicable to Hyper-V. Use Sync-RiDScripts with -Name and -GuestPath (GSI copy) or map an SMB share inside the guest.'
        return
    }
    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $resolved = Resolve-RiDVmxFromName -Name $Name
        if (-not $resolved) { return }
        $VmxPath = $resolved
    }
    # Decide whether we're applying (ShouldProcess) before strict validation, so dry-run can still preview
    $apply = $PSCmdlet.ShouldProcess($VmxPath, ("Configure shared folder '{0}'" -f $ShareName))
    if (-not (Test-RiDVmxPath -VmxPath $VmxPath -RequireExists:$apply)) { Get-RiDVmxPathHelp | Write-Host -ForegroundColor Yellow; return }
    # Locate vmrun executable
    $tools = Get-RiDVmTools
    if (-not $tools.VmrunPath) {
        Write-Warning 'vmrun not found. Unable to configure shared folders.'
        return
    }
    Enable-RiDSharedFolder -VmxPath $VmxPath -ShareName $ShareName -HostPath $HostPath -VmrunPath $tools.VmrunPath -Apply:$apply
}
