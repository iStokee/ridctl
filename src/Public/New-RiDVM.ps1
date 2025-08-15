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
        [Parameter()] [ValidateSet('auto','vmcli','vmrest','vmrun')][string]$Method = 'auto',
        [Parameter()] [string]$TemplateVmx,
        [Parameter()] [string]$TemplateSnapshot,
        [Parameter()] [switch]$Apply
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
            $vmx = New-RiDVmCliVM -VmCliPath $tools.VmCliPath -Name $Name -DestinationPath $DestinationPath -CpuCount $CpuCount -MemoryMB $MemoryMB -DiskGB $DiskGB -IsoPath $IsoPath -Apply:$Apply
            if (-not $Apply) { Write-Host 'VM creation via vmcli ran in dry-run mode (printed command only).' -ForegroundColor Yellow }
        }
        'vmrun' {
            if (-not $tools.VmrunPath) {
                Write-Warning 'vmrun was selected but could not be found on this system.'
                return
            }
            # Resolve template/snapshot from params, config or prompts
            if (-not $TemplateVmx -or -not (Test-Path -Path $TemplateVmx)) {
                $cfg = Get-RiDConfig
                if (-not $TemplateVmx -and $cfg.Templates -and $cfg.Templates.DefaultVmx) { $TemplateVmx = $cfg.Templates.DefaultVmx }
            }
            if (-not $TemplateSnapshot) {
                $cfg = Get-RiDConfig
                if ($cfg.Templates -and $cfg.Templates.DefaultSnapshot) { $TemplateSnapshot = $cfg.Templates.DefaultSnapshot }
            }
            if (-not $TemplateVmx -or -not (Test-Path -Path $TemplateVmx)) { $TemplateVmx = Read-Host 'Enter the path to the template VMX file' }
            if (-not $TemplateSnapshot) { $TemplateSnapshot = Read-Host 'Enter the snapshot name in the template to clone from' }

            # Destination
            if (-not (Test-Path -Path $DestinationPath)) { New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null }
            $destVmx  = Join-Path -Path $DestinationPath -ChildPath ("${Name}.vmx")

            # Clone
            Clone-RiDVmrunTemplate -VmrunPath $tools.VmrunPath -TemplateVmx $TemplateVmx -SnapshotName $TemplateSnapshot -DestinationVmx $destVmx -Apply:$Apply

            # VMX edits (CPU/Mem + optional ISO)
            $vmxSettings = @{
                'numvcpus' = $CpuCount
                'memsize'  = $MemoryMB
            }
            if (-not $IsoPath) {
                $ask = Read-Host 'No ISO path provided. Launch ISO helper? [Y/n]'
                if ($ask -notmatch '^[Nn]') { $IsoPath = Open-RiDIsoHelper }
            }
            if ($IsoPath) {
                $vmxSettings['ide1:0.present']        = 'TRUE'
                $vmxSettings['ide1:0.fileName']       = $IsoPath
                $vmxSettings['ide1:0.deviceType']     = 'cdrom-image'
                $vmxSettings['ide1:0.startConnected'] = 'TRUE'
                $vmxSettings['ide1:0.autodetect']     = 'FALSE'
            }
            Set-RiDVmxSettings -VmxPath $destVmx -Settings $vmxSettings -Apply:$Apply | Out-Null

            $appliedText = if ($Apply) { 'and applied' } else { '(dry-run printed)' }
            $isoText     = if ($IsoPath) { ' + ISO' } else { '' }
            Write-Host ("VM clone completed {0}. VMX updated with CPU/Mem{1}." -f $appliedText, $isoText) -ForegroundColor Yellow
        }
        'none' {
            Write-Warning 'No supported VMware command line tools were detected. Please install vmcli or vmrun.'
        }
        default {
            Write-Warning "Method '$Method' is not supported in this scaffold."
        }
    }
}
