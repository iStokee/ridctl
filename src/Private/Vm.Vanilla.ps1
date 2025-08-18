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
        $args = ('-c -s {0}GB -a lsilogic -t 1 "{1}"' -f $DiskGB, $vmdkPath)
        Write-Host ("[vdiskmanager] {0} {1}" -f $vdm, $args) -ForegroundColor DarkCyan
        try {
            $proc = Start-Process -FilePath $vdm -ArgumentList $args -PassThru -Wait -NoNewWindow -ErrorAction Stop
            if ($proc.ExitCode -ne 0) { Write-Error ("vmware-vdiskmanager failed with exit code {0}" -f $proc.ExitCode); return $null }
        } catch { Write-Error "Failed to create VMDK: $_"; return $null }
    }

    # Write minimal VMX
    $vmx = @()
    $vmx += '.encoding = "windows-1252"'
    $vmx += 'config.version = "8"'
    $vmx += 'virtualHW.version = "19"'
    $vmx += ('displayName = "{0}"' -f $Name)
    $vmx += 'guestOS = "windows10-64"'
    $vmx += ('numvcpus = "{0}"' -f $CpuCount)
    $vmx += ('memsize = "{0}"' -f $MemoryMB)
    $vmx += 'firmware = "efi"'
    $vmx += 'efi.secureBoot.enabled = "TRUE"'
    $vmx += 'scsi0.present = "TRUE"'
    $vmx += 'scsi0.virtualDev = "lsilogic"'
    $vmx += 'scsi0:0.present = "TRUE"'
    $vmx += ('scsi0:0.fileName = "{0}"' -f (Split-Path -Leaf $vmdkPath))
    if ($IsoPath) {
        $vmx += 'ide1:0.present = "TRUE"'
        $vmx += 'ide1:0.deviceType = "cdrom-image"'
        $vmx += ('ide1:0.fileName = "{0}"' -f $IsoPath)
        $vmx += 'ide1:0.startConnected = "TRUE"'
        $vmx += 'ide1:0.autodetect = "FALSE"'
    }
    $vmx += 'ethernet0.present = "TRUE"'
    $vmx += 'ethernet0.connectionType = "nat"'
    $vmx += 'usb.present = "TRUE"'
    try { $vmx | Out-File -LiteralPath $vmxPath -Encoding ASCII -Force } catch { Write-Error "Failed to write VMX: $_"; return $null }

    return $vmxPath
}

