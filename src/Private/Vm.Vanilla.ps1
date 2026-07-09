function New-RiDVmVanilla {
    <#
    .SYNOPSIS
        Creates a fresh VMware Workstation VM without a template.

    .DESCRIPTION
        Generates a minimal .vmx file and creates a growable VMDK via
        vmware-vdiskmanager.exe. Attaches ISO if provided, and sets CPU/Memory.
        Returns the VMX path on success. Honors -WhatIf/-Confirm via ShouldProcess.
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$DestinationPath,
        [Parameter()][int]$CpuCount = 2,
        [Parameter()][int]$MemoryMB = 4096,
        [Parameter()][int]$DiskGB = 60,
        [Parameter()][string]$IsoPath
    )
    $vmxPath = Join-Path -Path $DestinationPath -ChildPath ("{0}.vmx" -f $Name)
    $vmdkPath = Join-Path -Path $DestinationPath -ChildPath ("{0}.vmdk" -f $Name)

    $target = $vmxPath
    if (-not $PSCmdlet.ShouldProcess($target, 'Create vanilla VMware VM')) { return $null }

    try {
        if (-not (Test-Path -LiteralPath $DestinationPath)) {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        }
    } catch { Write-Error "Failed to create destination folder: $_"; return $null }

    # Find vmware-vdiskmanager.exe
    $vdm = $null
    try {
        $wk = Get-RiDWorkstationInfo
        if ($wk -and $wk.InstallPath) {
            $probe = Join-Path -Path $wk.InstallPath -ChildPath 'vmware-vdiskmanager.exe'
            if (Test-Path -LiteralPath $probe) { $vdm = $probe }
        }
    } catch { }
    if (-not $vdm) {
        foreach ($p in @(
            'C:\\Program Files\\VMware\\VMware Workstation\\vmware-vdiskmanager.exe',
            'C:\\Program Files (x86)\\VMware\\VMware Workstation\\vmware-vdiskmanager.exe'
        )) { if (Test-Path -LiteralPath $p) { $vdm = $p; break } }
    }
    if (-not $vdm) { Write-Error 'vmware-vdiskmanager.exe not found. Install VMware Workstation first.'; return $null }

    # Create disk if missing
    if (-not (Test-Path -LiteralPath $vmdkPath)) {
        $vdmArgs = ('-c -s {0}GB -a lsilogic -t 1 "{1}"' -f $DiskGB, $vmdkPath)
        Write-Host ("[vdiskmanager] {0} {1}" -f $vdm, $vdmArgs) -ForegroundColor DarkCyan
        try {
            $proc = Start-Process -FilePath $vdm -ArgumentList $vdmArgs -PassThru -Wait -NoNewWindow -ErrorAction Stop
            if ($proc.ExitCode -ne 0) { Write-Error ("vmware-vdiskmanager failed with exit code {0}" -f $proc.ExitCode); return $null }
        } catch { Write-Error "Failed to create VMDK: $_"; return $null }
    }

    # Write minimal VMX. Windows 11 setup requires EFI + Secure Boot + TPM;
    # managedvm.autoAddVTPM gives a software vTPM without full VM encryption
    # (Workstation 17+). NVMe disk and e1000e NIC have inbox Win11 drivers,
    # unlike the legacy lsilogic controller.
    $vmx = @()
    $vmx += '.encoding = "windows-1252"'
    $vmx += 'config.version = "8"'
    $vmx += 'virtualHW.version = "19"'
    $vmx += ('displayName = "{0}"' -f $Name)
    $vmx += 'guestOS = "windows11-64"'
    $vmx += ('numvcpus = "{0}"' -f $CpuCount)
    $vmx += ('memsize = "{0}"' -f $MemoryMB)
    $vmx += 'firmware = "efi"'
    $vmx += 'efi.secureBoot.enabled = "TRUE"'
    $vmx += 'managedvm.autoAddVTPM = "software"'
    $vmx += 'nvme0.present = "TRUE"'
    $vmx += 'nvme0:0.present = "TRUE"'
    $vmx += ('nvme0:0.fileName = "{0}"' -f (Split-Path -Leaf $vmdkPath))
    $vmx += 'sata0.present = "TRUE"'
    if ($IsoPath) {
        $vmx += 'sata0:1.present = "TRUE"'
        $vmx += 'sata0:1.deviceType = "cdrom-image"'
        $vmx += ('sata0:1.fileName = "{0}"' -f $IsoPath)
        $vmx += 'sata0:1.startConnected = "TRUE"'
    }
    $vmx += 'ethernet0.present = "TRUE"'
    $vmx += 'ethernet0.virtualDev = "e1000e"'
    $vmx += 'ethernet0.connectionType = "nat"'
    $vmx += 'usb.present = "TRUE"'
    $vmx += 'usb_xhci.present = "TRUE"'
    try { $vmx | Out-File -LiteralPath $vmxPath -Encoding ASCII -Force } catch { Write-Error "Failed to write VMX: $_"; return $null }

    return $vmxPath
}

