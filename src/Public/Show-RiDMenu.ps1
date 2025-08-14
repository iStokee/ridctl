function Show-RiDMenu {
    <#
    .SYNOPSIS
        Adaptive CLI menu for driving RiD features on host or guest.

    .DESCRIPTION
        Detects whether running on a host or inside a VM and presents
        the applicable set of actions. Integrates with the existing
        commands. Some actions are scaffolded and run in dry‑run unless
        explicitly applied.

    .EXAMPLE
        PS> Show-RiDMenu
    #>
    [CmdletBinding()] param()

    function _WriteBanner {
        Write-Host 'RiD Control' -ForegroundColor Cyan
        Write-Host '============' -ForegroundColor Cyan
    }

    function _ShowStatus {
        $s = Get-RiDStatus
        $role = if ($s.IsVM) { 'Guest VM' } else { 'Host' }
        Write-Host ("Role: {0}" -f $role) -ForegroundColor White
        if (-not $s.IsVM) {
            $vt = if ($s.VTReady -eq $true) { 'Ready' } elseif ($s.VTReady -eq $false) { 'Not Ready' } else { 'Unknown' }
            Write-Host ("Virtualization: {0}" -f $vt) -ForegroundColor White
        }
        Write-Host ("VMware Tools Installed: {0}" -f $s.VmwareToolsInstalled) -ForegroundColor White
        Write-Host ''
    }

    function _Pause {
        [void](Read-Host 'Press Enter to return to the menu')
    }

    while ($true) {
        Clear-Host
        _WriteBanner
        _ShowStatus

        $isVm = Get-RiDHostGuestInfo
        if (-not $isVm) {
            Write-Host 'Select an action (Host):' -ForegroundColor Green
            Write-Host '  1) Virtualization readiness check'
            Write-Host '  2) Create new VM (scaffold)'
            Write-Host '  3) Provision/Repair shared folder (vmrun)'
            Write-Host '  4) Sync scripts (scaffold)'
            Write-Host '  5) ISO helper'
            Write-Host '  6) Utilities (power/snapshot)'
            Write-Host '  X) Exit'
            $choice = Read-Host 'Enter choice'
            switch ($choice.ToUpper()) {
                '1' {
                    try { Test-RiDVirtualization -Detailed | Out-Null } catch { Write-Error $_ }
                    _Pause
                }
                '2' {
                    try {
                        $name = Read-Host 'VM Name'
                        $dest = Read-Host 'Destination folder (e.g. C:\\VMs\\RiDVM1)'
                        $cpu  = Read-Host 'CPU count (default 2)'
                        if (-not $cpu) { $cpu = 2 }
                        $mem  = Read-Host 'Memory MB (default 4096)'
                        if (-not $mem) { $mem = 4096 }
                        $disk = Read-Host 'Disk GB (default 60)'
                        if (-not $disk) { $disk = 60 }
                        $iso  = Read-Host 'ISO path (leave blank to skip)'
                        New-RiDVM -Name $name -DestinationPath $dest -CpuCount ([int]$cpu) -MemoryMB ([int]$mem) -DiskGB ([int]$disk) -IsoPath ($iso)
                    } catch { Write-Error $_ }
                    _Pause
                }
                '3' {
                    try {
                        $vmx  = Read-Host 'Path to VMX file'
                        $name = Read-Host 'Shared folder name (e.g. RiDShare)'
                        $host = Read-Host 'Host path to share (e.g. C:\\RiDShare)'
                        $apply = Read-Host 'Apply changes? [y/N]'
                        $doApply = ($apply -match '^[Yy]')
                        Repair-RiDSharedFolder -VmxPath $vmx -ShareName $name -HostPath $host -Apply:$doApply
                    } catch { Write-Error $_ }
                    _Pause
                }
                '4' {
                    try {
                        $dir = Read-Host 'Direction: FromShare (F), ToShare (T) or Bidirectional (B) [B]'
                        $dry = Read-Host 'Dry-run? [Y/n]'
                        $isDry = -not ($dry -match '^[Nn]')
                        switch ($dir.ToUpper()) {
                            'F' { Sync-RiDScripts -FromShare -DryRun:$isDry }
                            'T' { Sync-RiDScripts -ToShare -DryRun:$isDry }
                            default { Sync-RiDScripts -Bidirectional -DryRun:$isDry }
                        }
                    } catch { Write-Error $_ }
                    _Pause
                }
                '5' {
                    try {
                        $iso = Open-RiDIsoHelper
                        if ($iso) { Write-Host ("Selected ISO: {0}" -f $iso) -ForegroundColor Cyan }
                    } catch { Write-Error $_ }
                    _Pause
                }
                '6' {
                    try {
                        Write-Host 'Utilities:' -ForegroundColor Green
                        Write-Host '  a) Start VM'
                        Write-Host '  b) Stop VM'
                        Write-Host '  c) Snapshot VM'
                        Write-Host '  x) Back'
                        $u = Read-Host 'Choose'
                        switch ($u.ToLower()) {
                            'a' {
                                $vmx = Read-Host 'Path to VMX file'
                                $apply = Read-Host 'Apply? [y/N]'
                                Start-RiDVM -VmxPath $vmx -Apply:($apply -match '^[Yy]')
                            }
                            'b' {
                                $vmx = Read-Host 'Path to VMX file'
                                $hard = Read-Host 'Hard stop? [y/N]'
                                $apply = Read-Host 'Apply? [y/N]'
                                Stop-RiDVM -VmxPath $vmx -Hard:($hard -match '^[Yy]') -Apply:($apply -match '^[Yy]')
                            }
                            'c' {
                                $vmx = Read-Host 'Path to VMX file'
                                $snap = Read-Host 'Snapshot name'
                                $apply = Read-Host 'Apply? [y/N]'
                                Checkpoint-RiDVM -VmxPath $vmx -SnapshotName $snap -Apply:($apply -match '^[Yy]')
                            }
                            default { }
                        }
                    } catch { Write-Error $_ }
                    _Pause
                }
                'X' { break }
                default { Write-Host 'Invalid selection.' -ForegroundColor Yellow; _Pause }
            }
        } else {
            Write-Host 'Select an action (Guest VM):' -ForegroundColor Green
            Write-Host '  1) Configure VM in Windows (install Java, RiD)'
            Write-Host '  2) Sync scripts (scaffold)'
            Write-Host '  X) Exit'
            $choice = Read-Host 'Enter choice'
            switch ($choice.ToUpper()) {
                '1' {
                    try {
                        $instJava = Read-Host 'Install Java? [Y/n]'
                        $doJava = -not ($instJava -match '^[Nn]')
                        $url = Read-Host 'Override RiD URL (blank to use default)'
                        if ($url) {
                            Initialize-RiDGuest -InstallJava:($doJava) -RiDUrl $url
                        } else {
                            Initialize-RiDGuest -InstallJava:($doJava)
                        }
                    } catch { Write-Error $_ }
                    _Pause
                }
                '2' {
                    try {
                        $dir = Read-Host 'Direction: FromShare (F), ToShare (T) or Bidirectional (B) [B]'
                        $dry = Read-Host 'Dry-run? [Y/n]'
                        $isDry = -not ($dry -match '^[Nn]')
                        switch ($dir.ToUpper()) {
                            'F' { Sync-RiDScripts -FromShare -DryRun:$isDry }
                            'T' { Sync-RiDScripts -ToShare -DryRun:$isDry }
                            default { Sync-RiDScripts -Bidirectional -DryRun:$isDry }
                        }
                    } catch { Write-Error $_ }
                    _Pause
                }
                'X' { break }
                default { Write-Host 'Invalid selection.' -ForegroundColor Yellow; _Pause }
            }
        }
    }
}
