<#
    Detects the presence of VMware command line tools (vmcli, vmrun,
    vmrest).  These functions will be used by New-RiDVM and other
    operations to select the appropriate management interface.
#>
function Get-RiDVmTools {
    [CmdletBinding()] param()
    # Attempt to locate vmcli/vmrun using Get-Command. Also search common
    # installation paths as a fallback on Windows hosts.
    $vmcli = $null
    $vmrun = $null
    try {
        $cfg = Get-RiDConfig
        if ($cfg -and $cfg['Vmware'] -and $cfg['Vmware']['vmrunPath']) {
            $p = [string]$cfg['Vmware']['vmrunPath']
            if ($p -and (Test-Path -LiteralPath $p)) { $vmrun = $p }
        }
    } catch { }
    try {
        $vmcliCmd = Get-Command -Name vmcli, vmcli.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($vmcliCmd) { $vmcli = $vmcliCmd.Source }
    } catch {}
    try {
        if (-not $vmrun) {
            $vmrunCmd = Get-Command -Name vmrun, vmrun.exe -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($vmrunCmd) { $vmrun = $vmrunCmd.Source }
        }
    } catch {}
    # Fallback search for vmrun in default installation directories if not found
    if (-not $vmrun) {
        $possible = @(
            'C:\\Program Files\\VMware\\VMware Workstation\\vmrun.exe',
            'C:\\Program Files (x86)\\VMware\\VMware Workstation\\vmrun.exe'
        )
        foreach ($p in $possible) {
            if (Test-Path -Path $p) { $vmrun = $p; break }
        }
    }
    [pscustomobject]@{
        VmCliPath  = $vmcli
        VmrunPath  = $vmrun
        VmrestPath = $null
    }
}

function Get-RiDWorkstationInfo {
    [CmdletBinding()] param()
    $installPath = $null
    $version = $null
    $installed = $false
    try {
        $keys = @(
            'HKLM:\SOFTWARE\VMware, Inc.\VMware Workstation',
            'HKLM:\SOFTWARE\WOW6432Node\VMware, Inc.\VMware Workstation'
        )
        foreach ($k in $keys) {
            try {
                $ip = (Get-ItemProperty -Path $k -Name InstallPath -ErrorAction SilentlyContinue | Select-Object -ExpandProperty InstallPath -ErrorAction SilentlyContinue)
                $ver = (Get-ItemProperty -Path $k -Name Version -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Version -ErrorAction SilentlyContinue)
                if ($ip) { $installPath = [string]$ip }
                if ($ver) { $version = [string]$ver }
            } catch { }
        }
    } catch { }

    # Verify presence by checking real executables, not just registry entries
    $pathsToCheck = @()
    if ($installPath) {
        $pathsToCheck += (Join-Path -Path $installPath -ChildPath 'vmware.exe')
        $pathsToCheck += (Join-Path -Path $installPath -ChildPath 'vmrun.exe')
        $pathsToCheck += (Join-Path -Path $installPath -ChildPath 'vmcli.exe')
    }
    $pathsToCheck += 'C:\\Program Files\\VMware\\VMware Workstation\\vmware.exe'
    $pathsToCheck += 'C:\\Program Files (x86)\\VMware\\VMware Workstation\\vmware.exe'
    $pathsToCheck += 'C:\\Program Files\\VMware\\VMware Workstation\\vmrun.exe'
    $pathsToCheck += 'C:\\Program Files (x86)\\VMware\\VMware Workstation\\vmrun.exe'
    $pathsToCheck += 'C:\\Program Files\\VMware\\VMware Workstation\\vmcli.exe'
    $pathsToCheck += 'C:\\Program Files (x86)\\VMware\\VMware Workstation\\vmcli.exe'

    try {
        $tools = Get-RiDVmTools
        if ($tools.VmrunPath -and (Test-Path -LiteralPath $tools.VmrunPath)) { $installed = $true }
        if ($tools.VmCliPath  -and (Test-Path -LiteralPath $tools.VmCliPath))  { $installed = $true }
    } catch { }

    if (-not $installed) {
        foreach ($p in $pathsToCheck) {
            try { if (Test-Path -LiteralPath $p) { $installed = $true; break } } catch { }
        }
    }

    return [pscustomobject]@{ Installed = [bool]$installed; InstallPath = $installPath; Version = $version }
}
