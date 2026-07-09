function New-RiDVM {
    <#
    .SYNOPSIS
        Creates a new VMware Workstation virtual machine according to
        user‑specified parameters.

    .DESCRIPTION
        Creates a VMware Workstation VM. Preferred path is cloning from a
        template snapshot via vmrun (fast, produces a ready-to-boot guest);
        when no template is configured it falls back to a fresh "vanilla"
        VM (Windows 11-ready VMX + VMDK via vmware-vdiskmanager) that boots
        the installer ISO. Supports dry-run via -WhatIf and prompt/confirm
        via -Confirm. Optionally attaches an ISO and edits CPU/Memory.

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
        [Parameter()] [ValidateSet('auto','clone','vanilla','vmrun','vmcli','vmrest')][string]$Method = 'auto',
        [Parameter()] [string]$TemplateVmx,
        [Parameter()] [string]$TemplateSnapshot
    )

    function _Get-DefaultIsoCandidates {
        try {
            $cfg = Get-RiDConfig
            $dir = ''
            if ($cfg['Iso'] -and $cfg['Iso']['DefaultDownloadDir']) { $dir = [string]$cfg['Iso']['DefaultDownloadDir'] }
            if (-not $dir) { $dir = 'C:\\ISO' }
            if ($dir -and (Test-Path -LiteralPath $dir)) {
                return @(Get-ChildItem -LiteralPath $dir -Filter '*.iso' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
            }
        } catch { }
        return @()
    }

    function _PromptForIsoIfMissing {
        param([string]$CurrentIso)
        if ($CurrentIso) { return $CurrentIso }
        $isos = _Get-DefaultIsoCandidates
        if ($isos.Count -gt 0) {
            Write-Host 'Available ISOs in default folder:' -ForegroundColor Green
            $i = 1
            foreach ($f in $isos) { Write-Host ("  {0}) {1}" -f $i, $f.FullName) -ForegroundColor DarkCyan; $i++ }
            $sel = Read-Host 'Select an ISO by number or press Enter to skip'
            if ($sel -match '^[0-9]+$') {
                $idx = [int]$sel
                if ($idx -ge 1 -and $idx -le $isos.Count) { return $isos[$idx-1].FullName }
            }
        }
        $ask = Read-Host 'No ISO selected. Launch ISO helper? [Y/n]'
        if ($ask -notmatch '^[Nn]') { return (Open-RiDIsoHelper) }
        return $null
    }

    # Legacy method values from older configs map to auto routing
    if ($Method -in @('vmcli','vmrest')) {
        Write-Warning ("Method '{0}' is no longer supported; using automatic routing (clone when a template is configured, else vanilla)." -f $Method)
        $Method = 'auto'
    }
    if ($Method -eq 'vmrun') { $Method = 'clone' }

    # Resolve template/snapshot from params or config
    $cfg = Get-RiDConfig
    if (-not $TemplateVmx -and $cfg['Templates'] -and $cfg['Templates']['DefaultVmx']) { $TemplateVmx = [string]$cfg['Templates']['DefaultVmx'] }
    if (-not $TemplateSnapshot -and $cfg['Templates'] -and $cfg['Templates']['DefaultSnapshot']) { $TemplateSnapshot = [string]$cfg['Templates']['DefaultSnapshot'] }
    $haveTemplate = ($TemplateVmx -and (Test-Path -Path $TemplateVmx))

    $selectedMethod = $Method
    if ($Method -eq 'auto') {
        $selectedMethod = if ($haveTemplate) { 'clone' } else { 'vanilla' }
    }

    $destVmx = Join-Path -Path $DestinationPath -ChildPath ("${Name}.vmx")

    switch ($selectedMethod) {
        'clone' {
            $tools = Get-RiDVmTools
            if (-not $tools.VmrunPath) {
                Write-Warning 'vmrun not found. Install VMware Workstation or set Vmware.vmrunPath in config.'
                return
            }
            if (-not $haveTemplate) {
                Write-Warning 'No template VMX configured (Templates.DefaultVmx) or passed via -TemplateVmx. Build a golden image first (see docs), or use -Method vanilla for a fresh VM.'
                return
            }
            if (-not $TemplateSnapshot) {
                Write-Warning 'No template snapshot configured (Templates.DefaultSnapshot) or passed via -TemplateSnapshot. Take a snapshot of the golden image and set its name in config.'
                return
            }

            $apply = $PSCmdlet.ShouldProcess($destVmx, "Clone VM from template via vmrun")
            Clone-RiDVmrunTemplate -VmrunPath $tools.VmrunPath -TemplateVmx $TemplateVmx -SnapshotName $TemplateSnapshot -DestinationVmx $destVmx -Apply:$apply | Out-Null

            # VMX edits (CPU/Mem + optional ISO; clones normally need no ISO)
            $vmxSettings = @{
                'numvcpus' = $CpuCount
                'memsize'  = $MemoryMB
            }
            if ($IsoPath) {
                $vmxSettings['sata0.present']          = 'TRUE'
                $vmxSettings['sata0:1.present']        = 'TRUE'
                $vmxSettings['sata0:1.fileName']       = $IsoPath
                $vmxSettings['sata0:1.deviceType']     = 'cdrom-image'
                $vmxSettings['sata0:1.startConnected'] = 'TRUE'
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

            if ($apply) {
                Write-Host 'VM clone completed and VMX updated.' -ForegroundColor Yellow
                try { Register-RiDVM -Name $Name -VmxPath $destVmx | Out-Null } catch { Write-Error $_ }
                Write-Host 'Next steps:' -ForegroundColor Green
                Write-Host '  - Power on the VM: Start-RiDVM -Name ' -NoNewline -ForegroundColor DarkGray; Write-Host $Name -ForegroundColor DarkGray
            } else {
                Write-Host 'Planned clone and VMX updates printed (dry-run).' -ForegroundColor Yellow
            }
        }
        'vanilla' {
            if (-not $IsoPath) { $IsoPath = _PromptForIsoIfMissing $IsoPath }
            $apply = $PSCmdlet.ShouldProcess($destVmx, 'Create vanilla VMware VM')
            $vmx = if ($apply) { New-RiDVmVanilla -Name $Name -DestinationPath $DestinationPath -CpuCount $CpuCount -MemoryMB $MemoryMB -DiskGB $DiskGB -IsoPath $IsoPath -Confirm:$false } else { $null }
            if ($apply -and $vmx) {
                try { Register-RiDVM -Name $Name -VmxPath $vmx | Out-Null } catch { Write-Error $_ }
                Write-Host 'Vanilla VM created and registered.' -ForegroundColor Green
                Write-Host 'Next steps:' -ForegroundColor Green
                Write-Host '  - Power on the VM and complete Windows setup/OOBE.' -ForegroundColor DarkGray
                Write-Host '  - Inside the guest, run: Import-Module ./src -Force; Open-RiDGuestHelper' -ForegroundColor DarkGray
                Write-Host '  - When the guest is fully prepared, snapshot it and set Templates.DefaultVmx/DefaultSnapshot to clone from it next time.' -ForegroundColor DarkGray
            } else {
                Write-Host 'Planned vanilla VM creation (dry-run).' -ForegroundColor Yellow
            }
        }
    }
}
