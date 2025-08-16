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

    function _RunFirstRunWizard {
        try {
            # Build/normalize config so leaf values are strings
            $cfg = Initialize-RiDConfig
            if (-not $cfg['Iso']) { $cfg['Iso'] = @{} }
            if (-not $cfg['Templates']) { $cfg['Templates'] = @{} }
            if (-not $cfg['Share']) { $cfg['Share'] = @{} }
            if (-not $cfg['Vmware']) { $cfg['Vmware'] = @{} }

            Write-Host 'First-time setup: configure default options' -ForegroundColor Green
            Write-Host 'You can change these later under Options.' -ForegroundColor Yellow

            # ISO defaults
            function _S([object]$v) { if ($null -eq $v) { return '' } if ($v -is [System.Collections.IDictionary] -or ($v -is [System.Collections.IEnumerable] -and -not ($v -is [string]))) { return (ConvertTo-Json -InputObject $v -Depth 5 -Compress) } return [string]$v }
            $curIsoDir = _S $cfg['Iso']['DefaultDownloadDir']
            $ans = Read-Host ("ISO download directory [{0}]" -f $curIsoDir)
            if ($ans) { $cfg['Iso']['DefaultDownloadDir'] = $ans }
            $curRel = if (_S $cfg['Iso']['Release']) { _S $cfg['Iso']['Release'] } else { '23H2' }
            $curEd  = if (_S $cfg['Iso']['Edition']) { _S $cfg['Iso']['Edition'] } else { 'Pro' }
            $curAr  = if (_S $cfg['Iso']['Arch'])    { _S $cfg['Iso']['Arch'] }    else { 'x64' }
            $ans = Read-Host ("ISO Release (22H2/23H2/etc.) [{0}]" -f $curRel)
            if ($ans) { $cfg['Iso']['Release'] = $ans } elseif (-not $cfg['Iso']['Release']) { $cfg['Iso']['Release'] = $curRel }
            $ans = Read-Host ("ISO Edition (Home/Pro/...) [{0}]" -f $curEd)
            if ($ans) { $cfg['Iso']['Edition'] = $ans } elseif (-not $cfg['Iso']['Edition']) { $cfg['Iso']['Edition'] = $curEd }
            $ans = Read-Host ("ISO Architecture (x64/arm64) [{0}]" -f $curAr)
            if ($ans) { $cfg['Iso']['Arch'] = $ans } elseif (-not $cfg['Iso']['Arch']) { $cfg['Iso']['Arch'] = $curAr }

            # Shared folder defaults
            $curShare = if (_S $cfg['Share']['Name']) { _S $cfg['Share']['Name'] } else { 'rid' }
            $ans = Read-Host ("Shared folder name [{0}]" -f $curShare)
            if ($ans) { $cfg['Share']['Name'] = $ans } else { if (-not $cfg['Share']['Name']) { $cfg['Share']['Name'] = $curShare } }
            $curHost = if (_S $cfg['Share']['HostPath']) { _S $cfg['Share']['HostPath'] } else { 'C:\\RiDShare' }
            $ans = Read-Host ("Shared folder host path [{0}]" -f $curHost)
            if ($ans) { $cfg['Share']['HostPath'] = $ans } elseif (-not $cfg['Share']['HostPath']) { $cfg['Share']['HostPath'] = $curHost }

            # Templates defaults
            $curTplVmx = _S $cfg['Templates']['DefaultVmx']
            $ans = Read-Host ("Template VMX (for vmrun clone) [{0}]" -f $curTplVmx)
            if ($ans) { $cfg['Templates']['DefaultVmx'] = $ans }
            $curTplSnap = _S $cfg['Templates']['DefaultSnapshot']
            $ans = Read-Host ("Template snapshot name [{0}]" -f $curTplSnap)
            if ($ans) { $cfg['Templates']['DefaultSnapshot'] = $ans }

            # VMware tools paths
            $curVmrun = _S $cfg['Vmware']['vmrunPath']
            $ans = Read-Host ("vmrun path (optional) [{0}]" -f $curVmrun)
            if ($ans) { $cfg['Vmware']['vmrunPath'] = $ans }

            Set-RiDConfig -Config $cfg
            Write-Host 'Defaults saved.' -ForegroundColor Cyan

            # Friendly summary to avoid raw hashtable output
            # _S already defined above
            Write-Host 'Configured defaults:' -ForegroundColor Green
            Write-Host ("  ISO: Dir={0}, Release={1}, Edition={2}, Arch={3}" -f (_S $cfg['Iso']['DefaultDownloadDir']), (_S $cfg['Iso']['Release']), (_S $cfg['Iso']['Edition']), (_S $cfg['Iso']['Arch']))
            Write-Host ("  Share: Name={0}, HostPath={1}" -f (_S $cfg['Share']['Name']), (_S $cfg['Share']['HostPath']))
            Write-Host ("  Templates: VMX={0}, Snapshot={1}" -f (_S $cfg['Templates']['DefaultVmx']), (_S $cfg['Templates']['DefaultSnapshot']))
            Write-Host ("  VMware: vmrunPath={0}" -f (_S $cfg['Vmware']['vmrunPath']))

            # Ensure default share directory exists if configured
            try {
                $hp = _S $cfg['Share']['HostPath']
                if ($hp -and -not (Test-Path -LiteralPath $hp)) {
                    New-Item -ItemType Directory -Path $hp -Force | Out-Null
                    Write-Host ("Created shared folder directory: {0}" -f $hp) -ForegroundColor Cyan
                }
            } catch { Write-Verbose $_ }
        } catch { Write-Error $_ }
    }

    function _ShowOptionsMenu {
        function _S([object]$v) {
            if ($null -eq $v) { return '' }
            if ($v -is [System.Collections.IDictionary] -or ($v -is [System.Collections.IEnumerable] -and -not ($v -is [string]))) {
                return (ConvertTo-Json -InputObject $v -Depth 5 -Compress)
            }
            return [string]$v
        }
        
        try {
            # Normalize and ensure defaults exist for display
            $cfg = Initialize-RiDConfig
            if (-not $cfg['Iso']) { $cfg['Iso'] = @{} }
            if (-not $cfg['Templates']) { $cfg['Templates'] = @{} }
            if (-not $cfg['Share']) { $cfg['Share'] = @{} }
            if (-not $cfg['Vmware']) { $cfg['Vmware'] = @{} }

            while ($true) {
                Clear-Host
                _WriteBanner
                Write-Host 'Options' -ForegroundColor Green
                Write-Host '--------' -ForegroundColor Green
                Write-Host '[ISO]' -ForegroundColor Cyan
                Write-Host ("  1) DefaultDownloadDir = {0}" -f (_S $cfg['Iso']['DefaultDownloadDir']))
                Write-Host ("  2) FidoScriptPath     = {0}" -f (_S $cfg['Iso']['FidoScriptPath']))
                Write-Host ("  3) Release            = {0}" -f (_S $cfg['Iso']['Release']))
                Write-Host ("  4) Edition            = {0}" -f (_S $cfg['Iso']['Edition']))
                Write-Host ("  5) Arch               = {0}" -f (_S $cfg['Iso']['Arch']))
                Write-Host '[Templates]' -ForegroundColor Cyan
                Write-Host ("  6) DefaultVmx         = {0}" -f (_S $cfg['Templates']['DefaultVmx']))
                Write-Host ("  7) DefaultSnapshot    = {0}" -f (_S $cfg['Templates']['DefaultSnapshot']))
                Write-Host '[Shared Folder]' -ForegroundColor Cyan
                Write-Host ("  8) Name               = {0}" -f (_S $cfg['Share']['Name']))
                Write-Host ("  9) HostPath           = {0}" -f (_S $cfg['Share']['HostPath']))
                Write-Host '[VMware Tools]' -ForegroundColor Cyan
                Write-Host (" 10) vmrunPath          = {0}" -f (_S $cfg['Vmware']['vmrunPath']))
                Write-Host ''
                Write-Host '  S) Save   R) Reload   P) Paths   D) Reset Config   X) Back'
                $sel = Read-Host 'Choose'
                switch ($sel.ToUpper()) {
                    '1'  { $v = Read-Host 'Set Iso.DefaultDownloadDir'; if ($v) { $cfg['Iso']['DefaultDownloadDir'] = $v } }
                    '2'  { $v = Read-Host 'Set Iso.FidoScriptPath';     if ($v) { $cfg['Iso']['FidoScriptPath'] = $v } }
                    '3'  { $v = Read-Host 'Set Iso.Release';            if ($v) { $cfg['Iso']['Release'] = $v } }
                    '4'  { $v = Read-Host 'Set Iso.Edition';            if ($v) { $cfg['Iso']['Edition'] = $v } }
                    '5'  { $v = Read-Host 'Set Iso.Arch (x64/arm64)';   if ($v) { $cfg['Iso']['Arch'] = $v } }
                    '6'  { $v = Read-Host 'Set Templates.DefaultVmx';   if ($v) { $cfg['Templates']['DefaultVmx'] = $v } }
                    '7'  { $v = Read-Host 'Set Templates.DefaultSnapshot'; if ($v) { $cfg['Templates']['DefaultSnapshot'] = $v } }
                    '8'  { $v = Read-Host 'Set Share.Name';             if ($v) { $cfg['Share']['Name'] = $v } }
                    '9'  { $v = Read-Host 'Set Share.HostPath';         if ($v) { $cfg['Share']['HostPath'] = $v } }
                    '10' { $v = Read-Host 'Set Vmware.vmrunPath';       if ($v) { $cfg['Vmware']['vmrunPath'] = $v } }
                    'S'  { try { Set-RiDConfig -Config $cfg; Write-Host 'Configuration saved.' -ForegroundColor Cyan } catch { Write-Error $_ }; _Pause }
                    'R'  { $cfg = Initialize-RiDConfig; if (-not $cfg['Iso']) { $cfg['Iso'] = @{} }; if (-not $cfg['Templates']) { $cfg['Templates'] = @{} }; if (-not $cfg['Share']) { $cfg['Share'] = @{} }; if (-not $cfg['Vmware']) { $cfg['Vmware'] = @{} } }
                    'P'  {
                        try {
                            $paths = _Get-RiDConfigPaths
                            Write-Host ("System config: {0}" -f ($paths.System))
                            Write-Host ("User config:   {0}" -f ($paths.User))
                            Write-Host ("Local config:  {0}" -f ($paths.Local))
                        } catch { Write-Error $_ }
                        _Pause
                    }
                    'D'  {
                        Write-Host 'Reset configuration will delete one or more config files and rebuild defaults.' -ForegroundColor Yellow
                        $scope = Read-Host 'Scope [Local/User/System/All] (default Local)'
                        if (-not $scope) { $scope = 'Local' }
                        # Accept initial letter shortcuts (l/u/s/a)
                        switch ($scope.ToLower()) {
                            'l' { $scope = 'Local' }
                            'u' { $scope = 'User' }
                            's' { $scope = 'System' }
                            'a' { $scope = 'All' }
                        }
                        $confirm = Read-Host ("Are you sure you want to reset '{0}'? This will remove the file(s). [y/N]" -f $scope)
                        if ($confirm -match '^[Yy]') {
                            try { Reset-RiDConfig -Scope $scope -Confirm:$true | Out-Null; Write-Host 'Configuration reset and defaults rebuilt.' -ForegroundColor Cyan } catch { Write-Error $_ }
                        } else { Write-Host 'Cancelled.' -ForegroundColor Yellow }
                        _Pause
                    }
                    'X'  { return }
                    default { Write-Host 'Invalid selection.' -ForegroundColor Yellow; _Pause }
                }
            }
        } catch { Write-Error $_ }
    }

    while ($true) {
        Clear-Host
        # Ensure config exists and has defaults; safe no-op if already present
        try { Initialize-RiDConfig | Out-Null } catch { }
        if (-not $script:RiDFirstRunWizardDone -and $script:RiDConfigCreatedNew) {
            $prompt = Read-Host 'It looks like this is your first run. Configure defaults now? [Y/n]'
            if ($prompt -notmatch '^[Nn]') { _RunFirstRunWizard }
            $script:RiDFirstRunWizardDone = $true
        }
        _WriteBanner
        _ShowStatus

        $isVm = Get-RiDHostGuestInfo
        if (-not $isVm) {
            Write-Host 'Select an action (Host):' -ForegroundColor Green
            Write-Host '  1) Virtualization readiness check'
            Write-Host '  2) Create new VM (scaffold)'
            Write-Host '  3) Provision/Repair shared folder (vmrun)'
            Write-Host '  4) Sync scripts'
            Write-Host '  5) ISO helper'
            Write-Host '  6) Utilities (power/snapshot)'
            Write-Host '  7) Registered VMs'
            Write-Host '  8) Options'
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
                        $preview = Read-Host 'Preview only with -WhatIf? [Y/n]'
                        if ($preview -match '^[Nn]') {
                            New-RiDVM -Name $name -DestinationPath $dest -CpuCount ([int]$cpu) -MemoryMB ([int]$mem) -DiskGB ([int]$disk) -IsoPath ($iso) -Method $method -Confirm:$true
                        } else {
                            New-RiDVM -Name $name -DestinationPath $dest -CpuCount ([int]$cpu) -MemoryMB ([int]$mem) -DiskGB ([int]$disk) -IsoPath ($iso) -Method $method -WhatIf
                        }
                    } catch { Write-Error $_ }
                    _Pause
                }
                '3' {
                    try {
                        $vmx  = Read-Host 'Path to VMX file (e.g., C:\\VMs\\MyVM\\MyVM.vmx)'
                        $name = Read-Host 'Shared folder name (e.g. RiDShare)'
                        $host1 = Read-Host 'Host path to share (e.g. C:\\RiDShare)'
                        $preview = Read-Host 'Preview only with -WhatIf? [Y/n]'
                        if ($preview -match '^[Nn]') {
                            Repair-RiDSharedFolder -VmxPath $vmx -ShareName $name -HostPath $host1 -Confirm:$true
                        } else {
                            Repair-RiDSharedFolder -VmxPath $vmx -ShareName $name -HostPath $host1 -WhatIf
                        }
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
                                $selName = $null; $selVmx = $null; $useReg = $false
                                $vms = Get-RiDVM
                                if ($vms -and $vms.Count -gt 0) {
                                    $pick = Read-Host 'Choose from registered VMs? [Y/n]'
                                    if ($pick -notmatch '^[Nn]') {
                                        $i = 1
                                        foreach ($vm in $vms) {
                                            $exists = if ($vm.Exists) { 'Yes' } else { 'No' }
                                            Write-Host ("  {0}) {1} -> {2}  [{3}]" -f $i, ([string]$vm.Name), ([string]$vm.VmxPath), $exists)
                                            $i++
                                        }
                                        $sel = Read-Host 'Select index'
                                        if ($sel -match '^[0-9]+$') {
                                            $idx = [int]$sel
                                            if ($idx -ge 1 -and $idx -le $vms.Count) {
                                                $selName = $vms[$idx-1].Name
                                                $selVmx  = $vms[$idx-1].VmxPath
                                                $useReg = $true
                                            }
                                        }
                                    }
                                }
                                if (-not $useReg) { $selVmx = Read-Host 'Path to VMX file (e.g., C:\\VMs\\MyVM\\MyVM.vmx)' }
                                $preview = Read-Host 'Preview only with -WhatIf? [Y/n]'
                                if ($useReg) {
                                    if ($preview -match '^[Nn]') { Start-RiDVM -Name $selName -Confirm:$true } else { Start-RiDVM -Name $selName -WhatIf }
                                } else {
                                    if ($preview -match '^[Nn]') { Start-RiDVM -VmxPath $selVmx -Confirm:$true } else { Start-RiDVM -VmxPath $selVmx -WhatIf }
                                }
                            }
                            'b' {
                                $selName = $null; $selVmx = $null; $useReg = $false
                                $vms = Get-RiDVM
                                if ($vms -and $vms.Count -gt 0) {
                                    $pick = Read-Host 'Choose from registered VMs? [Y/n]'
                                    if ($pick -notmatch '^[Nn]') {
                                        $i = 1
                                        foreach ($vm in $vms) {
                                            $exists = if ($vm.Exists) { 'Yes' } else { 'No' }
                                            Write-Host ("  {0}) {1} -> {2}  [{3}]" -f $i, ([string]$vm.Name), ([string]$vm.VmxPath), $exists)
                                            $i++
                                        }
                                        $sel = Read-Host 'Select index'
                                        if ($sel -match '^[0-9]+$') {
                                            $idx = [int]$sel
                                            if ($idx -ge 1 -and $idx -le $vms.Count) {
                                                $selName = $vms[$idx-1].Name
                                                $selVmx  = $vms[$idx-1].VmxPath
                                                $useReg = $true
                                            }
                                        }
                                    }
                                }
                                if (-not $useReg) { $selVmx = Read-Host 'Path to VMX file (e.g., C:\\VMs\\MyVM\\MyVM.vmx)' }
                                $hard = Read-Host 'Hard stop? [y/N]'
                                $preview = Read-Host 'Preview only with -WhatIf? [Y/n]'
                                if ($useReg) {
                                    if ($preview -match '^[Nn]') { Stop-RiDVM -Name $selName -Hard:($hard -match '^[Yy]') -Confirm:$true } else { Stop-RiDVM -Name $selName -Hard:($hard -match '^[Yy]') -WhatIf }
                                } else {
                                    if ($preview -match '^[Nn]') { Stop-RiDVM -VmxPath $selVmx -Hard:($hard -match '^[Yy]') -Confirm:$true } else { Stop-RiDVM -VmxPath $selVmx -Hard:($hard -match '^[Yy]') -WhatIf }
                                }
                            }
                            'c' {
                                $selName = $null; $selVmx = $null; $useReg = $false
                                $vms = Get-RiDVM
                                if ($vms -and $vms.Count -gt 0) {
                                    $pick = Read-Host 'Choose from registered VMs? [Y/n]'
                                    if ($pick -notmatch '^[Nn]') {
                                        $i = 1
                                        foreach ($vm in $vms) {
                                            $exists = if ($vm.Exists) { 'Yes' } else { 'No' }
                                            Write-Host ("  {0}) {1} -> {2}  [{3}]" -f $i, ([string]$vm.Name), ([string]$vm.VmxPath), $exists)
                                            $i++
                                        }
                                        $sel = Read-Host 'Select index'
                                        if ($sel -match '^[0-9]+$') {
                                            $idx = [int]$sel
                                            if ($idx -ge 1 -and $idx -le $vms.Count) {
                                                $selName = $vms[$idx-1].Name
                                                $selVmx  = $vms[$idx-1].VmxPath
                                                $useReg = $true
                                            }
                                        }
                                    }
                                }
                                if (-not $useReg) { $selVmx = Read-Host 'Path to VMX file (e.g., C:\\VMs\\MyVM\\MyVM.vmx)' }
                                $snap = Read-Host 'Snapshot name'
                                $preview = Read-Host 'Preview only with -WhatIf? [Y/n]'
                                if ($useReg) {
                                    if ($preview -match '^[Nn]') { Checkpoint-RiDVM -Name $selName -SnapshotName $snap -Confirm:$true } else { Checkpoint-RiDVM -Name $selName -SnapshotName $snap -WhatIf }
                                } else {
                                    if ($preview -match '^[Nn]') { Checkpoint-RiDVM -VmxPath $selVmx -SnapshotName $snap -Confirm:$true } else { Checkpoint-RiDVM -VmxPath $selVmx -SnapshotName $snap -WhatIf }
                                }
                            }
                            default { }
                        }
                    } catch { Write-Error $_ }
                    _Pause
                }
                '7' {
                    try {
                        $vms = Get-RiDVM
                        if (-not $vms -or $vms.Count -eq 0) {
                            Write-Host 'No VMs registered yet.' -ForegroundColor Yellow
                            $doReg = Read-Host 'Register an existing VM now? [Y/n]'
                            if ($doReg -notmatch '^[Nn]') {
                                $nm = Read-Host 'Friendly name'
                                $vx = Read-Host 'Path to VMX file (e.g., C:\\VMs\\MyVM\\MyVM.vmx)'
                                try { 
                                    Register-RiDVM -Name $nm -VmxPath $vx
                                    $count = (Get-RiDVM | Measure-Object).Count
                                    Write-Host ("Registered. Now {0} VM(s) saved." -f $count) -ForegroundColor Cyan
                                } catch { Write-Error $_ }
                            }
                        } else {
                            Write-Host 'Registered VMs:' -ForegroundColor Green
                            $i = 1
                            foreach ($vm in $vms) {
                                $exists = if ($vm.Exists) { 'Yes' } else { 'No' }
                                Write-Host ("  {0}) {1} -> {2}  [{3}]" -f $i, ([string]$vm.Name), ([string]$vm.VmxPath), $exists)
                                $i++
                            }
                            Write-Host '  r) Register another VM'
                            Write-Host '  u) Unregister a VM'
                            Write-Host '  x) Back'
                            $sel = Read-Host 'Choose'
                            if ($sel -match '^[0-9]+$') {
                                $idx = [int]$sel
                                if ($idx -ge 1 -and $idx -le $vms.Count) {
                                    $vm = $vms[$idx-1]
                                    Write-Host ("Selected: {0} -> {1}" -f $vm.Name, $vm.VmxPath) -ForegroundColor Cyan
                                    Write-Host '  a) Start'
                                    Write-Host '  b) Stop'
                                    Write-Host '  c) Snapshot'
                                    Write-Host '  x) Back'
                                    $act = Read-Host 'Action'
                                    switch ($act.ToLower()) {
                                        'a' {
                                            $preview = Read-Host 'Preview only with -WhatIf? [Y/n]'
                                            if ($preview -match '^[Nn]') { Start-RiDVM -Name $vm.Name -Confirm:$true } else { Start-RiDVM -Name $vm.Name -WhatIf }
                                        }
                                        'b' {
                                            $hard = Read-Host 'Hard stop? [y/N]'
                                            $preview = Read-Host 'Preview only with -WhatIf? [Y/n]'
                                            if ($preview -match '^[Nn]') { Stop-RiDVM -Name $vm.Name -Hard:($hard -match '^[Yy]') -Confirm:$true } else { Stop-RiDVM -Name $vm.Name -Hard:($hard -match '^[Yy]') -WhatIf }
                                        }
                                        'c' {
                                            $snap = Read-Host 'Snapshot name'
                                            $preview = Read-Host 'Preview only with -WhatIf? [Y/n]'
                                            if ($preview -match '^[Nn]') { Checkpoint-RiDVM -Name $vm.Name -SnapshotName $snap -Confirm:$true } else { Checkpoint-RiDVM -Name $vm.Name -SnapshotName $snap -WhatIf }
                                        }
                                        default { }
                                    }
                                }
                            } elseif ($sel.ToLower() -eq 'r') {
                                $nm = Read-Host 'Friendly name'
                                $vx = Read-Host 'Path to VMX file (e.g., C:\\VMs\\MyVM\\MyVM.vmx)'
                                try { 
                                    Register-RiDVM -Name $nm -VmxPath $vx
                                    $count = (Get-RiDVM | Measure-Object).Count
                                    Write-Host ("Registered. Now {0} VM(s) saved." -f $count) -ForegroundColor Cyan
                                } catch { Write-Error $_ }
                            } elseif ($sel.ToLower() -eq 'u') {
                                $nm = Read-Host 'Name to unregister'
                                try { 
                                    Unregister-RiDVM -Name $nm
                                    $count = (Get-RiDVM | Measure-Object).Count
                                    Write-Host ("Unregistered. Now {0} VM(s) saved." -f $count) -ForegroundColor Cyan
                                } catch { Write-Error $_ }
                            }
                        }
                    } catch { Write-Error $_ }
                    _Pause
                }
                '8' { _ShowOptionsMenu }
                'X' { return }
                default { Write-Host 'Invalid selection.' -ForegroundColor Yellow; _Pause }
            }
        } else {
            Write-Host 'Select an action (Guest VM):' -ForegroundColor Green
            Write-Host '  1) Configure VM in Windows (install Java, RiD)'
            Write-Host '  2) Sync scripts'
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
