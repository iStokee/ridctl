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
        $vmcliCmd = Get-Command -Name vmcli, vmcli.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($vmcliCmd) { $vmcli = $vmcliCmd.Source }
    } catch {}
    try {
        $vmrunCmd = Get-Command -Name vmrun, vmrun.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($vmrunCmd) { $vmrun = $vmrunCmd.Source }
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

