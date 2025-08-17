function New-RiDVM {
    <#
    .SYNOPSIS
        Creates a new VMware Workstation virtual machine according to
        user‑specified parameters.

    .DESCRIPTION
        Detects available VMware tooling (vmcli preferred, then vmrun) and
        either performs a fresh VM creation (vmcli) or clones from a template
        snapshot (vmrun). Supports dry-run via -WhatIf and prompt/confirm via
        -Confirm. Optionally attaches an ISO and edits CPU/Memory in the VMX.

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
        PS> New-RiDVM -Name 'RiDVM1' -DestinationPath 'C:\VMs' -CpuCount 2 -MemoryMB 4096 -DiskGB 60 -WhatIf
        Prints planned vmcli/vmrun actions and VMX edits without applying.
    #>
    [CmdletBinding(SupportsShouldProcess=$true)] param(
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
        [Parameter()] [string]$TemplateSnapshot
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
            $target = (Join-Path -Path $DestinationPath -ChildPath ("${Name}.vmx"))
            $apply = $PSCmdlet.ShouldProcess($target, "Create new VM via vmcli")
            $vmx = New-RiDVmCliVM -VmCliPath $tools.VmCliPath -Name $Name -DestinationPath $DestinationPath -CpuCount $CpuCount -MemoryMB $MemoryMB -DiskGB $DiskGB -IsoPath $IsoPath -Apply:$apply
            if ($apply -and $vmx) {
                $ans = Read-Host ("Register this VM as '{0}' for quick access? [Y/n]" -f $Name)
                if ($ans -notmatch '^[Nn]') {
                    try { Register-RiDVM -Name $Name -VmxPath $vmx -Confirm:$true } catch { Write-Error $_ }
                }
                Write-Host 'Next steps:' -ForegroundColor Green
                Write-Host '  - Power on the VM and complete Windows OOBE.' -ForegroundColor DarkGray
                Write-Host '  - Inside the guest, run: Import-Module ./src -Force; Open-RiDGuestHelper' -ForegroundColor DarkGray
            }
        }
        'vmrun' {
            if (-not $tools.VmrunPath) {
                Write-Warning 'vmrun was selected but could not be found on this system.'
                return
            }
            # Resolve template/snapshot from params, config or prompts
            if (-not $TemplateVmx -or -not (Test-Path -Path $TemplateVmx)) {
                $cfg = Get-RiDConfig
                if (-not $TemplateVmx -and $cfg['Templates'] -and $cfg['Templates']['DefaultVmx']) { $TemplateVmx = $cfg['Templates']['DefaultVmx'] }
            }
            if (-not $TemplateSnapshot) {
                $cfg = Get-RiDConfig
                if ($cfg['Templates'] -and $cfg['Templates']['DefaultSnapshot']) { $TemplateSnapshot = $cfg['Templates']['DefaultSnapshot'] }
            }
            if (-not $TemplateVmx -or -not (Test-Path -Path $TemplateVmx)) { $TemplateVmx = Read-Host 'Enter the path to the template VMX file' }
            if (-not $TemplateSnapshot) { $TemplateSnapshot = Read-Host 'Enter the snapshot name in the template to clone from' }

            # Destination
            $destVmx  = Join-Path -Path $DestinationPath -ChildPath ("${Name}.vmx")

            # Confirm action and clone
            $apply = $PSCmdlet.ShouldProcess($destVmx, "Clone VM from template via vmrun")
            Clone-RiDVmrunTemplate -VmrunPath $tools.VmrunPath -TemplateVmx $TemplateVmx -SnapshotName $TemplateSnapshot -DestinationVmx $destVmx -Apply:$apply | Out-Null

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
            # VMX edit: if dry-run and VMX doesn't exist yet, print the intended settings
            if ($apply -or (Test-Path -Path $destVmx)) {
                Set-RiDVmxSettings -VmxPath $destVmx -Settings $vmxSettings -Apply:$apply | Out-Null
            } else {
                Write-Host '[vmx] Planned settings (dry-run, VMX not yet present):' -ForegroundColor DarkCyan
                foreach ($k in $vmxSettings.Keys) {
                    Write-Host ('  + {0} = "{1}"' -f $k, $vmxSettings[$k]) -ForegroundColor DarkCyan
                }
            }

            $isoText = if ($IsoPath) { ' + ISO' } else { '' }
            if ($apply) {
                Write-Host ("VM clone completed and VMX updated with CPU/Mem{0}." -f $isoText) -ForegroundColor Yellow
                $ans = Read-Host ("Register this VM as '{0}' for quick access? [Y/n]" -f $Name)
                if ($ans -notmatch '^[Nn]') {
                    try { Register-RiDVM -Name $Name -VmxPath $destVmx -Confirm:$true } catch { Write-Error $_ }
                }
                Write-Host 'Next steps:' -ForegroundColor Green
                Write-Host '  - Power on the VM and complete Windows OOBE.' -ForegroundColor DarkGray
                Write-Host '  - Inside the guest, run: Import-Module ./src -Force; Open-RiDGuestHelper' -ForegroundColor DarkGray
            } else {
                Write-Host ("Planned clone and VMX updates printed (dry-run){0}." -f $isoText) -ForegroundColor Yellow
            }
        }
        'none' {
            Write-Warning 'No supported VMware command line tools were detected. Please install vmcli or vmrun.'
        }
        default {
            Write-Warning "Method '$Method' is not supported in this scaffold."
        }
    }
}
