<#
    Wrapper functions around the traditional VMware Workstation vmrun
    tool.  These will support cloning from templates, powering on/off
    VMs, taking snapshots and managing shared folders.  Currently
    functions log a warning when called to indicate future work.
#>
function Invoke-RiDVmrun {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$Command,
        [Parameter()] [string[]]$Arguments
    )
    Write-Warning 'Invoke-RiDVmrun is not yet implemented.'
    return $null
}

function Clone-RiDVmrunTemplate {
    <#
    .SYNOPSIS
        Clones a VM from a template using vmrun.

    .DESCRIPTION
        Placeholder for clone operations using the vmrun command.  In
        the scaffold this simply prints the intended vmrun command.
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$VmrunPath,
        [Parameter(Mandatory=$true)] [string]$TemplateVmx,
        [Parameter(Mandatory=$true)] [string]$SnapshotName,
        [Parameter(Mandatory=$true)] [string]$DestinationVmx
    )
    Write-Host "[vmrun] clone \"$TemplateVmx\" \"$DestinationVmx\" full -snapshot=$SnapshotName" -ForegroundColor DarkCyan
    # TODO: Execute vmrun clone command and handle any errors.
}