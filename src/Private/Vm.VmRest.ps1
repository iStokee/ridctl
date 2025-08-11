<#
    Wrapper functions around the VMware Workstation REST API (vmrest).
    Functions defined here will start the REST service if necessary
    and perform requests to clone or manage VMs.  Currently, the
    functions simply warn that they are not implemented.
#>
function Invoke-RiDVmRestRequest {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$Method,
        [Parameter(Mandatory=$true)] [string]$Uri,
        [Parameter()] [hashtable]$Headers,
        [Parameter()] $Body
    )
    Write-Warning 'Invoke-RiDVmRestRequest is not yet implemented.'
    return $null
}