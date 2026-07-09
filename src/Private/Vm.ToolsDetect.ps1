<#
    Detects the presence of the VMware vmrun command line tool, used by
    New-RiDVM and the start/stop/snapshot operations.
#>
function Get-RiDVmTools {
    [CmdletBinding()] param()
    # Config override first, then PATH, then the registry install path,
    # then common installation directories.
    $vmrun = $null
    try {
        $cfg = Get-RiDConfig
        if ($cfg -and $cfg['Vmware'] -and $cfg['Vmware']['vmrunPath']) {
            $p = [string]$cfg['Vmware']['vmrunPath']
            if ($p -and (Test-Path -LiteralPath $p)) { $vmrun = $p }
        }
    } catch { }
    try {
        if (-not $vmrun) {
            $vmrunCmd = Get-Command -Name vmrun, vmrun.exe -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($vmrunCmd) { $vmrun = $vmrunCmd.Source }
        }
    } catch {}
    if (-not $vmrun) {
        try {
            $wk = Get-RiDWorkstationInfo
            if ($wk -and $wk.InstallPath) {
                $probe = Join-Path -Path $wk.InstallPath -ChildPath 'vmrun.exe'
                if (Test-Path -LiteralPath $probe) { $vmrun = $probe }
            }
        } catch { }
    }
    if (-not $vmrun) {
        $possible = @(
            'C:\Program Files\VMware\VMware Workstation\vmrun.exe',
            'C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe'
        )
        foreach ($p in $possible) {
            if (Test-Path -LiteralPath $p) { $vmrun = $p; break }
        }
    }
    [pscustomobject]@{
        VmrunPath = $vmrun
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

    # Verify presence by checking vmware.exe specifically (Workstation UI)
    $vmwareExePaths = @()
    if ($installPath) { $vmwareExePaths += (Join-Path -Path $installPath -ChildPath 'vmware.exe') }
    $vmwareExePaths += 'C:\\Program Files\\VMware\\VMware Workstation\\vmware.exe'
    $vmwareExePaths += 'C:\\Program Files (x86)\\VMware\\VMware Workstation\\vmware.exe'

    foreach ($p in $vmwareExePaths) {
        try { if (Test-Path -LiteralPath $p) { $installed = $true; break } } catch { }
    }

    return [pscustomobject]@{ Installed = [bool]$installed; InstallPath = $installPath; Version = $version }
}
