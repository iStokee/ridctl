function New-RiDVM {
    <#
    .SYNOPSIS
        Creates a new VMware Workstation virtual machine according to
        user‑specified parameters.

    .DESCRIPTION
        Will eventually detect available management tooling (vmcli,
        vmrest or vmrun) and either clone from a template or perform
        a fresh VM creation, attaching a Windows ISO and provisioning
        shared folders.  Until these capabilities are implemented this
        function logs that it is a placeholder and returns without
        performing any actions.

    .PARAMETER Name
        The name of the new virtual machine.

    .PARAMETER DestinationPath
        Filesystem path where the VM files should be created.

    .PARAMETER CpuCount
        Number of virtual CPUs.

    .PARAMETER MemoryMB
        Amount of virtual memory in MiB.

    .PARAMETER DiskGB
        Size of the virtual hard disk in GiB.

    .PARAMETER IsoPath
        Optional path to a Windows ISO.  If not provided the ISO
        helper will be invoked (in a future release).

    .EXAMPLE
        PS> New-RiDVM -Name 'RiDVM1' -DestinationPath 'C:\VMs' -CpuCount 2 -MemoryMB 4096 -DiskGB 60
        WARNING: New-RiDVM is not yet implemented.
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [string]$DestinationPath,

        [Parameter()] [int]$CpuCount = 2,
        [Parameter()] [int]$MemoryMB = 4096,
        [Parameter()] [int]$DiskGB = 60,
        [Parameter()] [string]$IsoPath,
        [Parameter()] [ValidateSet('auto','vmcli','vmrest','vmrun')][string]$Method = 'auto'
    )

    # Determine available VMware command line tools
    $tools = Get-RiDVmTools
    $selectedMethod = $Method
    if ($Method -eq 'auto') {
        if ($tools.VmCliPath)      { $selectedMethod = 'vmcli' }
        elseif ($tools.VmrunPath)  { $selectedMethod = 'vmrun' }
        else                       { $selectedMethod = 'none' }
    }
    switch ($selectedMethod) {
        'vmcli' {
            if (-not $tools.VmCliPath) {
                Write-Warning 'vmcli was selected but could not be found on this system.'
                return
            }
            New-RiDVmCliVM -VmCliPath $tools.VmCliPath -Name $Name -DestinationPath $DestinationPath -CpuCount $CpuCount -MemoryMB $MemoryMB -DiskGB $DiskGB -IsoPath $IsoPath
            Write-Host 'VM creation via vmcli is currently a dry‑run. No VM was actually created.' -ForegroundColor Yellow
        }
        'vmrun' {
            if (-not $tools.VmrunPath) {
                Write-Warning 'vmrun was selected but could not be found on this system.'
                return
            }
            # Prompt user for template and snapshot if not supplied via parameters
            $template = Read-Host 'Enter the path to the template VMX file'
            $snap     = Read-Host 'Enter the snapshot name in the template to clone from'
            $destVmx  = Join-Path -Path $DestinationPath -ChildPath ("${Name}.vmx")
            Clone-RiDVmrunTemplate -VmrunPath $tools.VmrunPath -TemplateVmx $template -SnapshotName $snap -DestinationVmx $destVmx
            Write-Host 'VM creation via vmrun clone is currently a dry‑run. No VM was actually created.' -ForegroundColor Yellow
        }
        'none' {
            Write-Warning 'No supported VMware command line tools were detected. Please install vmcli or vmrun.'
        }
        default {
            Write-Warning "Method '$Method' is not supported in this scaffold."
        }
    }
}