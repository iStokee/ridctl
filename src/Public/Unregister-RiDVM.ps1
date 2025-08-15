function Unregister-RiDVM {
    <#
    .SYNOPSIS
        Removes a VM from the registry by name.
    #>
    [CmdletBinding(SupportsShouldProcess=$true)] param(
        [Parameter(Mandatory=$true)] [string]$Name
    )
    if ($PSCmdlet.ShouldProcess($Name, 'Unregister VM')) {
        Remove-RiDVmRegistryEntry -Name $Name
        Write-Host ("Unregistered VM '{0}'." -f $Name) -ForegroundColor Cyan
    }
}

