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

    function _WriteBanner { Write-RiDHeader }
    function _ShowStatus {
        $s = Get-RiDStatus
        Write-RiDStatusCards -Status $s
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
                        $method = Read-Host 'Method [auto/vmcli/vmrun] (default auto)'
                        if (-not $method) { $method = 'auto' }
                        $iso  = Read-Host 'ISO path (leave blank to use helper)'
                        if (-not $iso) {
                            $useHelper = Read-Host 'Launch ISO helper now? [Y/n]'
                            if ($useHelper -notmatch '^[Nn]') { $iso = Open-RiDIsoHelper }
                        }
                        $confirm = Read-Host 'Apply changes (create VM)? [y/N]'
                        $doApply = ($confirm -match '^[Yy]')
                        New-RiDVM -Name $name -DestinationPath $dest -CpuCount ([int]$cpu) -MemoryMB ([int]$mem) -DiskGB ([int]$disk) -IsoPath ($iso) -Method $method -Apply:$doApply
                    } catch { Write-Error $_ }
                    _Pause
                }
                '3' {
                    try {
                        $vmx  = Read-Host 'Path to VMX file (e.g., C:\\VMs\\MyVM\\MyVM.vmx)'
                        $name = Read-Host 'Shared folder name (e.g. RiDShare)'
                        $host = Read-Host 'Host path to share (e.g. C:\\RiDShare)'
                        $apply = Read-Host 'Apply changes? [y/N]'
                        $doApply = ($apply -match '^[Yy]')
                        Repair-RiDSharedFolder -VmxPath $vmx -ShareName $name -HostPath $host -Apply:$doApply
                        $verify = Read-Host 'Verify inside guest now? [y/N]'
                        if ($verify -match '^[Yy]') {
                            $gu = Read-Host 'Guest username'
                            $gp = Read-Host 'Guest password'
                            $ok = Test-RiDSharedFolder -VmxPath $vmx -ShareName $name -GuestUser $gu -GuestPassword $gp
                            if ($ok) { Write-Host 'Guest can access the shared folder.' -ForegroundColor Green } else { Write-Host 'Guest cannot access the shared folder.' -ForegroundColor Yellow }
                        }
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
                                $vmx = Read-Host 'Path to VMX file (e.g., C:\\VMs\\MyVM\\MyVM.vmx)'
                                $apply = Read-Host 'Apply? [y/N]'
                                Start-RiDVM -VmxPath $vmx -Apply:($apply -match '^[Yy]')
                            }
                            'b' {
                                $vmx = Read-Host 'Path to VMX file (e.g., C:\\VMs\\MyVM\\MyVM.vmx)'
                                $hard = Read-Host 'Hard stop? [y/N]'
                                $apply = Read-Host 'Apply? [y/N]'
                                Stop-RiDVM -VmxPath $vmx -Hard:($hard -match '^[Yy]') -Apply:($apply -match '^[Yy]')
                            }
                            'c' {
                                $vmx = Read-Host 'Path to VMX file (e.g., C:\\VMs\\MyVM\\MyVM.vmx)'
                                $snap = Read-Host 'Snapshot name'
                                $apply = Read-Host 'Apply? [y/N]'
                                Checkpoint-RiDVM -VmxPath $vmx -SnapshotName $snap -Apply:($apply -match '^[Yy]')
                            }
                            default { }
                        }
                    } catch { Write-Error $_ }
                    _Pause
                }
                'X' { return }
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
                'X' { return }
                default { Write-Host 'Invalid selection.' -ForegroundColor Yellow; _Pause }
            }
        }
    }
}
