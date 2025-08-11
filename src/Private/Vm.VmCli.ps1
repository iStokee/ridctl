<#
    Wrapper functions around the VMware Workstation CLI tool (vmcli)
    introduced with Workstation 17.  These functions will handle
    creating new VMs, configuring hardware, attaching ISOs and
    performing other operations.  At this stage they simply raise
    a warning when called to indicate missing functionality.
#>
function Invoke-RiDVmCliCommand {
    <#
    .SYNOPSIS
        Runs a vmcli command.

    .DESCRIPTION
        Wraps invocation of the VMware vmcli.exe command with the
        provided arguments.  In this scaffold it writes the command
        that would be executed without actually launching vmcli.
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$VmCliPath,
        [Parameter(Mandatory=$true)] [string]$Arguments
    )
    Write-Host "[vmcli] $VmCliPath $Arguments" -ForegroundColor DarkCyan
    # TODO: Use Start-Process to invoke vmcli with arguments and handle errors.
    return $null
}

function New-RiDVmCliVM {
    <#
    .SYNOPSIS
        Creates a new VM using vmcli.

    .DESCRIPTION
        As part of the scaffold this function only prints the vmcli
        commands that would be used to create a new VM.  Later
        implementations will call Invoke-RiDVmCliCommand to perform
        actual operations.
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)] [string]$VmCliPath,
        [Parameter(Mandatory=$true)] [string]$Name,
        [Parameter(Mandatory=$true)] [string]$DestinationPath,
        [Parameter(Mandatory=$true)] [int]$CpuCount,
        [Parameter(Mandatory=$true)] [int]$MemoryMB,
        [Parameter(Mandatory=$true)] [int]$DiskGB,
        [Parameter()] [string]$IsoPath
    )
    Write-Host "Preparing to create VM '$Name' at '$DestinationPath' using vmcli." -ForegroundColor Cyan
    $args = "vm create --name \"$Name\" --cpus $CpuCount --memory $MemoryMB --disk-size $DiskGB"
    if ($IsoPath) { $args += " --iso \"$IsoPath\"" }
    Invoke-RiDVmCliCommand -VmCliPath $VmCliPath -Arguments $args
}